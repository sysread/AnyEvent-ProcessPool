use Dios {accessors => 'lvalue'};
use v5.10;

# ABSTRACT: A multi-process pool for Perl
# PODNAME: AnyEvent::ProcessPool::Worker

class AnyEvent::ProcessPool::Worker {
  use AnyEvent::ProcessPool::Task;

  method run {
    local $| = 1;
    while (defined(my $line = <STDIN>)) {
      say $self->do($line);
    }
  }

  method do(Str $line) {
    my $task = AnyEvent::ProcessPool::Task->decode($line);
    $task->execute;
    $task->encode;
  }
}

1;
