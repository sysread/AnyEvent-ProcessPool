use Test2::Bundle::Extended;
use AnyEvent::ProcessPool::Task;

subtest 'execute' => sub{
  subtest 'positive path' => sub{
    ok my $task = AnyEvent::ProcessPool::Task->new(code => sub{ 42 }), 'ctor';
    is $task->execute, 1, 'execute';
    is $task->result, 42, 'result';
  };

  subtest 'negative path' => sub{
    ok my $task = AnyEvent::ProcessPool::Task->new(code => sub{ die "failed" }), 'ctor';
    is $task->execute, 0, 'execute';
    like dies{ $task->result }, qr/failed/, 'result';
  };
};

subtest 'serialization' => sub{
  ok my $task = AnyEvent::ProcessPool::Task->new(code => sub{ 42 }), 'ctor';
  ok $task->execute, 'execute';

  ok my $line = $task->encode, 'encode';
  is scalar(split(qr/[\r\n]/, $line)), 1, 'no line breaks';

  ok my $decoded = AnyEvent::ProcessPool::Task->decode($line), 'decode';
  is $decoded->result, 42, 'result';
};

done_testing;
