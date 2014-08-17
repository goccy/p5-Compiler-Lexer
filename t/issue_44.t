use strict;
use warnings;
use Compiler::Lexer;
use Test::More;
use Data::Dumper;

my $tokens = Compiler::Lexer->new->tokenize('not /\d/');
is_deeply($tokens, [
    bless( {
        'kind' => Compiler::Lexer::Kind::T_SingleTerm,
        'has_warnings' => 0,
        'stype' => 0,
        'name' => 'AlphabetNot',
        'data' => 'not',
        'type' => Compiler::Lexer::TokenType::T_AlphabetNot,
        'line' => 1
    }, 'Compiler::Lexer::Token' ),
    bless( {
        'kind' => Compiler::Lexer::Kind::T_Term,
        'has_warnings' => 0,
        'stype' => 0,
        'name' => 'RegDelim',
        'data' => '/',
        'type' => Compiler::Lexer::TokenType::T_RegDelim,
        'line' => 1
    }, 'Compiler::Lexer::Token' ),
    bless( {
        'kind' => Compiler::Lexer::Kind::T_Term,
        'has_warnings' => 0,
        'stype' => 0,
        'name' => 'RegExp',
        'data' => '\\d',
        'type' => Compiler::Lexer::TokenType::T_RegExp,
        'line' => 1
    }, 'Compiler::Lexer::Token' ),
    bless( {
        'kind' => Compiler::Lexer::Kind::T_Term,
        'has_warnings' => 0,
        'stype' => 0,
        'name' => 'RegDelim',
        'data' => '/',
        'type' => Compiler::Lexer::TokenType::T_RegDelim,
        'line' => 1
    }, 'Compiler::Lexer::Token' )
]);

done_testing;
