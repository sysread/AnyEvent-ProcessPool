package AnyEvent::ProcessPool::Pipe;
# ABSTRACT: (not finished)

use strict;
use warnings;
use AnyEvent;
use AnyEvent::ProcessPool;

sub pool (%) {
  my %param = @_;
  my $in    = delete $param{in};
  my $out   = delete $param{out};
  my $pool  = AnyEvent::ProcessPool->new(%param);

  while (defined(my $task = $in->())) {
  }
}

sub in  (&) { return (in  => $_[0]) }
sub out (&) { return (out => $_[0]) }

=cut
pool workers => 4,
  from { get_next_task() },
  to { };
=cut

1;
