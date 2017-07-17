use Test2::Bundle::Extended;
use AnyEvent::ProcessPool::Async;

my $fetch = sub{ 42 };

ok tie(my $async, 'AnyEvent::ProcessPool::Async', $fetch), 'ctor';
is $async, 42, 'first FETCH';
is $async, 42, 'second FETCH';
like dies{ $async = 10 }, qr/AnyEvent::ProcessPool::Async is read only/, 'fail on set';

done_testing;
