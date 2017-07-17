requires 'perl'                    => 5.014;
requires 'AnyEvent'                => 0;
requires 'AnyEvent::Open3::Simple' => 0;
requires 'Data::Dump::Streamer'    => 0;
requires 'Data::UUID::MT'          => 0;
requires 'Dios'                    => 0.002003;
requires 'PPR'                     => 0.000009;
requires 'Guard'                   => 0;
requires 'String::Escape'          => 0;
requires 'Want'                    => 0;

on test => sub{
  requires 'Test2::Bundle::Extended' => 0;
  requires 'Test::Pod'               => 1.41;
};
