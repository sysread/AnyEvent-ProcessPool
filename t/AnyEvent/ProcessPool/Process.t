use Test2::Bundle::Extended;
use AnyEvent::ProcessPool::Process;
use AnyEvent;

subtest is_running => sub{
  ok my $proc = AnyEvent::ProcessPool::Process->new, 'ctor';

  ok !$proc->is_running, '!is_running';
  ok !$proc->pid, '!pid';

  $proc->await;

  ok $proc->is_running, 'is_running';
  ok $proc->pid, 'pid';
};

subtest run => sub{
  my $proc = AnyEvent::ProcessPool::Process->new;

  ok my $async = $proc->run(sub{ 42 }), 'run';
  is $async->recv, 42, 'result';

  ok my $fail = $proc->run(sub{ die "fnord" }), 'run';
  like dies{ $fail->recv }, qr/fnord/, 'croak';
};

subtest limit => sub{
  my $proc = AnyEvent::ProcessPool::Process->new(limit => 1);

  $proc->await;
  my $pid1 = $proc->pid;
  $proc->run(sub{})->recv; # block for result

  $proc->await;
  my $pid2 = $proc->pid;
  isnt $pid1, $pid2, 'new process after limit exceeded';
  is $proc->run(sub{'fnord'})->recv, 'fnord', 'functions after worker replacement';
};

subtest 'implicit run' => sub{
  my $proc = AnyEvent::ProcessPool::Process->new;
  ok !$proc->is_running, '!is_running before call to run';
  my $async = $proc->run(sub{ 42 });
  ok $proc->is_running, 'is_running after call to run';
  is $async->recv, 42, 'expected result';
};

done_testing;
