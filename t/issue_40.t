use strict;
use warnings;
use Compiler::Lexer;
use Test::More;
use Data::Dumper;

my $tokens = Compiler::Lexer->new->tokenize("'' / 1");
is_deeply($tokens, [
    bless( {
        'kind' => Compiler::Lexer::Kind::T_Term,
        'has_warnings' => 0,
        'stype' => 0,
        'name' => 'RawString',
        'data' => '',
        'type' => Compiler::Lexer::TokenType::T_RawString,
        'line' => 1
    }, 'Compiler::Lexer::Token' ),
    bless( {
        'kind' => Compiler::Lexer::Kind::T_Operator,
        'has_warnings' => 0,
        'stype' => 0,
        'name' => 'Div',
        'data' => '/',
        'type' => Compiler::Lexer::TokenType::T_Div,
        'line' => 1
    }, 'Compiler::Lexer::Token' ),
    bless( {
        'kind' => Compiler::Lexer::Kind::T_Term,
        'has_warnings' => 0,
        'stype' => 0,
        'name' => 'Int',
        'data' => '1',
        'type' => Compiler::Lexer::TokenType::T_Int,
        'line' => 1
    }, 'Compiler::Lexer::Token' )
]);

done_testing;
