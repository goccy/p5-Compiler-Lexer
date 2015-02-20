use strict;
use warnings;
use Compiler::Lexer;
use Test::More;
use Data::Dumper;

my $tokens = Compiler::Lexer->new->tokenize('s///;');
print Dumper $tokens;
is_deeply($tokens, [
    bless( {
        'type' => Compiler::Lexer::TokenType::T_RegReplace,
        'name' => 'RegReplace',
        'stype' => 0,
        'data' => 's',
        'has_warnings' => 0,
        'line' => 1,
        'kind' => Compiler::Lexer::Kind::T_RegReplacePrefix,
    }, 'Compiler::Lexer::Token' ),
    bless( {
        'stype' => 0,
        'data' => '/',
        'type' => Compiler::Lexer::TokenType::T_RegDelim,
        'name' => 'RegDelim',
        'has_warnings' => 0,
        'kind' => Compiler::Lexer::Kind::T_Term,
        'line' => 1
    }, 'Compiler::Lexer::Token' ),
    bless( {
        'has_warnings' => 0,
        'name' => 'RegReplaceFrom',
        'type' => Compiler::Lexer::TokenType::T_RegReplaceFrom,
        'data' => '',
        'stype' => 0,
        'line' => 1,
        'kind' => Compiler::Lexer::Kind::T_Term
    }, 'Compiler::Lexer::Token' ),
    bless( {
        'line' => 1,
        'kind' => Compiler::Lexer::Kind::T_Term,
        'type' => Compiler::Lexer::TokenType::T_RegMiddleDelim,
        'name' => 'RegMiddleDelim',
        'data' => '/',
        'stype' => 0,
        'has_warnings' => 0
    }, 'Compiler::Lexer::Token' ),
    bless( {
        'line' => 1,
        'kind' => Compiler::Lexer::Kind::T_Term,
        'has_warnings' => 0,
        'type' => Compiler::Lexer::TokenType::T_RegReplaceTo,
        'name' => 'RegReplaceTo',
        'stype' => 0,
        'data' => ''
    }, 'Compiler::Lexer::Token' ),
    bless( {
        'line' => 1,
        'kind' => Compiler::Lexer::Kind::T_Term,
        'name' => 'RegDelim',
        'type' => Compiler::Lexer::TokenType::T_RegDelim,
        'stype' => 0,
        'data' => '/',
        'has_warnings' => 0
    }, 'Compiler::Lexer::Token' ),
    bless( {
        'has_warnings' => 0,
        'name' => 'SemiColon',
        'type' => Compiler::Lexer::TokenType::T_SemiColon,
        'stype' => 0,
        'data' => ';',
        'line' => 1,
        'kind' => Compiler::Lexer::Kind::T_StmtEnd
    }, 'Compiler::Lexer::Token' )
]);

done_testing;
