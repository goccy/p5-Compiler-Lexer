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
use utf8;
use open qw( :utf8 :std );

require q(./test.pl); plan(tests => 10);

=pod

This example is take from: http://www.python.org/2.3/mro.html

"My first example"
class O: pass
class F(O): pass
class E(O): pass
class D(O): pass
class C(D,F): pass
class B(D,E): pass
class A(B,C): pass


                          6
                         ---
Level 3                 | O |                  (more general)
                      /  ---  \
                     /    |    \                      |
                    /     |     \                     |
                   /      |      \                    |
                  ---    ---    ---                   |
Level 2        3 | D | 4| E |  | F | 5                |
                  ---    ---    ---                   |
                   \  \ _ /       |                   |
                    \    / \ _    |                   |
                     \  /      \  |                   |
                      ---      ---                    |
Level 1            1 | B |    | C | 2                 |
                      ---      ---                    |
                        \      /                      |
                         \    /                      \ /
                           ---
Level 0                 0 | A |                (more specialized)
                           ---

=cut

{
    package 텟ţ::ᴼ;
    use mro 'c3'; 
    
    package 텟ţ::Ḟ;   
    use mro 'c3';  
    use base '텟ţ::ᴼ';        
    
    package 텟ţ::ऍ;
    use base '텟ţ::ᴼ';    
    use mro 'c3';     
    
    sub ƈ_or_ऍ { '텟ţ::ऍ' }

    package 텟ţ::Ḋ;
    use mro 'c3'; 
    use base '텟ţ::ᴼ';     
    
    sub ƈ_or_Ḋ { '텟ţ::Ḋ' }       
      
    package 텟ţ::ƈ;
    use base ('텟ţ::Ḋ', '텟ţ::Ḟ');
    use mro 'c3'; 
    
    sub ƈ_or_Ḋ { '텟ţ::ƈ' }
    sub ƈ_or_ऍ { '텟ţ::ƈ' }    
        
    package 텟ţ::ᛒ;    
    use mro 'c3'; 
    use base ('텟ţ::Ḋ', '텟ţ::ऍ');    
        
    package 텟ţ::ଅ;    
    use base ('텟ţ::ᛒ', '텟ţ::ƈ');
    use mro 'c3';    
}

ok(eq_array(
    mro::get_linear_isa('텟ţ::Ḟ'),
    [ qw(텟ţ::Ḟ 텟ţ::ᴼ) ]
), '... got the right MRO for 텟ţ::Ḟ');

ok(eq_array(
    mro::get_linear_isa('텟ţ::ऍ'),
    [ qw(텟ţ::ऍ 텟ţ::ᴼ) ]
), '... got the right MRO for 텟ţ::ऍ');    

ok(eq_array(
    mro::get_linear_isa('텟ţ::Ḋ'),
    [ qw(텟ţ::Ḋ 텟ţ::ᴼ) ]
), '... got the right MRO for 텟ţ::Ḋ');       

ok(eq_array(
    mro::get_linear_isa('텟ţ::ƈ'),
    [ qw(텟ţ::ƈ 텟ţ::Ḋ 텟ţ::Ḟ 텟ţ::ᴼ) ]
), '... got the right MRO for 텟ţ::ƈ'); 

ok(eq_array(
    mro::get_linear_isa('텟ţ::ᛒ'),
    [ qw(텟ţ::ᛒ 텟ţ::Ḋ 텟ţ::ऍ 텟ţ::ᴼ) ]
), '... got the right MRO for 텟ţ::ᛒ');     

ok(eq_array(
    mro::get_linear_isa('텟ţ::ଅ'),
    [ qw(텟ţ::ଅ 텟ţ::ᛒ 텟ţ::ƈ 텟ţ::Ḋ 텟ţ::ऍ 텟ţ::Ḟ 텟ţ::ᴼ) ]
), '... got the right MRO for 텟ţ::ଅ');  
    
is(텟ţ::ଅ->ƈ_or_Ḋ, '텟ţ::ƈ', '... got the expected method output');
is(텟ţ::ଅ->can('ƈ_or_Ḋ')->(), '텟ţ::ƈ', '... can got the expected method output');
is(텟ţ::ଅ->ƈ_or_ऍ, '텟ţ::ƈ', '... got the expected method output');
is(텟ţ::ଅ->can('ƈ_or_ऍ')->(), '텟ţ::ƈ', '... can got the expected method output');

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
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 5
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'utf8',
                   'type' => 88,
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
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'open',
                   'type' => 64,
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegList',
                   'data' => 'qw',
                   'type' => 139,
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
                   'data' => ' :utf8 :std ',
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
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RequireDecl',
                   'data' => 'require',
                   'type' => 65,
                   'line' => 8
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegQuote',
                   'data' => 'q',
                   'type' => 137,
                   'line' => 8
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '(',
                   'type' => 143,
                   'line' => 8
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => './test.pl',
                   'type' => 172,
                   'line' => 8
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => ')',
                   'type' => 143,
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
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'plan',
                   'type' => 114,
                   'line' => 8
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 8
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'tests',
                   'type' => 114,
                   'line' => 8
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'type' => 116,
                   'line' => 8
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Int',
                   'data' => '10',
                   'type' => 161,
                   'line' => 8
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
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
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 48
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Package',
                   'data' => 'package',
                   'type' => 120,
                   'line' => 49
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '텟ţ',
                   'type' => 119,
                   'line' => 49
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 49
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'ᴼ',
                   'type' => 119,
                   'line' => 49
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 49
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'mro',
                   'type' => 88,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'c3',
                   'type' => 164,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Package',
                   'data' => 'package',
                   'type' => 120,
                   'line' => 52
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '텟ţ',
                   'type' => 119,
                   'line' => 52
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 52
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'Ḟ',
                   'type' => 119,
                   'line' => 52
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 52
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
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 54
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'base',
                   'type' => 88,
                   'line' => 54
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '텟ţ::ᴼ',
                   'type' => 164,
                   'line' => 54
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 54
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Package',
                   'data' => 'package',
                   'type' => 120,
                   'line' => 56
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '텟ţ',
                   'type' => 119,
                   'line' => 56
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 56
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'ऍ',
                   'type' => 119,
                   'line' => 56
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 56
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
                   'data' => 'base',
                   'type' => 88,
                   'line' => 57
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '텟ţ::ᴼ',
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
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 58
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'mro',
                   'type' => 88,
                   'line' => 58
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'c3',
                   'type' => 164,
                   'line' => 58
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 58
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'FunctionDecl',
                   'data' => 'sub',
                   'type' => 58,
                   'line' => 60
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Function',
                   'data' => 'ƈ_or_ऍ',
                   'type' => 188,
                   'line' => 60
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 60
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '텟ţ::ऍ',
                   'type' => 164,
                   'line' => 60
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
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
                   'data' => '텟ţ',
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
                   'data' => 'Ḋ',
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
                   'line' => 63
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'mro',
                   'type' => 88,
                   'line' => 63
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'c3',
                   'type' => 164,
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
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 64
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'base',
                   'type' => 88,
                   'line' => 64
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '텟ţ::ᴼ',
                   'type' => 164,
                   'line' => 64
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 64
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'FunctionDecl',
                   'data' => 'sub',
                   'type' => 58,
                   'line' => 66
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Function',
                   'data' => 'ƈ_or_Ḋ',
                   'type' => 188,
                   'line' => 66
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 66
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '텟ţ::Ḋ',
                   'type' => 164,
                   'line' => 66
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 66
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Package',
                   'data' => 'package',
                   'type' => 120,
                   'line' => 68
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '텟ţ',
                   'type' => 119,
                   'line' => 68
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 68
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'ƈ',
                   'type' => 119,
                   'line' => 68
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 68
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
                   'data' => 'base',
                   'type' => 88,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '텟ţ::Ḋ',
                   'type' => 164,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '텟ţ::Ḟ',
                   'type' => 164,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
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
                   'data' => 'mro',
                   'type' => 88,
                   'line' => 70
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'c3',
                   'type' => 164,
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
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'FunctionDecl',
                   'data' => 'sub',
                   'type' => 58,
                   'line' => 72
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Function',
                   'data' => 'ƈ_or_Ḋ',
                   'type' => 188,
                   'line' => 72
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 72
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '텟ţ::ƈ',
                   'type' => 164,
                   'line' => 72
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 72
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'FunctionDecl',
                   'data' => 'sub',
                   'type' => 58,
                   'line' => 73
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Function',
                   'data' => 'ƈ_or_ऍ',
                   'type' => 188,
                   'line' => 73
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 73
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '텟ţ::ƈ',
                   'type' => 164,
                   'line' => 73
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
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
                   'data' => '텟ţ',
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
                   'data' => 'ᛒ',
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
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'mro',
                   'type' => 88,
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'c3',
                   'type' => 164,
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
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 77
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'base',
                   'type' => 88,
                   'line' => 77
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 77
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '텟ţ::Ḋ',
                   'type' => 164,
                   'line' => 77
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 77
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '텟ţ::ऍ',
                   'type' => 164,
                   'line' => 77
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 77
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
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
                   'data' => '텟ţ',
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
                   'data' => 'ଅ',
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
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '텟ţ::ᛒ',
                   'type' => 164,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '텟ţ::ƈ',
                   'type' => 164,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
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
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 81
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'mro',
                   'type' => 88,
                   'line' => 81
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'c3',
                   'type' => 164,
                   'line' => 81
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 81
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 82
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'ok',
                   'type' => 114,
                   'line' => 84
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 84
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'eq_array',
                   'type' => 114,
                   'line' => 84
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 84
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'mro',
                   'type' => 119,
                   'line' => 85
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 85
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'get_linear_isa',
                   'type' => 119,
                   'line' => 85
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 85
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '텟ţ::Ḟ',
                   'type' => 164,
                   'line' => 85
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 85
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 85
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'type' => 104,
                   'line' => 86
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegList',
                   'data' => 'qw',
                   'type' => 139,
                   'line' => 86
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '(',
                   'type' => 143,
                   'line' => 86
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => '텟ţ::Ḟ 텟ţ::ᴼ',
                   'type' => 172,
                   'line' => 86
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => ')',
                   'type' => 143,
                   'line' => 86
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBracket',
                   'data' => ']',
                   'type' => 105,
                   'line' => 86
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 87
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 87
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '... got the right MRO for 텟ţ::Ḟ',
                   'type' => 164,
                   'line' => 87
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 87
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 87
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'ok',
                   'type' => 114,
                   'line' => 89
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 89
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'eq_array',
                   'type' => 114,
                   'line' => 89
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 89
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'mro',
                   'type' => 119,
                   'line' => 90
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 90
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'get_linear_isa',
                   'type' => 119,
                   'line' => 90
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 90
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '텟ţ::ऍ',
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
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 90
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'type' => 104,
                   'line' => 91
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegList',
                   'data' => 'qw',
                   'type' => 139,
                   'line' => 91
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '(',
                   'type' => 143,
                   'line' => 91
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => '텟ţ::ऍ 텟ţ::ᴼ',
                   'type' => 172,
                   'line' => 91
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => ')',
                   'type' => 143,
                   'line' => 91
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBracket',
                   'data' => ']',
                   'type' => 105,
                   'line' => 91
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 92
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 92
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '... got the right MRO for 텟ţ::ऍ',
                   'type' => 164,
                   'line' => 92
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 92
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 92
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'ok',
                   'type' => 114,
                   'line' => 94
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 94
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'eq_array',
                   'type' => 114,
                   'line' => 94
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 94
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'mro',
                   'type' => 119,
                   'line' => 95
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 95
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'get_linear_isa',
                   'type' => 119,
                   'line' => 95
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 95
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '텟ţ::Ḋ',
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
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 95
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'type' => 104,
                   'line' => 96
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegList',
                   'data' => 'qw',
                   'type' => 139,
                   'line' => 96
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '(',
                   'type' => 143,
                   'line' => 96
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => '텟ţ::Ḋ 텟ţ::ᴼ',
                   'type' => 172,
                   'line' => 96
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => ')',
                   'type' => 143,
                   'line' => 96
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBracket',
                   'data' => ']',
                   'type' => 105,
                   'line' => 96
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 97
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 97
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '... got the right MRO for 텟ţ::Ḋ',
                   'type' => 164,
                   'line' => 97
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 97
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 97
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'ok',
                   'type' => 114,
                   'line' => 99
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 99
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'eq_array',
                   'type' => 114,
                   'line' => 99
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 99
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'mro',
                   'type' => 119,
                   'line' => 100
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 100
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'get_linear_isa',
                   'type' => 119,
                   'line' => 100
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 100
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '텟ţ::ƈ',
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
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 100
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'type' => 104,
                   'line' => 101
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegList',
                   'data' => 'qw',
                   'type' => 139,
                   'line' => 101
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '(',
                   'type' => 143,
                   'line' => 101
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => '텟ţ::ƈ 텟ţ::Ḋ 텟ţ::Ḟ 텟ţ::ᴼ',
                   'type' => 172,
                   'line' => 101
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => ')',
                   'type' => 143,
                   'line' => 101
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBracket',
                   'data' => ']',
                   'type' => 105,
                   'line' => 101
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 102
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 102
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '... got the right MRO for 텟ţ::ƈ',
                   'type' => 164,
                   'line' => 102
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 102
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 102
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'ok',
                   'type' => 114,
                   'line' => 104
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 104
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'eq_array',
                   'type' => 114,
                   'line' => 104
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 104
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'mro',
                   'type' => 119,
                   'line' => 105
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 105
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'get_linear_isa',
                   'type' => 119,
                   'line' => 105
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 105
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '텟ţ::ᛒ',
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
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 105
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'type' => 104,
                   'line' => 106
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegList',
                   'data' => 'qw',
                   'type' => 139,
                   'line' => 106
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '(',
                   'type' => 143,
                   'line' => 106
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => '텟ţ::ᛒ 텟ţ::Ḋ 텟ţ::ऍ 텟ţ::ᴼ',
                   'type' => 172,
                   'line' => 106
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => ')',
                   'type' => 143,
                   'line' => 106
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBracket',
                   'data' => ']',
                   'type' => 105,
                   'line' => 106
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 107
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 107
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '... got the right MRO for 텟ţ::ᛒ',
                   'type' => 164,
                   'line' => 107
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 107
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 107
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'ok',
                   'type' => 114,
                   'line' => 109
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 109
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'eq_array',
                   'type' => 114,
                   'line' => 109
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 109
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'mro',
                   'type' => 119,
                   'line' => 110
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 110
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'get_linear_isa',
                   'type' => 119,
                   'line' => 110
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 110
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '텟ţ::ଅ',
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
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 110
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'type' => 104,
                   'line' => 111
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegList',
                   'data' => 'qw',
                   'type' => 139,
                   'line' => 111
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '(',
                   'type' => 143,
                   'line' => 111
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => '텟ţ::ଅ 텟ţ::ᛒ 텟ţ::ƈ 텟ţ::Ḋ 텟ţ::ऍ 텟ţ::Ḟ 텟ţ::ᴼ',
                   'type' => 172,
                   'line' => 111
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => ')',
                   'type' => 143,
                   'line' => 111
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBracket',
                   'data' => ']',
                   'type' => 105,
                   'line' => 111
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 112
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 112
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '... got the right MRO for 텟ţ::ଅ',
                   'type' => 164,
                   'line' => 112
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 112
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 112
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'is',
                   'type' => 114,
                   'line' => 114
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 114
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '텟ţ',
                   'type' => 119,
                   'line' => 114
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 114
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'ଅ',
                   'type' => 119,
                   'line' => 114
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Pointer',
                   'data' => '->',
                   'type' => 117,
                   'line' => 114
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Call',
                   'data' => 'ƈ_or_Ḋ',
                   'type' => 189,
                   'line' => 114
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 114
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '텟ţ::ƈ',
                   'type' => 164,
                   'line' => 114
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 114
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '... got the expected method output',
                   'type' => 164,
                   'line' => 114
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 114
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 114
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'is',
                   'type' => 114,
                   'line' => 115
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 115
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '텟ţ',
                   'type' => 119,
                   'line' => 115
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 115
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'ଅ',
                   'type' => 119,
                   'line' => 115
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Pointer',
                   'data' => '->',
                   'type' => 117,
                   'line' => 115
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Method',
                   'data' => 'can',
                   'type' => 59,
                   'line' => 115
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 115
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'ƈ_or_Ḋ',
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
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Pointer',
                   'data' => '->',
                   'type' => 117,
                   'line' => 115
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
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
                   'data' => '텟ţ::ƈ',
                   'type' => 164,
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
                   'data' => '... can got the expected method output',
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
                   'data' => 'is',
                   'type' => 114,
                   'line' => 116
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 116
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '텟ţ',
                   'type' => 119,
                   'line' => 116
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 116
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'ଅ',
                   'type' => 119,
                   'line' => 116
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Pointer',
                   'data' => '->',
                   'type' => 117,
                   'line' => 116
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Call',
                   'data' => 'ƈ_or_ऍ',
                   'type' => 189,
                   'line' => 116
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 116
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '텟ţ::ƈ',
                   'type' => 164,
                   'line' => 116
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 116
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '... got the expected method output',
                   'type' => 164,
                   'line' => 116
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 116
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 116
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'is',
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
                   'data' => '텟ţ',
                   'type' => 119,
                   'line' => 117
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 117
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'ଅ',
                   'type' => 119,
                   'line' => 117
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Pointer',
                   'data' => '->',
                   'type' => 117,
                   'line' => 117
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Method',
                   'data' => 'can',
                   'type' => 59,
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
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'ƈ_or_ऍ',
                   'type' => 164,
                   'line' => 117
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 117
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Pointer',
                   'data' => '->',
                   'type' => 117,
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
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 117
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 117
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '텟ţ::ƈ',
                   'type' => 164,
                   'line' => 117
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 117
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '... can got the expected method output',
                   'type' => 164,
                   'line' => 117
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 117
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 117
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
            'token_num' => 3,
            'has_warnings' => 0,
            'end_line' => 5,
            'src' => ' use utf8 ;',
            'start_line' => 5,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 7,
            'has_warnings' => 0,
            'end_line' => 6,
            'src' => ' use open qw( :utf8 :std ) ;',
            'start_line' => 6,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 6,
            'has_warnings' => 0,
            'end_line' => 8,
            'src' => ' require q(./test.pl) ;',
            'start_line' => 8,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 7,
            'has_warnings' => 1,
            'end_line' => 8,
            'src' => ' plan ( tests => 10 ) ;',
            'start_line' => 8,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 107,
            'has_warnings' => 1,
            'end_line' => 82,
            'src' => ' { package 텟ţ::ᴼ ; use mro \'c3\' ; package 텟ţ::Ḟ ; use mro \'c3\' ; use base \'텟ţ::ᴼ\' ; package 텟ţ::ऍ ; use base \'텟ţ::ᴼ\' ; use mro \'c3\' ; sub ƈ_or_ऍ { \'텟ţ::ऍ\' } package 텟ţ::Ḋ ; use mro \'c3\' ; use base \'텟ţ::ᴼ\' ; sub ƈ_or_Ḋ { \'텟ţ::Ḋ\' } package 텟ţ::ƈ ; use base ( \'텟ţ::Ḋ\' , \'텟ţ::Ḟ\' ) ; use mro \'c3\' ; sub ƈ_or_Ḋ { \'텟ţ::ƈ\' } sub ƈ_or_ऍ { \'텟ţ::ƈ\' } package 텟ţ::ᛒ ; use mro \'c3\' ; use base ( \'텟ţ::Ḋ\' , \'텟ţ::ऍ\' ) ; package 텟ţ::ଅ ; use base ( \'텟ţ::ᛒ\' , \'텟ţ::ƈ\' ) ; use mro \'c3\' ; }',
            'start_line' => 48,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 3,
            'has_warnings' => 1,
            'end_line' => 49,
            'src' => ' package 텟ţ::ᴼ ;',
            'start_line' => 49,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 4,
            'has_warnings' => 0,
            'end_line' => 50,
            'src' => ' use mro \'c3\' ;',
            'start_line' => 50,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 3,
            'has_warnings' => 1,
            'end_line' => 52,
            'src' => ' package 텟ţ::Ḟ ;',
            'start_line' => 52,
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
            'token_num' => 4,
            'has_warnings' => 0,
            'end_line' => 54,
            'src' => ' use base \'텟ţ::ᴼ\' ;',
            'start_line' => 54,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 3,
            'has_warnings' => 1,
            'end_line' => 56,
            'src' => ' package 텟ţ::ऍ ;',
            'start_line' => 56,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 4,
            'has_warnings' => 0,
            'end_line' => 57,
            'src' => ' use base \'텟ţ::ᴼ\' ;',
            'start_line' => 57,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 4,
            'has_warnings' => 0,
            'end_line' => 58,
            'src' => ' use mro \'c3\' ;',
            'start_line' => 58,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 5,
            'has_warnings' => 0,
            'end_line' => 60,
            'src' => ' sub ƈ_or_ऍ { \'텟ţ::ऍ\' }',
            'start_line' => 60,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 3,
            'has_warnings' => 1,
            'end_line' => 62,
            'src' => ' package 텟ţ::Ḋ ;',
            'start_line' => 62,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 4,
            'has_warnings' => 0,
            'end_line' => 63,
            'src' => ' use mro \'c3\' ;',
            'start_line' => 63,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 4,
            'has_warnings' => 0,
            'end_line' => 64,
            'src' => ' use base \'텟ţ::ᴼ\' ;',
            'start_line' => 64,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 5,
            'has_warnings' => 0,
            'end_line' => 66,
            'src' => ' sub ƈ_or_Ḋ { \'텟ţ::Ḋ\' }',
            'start_line' => 66,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 3,
            'has_warnings' => 1,
            'end_line' => 68,
            'src' => ' package 텟ţ::ƈ ;',
            'start_line' => 68,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 8,
            'has_warnings' => 0,
            'end_line' => 69,
            'src' => ' use base ( \'텟ţ::Ḋ\' , \'텟ţ::Ḟ\' ) ;',
            'start_line' => 69,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 4,
            'has_warnings' => 0,
            'end_line' => 70,
            'src' => ' use mro \'c3\' ;',
            'start_line' => 70,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 5,
            'has_warnings' => 0,
            'end_line' => 72,
            'src' => ' sub ƈ_or_Ḋ { \'텟ţ::ƈ\' }',
            'start_line' => 72,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 5,
            'has_warnings' => 0,
            'end_line' => 73,
            'src' => ' sub ƈ_or_ऍ { \'텟ţ::ƈ\' }',
            'start_line' => 73,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 3,
            'has_warnings' => 1,
            'end_line' => 75,
            'src' => ' package 텟ţ::ᛒ ;',
            'start_line' => 75,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 4,
            'has_warnings' => 0,
            'end_line' => 76,
            'src' => ' use mro \'c3\' ;',
            'start_line' => 76,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 8,
            'has_warnings' => 0,
            'end_line' => 77,
            'src' => ' use base ( \'텟ţ::Ḋ\' , \'텟ţ::ऍ\' ) ;',
            'start_line' => 77,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 3,
            'has_warnings' => 1,
            'end_line' => 79,
            'src' => ' package 텟ţ::ଅ ;',
            'start_line' => 79,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 8,
            'has_warnings' => 0,
            'end_line' => 80,
            'src' => ' use base ( \'텟ţ::ᛒ\' , \'텟ţ::ƈ\' ) ;',
            'start_line' => 80,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 4,
            'has_warnings' => 0,
            'end_line' => 81,
            'src' => ' use mro \'c3\' ;',
            'start_line' => 81,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 20,
            'has_warnings' => 1,
            'end_line' => 87,
            'src' => ' ok ( eq_array ( mro::get_linear_isa ( \'텟ţ::Ḟ\' ) , [ qw(텟ţ::Ḟ 텟ţ::ᴼ) ] ) , \'... got the right MRO for 텟ţ::Ḟ\' ) ;',
            'start_line' => 84,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 20,
            'has_warnings' => 1,
            'end_line' => 92,
            'src' => ' ok ( eq_array ( mro::get_linear_isa ( \'텟ţ::ऍ\' ) , [ qw(텟ţ::ऍ 텟ţ::ᴼ) ] ) , \'... got the right MRO for 텟ţ::ऍ\' ) ;',
            'start_line' => 89,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 20,
            'has_warnings' => 1,
            'end_line' => 97,
            'src' => ' ok ( eq_array ( mro::get_linear_isa ( \'텟ţ::Ḋ\' ) , [ qw(텟ţ::Ḋ 텟ţ::ᴼ) ] ) , \'... got the right MRO for 텟ţ::Ḋ\' ) ;',
            'start_line' => 94,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 20,
            'has_warnings' => 1,
            'end_line' => 102,
            'src' => ' ok ( eq_array ( mro::get_linear_isa ( \'텟ţ::ƈ\' ) , [ qw(텟ţ::ƈ 텟ţ::Ḋ 텟ţ::Ḟ 텟ţ::ᴼ) ] ) , \'... got the right MRO for 텟ţ::ƈ\' ) ;',
            'start_line' => 99,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 20,
            'has_warnings' => 1,
            'end_line' => 107,
            'src' => ' ok ( eq_array ( mro::get_linear_isa ( \'텟ţ::ᛒ\' ) , [ qw(텟ţ::ᛒ 텟ţ::Ḋ 텟ţ::ऍ 텟ţ::ᴼ) ] ) , \'... got the right MRO for 텟ţ::ᛒ\' ) ;',
            'start_line' => 104,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 20,
            'has_warnings' => 1,
            'end_line' => 112,
            'src' => ' ok ( eq_array ( mro::get_linear_isa ( \'텟ţ::ଅ\' ) , [ qw(텟ţ::ଅ 텟ţ::ᛒ 텟ţ::ƈ 텟ţ::Ḋ 텟ţ::ऍ 텟ţ::Ḟ 텟ţ::ᴼ) ] ) , \'... got the right MRO for 텟ţ::ଅ\' ) ;',
            'start_line' => 109,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 11,
            'has_warnings' => 1,
            'end_line' => 114,
            'src' => ' is ( 텟ţ::ଅ-> ƈ_or_Ḋ , \'텟ţ::ƈ\' , \'... got the expected method output\' ) ;',
            'start_line' => 114,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 17,
            'has_warnings' => 1,
            'end_line' => 115,
            'src' => ' is ( 텟ţ::ଅ-> can ( \'ƈ_or_Ḋ\' )-> ( ) , \'텟ţ::ƈ\' , \'... can got the expected method output\' ) ;',
            'start_line' => 115,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 11,
            'has_warnings' => 1,
            'end_line' => 116,
            'src' => ' is ( 텟ţ::ଅ-> ƈ_or_ऍ , \'텟ţ::ƈ\' , \'... got the expected method output\' ) ;',
            'start_line' => 116,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 17,
            'has_warnings' => 1,
            'end_line' => 117,
            'src' => ' is ( 텟ţ::ଅ-> can ( \'ƈ_or_ऍ\' )-> ( ) , \'텟ţ::ƈ\' , \'... can got the expected method output\' ) ;',
            'start_line' => 117,
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
            'args' => '',
            'name' => 'utf8'
          },
          {
            'args' => '  qw (  :utf8 :std  )',
            'name' => 'open'
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
            'args' => '  \'텟ţ::ᴼ\'',
            'name' => 'base'
          },
          {
            'args' => '  \'텟ţ::ᴼ\'',
            'name' => 'base'
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
            'args' => '  \'텟ţ::ᴼ\'',
            'name' => 'base'
          },
          {
            'args' => '  ( \'텟ţ::Ḋ\' , \'텟ţ::Ḟ\' )',
            'name' => 'base'
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
            'args' => '  ( \'텟ţ::Ḋ\' , \'텟ţ::ऍ\' )',
            'name' => 'base'
          },
          {
            'args' => '  ( \'텟ţ::ᛒ\' , \'텟ţ::ƈ\' )',
            'name' => 'base'
          },
          {
            'args' => '  \'c3\'',
            'name' => 'mro'
          }
        ]
, 'Compiler::Lexer::get_used_modules');
};

done_testing;
