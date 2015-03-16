use strict;
use warnings;
use Compiler::Lexer;
use Test::More;
use Data::Dumper;

my $tokens  = Compiler::Lexer->new->tokenize('$x->y()->z');
my @methods = map { $_->data } grep { $_->type == Compiler::Lexer::TokenType::T_Method } @$tokens;

is $methods[0], 'y';
is $methods[1], 'z';

done_testing;

