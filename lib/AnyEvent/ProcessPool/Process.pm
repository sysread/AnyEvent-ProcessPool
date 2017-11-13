# ABSTRACT: Manages an individual worker process
package AnyEvent::ProcessPool::Process {
  use strict;
  use warnings;
  use Config;
  use AnyEvent;
  use AnyEvent::Open3::Simple;
  use AnyEvent::ProcessPool::Task;
  use AnyEvent::ProcessPool::Util 'next_id';
  use String::Escape 'backslash';
  use Try::Catch;

  my $perl = $Config{perlpath};
  my $ext  = $Config{_exe};
  $perl .= $ext if $^O ne 'VMS' && $perl !~ /$ext$/i;
  my @inc = map { sprintf('-I%s', backslash($_)) } @_, @INC;
  my $cmd = join ' ', @inc, q(-MAnyEvent::ProcessPool::Worker -e 'AnyEvent::ProcessPool::Worker::run()');

  sub new {
    my ($class, %param) = @_;
    return bless {
      id      => next_id,
      limit   => $param{limit},
      started => undef,
      process => undef,
      ps      => undef,
      pending => [],
    }, $class;
  }

  sub DESTROY {
    my $self = shift;
    $self->{ps}->close if $self->{ps};
    if (ref $self->{pending}) {
      foreach my $cv (@{$self->{pending}}) {
        if ($cv) {
          $cv->croak('AnyEvent::ProcessPool::Process went out of scope with pending tasks');
        }
      }
    }
  }

  sub pid {
    my $self = shift;
    return $self->{ps}->pid if $self->is_running;
  }

  sub is_running {
    my $self = shift;
    return defined $self->{started}
        && $self->{started}->ready;
  }

  sub await {
    my $self = shift;
    $self->start unless $self->is_running;
    $self->{started}->recv;
  }

  sub stop {
    my $self = shift;
    if (defined $self->{process}) {
      $self->{ps}->close;
      undef $self->{started};
      undef $self->{process};
      undef $self->{ps};
    }
  }

  sub start {
    my $self = shift;
    $self->{started} = AE::cv;
    $self->{process} = AnyEvent::Open3::Simple->new(
      on_start => sub{
        $self->{started}->send;
      },
      on_stdout => sub{
        my ($ps, $line) = @_;
        my $task = AnyEvent::ProcessPool::Task->decode($line);
        my $cv = shift @{$self->{pending}};
        $cv->send($task);

        if ($self->{limit} && $ps->user->{reqs} <= 0) {
          $self->stop;
        }
      },
      on_stderr => sub{
        warn "AnyEvent::ProcessPool::Worker: $_[1]\n";
      },
      on_error => sub{
        die "error launching worker process: $_[0]";
      },
      on_signal => sub{
        warn "worker terminated in response to signal: $_[1]";
        $self->stop;
      },
      on_fail => sub{
        warn "worker terminated with non-zero exit status: $_[1]";
        $self->stop;
      },
    );

    $self->{process}->run("$perl $cmd", sub{
      my $ps = shift;
      $ps->user({reqs => $self->{limit}}) if $self->{limit};
      $self->{ps} = $ps;
    });
  }

  sub run {
    my ($self, $task) = @_;
    $self->await;

    my $cv = AE::cv;
    push @{$self->{pending}}, $cv;

    $self->{ps}->say($task->encode);
    --$self->{ps}->user->{reqs} if $self->{limit};

    return $cv;
  }

  1;
}
