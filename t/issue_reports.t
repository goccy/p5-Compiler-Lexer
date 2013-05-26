use strict;
use warnings;
use Data::Dumper;
use Test::More;
BEGIN { use_ok('Compiler::Lexer') };

my $tokens = Compiler::Lexer->new('')->tokenize(<<'SCRIPT');
%-;
%+;
@-;
@+;
$-{a};
$+{a};
@-{a};
@+{a};
SCRIPT

subtest 'tokenize' => sub {
    is_deeply($$tokens, [
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Term,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'GlobalHashVar',
            'data' => '%-',
            'type' => Compiler::Lexer::TokenType::T_GlobalHashVar,
            'line' => 1
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_StmtEnd,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'SemiColon',
            'data' => ';',
            'type' => Compiler::Lexer::TokenType::T_SemiColon,
            'line' => 1
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Term,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'GlobalHashVar',
            'data' => '%+',
            'type' => Compiler::Lexer::TokenType::T_GlobalHashVar,
            'line' => 2
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_StmtEnd,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'SemiColon',
            'data' => ';',
            'type' => Compiler::Lexer::TokenType::T_SemiColon,
            'line' => 2
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Term,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'GlobalArrayVar',
            'data' => '@-',
            'type' => Compiler::Lexer::TokenType::T_GlobalArrayVar,
            'line' => 3
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_StmtEnd,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'SemiColon',
            'data' => ';',
            'type' => Compiler::Lexer::TokenType::T_SemiColon,
            'line' => 3
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Term,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'GlobalArrayVar',
            'data' => '@+',
            'type' => Compiler::Lexer::TokenType::T_GlobalArrayVar,,
            'line' => 4
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_StmtEnd,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'SemiColon',
            'data' => ';',
            'type' => Compiler::Lexer::TokenType::T_SemiColon,
            'line' => 4
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Term,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'SpecificValue',
            'data' => '$-',
            'type' => Compiler::Lexer::TokenType::T_SpecificValue,
            'line' => 5
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Symbol,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'LeftBrace',
            'data' => '{',
            'type' => Compiler::Lexer::TokenType::T_LeftBrace,
            'line' => 5
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Term,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'Key',
            'data' => 'a',
            'type' => Compiler::Lexer::TokenType::T_Key,
            'line' => 5
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Symbol,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'RightBrace',
            'data' => '}',
            'type' => Compiler::Lexer::TokenType::T_RightBrace,
            'line' => 5
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_StmtEnd,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'SemiColon',
            'data' => ';',
            'type' => Compiler::Lexer::TokenType::T_SemiColon,
            'line' => 5
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Term,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'SpecificValue',
            'data' => '$+',
            'type' => Compiler::Lexer::TokenType::T_SpecificValue,
            'line' => 6
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Symbol,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'LeftBrace',
            'data' => '{',
            'type' => Compiler::Lexer::TokenType::T_LeftBrace,
            'line' => 6
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Term,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'Key',
            'data' => 'a',
            'type' => Compiler::Lexer::TokenType::T_Key,
            'line' => 6
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Symbol,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'RightBrace',
            'data' => '}',
            'type' => Compiler::Lexer::TokenType::T_RightBrace,
            'line' => 6
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_StmtEnd,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'SemiColon',
            'data' => ';',
            'type' => Compiler::Lexer::TokenType::T_SemiColon,
            'line' => 6
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Term,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'ArrayVar',
            'data' => '@-',
            'type' => Compiler::Lexer::TokenType::T_ArrayVar,
            'line' => 7
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Symbol,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'LeftBrace',
            'data' => '{',
            'type' => Compiler::Lexer::TokenType::T_LeftBrace,
            'line' => 7
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Term,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'Key',
            'data' => 'a',
            'type' => Compiler::Lexer::TokenType::T_Key,
            'line' => 7
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Symbol,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'RightBrace',
            'data' => '}',
            'type' => Compiler::Lexer::TokenType::T_RightBrace,
            'line' => 7
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_StmtEnd,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'SemiColon',
            'data' => ';',
            'type' => Compiler::Lexer::TokenType::T_SemiColon,
            'line' => 7
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Term,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'ArrayVar',
            'data' => '@+',
            'type' => Compiler::Lexer::TokenType::T_ArrayVar,
            'line' => 8
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Symbol,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'LeftBrace',
            'data' => '{',
            'type' => Compiler::Lexer::TokenType::T_LeftBrace,
            'line' => 8
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Term,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'Key',
            'data' => 'a',
            'type' => Compiler::Lexer::TokenType::T_Key,
            'line' => 8
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Symbol,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'RightBrace',
            'data' => '}',
            'type' => Compiler::Lexer::TokenType::T_RightBrace,
            'line' => 8
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_StmtEnd,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'SemiColon',
            'data' => ';',
            'type' => Compiler::Lexer::TokenType::T_SemiColon,
            'line' => 8
        }, 'Compiler::Lexer::Token' )
    ]);
};

done_testing;
