use Dios {accessors => 'lvalue'};

# ABSTRACT: A multi-process pool for Perl
# PODNAME: AnyEvent::ProcessPool

=head1 SYNOPSIS

  use AnyEvent::ProcessPool;

  my $pool = AnyEvent::ProcessPool->new(
    workers  => 8,
    max_reqs => 10,
  );

  my $async = $pool->run(sub{
    # do stuff...
  });

  my $result = $async->();

=head1 DESCRIPTION

=cut

class AnyEvent::ProcessPool {
  use AnyEvent;
  use AnyEvent::ProcessPool::Process;
  use AnyEvent::ProcessPool::Util 'next_id';

  has Int       $.workers  is req;
  has Undef|Int $.max_reqs is ro;

  has @!pool     is rw;
  has @!queue    is rw;
  has %!pending  is rw;
  has %!assigned is rw;
  has %!ready    is rw;
  has $!started  is rw = 0;

=head1 METHODS

=head2 new

=head2 run

=cut

  method start {
    foreach (1 .. $workers) {
      push @pool, AnyEvent::ProcessPool::Process->new(
        max_reqs => $max_reqs,
        on_task  => sub{
          my $worker = shift;
          my $id = shift @{$assigned{$worker->id}}
            or die "no task id assigned to worker " . $worker->id;
          push @pool, $worker;
          $self->process_pending;
          $ready{$id}->send;
        },
      );
    }

    $started = 1;
  }

  method run(Code $code --> Code) {
    $self->start unless $started;

    my $id = next_id;
    push @queue, [$id, $code];
    $ready{$id} = AE::cv;

    $self->process_pending;

    return sub{
      $ready{$id}->recv;
      my $async = $pending{$id};
      delete $pending{$id};
      delete $ready{$id};
      $async->();
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

1;
