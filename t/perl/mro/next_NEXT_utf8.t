use strict;
use warnings;
use Test::More;
BEGIN {
    use_ok('Compiler::Lexer');
}
my $script =<<'__SCRIPT__';
#!/usr/bin/perl

use strict;
use warnings;
use NEXT;
use utf8;
use open qw( :utf8 :std );

chdir 't' if -d 't';
require './test.pl';
plan(tests => 4);

{
    package ᕘ;
    use strict;
    use warnings;
    use mro 'c3';
    
    sub fಓ { 'ᕘ::fಓ' }
    
    package Fᶽ;
    use strict;
    use warnings;
    use mro 'c3';
    use base 'ᕘ';

    sub fಓ { 'Fᶽ::fಓ => ' . (shift)->next::method }
        
    package Bᛆ;
    use strict;
    use warnings;    
    use mro 'c3';
    use base 'ᕘ';

    sub fಓ { 'Bᛆ::fಓ => ' . (shift)->next::method }
    
    package Baᕃ;
    use strict;
    use warnings;    

    use base 'Bᛆ', 'Fᶽ';
    
    sub fಓ { 'Baᕃ::fಓ => ' . (shift)->NEXT::fಓ }    
}

is(ᕘ->fಓ, 'ᕘ::fಓ', '... got the right value from ᕘ->fಓ');
is(Fᶽ->fಓ, 'Fᶽ::fಓ => ᕘ::fಓ', '... got the right value from Fᶽ->fಓ');
is(Bᛆ->fಓ, 'Bᛆ::fಓ => ᕘ::fಓ', '... got the right value from Bᛆ->fಓ');

is(Baᕃ->fಓ, 'Baᕃ::fಓ => Bᛆ::fಓ => Fᶽ::fಓ => ᕘ::fಓ', '... got the right value using NEXT in a subclass of a C3 class');


__SCRIPT__

subtest 'tokenize' => sub {
    my $tokens = Compiler::Lexer->new('')->tokenize($script);
    is_deeply($tokens, [
          bless( {
                   'data' => 'use',
                   'name' => 'UseDecl',
                   'line' => 3,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 3,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'data' => 'strict',
                   'name' => 'UsedName'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 3,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'line' => 4,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 4,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'warnings',
                   'name' => 'UsedName'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 4,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 5,
                   'data' => 'use',
                   'name' => 'UseDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'UsedName',
                   'data' => 'NEXT',
                   'line' => 5,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UsedName
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 5,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 6,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'name' => 'UseDecl',
                   'data' => 'use'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'UsedName',
                   'data' => 'utf8',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 6,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 7,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'data' => 'use',
                   'name' => 'UseDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'open',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 7
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 7,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegList,
                   'data' => 'qw',
                   'name' => 'RegList'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegDelim',
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'line' => 7
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ' :utf8 :std ',
                   'name' => 'RegExp',
                   'line' => 7,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegExp
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 7,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegDelim',
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 7
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'chdir',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 9
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 't',
                   'name' => 'RawString',
                   'line' => 9,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 9,
                   'data' => 'if',
                   'name' => 'IfStmt'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 9,
                   'name' => 'Handle',
                   'data' => '-d'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'data' => 't',
                   'line' => 9,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 9
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RequireDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 10,
                   'name' => 'RequireDecl',
                   'data' => 'require'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 10,
                   'data' => './test.pl',
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 10,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 11,
                   'name' => 'Key',
                   'data' => 'plan'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'line' => 11,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 11,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'data' => 'tests'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=>',
                   'name' => 'Arrow',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 11
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'data' => '4',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 11
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'line' => 11,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 11,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 13,
                   'name' => 'LeftBrace',
                   'data' => '{'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Package,
                   'type' => Compiler::Lexer::TokenType::T_Package,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 14,
                   'data' => 'package',
                   'name' => 'Package'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'ᕘ',
                   'name' => 'Class',
                   'line' => 14,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Class,
                   'kind' => Compiler::Lexer::Kind::T_Class,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 14,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 15,
                   'name' => 'UseDecl',
                   'data' => 'use'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'UsedName',
                   'data' => 'strict',
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 15
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 15,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'use',
                   'name' => 'UseDecl',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'line' => 16
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 16,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'warnings',
                   'name' => 'UsedName'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 16
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'line' => 17,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'mro',
                   'name' => 'UsedName',
                   'line' => 17,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 17,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'data' => 'c3'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 17,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 19,
                   'data' => 'sub',
                   'name' => 'FunctionDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 19,
                   'type' => Compiler::Lexer::TokenType::T_Function,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Function',
                   'data' => 'fಓ'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'name' => 'LeftBrace',
                   'line' => 19,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 19,
                   'data' => 'ᕘ::fಓ',
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 19
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Package',
                   'data' => 'package',
                   'line' => 21,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Package,
                   'kind' => Compiler::Lexer::Kind::T_Package
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Class',
                   'data' => 'Fᶽ',
                   'line' => 21,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Class,
                   'type' => Compiler::Lexer::TokenType::T_Class,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 21,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'use',
                   'name' => 'UseDecl',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 22
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'strict',
                   'name' => 'UsedName',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'line' => 22
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 22,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'use',
                   'name' => 'UseDecl',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 23
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 23,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'UsedName',
                   'data' => 'warnings'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 23
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'line' => 24,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 24,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'mro',
                   'name' => 'UsedName'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'c3',
                   'name' => 'RawString',
                   'line' => 24,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 24,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'line' => 25,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 25,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'data' => 'base',
                   'name' => 'UsedName'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'data' => 'ᕘ',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 25
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 25,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 27,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'FunctionDecl',
                   'data' => 'sub'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Function',
                   'data' => 'fಓ',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Function,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'line' => 27,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'data' => 'Fᶽ::fಓ => ',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '.',
                   'name' => 'StringAdd',
                   'line' => 27,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_StringAdd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'line' => 27,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 27,
                   'name' => 'BuiltinFunc',
                   'data' => 'shift'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_Pointer,
                   'line' => 27,
                   'name' => 'Pointer',
                   'data' => '->'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'next',
                   'name' => 'Namespace',
                   'line' => 27,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'type' => Compiler::Lexer::TokenType::T_Namespace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_NamespaceResolver,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 27,
                   'name' => 'Namespace',
                   'data' => 'method'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBrace',
                   'data' => '}',
                   'line' => 27,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Package,
                   'type' => Compiler::Lexer::TokenType::T_Package,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 29,
                   'data' => 'package',
                   'name' => 'Package'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Class,
                   'kind' => Compiler::Lexer::Kind::T_Class,
                   'line' => 29,
                   'data' => 'Bᛆ',
                   'name' => 'Class'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 29,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'line' => 30,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'UsedName',
                   'data' => 'strict',
                   'line' => 30,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UsedName
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'line' => 30,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 31,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'use',
                   'name' => 'UseDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 31,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'data' => 'warnings',
                   'name' => 'UsedName'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'use',
                   'name' => 'UseDecl',
                   'line' => 32,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'UsedName',
                   'data' => 'mro',
                   'line' => 32,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'kind' => Compiler::Lexer::Kind::T_Module
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 32,
                   'data' => 'c3',
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 32,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 33,
                   'data' => 'use',
                   'name' => 'UseDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'base',
                   'name' => 'UsedName',
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 33
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'data' => 'ᕘ',
                   'line' => 33,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 33
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 35,
                   'data' => 'sub',
                   'name' => 'FunctionDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'fಓ',
                   'name' => 'Function',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Function,
                   'line' => 35
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'line' => 35,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'data' => 'Bᛆ::fಓ => ',
                   'line' => 35,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '.',
                   'name' => 'StringAdd',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_StringAdd,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 35
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'line' => 35,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'shift',
                   'name' => 'BuiltinFunc',
                   'line' => 35,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'line' => 35,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 35,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Pointer,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Pointer',
                   'data' => '->'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 35,
                   'data' => 'next',
                   'name' => 'Namespace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'line' => 35,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_NamespaceResolver,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'method',
                   'name' => 'Namespace',
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 35
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'name' => 'RightBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'line' => 35
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Package',
                   'data' => 'package',
                   'line' => 37,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Package,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Package
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'Baᕃ',
                   'name' => 'Class',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Class,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Class,
                   'line' => 37
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 37
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'line' => 38,
                   'data' => 'use',
                   'name' => 'UseDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'UsedName',
                   'data' => 'strict',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 38
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 38,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 39,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'data' => 'use',
                   'name' => 'UseDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'line' => 39,
                   'data' => 'warnings',
                   'name' => 'UsedName'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 39,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'line' => 41,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'base',
                   'name' => 'UsedName',
                   'line' => 41,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UsedName
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 41,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'data' => 'Bᛆ'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 41
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'data' => 'Fᶽ',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'line' => 41
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 41,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl,
                   'line' => 43,
                   'data' => 'sub',
                   'name' => 'FunctionDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 43,
                   'type' => Compiler::Lexer::TokenType::T_Function,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'fಓ',
                   'name' => 'Function'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 43,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBrace',
                   'data' => '{'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 43,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => 'Baᕃ::fಓ => ',
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'StringAdd',
                   'data' => '.',
                   'line' => 43,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_StringAdd,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'line' => 43,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'shift',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'line' => 43
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'line' => 43,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Pointer',
                   'data' => '->',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Pointer,
                   'line' => 43
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Namespace',
                   'data' => 'NEXT',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 43
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '::',
                   'name' => 'NamespaceResolver',
                   'line' => 43,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_NamespaceResolver,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 43,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'data' => 'fಓ',
                   'name' => 'Namespace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBrace',
                   'data' => '}',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 43
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 44,
                   'data' => '}',
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 46,
                   'name' => 'Key',
                   'data' => 'is'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'line' => 46,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 46,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Class,
                   'kind' => Compiler::Lexer::Kind::T_Class,
                   'name' => 'Class',
                   'data' => 'ᕘ'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Pointer,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 46,
                   'name' => 'Pointer',
                   'data' => '->'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Method,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 46,
                   'name' => 'Method',
                   'data' => 'fಓ'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 46,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 46,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'ᕘ::fಓ',
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 46,
                   'name' => 'Comma',
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'data' => '... got the right value from ᕘ->fಓ',
                   'line' => 46,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 46,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'is',
                   'name' => 'Key',
                   'line' => 47,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 47,
                   'data' => '(',
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Class,
                   'type' => Compiler::Lexer::TokenType::T_Class,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 47,
                   'name' => 'Class',
                   'data' => 'Fᶽ'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 47,
                   'type' => Compiler::Lexer::TokenType::T_Pointer,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '->',
                   'name' => 'Pointer'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Method',
                   'data' => 'fಓ',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Method,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 47
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'name' => 'Comma',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 47
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'data' => 'Fᶽ::fಓ => ᕘ::fಓ',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 47
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 47,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 47,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '... got the right value from Fᶽ->fಓ',
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 47,
                   'name' => 'RightParenthesis',
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 47,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'is',
                   'name' => 'Key',
                   'line' => 48,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'line' => 48,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Class',
                   'data' => 'Bᛆ',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Class,
                   'kind' => Compiler::Lexer::Kind::T_Class,
                   'line' => 48
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Pointer',
                   'data' => '->',
                   'type' => Compiler::Lexer::TokenType::T_Pointer,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 48
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'fಓ',
                   'name' => 'Method',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Method,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 48
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'name' => 'Comma',
                   'line' => 48,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 48,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'Bᛆ::fಓ => ᕘ::fಓ',
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 48
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 48,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'data' => '... got the right value from Bᛆ->fಓ'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 48
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 48,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'is',
                   'name' => 'Key',
                   'line' => 50,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 50,
                   'data' => '(',
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Class',
                   'data' => 'Baᕃ',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Class,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Class,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 50,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Pointer,
                   'data' => '->',
                   'name' => 'Pointer'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Method,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 50,
                   'data' => 'fಓ',
                   'name' => 'Method'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'data' => 'Baᕃ::fಓ => Bᛆ::fಓ => Fᶽ::fಓ => ᕘ::fಓ',
                   'line' => 50,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 50,
                   'name' => 'Comma',
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '... got the right value using NEXT in a subclass of a C3 class',
                   'name' => 'RawString',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 50,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => ')',
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' )
        ]
, 'Compiler::Lexer::tokenize');
};

subtest 'get_groups_by_syntax_level' => sub {
    my $lexer = Compiler::Lexer->new('');
    my $tokens = $lexer->tokenize($script);
    my $stmts = $lexer->get_groups_by_syntax_level($tokens, Compiler::Lexer::SyntaxType::T_Stmt);
    is_deeply($stmts, [
          {
            'indent' => 0,
            'src' => ' use strict ;',
            'start_line' => 3,
            'block_id' => 0,
            'token_num' => 3,
            'end_line' => 3,
            'has_warnings' => 0
          },
          {
            'start_line' => 4,
            'indent' => 0,
            'src' => ' use warnings ;',
            'has_warnings' => 0,
            'end_line' => 4,
            'token_num' => 3,
            'block_id' => 0
          },
          {
            'start_line' => 5,
            'src' => ' use NEXT ;',
            'indent' => 0,
            'end_line' => 5,
            'has_warnings' => 0,
            'token_num' => 3,
            'block_id' => 0
          },
          {
            'has_warnings' => 0,
            'end_line' => 6,
            'token_num' => 3,
            'block_id' => 0,
            'start_line' => 6,
            'src' => ' use utf8 ;',
            'indent' => 0
          },
          {
            'indent' => 0,
            'src' => ' use open qw( :utf8 :std ) ;',
            'start_line' => 7,
            'block_id' => 0,
            'token_num' => 7,
            'end_line' => 7,
            'has_warnings' => 0
          },
          {
            'has_warnings' => 0,
            'end_line' => 9,
            'block_id' => 0,
            'token_num' => 6,
            'start_line' => 9,
            'indent' => 0,
            'src' => ' chdir \'t\' if -d \'t\' ;'
          },
          {
            'token_num' => 3,
            'block_id' => 0,
            'has_warnings' => 0,
            'end_line' => 10,
            'start_line' => 10,
            'indent' => 0,
            'src' => ' require \'./test.pl\' ;'
          },
          {
            'has_warnings' => 1,
            'end_line' => 11,
            'token_num' => 7,
            'block_id' => 0,
            'start_line' => 11,
            'src' => ' plan ( tests => 4 ) ;',
            'indent' => 0
          },
          {
            'end_line' => 44,
            'has_warnings' => 1,
            'token_num' => 102,
            'block_id' => 0,
            'start_line' => 13,
            'src' => ' { package ᕘ ; use strict ; use warnings ; use mro \'c3\' ; sub fಓ { \'ᕘ::fಓ\' } package Fᶽ ; use strict ; use warnings ; use mro \'c3\' ; use base \'ᕘ\' ; sub fಓ { \'Fᶽ::fಓ => \' . ( shift )-> next::method } package Bᛆ ; use strict ; use warnings ; use mro \'c3\' ; use base \'ᕘ\' ; sub fಓ { \'Bᛆ::fಓ => \' . ( shift )-> next::method } package Baᕃ ; use strict ; use warnings ; use base \'Bᛆ\' , \'Fᶽ\' ; sub fಓ { \'Baᕃ::fಓ => \' . ( shift )-> NEXT::fಓ } }',
            'indent' => 0
          },
          {
            'token_num' => 3,
            'block_id' => 1,
            'has_warnings' => 1,
            'end_line' => 14,
            'indent' => 1,
            'src' => ' package ᕘ ;',
            'start_line' => 14
          },
          {
            'block_id' => 1,
            'token_num' => 3,
            'end_line' => 15,
            'has_warnings' => 0,
            'src' => ' use strict ;',
            'indent' => 1,
            'start_line' => 15
          },
          {
            'has_warnings' => 0,
            'end_line' => 16,
            'block_id' => 1,
            'token_num' => 3,
            'indent' => 1,
            'src' => ' use warnings ;',
            'start_line' => 16
          },
          {
            'indent' => 1,
            'src' => ' use mro \'c3\' ;',
            'start_line' => 17,
            'token_num' => 4,
            'block_id' => 1,
            'end_line' => 17,
            'has_warnings' => 0
          },
          {
            'end_line' => 19,
            'has_warnings' => 0,
            'block_id' => 1,
            'token_num' => 5,
            'start_line' => 19,
            'src' => ' sub fಓ { \'ᕘ::fಓ\' }',
            'indent' => 1
          },
          {
            'indent' => 1,
            'src' => ' package Fᶽ ;',
            'start_line' => 21,
            'end_line' => 21,
            'has_warnings' => 1,
            'token_num' => 3,
            'block_id' => 1
          },
          {
            'start_line' => 22,
            'indent' => 1,
            'src' => ' use strict ;',
            'end_line' => 22,
            'has_warnings' => 0,
            'block_id' => 1,
            'token_num' => 3
          },
          {
            'token_num' => 3,
            'block_id' => 1,
            'has_warnings' => 0,
            'end_line' => 23,
            'start_line' => 23,
            'indent' => 1,
            'src' => ' use warnings ;'
          },
          {
            'has_warnings' => 0,
            'end_line' => 24,
            'block_id' => 1,
            'token_num' => 4,
            'start_line' => 24,
            'src' => ' use mro \'c3\' ;',
            'indent' => 1
          },
          {
            'block_id' => 1,
            'token_num' => 4,
            'end_line' => 25,
            'has_warnings' => 0,
            'start_line' => 25,
            'src' => ' use base \'ᕘ\' ;',
            'indent' => 1
          },
          {
            'has_warnings' => 1,
            'end_line' => 27,
            'token_num' => 11,
            'block_id' => 1,
            'indent' => 1,
            'src' => ' sub fಓ { \'Fᶽ::fಓ => \' . ( shift )-> next::method }',
            'start_line' => 27
          },
          {
            'end_line' => 29,
            'has_warnings' => 1,
            'block_id' => 1,
            'token_num' => 3,
            'indent' => 1,
            'src' => ' package Bᛆ ;',
            'start_line' => 29
          },
          {
            'has_warnings' => 0,
            'end_line' => 30,
            'block_id' => 1,
            'token_num' => 3,
            'start_line' => 30,
            'indent' => 1,
            'src' => ' use strict ;'
          },
          {
            'end_line' => 31,
            'has_warnings' => 0,
            'block_id' => 1,
            'token_num' => 3,
            'start_line' => 31,
            'src' => ' use warnings ;',
            'indent' => 1
          },
          {
            'end_line' => 32,
            'has_warnings' => 0,
            'token_num' => 4,
            'block_id' => 1,
            'indent' => 1,
            'src' => ' use mro \'c3\' ;',
            'start_line' => 32
          },
          {
            'src' => ' use base \'ᕘ\' ;',
            'indent' => 1,
            'start_line' => 33,
            'token_num' => 4,
            'block_id' => 1,
            'end_line' => 33,
            'has_warnings' => 0
          },
          {
            'has_warnings' => 1,
            'end_line' => 35,
            'block_id' => 1,
            'token_num' => 11,
            'indent' => 1,
            'src' => ' sub fಓ { \'Bᛆ::fಓ => \' . ( shift )-> next::method }',
            'start_line' => 35
          },
          {
            'has_warnings' => 1,
            'end_line' => 37,
            'block_id' => 1,
            'token_num' => 3,
            'start_line' => 37,
            'src' => ' package Baᕃ ;',
            'indent' => 1
          },
          {
            'start_line' => 38,
            'indent' => 1,
            'src' => ' use strict ;',
            'end_line' => 38,
            'has_warnings' => 0,
            'block_id' => 1,
            'token_num' => 3
          },
          {
            'token_num' => 3,
            'block_id' => 1,
            'end_line' => 39,
            'has_warnings' => 0,
            'start_line' => 39,
            'indent' => 1,
            'src' => ' use warnings ;'
          },
          {
            'indent' => 1,
            'src' => ' use base \'Bᛆ\' , \'Fᶽ\' ;',
            'start_line' => 41,
            'end_line' => 41,
            'has_warnings' => 0,
            'token_num' => 6,
            'block_id' => 1
          },
          {
            'block_id' => 1,
            'token_num' => 11,
            'end_line' => 43,
            'has_warnings' => 1,
            'src' => ' sub fಓ { \'Baᕃ::fಓ => \' . ( shift )-> NEXT::fಓ }',
            'indent' => 1,
            'start_line' => 43
          },
          {
            'token_num' => 11,
            'block_id' => 0,
            'has_warnings' => 1,
            'end_line' => 46,
            'start_line' => 46,
            'indent' => 0,
            'src' => ' is ( ᕘ-> fಓ , \'ᕘ::fಓ\' , \'... got the right value from ᕘ->fಓ\' ) ;'
          },
          {
            'src' => ' is ( Fᶽ-> fಓ , \'Fᶽ::fಓ => ᕘ::fಓ\' , \'... got the right value from Fᶽ->fಓ\' ) ;',
            'indent' => 0,
            'start_line' => 47,
            'has_warnings' => 1,
            'end_line' => 47,
            'block_id' => 0,
            'token_num' => 11
          },
          {
            'block_id' => 0,
            'token_num' => 11,
            'end_line' => 48,
            'has_warnings' => 1,
            'start_line' => 48,
            'indent' => 0,
            'src' => ' is ( Bᛆ-> fಓ , \'Bᛆ::fಓ => ᕘ::fಓ\' , \'... got the right value from Bᛆ->fಓ\' ) ;'
          },
          {
            'token_num' => 11,
            'block_id' => 0,
            'has_warnings' => 1,
            'end_line' => 50,
            'src' => ' is ( Baᕃ-> fಓ , \'Baᕃ::fಓ => Bᛆ::fಓ => Fᶽ::fಓ => ᕘ::fಓ\' , \'... got the right value using NEXT in a subclass of a C3 class\' ) ;',
            'indent' => 0,
            'start_line' => 50
          }
        ]
, 'Compiler::Lexer::get_groups_by_syntax_level');
};

subtest 'get_used_modules' => sub {
    my $modules = Compiler::Lexer->new('')->get_used_modules($script);
    is_deeply($modules, [
          {
            'name' => 'strict',
            'args' => ''
          },
          {
            'args' => '',
            'name' => 'warnings'
          },
          {
            'name' => 'NEXT',
            'args' => ''
          },
          {
            'name' => 'utf8',
            'args' => ''
          },
          {
            'args' => '  qw (  :utf8 :std  )',
            'name' => 'open'
          },
          {
            'args' => '',
            'name' => 'strict'
          },
          {
            'args' => '',
            'name' => 'warnings'
          },
          {
            'name' => 'mro',
            'args' => '  \'c3\''
          },
          {
            'name' => 'strict',
            'args' => ''
          },
          {
            'name' => 'warnings',
            'args' => ''
          },
          {
            'name' => 'mro',
            'args' => '  \'c3\''
          },
          {
            'args' => '  \'ᕘ\'',
            'name' => 'base'
          },
          {
            'name' => 'strict',
            'args' => ''
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
            'args' => '  \'ᕘ\'',
            'name' => 'base'
          },
          {
            'args' => '',
            'name' => 'strict'
          },
          {
            'name' => 'warnings',
            'args' => ''
          },
          {
            'name' => 'base',
            'args' => '  \'Bᛆ\'  ,  \'Fᶽ\''
          }
        ]
, 'Compiler::Lexer::get_used_modules');
};

done_testing;
