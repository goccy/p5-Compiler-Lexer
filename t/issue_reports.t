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
            'kind' => 21,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'GlobalHashVar',
            'data' => '%-',
            'type' => 181,
            'line' => 1
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => 26,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'SemiColon',
            'data' => ';',
            'type' => 99,
            'line' => 1
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => 21,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'GlobalHashVar',
            'data' => '%+',
            'type' => 181,
            'line' => 2
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => 26,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'SemiColon',
            'data' => ';',
            'type' => 99,
            'line' => 2
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => 21,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'GlobalArrayVar',
            'data' => '@-',
            'type' => 180,
            'line' => 3
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => 26,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'SemiColon',
            'data' => ';',
            'type' => 99,
            'line' => 3
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => 21,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'GlobalArrayVar',
            'data' => '@+',
            'type' => 180,
            'line' => 4
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => 26,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'SemiColon',
            'data' => ';',
            'type' => 99,
            'line' => 4
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => 21,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'SpecificValue',
            'data' => '$-',
            'type' => 129,
            'line' => 5
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => 27,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'LeftBrace',
            'data' => '{',
            'type' => 102,
            'line' => 5
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => 21,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'Key',
            'data' => 'a',
            'type' => 114,
            'line' => 5
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => 27,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'RightBrace',
            'data' => '}',
            'type' => 103,
            'line' => 5
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => 26,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'SemiColon',
            'data' => ';',
            'type' => 99,
            'line' => 5
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => 21,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'SpecificValue',
            'data' => '$+',
            'type' => 129,
            'line' => 6
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => 27,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'LeftBrace',
            'data' => '{',
            'type' => 102,
            'line' => 6
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => 21,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'Key',
            'data' => 'a',
            'type' => 114,
            'line' => 6
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => 27,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'RightBrace',
            'data' => '}',
            'type' => 103,
            'line' => 6
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => 26,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'SemiColon',
            'data' => ';',
            'type' => 99,
            'line' => 6
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => 21,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'ArrayVar',
            'data' => '@-',
            'type' => 159,
            'line' => 7
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => 27,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'LeftBrace',
            'data' => '{',
            'type' => 102,
            'line' => 7
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => 21,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'Key',
            'data' => 'a',
            'type' => 114,
            'line' => 7
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => 27,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'RightBrace',
            'data' => '}',
            'type' => 103,
            'line' => 7
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => 26,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'SemiColon',
            'data' => ';',
            'type' => 99,
            'line' => 7
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => 21,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'ArrayVar',
            'data' => '@+',
            'type' => 159,
            'line' => 8
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => 27,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'LeftBrace',
            'data' => '{',
            'type' => 102,
            'line' => 8
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => 21,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'Key',
            'data' => 'a',
            'type' => 114,
            'line' => 8
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => 27,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'RightBrace',
            'data' => '}',
            'type' => 103,
            'line' => 8
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => 26,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'SemiColon',
            'data' => ';',
            'type' => 99,
            'line' => 8
        }, 'Compiler::Lexer::Token' )
    ]);
};

done_testing;
