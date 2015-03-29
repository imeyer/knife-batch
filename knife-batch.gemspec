# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "knife-batch/version"

Gem::Specification.new do |s|
  s.name        = "knife-batch"
  s.version     = Knife::Batch::VERSION
  s.authors     = ["Ian Meyer"]
  s.email       = ["ianmmeyer@gmail.com"]
  s.homepage    = "http://github.com/imeyer/knife-batch"
  s.summary     = %q{Knife plugin to run ssh commands against batches of servers}
  s.description = %q{`knife batch` is a wonderful little plugin for executing commands a la `knife ssh`, but doing it in groups of `n` with a sleep between execution iterations.}

  s.rubyforge_project = "knife-batch"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  s.add_runtime_dependency "chef", ">= 11", "~> 12"
end
