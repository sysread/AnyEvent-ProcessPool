package AnyEvent::ProcessPool::Util;

# ABSTRACT: A multi-process pool for Perl

use strict;
use warnings;
use v5.10;
use parent 'Exporter';

use Data::UUID::MT;

our @EXPORT_OK = qw(
  next_id
);

sub next_id {
  state $ug = Data::UUID::MT->new(version => 4);
  state $ids = $ug->iterator;
  return $ids->();
}

1;
