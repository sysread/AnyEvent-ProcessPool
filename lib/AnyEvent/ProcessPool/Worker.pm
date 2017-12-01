package AnyEvent::ProcessPool::Worker;
# ABSTRACT: The task executor code run in the worker process

use v5.10;
use common::sense;
use AnyEvent::ProcessPool::Task;

sub run {
  local $| = 1;
  while (defined(my $line = <STDIN>)) {
    my $task = AnyEvent::ProcessPool::Task->decode($line);
    $task->execute;
    say $task->encode;
  }
}

1;
