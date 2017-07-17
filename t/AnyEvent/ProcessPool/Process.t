use Test2::Bundle::Extended;
use AnyEvent::ProcessPool::Process;
use AnyEvent::ProcessPool::TestUtil;
use AnyEvent;

timed_subtest is_running => sub{
  my $cv = AE::cv;
  ok my $proc = AnyEvent::ProcessPool::Process->new(
    on_ready => sub{ $cv->send(42) }
  ), 'ctor';

  ok !$proc->is_running, '!is_running';
  ok !$proc->pid, '!pid';

  $proc->start;

  is $cv->recv, 42, 'on_ready was called';
  ok $proc->is_running, 'is_running';
  ok $proc->pid, 'pid';
};

timed_subtest run => sub{
  my $cv = AE::cv;
  my $proc = AnyEvent::ProcessPool::Process->new(on_ready => $cv);
  $proc->start;
  $cv->recv;

  ok my $async = $proc->run(sub{ 42 }), 'run';
  is $async->(), 42, 'result';

  ok my $fail = $proc->run(sub{ die "fnord" }), 'run';
  like dies{ $fail->() }, qr/fnord/, 'croak';
};

timed_subtest max_reqs => sub{
  my $cv = AE::cv;
  my $proc = AnyEvent::ProcessPool::Process->new(on_ready => $cv, max_reqs => 1);
  $proc->start;
  $cv->recv;

  my $pid1 = $proc->pid;
  $proc->run(sub{})->(); # block for result

  my $pid2 = $proc->pid;
  isnt $pid1, $pid2, 'new process after max_reqs exceeded';
  is $proc->run(sub{'fnord'})->(), 'fnord', 'functions after worker replacement';
};

timed_subtest 'implicit run' => sub{
  my $proc = AnyEvent::ProcessPool::Process->new;
  ok !$proc->is_running, '!is_running before call to run';
  my $async = $proc->run(sub{ 42 });
  ok $proc->is_running, 'is_running after call to run';
  is $async->(), 42, 'expected result';
};

done_testing;
