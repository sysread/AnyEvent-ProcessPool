package AnyEvent::ProcessPool::Process;
# ABSTRACT: Supervisor for a single, forked process

use common::sense;

use Moo;
use Carp;
use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Util qw(fork_call portable_socketpair fh_nonblocking);
use AnyEvent::ProcessPool::Task;
use AnyEvent::ProcessPool::Util qw(next_id cpu_count);
use Try::Catch;

has limit   => (is => 'ro');
has handle  => (is => 'rw', clearer => 1, predicate => 'is_running');
has count   => (is => 'rw', default => sub{ 0 });
has stopped => (is => 'rw', default => sub{ 0 });

sub DEMOLISH {
  my $self = shift;
  $self->stop if $self->is_running;
}

sub stop {
  my $self = shift;
  $self->stopped(1);
  $self->handle->push_shutdown if $self->handle;
}

sub has_limit {
  my $self = shift;
  return defined $self->limit;
}

sub has_capacity {
  my $self = shift;
  return $self->is_running && (!$self->has_limit || $self->count < $self->limit);
}

sub run {
  my ($self, $task) = @_;
  return if $self->stopped;

  if (!$self->has_capacity) {
    if (my $handle = $self->handle) {
      $self->clear_handle;
      $handle->on_eof(sub{ undef $handle });
      $handle->push_shutdown;
    }

    $self->spawn;
  }

  my $cv = AE::cv;

  $self->count($self->count + 1);
  $self->handle->push_write($task->encode . "\n");
  $self->handle->push_read(line => "\n", sub{
    my ($handle, $line, $eol) = @_;
    my $task = AnyEvent::ProcessPool::Task->decode($line);
    $cv->send($task);
  });

  return $cv;
}

sub spawn {
  my $self = shift;
  return if $self->stopped;

  my ($child, $parent) = portable_socketpair;

  fh_nonblocking $child, 1;
  my $handle = AnyEvent::Handle->new(
    fh => $child,
    on_eol => sub{ warn "$$ EOL: @_" },
    on_error => sub{ warn "$$ ERROR: @_" },
  );

  my $forked = fork_call {
    close $child;
    local $| = 1;

    my $count = 0;

    while (defined(my $line = <$parent>)) {
      my $task = AnyEvent::ProcessPool::Task->decode($line);
      $task->execute;

      syswrite $parent, $task->encode . "\n";

      if ($self->has_limit && ++$count >= $self->limit) {
        break;
      }
    }
  }
  sub {
  };

  close $parent;

  $self->handle($handle);
  $self->count(0);
}

1;
