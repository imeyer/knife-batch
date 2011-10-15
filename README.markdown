# knife batch

`knife batch` is a wonderful little plugin for executing commands a la `knife ssh`, but doing it in groups of `n` with a sleep between execution iterations.

# Installation

`gem install knife-batch`

# Usage

`knife batch` works exactly like `knife ssh` but with a couple of additional options.
`knife batch "role:cluster" "whoami" -B 10 -W 5` will execute `whoami` against 10 servers with a sleep of 5 seconds in between.

`-B INTEGER` defines how many servers at max will be batched.
`-W INTEGER` defines the time to sleep in between executions.