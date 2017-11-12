package AnyEvent::ProcessPool::Worker;
# ABSTRACT: The task executor code run in the worker process

use strict;
use warnings;
use v5.10;
require AnyEvent::ProcessPool::Task;

sub run {
  local $| = 1;
  while (defined(my $line = <STDIN>)) {
    my $task = AnyEvent::ProcessPool::Task->new($line);
    $task->execute;
    say $task->encode;
  }
}

1;
