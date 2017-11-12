package AnyEvent::ProcessPool::Task;

use strict;
use warnings;
use Carp;
use Data::Dump::Streamer;
use MIME::Base64;
use Try::Catch;

sub new {
  my ($class, $arg) = @_;

  my $self = bless {code => undef}, $class;

  if (ref $arg eq 'CODE') {
    $self->{code} = $arg;
  }
  elsif (defined $arg) {
    my $data = decode_base64($arg);
    $self->{code} = eval "do{ $data }";
    $@ && die $@;
  }

  return $self;
}

sub encode {
  my $self = shift;
  return encode_base64(
    Dump($self->{code})->Purity(1)->Declare(1)->Indent(0)->Out,
    ''
  );
}

sub result {
  my $self = shift;
  return $self->{code}->();
}

sub execute {
  my $self = shift;
  my $rv = 0;

  try {
    my $result = $self->result;
    $self->{code} = sub{ $result };
    $rv = 1;
  }
  catch {
    my $error = $_;
    $self->{code} = sub{ croak $error };
  };

  return $rv;
}

1;
