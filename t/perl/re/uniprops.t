use strict;
use warnings;
use Test::More;
BEGIN {
    use_ok('Compiler::Lexer');
}
my $script =<<'__SCRIPT__';
use strict;
use warnings;
no warnings 'once';

if ($^O eq 'dec_osf') {
   print "1..0 # $^O cannot handle this test\n";
   exit(0);
}

# This is a wrapper for a generated file.  Assumes being run from 't'
# directory.

# It is skipped by default under PERL_DEBUG_READONLY_COW, but you can run
# it directly via:  cd t; ./perl -I../lib ../lib/unicore/TestProp.pl

require Config;
if ($Config::Config{ccflags} =~ /(?:^|\s)-DPERL_DEBUG_READONLY_COW\b/) {
    print "1..0 # Skip PERL_DEBUG_READONLY_COW\n";
    exit;
}

do '../lib/unicore/TestProp.pl';

# Since TestProp.pl explicitly exits, we will only get here if it
# could not load.
if (defined &DynaLoader::boot_DynaLoader # not miniperl
 || eval 'require "unicore/Heavy.pl"'    # or tables are built
) {
    die "Could not run lib/unicore/TestProp.pl: ", $@||$!;
}
else {
    print "1..0 # Skip Unicode tables not built yet\n";
}

0

__SCRIPT__

subtest 'tokenize' => sub {
    my $tokens = Compiler::Lexer->new('')->tokenize($script);
    is_deeply($tokens, [
          bless( {
                   'line' => 1,
                   'name' => 'UseDecl',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'data' => 'use',
                   'type' => Compiler::Lexer::TokenType::T_UseDecl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 1,
                   'name' => 'UsedName',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
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
                   'line' => 1,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 2,
                   'name' => 'UseDecl',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'use',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'data' => 'warnings',
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'name' => 'UsedName',
                   'line' => 2
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'line' => 2,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'line' => 3,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'data' => 'no',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 3,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'warnings',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'line' => 3,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'once',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'line' => 3
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'data' => 'if',
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'name' => 'IfStmt',
                   'line' => 5
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 5,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SpecificValue',
                   'line' => 5,
                   'data' => '$^O',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'eq',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 5,
                   'name' => 'StringEqual'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'dec_osf',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'line' => 5
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'line' => 5,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 5,
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'data' => 'print',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'BuiltinFunc',
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '1..0 # $^O cannot handle this test\\n',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'line' => 6,
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 6,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 7,
                   'name' => 'BuiltinFunc',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'data' => 'exit',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 7,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'data' => '0',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Int',
                   'line' => 7
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 7,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'line' => 7
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBrace',
                   'line' => 8,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RequireDecl',
                   'line' => 16,
                   'type' => Compiler::Lexer::TokenType::T_RequireDecl,
                   'data' => 'require',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 16,
                   'name' => 'RequiredName',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'Config',
                   'type' => Compiler::Lexer::TokenType::T_RequiredName,
                   'kind' => Compiler::Lexer::Kind::T_Module
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'line' => 16,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'data' => 'if',
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'name' => 'IfStmt',
                   'line' => 17
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 17,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 17,
                   'name' => 'GlobalVar',
                   'data' => '$Config',
                   'type' => Compiler::Lexer::TokenType::T_GlobalVar,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'NamespaceResolver',
                   'line' => 17,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_NamespaceResolver,
                   'data' => '::',
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Namespace',
                   'line' => 17,
                   'data' => 'Config',
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 17,
                   'name' => 'LeftBrace',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '{',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'ccflags',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'Key',
                   'line' => 17
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 17,
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=~',
                   'type' => Compiler::Lexer::TokenType::T_RegOK,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 17,
                   'name' => 'RegOK'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '/',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'line' => 17,
                   'name' => 'RegDelim'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(?:^|\\s)-DPERL_DEBUG_READONLY_COW\\b',
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegExp',
                   'line' => 17
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'data' => '/',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegDelim',
                   'line' => 17
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 17,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '{',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBrace',
                   'line' => 17
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 18,
                   'name' => 'BuiltinFunc',
                   'data' => 'print',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '1..0 # Skip PERL_DEBUG_READONLY_COW\\n',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 18,
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'line' => 18
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 19,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'data' => 'exit',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 19,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'data' => '}',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace',
                   'line' => 20
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'do',
                   'kind' => Compiler::Lexer::Kind::T_Do,
                   'type' => Compiler::Lexer::TokenType::T_Do,
                   'line' => 22,
                   'name' => 'Do'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '../lib/unicore/TestProp.pl',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 22,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'line' => 22
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'if',
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'line' => 26,
                   'name' => 'IfStmt'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'line' => 26,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'defined',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'line' => 26
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '&',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_BitAnd,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 26,
                   'name' => 'BitAnd'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'data' => 'DynaLoader',
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Namespace',
                   'line' => 26
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'NamespaceResolver',
                   'line' => 26,
                   'type' => Compiler::Lexer::TokenType::T_NamespaceResolver,
                   'data' => '::',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'data' => 'boot_DynaLoader',
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'Namespace',
                   'line' => 26
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 27,
                   'name' => 'Or',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'data' => '||',
                   'type' => Compiler::Lexer::TokenType::T_Or,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 27,
                   'name' => 'BuiltinFunc',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'eval',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'require "unicore/Heavy.pl"',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 27,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'line' => 28,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'LeftBrace',
                   'line' => 28
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'line' => 29,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'data' => 'die',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'line' => 29,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'Could not run lib/unicore/TestProp.pl: ',
                   'type' => Compiler::Lexer::TokenType::T_String
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 29,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$@',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'line' => 29,
                   'name' => 'SpecificValue'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Or,
                   'data' => '||',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 29,
                   'name' => 'Or'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$!',
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'SpecificValue',
                   'line' => 29
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'line' => 29,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 30,
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'ElseStmt',
                   'line' => 31,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'data' => 'else',
                   'type' => Compiler::Lexer::TokenType::T_ElseStmt
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 31,
                   'name' => 'LeftBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'line' => 32,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'data' => 'print',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '1..0 # Skip Unicode tables not built yet\\n',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'String',
                   'line' => 32
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'line' => 32,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 33,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 35,
                   'name' => 'Int',
                   'data' => '0',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
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
            'block_id' => 0,
            'start_line' => 1,
            'indent' => 0,
            'src' => ' use strict ;',
            'token_num' => 3,
            'end_line' => 1,
            'has_warnings' => 0
          },
          {
            'src' => ' use warnings ;',
            'token_num' => 3,
            'start_line' => 2,
            'block_id' => 0,
            'indent' => 0,
            'has_warnings' => 0,
            'end_line' => 2
          },
          {
            'has_warnings' => 1,
            'end_line' => 3,
            'src' => ' no warnings \'once\' ;',
            'token_num' => 4,
            'block_id' => 0,
            'start_line' => 3,
            'indent' => 0
          },
          {
            'end_line' => 8,
            'has_warnings' => 0,
            'block_id' => 0,
            'start_line' => 5,
            'indent' => 0,
            'token_num' => 16,
            'src' => ' if ( $^O eq \'dec_osf\' ) { print "1..0 # $^O cannot handle this test\\n" ; exit ( 0 ) ; }'
          },
          {
            'indent' => 1,
            'start_line' => 6,
            'block_id' => 1,
            'token_num' => 3,
            'src' => ' print "1..0 # $^O cannot handle this test\\n" ;',
            'end_line' => 6,
            'has_warnings' => 0
          },
          {
            'end_line' => 7,
            'has_warnings' => 0,
            'indent' => 1,
            'start_line' => 7,
            'block_id' => 1,
            'token_num' => 5,
            'src' => ' exit ( 0 ) ;'
          },
          {
            'src' => ' require Config ;',
            'token_num' => 3,
            'block_id' => 0,
            'start_line' => 16,
            'indent' => 0,
            'has_warnings' => 0,
            'end_line' => 16
          },
          {
            'has_warnings' => 1,
            'end_line' => 20,
            'src' => ' if ( $Config::Config { ccflags } =~/(?:^|\\s)-DPERL_DEBUG_READONLY_COW\\b/ ) { print "1..0 # Skip PERL_DEBUG_READONLY_COW\\n" ; exit ; }',
            'token_num' => 18,
            'block_id' => 0,
            'start_line' => 17,
            'indent' => 0
          },
          {
            'has_warnings' => 0,
            'end_line' => 18,
            'src' => ' print "1..0 # Skip PERL_DEBUG_READONLY_COW\\n" ;',
            'token_num' => 3,
            'block_id' => 2,
            'start_line' => 18,
            'indent' => 1
          },
          {
            'start_line' => 19,
            'block_id' => 2,
            'indent' => 1,
            'src' => ' exit ;',
            'token_num' => 2,
            'end_line' => 19,
            'has_warnings' => 0
          },
          {
            'token_num' => 3,
            'src' => ' do \'../lib/unicore/TestProp.pl\' ;',
            'indent' => 0,
            'start_line' => 22,
            'block_id' => 0,
            'has_warnings' => 0,
            'end_line' => 22
          },
          {
            'block_id' => 0,
            'start_line' => 26,
            'indent' => 0,
            'src' => ' if ( defined & DynaLoader::boot_DynaLoader || eval \'require "unicore/Heavy.pl"\' ) { die "Could not run lib/unicore/TestProp.pl: " , $@ || $! ; }',
            'token_num' => 18,
            'end_line' => 30,
            'has_warnings' => 1
          },
          {
            'end_line' => 29,
            'has_warnings' => 0,
            'start_line' => 29,
            'indent' => 1,
            'block_id' => 3,
            'src' => ' die "Could not run lib/unicore/TestProp.pl: " , $@ || $! ;',
            'token_num' => 7
          },
          {
            'has_warnings' => 0,
            'end_line' => 33,
            'src' => ' else { print "1..0 # Skip Unicode tables not built yet\\n" ; }',
            'token_num' => 6,
            'block_id' => 0,
            'start_line' => 31,
            'indent' => 0
          },
          {
            'has_warnings' => 0,
            'end_line' => 32,
            'src' => ' print "1..0 # Skip Unicode tables not built yet\\n" ;',
            'token_num' => 3,
            'block_id' => 4,
            'start_line' => 32,
            'indent' => 1
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
          }
        ]
, 'Compiler::Lexer::get_used_modules');
};

done_testing;
