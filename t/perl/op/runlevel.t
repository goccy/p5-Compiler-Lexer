use strict;
use warnings;
use Test::More;
BEGIN {
    use_ok('Compiler::Lexer');
}
my $script =<<'__SCRIPT__';
#!./perl

##
## Many of these tests are originally from Michael Schroeder
## <Michael.Schroeder@informatik.uni-erlangen.de>
## Adapted and expanded by Gurusamy Sarathy <gsar@activestate.com>
##

chdir 't' if -d 't';
@INC = '../lib';
require './test.pl';

$|=1;

run_multiple_progs('', \*DATA);

done_testing();

__END__
@a = (1, 2, 3);
{
  @a = sort { last ; } @a;
}
EXPECT
Can't "last" outside a loop block at - line 3.
########
package TEST;
 
sub TIESCALAR {
  my $foo;
  return bless \$foo;
}
sub FETCH {
  eval 'die("test")';
  print "still in fetch\n";
  return ">$@<";
}
package main;
 
tie $bar, TEST;
print "- $bar\n";
EXPECT
still in fetch
- >test at (eval 1) line 1.
<
########
package TEST;
 
sub TIESCALAR {
  my $foo;
  eval('die("foo\n")');
  print "after eval\n";
  return bless \$foo;
}
sub FETCH {
  return "ZZZ";
}
 
package main;
 
tie $bar, TEST;
print "- $bar\n";
print "OK\n";
EXPECT
after eval
- ZZZ
OK
########
package TEST;
 
sub TIEHANDLE {
  my $foo;
  return bless \$foo;
}
sub PRINT {
print STDERR "PRINT CALLED\n";
(split(/./, 'x'x10000))[0];
eval('die("test\n")');
}
 
package main;
 
open FH, ">&STDOUT";
tie *FH, TEST;
print FH "OK\n";
print STDERR "DONE\n";
EXPECT
PRINT CALLED
DONE
########
sub warnhook {
  print "WARNHOOK\n";
  eval('die("foooo\n")');
}
$SIG{'__WARN__'} = 'warnhook';
warn("dfsds\n");
print "END\n";
EXPECT
WARNHOOK
END
########
package TEST;
 
use overload
     "\"\""   =>  \&str
;
 
sub str {
  eval('die("test\n")');
  return "STR";
}
 
package main;
 
$bar = bless {}, TEST;
print "$bar\n";
print "OK\n";
EXPECT
STR
OK
########
sub foo {
  $a <=> $b unless eval('$a == 0 ? bless undef : ($a <=> $b)');
}
@a = (3, 2, 0, 1);
@a = sort foo @a;
print join(', ', @a)."\n";
EXPECT
0, 1, 2, 3
########
sub foo {
  goto bar if $a == 0 || $b == 0;
  $a <=> $b;
}
@a = (3, 2, 0, 1);
@a = sort foo @a;
print join(', ', @a)."\n";
exit;
bar:
print "bar reached\n";
EXPECT
Can't "goto" out of a pseudo block at - line 2.
########
%seen = ();
sub sortfn {
  (split(/./, 'x'x10000))[0];
  my (@y) = ( 4, 6, 5);
  @y = sort { $a <=> $b } @y;
  my $t = "sortfn ".join(', ', @y)."\n";
  print $t if ($seen{$t}++ == 0);
  return $_[0] <=> $_[1];
}
@x = ( 3, 2, 1 );
@x = sort { &sortfn($a, $b) } @x;
print "---- ".join(', ', @x)."\n";
EXPECT
sortfn 4, 5, 6
---- 1, 2, 3
########
@a = (3, 2, 1);
@a = sort { eval('die("no way")') ,  $a <=> $b} @a;
print join(", ", @a)."\n";
EXPECT
1, 2, 3
########
@a = (1, 2, 3);
foo:
{
  @a = sort { last foo; } @a;
}
EXPECT
Label not found for "last foo" at - line 4.
########
package TEST;
 
sub TIESCALAR {
  my $foo;
  return bless \$foo;
}
sub FETCH {
  next;
  return "ZZZ";
}
sub STORE {
}
 
package main;
 
tie $bar, TEST;
{
  print "- $bar\n";
}
print "OK\n";
EXPECT
Can't "next" outside a loop block at - line 8.
########
package TEST;
 
sub TIESCALAR {
  my $foo;
  return bless \$foo;
}
sub FETCH {
  goto bbb;
  return "ZZZ";
}
 
package main;
 
tie $bar, TEST;
print "- $bar\n";
exit;
bbb:
print "bbb\n";
EXPECT
Can't find label bbb at - line 8.
########
sub foo {
  $a <=> $b unless eval('$a == 0 ? die("foo\n") : ($a <=> $b)');
}
@a = (3, 2, 0, 1);
@a = sort foo @a;
print join(', ', @a)."\n";
EXPECT
0, 1, 2, 3
########
package TEST;
sub TIESCALAR {
  my $foo;
  return bless \$foo;
}
sub FETCH {
  return "fetch";
}
sub STORE {
(split(/./, 'x'x10000))[0];
}
package main;
tie $bar, TEST;
$bar = "x";
########
package TEST;
sub TIESCALAR {
  my $foo;
  next;
  return bless \$foo;
}
package main;
{
tie $bar, TEST;
}
EXPECT
Can't "next" outside a loop block at - line 4.
########
@a = (1, 2, 3);
foo:
{
  @a = sort { exit(0) } @a;
}
END { print "foobar\n" }
EXPECT
foobar
########
$SIG{__DIE__} = sub {
    print "In DIE\n";
    $i = 0;
    while (($p,$f,$l,$s) = caller(++$i)) {
        print "$p|$f|$l|$s\n";
    }
};
eval { die };
&{sub { eval 'die' }}();
sub foo { eval { die } } foo();
{package rmb; sub{ eval{die} } ->() };	# check __ANON__ knows package	
EXPECT
In DIE
main|-|8|(eval)
In DIE
main|-|9|(eval)
main|-|9|main::__ANON__
In DIE
main|-|10|(eval)
main|-|10|main::foo
In DIE
rmb|-|11|(eval)
rmb|-|11|rmb::__ANON__
########
package TEST;
 
sub TIEARRAY {
  return bless [qw(foo fee fie foe)], $_[0];
}
sub FETCH {
  my ($s,$i) = @_;
  if ($i) {
    goto bbb;
  }
bbb:
  return $s->[$i];
}
 
package main;
tie my @bar, 'TEST';
print join('|', @bar[0..3]), "\n"; 
EXPECT
foo|fee|fie|foe
########
package TH;
sub TIEHASH { bless {}, TH }
sub STORE { eval { print "@_[1,2]\n" }; die "bar\n" }
tie %h, TH;
eval { $h{A} = 1; print "never\n"; };
print $@;
eval { $h{B} = 2; };
print $@;
EXPECT
A 1
bar
B 2
bar
########
sub n { 0 }
sub f { my $x = shift; d(); }
f(n());
f();

sub d {
    my $i = 0; my @a;
    while (do { { package DB; @a = caller($i++) } } ) {
        @a = @DB::args;
        for (@a) { print "$_\n"; $_ = '' }
    }
}
EXPECT
0
########
sub TIEHANDLE { bless {} }
sub PRINT { next }

tie *STDERR, '';
{ map ++$_, 1 }

EXPECT
Can't "next" outside a loop block at - line 2.
########
sub TIEHANDLE { bless {} }
sub PRINT { print "[TIE] $_[1]" }

tie *STDERR, '';
die "DIE\n";

EXPECT
[TIE] DIE
########
sub TIEHANDLE { bless {} }
sub PRINT { 
    (split(/./, 'x'x10000))[0];
    eval('die("test\n")');
    warn "[TIE] $_[1]";
}
open OLDERR, '>&STDERR';
tie *STDERR, '';

use warnings FATAL => qw(uninitialized);
print undef;

EXPECT
[TIE] Use of uninitialized value in print at - line 11.

__SCRIPT__

subtest 'tokenize' => sub {
    my $tokens = Compiler::Lexer->new('')->tokenize($script);
    is_deeply($tokens, [
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'chdir',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 9
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 9,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'data' => 't'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'line' => 9,
                   'data' => 'if',
                   'name' => 'IfStmt'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-d',
                   'name' => 'Handle',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'line' => 9
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 't',
                   'name' => 'RawString',
                   'line' => 9,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 9,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '@INC',
                   'name' => 'LibraryDirectories',
                   'line' => 10,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LibraryDirectories
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'name' => 'Assign',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 10
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '../lib',
                   'name' => 'RawString',
                   'line' => 10,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 10,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 11,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RequireDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'require',
                   'name' => 'RequireDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => './test.pl',
                   'name' => 'RawString',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 11
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 11,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$|',
                   'name' => 'SpecificValue',
                   'line' => 13,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 13,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=',
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '1',
                   'name' => 'Int',
                   'line' => 13,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 13,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 15,
                   'data' => 'run_multiple_progs',
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'line' => 15,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 15,
                   'name' => 'RawString',
                   'data' => ''
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 15,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'data' => ',',
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '\\',
                   'name' => 'Ref',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Ref,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 15
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Glob',
                   'data' => '*DATA',
                   'type' => Compiler::Lexer::TokenType::T_Glob,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 15
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 15
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 15
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'data' => 'done_testing',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 17
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 17,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 17,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'line' => 17,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
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
            'start_line' => 9,
            'indent' => 0,
            'src' => ' chdir \'t\' if -d \'t\' ;',
            'token_num' => 6,
            'block_id' => 0,
            'has_warnings' => 0,
            'end_line' => 9
          },
          {
            'start_line' => 10,
            'indent' => 0,
            'src' => ' @INC = \'../lib\' ;',
            'end_line' => 10,
            'has_warnings' => 0,
            'block_id' => 0,
            'token_num' => 4
          },
          {
            'end_line' => 11,
            'has_warnings' => 0,
            'block_id' => 0,
            'token_num' => 3,
            'indent' => 0,
            'src' => ' require \'./test.pl\' ;',
            'start_line' => 11
          },
          {
            'indent' => 0,
            'src' => ' $| = 1 ;',
            'start_line' => 13,
            'end_line' => 13,
            'has_warnings' => 0,
            'token_num' => 4,
            'block_id' => 0
          },
          {
            'end_line' => 15,
            'has_warnings' => 1,
            'token_num' => 8,
            'block_id' => 0,
            'start_line' => 15,
            'indent' => 0,
            'src' => ' run_multiple_progs ( \'\' , \\ *DATA ) ;'
          },
          {
            'end_line' => 17,
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 4,
            'start_line' => 17,
            'indent' => 0,
            'src' => ' done_testing ( ) ;'
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
