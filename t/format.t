use strict;
use warnings;
use Data::Dumper;
use Test::More;
BEGIN { use_ok('Compiler::Lexer') };

subtest 'tokenize' => sub {
    my $tokens = Compiler::Lexer->new('')->tokenize(<<'SCRIPT');
format STDOUT =
ok @<<<<<<<
$test
.
my $hoge;
SCRIPT

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

subtest 'omitted handler name' => sub {
    my $tokens = Compiler::Lexer->new('')->tokenize(<<'SCRIPT');
format =
ok @<<<<<<<
$test
.
my $hoge;
SCRIPT

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

subtest 'do not misrecognize when confusing case' => sub {
    my $tokens = Compiler::Lexer->new('')->tokenize(<<'SCRIPT');
my $foo = {
    format => 1,
};

my $bar =
  "asdf";
1;
SCRIPT

    is_deeply($tokens, [
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Decl,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'VarDecl',
            'data' => 'my',
            'type' => Compiler::Lexer::TokenType::T_VarDecl,
            'line' => 1,
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Term,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'LocalVar',
            'data' => '$foo',
            'type' => Compiler::Lexer::TokenType::T_LocalVar,
            'line' => 1,
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Assign,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'Assign',
            'data' => '=',
            'type' => Compiler::Lexer::TokenType::T_Assign,
            'line' => 1,
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Symbol,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'LeftBrace',
            'data' => '{',
            'type' => Compiler::Lexer::TokenType::T_LeftBrace,
            'line' => 1,
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Term,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'Key',
            'data' => 'format',
            'type' => Compiler::Lexer::TokenType::T_Key,
            'line' => 2,
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Operator,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'Arrow',
            'data' => '=>',
            'type' => Compiler::Lexer::TokenType::T_Arrow,
            'line' => 2,
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Term,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'Int',
            'data' => '1',
            'type' => Compiler::Lexer::TokenType::T_Int,
            'line' => 2,
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Comma,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'Comma',
            'data' => ',',
            'type' => Compiler::Lexer::TokenType::T_Comma,
            'line' => 2,
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Symbol,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'RightBrace',
            'data' => '}',
            'type' => Compiler::Lexer::TokenType::T_RightBrace,
            'line' => 3,
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_StmtEnd,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'SemiColon',
            'data' => ';',
            'type' => Compiler::Lexer::TokenType::T_SemiColon,
            'line' => 3,
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Decl,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'VarDecl',
            'data' => 'my',
            'type' => Compiler::Lexer::TokenType::T_VarDecl,
            'line' => 5,
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Term,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'LocalVar',
            'data' => '$bar',
            'type' => Compiler::Lexer::TokenType::T_LocalVar,
            'line' => 5,
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Assign,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'Assign',
            'data' => '=',
            'type' => Compiler::Lexer::TokenType::T_Assign,
            'line' => 5,
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Term,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'String',
            'data' => 'asdf',
            'type' => Compiler::Lexer::TokenType::T_String,
            'line' => 6,
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_StmtEnd,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'SemiColon',
            'data' => ';',
            'type' => Compiler::Lexer::TokenType::T_SemiColon,
            'line' => 6,
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Term,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'Int',
            'data' => '1',
            'type' => Compiler::Lexer::TokenType::T_Int,
            'line' => 7,
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_StmtEnd,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'SemiColon',
            'data' => ';',
            'type' => Compiler::Lexer::TokenType::T_SemiColon,
            'line' => 7,
        }, 'Compiler::Lexer::Token' )
    ]);
};

done_testing;
