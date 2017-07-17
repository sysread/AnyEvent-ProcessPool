use Dios {accessors => 'lvalue'};

# ABSTRACT: A multi-process pool for Perl
# PODNAME: AnyEvent::ProcessPool::Process

class AnyEvent::ProcessPool::Process {
  use AnyEvent::Open3::Simple;
  use AnyEvent::ProcessPool::Task;
  use AnyEvent::ProcessPool::Util 'next_id';
  use AnyEvent;
  use Config;
  use String::Escape 'backslash';

  has Undef|Code|AnyEvent::CondVar $.on_ready is ro;
  has Undef|Code $.on_task is ro;
  has Int $.max_reqs is ro //= 0;
  has Str $.id is ro = next_id;

  has $!started is rw;
  has @!pending is rw;
  has $!proc is rw;
  has $!ipc is ro = AnyEvent::Open3::Simple->new(
    on_start  => sub{ $self->_on_start(@_) },
    on_stdout => sub{ $self->_on_read(@_) },
    on_stderr => sub{ warn "AnyEvent::ProcessPool::Worker: $_[1]\n" },
    on_error  => sub{ die "error launching worker process: $_[0]" },
    on_signal => sub{
      warn "worker terminated in response to signal: $_[1]";
      $self->_clear_proc;
    },
    on_fail   => sub{
      warn "worker terminated with non-zero exit status: $_[1]";
      $self->_clear_proc;
    },
  );

  method is_running { defined $proc }

  method pid { defined $proc && $proc->pid }

  method pending { scalar @pending }

  method start {
    return if $proc;
    $started = AE::cv;
    my $perl = $Config{perlpath};
    my $ext  = $Config{_exe};
    $perl .= $ext if $^O ne 'VMS' && $perl !~ /$ext$/i;
    my @inc = map { sprintf('-I%s', backslash($_)) } @_, @INC;
    my $cmd = join ' ', @inc, q(-MAnyEvent::ProcessPool::Worker -e 'AnyEvent::ProcessPool::Worker->new->run');
    $ipc->run("$perl $cmd");
  }

  method run(Code $code --> Code) {
    $self->start unless $proc;
    $started->recv;
    my $cv = AE::cv;
    push @pending, $cv;
    my $task = AnyEvent::ProcessPool::Task->new(code => $code);
    $proc->say($task->encode);
    ++$proc->user->{reqs};
    return sub{ $cv->recv };
  }

  method _clear_proc {
    return unless $proc;
    $proc->close;
    undef $proc;
  }

  method _on_start($process, $program, @args?) {
    $proc = $process;
    $proc->user({reqs => 0});
    $started->send;
    $on_ready->($self) if $on_ready;
  }

  method _on_read($process, $line) {
    my $cv = shift @pending;
    my $task = AnyEvent::ProcessPool::Task->decode($line);
    my $result = eval{ $task->result };

    if ($@) {
      $cv->croak($@);
    } else {
      $cv->send($result);
    }

    $on_task->($self) if $on_task;

    $self->_clear_proc
      if $proc
      && $max_reqs > 0
      && $proc->user->{reqs} == $max_reqs;
  }
}

1;
