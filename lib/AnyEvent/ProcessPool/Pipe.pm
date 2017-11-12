package AnyEvent::ProcessPool::Pipe;

use strict;
use warnings;
use AnyEvent;
use AnyEvent::ProcessPool;

sub pool (%) {
  my %param = @_;
  my $from  = delete $param{from};
  my $to    = delete $param{to};
  my $pool  = AnyEvent::ProcessPool->new(%param);

  while (defined(my $task = $from->())) {
  }
}

sub from (&) { return (from => $_[0]) }
sub to   (&) { return (to   => $_[0]) }

=cut
pool workers => 4,
  from { get_next_task() },
  to { };
=cut

1;
