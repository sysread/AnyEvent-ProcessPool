use Dios {accessors => 'lvalue'};

# ABSTRACT: A multi-process pool for Perl
# PODNAME: AnyEvent::ProcessPool

class AnyEvent::ProcessPool {
  use Carp;
  use AnyEvent;
  use AnyEvent::ProcessPool::Process;
  use AnyEvent::ProcessPool::Util 'next_id';
  use Time::HiRes 'time';

  has Int       $.workers  is req;
  has Undef|Int $.max_reqs is ro;

  has @!pool     is rw;
  has @!queue    is rw;
  has %!pending  is rw;
  has %!assigned is rw;
  has %!ready    is rw;
  has $!started  is rw = 0;

  method start {
    foreach (1 .. $workers) {
      push @pool, AnyEvent::ProcessPool::Process->new(
        max_reqs => $max_reqs,
        on_task  => sub{
          my $worker = shift;
          my $id = shift @{$assigned{$worker->id}};
          push @pool, $worker;
          $ready{$id}->send;
          $self->process_pending;
        },
      );
    }

    $started = 1;
  }

  method async(Code $code --> Code) {
    $self->start unless $started;

    my $id = next_id;
    push @queue, [$id, $code];
    $ready{$id} = AE::cv;

    $self->process_pending;

    return sub{
      # Wait for task to be sent and result to be available
      $ready{$id}->recv;

      my $result = $pending{$id};

      # Clean up
      delete $pending{$id};
      delete $ready{$id};

      # Return result
      $result->();
    };
  }

  method process_pending {
    while (@queue && @pool) {
      my $worker = shift @pool;
      my $item = shift @queue;
      my ($id, $code) = @$item;
      $pending{$id} = $worker->run($code);
      $assigned{$worker->id} //= [];
      push @{$assigned{$worker->id}}, $id;
    }
  }
}

=head1 SYNOPSIS

  use AnyEvent::ProcessPool;

  my $pool = AnyEvent::ProcessPool->new(
    workers  => 8,
    max_reqs => 10,
  );

  my $result = $pool->async(sub{
    # do stuff...
  });

  if ($result eq '...') {
    # blocks until $result is populated
  }

=head1 DESCRIPTION

Executes code using a pool a forked Perl subprocesses. Supports configurable
pool size, automatically restarting processes after a configurable number of
requests, and closures (with the caveat that changes are not propagated back to
the parent process).

=head1 ATTRIBUTES

=head2 workers

Required attribute specifying the number of worker processes to launch. Must be
a positive integer.

=head2 max_reqs

Optional attribute that causes a worker process to be restarted after
performing C<max_reqs> tasks. This can be useful when calling code which may be
leaky. When unspecified or set to zero, worker processes will only be restarted
if it unexpectedly fails.

=head1 METHODS

=head2 async

Executes a task in a worker sub-process. Returns a tied variable (an instance
of C<AnyEvent::ProcessPool::Async>) that, when accessed (triggering a call to
C<FETCH>) will block until the result of execution is available.

=head1 DIAGNOSTICS

=head2 Task errors

Error messages resulting from a C<die> or C<croak> in task code executed in a
worker process are rethrown in the parent process when the "future" result is
synchronized.

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

=head1 INCOMPATIBILITIES

=head2 Perl 5.18

L<PPR> (sub-dep of L<Dios>) throws strange parsing errors when running this
module under 5.18. I have not had time to dig into them fully to determine
whether or not this is a result of a bug in C<AnyEvent::ProcessPool>, L<PPR>,
or 5.18.

=head2 Perl 5.20

Due to an apparently well-known bug in regex handling in 5.20 (which wasn't
known to me but is emitted by L<PPR>), L<PPR> (sub-dep of L<Dios>) runs
abysmally under 5.20, causing most actions to fail or hang indefinitely.

=head1 ALTERNATIVES

=over

=item L<Parallel::ForkManager>

Highly reliable, but blocking and difficult to integrate into non-blocking
code.

=item L<Coro::ProcessPool>

Similar in function, but runs only under L<Coro> (which as of 6.513 has
experimental support for 5.22).

=back

=cut

1;
