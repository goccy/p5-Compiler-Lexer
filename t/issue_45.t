use strict;
use warnings;
use Compiler::Lexer;
use Test::More;

Compiler::Lexer->new->tokenize('^/');

ok 1;
done_testing;
