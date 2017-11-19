requires 'perl',                 '5.010';
requires 'AnyEvent',             '7.14';
requires 'Carp',                 '0';
requires 'Class::Load',          '0';
requires 'Data::Dump::Streamer', '0';
requires 'Data::UUID::MT',       '0';
requires 'Exporter',             '0';
requires 'MIME::Base64',         '0';
requires 'PadWalker',            '2.3';
requires 'Try::Catch',           '0';
requires 'common::sense',        '3.74';
requires 'parent',               '0';

on test => sub{
  requires 'Test2::Bundle::Extended', '0';
  requires 'Test::Pod', '1.41';
};
