use Test2::Bundle::Extended;
use AnyEvent::ProcessPool::Process;
use AnyEvent::ProcessPool::Task;
use AnyEvent;

bail_out 'OS unsupported' if $^O eq 'MSWin32';

subtest is_running => sub{
  ok my $proc = AnyEvent::ProcessPool::Process->new, 'ctor';
  ok !$proc->is_running, '!is_running';
  $proc->spawn;
  ok $proc->is_running, 'is_running';
};

subtest run => sub{
  my $proc = AnyEvent::ProcessPool::Process->new;
  ok !$proc->is_running, '!is_running';
  ok my $cv = $proc->run(AnyEvent::ProcessPool::Task->new(sub{42})), 'run';
  ok $proc->is_running, 'is_running';
  ok my $task = $cv->recv, 'recv task';
  ok $task->done, 'done';
  ok !$task->failed, '!failed';
  is $task->result, 42, 'result';
};

subtest fail => sub{
  my $proc = AnyEvent::ProcessPool::Process->new;
  ok my $cv = $proc->run(AnyEvent::ProcessPool::Task->new(sub{die "fnord"})), 'run';
  ok my $task = $cv->recv, 'recv task';
  ok $task->done, 'done';
  ok $task->failed, '!failed';
  like $task->result, qr/fnord/, 'result';
};

subtest limit => sub{
  my $proc = AnyEvent::ProcessPool::Process->new(limit => 1);

  $proc->spawn;
  my $handle = $proc->handle;

  $proc->run(AnyEvent::ProcessPool::Task->new(sub{}))->recv; # block for result
  $proc->run(AnyEvent::ProcessPool::Task->new(sub{}))->recv; # block for result

  isnt $proc->handle, $handle, 'new process after limit exceeded';
  is $proc->run(AnyEvent::ProcessPool::Task->new(sub{"fnord"}))->recv->result, 'fnord', 'functions after worker replacement';

  subtest 'queue > limit' => sub {
    my $args    = [1 .. 10];
    my $proc    = AnyEvent::ProcessPool::Process->new(limit => 2);
    my @tasks   = map{ $proc->run(AnyEvent::ProcessPool::Task->new(sub{ shift }, [$_])) } @$args;
    my @results = map{ $_->recv->result } @tasks;
    is \@results, $args;
  };
};

done_testing;
