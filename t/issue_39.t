use strict;
use warnings;
use Compiler::Lexer;
use Test::More;

my $src = "( sub { /!/ }, '//' )";
my $lexer = Compiler::Lexer->new('-');
my $tokens = $lexer->tokenize($src);

my @dor = grep { $_->name eq 'DefaultOperator' && $_->data eq '//' } @$tokens;
is 0+@dor, 0;
done_testing;
