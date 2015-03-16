use strict;
use warnings;
use Compiler::Lexer;
use Test::More;

my $results = Compiler::Lexer->new('-')->recursive_tokenize(<<'SCRIPT');
use Compiler::Lexer;

my $lexer = Compiler::Lexer->new('-');

SCRIPT

ok(scalar @{$results->{'Compiler::Lexer'}} > 0);

done_testing;
