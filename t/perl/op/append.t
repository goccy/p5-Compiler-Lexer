use strict;
use warnings;
use Test::More;
BEGIN {
    use_ok('Compiler::Lexer');
}
my $script =<<'SCRIPT';
#!./perl

print "1..13\n";

$a = 'ab' . 'c';	# compile time
$b = 'def';

$c = $a . $b;
print "#1\t:$c: eq :abcdef:\n";
if ($c eq 'abcdef') {print "ok 1\n";} else {print "not ok 1\n";}

$c .= 'xyz';
print "#2\t:$c: eq :abcdefxyz:\n";
if ($c eq 'abcdefxyz') {print "ok 2\n";} else {print "not ok 2\n";}

$_ = $a;
$_ .= $b;
print "#3\t:$_: eq :abcdef:\n";
if ($_ eq 'abcdef') {print "ok 3\n";} else {print "not ok 3\n";}

# test that when right argument of concat is UTF8, and is the same
# variable as the target, and the left argument is not UTF8, it no
# longer frees the wrong string.
{
    sub r2 {
	my $string = '';
	$string .= pack("U0a*", 'mnopqrstuvwx');
	$string = "abcdefghijkl$string";
    }

    r2() and print "ok $_\n" for qw/ 4 5 /;
}

# test that nul bytes get copied
{
    my ($a, $ab)   = ("a", "a\0b");
    my ($ua, $uab) = map pack("U0a*", $_), $a, $ab;

    my $ub = pack("U0a*", 'b');

    my $t1 = $a; $t1 .= $ab;

    print $t1 =~ /b/ ? "ok 6\n" : "not ok 6\t# $t1\n";
    
    my $t2 = $a; $t2 .= $uab;
    
    print eval '$t2 =~ /$ub/' ? "ok 7\n" : "not ok 7\t# $t2\n";
    
    my $t3 = $ua; $t3 .= $ab;
    
    print $t3 =~ /$ub/ ? "ok 8\n" : "not ok 8\t# $t3\n";
    
    my $t4 = $ua; $t4 .= $uab;
    
    print eval '$t4 =~ /$ub/' ? "ok 9\n" : "not ok 9\t# $t4\n";
    
    my $t5 = $a; $t5 = $ab . $t5;
    
    print $t5 =~ /$ub/ ? "ok 10\n" : "not ok 10\t# $t5\n";
    
    my $t6 = $a; $t6 = $uab . $t6;
    
    print eval '$t6 =~ /$ub/' ? "ok 11\n" : "not ok 11\t# $t6\n";
    
    my $t7 = $ua; $t7 = $ab . $t7;
    
    print $t7 =~ /$ub/ ? "ok 12\n" : "not ok 12\t# $t7\n";
    
    my $t8 = $ua; $t8 = $uab . $t8;
    
    print eval '$t8 =~ /$ub/' ? "ok 13\n" : "not ok 13\t# $t8\n";
}

SCRIPT

subtest 'tokenize' => sub {
    my $tokens = Compiler::Lexer->new('')->tokenize($script);
    is_deeply($$tokens, [
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'print',
                   'type' => 64,
                   'line' => 3
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => '1..13\\n',
                   'type' => 163,
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
                   'name' => 'GlobalVar',
                   'data' => '$a',
                   'type' => 179,
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
                   'data' => 'ab',
                   'type' => 164,
                   'line' => 5
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringAdd',
                   'data' => '.',
                   'type' => 9,
                   'line' => 5
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'c',
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
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'GlobalVar',
                   'data' => '$b',
                   'type' => 179,
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'def',
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
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'GlobalVar',
                   'data' => '$c',
                   'type' => 179,
                   'line' => 8
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 8
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$a',
                   'type' => 157,
                   'line' => 8
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringAdd',
                   'data' => '.',
                   'type' => 9,
                   'line' => 8
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$b',
                   'type' => 157,
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
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'print',
                   'type' => 64,
                   'line' => 9
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => '#1\\t:$c: eq :abcdef:\\n',
                   'type' => 163,
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
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'IfStmt',
                   'data' => 'if',
                   'type' => 89,
                   'line' => 10
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 10
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$c',
                   'type' => 157,
                   'line' => 10
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringEqual',
                   'data' => 'eq',
                   'type' => 39,
                   'line' => 10
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'abcdef',
                   'type' => 164,
                   'line' => 10
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 10
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 10
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'print',
                   'type' => 64,
                   'line' => 10
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'ok 1\\n',
                   'type' => 163,
                   'line' => 10
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 10
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 10
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'ElseStmt',
                   'data' => 'else',
                   'type' => 90,
                   'line' => 10
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 10
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'print',
                   'type' => 64,
                   'line' => 10
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'not ok 1\\n',
                   'type' => 163,
                   'line' => 10
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 10
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 10
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$c',
                   'type' => 157,
                   'line' => 12
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringAdd',
                   'data' => '.=',
                   'type' => 9,
                   'line' => 12
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'xyz',
                   'type' => 164,
                   'line' => 12
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 12
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'print',
                   'type' => 64,
                   'line' => 13
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => '#2\\t:$c: eq :abcdefxyz:\\n',
                   'type' => 163,
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
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'IfStmt',
                   'data' => 'if',
                   'type' => 89,
                   'line' => 14
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 14
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$c',
                   'type' => 157,
                   'line' => 14
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringEqual',
                   'data' => 'eq',
                   'type' => 39,
                   'line' => 14
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'abcdefxyz',
                   'type' => 164,
                   'line' => 14
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 14
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 14
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'print',
                   'type' => 64,
                   'line' => 14
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'ok 2\\n',
                   'type' => 163,
                   'line' => 14
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 14
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 14
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'ElseStmt',
                   'data' => 'else',
                   'type' => 90,
                   'line' => 14
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 14
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'print',
                   'type' => 64,
                   'line' => 14
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'not ok 2\\n',
                   'type' => 163,
                   'line' => 14
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 14
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 14
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SpecificValue',
                   'data' => '$_',
                   'type' => 129,
                   'line' => 16
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 16
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$a',
                   'type' => 157,
                   'line' => 16
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 16
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SpecificValue',
                   'data' => '$_',
                   'type' => 129,
                   'line' => 17
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringAdd',
                   'data' => '.=',
                   'type' => 9,
                   'line' => 17
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$b',
                   'type' => 157,
                   'line' => 17
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 17
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'print',
                   'type' => 64,
                   'line' => 18
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => '#3\\t:$_: eq :abcdef:\\n',
                   'type' => 163,
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
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'IfStmt',
                   'data' => 'if',
                   'type' => 89,
                   'line' => 19
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 19
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SpecificValue',
                   'data' => '$_',
                   'type' => 129,
                   'line' => 19
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringEqual',
                   'data' => 'eq',
                   'type' => 39,
                   'line' => 19
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'abcdef',
                   'type' => 164,
                   'line' => 19
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 19
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 19
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'print',
                   'type' => 64,
                   'line' => 19
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'ok 3\\n',
                   'type' => 163,
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
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 19
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'ElseStmt',
                   'data' => 'else',
                   'type' => 90,
                   'line' => 19
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 19
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'print',
                   'type' => 64,
                   'line' => 19
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'not ok 3\\n',
                   'type' => 163,
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
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 19
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 24
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'FunctionDecl',
                   'data' => 'sub',
                   'type' => 58,
                   'line' => 25
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Function',
                   'data' => 'r2',
                   'type' => 188,
                   'line' => 25
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 25
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 26
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$string',
                   'type' => 176,
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
                   'name' => 'RawString',
                   'data' => '',
                   'type' => 164,
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
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$string',
                   'type' => 157,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringAdd',
                   'data' => '.=',
                   'type' => 9,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'pack',
                   'type' => 64,
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
                   'name' => 'String',
                   'data' => 'U0a*',
                   'type' => 163,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'mnopqrstuvwx',
                   'type' => 164,
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
                   'name' => 'Var',
                   'data' => '$string',
                   'type' => 157,
                   'line' => 28
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 28
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'abcdefghijkl$string',
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
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 29
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Call',
                   'data' => 'r2',
                   'type' => 189,
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
                   'data' => 'and',
                   'type' => 16,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'print',
                   'type' => 64,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'ok $_\\n',
                   'type' => 163,
                   'line' => 31
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
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegList',
                   'data' => 'qw',
                   'type' => 139,
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
                   'data' => ' 4 5 ',
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
                   'line' => 32
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 35
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
                   'name' => 'Var',
                   'data' => '$a',
                   'type' => 157,
                   'line' => 36
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 36
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'GlobalVar',
                   'data' => '$ab',
                   'type' => 179,
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
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
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
                   'name' => 'String',
                   'data' => 'a',
                   'type' => 163,
                   'line' => 36
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 36
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'a\\0b',
                   'type' => 163,
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
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
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
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 37
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'GlobalVar',
                   'data' => '$ua',
                   'type' => 179,
                   'line' => 37
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 37
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'GlobalVar',
                   'data' => '$uab',
                   'type' => 179,
                   'line' => 37
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
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
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'map',
                   'type' => 64,
                   'line' => 37
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'pack',
                   'type' => 64,
                   'line' => 37
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 37
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'U0a*',
                   'type' => 163,
                   'line' => 37
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 37
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SpecificValue',
                   'data' => '$_',
                   'type' => 129,
                   'line' => 37
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 37
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 37
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$a',
                   'type' => 157,
                   'line' => 37
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 37
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$ab',
                   'type' => 157,
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
                   'line' => 39
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$ub',
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
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'pack',
                   'type' => 64,
                   'line' => 39
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 39
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'U0a*',
                   'type' => 163,
                   'line' => 39
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 39
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'b',
                   'type' => 164,
                   'line' => 39
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
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
                   'data' => '$t1',
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
                   'name' => 'Var',
                   'data' => '$a',
                   'type' => 157,
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
                   'data' => '$t1',
                   'type' => 157,
                   'line' => 41
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringAdd',
                   'data' => '.=',
                   'type' => 9,
                   'line' => 41
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$ab',
                   'type' => 157,
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
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'print',
                   'type' => 64,
                   'line' => 43
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$t1',
                   'type' => 157,
                   'line' => 43
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegOK',
                   'data' => '=~',
                   'type' => 31,
                   'line' => 43
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 43
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => 'b',
                   'type' => 172,
                   'line' => 43
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 43
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'ThreeTermOperator',
                   'data' => '?',
                   'type' => 6,
                   'line' => 43
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'ok 6\\n',
                   'type' => 163,
                   'line' => 43
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 25,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Colon',
                   'data' => ':',
                   'type' => 98,
                   'line' => 43
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'not ok 6\\t# $t1\\n',
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
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 45
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$t2',
                   'type' => 176,
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
                   'name' => 'Var',
                   'data' => '$a',
                   'type' => 157,
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
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$t2',
                   'type' => 157,
                   'line' => 45
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringAdd',
                   'data' => '.=',
                   'type' => 9,
                   'line' => 45
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$uab',
                   'type' => 157,
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
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'print',
                   'type' => 64,
                   'line' => 47
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'eval',
                   'type' => 64,
                   'line' => 47
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '$t2 =~ /$ub/',
                   'type' => 164,
                   'line' => 47
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'ThreeTermOperator',
                   'data' => '?',
                   'type' => 6,
                   'line' => 47
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'ok 7\\n',
                   'type' => 163,
                   'line' => 47
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 25,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Colon',
                   'data' => ':',
                   'type' => 98,
                   'line' => 47
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'not ok 7\\t# $t2\\n',
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
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 49
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$t3',
                   'type' => 176,
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
                   'name' => 'Var',
                   'data' => '$ua',
                   'type' => 157,
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
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$t3',
                   'type' => 157,
                   'line' => 49
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringAdd',
                   'data' => '.=',
                   'type' => 9,
                   'line' => 49
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$ab',
                   'type' => 157,
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
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'print',
                   'type' => 64,
                   'line' => 51
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$t3',
                   'type' => 157,
                   'line' => 51
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegOK',
                   'data' => '=~',
                   'type' => 31,
                   'line' => 51
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 51
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => '$ub',
                   'type' => 172,
                   'line' => 51
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 51
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'ThreeTermOperator',
                   'data' => '?',
                   'type' => 6,
                   'line' => 51
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'ok 8\\n',
                   'type' => 163,
                   'line' => 51
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 25,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Colon',
                   'data' => ':',
                   'type' => 98,
                   'line' => 51
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'not ok 8\\t# $t3\\n',
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
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 53
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$t4',
                   'type' => 176,
                   'line' => 53
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 53
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$ua',
                   'type' => 157,
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
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$t4',
                   'type' => 157,
                   'line' => 53
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringAdd',
                   'data' => '.=',
                   'type' => 9,
                   'line' => 53
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$uab',
                   'type' => 157,
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
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'print',
                   'type' => 64,
                   'line' => 55
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'eval',
                   'type' => 64,
                   'line' => 55
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '$t4 =~ /$ub/',
                   'type' => 164,
                   'line' => 55
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'ThreeTermOperator',
                   'data' => '?',
                   'type' => 6,
                   'line' => 55
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'ok 9\\n',
                   'type' => 163,
                   'line' => 55
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 25,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Colon',
                   'data' => ':',
                   'type' => 98,
                   'line' => 55
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'not ok 9\\t# $t4\\n',
                   'type' => 163,
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
                   'data' => '$t5',
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
                   'name' => 'Var',
                   'data' => '$a',
                   'type' => 157,
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
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$t5',
                   'type' => 157,
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
                   'name' => 'Var',
                   'data' => '$ab',
                   'type' => 157,
                   'line' => 57
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringAdd',
                   'data' => '.',
                   'type' => 9,
                   'line' => 57
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$t5',
                   'type' => 157,
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
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'print',
                   'type' => 64,
                   'line' => 59
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$t5',
                   'type' => 157,
                   'line' => 59
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegOK',
                   'data' => '=~',
                   'type' => 31,
                   'line' => 59
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 59
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => '$ub',
                   'type' => 172,
                   'line' => 59
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 59
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'ThreeTermOperator',
                   'data' => '?',
                   'type' => 6,
                   'line' => 59
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'ok 10\\n',
                   'type' => 163,
                   'line' => 59
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 25,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Colon',
                   'data' => ':',
                   'type' => 98,
                   'line' => 59
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'not ok 10\\t# $t5\\n',
                   'type' => 163,
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
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 61
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$t6',
                   'type' => 176,
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
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$a',
                   'type' => 157,
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
                   'data' => '$t6',
                   'type' => 157,
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
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$uab',
                   'type' => 157,
                   'line' => 61
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringAdd',
                   'data' => '.',
                   'type' => 9,
                   'line' => 61
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$t6',
                   'type' => 157,
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
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'print',
                   'type' => 64,
                   'line' => 63
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'eval',
                   'type' => 64,
                   'line' => 63
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '$t6 =~ /$ub/',
                   'type' => 164,
                   'line' => 63
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'ThreeTermOperator',
                   'data' => '?',
                   'type' => 6,
                   'line' => 63
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'ok 11\\n',
                   'type' => 163,
                   'line' => 63
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 25,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Colon',
                   'data' => ':',
                   'type' => 98,
                   'line' => 63
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'not ok 11\\t# $t6\\n',
                   'type' => 163,
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
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$t7',
                   'type' => 176,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$ua',
                   'type' => 157,
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
                   'name' => 'Var',
                   'data' => '$t7',
                   'type' => 157,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$ab',
                   'type' => 157,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringAdd',
                   'data' => '.',
                   'type' => 9,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$t7',
                   'type' => 157,
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
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'print',
                   'type' => 64,
                   'line' => 67
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$t7',
                   'type' => 157,
                   'line' => 67
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegOK',
                   'data' => '=~',
                   'type' => 31,
                   'line' => 67
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 67
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => '$ub',
                   'type' => 172,
                   'line' => 67
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 67
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'ThreeTermOperator',
                   'data' => '?',
                   'type' => 6,
                   'line' => 67
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'ok 12\\n',
                   'type' => 163,
                   'line' => 67
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 25,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Colon',
                   'data' => ':',
                   'type' => 98,
                   'line' => 67
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'not ok 12\\t# $t7\\n',
                   'type' => 163,
                   'line' => 67
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 67
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$t8',
                   'type' => 176,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$ua',
                   'type' => 157,
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
                   'name' => 'Var',
                   'data' => '$t8',
                   'type' => 157,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$uab',
                   'type' => 157,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringAdd',
                   'data' => '.',
                   'type' => 9,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$t8',
                   'type' => 157,
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
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'print',
                   'type' => 64,
                   'line' => 71
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'eval',
                   'type' => 64,
                   'line' => 71
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '$t8 =~ /$ub/',
                   'type' => 164,
                   'line' => 71
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'ThreeTermOperator',
                   'data' => '?',
                   'type' => 6,
                   'line' => 71
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'ok 13\\n',
                   'type' => 163,
                   'line' => 71
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 25,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Colon',
                   'data' => ':',
                   'type' => 98,
                   'line' => 71
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'not ok 13\\t# $t8\\n',
                   'type' => 163,
                   'line' => 71
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 71
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 72
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
            'src' => ' print "1..13\\n" ;',
            'start_line' => 3,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 6,
            'has_warnings' => 1,
            'end_line' => 5,
            'src' => ' $a = \'ab\' . \'c\' ;',
            'start_line' => 5,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 6,
            'src' => ' $b = \'def\' ;',
            'start_line' => 6,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 6,
            'has_warnings' => 1,
            'end_line' => 8,
            'src' => ' $c = $a . $b ;',
            'start_line' => 8,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 3,
            'has_warnings' => 0,
            'end_line' => 9,
            'src' => ' print "#1\\t:$c: eq :abcdef:\\n" ;',
            'start_line' => 9,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 11,
            'has_warnings' => 1,
            'end_line' => 10,
            'src' => ' if ( $c eq \'abcdef\' ) { print "ok 1\\n" ; }',
            'start_line' => 10,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 3,
            'has_warnings' => 0,
            'end_line' => 10,
            'src' => ' print "ok 1\\n" ;',
            'start_line' => 10,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 6,
            'has_warnings' => 0,
            'end_line' => 10,
            'src' => ' else { print "not ok 1\\n" ; }',
            'start_line' => 10,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 3,
            'has_warnings' => 0,
            'end_line' => 10,
            'src' => ' print "not ok 1\\n" ;',
            'start_line' => 10,
            'indent' => 1,
            'block_id' => 2
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 12,
            'src' => ' $c .= \'xyz\' ;',
            'start_line' => 12,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 3,
            'has_warnings' => 0,
            'end_line' => 13,
            'src' => ' print "#2\\t:$c: eq :abcdefxyz:\\n" ;',
            'start_line' => 13,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 11,
            'has_warnings' => 1,
            'end_line' => 14,
            'src' => ' if ( $c eq \'abcdefxyz\' ) { print "ok 2\\n" ; }',
            'start_line' => 14,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 3,
            'has_warnings' => 0,
            'end_line' => 14,
            'src' => ' print "ok 2\\n" ;',
            'start_line' => 14,
            'indent' => 1,
            'block_id' => 3
          },
          {
            'token_num' => 6,
            'has_warnings' => 0,
            'end_line' => 14,
            'src' => ' else { print "not ok 2\\n" ; }',
            'start_line' => 14,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 3,
            'has_warnings' => 0,
            'end_line' => 14,
            'src' => ' print "not ok 2\\n" ;',
            'start_line' => 14,
            'indent' => 1,
            'block_id' => 4
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 16,
            'src' => ' $_ = $a ;',
            'start_line' => 16,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 17,
            'src' => ' $_ .= $b ;',
            'start_line' => 17,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 3,
            'has_warnings' => 0,
            'end_line' => 18,
            'src' => ' print "#3\\t:$_: eq :abcdef:\\n" ;',
            'start_line' => 18,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 11,
            'has_warnings' => 0,
            'end_line' => 19,
            'src' => ' if ( $_ eq \'abcdef\' ) { print "ok 3\\n" ; }',
            'start_line' => 19,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 3,
            'has_warnings' => 0,
            'end_line' => 19,
            'src' => ' print "ok 3\\n" ;',
            'start_line' => 19,
            'indent' => 1,
            'block_id' => 5
          },
          {
            'token_num' => 6,
            'has_warnings' => 0,
            'end_line' => 19,
            'src' => ' else { print "not ok 3\\n" ; }',
            'start_line' => 19,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 3,
            'has_warnings' => 0,
            'end_line' => 19,
            'src' => ' print "not ok 3\\n" ;',
            'start_line' => 19,
            'indent' => 1,
            'block_id' => 6
          },
          {
            'token_num' => 36,
            'has_warnings' => 1,
            'end_line' => 32,
            'src' => ' { sub r2 { my $string = \'\' ; $string .= pack ( "U0a*" , \'mnopqrstuvwx\' ) ; $string = "abcdefghijkl$string" ; } r2 ( ) and print "ok $_\\n" for qw/ 4 5 / ; }',
            'start_line' => 24,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 22,
            'has_warnings' => 1,
            'end_line' => 29,
            'src' => ' sub r2 { my $string = \'\' ; $string .= pack ( "U0a*" , \'mnopqrstuvwx\' ) ; $string = "abcdefghijkl$string" ; }',
            'start_line' => 25,
            'indent' => 1,
            'block_id' => 7
          },
          {
            'token_num' => 5,
            'has_warnings' => 0,
            'end_line' => 26,
            'src' => ' my $string = \'\' ;',
            'start_line' => 26,
            'indent' => 2,
            'block_id' => 8
          },
          {
            'token_num' => 9,
            'has_warnings' => 1,
            'end_line' => 27,
            'src' => ' $string .= pack ( "U0a*" , \'mnopqrstuvwx\' ) ;',
            'start_line' => 27,
            'indent' => 2,
            'block_id' => 8
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 28,
            'src' => ' $string = "abcdefghijkl$string" ;',
            'start_line' => 28,
            'indent' => 2,
            'block_id' => 8
          },
          {
            'token_num' => 12,
            'has_warnings' => 0,
            'end_line' => 31,
            'src' => ' r2 ( ) and print "ok $_\\n" for qw/ 4 5 / ;',
            'start_line' => 31,
            'indent' => 1,
            'block_id' => 7
          },
          {
            'token_num' => 200,
            'has_warnings' => 1,
            'end_line' => 72,
            'src' => ' { my ( $a , $ab ) = ( "a" , "a\\0b" ) ; my ( $ua , $uab ) = map pack ( "U0a*" , $_ ) , $a , $ab ; my $ub = pack ( "U0a*" , \'b\' ) ; my $t1 = $a ; $t1 .= $ab ; print $t1 =~/b/ ? "ok 6\\n" : "not ok 6\\t# $t1\\n" ; my $t2 = $a ; $t2 .= $uab ; print eval \'$t2 =~ /$ub/\' ? "ok 7\\n" : "not ok 7\\t# $t2\\n" ; my $t3 = $ua ; $t3 .= $ab ; print $t3 =~/$ub/ ? "ok 8\\n" : "not ok 8\\t# $t3\\n" ; my $t4 = $ua ; $t4 .= $uab ; print eval \'$t4 =~ /$ub/\' ? "ok 9\\n" : "not ok 9\\t# $t4\\n" ; my $t5 = $a ; $t5 = $ab . $t5 ; print $t5 =~/$ub/ ? "ok 10\\n" : "not ok 10\\t# $t5\\n" ; my $t6 = $a ; $t6 = $uab . $t6 ; print eval \'$t6 =~ /$ub/\' ? "ok 11\\n" : "not ok 11\\t# $t6\\n" ; my $t7 = $ua ; $t7 = $ab . $t7 ; print $t7 =~/$ub/ ? "ok 12\\n" : "not ok 12\\t# $t7\\n" ; my $t8 = $ua ; $t8 = $uab . $t8 ; print eval \'$t8 =~ /$ub/\' ? "ok 13\\n" : "not ok 13\\t# $t8\\n" ; }',
            'start_line' => 35,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 13,
            'has_warnings' => 1,
            'end_line' => 36,
            'src' => ' my ( $a , $ab ) = ( "a" , "a\\0b" ) ;',
            'start_line' => 36,
            'indent' => 1,
            'block_id' => 9
          },
          {
            'token_num' => 19,
            'has_warnings' => 1,
            'end_line' => 37,
            'src' => ' my ( $ua , $uab ) = map pack ( "U0a*" , $_ ) , $a , $ab ;',
            'start_line' => 37,
            'indent' => 1,
            'block_id' => 9
          },
          {
            'token_num' => 10,
            'has_warnings' => 0,
            'end_line' => 39,
            'src' => ' my $ub = pack ( "U0a*" , \'b\' ) ;',
            'start_line' => 39,
            'indent' => 1,
            'block_id' => 9
          },
          {
            'token_num' => 5,
            'has_warnings' => 1,
            'end_line' => 41,
            'src' => ' my $t1 = $a ;',
            'start_line' => 41,
            'indent' => 1,
            'block_id' => 9
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 41,
            'src' => ' $t1 .= $ab ;',
            'start_line' => 41,
            'indent' => 1,
            'block_id' => 9
          },
          {
            'token_num' => 11,
            'has_warnings' => 1,
            'end_line' => 43,
            'src' => ' print $t1 =~/b/ ? "ok 6\\n" : "not ok 6\\t# $t1\\n" ;',
            'start_line' => 43,
            'indent' => 1,
            'block_id' => 9
          },
          {
            'token_num' => 5,
            'has_warnings' => 1,
            'end_line' => 45,
            'src' => ' my $t2 = $a ;',
            'start_line' => 45,
            'indent' => 1,
            'block_id' => 9
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 45,
            'src' => ' $t2 .= $uab ;',
            'start_line' => 45,
            'indent' => 1,
            'block_id' => 9
          },
          {
            'token_num' => 8,
            'has_warnings' => 0,
            'end_line' => 47,
            'src' => ' print eval \'$t2 =~ /$ub/\' ? "ok 7\\n" : "not ok 7\\t# $t2\\n" ;',
            'start_line' => 47,
            'indent' => 1,
            'block_id' => 9
          },
          {
            'token_num' => 5,
            'has_warnings' => 1,
            'end_line' => 49,
            'src' => ' my $t3 = $ua ;',
            'start_line' => 49,
            'indent' => 1,
            'block_id' => 9
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 49,
            'src' => ' $t3 .= $ab ;',
            'start_line' => 49,
            'indent' => 1,
            'block_id' => 9
          },
          {
            'token_num' => 11,
            'has_warnings' => 1,
            'end_line' => 51,
            'src' => ' print $t3 =~/$ub/ ? "ok 8\\n" : "not ok 8\\t# $t3\\n" ;',
            'start_line' => 51,
            'indent' => 1,
            'block_id' => 9
          },
          {
            'token_num' => 5,
            'has_warnings' => 1,
            'end_line' => 53,
            'src' => ' my $t4 = $ua ;',
            'start_line' => 53,
            'indent' => 1,
            'block_id' => 9
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 53,
            'src' => ' $t4 .= $uab ;',
            'start_line' => 53,
            'indent' => 1,
            'block_id' => 9
          },
          {
            'token_num' => 8,
            'has_warnings' => 0,
            'end_line' => 55,
            'src' => ' print eval \'$t4 =~ /$ub/\' ? "ok 9\\n" : "not ok 9\\t# $t4\\n" ;',
            'start_line' => 55,
            'indent' => 1,
            'block_id' => 9
          },
          {
            'token_num' => 5,
            'has_warnings' => 1,
            'end_line' => 57,
            'src' => ' my $t5 = $a ;',
            'start_line' => 57,
            'indent' => 1,
            'block_id' => 9
          },
          {
            'token_num' => 6,
            'has_warnings' => 1,
            'end_line' => 57,
            'src' => ' $t5 = $ab . $t5 ;',
            'start_line' => 57,
            'indent' => 1,
            'block_id' => 9
          },
          {
            'token_num' => 11,
            'has_warnings' => 1,
            'end_line' => 59,
            'src' => ' print $t5 =~/$ub/ ? "ok 10\\n" : "not ok 10\\t# $t5\\n" ;',
            'start_line' => 59,
            'indent' => 1,
            'block_id' => 9
          },
          {
            'token_num' => 5,
            'has_warnings' => 1,
            'end_line' => 61,
            'src' => ' my $t6 = $a ;',
            'start_line' => 61,
            'indent' => 1,
            'block_id' => 9
          },
          {
            'token_num' => 6,
            'has_warnings' => 1,
            'end_line' => 61,
            'src' => ' $t6 = $uab . $t6 ;',
            'start_line' => 61,
            'indent' => 1,
            'block_id' => 9
          },
          {
            'token_num' => 8,
            'has_warnings' => 0,
            'end_line' => 63,
            'src' => ' print eval \'$t6 =~ /$ub/\' ? "ok 11\\n" : "not ok 11\\t# $t6\\n" ;',
            'start_line' => 63,
            'indent' => 1,
            'block_id' => 9
          },
          {
            'token_num' => 5,
            'has_warnings' => 1,
            'end_line' => 65,
            'src' => ' my $t7 = $ua ;',
            'start_line' => 65,
            'indent' => 1,
            'block_id' => 9
          },
          {
            'token_num' => 6,
            'has_warnings' => 1,
            'end_line' => 65,
            'src' => ' $t7 = $ab . $t7 ;',
            'start_line' => 65,
            'indent' => 1,
            'block_id' => 9
          },
          {
            'token_num' => 11,
            'has_warnings' => 1,
            'end_line' => 67,
            'src' => ' print $t7 =~/$ub/ ? "ok 12\\n" : "not ok 12\\t# $t7\\n" ;',
            'start_line' => 67,
            'indent' => 1,
            'block_id' => 9
          },
          {
            'token_num' => 5,
            'has_warnings' => 1,
            'end_line' => 69,
            'src' => ' my $t8 = $ua ;',
            'start_line' => 69,
            'indent' => 1,
            'block_id' => 9
          },
          {
            'token_num' => 6,
            'has_warnings' => 1,
            'end_line' => 69,
            'src' => ' $t8 = $uab . $t8 ;',
            'start_line' => 69,
            'indent' => 1,
            'block_id' => 9
          },
          {
            'token_num' => 8,
            'has_warnings' => 0,
            'end_line' => 71,
            'src' => ' print eval \'$t8 =~ /$ub/\' ? "ok 13\\n" : "not ok 13\\t# $t8\\n" ;',
            'start_line' => 71,
            'indent' => 1,
            'block_id' => 9
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
