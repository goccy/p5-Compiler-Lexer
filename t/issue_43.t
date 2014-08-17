use strict;
use warnings;
use Compiler::Lexer;
use Test::More;

my $tokens = Compiler::Lexer->new->tokenize(<<'...');
/foo/m;
/bar/;
...

my %delim = map {
    ($_->data => 1)
} grep {
    $_->type == Compiler::Lexer::TokenType::T_RegDelim
} @$tokens;


is_deeply([keys %delim], ['/']);

done_testing;
