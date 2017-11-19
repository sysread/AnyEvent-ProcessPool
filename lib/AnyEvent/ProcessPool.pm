package AnyEvent::ProcessPool;
# ABSTRACT: Asynchronously runs code concurrently in a pool of perl processes

use common::sense;
use Carp;
use AnyEvent;
use AnyEvent::Util;
use AnyEvent::ProcessPool::Process;
use AnyEvent::ProcessPool::Task;
use AnyEvent::ProcessPool::Util qw(next_id cpu_count);

sub new {
  my ($class, %param) = @_;

  my $self = bless {
    workers  => $param{workers} || cpu_count,
    limit    => $param{limit},
    include  => $param{include},
    pid      => $$,
    pool     => [], # array of AE::PP::Process objects
    queue    => [], # array of [id, code] tasks
    complete => {}, # task_id => condvar: signals result to caller
    pending  => {}, # task_id => condvar: signals result internally
  }, $class;

  # Initialize workers but do not yet wait for them to be started
  if ($self->{limit}) {
    $AnyEvent::Util::MAX_FORKS = $self->{limit};
  }

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
  return unless $self;
  return unless $self->{pid} == $$;

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

sub async {
  my $self = shift;
  my $code = shift;
  my $id   = next_id;
  my $task = AnyEvent::ProcessPool::Task->new($code, [@_]);
  $self->{complete}{$id} = AE::cv;
  push @{$self->{queue}}, [$id, $task];
  $self->process_queue;
  return $self->{complete}{$id};
}

sub process_queue {
  my $self  = shift;
  my $queue = $self->{queue};
  my $pool  = $self->{pool};

  if (@$queue && @$pool) {
    my ($id, $task) = @{shift @$queue};
    my $worker = shift @$pool;

    $self->{pending}{$id} = $worker->run($task);

    $self->{pending}{$id}->cb(sub{
      my $task = shift->recv;

      if ($task->failed) {
        $self->{complete}{$id}->croak($task->result);
      } else {
        $self->{complete}{$id}->send($task->result);
      }

      delete $self->{pending}{$id};
      delete $self->{complete}{$id};

      push @{$self->{pool}}, $worker;
      $self->process_queue;
    });
  }
}

1;

=head1 SYNOPSIS

  use AnyEvent::ProcessPool;

  my $pool = AnyEvent::ProcessPool->new(
    workers => 8,
    limit   => 10,
    include => ['lib', 'some/lib/path'],
  );

  my $condvar = $pool->async(sub{
    # do task type stuff...
  });

  # Block until result is ready
  my $result = $condvar->recv;

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

=head2 include

An optional array ref of paths to add to the perl command string used to start
the sub-process worker.

=head1 METHODS

=head2 async

Executes the supplied code ref in a worker sub-process. Remaining (optional)
arguments are passed unchanged to the code ref in the worker process. Returns a
L<condvar|AnyEvent/CONDITION VARIABLES> that will block and return the task
result when C<recv> is called on it.

Alternately, the name of a task class may be supplied. The class must implement
the methods 'new' (as a constructor) and 'run'. When using a task class, the
arguments will be passed to the constructor (new) and the result of 'run' will
be returned.

  # With an anonymous subroutine
  my $cv = $pool->async(sub{ ... });

  # With a code ref
  my $cv = $pool->async(\&do_stuff);

  # With optional parameter list
  my $cv = $pool->async(sub{ ... }, $arg1, $arg2, ...);

  # With a task class
  my $cv = $pool->async('My::Task', $arg1, ...);


=head2 join

Blocks until all pending tasks have completed. This does not prevent new tasks
from being queued while waiting (for example, in the callback of an already
queued task's condvar).

=head1 PIPELINES

Pipelinelines are alternative way of using the process pool. See
L<AnyEvent::ProcessPool::Pipeline> for details.

  use AnyEvent::ProcessPool::Pipeline;

  pipeline workers => 4,
    in  { get_next_task() }
    out { do_stuff_with_result(shift->recv) };

=head1 DIAGNOSTICS

=head2 Task errors

Error messages resulting from a C<die> or C<croak> in task code executed in a
worker process are rethrown in the parent process when the condition variable's
C<recv> method is called.

=head1 CAVEATS ON MSWIN32

In addition to the usual caveats with regard to emulated forking on Windows,
the platform's poor support for pipes means resorting to a pair of TCP sockets
instead (which works but is much, much, slower). See the notes for
C<portable_socketpair> and C<fork_call> in L<AnyEvent::Util>.

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
