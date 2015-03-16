use strict;
use warnings;
use Compiler::Lexer;
use Test::More tests => 1;
BEGIN { use_ok('Compiler::Lexer') };
use Data::Dumper;

my $tokens = Compiler::Lexer->new('-')->tokenize('package Foo');
print Dumper $tokens;
