use strict;
use warnings;
use Data::Dumper;
use Test::More;
BEGIN { use_ok('Compiler::Lexer') };

my $tokens = Compiler::Lexer->new('')->tokenize(<<'SCRIPT');
format STDOUT =
ok @<<<<<<<
$test
.
my $hoge;
SCRIPT

subtest 'tokenize' => sub {
    is_deeply($tokens, [
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Decl,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'FormatDecl',
            'data' => 'format',
            'type' => Compiler::Lexer::TokenType::T_FormatDecl,
            'line' => 1
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Handle,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'STDOUT',
            'data' => 'STDOUT',
            'type' => Compiler::Lexer::TokenType::T_STDOUT,
            'line' => 1
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Assign,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'Assign',
            'data' => '=',
            'type' => Compiler::Lexer::TokenType::T_Assign,
            'line' => 1
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Term,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'Format',
            'data' => 'ok @<<<<<<<
$test
',
            'type' => Compiler::Lexer::TokenType::T_Format,
            'line' => 4
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Term,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'FormatEnd',
            'data' => '.',
            'type' => Compiler::Lexer::TokenType::T_FormatEnd,
            'line' => 4
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Decl,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'VarDecl',
            'data' => 'my',
            'type' => Compiler::Lexer::TokenType::T_VarDecl,
            'line' => 4
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Term,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'LocalVar',
            'data' => '$hoge',
            'type' => Compiler::Lexer::TokenType::T_LocalVar,
            'line' => 4
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_StmtEnd,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'SemiColon',
            'data' => ';',
            'type' => Compiler::Lexer::TokenType::T_SemiColon,
            'line' => 4
        }, 'Compiler::Lexer::Token' )
    ]);
};

done_testing;
