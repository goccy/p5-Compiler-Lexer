use strict;
use warnings;
use Compiler::Lexer;
use Test::More;

my $tokens = Compiler::Lexer->new->tokenize('$foo x= 3');
is_deeply($tokens, [
    bless( {
        'kind' => Compiler::Lexer::Kind::T_Term,
        'has_warnings' => 0,
        'stype' => 0,
        'name' => 'GlobalVar',
        'data' => '$foo',
        'type' => Compiler::Lexer::TokenType::T_GlobalVar,
        'line' => 1
    }, 'Compiler::Lexer::Token' ),
    bless( {
        'kind' => Compiler::Lexer::Kind::T_Assign,
        'has_warnings' => 0,
        'stype' => 0,
        'name' => 'StringMulEqual',
        'data' => 'x=',
        'type' => Compiler::Lexer::TokenType::T_StringMulEqual,
        'line' => 1
    }, 'Compiler::Lexer::Token' ),
    bless( {
        'kind' => Compiler::Lexer::Kind::T_Term,
        'has_warnings' => 0,
        'stype' => 0,
        'name' => 'Int',
        'data' => '3',
        'type' => Compiler::Lexer::TokenType::T_Int,
        'line' => 1
    }, 'Compiler::Lexer::Token' )
]);

done_testing;
