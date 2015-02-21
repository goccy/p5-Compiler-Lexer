use strict;
use warnings;
use Compiler::Lexer;
use Test::More;

my $tokens = Compiler::Lexer->new->tokenize('$foo-1');
is_deeply($tokens, [
    bless( {
        'line' => 1,
        'kind' => Compiler::Lexer::Kind::T_Term,
        'name' => 'GlobalVar',
        'type' => Compiler::Lexer::TokenType::T_GlobalVar,
        'has_warnings' => 0,
        'stype' => 0,
        'data' => '$foo'
    }, 'Compiler::Lexer::Token' ),
    bless( {
        'line' => 1,
        'kind' => Compiler::Lexer::Kind::T_Operator,
        'name' => 'Sub',
        'type' => Compiler::Lexer::TokenType::T_Sub,
        'stype' => 0,
        'has_warnings' => 0,
        'data' => '-'
    }, 'Compiler::Lexer::Token' ),
    bless( {
        'has_warnings' => 0,
        'stype' => 0,
        'data' => '1',
        'line' => 1,
        'type' => Compiler::Lexer::TokenType::T_Int,
        'kind' => Compiler::Lexer::Kind::T_Term,
        'name' => 'Int'
    }, 'Compiler::Lexer::Token' )
]);

done_testing;
