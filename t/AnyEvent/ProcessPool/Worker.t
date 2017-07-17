use Test2::Bundle::Extended;
use AnyEvent::ProcessPool::Worker;
use AnyEvent::ProcessPool::Task;

my $task = AnyEvent::ProcessPool::Task->new(code => sub{ 42 });

ok my $worker = AnyEvent::ProcessPool::Worker->new, 'ctor';
ok my $line = $worker->do($task->encode), 'do';
ok my $done = AnyEvent::ProcessPool::Task->decode($line), 'output decodes to task';
is $done->result, 42, 'expected result';

done_testing;
