package AnyEvent::ProcessPool::TestUtil;

use strict;
use warnings;
use parent 'Exporter';
use AnyEvent;
use AnyEvent::Util;
use Test2::Bundle::Extended;

our @EXPORT = qw(
  timed_subtest
);

sub timed_subtest {
  my $name    = shift;
  my $code    = pop;
  my $timeout = shift || 10;
  my $timed_out;

  subtest "$name (${timeout}s timeout)" => sub {
    eval {
      local $SIG{ALRM} = sub{
        alarm 0;
        die "alarm\n"
      };

      alarm $timeout;
      $code->();
      alarm 0;
    };

    if ($@) {
      die unless $@ eq "alarm\n";
      note "Failsafe timeout triggered for subtest '$name' after $timeout seconds";
      $timed_out = 1;
    }

    ok !$timed_out, "failsafe timeout not reached";
  };
}

1;
