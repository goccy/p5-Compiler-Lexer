use strict;
use warnings;
use Test::More;
BEGIN {
    use_ok('Compiler::Lexer');
}
my $script =<<'__SCRIPT__';
#!./perl

use strict;
use warnings;

require q(./test.pl); plan(tests => 2);

=pod

This tests a strange bug found by Matt S. Trout 
while building DBIx::Class. Thanks Matt!!!! 

   <A>
  /   \
<C>   <B>
  \   /
   <D>

=cut

{
    package Diamond_A;
    use mro 'dfs'; 

    sub foo { 'Diamond_A::foo' }
}
{
    package Diamond_B;
    use base 'Diamond_A';
    use mro 'dfs';     

    sub foo { 'Diamond_B::foo => ' . (shift)->SUPER::foo }
}
{
    package Diamond_C;
    use mro 'dfs';    
    use base 'Diamond_A';     

}
{
    package Diamond_D;
    use base ('Diamond_C', 'Diamond_B');
    use mro 'dfs';    
    
    sub foo { 'Diamond_D::foo => ' . (shift)->SUPER::foo }    
}

ok(eq_array(
    mro::get_linear_isa('Diamond_D'),
    [ qw(Diamond_D Diamond_C Diamond_A Diamond_B) ]
), '... got the right MRO for Diamond_D');

is(Diamond_D->foo, 
   'Diamond_D::foo => Diamond_A::foo', 
   '... got the right next::method dispatch path');

__SCRIPT__

subtest 'tokenize' => sub {
    my $tokens = Compiler::Lexer->new('')->tokenize($script);
    is_deeply($tokens, [
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'use',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'line' => 3,
                   'name' => 'UseDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'data' => 'strict',
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'name' => 'UsedName',
                   'line' => 3
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'line' => 3
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 4,
                   'name' => 'UseDecl',
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'data' => 'use',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 4,
                   'name' => 'UsedName',
                   'data' => 'warnings',
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 4,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RequireDecl',
                   'line' => 6,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'require',
                   'type' => Compiler::Lexer::TokenType::T_RequireDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegQuote',
                   'line' => 6,
                   'type' => Compiler::Lexer::TokenType::T_RegQuote,
                   'data' => 'q',
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 6,
                   'name' => 'RegDelim'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => './test.pl',
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'line' => 6,
                   'name' => 'RegExp'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegDelim',
                   'line' => 6,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'plan',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 6,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'line' => 6,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'line' => 6,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'tests',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Arrow',
                   'line' => 6,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '=>',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'line' => 6,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '2',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Int
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 6,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 6,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'LeftBrace',
                   'line' => 21
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Package,
                   'data' => 'package',
                   'kind' => Compiler::Lexer::Kind::T_Package,
                   'name' => 'Package',
                   'line' => 22
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Class',
                   'line' => 22,
                   'data' => 'Diamond_A',
                   'type' => Compiler::Lexer::TokenType::T_Class,
                   'kind' => Compiler::Lexer::Kind::T_Class,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'line' => 22
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'data' => 'use',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 23,
                   'name' => 'UseDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 23,
                   'name' => 'UsedName',
                   'data' => 'mro',
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'dfs',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'RawString',
                   'line' => 23
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'line' => 23
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'sub',
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 25,
                   'name' => 'FunctionDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 25,
                   'name' => 'Function',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'data' => 'foo',
                   'type' => Compiler::Lexer::TokenType::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'line' => 25,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'Diamond_A::foo',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'line' => 25,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 25,
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'data' => '}',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 26,
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'line' => 27,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Package',
                   'line' => 28,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'package',
                   'type' => Compiler::Lexer::TokenType::T_Package,
                   'kind' => Compiler::Lexer::Kind::T_Package
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Class',
                   'line' => 28,
                   'data' => 'Diamond_B',
                   'kind' => Compiler::Lexer::Kind::T_Class,
                   'type' => Compiler::Lexer::TokenType::T_Class,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 28,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'use',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'UseDecl',
                   'line' => 29
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'base',
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'name' => 'UsedName',
                   'line' => 29
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'Diamond_A',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 29,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'line' => 29,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 30,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'mro',
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'line' => 30,
                   'name' => 'UsedName'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'dfs',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'line' => 30,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'line' => 30
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 32,
                   'name' => 'FunctionDecl',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl,
                   'data' => 'sub',
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'data' => 'foo',
                   'type' => Compiler::Lexer::TokenType::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'Function',
                   'line' => 32
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'line' => 32,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '{',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'line' => 32,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => 'Diamond_B::foo => ',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'StringAdd',
                   'line' => 32,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'data' => '.',
                   'type' => Compiler::Lexer::TokenType::T_StringAdd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 32,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'shift',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'BuiltinFunc',
                   'line' => 32
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'line' => 32
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'data' => '->',
                   'type' => Compiler::Lexer::TokenType::T_Pointer,
                   'name' => 'Pointer',
                   'line' => 32
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Namespace',
                   'line' => 32,
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'data' => 'SUPER',
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 32,
                   'name' => 'NamespaceResolver',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '::',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_NamespaceResolver
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'data' => 'foo',
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'name' => 'Namespace',
                   'line' => 32
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 32,
                   'name' => 'RightBrace',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightBrace',
                   'line' => 33
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'line' => 34
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Package',
                   'line' => 35,
                   'data' => 'package',
                   'kind' => Compiler::Lexer::Kind::T_Package,
                   'type' => Compiler::Lexer::TokenType::T_Package,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 35,
                   'name' => 'Class',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Class,
                   'data' => 'Diamond_C',
                   'type' => Compiler::Lexer::TokenType::T_Class
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 35,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'data' => 'use',
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'line' => 36,
                   'name' => 'UseDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'UsedName',
                   'line' => 36,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'mro',
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'type' => Compiler::Lexer::TokenType::T_UsedName
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'line' => 36,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'dfs',
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'line' => 36
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 37,
                   'name' => 'UseDecl',
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'data' => 'use',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 37,
                   'name' => 'UsedName',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'base',
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'kind' => Compiler::Lexer::Kind::T_Module
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'line' => 37,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => 'Diamond_A',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 37,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'data' => '}',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'RightBrace',
                   'line' => 39
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'LeftBrace',
                   'line' => 40
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Package',
                   'line' => 41,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Package,
                   'data' => 'package',
                   'type' => Compiler::Lexer::TokenType::T_Package
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 41,
                   'name' => 'Class',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Class,
                   'data' => 'Diamond_D',
                   'kind' => Compiler::Lexer::Kind::T_Class
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'line' => 41,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 42,
                   'name' => 'UseDecl',
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'data' => 'use',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'base',
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'name' => 'UsedName',
                   'line' => 42
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 42,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 42,
                   'name' => 'RawString',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'Diamond_C',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'line' => 42,
                   'data' => ',',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'Diamond_B',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 42,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 42,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'line' => 42
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 43,
                   'name' => 'UseDecl',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'data' => 'use',
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'mro',
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'UsedName',
                   'line' => 43
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'dfs',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 43,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'line' => 43,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'sub',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl,
                   'name' => 'FunctionDecl',
                   'line' => 45
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'foo',
                   'type' => Compiler::Lexer::TokenType::T_Function,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'Function',
                   'line' => 45
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '{',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'LeftBrace',
                   'line' => 45
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'Diamond_D::foo => ',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'line' => 45
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'data' => '.',
                   'type' => Compiler::Lexer::TokenType::T_StringAdd,
                   'line' => 45,
                   'name' => 'StringAdd'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 45,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'data' => 'shift',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'line' => 45,
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 45,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Pointer,
                   'data' => '->',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 45,
                   'name' => 'Pointer'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'SUPER',
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'Namespace',
                   'line' => 45
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '::',
                   'type' => Compiler::Lexer::TokenType::T_NamespaceResolver,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'NamespaceResolver',
                   'line' => 45
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 45,
                   'name' => 'Namespace',
                   'data' => 'foo',
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'line' => 45,
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'line' => 46,
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'ok',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'line' => 48
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 48,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'line' => 48,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'eq_array',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'line' => 48
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'mro',
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'line' => 49,
                   'name' => 'Namespace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '::',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_NamespaceResolver,
                   'line' => 49,
                   'name' => 'NamespaceResolver'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'get_linear_isa',
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'Namespace',
                   'line' => 49
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 49,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'line' => 49,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'Diamond_D',
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'line' => 49,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'line' => 49
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '[',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 50,
                   'name' => 'LeftBracket'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegList,
                   'data' => 'qw',
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 50,
                   'name' => 'RegList'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 50,
                   'name' => 'RegDelim'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'data' => 'Diamond_D Diamond_C Diamond_A Diamond_B',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegExp',
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 50,
                   'name' => 'RightBracket',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'data' => ']',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'line' => 51
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 51,
                   'name' => 'Comma',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 51,
                   'name' => 'RawString',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '... got the right MRO for Diamond_D',
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'line' => 51
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 51,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'is',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'line' => 53,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 53,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Class',
                   'line' => 53,
                   'type' => Compiler::Lexer::TokenType::T_Class,
                   'data' => 'Diamond_D',
                   'kind' => Compiler::Lexer::Kind::T_Class,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'data' => '->',
                   'type' => Compiler::Lexer::TokenType::T_Pointer,
                   'line' => 53,
                   'name' => 'Pointer'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'foo',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_Method,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Method',
                   'line' => 53
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 53,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'line' => 54,
                   'data' => 'Diamond_D::foo => Diamond_A::foo',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 54,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'line' => 55,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '... got the right next::method dispatch path',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 55,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'line' => 55
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
            'start_line' => 3,
            'block_id' => 0,
            'src' => ' use strict ;',
            'token_num' => 3,
            'end_line' => 3,
            'has_warnings' => 0
          },
          {
            'has_warnings' => 0,
            'end_line' => 4,
            'src' => ' use warnings ;',
            'token_num' => 3,
            'start_line' => 4,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'has_warnings' => 0,
            'end_line' => 6,
            'token_num' => 6,
            'src' => ' require q(./test.pl) ;',
            'indent' => 0,
            'start_line' => 6,
            'block_id' => 0
          },
          {
            'end_line' => 6,
            'has_warnings' => 1,
            'block_id' => 0,
            'start_line' => 6,
            'indent' => 0,
            'src' => ' plan ( tests => 2 ) ;',
            'token_num' => 7
          },
          {
            'src' => ' { package Diamond_A ; use mro \'dfs\' ; sub foo { \'Diamond_A::foo\' } }',
            'token_num' => 14,
            'start_line' => 21,
            'indent' => 0,
            'block_id' => 0,
            'has_warnings' => 1,
            'end_line' => 26
          },
          {
            'has_warnings' => 1,
            'end_line' => 22,
            'src' => ' package Diamond_A ;',
            'token_num' => 3,
            'block_id' => 1,
            'start_line' => 22,
            'indent' => 1
          },
          {
            'token_num' => 4,
            'src' => ' use mro \'dfs\' ;',
            'start_line' => 23,
            'block_id' => 1,
            'indent' => 1,
            'has_warnings' => 0,
            'end_line' => 23
          },
          {
            'src' => ' sub foo { \'Diamond_A::foo\' }',
            'token_num' => 5,
            'start_line' => 25,
            'block_id' => 1,
            'indent' => 1,
            'has_warnings' => 0,
            'end_line' => 25
          },
          {
            'end_line' => 33,
            'has_warnings' => 1,
            'start_line' => 27,
            'indent' => 0,
            'block_id' => 0,
            'src' => ' { package Diamond_B ; use base \'Diamond_A\' ; use mro \'dfs\' ; sub foo { \'Diamond_B::foo => \' . ( shift )-> SUPER::foo } }',
            'token_num' => 24
          },
          {
            'end_line' => 28,
            'has_warnings' => 1,
            'start_line' => 28,
            'block_id' => 3,
            'indent' => 1,
            'token_num' => 3,
            'src' => ' package Diamond_B ;'
          },
          {
            'block_id' => 3,
            'start_line' => 29,
            'indent' => 1,
            'token_num' => 4,
            'src' => ' use base \'Diamond_A\' ;',
            'end_line' => 29,
            'has_warnings' => 0
          },
          {
            'end_line' => 30,
            'has_warnings' => 0,
            'block_id' => 3,
            'start_line' => 30,
            'indent' => 1,
            'token_num' => 4,
            'src' => ' use mro \'dfs\' ;'
          },
          {
            'src' => ' sub foo { \'Diamond_B::foo => \' . ( shift )-> SUPER::foo }',
            'token_num' => 11,
            'indent' => 1,
            'start_line' => 32,
            'block_id' => 3,
            'has_warnings' => 1,
            'end_line' => 32
          },
          {
            'end_line' => 39,
            'has_warnings' => 1,
            'block_id' => 0,
            'start_line' => 34,
            'indent' => 0,
            'src' => ' { package Diamond_C ; use mro \'dfs\' ; use base \'Diamond_A\' ; }',
            'token_num' => 13
          },
          {
            'end_line' => 35,
            'has_warnings' => 1,
            'start_line' => 35,
            'block_id' => 5,
            'indent' => 1,
            'src' => ' package Diamond_C ;',
            'token_num' => 3
          },
          {
            'token_num' => 4,
            'src' => ' use mro \'dfs\' ;',
            'block_id' => 5,
            'start_line' => 36,
            'indent' => 1,
            'has_warnings' => 0,
            'end_line' => 36
          },
          {
            'src' => ' use base \'Diamond_A\' ;',
            'token_num' => 4,
            'block_id' => 5,
            'start_line' => 37,
            'indent' => 1,
            'has_warnings' => 0,
            'end_line' => 37
          },
          {
            'end_line' => 46,
            'has_warnings' => 1,
            'start_line' => 40,
            'indent' => 0,
            'block_id' => 0,
            'token_num' => 28,
            'src' => ' { package Diamond_D ; use base ( \'Diamond_C\' , \'Diamond_B\' ) ; use mro \'dfs\' ; sub foo { \'Diamond_D::foo => \' . ( shift )-> SUPER::foo } }'
          },
          {
            'end_line' => 41,
            'has_warnings' => 1,
            'start_line' => 41,
            'indent' => 1,
            'block_id' => 6,
            'src' => ' package Diamond_D ;',
            'token_num' => 3
          },
          {
            'has_warnings' => 0,
            'end_line' => 42,
            'token_num' => 8,
            'src' => ' use base ( \'Diamond_C\' , \'Diamond_B\' ) ;',
            'indent' => 1,
            'start_line' => 42,
            'block_id' => 6
          },
          {
            'src' => ' use mro \'dfs\' ;',
            'token_num' => 4,
            'start_line' => 43,
            'indent' => 1,
            'block_id' => 6,
            'has_warnings' => 0,
            'end_line' => 43
          },
          {
            'token_num' => 11,
            'src' => ' sub foo { \'Diamond_D::foo => \' . ( shift )-> SUPER::foo }',
            'indent' => 1,
            'start_line' => 45,
            'block_id' => 6,
            'has_warnings' => 1,
            'end_line' => 45
          },
          {
            'end_line' => 51,
            'has_warnings' => 1,
            'indent' => 0,
            'start_line' => 48,
            'block_id' => 0,
            'src' => ' ok ( eq_array ( mro::get_linear_isa ( \'Diamond_D\' ) , [ qw(Diamond_D Diamond_C Diamond_A Diamond_B) ] ) , \'... got the right MRO for Diamond_D\' ) ;',
            'token_num' => 20
          },
          {
            'has_warnings' => 1,
            'end_line' => 55,
            'token_num' => 11,
            'src' => ' is ( Diamond_D-> foo , \'Diamond_D::foo => Diamond_A::foo\' , \'... got the right next::method dispatch path\' ) ;',
            'block_id' => 0,
            'start_line' => 53,
            'indent' => 0
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
            'name' => 'mro',
            'args' => '  \'dfs\''
          },
          {
            'args' => '  \'Diamond_A\'',
            'name' => 'base'
          },
          {
            'name' => 'mro',
            'args' => '  \'dfs\''
          },
          {
            'name' => 'mro',
            'args' => '  \'dfs\''
          },
          {
            'args' => '  \'Diamond_A\'',
            'name' => 'base'
          },
          {
            'name' => 'base',
            'args' => '  ( \'Diamond_C\' , \'Diamond_B\' )'
          },
          {
            'name' => 'mro',
            'args' => '  \'dfs\''
          }
        ]
, 'Compiler::Lexer::get_used_modules');
};

done_testing;
