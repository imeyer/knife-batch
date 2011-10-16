#
# Author:: Ian Meyer <ianmmeyer@gmail.com>
# Plugin name:: batch
#
# Copyright 2011, Ian Meyer
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class Batch < Chef::Knife
  banner "knife batch [QUERY] [CMD]"

  deps do
    require 'net/ssh'
    require 'net/ssh/multi'
    require 'readline'
    require 'chef/search/query'
    require 'chef/mixin/command'
  end

  option :wait,
    :short => "-W SECONDS",
    :long => "--wait SECONDS",
    :description => "The number of seconds between batches.",
    :default => 0.5

  option :batch_size,
    :short => "-B NODES",
    :long => "--batch-size NODES",
    :description => "The number of nodes to run per batch.",
    :default => 5

  option :stop_on_failure,
    :short => "-S",
    :long => "--stop-on-failure",
    :description => "Stop on first failure of remote command",
    :default => false

  option :manual,
    :short => "-m",
    :long => "--manual-list",
    :boolean => true,
    :description => "QUERY is a space separated list of servers",
    :default => false

  option :ssh_user,
    :short => "-x USERNAME",
    :long => "--ssh-user USERNAME",
    :description => "The ssh username"

  option :ssh_password,
    :short => "-P PASSWORD",
    :long => "--ssh-password PASSWORD",
    :description => "The ssh password"

  option :ssh_port,
    :short => "-p PORT",
    :long => "--ssh-port PORT",
    :description => "The ssh port",
    :default => "22",
    :proc => Proc.new { |key| Chef::Config[:knife][:ssh_port] = key }

  option :identity_file,
    :short => "-i IDENTITY_FILE",
    :long => "--identity-file IDENTITY_FILE",
    :description => "The SSH identity file used for authentication"

  option :no_host_key_verify,
    :long => "--no-host-key-verify",
    :description => "Disable host key verification",
    :boolean => true,
    :default => false

  option :attribute,
    :short => "-a ATTR",
    :long => "--attribute ATTR",
    :description => "The attribute to use for opening the connection - default is fqdn",
    :default => "fqdn"

  def session(nodes)
    ssh_error_handler = Proc.new do |server|
      if config[:manual]
        node_name = server.host
      else
        nodes.each do |n|
          node_name = n if format_for_display(n)[config[:attribute]] == server.host
        end
      end
      ui.warn "Failed to connect to #{node_name} -- #{$!.class.name}: #{$!.message}"
      $!.backtrace.each { |l| Chef::Log.debug(l) }
    end

    @ssh_session ||= Net::SSH::Multi.start(:concurrent_connections => config[:concurrency], :on_error => ssh_error_handler)
  end

  def get_nodes
    list = case config[:manual]
           when true
             @name_args[0].split(" ")
           when false
             r = Array.new
             q = Chef::Search::Query.new
             @action_nodes = q.search(:node, @name_args[0])[0]
             @action_nodes.each do |item|
               i = format_for_display(item)[config[:attribute]]
               r.push(i) unless i.nil?
             end
             r
           end
    (ui.fatal("No nodes returned from search!"); exit 10) if list.length == 0

    list.each_slice(config[:batch_size].to_i).to_a
  end

  def print_data(host, data)
    if data =~ /\n/
      data.split(/\n/).each { |d| print_data(host, d) }
    else
      padding = @longest - host.length
      print ui.color(host, :cyan)
      padding.downto(0) { print " " }
      puts data
    end
  end

  def session_from_list(nodes)
    nodes.each do |item|
      Chef::Log.debug("Adding #{item}")

      hostspec = config[:ssh_user] ? "#{config[:ssh_user]}@#{item}" : item
      session_opts = {}
      session_opts[:keys] = File.expand_path(config[:identity_file]) if config[:identity_file]
      session_opts[:password] = config[:ssh_password] if config[:ssh_password]
      session_opts[:port] = Chef::Config[:knife][:ssh_port] || config[:ssh_port]
      session_opts[:logger] = Chef::Log.logger if Chef::Log.level == :debug

      if config[:no_host_key_verify]
        session_opts[:paranoid] = false
        session_opts[:user_known_hosts_file] = "/dev/null"
      end
      session(nodes).use(hostspec, session_opts)

      @longest = item.length if item.length > @longest
    end

    session(nodes)
  end

  def ssh_command(command, subsession=nil, nodes)
    subsession ||= session(nodes)
    subsession.open_channel do |channel|
      host = channel[:host]
      channel.request_pty
      channel.exec command do |ch, success|
        exit_code = nil
        raise ArgumentError, "Cannot execute #{command}" unless success
        channel.on_data do |ch, data|
          print_data(host, data)
        end

        if config[:stop_on_failure]
          channel.on_request("exit-status") do |ch, data|
            exit_code = data.read_long
            if not exit_code.nil?
              exit 1 if exit_code.to_i > 0
            end
          end
        end
      end
    end
    @ssh_session.loop
    @ssh_session = nil
  end

  def run
    extend Chef::Mixin::Command
      
    @longest = 0
    all_nodes = get_nodes
    all_nodes.each do |nodes|
      session_from_list(nodes)

      ssh_command(@name_args[1..-1].join(" "), nodes)
      puts "*" * 80
      puts "Taking a nap for #{config[:wait]} seconds..."
      puts "*" * 80
      sleep config[:wait].to_f
    end
  end
end
