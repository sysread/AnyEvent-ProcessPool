# Perl versions supported
requires  'perl', '5.014';
conflicts 'perl', '5.018'; # strange PPR conflict
conflicts 'perl', '5.020'; # regex bug

# Dios-related
requires 'Dios', '0.002011'; # fixes attr decl bug
requires 'PPR',  '0.000014'; # fixes method decl bug
requires 'Want', '0';        # undeclared sub-dep somewhere down this chain

# AnyEvent and friends
requires 'AnyEvent', '7.14';
requires 'AnyEvent::Open3::Simple', '0.86';

# Misc
requires 'Data::Dump::Streamer', '0';
requires 'Data::UUID::MT', '0';
requires 'String::Escape', '0';

# Testing
on test => sub{
  requires 'Test2::Bundle::Extended', '0';
  requires 'Test::Pod', '1.41';
};
