package AnyEvent::ProcessPool;
# ABSTRACT: Asynchronously runs code concurrently in a pool of perl processes

=head1 SYNOPSIS

  use AnyEvent::ProcessPool;

  my $pool = AnyEvent::ProcessPool->new(
    workers => 8,
    limit   => 10,
  );

  my $condvar = $pool->async(sub{
    # do task type stuff...
  });

  # Block until result is ready
  my $result = $condvar->recv;

  if ($result eq '...') {
    ...
  }

=head1 DESCRIPTION

Executes code using a pool a forked Perl subprocesses. Supports configurable
pool size, automatically restarting processes after a configurable number of
requests, and closures (with the caveat that changes are not propagated back to
the parent process).

=head1 CONSTRUCTOR

=head2 workers

Required attribute specifying the number of worker processes to launch.
Defaults to the number of CPUs.

=head2 limit

Optional attribute that causes a worker process to be restarted after
performing C<limit> tasks. This can be useful when calling code which may be
leaky. When unspecified or set to zero, worker processes will only be restarted
if it unexpectedly fails.

=head1 METHODS

=head2 async

Executes the supplied code ref in a worker sub-process. Returns a
L<condvar|AnyEvent/CONDITION VARIABLES> that will block and return the task
result when C<recv> is called on it.

=head2 join

Blocks until all pending tasks have completed.

=head1 DIAGNOSTICS

=head2 Task errors

Error messages resulting from a C<die> or C<croak> in task code executed in a
worker process are rethrown in the parent process when the condition variable's
C<recv> method is called.

=head2 "AnyEvent::ProcessPool::Worker: ..." (warning)

When a worker sub-process emits output to C<STDERR>, the process pool warns
the message out to its own C<STDERR>.

=head2 "error launching worker process: ..."

Thrown when a worker sub-process failed to launch due to an execution error.

=head2 "worker terminated in response to signal: ..."

Thrown when a worker sub-process exits as a result of a signal received.

=head2 "worker terminated with non-zero exit status: ..."

Thrown when a worker sub-process terminates with a non-zero exit code. The
worker will be automatically restarted.

=head1 SEE ALSO

=over

=item L<Parallel::ForkManager>

Highly reliable, but somewhat arcane, blocking, and can be tricky to integrate
into non-blocking code.

=item L<Coro::ProcessPool>

Similar in function, but runs only under L<Coro> (which as of 6.513 has
experimental support for 5.22).

=back

=cut

use strict;
use warnings;
use Carp;
use AnyEvent;
use AnyEvent::ProcessPool::Process;
use AnyEvent::ProcessPool::Util qw(next_id cpu_count);

sub new {
  my ($class, %param) = @_;

  my $self = bless {
    workers  => $param{workers} || cpu_count,
    limit    => $param{limit},
    pool     => [], # array of AE::PP::Process objects
    queue    => [], # array of [id, code] tasks
    complete => {}, # task_id => condvar: signals result to caller
    pending  => {}, # task_id => condvar: signals result internally
  }, $class;

  # Initialize workers but do not yet wait for them to be started
  foreach (1 .. $self->{workers}) {
    my $worker = AnyEvent::ProcessPool::Process->new(limit => $self->{limit});
    push @{$self->{pool}}, $worker;
  }

  return $self;
}

sub join {
  my $self = shift;
  foreach my $task_id (keys %{$self->{complete}}) {
    if (my $cv = $self->{complete}{$task_id}) {
      $cv->recv;
    }
  }
}

sub DESTROY {
  my ($self, $global) = @_;

  if ($self) {
    # Unblock watchers for any remaining pending tasks
    if (ref $self->{pending}) {
      foreach my $cv (values %{$self->{pending}}) {
        $cv->croak('AnyEvent::ProcessPool destroyed with pending tasks remaining');
      }
    }

    # Terminate any workers still alive
    if (ref $self->{pool}) {
      foreach my $worker (@{$self->{pool}}) {
        $worker->stop if $worker;
      }
    }
  }
}

sub async {
  my ($self, $code) = @_;
  my $id = next_id;
  $self->{complete}{$id} = AE::cv;
  push @{$self->{queue}}, [$id, $code];
  $self->process_queue;
  return $self->{complete}{$id};
}

sub process_queue {
  my $self  = shift;
  my $queue = $self->{queue};
  my $pool  = $self->{pool};

  while (@$queue && @$pool) {
    my ($id, $code) = @{shift @$queue};
    my $worker = shift @$pool;

    $self->{pending}{$id} = $worker->run($code);

    $self->{pending}{$id}->cb(sub{
      $self->{complete}{$id}->send(shift->recv);
      delete $self->{pending}{$id};
      delete $self->{complete}{$id};
      push @$pool, $worker;
      $self->process_queue;
    });
  }
}

1;
