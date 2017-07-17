package AnyEvent::ProcessPool::Async;

#ABSTRACT: A tied subref that returns the results of its evaluation on FETCH

use strict;
use warnings;
use Carp;
use parent 'Tie::Scalar';

sub TIESCALAR { bless \$_[1], $_[0] }
sub STORE { croak 'AnyEvent::ProcessPool::Async is read only' }
sub FETCH { ${$_[0]}->() }

1;
