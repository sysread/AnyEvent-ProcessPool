use Test2::Bundle::Extended;
use AnyEvent::ProcessPool::TestUtil;
use AnyEvent::ProcessPool;

timed_subtest 'basics' => sub{
  ok my $pool = AnyEvent::ProcessPool->new(max_reqs => 2, workers => 2), 'ctor';
  ok my $async = $pool->async(sub{ 42 }), 'run';
  is $async, 42, 'result';
};

timed_subtest 'queue' => sub{
  ok my $pool = AnyEvent::ProcessPool->new(max_reqs => 2, workers => 2), 'ctor';

  my @seq = 0 .. 10;
  my @async;

  foreach my $i (@seq) {
    push @async, $pool->async(sub{ $i });
  }

  foreach my $i (@seq) {
    is $async[$i], $i, "result $i";
  }
};

done_testing;
