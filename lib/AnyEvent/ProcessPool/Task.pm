use Dios {accessors => 'lvalue'};

# ABSTRACT: A multi-process pool for Perl
# PODNAME: AnyEvent::ProcessPool::Task

class AnyEvent::ProcessPool::Task {
  use Carp;
  use Data::Dump::Streamer;
  use MIME::Base64;

  has Code $.code is rw;

  method decode(Class $class: Str $line --> AnyEvent::ProcessPool::Task) {
    my $data = decode_base64($line);
    my $sub  = eval "do{ $data }";
    $@ && die $@;
    $class->new(code => $sub);
  }

  method encode(--> Str) {
    my $data = Dump($code)->Purity(1)->Declare(1)->Indent(0)->Out;
    encode_base64($data, '');
  }

  method result { $code->() }

  method execute {
    my $result = eval { $self->result };

    if ($@) {
      my $error = "$@";
      $self->code = sub{ croak $error };
      return 0;
    }
    else {
      $self->code = sub{ $result };
      return 1;
    }
  }
}

1;
