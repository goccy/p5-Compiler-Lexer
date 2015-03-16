use strict;
use warnings;
use Compiler::Lexer;
use Test::More;
use Data::Dumper;
my $tokens = Compiler::Lexer->new->tokenize('foo\'Bar;');
is_deeply($tokens, [
    bless( {
        'kind' => Compiler::Lexer::Kind::T_Namespace,
        'has_warnings' => 0,
        'stype' => 0,
        'name' => 'Namespace',
        'data' => 'foo',
        'type' => Compiler::Lexer::TokenType::T_Namespace,
        'line' => 1
    }, 'Compiler::Lexer::Token' ),
    bless( {
        'kind' => Compiler::Lexer::Kind::T_Operator,
        'has_warnings' => 0,
        'stype' => 0,
        'name' => 'NamespaceResolver',
        'data' => '\'',
        'type' => Compiler::Lexer::TokenType::T_NamespaceResolver,
        'line' => 1
    }, 'Compiler::Lexer::Token' ),
    bless( {
        'kind' => Compiler::Lexer::Kind::T_Namespace,
        'has_warnings' => 0,
        'stype' => 0,
        'name' => 'Namespace',
        'data' => 'Bar',
        'type' => Compiler::Lexer::TokenType::T_Namespace,
        'line' => 1
    }, 'Compiler::Lexer::Token' ),
    bless( {
        'kind' => Compiler::Lexer::Kind::T_StmtEnd,
        'has_warnings' => 0,
        'stype' => 0,
        'name' => 'SemiColon',
        'data' => ';',
        'type' => Compiler::Lexer::TokenType::T_SemiColon,
        'line' => 1
    }, 'Compiler::Lexer::Token' )
]);

done_testing;
