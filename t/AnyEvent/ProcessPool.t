use Test2::Bundle::Extended;
use AnyEvent::ProcessPool::TestUtil;
use AnyEvent::ProcessPool;
use AnyEvent;
use Time::HiRes qw(time);

subtest 'basics' => sub{
  ok my $pool = AnyEvent::ProcessPool->new(limit => 2, workers => 2), 'ctor';
  ok my $async = $pool->async(sub{ 42 }), 'run';
  is $async->recv, 42, 'result';
};

subtest 'queue' => sub{
  ok my $pool = AnyEvent::ProcessPool->new(limit => 4, workers => 2), 'ctor';

  my @seq = 0 .. 10;
  my @async;

  foreach my $i (@seq) {
    push @async, $pool->async(sub{ $i });
  }

  foreach my $i (@seq) {
    is $async[$i]->recv, $i, "result $i";
  }
};

done_testing;
