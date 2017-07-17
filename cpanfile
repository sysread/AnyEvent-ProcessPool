requires 'AnyEvent'                => 0;
requires 'AnyEvent::Open3::Simple' => 0;
requires 'Data::Dump::Streamer'    => 0;
requires 'Data::UUID::MT'          => 0;
requires 'Dios'                    => 0;

on test => sub{
  requires 'Test2::Bundle::Extended' => 0;
  requires 'Test::Pod'               => 1.41;
};
