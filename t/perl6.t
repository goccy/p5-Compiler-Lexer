use strict;
use warnings;
use utf8;
use 5.010000;
use Compiler::Lexer;
use Test::More;

my $codeA = q|{}/'|;
my $codeB = q|$g-f~B,'';|;

for my $code ($codeA, $codeB) {
    my $tokens = Compiler::Lexer->new->tokenize($code);
    ok(1);
}

done_testing;
