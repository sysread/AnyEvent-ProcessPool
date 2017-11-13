package AnyEvent::ProcessPool::Task;

use strict;
use warnings;
use Carp;
use Data::Dump::Streamer;
use MIME::Base64;
use Try::Catch;

use constant READY => 1;
use constant DONE  => 2;
use constant FAIL  => 4;

sub new {
  my ($class, $code, $args) = @_;
  bless [READY, [$code, $args]], $class;
}

sub done   { $_[0][0] & DONE }
sub failed { $_[0][0] & FAIL }

sub result {
  return $_[0][1] if $_[0][0] & DONE;
  return;
}

sub execute {
  my $self = shift;

  try {
    my ($code, $args) = @{$self->[1]};
    $self->[1] = $code->(@$args);
    $self->[0] = DONE;
  }
  catch {
    $self->[0] = DONE | FAIL;
    $self->[1] = $_;
  };

  return $self->[0] & FAIL ? 0 : 1;
}

sub encode {
  my $self = shift;
  my $data = Dump($self)->Purity(1)->Declare(1)->Indent(0)->Out;
  encode_base64($data, '');
}

sub decode {
  my $class = shift;
  my $data  = decode_base64($_[0]);
  my $self  = eval "do{ $data }";
  croak "task decode error: $@" if $@;
  return $self;
}

1;
