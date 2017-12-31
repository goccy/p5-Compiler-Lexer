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

BEGIN { chdir 't' if -d 't'; require q(./test.pl); @INC = qw "../lib lib" }

plan(tests => 12);

{

    {
        package Foo;
        use strict;
        use warnings;
        use mro 'c3';
        sub new { bless {}, $_[0] }
        sub bar { 'Foo::bar' }
    }

    # call the submethod in the direct instance

    my $foo = Foo->new();
    object_ok($foo, 'Foo');

    can_ok($foo, 'bar');
    is($foo->bar(), 'Foo::bar', '... got the right return value');    

    # fail calling it from a subclass

    {
        package Bar;
        use strict;
        use warnings;
        use mro 'c3';
        our @ISA = ('Foo');
    }  
    
    my $bar = Bar->new();
    object_ok($bar, 'Bar');
    object_ok($bar, 'Foo');    
    
    # test it working with with Sub::Name
    SKIP: {    
        eval 'use Sub::Name';
        skip("Sub::Name is required for this test", 3) if $@;
    
        my $m = sub { (shift)->next::method() };
        Sub::Name::subname('Bar::bar', $m);
        {
            no strict 'refs';
            *{'Bar::bar'} = $m;
        }

        can_ok($bar, 'bar');
        my $value = eval { $bar->bar() };
        ok(!$@, '... calling bar() succeeded') || diag $@;
        is($value, 'Foo::bar', '... got the right return value too');
    }
    
    # test it failing without Sub::Name
    {
        package Baz;
        use strict;
        use warnings;
        use mro 'c3';
        our @ISA = ('Foo');
    }      
    
    my $baz = Baz->new();
    object_ok($baz, 'Baz');
    object_ok($baz, 'Foo');    
    
    {
        my $m = sub { (shift)->next::method() };
        {
            no strict 'refs';
            *{'Baz::bar'} = $m;
        }

        eval { $baz->bar() };
        ok($@, '... calling bar() with next::method failed') || diag $@;
    }

    # Test with non-existing class (used to segfault)
    {
        package Qux;
        use mro;
        sub foo { No::Such::Class->next::can }
    }

    eval { Qux->foo() };
    is($@, '', "->next::can on non-existing package name");

}

__SCRIPT__

subtest 'tokenize' => sub {
    my $tokens = Compiler::Lexer->new('')->tokenize($script);
    is_deeply($tokens, [
          bless( {
                   'line' => 3,
                   'name' => 'UseDecl',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'data' => 'use',
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 3,
                   'name' => 'UsedName',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'strict',
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'kind' => Compiler::Lexer::Kind::T_Module
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 3,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'UseDecl',
                   'line' => 4,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'use',
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'warnings',
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'line' => 4,
                   'name' => 'UsedName'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 4,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ModWord,
                   'data' => 'BEGIN',
                   'kind' => Compiler::Lexer::Kind::T_ModWord,
                   'line' => 6,
                   'name' => 'ModWord'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'line' => 6,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'data' => 'chdir',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'BuiltinFunc',
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 6,
                   'name' => 'RawString',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 't',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'data' => 'if',
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'IfStmt',
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-d',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Handle',
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 6,
                   'name' => 'RawString',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 't',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 6,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 6,
                   'name' => 'RequireDecl',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'data' => 'require',
                   'type' => Compiler::Lexer::TokenType::T_RequireDecl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegQuote',
                   'line' => 6,
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'data' => 'q',
                   'type' => Compiler::Lexer::TokenType::T_RegQuote,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegDelim',
                   'line' => 6,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegExp',
                   'line' => 6,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => './test.pl',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegExp
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 6,
                   'name' => 'RegDelim',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LibraryDirectories,
                   'data' => '@INC',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 6,
                   'name' => 'LibraryDirectories'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'line' => 6,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'data' => '=',
                   'kind' => Compiler::Lexer::Kind::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 6,
                   'name' => 'RegList',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegList,
                   'data' => 'qw',
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '../lib lib',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'line' => 6,
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'plan',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 8,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'line' => 8,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 8,
                   'name' => 'Key',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'tests',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 8,
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'data' => '=>',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'line' => 8,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '12',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'line' => 8,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'line' => 8,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBrace',
                   'line' => 10
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 12,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '{',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 13,
                   'name' => 'Package',
                   'data' => 'package',
                   'kind' => Compiler::Lexer::Kind::T_Package,
                   'type' => Compiler::Lexer::TokenType::T_Package,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Class',
                   'line' => 13,
                   'type' => Compiler::Lexer::TokenType::T_Class,
                   'data' => 'Foo',
                   'kind' => Compiler::Lexer::Kind::T_Class,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 13,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'UseDecl',
                   'line' => 14,
                   'data' => 'use',
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 14,
                   'name' => 'UsedName',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'data' => 'strict',
                   'type' => Compiler::Lexer::TokenType::T_UsedName
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'line' => 14
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 15,
                   'name' => 'UseDecl',
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'data' => 'use',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'warnings',
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'name' => 'UsedName',
                   'line' => 15
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'line' => 15
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'data' => 'use',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'UseDecl',
                   'line' => 16
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'data' => 'mro',
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'name' => 'UsedName',
                   'line' => 16
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'line' => 16,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'c3',
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 16,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 17,
                   'name' => 'FunctionDecl',
                   'data' => 'sub',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 17,
                   'name' => 'Function',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'data' => 'new',
                   'type' => Compiler::Lexer::TokenType::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'LeftBrace',
                   'line' => 17
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'data' => 'bless',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'line' => 17
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 17,
                   'name' => 'LeftBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 17,
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'line' => 17
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 17,
                   'name' => 'SpecificValue',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$_',
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '[',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 17,
                   'name' => 'LeftBracket'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '0',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 17,
                   'name' => 'Int'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ']',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 17,
                   'name' => 'RightBracket'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'line' => 17
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'FunctionDecl',
                   'line' => 18,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'sub',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 18,
                   'name' => 'Function',
                   'type' => Compiler::Lexer::TokenType::T_Function,
                   'data' => 'bar',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'line' => 18,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => 'Foo::bar',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 18,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 18,
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'data' => '}',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace',
                   'line' => 19
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'VarDecl',
                   'line' => 23,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'my',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LocalVar',
                   'line' => 23,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$foo',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'Assign',
                   'line' => 23
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'Foo',
                   'kind' => Compiler::Lexer::Kind::T_Class,
                   'type' => Compiler::Lexer::TokenType::T_Class,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 23,
                   'name' => 'Class'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Pointer',
                   'line' => 23,
                   'data' => '->',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_Pointer,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Method,
                   'data' => 'new',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 23,
                   'name' => 'Method'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 23,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 23,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'line' => 23
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 24,
                   'name' => 'Key',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'object_ok',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'line' => 24,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '$foo',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'line' => 24
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'line' => 24
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 24,
                   'name' => 'RawString',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'Foo',
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 24,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'line' => 24,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'line' => 26,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'data' => 'can_ok',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 26,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$foo',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'line' => 26
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'line' => 26
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => 'bar',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'RawString',
                   'line' => 26
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 26,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'line' => 26,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'line' => 27,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'is',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'line' => 27,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$foo',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Pointer',
                   'line' => 27,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'data' => '->',
                   'type' => Compiler::Lexer::TokenType::T_Pointer,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Method',
                   'line' => 27,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Method,
                   'data' => 'bar',
                   'kind' => Compiler::Lexer::Kind::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 27,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'line' => 27,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 27,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'Foo::bar',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 27,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 27,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '... got the right return value',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightParenthesis',
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 31,
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Package,
                   'data' => 'package',
                   'type' => Compiler::Lexer::TokenType::T_Package,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 32,
                   'name' => 'Package'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Class',
                   'line' => 32,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Class,
                   'data' => 'Bar',
                   'type' => Compiler::Lexer::TokenType::T_Class
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 32,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'UseDecl',
                   'line' => 33,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'use',
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'data' => 'strict',
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'line' => 33,
                   'name' => 'UsedName'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'line' => 33
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'data' => 'use',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'UseDecl',
                   'line' => 34
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 34,
                   'name' => 'UsedName',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'data' => 'warnings',
                   'type' => Compiler::Lexer::TokenType::T_UsedName
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'line' => 34
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 35,
                   'name' => 'UseDecl',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'use',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'data' => 'mro',
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'name' => 'UsedName',
                   'line' => 35
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'line' => 35,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => 'c3',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 35,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'our',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_OurDecl,
                   'line' => 36,
                   'name' => 'OurDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '@ISA',
                   'type' => Compiler::Lexer::TokenType::T_GlobalArrayVar,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 36,
                   'name' => 'GlobalArrayVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'Assign',
                   'line' => 36
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'line' => 36
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'Foo',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'line' => 36
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'RightParenthesis',
                   'line' => 36
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 36,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 37,
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl',
                   'line' => 39
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'data' => '$bar',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LocalVar',
                   'line' => 39
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'data' => '=',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'Assign',
                   'line' => 39
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Class,
                   'data' => 'Bar',
                   'kind' => Compiler::Lexer::Kind::T_Class,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'Class',
                   'line' => 39
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'data' => '->',
                   'type' => Compiler::Lexer::TokenType::T_Pointer,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 39,
                   'name' => 'Pointer'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Method',
                   'line' => 39,
                   'type' => Compiler::Lexer::TokenType::T_Method,
                   'data' => 'new',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 39,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'line' => 39
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'line' => 39,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'object_ok',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 40,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'line' => 40
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'line' => 40,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$bar',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'line' => 40
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => 'Bar',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'line' => 40
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'line' => 40,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 40,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 41,
                   'name' => 'Key',
                   'has_warnings' => 1,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'object_ok',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'LeftParenthesis',
                   'line' => 41
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$bar',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'line' => 41,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 41,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'Foo',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'line' => 41
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'line' => 41,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 41,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'line' => 44,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'SKIP',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 44,
                   'name' => 'Colon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Colon,
                   'data' => ':',
                   'kind' => Compiler::Lexer::Kind::T_Colon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftBrace',
                   'line' => 44
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'data' => 'eval',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'BuiltinFunc',
                   'line' => 45
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 45,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => 'use Sub::Name',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'line' => 45,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'line' => 46,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'skip',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'line' => 46,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 46,
                   'name' => 'String',
                   'data' => 'Sub::Name is required for this test',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 46,
                   'name' => 'Int',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'data' => '3',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 46,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'IfStmt',
                   'line' => 46,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'data' => 'if',
                   'kind' => Compiler::Lexer::Kind::T_Stmt
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SpecificValue',
                   'line' => 46,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$@',
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'line' => 46,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'data' => 'my',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'VarDecl',
                   'line' => 48
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$m',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LocalVar',
                   'line' => 48
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'data' => '=',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Assign',
                   'line' => 48
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 48,
                   'name' => 'FunctionDecl',
                   'data' => 'sub',
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'LeftBrace',
                   'line' => 48
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 48,
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 48,
                   'name' => 'BuiltinFunc',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'data' => 'shift',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'RightParenthesis',
                   'line' => 48
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Pointer',
                   'line' => 48,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '->',
                   'type' => Compiler::Lexer::TokenType::T_Pointer,
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'data' => 'next',
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'name' => 'Namespace',
                   'line' => 48
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 48,
                   'name' => 'NamespaceResolver',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_NamespaceResolver,
                   'data' => '::',
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 48,
                   'name' => 'Namespace',
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'data' => 'method',
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 48,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'line' => 48
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 48,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 48,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 49,
                   'name' => 'Namespace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'data' => 'Sub',
                   'kind' => Compiler::Lexer::Kind::T_Namespace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 49,
                   'name' => 'NamespaceResolver',
                   'type' => Compiler::Lexer::TokenType::T_NamespaceResolver,
                   'data' => '::',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 49,
                   'name' => 'Namespace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'Name',
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'type' => Compiler::Lexer::TokenType::T_Namespace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 49,
                   'name' => 'NamespaceResolver',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '::',
                   'type' => Compiler::Lexer::TokenType::T_NamespaceResolver,
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 49,
                   'name' => 'Namespace',
                   'data' => 'subname',
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 49,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'Bar::bar',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'line' => 49
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 49,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'line' => 49,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '$m',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'line' => 49,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 49,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'line' => 50,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'data' => 'no',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 51,
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'strict',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'line' => 51
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'refs',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'RawString',
                   'line' => 51
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'line' => 51,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 52,
                   'name' => 'Glob',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '*',
                   'type' => Compiler::Lexer::TokenType::T_Glob,
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 52,
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'Bar::bar',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 52,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 52,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 52,
                   'name' => 'Assign',
                   'data' => '=',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$m',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'line' => 52
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 52,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 53,
                   'name' => 'RightBrace',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'data' => '}',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'data' => 'can_ok',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 55,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 55,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$bar',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'line' => 55
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'line' => 55
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'bar',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'line' => 55
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'RightParenthesis',
                   'line' => 55
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 55,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'VarDecl',
                   'line' => 56,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 56,
                   'name' => 'LocalVar',
                   'data' => '$value',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'line' => 56,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'data' => '=',
                   'kind' => Compiler::Lexer::Kind::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'data' => 'eval',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'line' => 56
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'line' => 56,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$bar',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'line' => 56
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Pointer',
                   'line' => 56,
                   'type' => Compiler::Lexer::TokenType::T_Pointer,
                   'data' => '->',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'bar',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_Method,
                   'line' => 56,
                   'name' => 'Method'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'line' => 56,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'line' => 56,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'line' => 56
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 56,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 57,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'ok',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 57,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 57,
                   'name' => 'Not',
                   'type' => Compiler::Lexer::TokenType::T_Not,
                   'data' => '!',
                   'kind' => Compiler::Lexer::Kind::T_SingleTerm,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$@',
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SpecificValue',
                   'line' => 57
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 57,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'line' => 57,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '... calling bar() succeeded',
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 57,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Or,
                   'data' => '||',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 57,
                   'name' => 'Or'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'diag',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 1,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'line' => 57
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$@',
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 57,
                   'name' => 'SpecificValue'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 57,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'is',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'name' => 'Key',
                   'line' => 58
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 58,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$value',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'line' => 58
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'line' => 58
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 58,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => 'Foo::bar',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'line' => 58
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 58,
                   'name' => 'RawString',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '... got the right return value too',
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 58,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'line' => 58
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 59,
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
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
                   'line' => 62
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Package',
                   'line' => 63,
                   'type' => Compiler::Lexer::TokenType::T_Package,
                   'data' => 'package',
                   'kind' => Compiler::Lexer::Kind::T_Package,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 63,
                   'name' => 'Class',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'Baz',
                   'kind' => Compiler::Lexer::Kind::T_Class,
                   'type' => Compiler::Lexer::TokenType::T_Class
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'line' => 63
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'use',
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 64,
                   'name' => 'UseDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'data' => 'strict',
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'line' => 64,
                   'name' => 'UsedName'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 64,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'use',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'name' => 'UseDecl',
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'UsedName',
                   'line' => 65,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'warnings',
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'kind' => Compiler::Lexer::Kind::T_Module
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 65,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'use',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'line' => 66,
                   'name' => 'UseDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'UsedName',
                   'line' => 66,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'data' => 'mro',
                   'kind' => Compiler::Lexer::Kind::T_Module
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => 'c3',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 66,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'line' => 66,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'data' => 'our',
                   'type' => Compiler::Lexer::TokenType::T_OurDecl,
                   'name' => 'OurDecl',
                   'line' => 67
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar,
                   'data' => '@ISA',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'ArrayVar',
                   'line' => 67
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'line' => 67,
                   'data' => '=',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 67,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'Foo',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'line' => 67
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'line' => 67,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 67,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'data' => '}',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 68,
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'VarDecl',
                   'line' => 70,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'data' => 'my',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LocalVar',
                   'line' => 70,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'data' => '$baz',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'Assign',
                   'line' => 70
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Class,
                   'data' => 'Baz',
                   'type' => Compiler::Lexer::TokenType::T_Class,
                   'line' => 70,
                   'name' => 'Class'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 70,
                   'name' => 'Pointer',
                   'data' => '->',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_Pointer,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 70,
                   'name' => 'Method',
                   'data' => 'new',
                   'type' => Compiler::Lexer::TokenType::T_Method,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'line' => 70
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 70,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'line' => 70
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 71,
                   'name' => 'Key',
                   'data' => 'object_ok',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 1,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'line' => 71,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$baz',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 71,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'line' => 71,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => 'Baz',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 71,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 71,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'line' => 71
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'line' => 72,
                   'data' => 'object_ok',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 72,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 72,
                   'name' => 'Var',
                   'data' => '$baz',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 72,
                   'name' => 'Comma',
                   'data' => ',',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'line' => 72,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'Foo',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 72,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 72,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 74,
                   'name' => 'LeftBrace',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'VarDecl',
                   'line' => 75,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'data' => 'my',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$m',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 75,
                   'name' => 'LocalVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'line' => 75,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'data' => '=',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'FunctionDecl',
                   'line' => 75,
                   'data' => 'sub',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 75,
                   'name' => 'LeftBrace',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 75,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'line' => 75,
                   'data' => 'shift',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 75,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'data' => '->',
                   'type' => Compiler::Lexer::TokenType::T_Pointer,
                   'name' => 'Pointer',
                   'line' => 75
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Namespace',
                   'line' => 75,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'data' => 'next',
                   'kind' => Compiler::Lexer::Kind::T_Namespace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '::',
                   'type' => Compiler::Lexer::TokenType::T_NamespaceResolver,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'NamespaceResolver',
                   'line' => 75
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Namespace',
                   'line' => 75,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'data' => 'method',
                   'kind' => Compiler::Lexer::Kind::T_Namespace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 75,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 75,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightBrace',
                   'line' => 75
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 75,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftBrace',
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'data' => 'no',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'line' => 77,
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'strict',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'name' => 'Key',
                   'line' => 77
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => 'refs',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'RawString',
                   'line' => 77
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'line' => 77,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Glob',
                   'line' => 78,
                   'data' => '*',
                   'type' => Compiler::Lexer::TokenType::T_Glob,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'line' => 78,
                   'data' => '{',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'Baz::bar',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'line' => 78,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 78,
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 78,
                   'name' => 'Assign',
                   'data' => '=',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 78,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '$m',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'line' => 78
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBrace',
                   'line' => 79,
                   'data' => '}',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'data' => 'eval',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'BuiltinFunc',
                   'line' => 81
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 81,
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$baz',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 81,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Pointer',
                   'line' => 81,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'data' => '->',
                   'type' => Compiler::Lexer::TokenType::T_Pointer
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Method',
                   'line' => 81,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Method,
                   'data' => 'bar',
                   'kind' => Compiler::Lexer::Kind::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 81,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'line' => 81,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBrace',
                   'line' => 81,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'line' => 81
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'ok',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 82,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'line' => 82
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'data' => '$@',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'SpecificValue',
                   'line' => 82
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 82,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'line' => 82,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '... calling bar() with next::method failed',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'line' => 82,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 82,
                   'name' => 'Or',
                   'data' => '||',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_Or,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 82,
                   'name' => 'Key',
                   'data' => 'diag',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SpecificValue',
                   'line' => 82,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$@',
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'line' => 82
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'line' => 83
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 86,
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Package',
                   'line' => 87,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'package',
                   'kind' => Compiler::Lexer::Kind::T_Package,
                   'type' => Compiler::Lexer::TokenType::T_Package
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Class,
                   'data' => 'Qux',
                   'kind' => Compiler::Lexer::Kind::T_Class,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'Class',
                   'line' => 87
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'line' => 87
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'data' => 'use',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'UseDecl',
                   'line' => 88
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 88,
                   'name' => 'UsedName',
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'data' => 'mro',
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'line' => 88,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 89,
                   'name' => 'FunctionDecl',
                   'data' => 'sub',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'data' => 'foo',
                   'type' => Compiler::Lexer::TokenType::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 89,
                   'name' => 'Function'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'line' => 89
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Namespace',
                   'line' => 89,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'No',
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'type' => Compiler::Lexer::TokenType::T_Namespace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'NamespaceResolver',
                   'line' => 89,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'data' => '::',
                   'type' => Compiler::Lexer::TokenType::T_NamespaceResolver
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Namespace',
                   'line' => 89,
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'data' => 'Such',
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'NamespaceResolver',
                   'line' => 89,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '::',
                   'type' => Compiler::Lexer::TokenType::T_NamespaceResolver,
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'data' => 'Class',
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'line' => 89,
                   'name' => 'Namespace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Pointer',
                   'line' => 89,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'data' => '->',
                   'type' => Compiler::Lexer::TokenType::T_Pointer,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'next',
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'name' => 'Namespace',
                   'line' => 89
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'NamespaceResolver',
                   'line' => 89,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'data' => '::',
                   'type' => Compiler::Lexer::TokenType::T_NamespaceResolver,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Namespace',
                   'line' => 89,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'can',
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'type' => Compiler::Lexer::TokenType::T_Namespace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'data' => '}',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightBrace',
                   'line' => 89
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 90,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 92,
                   'name' => 'BuiltinFunc',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'eval',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 92,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '{',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Class',
                   'line' => 92,
                   'kind' => Compiler::Lexer::Kind::T_Class,
                   'data' => 'Qux',
                   'type' => Compiler::Lexer::TokenType::T_Class,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 92,
                   'name' => 'Pointer',
                   'type' => Compiler::Lexer::TokenType::T_Pointer,
                   'data' => '->',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Method',
                   'line' => 92,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'foo',
                   'type' => Compiler::Lexer::TokenType::T_Method,
                   'kind' => Compiler::Lexer::Kind::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'line' => 92,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 92,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 92,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'data' => '}',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 92,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'is',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 93,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 93,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$@',
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'line' => 93,
                   'name' => 'SpecificValue'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 93,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => '',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'line' => 93
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'line' => 93,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ',',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'line' => 93,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '->next::can on non-existing package name',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 93,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 93,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 95,
                   'name' => 'RightBrace'
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
            'has_warnings' => 0,
            'end_line' => 3,
            'token_num' => 3,
            'src' => ' use strict ;',
            'start_line' => 3,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'end_line' => 4,
            'has_warnings' => 0,
            'start_line' => 4,
            'indent' => 0,
            'block_id' => 0,
            'src' => ' use warnings ;',
            'token_num' => 3
          },
          {
            'has_warnings' => 0,
            'end_line' => 6,
            'token_num' => 6,
            'src' => ' chdir \'t\' if -d \'t\' ;',
            'indent' => 1,
            'start_line' => 6,
            'block_id' => 1
          },
          {
            'start_line' => 6,
            'block_id' => 1,
            'indent' => 1,
            'token_num' => 6,
            'src' => ' require q(./test.pl) ;',
            'end_line' => 6,
            'has_warnings' => 0
          },
          {
            'src' => ' plan ( tests => 12 ) ;',
            'token_num' => 7,
            'block_id' => 0,
            'start_line' => 8,
            'indent' => 0,
            'has_warnings' => 1,
            'end_line' => 8
          },
          {
            'end_line' => 95,
            'has_warnings' => 1,
            'indent' => 0,
            'start_line' => 10,
            'block_id' => 0,
            'src' => ' { { package Foo ; use strict ; use warnings ; use mro \'c3\' ; sub new { bless { } , $_ [ 0 ] } sub bar { \'Foo::bar\' } } my $foo = Foo-> new ( ) ; object_ok ( $foo , \'Foo\' ) ; can_ok ( $foo , \'bar\' ) ; is ( $foo-> bar ( ) , \'Foo::bar\' , \'... got the right return value\' ) ; { package Bar ; use strict ; use warnings ; use mro \'c3\' ; our @ISA = ( \'Foo\' ) ; } my $bar = Bar-> new ( ) ; object_ok ( $bar , \'Bar\' ) ; object_ok ( $bar , \'Foo\' ) ; SKIP : { eval \'use Sub::Name\' ; skip ( "Sub::Name is required for this test" , 3 ) if $@ ; my $m = sub { ( shift )-> next::method ( ) } ; Sub::Name::subname ( \'Bar::bar\' , $m ) ; { no strict \'refs\' ; * { \'Bar::bar\' } = $m ; } can_ok ( $bar , \'bar\' ) ; my $value = eval { $bar-> bar ( ) } ; ok ( ! $@ , \'... calling bar() succeeded\' ) || diag $@ ; is ( $value , \'Foo::bar\' , \'... got the right return value too\' ) ; } { package Baz ; use strict ; use warnings ; use mro \'c3\' ; our @ISA = ( \'Foo\' ) ; } my $baz = Baz-> new ( ) ; object_ok ( $baz , \'Baz\' ) ; object_ok ( $baz , \'Foo\' ) ; { my $m = sub { ( shift )-> next::method ( ) } ; { no strict \'refs\' ; * { \'Baz::bar\' } = $m ; } eval { $baz-> bar ( ) } ; ok ( $@ , \'... calling bar() with next::method failed\' ) || diag $@ ; } { package Qux ; use mro ; sub foo { No::Such::Class-> next::can } } eval { Qux-> foo ( ) } ; is ( $@ , \'\' , "->next::can on non-existing package name" ) ; }',
            'token_num' => 330
          },
          {
            'indent' => 2,
            'start_line' => 13,
            'block_id' => 3,
            'src' => ' package Foo ;',
            'token_num' => 3,
            'end_line' => 13,
            'has_warnings' => 1
          },
          {
            'end_line' => 14,
            'has_warnings' => 0,
            'indent' => 2,
            'start_line' => 14,
            'block_id' => 3,
            'token_num' => 3,
            'src' => ' use strict ;'
          },
          {
            'end_line' => 15,
            'has_warnings' => 0,
            'indent' => 2,
            'start_line' => 15,
            'block_id' => 3,
            'src' => ' use warnings ;',
            'token_num' => 3
          },
          {
            'end_line' => 16,
            'has_warnings' => 0,
            'start_line' => 16,
            'indent' => 2,
            'block_id' => 3,
            'src' => ' use mro \'c3\' ;',
            'token_num' => 4
          },
          {
            'start_line' => 17,
            'block_id' => 3,
            'indent' => 2,
            'src' => ' sub new { bless { } , $_ [ 0 ] }',
            'token_num' => 12,
            'end_line' => 17,
            'has_warnings' => 0
          },
          {
            'end_line' => 18,
            'has_warnings' => 0,
            'start_line' => 18,
            'indent' => 2,
            'block_id' => 3,
            'src' => ' sub bar { \'Foo::bar\' }',
            'token_num' => 5
          },
          {
            'start_line' => 23,
            'block_id' => 2,
            'indent' => 1,
            'token_num' => 9,
            'src' => ' my $foo = Foo-> new ( ) ;',
            'end_line' => 23,
            'has_warnings' => 1
          },
          {
            'start_line' => 24,
            'block_id' => 2,
            'indent' => 1,
            'token_num' => 7,
            'src' => ' object_ok ( $foo , \'Foo\' ) ;',
            'end_line' => 24,
            'has_warnings' => 1
          },
          {
            'indent' => 1,
            'start_line' => 26,
            'block_id' => 2,
            'src' => ' can_ok ( $foo , \'bar\' ) ;',
            'token_num' => 7,
            'end_line' => 26,
            'has_warnings' => 1
          },
          {
            'src' => ' is ( $foo-> bar ( ) , \'Foo::bar\' , \'... got the right return value\' ) ;',
            'token_num' => 13,
            'indent' => 1,
            'start_line' => 27,
            'block_id' => 2,
            'has_warnings' => 1,
            'end_line' => 27
          },
          {
            'has_warnings' => 1,
            'end_line' => 37,
            'src' => ' { package Bar ; use strict ; use warnings ; use mro \'c3\' ; our @ISA = ( \'Foo\' ) ; }',
            'token_num' => 22,
            'block_id' => 2,
            'start_line' => 31,
            'indent' => 1
          },
          {
            'start_line' => 32,
            'indent' => 2,
            'block_id' => 6,
            'token_num' => 3,
            'src' => ' package Bar ;',
            'end_line' => 32,
            'has_warnings' => 1
          },
          {
            'token_num' => 3,
            'src' => ' use strict ;',
            'indent' => 2,
            'start_line' => 33,
            'block_id' => 6,
            'has_warnings' => 0,
            'end_line' => 33
          },
          {
            'start_line' => 34,
            'block_id' => 6,
            'indent' => 2,
            'token_num' => 3,
            'src' => ' use warnings ;',
            'end_line' => 34,
            'has_warnings' => 0
          },
          {
            'end_line' => 35,
            'has_warnings' => 0,
            'start_line' => 35,
            'indent' => 2,
            'block_id' => 6,
            'src' => ' use mro \'c3\' ;',
            'token_num' => 4
          },
          {
            'end_line' => 36,
            'has_warnings' => 0,
            'block_id' => 6,
            'start_line' => 36,
            'indent' => 2,
            'token_num' => 7,
            'src' => ' our @ISA = ( \'Foo\' ) ;'
          },
          {
            'has_warnings' => 1,
            'end_line' => 39,
            'token_num' => 9,
            'src' => ' my $bar = Bar-> new ( ) ;',
            'indent' => 1,
            'start_line' => 39,
            'block_id' => 2
          },
          {
            'has_warnings' => 1,
            'end_line' => 40,
            'token_num' => 7,
            'src' => ' object_ok ( $bar , \'Bar\' ) ;',
            'block_id' => 2,
            'start_line' => 40,
            'indent' => 1
          },
          {
            'src' => ' object_ok ( $bar , \'Foo\' ) ;',
            'token_num' => 7,
            'start_line' => 41,
            'block_id' => 2,
            'indent' => 1,
            'has_warnings' => 1,
            'end_line' => 41
          },
          {
            'end_line' => 45,
            'has_warnings' => 0,
            'start_line' => 45,
            'indent' => 2,
            'block_id' => 7,
            'token_num' => 3,
            'src' => ' eval \'use Sub::Name\' ;'
          },
          {
            'src' => ' skip ( "Sub::Name is required for this test" , 3 ) if $@ ;',
            'token_num' => 9,
            'indent' => 2,
            'start_line' => 46,
            'block_id' => 7,
            'has_warnings' => 1,
            'end_line' => 46
          },
          {
            'src' => ' my $m = sub { ( shift )-> next::method ( ) } ;',
            'token_num' => 14,
            'indent' => 2,
            'start_line' => 48,
            'block_id' => 7,
            'has_warnings' => 1,
            'end_line' => 48
          },
          {
            'has_warnings' => 1,
            'end_line' => 49,
            'src' => ' Sub::Name::subname ( \'Bar::bar\' , $m ) ;',
            'token_num' => 7,
            'block_id' => 7,
            'start_line' => 49,
            'indent' => 2
          },
          {
            'end_line' => 53,
            'has_warnings' => 1,
            'indent' => 2,
            'start_line' => 50,
            'block_id' => 7,
            'src' => ' { no strict \'refs\' ; * { \'Bar::bar\' } = $m ; }',
            'token_num' => 13
          },
          {
            'end_line' => 51,
            'has_warnings' => 1,
            'indent' => 3,
            'start_line' => 51,
            'block_id' => 9,
            'src' => ' no strict \'refs\' ;',
            'token_num' => 4
          },
          {
            'end_line' => 52,
            'has_warnings' => 1,
            'start_line' => 52,
            'indent' => 3,
            'block_id' => 9,
            'token_num' => 7,
            'src' => ' * { \'Bar::bar\' } = $m ;'
          },
          {
            'end_line' => 55,
            'has_warnings' => 1,
            'indent' => 2,
            'start_line' => 55,
            'block_id' => 7,
            'token_num' => 7,
            'src' => ' can_ok ( $bar , \'bar\' ) ;'
          },
          {
            'has_warnings' => 1,
            'end_line' => 56,
            'token_num' => 12,
            'src' => ' my $value = eval { $bar-> bar ( ) } ;',
            'start_line' => 56,
            'block_id' => 7,
            'indent' => 2
          },
          {
            'start_line' => 57,
            'block_id' => 7,
            'indent' => 2,
            'token_num' => 11,
            'src' => ' ok ( ! $@ , \'... calling bar() succeeded\' ) || diag $@ ;',
            'end_line' => 57,
            'has_warnings' => 1
          },
          {
            'token_num' => 9,
            'src' => ' is ( $value , \'Foo::bar\' , \'... got the right return value too\' ) ;',
            'indent' => 2,
            'start_line' => 58,
            'block_id' => 7,
            'has_warnings' => 1,
            'end_line' => 58
          },
          {
            'src' => ' { package Baz ; use strict ; use warnings ; use mro \'c3\' ; our @ISA = ( \'Foo\' ) ; }',
            'token_num' => 22,
            'indent' => 1,
            'start_line' => 62,
            'block_id' => 2,
            'has_warnings' => 1,
            'end_line' => 68
          },
          {
            'src' => ' package Baz ;',
            'token_num' => 3,
            'start_line' => 63,
            'indent' => 2,
            'block_id' => 10,
            'has_warnings' => 1,
            'end_line' => 63
          },
          {
            'block_id' => 10,
            'start_line' => 64,
            'indent' => 2,
            'src' => ' use strict ;',
            'token_num' => 3,
            'end_line' => 64,
            'has_warnings' => 0
          },
          {
            'has_warnings' => 0,
            'end_line' => 65,
            'token_num' => 3,
            'src' => ' use warnings ;',
            'block_id' => 10,
            'start_line' => 65,
            'indent' => 2
          },
          {
            'has_warnings' => 0,
            'end_line' => 66,
            'src' => ' use mro \'c3\' ;',
            'token_num' => 4,
            'start_line' => 66,
            'block_id' => 10,
            'indent' => 2
          },
          {
            'token_num' => 7,
            'src' => ' our @ISA = ( \'Foo\' ) ;',
            'indent' => 2,
            'start_line' => 67,
            'block_id' => 10,
            'has_warnings' => 0,
            'end_line' => 67
          },
          {
            'start_line' => 70,
            'block_id' => 2,
            'indent' => 1,
            'token_num' => 9,
            'src' => ' my $baz = Baz-> new ( ) ;',
            'end_line' => 70,
            'has_warnings' => 1
          },
          {
            'src' => ' object_ok ( $baz , \'Baz\' ) ;',
            'token_num' => 7,
            'block_id' => 2,
            'start_line' => 71,
            'indent' => 1,
            'has_warnings' => 1,
            'end_line' => 71
          },
          {
            'src' => ' object_ok ( $baz , \'Foo\' ) ;',
            'token_num' => 7,
            'start_line' => 72,
            'block_id' => 2,
            'indent' => 1,
            'has_warnings' => 1,
            'end_line' => 72
          },
          {
            'end_line' => 83,
            'has_warnings' => 1,
            'start_line' => 74,
            'indent' => 1,
            'block_id' => 2,
            'src' => ' { my $m = sub { ( shift )-> next::method ( ) } ; { no strict \'refs\' ; * { \'Baz::bar\' } = $m ; } eval { $baz-> bar ( ) } ; ok ( $@ , \'... calling bar() with next::method failed\' ) || diag $@ ; }',
            'token_num' => 48
          },
          {
            'block_id' => 11,
            'start_line' => 75,
            'indent' => 2,
            'token_num' => 14,
            'src' => ' my $m = sub { ( shift )-> next::method ( ) } ;',
            'end_line' => 75,
            'has_warnings' => 1
          },
          {
            'has_warnings' => 1,
            'end_line' => 79,
            'token_num' => 13,
            'src' => ' { no strict \'refs\' ; * { \'Baz::bar\' } = $m ; }',
            'indent' => 2,
            'start_line' => 76,
            'block_id' => 11
          },
          {
            'src' => ' no strict \'refs\' ;',
            'token_num' => 4,
            'indent' => 3,
            'start_line' => 77,
            'block_id' => 13,
            'has_warnings' => 1,
            'end_line' => 77
          },
          {
            'start_line' => 78,
            'indent' => 3,
            'block_id' => 13,
            'src' => ' * { \'Baz::bar\' } = $m ;',
            'token_num' => 7,
            'end_line' => 78,
            'has_warnings' => 1
          },
          {
            'has_warnings' => 1,
            'end_line' => 81,
            'src' => ' eval { $baz-> bar ( ) } ;',
            'token_num' => 9,
            'indent' => 2,
            'start_line' => 81,
            'block_id' => 11
          },
          {
            'has_warnings' => 1,
            'end_line' => 82,
            'src' => ' ok ( $@ , \'... calling bar() with next::method failed\' ) || diag $@ ;',
            'token_num' => 10,
            'indent' => 2,
            'start_line' => 82,
            'block_id' => 11
          },
          {
            'has_warnings' => 1,
            'end_line' => 90,
            'src' => ' { package Qux ; use mro ; sub foo { No::Such::Class-> next::can } }',
            'token_num' => 15,
            'block_id' => 2,
            'start_line' => 86,
            'indent' => 1
          },
          {
            'token_num' => 3,
            'src' => ' package Qux ;',
            'block_id' => 14,
            'start_line' => 87,
            'indent' => 2,
            'has_warnings' => 1,
            'end_line' => 87
          },
          {
            'has_warnings' => 0,
            'end_line' => 88,
            'src' => ' use mro ;',
            'token_num' => 3,
            'start_line' => 88,
            'block_id' => 14,
            'indent' => 2
          },
          {
            'start_line' => 89,
            'block_id' => 14,
            'indent' => 2,
            'token_num' => 7,
            'src' => ' sub foo { No::Such::Class-> next::can }',
            'end_line' => 89,
            'has_warnings' => 1
          },
          {
            'block_id' => 2,
            'start_line' => 92,
            'indent' => 1,
            'token_num' => 9,
            'src' => ' eval { Qux-> foo ( ) } ;',
            'end_line' => 92,
            'has_warnings' => 1
          },
          {
            'indent' => 1,
            'start_line' => 93,
            'block_id' => 2,
            'src' => ' is ( $@ , \'\' , "->next::can on non-existing package name" ) ;',
            'token_num' => 9,
            'end_line' => 93,
            'has_warnings' => 1
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
            'name' => 'warnings',
            'args' => ''
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
            'args' => '',
            'name' => 'mro'
          }
        ]
, 'Compiler::Lexer::get_used_modules');
};

done_testing;
