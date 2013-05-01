use strict;
use warnings;
use Test::More;
BEGIN {
    use_ok('Compiler::Lexer');
}
my $script =<<'SCRIPT';
#!./perl

use strict;
use warnings;

require q(./test.pl); plan(tests => 12);

=pod

This example is taken from: http://rt.cpan.org/Public/Bug/Display.html?id=20879

               ---     ---     ---
Level 5     8 | A | 9 | B | A | C |    (More General)
               ---     ---     ---       V
                  \     |     /          |
                   \    |    /           |
                    \   |   /            |
                     \  |  /             |
                       ---               |
Level 4             7 | D |              |
                       ---               |
                      /   \              |
                     /     \             |
                  ---       ---          |
Level 3        4 | G |   6 | E |         |
                  ---       ---          |
                   |         |           |
                   |         |           |
                  ---       ---          |
Level 2        3 | H |   5 | F |         |
                  ---       ---          |
                      \   /  |           |
                       \ /   |           |
                        \    |           |
                       / \   |           |
                      /   \  |           |
                  ---       ---          |
Level 1        1 | J |   2 | I |         |
                  ---       ---          |
                    \       /            |
                     \     /             |
                       ---               v
Level 0             0 | K |            (More Specialized)
                       ---


0123456789A
KJIHGFEDABC

=cut

{
    package Test::A; use mro 'c3';

    package Test::B; use mro 'c3';

    package Test::C; use mro 'c3';

    package Test::D; use mro 'c3';
    use base qw/Test::A Test::B Test::C/;

    package Test::E; use mro 'c3';
    use base qw/Test::D/;

    package Test::F; use mro 'c3';
    use base qw/Test::E/;
    sub testmeth { "wrong" }

    package Test::G; use mro 'c3';
    use base qw/Test::D/;

    package Test::H; use mro 'c3';
    use base qw/Test::G/;

    package Test::I; use mro 'c3';
    use base qw/Test::H Test::F/;
    sub testmeth { "right" }

    package Test::J; use mro 'c3';
    use base qw/Test::F/;

    package Test::K; use mro 'c3';
    use base qw/Test::J Test::I/;
    sub testmeth { shift->next::method }
}

ok(eq_array(
    mro::get_linear_isa('Test::A'),
    [ qw(Test::A) ]
), '... got the right C3 merge order for Test::A');

ok(eq_array(
    mro::get_linear_isa('Test::B'),
    [ qw(Test::B) ]
), '... got the right C3 merge order for Test::B');

ok(eq_array(
    mro::get_linear_isa('Test::C'),
    [ qw(Test::C) ]
), '... got the right C3 merge order for Test::C');

ok(eq_array(
    mro::get_linear_isa('Test::D'),
    [ qw(Test::D Test::A Test::B Test::C) ]
), '... got the right C3 merge order for Test::D');

ok(eq_array(
    mro::get_linear_isa('Test::E'),
    [ qw(Test::E Test::D Test::A Test::B Test::C) ]
), '... got the right C3 merge order for Test::E');

ok(eq_array(
    mro::get_linear_isa('Test::F'),
    [ qw(Test::F Test::E Test::D Test::A Test::B Test::C) ]
), '... got the right C3 merge order for Test::F');

ok(eq_array(
    mro::get_linear_isa('Test::G'),
    [ qw(Test::G Test::D Test::A Test::B Test::C) ]
), '... got the right C3 merge order for Test::G');

ok(eq_array(
    mro::get_linear_isa('Test::H'),
    [ qw(Test::H Test::G Test::D Test::A Test::B Test::C) ]
), '... got the right C3 merge order for Test::H');

ok(eq_array(
    mro::get_linear_isa('Test::I'),
    [ qw(Test::I Test::H Test::G Test::F Test::E Test::D Test::A Test::B Test::C) ]
), '... got the right C3 merge order for Test::I');

ok(eq_array(
    mro::get_linear_isa('Test::J'),
    [ qw(Test::J Test::F Test::E Test::D Test::A Test::B Test::C) ]
), '... got the right C3 merge order for Test::J');

ok(eq_array(
    mro::get_linear_isa('Test::K'),
    [ qw(Test::K Test::J Test::I Test::H Test::G Test::F Test::E Test::D Test::A Test::B Test::C) ]
), '... got the right C3 merge order for Test::K');

is(Test::K->testmeth(), "right", 'next::method working ok');

SCRIPT

subtest 'tokenize' => sub {
    my $tokens = Compiler::Lexer->new('')->tokenize($script);
    is_deeply($$tokens, [
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 3
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'strict',
                   'type' => 88,
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
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 4
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'warnings',
                   'type' => 88,
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
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RequireDecl',
                   'data' => 'require',
                   'type' => 65,
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegQuote',
                   'data' => 'q',
                   'type' => 137,
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '(',
                   'type' => 143,
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => './test.pl',
                   'type' => 172,
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => ')',
                   'type' => 143,
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
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'plan',
                   'type' => 114,
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'tests',
                   'type' => 114,
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'type' => 116,
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Int',
                   'data' => '12',
                   'type' => 161,
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
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
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 52
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Package',
                   'data' => 'package',
                   'type' => 120,
                   'line' => 53
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'Test',
                   'type' => 119,
                   'line' => 53
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 53
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'A',
                   'type' => 119,
                   'line' => 53
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 53
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 53
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'mro',
                   'type' => 88,
                   'line' => 53
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'c3',
                   'type' => 164,
                   'line' => 53
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 53
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Package',
                   'data' => 'package',
                   'type' => 120,
                   'line' => 55
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'Test',
                   'type' => 119,
                   'line' => 55
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 55
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'B',
                   'type' => 119,
                   'line' => 55
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 55
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 55
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'mro',
                   'type' => 88,
                   'line' => 55
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'c3',
                   'type' => 164,
                   'line' => 55
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 55
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Package',
                   'data' => 'package',
                   'type' => 120,
                   'line' => 57
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'Test',
                   'type' => 119,
                   'line' => 57
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 57
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'C',
                   'type' => 119,
                   'line' => 57
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 57
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 57
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'mro',
                   'type' => 88,
                   'line' => 57
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'c3',
                   'type' => 164,
                   'line' => 57
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 57
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Package',
                   'data' => 'package',
                   'type' => 120,
                   'line' => 59
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'Test',
                   'type' => 119,
                   'line' => 59
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 59
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'D',
                   'type' => 119,
                   'line' => 59
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 59
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 59
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'mro',
                   'type' => 88,
                   'line' => 59
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'c3',
                   'type' => 164,
                   'line' => 59
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 59
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 60
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'base',
                   'type' => 88,
                   'line' => 60
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegList',
                   'data' => 'qw',
                   'type' => 139,
                   'line' => 60
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 60
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => 'Test::A Test::B Test::C',
                   'type' => 172,
                   'line' => 60
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 60
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 60
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Package',
                   'data' => 'package',
                   'type' => 120,
                   'line' => 62
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'Test',
                   'type' => 119,
                   'line' => 62
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 62
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'E',
                   'type' => 119,
                   'line' => 62
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 62
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 62
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'mro',
                   'type' => 88,
                   'line' => 62
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'c3',
                   'type' => 164,
                   'line' => 62
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 62
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 63
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'base',
                   'type' => 88,
                   'line' => 63
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegList',
                   'data' => 'qw',
                   'type' => 139,
                   'line' => 63
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 63
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => 'Test::D',
                   'type' => 172,
                   'line' => 63
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 63
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 63
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Package',
                   'data' => 'package',
                   'type' => 120,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'Test',
                   'type' => 119,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'F',
                   'type' => 119,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'mro',
                   'type' => 88,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'c3',
                   'type' => 164,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 66
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'base',
                   'type' => 88,
                   'line' => 66
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegList',
                   'data' => 'qw',
                   'type' => 139,
                   'line' => 66
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 66
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => 'Test::E',
                   'type' => 172,
                   'line' => 66
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 66
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 66
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'FunctionDecl',
                   'data' => 'sub',
                   'type' => 58,
                   'line' => 67
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Function',
                   'data' => 'testmeth',
                   'type' => 188,
                   'line' => 67
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 67
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'wrong',
                   'type' => 163,
                   'line' => 67
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 67
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Package',
                   'data' => 'package',
                   'type' => 120,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'Test',
                   'type' => 119,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'G',
                   'type' => 119,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'mro',
                   'type' => 88,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'c3',
                   'type' => 164,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 70
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'base',
                   'type' => 88,
                   'line' => 70
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegList',
                   'data' => 'qw',
                   'type' => 139,
                   'line' => 70
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 70
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => 'Test::D',
                   'type' => 172,
                   'line' => 70
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 70
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 70
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Package',
                   'data' => 'package',
                   'type' => 120,
                   'line' => 72
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'Test',
                   'type' => 119,
                   'line' => 72
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 72
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'H',
                   'type' => 119,
                   'line' => 72
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 72
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 72
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'mro',
                   'type' => 88,
                   'line' => 72
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'c3',
                   'type' => 164,
                   'line' => 72
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 72
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 73
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'base',
                   'type' => 88,
                   'line' => 73
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegList',
                   'data' => 'qw',
                   'type' => 139,
                   'line' => 73
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 73
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => 'Test::G',
                   'type' => 172,
                   'line' => 73
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 73
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 73
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Package',
                   'data' => 'package',
                   'type' => 120,
                   'line' => 75
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'Test',
                   'type' => 119,
                   'line' => 75
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 75
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'I',
                   'type' => 119,
                   'line' => 75
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 75
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 75
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'mro',
                   'type' => 88,
                   'line' => 75
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'c3',
                   'type' => 164,
                   'line' => 75
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 75
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'base',
                   'type' => 88,
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegList',
                   'data' => 'qw',
                   'type' => 139,
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => 'Test::H Test::F',
                   'type' => 172,
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'FunctionDecl',
                   'data' => 'sub',
                   'type' => 58,
                   'line' => 77
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Function',
                   'data' => 'testmeth',
                   'type' => 188,
                   'line' => 77
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 77
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'right',
                   'type' => 163,
                   'line' => 77
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 77
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Package',
                   'data' => 'package',
                   'type' => 120,
                   'line' => 79
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'Test',
                   'type' => 119,
                   'line' => 79
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 79
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'J',
                   'type' => 119,
                   'line' => 79
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 79
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 79
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'mro',
                   'type' => 88,
                   'line' => 79
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'c3',
                   'type' => 164,
                   'line' => 79
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 79
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'base',
                   'type' => 88,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegList',
                   'data' => 'qw',
                   'type' => 139,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => 'Test::F',
                   'type' => 172,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Package',
                   'data' => 'package',
                   'type' => 120,
                   'line' => 82
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'Test',
                   'type' => 119,
                   'line' => 82
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 82
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'K',
                   'type' => 119,
                   'line' => 82
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 82
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 82
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'mro',
                   'type' => 88,
                   'line' => 82
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'c3',
                   'type' => 164,
                   'line' => 82
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 82
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 83
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'base',
                   'type' => 88,
                   'line' => 83
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegList',
                   'data' => 'qw',
                   'type' => 139,
                   'line' => 83
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 83
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => 'Test::J Test::I',
                   'type' => 172,
                   'line' => 83
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 83
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 83
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'FunctionDecl',
                   'data' => 'sub',
                   'type' => 58,
                   'line' => 84
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Function',
                   'data' => 'testmeth',
                   'type' => 188,
                   'line' => 84
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 84
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'shift',
                   'type' => 64,
                   'line' => 84
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Pointer',
                   'data' => '->',
                   'type' => 117,
                   'line' => 84
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'next',
                   'type' => 119,
                   'line' => 84
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 84
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'method',
                   'type' => 119,
                   'line' => 84
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 84
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 85
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'ok',
                   'type' => 114,
                   'line' => 87
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 87
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'eq_array',
                   'type' => 114,
                   'line' => 87
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 87
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'mro',
                   'type' => 119,
                   'line' => 88
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 88
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'get_linear_isa',
                   'type' => 119,
                   'line' => 88
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 88
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'Test::A',
                   'type' => 164,
                   'line' => 88
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 88
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 88
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'type' => 104,
                   'line' => 89
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegList',
                   'data' => 'qw',
                   'type' => 139,
                   'line' => 89
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '(',
                   'type' => 143,
                   'line' => 89
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => 'Test::A',
                   'type' => 172,
                   'line' => 89
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => ')',
                   'type' => 143,
                   'line' => 89
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBracket',
                   'data' => ']',
                   'type' => 105,
                   'line' => 89
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 90
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 90
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '... got the right C3 merge order for Test::A',
                   'type' => 164,
                   'line' => 90
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 90
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 90
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'ok',
                   'type' => 114,
                   'line' => 92
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 92
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'eq_array',
                   'type' => 114,
                   'line' => 92
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 92
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'mro',
                   'type' => 119,
                   'line' => 93
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 93
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'get_linear_isa',
                   'type' => 119,
                   'line' => 93
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 93
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'Test::B',
                   'type' => 164,
                   'line' => 93
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 93
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 93
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'type' => 104,
                   'line' => 94
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegList',
                   'data' => 'qw',
                   'type' => 139,
                   'line' => 94
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '(',
                   'type' => 143,
                   'line' => 94
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => 'Test::B',
                   'type' => 172,
                   'line' => 94
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => ')',
                   'type' => 143,
                   'line' => 94
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBracket',
                   'data' => ']',
                   'type' => 105,
                   'line' => 94
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 95
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 95
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '... got the right C3 merge order for Test::B',
                   'type' => 164,
                   'line' => 95
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 95
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 95
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'ok',
                   'type' => 114,
                   'line' => 97
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 97
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'eq_array',
                   'type' => 114,
                   'line' => 97
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 97
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'mro',
                   'type' => 119,
                   'line' => 98
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 98
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'get_linear_isa',
                   'type' => 119,
                   'line' => 98
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 98
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'Test::C',
                   'type' => 164,
                   'line' => 98
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 98
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 98
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'type' => 104,
                   'line' => 99
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegList',
                   'data' => 'qw',
                   'type' => 139,
                   'line' => 99
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '(',
                   'type' => 143,
                   'line' => 99
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => 'Test::C',
                   'type' => 172,
                   'line' => 99
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => ')',
                   'type' => 143,
                   'line' => 99
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBracket',
                   'data' => ']',
                   'type' => 105,
                   'line' => 99
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 100
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 100
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '... got the right C3 merge order for Test::C',
                   'type' => 164,
                   'line' => 100
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 100
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 100
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'ok',
                   'type' => 114,
                   'line' => 102
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 102
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'eq_array',
                   'type' => 114,
                   'line' => 102
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 102
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'mro',
                   'type' => 119,
                   'line' => 103
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 103
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'get_linear_isa',
                   'type' => 119,
                   'line' => 103
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 103
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'Test::D',
                   'type' => 164,
                   'line' => 103
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 103
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 103
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'type' => 104,
                   'line' => 104
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegList',
                   'data' => 'qw',
                   'type' => 139,
                   'line' => 104
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '(',
                   'type' => 143,
                   'line' => 104
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => 'Test::D Test::A Test::B Test::C',
                   'type' => 172,
                   'line' => 104
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => ')',
                   'type' => 143,
                   'line' => 104
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBracket',
                   'data' => ']',
                   'type' => 105,
                   'line' => 104
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 105
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 105
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '... got the right C3 merge order for Test::D',
                   'type' => 164,
                   'line' => 105
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 105
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 105
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'ok',
                   'type' => 114,
                   'line' => 107
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 107
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'eq_array',
                   'type' => 114,
                   'line' => 107
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 107
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'mro',
                   'type' => 119,
                   'line' => 108
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 108
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'get_linear_isa',
                   'type' => 119,
                   'line' => 108
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 108
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'Test::E',
                   'type' => 164,
                   'line' => 108
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 108
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 108
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'type' => 104,
                   'line' => 109
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegList',
                   'data' => 'qw',
                   'type' => 139,
                   'line' => 109
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '(',
                   'type' => 143,
                   'line' => 109
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => 'Test::E Test::D Test::A Test::B Test::C',
                   'type' => 172,
                   'line' => 109
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => ')',
                   'type' => 143,
                   'line' => 109
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBracket',
                   'data' => ']',
                   'type' => 105,
                   'line' => 109
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 110
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 110
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '... got the right C3 merge order for Test::E',
                   'type' => 164,
                   'line' => 110
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 110
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 110
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'ok',
                   'type' => 114,
                   'line' => 112
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 112
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'eq_array',
                   'type' => 114,
                   'line' => 112
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 112
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'mro',
                   'type' => 119,
                   'line' => 113
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 113
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'get_linear_isa',
                   'type' => 119,
                   'line' => 113
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 113
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'Test::F',
                   'type' => 164,
                   'line' => 113
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 113
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 113
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'type' => 104,
                   'line' => 114
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegList',
                   'data' => 'qw',
                   'type' => 139,
                   'line' => 114
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '(',
                   'type' => 143,
                   'line' => 114
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => 'Test::F Test::E Test::D Test::A Test::B Test::C',
                   'type' => 172,
                   'line' => 114
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => ')',
                   'type' => 143,
                   'line' => 114
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBracket',
                   'data' => ']',
                   'type' => 105,
                   'line' => 114
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 115
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 115
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '... got the right C3 merge order for Test::F',
                   'type' => 164,
                   'line' => 115
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 115
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 115
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'ok',
                   'type' => 114,
                   'line' => 117
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 117
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'eq_array',
                   'type' => 114,
                   'line' => 117
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 117
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'mro',
                   'type' => 119,
                   'line' => 118
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 118
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'get_linear_isa',
                   'type' => 119,
                   'line' => 118
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 118
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'Test::G',
                   'type' => 164,
                   'line' => 118
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 118
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 118
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'type' => 104,
                   'line' => 119
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegList',
                   'data' => 'qw',
                   'type' => 139,
                   'line' => 119
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '(',
                   'type' => 143,
                   'line' => 119
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => 'Test::G Test::D Test::A Test::B Test::C',
                   'type' => 172,
                   'line' => 119
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => ')',
                   'type' => 143,
                   'line' => 119
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBracket',
                   'data' => ']',
                   'type' => 105,
                   'line' => 119
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 120
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 120
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '... got the right C3 merge order for Test::G',
                   'type' => 164,
                   'line' => 120
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 120
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 120
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'ok',
                   'type' => 114,
                   'line' => 122
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 122
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'eq_array',
                   'type' => 114,
                   'line' => 122
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 122
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'mro',
                   'type' => 119,
                   'line' => 123
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 123
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'get_linear_isa',
                   'type' => 119,
                   'line' => 123
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 123
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'Test::H',
                   'type' => 164,
                   'line' => 123
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 123
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 123
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'type' => 104,
                   'line' => 124
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegList',
                   'data' => 'qw',
                   'type' => 139,
                   'line' => 124
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '(',
                   'type' => 143,
                   'line' => 124
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => 'Test::H Test::G Test::D Test::A Test::B Test::C',
                   'type' => 172,
                   'line' => 124
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => ')',
                   'type' => 143,
                   'line' => 124
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBracket',
                   'data' => ']',
                   'type' => 105,
                   'line' => 124
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 125
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 125
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '... got the right C3 merge order for Test::H',
                   'type' => 164,
                   'line' => 125
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 125
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 125
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'ok',
                   'type' => 114,
                   'line' => 127
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 127
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'eq_array',
                   'type' => 114,
                   'line' => 127
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 127
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'mro',
                   'type' => 119,
                   'line' => 128
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 128
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'get_linear_isa',
                   'type' => 119,
                   'line' => 128
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 128
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'Test::I',
                   'type' => 164,
                   'line' => 128
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 128
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 128
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'type' => 104,
                   'line' => 129
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegList',
                   'data' => 'qw',
                   'type' => 139,
                   'line' => 129
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '(',
                   'type' => 143,
                   'line' => 129
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => 'Test::I Test::H Test::G Test::F Test::E Test::D Test::A Test::B Test::C',
                   'type' => 172,
                   'line' => 129
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => ')',
                   'type' => 143,
                   'line' => 129
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBracket',
                   'data' => ']',
                   'type' => 105,
                   'line' => 129
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 130
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 130
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '... got the right C3 merge order for Test::I',
                   'type' => 164,
                   'line' => 130
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 130
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 130
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'ok',
                   'type' => 114,
                   'line' => 132
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 132
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'eq_array',
                   'type' => 114,
                   'line' => 132
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 132
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'mro',
                   'type' => 119,
                   'line' => 133
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 133
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'get_linear_isa',
                   'type' => 119,
                   'line' => 133
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 133
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'Test::J',
                   'type' => 164,
                   'line' => 133
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 133
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 133
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'type' => 104,
                   'line' => 134
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegList',
                   'data' => 'qw',
                   'type' => 139,
                   'line' => 134
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '(',
                   'type' => 143,
                   'line' => 134
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => 'Test::J Test::F Test::E Test::D Test::A Test::B Test::C',
                   'type' => 172,
                   'line' => 134
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => ')',
                   'type' => 143,
                   'line' => 134
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBracket',
                   'data' => ']',
                   'type' => 105,
                   'line' => 134
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 135
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 135
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '... got the right C3 merge order for Test::J',
                   'type' => 164,
                   'line' => 135
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 135
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 135
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'ok',
                   'type' => 114,
                   'line' => 137
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 137
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'eq_array',
                   'type' => 114,
                   'line' => 137
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 137
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'mro',
                   'type' => 119,
                   'line' => 138
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 138
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'get_linear_isa',
                   'type' => 119,
                   'line' => 138
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 138
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'Test::K',
                   'type' => 164,
                   'line' => 138
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 138
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 138
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'type' => 104,
                   'line' => 139
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegList',
                   'data' => 'qw',
                   'type' => 139,
                   'line' => 139
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '(',
                   'type' => 143,
                   'line' => 139
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => 'Test::K Test::J Test::I Test::H Test::G Test::F Test::E Test::D Test::A Test::B Test::C',
                   'type' => 172,
                   'line' => 139
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => ')',
                   'type' => 143,
                   'line' => 139
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBracket',
                   'data' => ']',
                   'type' => 105,
                   'line' => 139
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 140
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 140
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '... got the right C3 merge order for Test::K',
                   'type' => 164,
                   'line' => 140
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 140
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 140
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'is',
                   'type' => 114,
                   'line' => 142
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 142
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'Test',
                   'type' => 119,
                   'line' => 142
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 142
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'K',
                   'type' => 119,
                   'line' => 142
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Pointer',
                   'data' => '->',
                   'type' => 117,
                   'line' => 142
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Method',
                   'data' => 'testmeth',
                   'type' => 59,
                   'line' => 142
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 142
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 142
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 142
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'right',
                   'type' => 163,
                   'line' => 142
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 142
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'next::method working ok',
                   'type' => 164,
                   'line' => 142
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 142
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 142
                 }, 'Compiler::Lexer::Token' )
        ]
, 'Compiler::Lexer::tokenize');
};

subtest 'get_groups_by_syntax_level' => sub {
    my $lexer = Compiler::Lexer->new('');
    my $tokens = $lexer->tokenize($script);
    my $stmts = $lexer->get_groups_by_syntax_level($$tokens, Compiler::Lexer::SyntaxType::T_Stmt);
    is_deeply($$stmts, [
          {
            'token_num' => 3,
            'has_warnings' => 0,
            'end_line' => 3,
            'src' => ' use strict ;',
            'start_line' => 3,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 3,
            'has_warnings' => 0,
            'end_line' => 4,
            'src' => ' use warnings ;',
            'start_line' => 4,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 6,
            'has_warnings' => 0,
            'end_line' => 6,
            'src' => ' require q(./test.pl) ;',
            'start_line' => 6,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 7,
            'has_warnings' => 1,
            'end_line' => 6,
            'src' => ' plan ( tests => 12 ) ;',
            'start_line' => 6,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 152,
            'has_warnings' => 1,
            'end_line' => 85,
            'src' => ' { package Test::A ; use mro \'c3\' ; package Test::B ; use mro \'c3\' ; package Test::C ; use mro \'c3\' ; package Test::D ; use mro \'c3\' ; use base qw/Test::A Test::B Test::C/ ; package Test::E ; use mro \'c3\' ; use base qw/Test::D/ ; package Test::F ; use mro \'c3\' ; use base qw/Test::E/ ; sub testmeth { "wrong" } package Test::G ; use mro \'c3\' ; use base qw/Test::D/ ; package Test::H ; use mro \'c3\' ; use base qw/Test::G/ ; package Test::I ; use mro \'c3\' ; use base qw/Test::H Test::F/ ; sub testmeth { "right" } package Test::J ; use mro \'c3\' ; use base qw/Test::F/ ; package Test::K ; use mro \'c3\' ; use base qw/Test::J Test::I/ ; sub testmeth { shift-> next::method } }',
            'start_line' => 52,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 3,
            'has_warnings' => 1,
            'end_line' => 53,
            'src' => ' package Test::A ;',
            'start_line' => 53,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 4,
            'has_warnings' => 0,
            'end_line' => 53,
            'src' => ' use mro \'c3\' ;',
            'start_line' => 53,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 3,
            'has_warnings' => 1,
            'end_line' => 55,
            'src' => ' package Test::B ;',
            'start_line' => 55,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 4,
            'has_warnings' => 0,
            'end_line' => 55,
            'src' => ' use mro \'c3\' ;',
            'start_line' => 55,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 3,
            'has_warnings' => 1,
            'end_line' => 57,
            'src' => ' package Test::C ;',
            'start_line' => 57,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 4,
            'has_warnings' => 0,
            'end_line' => 57,
            'src' => ' use mro \'c3\' ;',
            'start_line' => 57,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 3,
            'has_warnings' => 1,
            'end_line' => 59,
            'src' => ' package Test::D ;',
            'start_line' => 59,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 4,
            'has_warnings' => 0,
            'end_line' => 59,
            'src' => ' use mro \'c3\' ;',
            'start_line' => 59,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 7,
            'has_warnings' => 0,
            'end_line' => 60,
            'src' => ' use base qw/Test::A Test::B Test::C/ ;',
            'start_line' => 60,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 3,
            'has_warnings' => 1,
            'end_line' => 62,
            'src' => ' package Test::E ;',
            'start_line' => 62,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 4,
            'has_warnings' => 0,
            'end_line' => 62,
            'src' => ' use mro \'c3\' ;',
            'start_line' => 62,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 7,
            'has_warnings' => 0,
            'end_line' => 63,
            'src' => ' use base qw/Test::D/ ;',
            'start_line' => 63,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 3,
            'has_warnings' => 1,
            'end_line' => 65,
            'src' => ' package Test::F ;',
            'start_line' => 65,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 4,
            'has_warnings' => 0,
            'end_line' => 65,
            'src' => ' use mro \'c3\' ;',
            'start_line' => 65,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 7,
            'has_warnings' => 0,
            'end_line' => 66,
            'src' => ' use base qw/Test::E/ ;',
            'start_line' => 66,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 5,
            'has_warnings' => 0,
            'end_line' => 67,
            'src' => ' sub testmeth { "wrong" }',
            'start_line' => 67,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 3,
            'has_warnings' => 1,
            'end_line' => 69,
            'src' => ' package Test::G ;',
            'start_line' => 69,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 4,
            'has_warnings' => 0,
            'end_line' => 69,
            'src' => ' use mro \'c3\' ;',
            'start_line' => 69,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 7,
            'has_warnings' => 0,
            'end_line' => 70,
            'src' => ' use base qw/Test::D/ ;',
            'start_line' => 70,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 3,
            'has_warnings' => 1,
            'end_line' => 72,
            'src' => ' package Test::H ;',
            'start_line' => 72,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 4,
            'has_warnings' => 0,
            'end_line' => 72,
            'src' => ' use mro \'c3\' ;',
            'start_line' => 72,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 7,
            'has_warnings' => 0,
            'end_line' => 73,
            'src' => ' use base qw/Test::G/ ;',
            'start_line' => 73,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 3,
            'has_warnings' => 1,
            'end_line' => 75,
            'src' => ' package Test::I ;',
            'start_line' => 75,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 4,
            'has_warnings' => 0,
            'end_line' => 75,
            'src' => ' use mro \'c3\' ;',
            'start_line' => 75,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 7,
            'has_warnings' => 0,
            'end_line' => 76,
            'src' => ' use base qw/Test::H Test::F/ ;',
            'start_line' => 76,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 5,
            'has_warnings' => 0,
            'end_line' => 77,
            'src' => ' sub testmeth { "right" }',
            'start_line' => 77,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 3,
            'has_warnings' => 1,
            'end_line' => 79,
            'src' => ' package Test::J ;',
            'start_line' => 79,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 4,
            'has_warnings' => 0,
            'end_line' => 79,
            'src' => ' use mro \'c3\' ;',
            'start_line' => 79,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 7,
            'has_warnings' => 0,
            'end_line' => 80,
            'src' => ' use base qw/Test::F/ ;',
            'start_line' => 80,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 3,
            'has_warnings' => 1,
            'end_line' => 82,
            'src' => ' package Test::K ;',
            'start_line' => 82,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 4,
            'has_warnings' => 0,
            'end_line' => 82,
            'src' => ' use mro \'c3\' ;',
            'start_line' => 82,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 7,
            'has_warnings' => 0,
            'end_line' => 83,
            'src' => ' use base qw/Test::J Test::I/ ;',
            'start_line' => 83,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 7,
            'has_warnings' => 1,
            'end_line' => 84,
            'src' => ' sub testmeth { shift-> next::method }',
            'start_line' => 84,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 20,
            'has_warnings' => 1,
            'end_line' => 90,
            'src' => ' ok ( eq_array ( mro::get_linear_isa ( \'Test::A\' ) , [ qw(Test::A) ] ) , \'... got the right C3 merge order for Test::A\' ) ;',
            'start_line' => 87,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 20,
            'has_warnings' => 1,
            'end_line' => 95,
            'src' => ' ok ( eq_array ( mro::get_linear_isa ( \'Test::B\' ) , [ qw(Test::B) ] ) , \'... got the right C3 merge order for Test::B\' ) ;',
            'start_line' => 92,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 20,
            'has_warnings' => 1,
            'end_line' => 100,
            'src' => ' ok ( eq_array ( mro::get_linear_isa ( \'Test::C\' ) , [ qw(Test::C) ] ) , \'... got the right C3 merge order for Test::C\' ) ;',
            'start_line' => 97,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 20,
            'has_warnings' => 1,
            'end_line' => 105,
            'src' => ' ok ( eq_array ( mro::get_linear_isa ( \'Test::D\' ) , [ qw(Test::D Test::A Test::B Test::C) ] ) , \'... got the right C3 merge order for Test::D\' ) ;',
            'start_line' => 102,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 20,
            'has_warnings' => 1,
            'end_line' => 110,
            'src' => ' ok ( eq_array ( mro::get_linear_isa ( \'Test::E\' ) , [ qw(Test::E Test::D Test::A Test::B Test::C) ] ) , \'... got the right C3 merge order for Test::E\' ) ;',
            'start_line' => 107,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 20,
            'has_warnings' => 1,
            'end_line' => 115,
            'src' => ' ok ( eq_array ( mro::get_linear_isa ( \'Test::F\' ) , [ qw(Test::F Test::E Test::D Test::A Test::B Test::C) ] ) , \'... got the right C3 merge order for Test::F\' ) ;',
            'start_line' => 112,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 20,
            'has_warnings' => 1,
            'end_line' => 120,
            'src' => ' ok ( eq_array ( mro::get_linear_isa ( \'Test::G\' ) , [ qw(Test::G Test::D Test::A Test::B Test::C) ] ) , \'... got the right C3 merge order for Test::G\' ) ;',
            'start_line' => 117,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 20,
            'has_warnings' => 1,
            'end_line' => 125,
            'src' => ' ok ( eq_array ( mro::get_linear_isa ( \'Test::H\' ) , [ qw(Test::H Test::G Test::D Test::A Test::B Test::C) ] ) , \'... got the right C3 merge order for Test::H\' ) ;',
            'start_line' => 122,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 20,
            'has_warnings' => 1,
            'end_line' => 130,
            'src' => ' ok ( eq_array ( mro::get_linear_isa ( \'Test::I\' ) , [ qw(Test::I Test::H Test::G Test::F Test::E Test::D Test::A Test::B Test::C) ] ) , \'... got the right C3 merge order for Test::I\' ) ;',
            'start_line' => 127,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 20,
            'has_warnings' => 1,
            'end_line' => 135,
            'src' => ' ok ( eq_array ( mro::get_linear_isa ( \'Test::J\' ) , [ qw(Test::J Test::F Test::E Test::D Test::A Test::B Test::C) ] ) , \'... got the right C3 merge order for Test::J\' ) ;',
            'start_line' => 132,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 20,
            'has_warnings' => 1,
            'end_line' => 140,
            'src' => ' ok ( eq_array ( mro::get_linear_isa ( \'Test::K\' ) , [ qw(Test::K Test::J Test::I Test::H Test::G Test::F Test::E Test::D Test::A Test::B Test::C) ] ) , \'... got the right C3 merge order for Test::K\' ) ;',
            'start_line' => 137,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 13,
            'has_warnings' => 1,
            'end_line' => 142,
            'src' => ' is ( Test::K-> testmeth ( ) , "right" , \'next::method working ok\' ) ;',
            'start_line' => 142,
            'indent' => 0,
            'block_id' => 0
          }
        ]
, 'Compiler::Lexer::get_groups_by_syntax_level');
};

subtest 'get_used_modules' => sub {
    my $modules = Compiler::Lexer->new('')->get_used_modules($script);
    is_deeply($modules, [
          {
            'args' => '',
            'name' => 'strict'
          },
          {
            'args' => '',
            'name' => 'warnings'
          },
          {
            'args' => '  \'c3\'',
            'name' => 'mro'
          },
          {
            'args' => '  \'c3\'',
            'name' => 'mro'
          },
          {
            'args' => '  \'c3\'',
            'name' => 'mro'
          },
          {
            'args' => '  \'c3\'',
            'name' => 'mro'
          },
          {
            'args' => '  qw / Test::A Test::B Test::C /',
            'name' => 'base'
          },
          {
            'args' => '  \'c3\'',
            'name' => 'mro'
          },
          {
            'args' => '  qw / Test::D /',
            'name' => 'base'
          },
          {
            'args' => '  \'c3\'',
            'name' => 'mro'
          },
          {
            'args' => '  qw / Test::E /',
            'name' => 'base'
          },
          {
            'args' => '  \'c3\'',
            'name' => 'mro'
          },
          {
            'args' => '  qw / Test::D /',
            'name' => 'base'
          },
          {
            'args' => '  \'c3\'',
            'name' => 'mro'
          },
          {
            'args' => '  qw / Test::G /',
            'name' => 'base'
          },
          {
            'args' => '  \'c3\'',
            'name' => 'mro'
          },
          {
            'args' => '  qw / Test::H Test::F /',
            'name' => 'base'
          },
          {
            'args' => '  \'c3\'',
            'name' => 'mro'
          },
          {
            'args' => '  qw / Test::F /',
            'name' => 'base'
          },
          {
            'args' => '  \'c3\'',
            'name' => 'mro'
          },
          {
            'args' => '  qw / Test::J Test::I /',
            'name' => 'base'
          }
        ]
, 'Compiler::Lexer::get_used_modules');
};

done_testing;
