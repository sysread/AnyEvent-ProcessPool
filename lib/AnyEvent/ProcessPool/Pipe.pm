package AnyEvent::ProcessPool::Pipe;
# ABSTRACT: A simplified, straightforward way to parallelize tasks

=head1 SYNOPSIS

  use AnyEvent::ProcessPool::Pipe;

  pipeline workers => 4,
    in {
      get_next_task();
    },
    out {
      process_result(shift);
    };

=head1 EXPORTED SUBROUTINES

=head2 pipeline

=over

=item in

=item out

=back

Launches an L<AnyEvent::ProcessPool> and immediately starts processing tasks it
receives when executing the code specified by C<in>. As results arrive (and not
necessarily in the order in which they were queued), they are delivered as
L<condition variables|AnyEvent/CONDITION VARIABLES> (ready ones, guaranteed not
to block) via the code supplied by C<out>. The pipeline will continue to run
until C<in> returns C<undef>, after which it will continue to run until all
pending results have been delivered. C<pipeline> returns the total number of
tasks processed.

Aside from C<in> and C<out>, all other arguments are passed unchanged to
L<AnyEvent::ProcessPool>'s constructor.

=cut

use strict;
use warnings;
use AnyEvent::ProcessPool;
use Try::Catch;

use parent 'Exporter';

our @EXPORT = qw(pipeline in out);

sub pipeline (%) {
  my %param = @_;
  my $in    = delete $param{in};
  my $out   = delete $param{out};
  my $pool  = AnyEvent::ProcessPool->new(%param);
  my $count = 0;

  my %pending;
  while (defined(my $task = $in->())) {
    my $cv = $pool->async($task);
    $pending{$cv} = $cv;
    $cv->cb(sub{ ++$count; $out->(shift) });
  }

  $pool->join; # wait for all tasks to complete

  return $count;
}

sub in  (&) { return (in  => $_[0]) }
sub out (&) { return (out => $_[0]) }

1;
