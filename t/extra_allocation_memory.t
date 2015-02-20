use strict;
use warnings;
use Compiler::Lexer;
use Test::More;

subtest 'run without SEGV' => sub {
    my $lexer  = Compiler::Lexer->new({
        extra_allocation_memory_size => 1,
    });
    my $tokens = $lexer->tokenize('s///;');
    is_deeply($tokens, [
        bless( {
            'kind' => Compiler::Lexer::Kind::T_RegReplacePrefix,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'RegReplace',
            'data' => 's',
            'type' => Compiler::Lexer::TokenType::T_RegReplace,
            'line' => 1,
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Term,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'RegDelim',
            'data' => '/',
            'type' => Compiler::Lexer::TokenType::T_RegDelim,
            'line' => 1,
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Term,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'RegReplaceFrom',
            'data' => '',
            'type' => Compiler::Lexer::TokenType::T_RegReplaceFrom,
            'line' => 1,
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Term,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'RegMiddleDelim',
            'data' => '/',
            'type' => Compiler::Lexer::TokenType::T_RegMiddleDelim,
            'line' => 1,
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Term,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'RegReplaceTo',
            'data' => '',
            'type' => Compiler::Lexer::TokenType::T_RegReplaceTo,
            'line' => 1,
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Term,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'RegDelim',
            'data' => '/',
            'type' => Compiler::Lexer::TokenType::T_RegDelim,
            'line' => 1,
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_StmtEnd,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'SemiColon',
            'data' => ';',
            'type' => Compiler::Lexer::TokenType::T_SemiColon,
            'line' => 1,
        }, 'Compiler::Lexer::Token' )
    ]);
};

done_testing;

