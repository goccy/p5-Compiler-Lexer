use strict;
use warnings;
use Test::More;
BEGIN {
    use_ok('Compiler::Lexer');
}
my $script =<<'SCRIPT';
#!./perl -w

BEGIN {
    chdir 't' if -d 't';
    @INC = '../lib';
    require './test.pl';
}

plan tests => 5;

my $rx = qr//;

is(ref $rx, "Regexp", "qr// blessed into 'Regexp' by default");


# Make sure /$qr/ doesn’t clobber match vars before the match (bug 70764).
{
 my $output = '';
 my $rx = qr/o/;
 my $a = "ooaoaoao";

 my $foo = 0;
 $foo += () = ($a =~ /$rx/g);
 $output .= "$foo\n"; # correct

 $foo = 0;
 for ($foo += ($a =~ /o/); $' && ($' =~ /o/) && ($foo++) ; ) { ; }
 $output .= "1: $foo\n"; # No error

 $foo = 0;
 for ($foo += ($a =~ /$rx/); $' && ($' =~ /$rx/) && ($foo++) ; ) { ; }
 $output .= "2: $foo\n"; # initialization warning, incorrect results

 is $output, "5\n1: 5\n2: 5\n", '$a_match_var =~ /$qr/';
}
for my $_($'){
 my $output = '';
 my $rx = qr/o/;
 my $a = "ooaoaoao";

 my $foo = 0;
 $foo += () = ($a =~ /$rx/g);
 $output .= "$foo\n"; # correct

 $foo = 0;
 for ($foo += ($a =~ /o/); $' && /o/ && ($foo++) ; ) { ; }
 $output .= "1: $foo\n"; # No error

 $foo = 0;
 for ($foo += ($a =~ /$rx/); $' && /$rx/ && ($foo++) ; ) { ; }
 $output .= "2: $foo\n"; # initialization warning, incorrect results

 is $output, "5\n1: 5\n2: 5\n", '/$qr/ with my $_ aliased to a match var';
}
for($'){
 my $output = '';
 my $rx = qr/o/;
 my $a = "ooaoaoao";

 my $foo = 0;
 $foo += () = ($a =~ /$rx/g);
 $output .= "$foo\n"; # correct

 $foo = 0;
 for ($foo += ($a =~ /o/); $' && /o/ && ($foo++) ; ) { ; }
 $output .= "1: $foo\n"; # No error

 $foo = 0;
 for ($foo += ($a =~ /$rx/); $' && /$rx/ && ($foo++) ; ) { ; }
 $output .= "2: $foo\n"; # initialization warning, incorrect results

 is $output, "5\n1: 5\n2: 5\n", q|/$qr/ with $'_ aliased to a match var|;
}

# Make sure /$qr/ calls get-magic on its LHS (bug 71470).
{
 my $scratch;
 sub qrBug::TIESCALAR{bless[], 'qrBug'}
 sub qrBug::FETCH { $scratch .= "[fetching]"; 'glat' }
 tie my $flile, "qrBug";
 $flile =~ qr/(?:)/;
 is $scratch, "[fetching]", '/$qr/ with magical LHS';
}

SCRIPT

subtest 'tokenize' => sub {
    my $tokens = Compiler::Lexer->new('')->tokenize($script);
    is_deeply($$tokens, [
          bless( {
                   'kind' => 9,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'ModWord',
                   'data' => 'BEGIN',
                   'type' => 69,
                   'line' => 3
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 3
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'chdir',
                   'type' => 64,
                   'line' => 4
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 't',
                   'type' => 164,
                   'line' => 4
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'IfStmt',
                   'data' => 'if',
                   'type' => 89,
                   'line' => 4
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 13,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Handle',
                   'data' => '-d',
                   'type' => 83,
                   'line' => 4
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 't',
                   'type' => 164,
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
                   'name' => 'LibraryDirectories',
                   'data' => '@INC',
                   'type' => 132,
                   'line' => 5
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 5
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '../lib',
                   'type' => 164,
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
                   'name' => 'RequireDecl',
                   'data' => 'require',
                   'type' => 65,
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => './test.pl',
                   'type' => 164,
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
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 7
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'plan',
                   'type' => 114,
                   'line' => 9
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'tests',
                   'type' => 114,
                   'line' => 9
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'type' => 116,
                   'line' => 9
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Int',
                   'data' => '5',
                   'type' => 161,
                   'line' => 9
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 9
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 11
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$rx',
                   'type' => 176,
                   'line' => 11
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 11
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDecl',
                   'data' => 'qr',
                   'type' => 141,
                   'line' => 11
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 11
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => '',
                   'type' => 172,
                   'line' => 11
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 11
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 11
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'is',
                   'type' => 114,
                   'line' => 13
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 13
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'ref',
                   'type' => 64,
                   'line' => 13
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$rx',
                   'type' => 157,
                   'line' => 13
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 13
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Regexp',
                   'type' => 163,
                   'line' => 13
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 13
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'qr// blessed into \'Regexp\' by default',
                   'type' => 163,
                   'line' => 13
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 13
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 13
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 17
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 18
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$output',
                   'type' => 176,
                   'line' => 18
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 18
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '',
                   'type' => 164,
                   'line' => 18
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 18
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 19
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$rx',
                   'type' => 176,
                   'line' => 19
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 19
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDecl',
                   'data' => 'qr',
                   'type' => 141,
                   'line' => 19
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 19
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => 'o',
                   'type' => 172,
                   'line' => 19
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 19
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 19
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 20
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$a',
                   'type' => 176,
                   'line' => 20
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 20
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'ooaoaoao',
                   'type' => 163,
                   'line' => 20
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 20
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 22
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$foo',
                   'type' => 176,
                   'line' => 22
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 22
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Int',
                   'data' => '0',
                   'type' => 161,
                   'line' => 22
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 22
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$foo',
                   'type' => 157,
                   'line' => 23
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'AddEqual',
                   'data' => '+=',
                   'type' => 20,
                   'line' => 23
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 23
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 23
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 23
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 23
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$a',
                   'type' => 157,
                   'line' => 23
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegOK',
                   'data' => '=~',
                   'type' => 31,
                   'line' => 23
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 23
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => '$rx',
                   'type' => 172,
                   'line' => 23
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 23
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegOpt',
                   'data' => 'g',
                   'type' => 136,
                   'line' => 23
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 23
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 23
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$output',
                   'type' => 157,
                   'line' => 24
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringAdd',
                   'data' => '.=',
                   'type' => 9,
                   'line' => 24
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => '$foo\\n',
                   'type' => 163,
                   'line' => 24
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 24
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$foo',
                   'type' => 157,
                   'line' => 26
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 26
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Int',
                   'data' => '0',
                   'type' => 161,
                   'line' => 26
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 26
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'ForStmt',
                   'data' => 'for',
                   'type' => 125,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$foo',
                   'type' => 157,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'AddEqual',
                   'data' => '+=',
                   'type' => 20,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$a',
                   'type' => 157,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegOK',
                   'data' => '=~',
                   'type' => 31,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => 'o',
                   'type' => 172,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SpecificValue',
                   'data' => '$\'',
                   'type' => 129,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'And',
                   'data' => '&&',
                   'type' => 16,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SpecificValue',
                   'data' => '$\'',
                   'type' => 129,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegOK',
                   'data' => '=~',
                   'type' => 31,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => 'o',
                   'type' => 172,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'And',
                   'data' => '&&',
                   'type' => 16,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$foo',
                   'type' => 157,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Inc',
                   'data' => '++',
                   'type' => 42,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$output',
                   'type' => 157,
                   'line' => 28
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringAdd',
                   'data' => '.=',
                   'type' => 9,
                   'line' => 28
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => '1: $foo\\n',
                   'type' => 163,
                   'line' => 28
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 28
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$foo',
                   'type' => 157,
                   'line' => 30
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 30
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Int',
                   'data' => '0',
                   'type' => 161,
                   'line' => 30
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 30
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'ForStmt',
                   'data' => 'for',
                   'type' => 125,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$foo',
                   'type' => 157,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'AddEqual',
                   'data' => '+=',
                   'type' => 20,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$a',
                   'type' => 157,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegOK',
                   'data' => '=~',
                   'type' => 31,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => '$rx',
                   'type' => 172,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SpecificValue',
                   'data' => '$\'',
                   'type' => 129,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'And',
                   'data' => '&&',
                   'type' => 16,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SpecificValue',
                   'data' => '$\'',
                   'type' => 129,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegOK',
                   'data' => '=~',
                   'type' => 31,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => '$rx',
                   'type' => 172,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'And',
                   'data' => '&&',
                   'type' => 16,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$foo',
                   'type' => 157,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Inc',
                   'data' => '++',
                   'type' => 42,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$output',
                   'type' => 157,
                   'line' => 32
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringAdd',
                   'data' => '.=',
                   'type' => 9,
                   'line' => 32
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => '2: $foo\\n',
                   'type' => 163,
                   'line' => 32
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 32
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'is',
                   'type' => 114,
                   'line' => 34
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$output',
                   'type' => 157,
                   'line' => 34
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 34
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => '5\\n1: 5\\n2: 5\\n',
                   'type' => 163,
                   'line' => 34
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 34
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '$a_match_var =~ /$qr/',
                   'type' => 164,
                   'line' => 34
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 34
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 35
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'ForStmt',
                   'data' => 'for',
                   'type' => 125,
                   'line' => 36
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 36
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SpecificValue',
                   'data' => '$_',
                   'type' => 129,
                   'line' => 36
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 36
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SpecificValue',
                   'data' => '$\'',
                   'type' => 129,
                   'line' => 36
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 36
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 36
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 37
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$output',
                   'type' => 176,
                   'line' => 37
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 37
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '',
                   'type' => 164,
                   'line' => 37
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 37
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 38
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$rx',
                   'type' => 176,
                   'line' => 38
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 38
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDecl',
                   'data' => 'qr',
                   'type' => 141,
                   'line' => 38
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 38
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => 'o',
                   'type' => 172,
                   'line' => 38
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 38
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 38
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 39
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$a',
                   'type' => 176,
                   'line' => 39
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 39
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'ooaoaoao',
                   'type' => 163,
                   'line' => 39
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 39
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 41
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$foo',
                   'type' => 176,
                   'line' => 41
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 41
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Int',
                   'data' => '0',
                   'type' => 161,
                   'line' => 41
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 41
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$foo',
                   'type' => 157,
                   'line' => 42
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'AddEqual',
                   'data' => '+=',
                   'type' => 20,
                   'line' => 42
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 42
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 42
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 42
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 42
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$a',
                   'type' => 157,
                   'line' => 42
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegOK',
                   'data' => '=~',
                   'type' => 31,
                   'line' => 42
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 42
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => '$rx',
                   'type' => 172,
                   'line' => 42
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 42
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegOpt',
                   'data' => 'g',
                   'type' => 136,
                   'line' => 42
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 42
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 42
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$output',
                   'type' => 157,
                   'line' => 43
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringAdd',
                   'data' => '.=',
                   'type' => 9,
                   'line' => 43
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => '$foo\\n',
                   'type' => 163,
                   'line' => 43
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 43
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$foo',
                   'type' => 157,
                   'line' => 45
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 45
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Int',
                   'data' => '0',
                   'type' => 161,
                   'line' => 45
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 45
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'ForStmt',
                   'data' => 'for',
                   'type' => 125,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$foo',
                   'type' => 157,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'AddEqual',
                   'data' => '+=',
                   'type' => 20,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$a',
                   'type' => 157,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegOK',
                   'data' => '=~',
                   'type' => 31,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => 'o',
                   'type' => 172,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SpecificValue',
                   'data' => '$\'',
                   'type' => 129,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'And',
                   'data' => '&&',
                   'type' => 16,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => 'o',
                   'type' => 172,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'And',
                   'data' => '&&',
                   'type' => 16,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$foo',
                   'type' => 157,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Inc',
                   'data' => '++',
                   'type' => 42,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$output',
                   'type' => 157,
                   'line' => 47
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringAdd',
                   'data' => '.=',
                   'type' => 9,
                   'line' => 47
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => '1: $foo\\n',
                   'type' => 163,
                   'line' => 47
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 47
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$foo',
                   'type' => 157,
                   'line' => 49
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 49
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Int',
                   'data' => '0',
                   'type' => 161,
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
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'ForStmt',
                   'data' => 'for',
                   'type' => 125,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$foo',
                   'type' => 157,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'AddEqual',
                   'data' => '+=',
                   'type' => 20,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$a',
                   'type' => 157,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegOK',
                   'data' => '=~',
                   'type' => 31,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => '$rx',
                   'type' => 172,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
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
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SpecificValue',
                   'data' => '$\'',
                   'type' => 129,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'And',
                   'data' => '&&',
                   'type' => 16,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => '$rx',
                   'type' => 172,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'And',
                   'data' => '&&',
                   'type' => 16,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$foo',
                   'type' => 157,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Inc',
                   'data' => '++',
                   'type' => 42,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
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
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
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
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$output',
                   'type' => 157,
                   'line' => 51
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringAdd',
                   'data' => '.=',
                   'type' => 9,
                   'line' => 51
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => '2: $foo\\n',
                   'type' => 163,
                   'line' => 51
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 51
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'is',
                   'type' => 114,
                   'line' => 53
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$output',
                   'type' => 157,
                   'line' => 53
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 53
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => '5\\n1: 5\\n2: 5\\n',
                   'type' => 163,
                   'line' => 53
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 53
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '/$qr/ with my $_ aliased to a match var',
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
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 54
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'ForStmt',
                   'data' => 'for',
                   'type' => 125,
                   'line' => 55
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 55
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SpecificValue',
                   'data' => '$\'',
                   'type' => 129,
                   'line' => 55
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 55
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 55
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 56
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$output',
                   'type' => 176,
                   'line' => 56
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 56
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '',
                   'type' => 164,
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
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 57
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$rx',
                   'type' => 176,
                   'line' => 57
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 57
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDecl',
                   'data' => 'qr',
                   'type' => 141,
                   'line' => 57
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 57
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => 'o',
                   'type' => 172,
                   'line' => 57
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
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
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 58
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$a',
                   'type' => 176,
                   'line' => 58
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 58
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'ooaoaoao',
                   'type' => 163,
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
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 60
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$foo',
                   'type' => 176,
                   'line' => 60
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 60
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Int',
                   'data' => '0',
                   'type' => 161,
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
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$foo',
                   'type' => 157,
                   'line' => 61
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'AddEqual',
                   'data' => '+=',
                   'type' => 20,
                   'line' => 61
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 61
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 61
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 61
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 61
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$a',
                   'type' => 157,
                   'line' => 61
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegOK',
                   'data' => '=~',
                   'type' => 31,
                   'line' => 61
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 61
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => '$rx',
                   'type' => 172,
                   'line' => 61
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 61
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegOpt',
                   'data' => 'g',
                   'type' => 136,
                   'line' => 61
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 61
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 61
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$output',
                   'type' => 157,
                   'line' => 62
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringAdd',
                   'data' => '.=',
                   'type' => 9,
                   'line' => 62
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => '$foo\\n',
                   'type' => 163,
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
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$foo',
                   'type' => 157,
                   'line' => 64
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 64
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Int',
                   'data' => '0',
                   'type' => 161,
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
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'ForStmt',
                   'data' => 'for',
                   'type' => 125,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$foo',
                   'type' => 157,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'AddEqual',
                   'data' => '+=',
                   'type' => 20,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$a',
                   'type' => 157,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegOK',
                   'data' => '=~',
                   'type' => 31,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => 'o',
                   'type' => 172,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
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
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SpecificValue',
                   'data' => '$\'',
                   'type' => 129,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'And',
                   'data' => '&&',
                   'type' => 16,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => 'o',
                   'type' => 172,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'And',
                   'data' => '&&',
                   'type' => 16,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$foo',
                   'type' => 157,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Inc',
                   'data' => '++',
                   'type' => 42,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
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
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
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
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$output',
                   'type' => 157,
                   'line' => 66
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringAdd',
                   'data' => '.=',
                   'type' => 9,
                   'line' => 66
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => '1: $foo\\n',
                   'type' => 163,
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
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$foo',
                   'type' => 157,
                   'line' => 68
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 68
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Int',
                   'data' => '0',
                   'type' => 161,
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
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'ForStmt',
                   'data' => 'for',
                   'type' => 125,
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
                   'name' => 'Var',
                   'data' => '$foo',
                   'type' => 157,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'AddEqual',
                   'data' => '+=',
                   'type' => 20,
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
                   'name' => 'Var',
                   'data' => '$a',
                   'type' => 157,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegOK',
                   'data' => '=~',
                   'type' => 31,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => '$rx',
                   'type' => 172,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
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
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SpecificValue',
                   'data' => '$\'',
                   'type' => 129,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'And',
                   'data' => '&&',
                   'type' => 16,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => '$rx',
                   'type' => 172,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'And',
                   'data' => '&&',
                   'type' => 16,
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
                   'name' => 'Var',
                   'data' => '$foo',
                   'type' => 157,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Inc',
                   'data' => '++',
                   'type' => 42,
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
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
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
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$output',
                   'type' => 157,
                   'line' => 70
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringAdd',
                   'data' => '.=',
                   'type' => 9,
                   'line' => 70
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => '2: $foo\\n',
                   'type' => 163,
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
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'is',
                   'type' => 114,
                   'line' => 72
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$output',
                   'type' => 157,
                   'line' => 72
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 72
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => '5\\n1: 5\\n2: 5\\n',
                   'type' => 163,
                   'line' => 72
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 72
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegQuote',
                   'data' => 'q',
                   'type' => 137,
                   'line' => 72
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '|',
                   'type' => 143,
                   'line' => 72
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => '/$qr/ with $\'_ aliased to a match var',
                   'type' => 172,
                   'line' => 72
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '|',
                   'type' => 143,
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
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 73
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 77
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$scratch',
                   'type' => 176,
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
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'FunctionDecl',
                   'data' => 'sub',
                   'type' => 58,
                   'line' => 78
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'qrBug',
                   'type' => 119,
                   'line' => 78
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 78
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'TIESCALAR',
                   'type' => 119,
                   'line' => 78
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 78
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'bless',
                   'type' => 64,
                   'line' => 78
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'type' => 104,
                   'line' => 78
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBracket',
                   'data' => ']',
                   'type' => 105,
                   'line' => 78
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 78
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'qrBug',
                   'type' => 164,
                   'line' => 78
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 78
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'FunctionDecl',
                   'data' => 'sub',
                   'type' => 58,
                   'line' => 79
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'qrBug',
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
                   'data' => 'FETCH',
                   'type' => 119,
                   'line' => 79
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 79
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$scratch',
                   'type' => 157,
                   'line' => 79
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringAdd',
                   'data' => '.=',
                   'type' => 9,
                   'line' => 79
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => '[fetching]',
                   'type' => 163,
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
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'glat',
                   'type' => 164,
                   'line' => 79
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 79
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'tie',
                   'type' => 64,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$flile',
                   'type' => 176,
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
                   'name' => 'String',
                   'data' => 'qrBug',
                   'type' => 163,
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
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$flile',
                   'type' => 157,
                   'line' => 81
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegOK',
                   'data' => '=~',
                   'type' => 31,
                   'line' => 81
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDecl',
                   'data' => 'qr',
                   'type' => 141,
                   'line' => 81
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 81
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => '(?:)',
                   'type' => 172,
                   'line' => 81
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
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
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'is',
                   'type' => 114,
                   'line' => 82
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$scratch',
                   'type' => 157,
                   'line' => 82
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 82
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => '[fetching]',
                   'type' => 163,
                   'line' => 82
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 82
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '/$qr/ with magical LHS',
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
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 83
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
            'token_num' => 6,
            'has_warnings' => 0,
            'end_line' => 4,
            'src' => ' chdir \'t\' if -d \'t\' ;',
            'start_line' => 4,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 4,
            'has_warnings' => 0,
            'end_line' => 5,
            'src' => ' @INC = \'../lib\' ;',
            'start_line' => 5,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 3,
            'has_warnings' => 0,
            'end_line' => 6,
            'src' => ' require \'./test.pl\' ;',
            'start_line' => 6,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 5,
            'has_warnings' => 1,
            'end_line' => 9,
            'src' => ' plan tests => 5 ;',
            'start_line' => 9,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 8,
            'has_warnings' => 0,
            'end_line' => 11,
            'src' => ' my $rx = qr// ;',
            'start_line' => 11,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 10,
            'has_warnings' => 1,
            'end_line' => 13,
            'src' => ' is ( ref $rx , "Regexp" , "qr// blessed into \'Regexp\' by default" ) ;',
            'start_line' => 13,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 128,
            'has_warnings' => 1,
            'end_line' => 35,
            'src' => ' { my $output = \'\' ; my $rx = qr/o/ ; my $a = "ooaoaoao" ; my $foo = 0 ; $foo += ( ) = ( $a =~/$rx/g ) ; $output .= "$foo\\n" ; $foo = 0 ; for ( $foo += ( $a =~/o/ ) ; $\' && ( $\' =~/o/ ) && ( $foo ++ ) ; ) { ; } $output .= "1: $foo\\n" ; $foo = 0 ; for ( $foo += ( $a =~/$rx/ ) ; $\' && ( $\' =~/$rx/ ) && ( $foo ++ ) ; ) { ; } $output .= "2: $foo\\n" ; is $output , "5\\n1: 5\\n2: 5\\n" , \'$a_match_var =~ /$qr/\' ; }',
            'start_line' => 17,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 5,
            'has_warnings' => 0,
            'end_line' => 18,
            'src' => ' my $output = \'\' ;',
            'start_line' => 18,
            'indent' => 1,
            'block_id' => 2
          },
          {
            'token_num' => 8,
            'has_warnings' => 0,
            'end_line' => 19,
            'src' => ' my $rx = qr/o/ ;',
            'start_line' => 19,
            'indent' => 1,
            'block_id' => 2
          },
          {
            'token_num' => 5,
            'has_warnings' => 0,
            'end_line' => 20,
            'src' => ' my $a = "ooaoaoao" ;',
            'start_line' => 20,
            'indent' => 1,
            'block_id' => 2
          },
          {
            'token_num' => 5,
            'has_warnings' => 0,
            'end_line' => 22,
            'src' => ' my $foo = 0 ;',
            'start_line' => 22,
            'indent' => 1,
            'block_id' => 2
          },
          {
            'token_num' => 14,
            'has_warnings' => 1,
            'end_line' => 23,
            'src' => ' $foo += ( ) = ( $a =~/$rx/g ) ;',
            'start_line' => 23,
            'indent' => 1,
            'block_id' => 2
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 24,
            'src' => ' $output .= "$foo\\n" ;',
            'start_line' => 24,
            'indent' => 1,
            'block_id' => 2
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 26,
            'src' => ' $foo = 0 ;',
            'start_line' => 26,
            'indent' => 1,
            'block_id' => 2
          },
          {
            'token_num' => 31,
            'has_warnings' => 1,
            'end_line' => 27,
            'src' => ' for ( $foo += ( $a =~/o/ ) ; $\' && ( $\' =~/o/ ) && ( $foo ++ ) ; ) { ; }',
            'start_line' => 27,
            'indent' => 1,
            'block_id' => 2
          },
          {
            'token_num' => 10,
            'has_warnings' => 1,
            'end_line' => 27,
            'src' => ' $foo += ( $a =~/o/ ) ;',
            'start_line' => 27,
            'indent' => 1,
            'block_id' => 2
          },
          {
            'token_num' => 15,
            'has_warnings' => 1,
            'end_line' => 27,
            'src' => ' $\' && ( $\' =~/o/ ) && ( $foo ++ ) ;',
            'start_line' => 27,
            'indent' => 1,
            'block_id' => 2
          },
          {
            'token_num' => 1,
            'has_warnings' => 0,
            'end_line' => 27,
            'src' => ' ;',
            'start_line' => 27,
            'indent' => 2,
            'block_id' => 3
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 28,
            'src' => ' $output .= "1: $foo\\n" ;',
            'start_line' => 28,
            'indent' => 1,
            'block_id' => 2
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 30,
            'src' => ' $foo = 0 ;',
            'start_line' => 30,
            'indent' => 1,
            'block_id' => 2
          },
          {
            'token_num' => 31,
            'has_warnings' => 1,
            'end_line' => 31,
            'src' => ' for ( $foo += ( $a =~/$rx/ ) ; $\' && ( $\' =~/$rx/ ) && ( $foo ++ ) ; ) { ; }',
            'start_line' => 31,
            'indent' => 1,
            'block_id' => 2
          },
          {
            'token_num' => 10,
            'has_warnings' => 1,
            'end_line' => 31,
            'src' => ' $foo += ( $a =~/$rx/ ) ;',
            'start_line' => 31,
            'indent' => 1,
            'block_id' => 3
          },
          {
            'token_num' => 15,
            'has_warnings' => 1,
            'end_line' => 31,
            'src' => ' $\' && ( $\' =~/$rx/ ) && ( $foo ++ ) ;',
            'start_line' => 31,
            'indent' => 1,
            'block_id' => 3
          },
          {
            'token_num' => 1,
            'has_warnings' => 0,
            'end_line' => 31,
            'src' => ' ;',
            'start_line' => 31,
            'indent' => 2,
            'block_id' => 4
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 32,
            'src' => ' $output .= "2: $foo\\n" ;',
            'start_line' => 32,
            'indent' => 1,
            'block_id' => 2
          },
          {
            'token_num' => 7,
            'has_warnings' => 1,
            'end_line' => 34,
            'src' => ' is $output , "5\\n1: 5\\n2: 5\\n" , \'$a_match_var =~ /$qr/\' ;',
            'start_line' => 34,
            'indent' => 1,
            'block_id' => 2
          },
          {
            'token_num' => 126,
            'has_warnings' => 1,
            'end_line' => 54,
            'src' => ' for my $_ ( $\' ) { my $output = \'\' ; my $rx = qr/o/ ; my $a = "ooaoaoao" ; my $foo = 0 ; $foo += ( ) = ( $a =~/$rx/g ) ; $output .= "$foo\\n" ; $foo = 0 ; for ( $foo += ( $a =~/o/ ) ; $\' &&/o/ && ( $foo ++ ) ; ) { ; } $output .= "1: $foo\\n" ; $foo = 0 ; for ( $foo += ( $a =~/$rx/ ) ; $\' &&/$rx/ && ( $foo ++ ) ; ) { ; } $output .= "2: $foo\\n" ; is $output , "5\\n1: 5\\n2: 5\\n" , \'/$qr/ with my $_ aliased to a match var\' ; }',
            'start_line' => 36,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 5,
            'has_warnings' => 0,
            'end_line' => 37,
            'src' => ' my $output = \'\' ;',
            'start_line' => 37,
            'indent' => 1,
            'block_id' => 5
          },
          {
            'token_num' => 8,
            'has_warnings' => 0,
            'end_line' => 38,
            'src' => ' my $rx = qr/o/ ;',
            'start_line' => 38,
            'indent' => 1,
            'block_id' => 5
          },
          {
            'token_num' => 5,
            'has_warnings' => 0,
            'end_line' => 39,
            'src' => ' my $a = "ooaoaoao" ;',
            'start_line' => 39,
            'indent' => 1,
            'block_id' => 5
          },
          {
            'token_num' => 5,
            'has_warnings' => 0,
            'end_line' => 41,
            'src' => ' my $foo = 0 ;',
            'start_line' => 41,
            'indent' => 1,
            'block_id' => 5
          },
          {
            'token_num' => 14,
            'has_warnings' => 1,
            'end_line' => 42,
            'src' => ' $foo += ( ) = ( $a =~/$rx/g ) ;',
            'start_line' => 42,
            'indent' => 1,
            'block_id' => 5
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 43,
            'src' => ' $output .= "$foo\\n" ;',
            'start_line' => 43,
            'indent' => 1,
            'block_id' => 5
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 45,
            'src' => ' $foo = 0 ;',
            'start_line' => 45,
            'indent' => 1,
            'block_id' => 5
          },
          {
            'token_num' => 27,
            'has_warnings' => 1,
            'end_line' => 46,
            'src' => ' for ( $foo += ( $a =~/o/ ) ; $\' &&/o/ && ( $foo ++ ) ; ) { ; }',
            'start_line' => 46,
            'indent' => 1,
            'block_id' => 5
          },
          {
            'token_num' => 10,
            'has_warnings' => 1,
            'end_line' => 46,
            'src' => ' $foo += ( $a =~/o/ ) ;',
            'start_line' => 46,
            'indent' => 1,
            'block_id' => 5
          },
          {
            'token_num' => 11,
            'has_warnings' => 1,
            'end_line' => 46,
            'src' => ' $\' &&/o/ && ( $foo ++ ) ;',
            'start_line' => 46,
            'indent' => 1,
            'block_id' => 5
          },
          {
            'token_num' => 1,
            'has_warnings' => 0,
            'end_line' => 46,
            'src' => ' ;',
            'start_line' => 46,
            'indent' => 2,
            'block_id' => 6
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 47,
            'src' => ' $output .= "1: $foo\\n" ;',
            'start_line' => 47,
            'indent' => 1,
            'block_id' => 5
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 49,
            'src' => ' $foo = 0 ;',
            'start_line' => 49,
            'indent' => 1,
            'block_id' => 5
          },
          {
            'token_num' => 27,
            'has_warnings' => 1,
            'end_line' => 50,
            'src' => ' for ( $foo += ( $a =~/$rx/ ) ; $\' &&/$rx/ && ( $foo ++ ) ; ) { ; }',
            'start_line' => 50,
            'indent' => 1,
            'block_id' => 5
          },
          {
            'token_num' => 10,
            'has_warnings' => 1,
            'end_line' => 50,
            'src' => ' $foo += ( $a =~/$rx/ ) ;',
            'start_line' => 50,
            'indent' => 1,
            'block_id' => 6
          },
          {
            'token_num' => 11,
            'has_warnings' => 1,
            'end_line' => 50,
            'src' => ' $\' &&/$rx/ && ( $foo ++ ) ;',
            'start_line' => 50,
            'indent' => 1,
            'block_id' => 6
          },
          {
            'token_num' => 1,
            'has_warnings' => 0,
            'end_line' => 50,
            'src' => ' ;',
            'start_line' => 50,
            'indent' => 2,
            'block_id' => 7
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 51,
            'src' => ' $output .= "2: $foo\\n" ;',
            'start_line' => 51,
            'indent' => 1,
            'block_id' => 5
          },
          {
            'token_num' => 7,
            'has_warnings' => 1,
            'end_line' => 53,
            'src' => ' is $output , "5\\n1: 5\\n2: 5\\n" , \'/$qr/ with my $_ aliased to a match var\' ;',
            'start_line' => 53,
            'indent' => 1,
            'block_id' => 5
          },
          {
            'token_num' => 127,
            'has_warnings' => 1,
            'end_line' => 73,
            'src' => ' for ( $\' ) { my $output = \'\' ; my $rx = qr/o/ ; my $a = "ooaoaoao" ; my $foo = 0 ; $foo += ( ) = ( $a =~/$rx/g ) ; $output .= "$foo\\n" ; $foo = 0 ; for ( $foo += ( $a =~/o/ ) ; $\' &&/o/ && ( $foo ++ ) ; ) { ; } $output .= "1: $foo\\n" ; $foo = 0 ; for ( $foo += ( $a =~/$rx/ ) ; $\' &&/$rx/ && ( $foo ++ ) ; ) { ; } $output .= "2: $foo\\n" ; is $output , "5\\n1: 5\\n2: 5\\n" , q|/$qr/ with $\'_ aliased to a match var| ; }',
            'start_line' => 55,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 5,
            'has_warnings' => 0,
            'end_line' => 56,
            'src' => ' my $output = \'\' ;',
            'start_line' => 56,
            'indent' => 1,
            'block_id' => 8
          },
          {
            'token_num' => 8,
            'has_warnings' => 0,
            'end_line' => 57,
            'src' => ' my $rx = qr/o/ ;',
            'start_line' => 57,
            'indent' => 1,
            'block_id' => 8
          },
          {
            'token_num' => 5,
            'has_warnings' => 0,
            'end_line' => 58,
            'src' => ' my $a = "ooaoaoao" ;',
            'start_line' => 58,
            'indent' => 1,
            'block_id' => 8
          },
          {
            'token_num' => 5,
            'has_warnings' => 0,
            'end_line' => 60,
            'src' => ' my $foo = 0 ;',
            'start_line' => 60,
            'indent' => 1,
            'block_id' => 8
          },
          {
            'token_num' => 14,
            'has_warnings' => 1,
            'end_line' => 61,
            'src' => ' $foo += ( ) = ( $a =~/$rx/g ) ;',
            'start_line' => 61,
            'indent' => 1,
            'block_id' => 8
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 62,
            'src' => ' $output .= "$foo\\n" ;',
            'start_line' => 62,
            'indent' => 1,
            'block_id' => 8
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 64,
            'src' => ' $foo = 0 ;',
            'start_line' => 64,
            'indent' => 1,
            'block_id' => 8
          },
          {
            'token_num' => 27,
            'has_warnings' => 1,
            'end_line' => 65,
            'src' => ' for ( $foo += ( $a =~/o/ ) ; $\' &&/o/ && ( $foo ++ ) ; ) { ; }',
            'start_line' => 65,
            'indent' => 1,
            'block_id' => 8
          },
          {
            'token_num' => 10,
            'has_warnings' => 1,
            'end_line' => 65,
            'src' => ' $foo += ( $a =~/o/ ) ;',
            'start_line' => 65,
            'indent' => 1,
            'block_id' => 8
          },
          {
            'token_num' => 11,
            'has_warnings' => 1,
            'end_line' => 65,
            'src' => ' $\' &&/o/ && ( $foo ++ ) ;',
            'start_line' => 65,
            'indent' => 1,
            'block_id' => 8
          },
          {
            'token_num' => 1,
            'has_warnings' => 0,
            'end_line' => 65,
            'src' => ' ;',
            'start_line' => 65,
            'indent' => 2,
            'block_id' => 9
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 66,
            'src' => ' $output .= "1: $foo\\n" ;',
            'start_line' => 66,
            'indent' => 1,
            'block_id' => 8
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 68,
            'src' => ' $foo = 0 ;',
            'start_line' => 68,
            'indent' => 1,
            'block_id' => 8
          },
          {
            'token_num' => 27,
            'has_warnings' => 1,
            'end_line' => 69,
            'src' => ' for ( $foo += ( $a =~/$rx/ ) ; $\' &&/$rx/ && ( $foo ++ ) ; ) { ; }',
            'start_line' => 69,
            'indent' => 1,
            'block_id' => 8
          },
          {
            'token_num' => 10,
            'has_warnings' => 1,
            'end_line' => 69,
            'src' => ' $foo += ( $a =~/$rx/ ) ;',
            'start_line' => 69,
            'indent' => 1,
            'block_id' => 9
          },
          {
            'token_num' => 11,
            'has_warnings' => 1,
            'end_line' => 69,
            'src' => ' $\' &&/$rx/ && ( $foo ++ ) ;',
            'start_line' => 69,
            'indent' => 1,
            'block_id' => 9
          },
          {
            'token_num' => 1,
            'has_warnings' => 0,
            'end_line' => 69,
            'src' => ' ;',
            'start_line' => 69,
            'indent' => 2,
            'block_id' => 10
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 70,
            'src' => ' $output .= "2: $foo\\n" ;',
            'start_line' => 70,
            'indent' => 1,
            'block_id' => 8
          },
          {
            'token_num' => 10,
            'has_warnings' => 1,
            'end_line' => 72,
            'src' => ' is $output , "5\\n1: 5\\n2: 5\\n" , q|/$qr/ with $\'_ aliased to a match var| ;',
            'start_line' => 72,
            'indent' => 1,
            'block_id' => 8
          },
          {
            'token_num' => 43,
            'has_warnings' => 1,
            'end_line' => 83,
            'src' => ' { my $scratch ; sub qrBug::TIESCALAR { bless [ ] , \'qrBug\' } sub qrBug::FETCH { $scratch .= "[fetching]" ; \'glat\' } tie my $flile , "qrBug" ; $flile =~ qr/(?:)/ ; is $scratch , "[fetching]" , \'/$qr/ with magical LHS\' ; }',
            'start_line' => 76,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 3,
            'has_warnings' => 0,
            'end_line' => 77,
            'src' => ' my $scratch ;',
            'start_line' => 77,
            'indent' => 1,
            'block_id' => 11
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 79,
            'src' => ' $scratch .= "[fetching]" ;',
            'start_line' => 79,
            'indent' => 2,
            'block_id' => 13
          },
          {
            'token_num' => 6,
            'has_warnings' => 0,
            'end_line' => 80,
            'src' => ' tie my $flile , "qrBug" ;',
            'start_line' => 80,
            'indent' => 1,
            'block_id' => 11
          },
          {
            'token_num' => 7,
            'has_warnings' => 1,
            'end_line' => 81,
            'src' => ' $flile =~ qr/(?:)/ ;',
            'start_line' => 81,
            'indent' => 1,
            'block_id' => 11
          },
          {
            'token_num' => 7,
            'has_warnings' => 1,
            'end_line' => 82,
            'src' => ' is $scratch , "[fetching]" , \'/$qr/ with magical LHS\' ;',
            'start_line' => 82,
            'indent' => 1,
            'block_id' => 11
          }
        ]
, 'Compiler::Lexer::get_groups_by_syntax_level');
};

subtest 'get_used_modules' => sub {
    my $modules = Compiler::Lexer->new('')->get_used_modules($script);
    is_deeply($modules, []
, 'Compiler::Lexer::get_used_modules');
};

done_testing;
