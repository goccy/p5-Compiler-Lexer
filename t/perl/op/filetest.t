use strict;
use warnings;
use Test::More;
BEGIN {
    use_ok('Compiler::Lexer');
}
my $script =<<'__SCRIPT__';
#!./perl

# There are few filetest operators that are portable enough to test.
# See pod/perlport.pod for details.

BEGIN {
    chdir 't' if -d 't';
    require './test.pl';
    set_up_inc(qw '../lib ../cpan/Perl-OSType/lib');
}

plan(tests => 53 + 27*14);

if ($^O =~ /MSWin32|cygwin|msys/ && !is_miniperl) {
  require Win32; # for IsAdminUser()
}

# Tests presume we are in t/op directory and that file 'TEST' is found
# therein.
is(-d 'op', 1, "-d: directory correctly identified");
is(-f 'TEST', 1, "-f: plain file correctly identified");
isnt(-f 'op', 1, "-f: directory is not a plain file");
isnt(-d 'TEST', 1, "-d: plain file is not a directory");
is(-r 'TEST', 1, "-r: file readable by effective uid/gid not found");

# Make a read only file. This happens to be empty, so we also use it later.
my $ro_empty_file = tempfile();

{
    open my $fh, '>', $ro_empty_file or die "open $fh: $!";
    close $fh or die "close $fh: $!";
}

chmod 0555, $ro_empty_file or die "chmod 0555, '$ro_empty_file' failed: $!";

SKIP: {
    my $restore_root;
    skip "Need Win32::IsAdminUser() on $^O", 1
      if $^O =~ /MSWin32|cygwin|msys/ && is_miniperl();
    my $Is_WinAdminUser = ($^O =~ /MSWin32|cygwin|msys/ and Win32::IsAdminUser()) ? 1 : 0;
    # TODO: skip("On an ACL filesystem like $^O we cannot rely on -w via uid/gid");
    # We have no filesystem check for ACL in core
    if ($Is_WinAdminUser) {
        skip("As Windows Administrator we cannot rely on -w via uid/gid");
    }
    elsif ($> == 0) {
	# root can read and write anything, so switch uid (may not be
	# implemented)
	eval '$> = 1';

	skip("Can't drop root privs to test read-only files") if $> == 0;
	note("Dropped root privs to test read-only files. \$> == $>");
	++$restore_root;
    }

    isnt(-w $ro_empty_file, 1, "-w: file writable by effective uid/gid");

    if ($restore_root) {
	# If the previous assignment to $> worked, so should this:
	$> = 0;
	note("Restored root privs after testing read-only files. \$> == $>");
    }
}

# these would fail for the euid 1
# (unless we have unpacked the source code as uid 1...)
is(-r 'op', 1, "-r: directory readable by effective uid/gid");
is(-w 'op', 1, "-w: directory writable by effective uid/gid");
is(-x 'op', 1, "-x: executable by effective uid/gid"); # Hohum.  Are directories -x everywhere?

is( "@{[grep -r, qw(foo io noo op zoo)]}", "io op",
    "-r: found directories readable by effective uid/gid" );

# Test stackability of filetest operators

is(defined( -f -d 'TEST' ), 1, "-f and -d stackable: plain file found");
isnt(-f -d _, 1, "-f and -d stackable: no plain file found");
isnt(defined( -e 'zoo' ), 1, "-e: file does not exist");
isnt(defined( -e -d 'zoo' ), 1, "-e and -d: neither file nor directory exists");
isnt(defined( -f -e 'zoo' ), 1, "-f and -e: not a plain file and does not exist");
is(-f -e 'TEST', 1, "-f and -e: plain file and exists");
is(-e -f 'TEST', 1, "-e and -f: exists and is plain file");
is(defined(-d -e 'TEST'), 1, "-d and -e: file at least exists");
is(defined(-e -d 'TEST'), 1, "-e and -d: file at least exists");
isnt( -f -d 'op', 1, "-f and -d: directory found but is not a plain file");
is(-x -d -x 'op', 1, "-x, -d and -x again: directory exists and is executable");
my ($size) = (stat 'TEST')[7];
cmp_ok($size, '>', 1, 'TEST is longer than 1 byte');
is( (-s -f 'TEST'), $size, "-s returns real size" );
is(-f -s 'TEST', 1, "-f and -s: plain file with non-zero size");

# now with an empty file
is(-f $ro_empty_file, 1, "-f: plain file found");
is(-s $ro_empty_file, 0, "-s: file has 0 bytes");
is(-f -s $ro_empty_file, 0, "-f and -s: plain file with 0 bytes");
is(-s -f $ro_empty_file, 0, "-s and -f: file with 0 bytes is plain file");

# stacked -l
eval { -l -e "TEST" };
like $@, qr/^The stat preceding -l _ wasn't an lstat at /,
  'stacked -l non-lstat error with warnings off';
{
 local $^W = 1;
 eval { -l -e "TEST" };
 like $@, qr/^The stat preceding -l _ wasn't an lstat at /,
  'stacked -l non-lstat error with warnings on';
}
# Make sure -l is using the previous stat buffer, and not using the previ-
# ous op’s return value as a file name.
# t/TEST can be a symlink under -Dmksymlinks, so use our temporary file.
SKIP: {
 use Perl::OSType 'os_type';
 if (os_type ne 'Unix') { skip "Not Unix", 3 }
 if ( $^O =~ /android/ ) {
     # Even the most basic toolbox in android provides ln,
     # but not which.
     $ln = "ln";
 }
 else {
     chomp(my $ln = `which ln`);
     if ( ! -e $ln ) { skip "No ln"   , 3 }
 }
 lstat $ro_empty_file;
 `ln -s $ro_empty_file 1`;
 isnt(-l -e _, 1, 'stacked -l uses previous stat, not previous retval');
 unlink 1;

 # Since we already have our skip block set up, we might as well put this
 # test here, too:
 # -l always treats a non-bareword argument as a file name
 system 'ln', '-s', $ro_empty_file, \*foo;
 local $^W = 1;
 my @warnings;
 local $SIG{__WARN__} = sub { push @warnings, @_ };
 is(-l \*foo, 1, '-l \*foo is a file name');
 ok($warnings[0] =~ /-l on filehandle foo/, 'warning for -l $handle');
 unlink \*foo;
}
# More -l $handle warning tests
{
 local $^W = 1;
 my @warnings;
 local $SIG{__WARN__} = sub { push @warnings, @_ };
 () = -l \*{"\x{3c6}oo"};
 like($warnings[0], qr/-l on filehandle \x{3c6}oo/,
  '-l $handle warning is utf8-clean');
 () = -l *foo;
 like($warnings[1], qr/-l on filehandle foo/,
  '-l $handle warning occurs for globs, not just globrefs');
 tell foo; # vivify the IO slot
 () = -l *foo{IO};
    # (element [3] because tell also warns)
 like($warnings[3], qr/-l on filehandle at/,
  '-l $handle warning occurs for iorefs as well');
} 

# test that _ is a bareword after filetest operators

-f 'TEST';
is(-f _, 1, "_ is bareword after filetest operator");
sub _ { "this is not a file name" }
is(-f _, 1, "_ is bareword after filetest operator");

my $over;
{
    package OverFtest;

    use overload 
	fallback => 1,
        -X => sub { 
            $over = [qq($_[0]), $_[1]];
            "-$_[1]"; 
        };
}
{
    package OverString;

    # No fallback. -X should fall back to string overload even without
    # it.
    use overload q/""/ => sub { $over = 1; "TEST" };
}
{
    package OverBoth;

    use overload
        q/""/   => sub { "TEST" },
        -X      => sub { "-$_[1]" };
}
{
    package OverNeither;

    # Need fallback. Previous versions of perl required 'fallback' to do
    # -X operations on an object with no "" overload.
    use overload 
        '+' => sub { 1 },
        fallback => 1;
}

my $ft = bless [], "OverFtest";
my $ftstr = qq($ft);
my $str = bless [], "OverString";
my $both = bless [], "OverBoth";
my $neither = bless [], "OverNeither";
my $nstr = qq($neither);

open my $gv, "<", "TEST";
bless $gv, "OverString";
open my $io, "<", "TEST";
$io = *{$io}{IO};
bless $io, "OverString";

my $fcntl_not_available;
eval { require Fcntl } or $fcntl_not_available = 1;

for my $op (split //, "rwxoRWXOezsfdlpSbctugkTMBAC") {
    $over = [];
    my $rv = eval "-$op \$ft";
    isnt( $rv, undef,               "overloaded -$op succeeds" )
        or diag( $@ );
    is( $over->[0], $ftstr,         "correct object for overloaded -$op" );
    is( $over->[1], $op,            "correct op for overloaded -$op" );
    is( $rv,        "-$op",         "correct return value for overloaded -$op");

    my ($exp, $is) = (1, "is");
    if (
	(
	  !$fcntl_not_available and
	  (
	    $op eq "u" and not eval { Fcntl::S_ISUID() } or
	    $op eq "g" and not eval { Fcntl::S_ISGID() } or
	    $op eq "k" and not eval { Fcntl::S_ISVTX() }
	  )
	)
	||
	# the Fcntl test is meaningless in miniperl and
	# S_ISVTX isn't available on Win32
	( $^O eq 'MSWin32' && $op eq 'k' && is_miniperl )
    ) {
        ($exp, $is) = (0, "not");
    }

    $over = 0;
    $rv = eval "-$op \$str";
    is($@, "",                      "-$op succeeds with string overloading");
    is( $rv, eval "-$op 'TEST'",    "correct -$op on string overload" );
    is( $over,      $exp,           "string overload $is called for -$op" );

    ($exp, $is) = $op eq "l" ? (1, "is") : (0, "not");

    $over = 0;
    eval "-$op \$gv";
    is( $over,      $exp,   "string overload $is called for -$op on GLOB" );

    # IO refs always get string overload called. This might be a bug.
    $op eq "t" || $op eq "T" || $op eq "B"
        and ($exp, $is) = (1, "is");

    $over = 0;
    eval "-$op \$io";
    is( $over,      $exp,   "string overload $is called for -$op on IO");

    $rv = eval "-$op \$both";
    is( $rv,        "-$op",         "correct -$op on string/-X overload" );

    $rv = eval "-$op \$neither";
    is($@, "",                      "-$op succeeds with random overloading");
    is( $rv, eval "-$op \$nstr",    "correct -$op with random overloading" );

    is( eval "-r -$op \$ft", "-r",      "stacked overloaded -$op" );
    is( eval "-$op -r \$ft", "-$op",    "overloaded stacked -$op" );
}

# -l stack corruption: this bug occurred from 5.8 to 5.14
{
 push my @foo, "bar", -l baz;
 is $foo[0], "bar", '-l bareword does not corrupt the stack';
}

# -l and fatal warnings
stat "test.pl";
eval { use warnings FATAL => io; -l cradd };
isnt(stat _, 1,
     'fatal warnings do not prevent -l HANDLE from setting stat status');

# File test ops should not call get-magic on the topmost SV on the stack if
# it belongs to another op.
{
  my $w;
  sub oon::TIESCALAR{bless[],'oon'}
  sub oon::FETCH{$w++}
  tie my $t, 'oon';
  push my @a, $t, -t;
  is $w, 1, 'file test does not call FETCH on stack item not its own';
}

# -T and -B

my $Perl = which_perl();

SKIP: {
    skip "no -T on filehandles", 8 unless eval { -T STDERR; 1 };

    # Test that -T HANDLE sets the last stat type
    -l "perl.c";   # last stat type is now lstat
    -T STDERR;     # should set it to stat, since -T does a stat
    eval { -l _ }; # should die, because the last stat type is not lstat
    like $@, qr/^The stat preceding -l _ wasn't an lstat at /,
	'-T HANDLE sets the stat type';

    # statgv should be cleared when freed
    fresh_perl_is
	'open my $fh, "test.pl"; -r $fh; undef $fh; open my $fh2, '
	. "q\0$Perl\0; print -B _",
	'',
	{ switches => ['-l'] },
	'PL_statgv should not point to freed-and-reused SV';

    # or coerced into a non-glob
    fresh_perl_is
	'open Fh, "test.pl"; -r($h{i} = *Fh); $h{i} = 3; undef %h;'
	. 'open my $fh2, ' . "q\0" . which_perl() . "\0; print -B _",
	'',
	{ switches => ['-l'] },
	'PL_statgv should not point to coerced-freed-and-reused GV';

    # -T _ should work after stat $ioref
    open my $fh, 'test.pl';
    stat $Perl; # a binary file
    stat *$fh{IO};
    is(-T _, 1, '-T _ works after stat $ioref');

    # and after -r $ioref
    -r *$fh{IO};
    is(-T _, 1, '-T _ works after -r $ioref');

    # -T _ on closed filehandle should still reset stat info
    stat $fh;
    close $fh;
    -T _;
    isnt(stat _, 1, '-T _ on closed filehandle resets stat info');

    lstat "test.pl";
    -T $fh; # closed
    eval { lstat _ };
    like $@, qr/^The stat preceding lstat\(\) wasn't an lstat at /,
	'-T on closed handle resets last stat type';

    # Fatal warnings should not affect the setting of errno.
    $! = 7;
    -T cradd;
    my $errno = $!;
    $! = 7;
    eval { use warnings FATAL => unopened; -T cradd };
    my $errno2 = $!;
    is $errno2, $errno,
	'fatal warnings do not affect errno after -T BADHADNLE';
}

is runperl(prog => '-T _', switches => ['-w'], stderr => 1), "",
  'no uninit warnings from -T with no preceding stat';

SKIP: {
    my $rand_file_name = 'filetest-' . rand =~ y/.//dr;
    if (-e $rand_file_name) { skip "File $rand_file_name exists", 1 }
    stat 'test.pl';
    -T $rand_file_name;
    isnt(stat _, 1, '-T "nonexistent" resets stat success status');
}

# Unsuccessful filetests on filehandles should leave stat buffers in the
# same state whether fatal warnings are on or off.
{
    stat "test.pl";
    # This GV has no IO
    -r *phlon;
    my $failed_stat1 = stat _;

    stat "test.pl";
    eval { use warnings FATAL => unopened; -r *phlon };
    my $failed_stat2 = stat _;

    is $failed_stat2, $failed_stat1,
	'failed -r($gv_without_io) with and w/out fatal warnings';

    stat "test.pl";
    -r cength;  # at compile time autovivifies IO, but with no fp
    $failed_stat1 = stat _;

    stat "test.pl";
    eval { use warnings FATAL => unopened; -r cength };
    $failed_stat2 = stat _;
    
    is $failed_stat2, $failed_stat1,
	'failed -r($gv_with_io_but_no_fp) with and w/out fatal warnings';
} 

__SCRIPT__

subtest 'tokenize' => sub {
    my $tokens = Compiler::Lexer->new('')->tokenize($script);
    is_deeply($tokens, [
          bless( {
                   'name' => 'ModWord',
                   'kind' => Compiler::Lexer::Kind::T_ModWord,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_ModWord,
                   'data' => 'BEGIN',
                   'has_warnings' => 0,
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'has_warnings' => 0,
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'chdir',
                   'has_warnings' => 0,
                   'line' => 7
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 't',
                   'has_warnings' => 0,
                   'line' => 7,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'if',
                   'has_warnings' => 0,
                   'line' => 7,
                   'name' => 'IfStmt',
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '-d',
                   'has_warnings' => 0,
                   'line' => 7
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 't',
                   'has_warnings' => 0,
                   'line' => 7,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 7,
                   'data' => ';',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RequireDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'RequireDecl',
                   'line' => 8,
                   'has_warnings' => 0,
                   'data' => 'require'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 8,
                   'data' => './test.pl',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 8
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 9,
                   'has_warnings' => 1,
                   'data' => 'set_up_inc',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'has_warnings' => 0,
                   'line' => 9,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 9,
                   'has_warnings' => 0,
                   'data' => 'qw',
                   'type' => Compiler::Lexer::TokenType::T_RegList,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'name' => 'RegList'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '../lib ../cpan/Perl-OSType/lib',
                   'has_warnings' => 0,
                   'line' => 9,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 9,
                   'data' => ')',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 9,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 10,
                   'data' => '}',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 12,
                   'has_warnings' => 1,
                   'data' => 'plan',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 12,
                   'data' => '(',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 12,
                   'data' => 'tests',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 12,
                   'data' => '=>',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Arrow',
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '53',
                   'has_warnings' => 0,
                   'line' => 12,
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'Add',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Add,
                   'has_warnings' => 0,
                   'data' => '+',
                   'line' => 12
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '27',
                   'line' => 12
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 12,
                   'data' => '*',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Mul,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Mul',
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 12,
                   'data' => '14',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 12,
                   'data' => ')',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 12,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'name' => 'IfStmt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'has_warnings' => 0,
                   'data' => 'if',
                   'line' => 14
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 14,
                   'data' => '(',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'SpecificValue',
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '$^O',
                   'line' => 14
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegOK,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegOK',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 14,
                   'data' => '=~',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegDelim',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '/',
                   'has_warnings' => 0,
                   'line' => 14
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegExp',
                   'line' => 14,
                   'has_warnings' => 0,
                   'data' => 'MSWin32|cygwin|msys'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegDelim',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'has_warnings' => 0,
                   'data' => '/',
                   'line' => 14
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'And',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_And,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '&&',
                   'has_warnings' => 0,
                   'line' => 14
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '!',
                   'line' => 14,
                   'kind' => Compiler::Lexer::Kind::T_SingleTerm,
                   'name' => 'Not',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Not
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'is_miniperl',
                   'has_warnings' => 1,
                   'line' => 14
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 14,
                   'data' => ')',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 14,
                   'data' => '{',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'RequireDecl',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RequireDecl,
                   'has_warnings' => 0,
                   'data' => 'require',
                   'line' => 15
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'Win32',
                   'has_warnings' => 0,
                   'line' => 15,
                   'name' => 'RequiredName',
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RequiredName
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 15,
                   'has_warnings' => 0,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 16,
                   'data' => '}',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'is',
                   'has_warnings' => 1,
                   'line' => 20
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 20,
                   'data' => '(',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 20,
                   'data' => '-d',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 20,
                   'data' => 'op',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 20,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '1',
                   'has_warnings' => 0,
                   'line' => 20
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 20,
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 20,
                   'data' => '-d: directory correctly identified',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 20
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 20
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'is',
                   'has_warnings' => 1,
                   'line' => 21,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 21,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 21,
                   'has_warnings' => 0,
                   'data' => '-f',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'line' => 21,
                   'has_warnings' => 0,
                   'data' => 'TEST'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 21,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '1',
                   'line' => 21,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 21,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-f: plain file correctly identified',
                   'line' => 21,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 21,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 21
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'isnt',
                   'has_warnings' => 1,
                   'line' => 22,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'has_warnings' => 0,
                   'line' => 22,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-f',
                   'line' => 22,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle',
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 22,
                   'data' => 'op',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 22,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'data' => '1',
                   'has_warnings' => 0,
                   'line' => 22
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 22,
                   'data' => ',',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '-f: directory is not a plain file',
                   'has_warnings' => 0,
                   'line' => 22
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 22,
                   'has_warnings' => 0,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 22,
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 23,
                   'data' => 'isnt',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 23,
                   'data' => '(',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle',
                   'line' => 23,
                   'has_warnings' => 0,
                   'data' => '-d'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => 'TEST',
                   'has_warnings' => 0,
                   'line' => 23
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 23,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int',
                   'line' => 23,
                   'has_warnings' => 0,
                   'data' => '1'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 23,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => '-d: plain file is not a directory',
                   'has_warnings' => 0,
                   'line' => 23
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 23,
                   'data' => ')',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 23,
                   'has_warnings' => 0,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'is',
                   'line' => 24,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 24,
                   'data' => '(',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-r',
                   'line' => 24,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'line' => 24,
                   'has_warnings' => 0,
                   'data' => 'TEST'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 24,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '1',
                   'line' => 24,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 24
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => '-r: file readable by effective uid/gid not found',
                   'has_warnings' => 0,
                   'line' => 24
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 24
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 24,
                   'has_warnings' => 0,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'my',
                   'line' => 27,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 27,
                   'data' => '$ro_empty_file',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LocalVar',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'name' => 'Assign',
                   'line' => 27,
                   'has_warnings' => 0,
                   'data' => '='
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 27,
                   'has_warnings' => 1,
                   'data' => 'tempfile',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'line' => 27,
                   'has_warnings' => 0,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 27,
                   'data' => ')',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 29,
                   'data' => '{',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'open',
                   'line' => 30,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'VarDecl',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'has_warnings' => 0,
                   'line' => 30
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 30,
                   'data' => '$fh',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 30
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '>',
                   'has_warnings' => 0,
                   'line' => 30
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 30,
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'line' => 30,
                   'has_warnings' => 0,
                   'data' => '$ro_empty_file'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 30,
                   'has_warnings' => 0,
                   'data' => 'or',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'AlphabetOr'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'data' => 'die',
                   'line' => 30
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'open $fh: $!',
                   'line' => 30,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'line' => 30,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'close',
                   'line' => 31,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'line' => 31,
                   'has_warnings' => 0,
                   'data' => '$fh'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 31,
                   'data' => 'or',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'name' => 'AlphabetOr',
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'die',
                   'has_warnings' => 0,
                   'line' => 31,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 31,
                   'data' => 'close $fh: $!',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 32,
                   'has_warnings' => 0,
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'data' => 'chmod',
                   'has_warnings' => 0,
                   'line' => 34
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '0555',
                   'line' => 34
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'line' => 34,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 34,
                   'data' => '$ro_empty_file',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'or',
                   'line' => 34,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'AlphabetOr',
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 34,
                   'data' => 'die',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'line' => 34,
                   'has_warnings' => 0,
                   'data' => 'chmod 0555, \'$ro_empty_file\' failed: $!'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 34,
                   'has_warnings' => 0,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'SKIP',
                   'has_warnings' => 1,
                   'line' => 36
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Colon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Colon',
                   'kind' => Compiler::Lexer::Kind::T_Colon,
                   'line' => 36,
                   'data' => ':',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'has_warnings' => 0,
                   'line' => 36,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'VarDecl',
                   'line' => 37,
                   'has_warnings' => 0,
                   'data' => 'my'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'LocalVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '$restore_root',
                   'line' => 37
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'line' => 37,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 38,
                   'has_warnings' => 1,
                   'data' => 'skip',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'Need Win32::IsAdminUser() on $^O',
                   'line' => 38
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 38
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 38,
                   'data' => '1',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 39,
                   'data' => 'if',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'IfStmt',
                   'kind' => Compiler::Lexer::Kind::T_Stmt
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SpecificValue',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 39,
                   'data' => '$^O',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 39,
                   'data' => '=~',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegOK,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegOK',
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '/',
                   'has_warnings' => 0,
                   'line' => 39,
                   'name' => 'RegDelim',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegExp',
                   'line' => 39,
                   'has_warnings' => 0,
                   'data' => 'MSWin32|cygwin|msys'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '/',
                   'line' => 39
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 39,
                   'has_warnings' => 0,
                   'data' => '&&',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_And,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'And'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 39,
                   'data' => 'is_miniperl',
                   'has_warnings' => 1,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 39,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 39
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 39
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'my',
                   'has_warnings' => 0,
                   'line' => 40,
                   'name' => 'VarDecl',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LocalVar',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'data' => '$Is_WinAdminUser',
                   'has_warnings' => 0,
                   'line' => 40
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 40,
                   'data' => '=',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Assign',
                   'kind' => Compiler::Lexer::Kind::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'line' => 40,
                   'has_warnings' => 0,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 40,
                   'has_warnings' => 0,
                   'data' => '$^O',
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'SpecificValue'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '=~',
                   'line' => 40,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'RegOK',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegOK
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegDelim',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'has_warnings' => 0,
                   'data' => '/',
                   'line' => 40
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 40,
                   'data' => 'MSWin32|cygwin|msys',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'name' => 'RegExp',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 40,
                   'data' => '/',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'AlphabetAnd',
                   'type' => Compiler::Lexer::TokenType::T_AlphabetAnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'and',
                   'line' => 40
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'Win32',
                   'line' => 40,
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'name' => 'Namespace',
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'NamespaceResolver',
                   'type' => Compiler::Lexer::TokenType::T_NamespaceResolver,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '::',
                   'line' => 40
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'name' => 'Namespace',
                   'line' => 40,
                   'has_warnings' => 0,
                   'data' => 'IsAdminUser'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'has_warnings' => 0,
                   'line' => 40
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'line' => 40,
                   'has_warnings' => 0,
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 40,
                   'has_warnings' => 0,
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_ThreeTermOperator,
                   'name' => 'ThreeTermOperator',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 40,
                   'data' => '?',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int',
                   'line' => 40,
                   'has_warnings' => 0,
                   'data' => '1'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ':',
                   'line' => 40,
                   'kind' => Compiler::Lexer::Kind::T_Colon,
                   'name' => 'Colon',
                   'type' => Compiler::Lexer::TokenType::T_Colon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'data' => '0',
                   'has_warnings' => 0,
                   'line' => 40
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'line' => 40,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'if',
                   'has_warnings' => 0,
                   'line' => 43,
                   'name' => 'IfStmt',
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 43,
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 43,
                   'data' => '$Is_WinAdminUser',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 43,
                   'data' => ')',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 43,
                   'data' => '{',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'data' => 'skip',
                   'line' => 44
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'line' => 44,
                   'has_warnings' => 0,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'As Windows Administrator we cannot rely on -w via uid/gid',
                   'line' => 44
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 44
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 44,
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '}',
                   'line' => 45,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_ElsifStmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'name' => 'ElsifStmt',
                   'line' => 46,
                   'has_warnings' => 0,
                   'data' => 'elsif'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 46,
                   'data' => '(',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'name' => 'SpecificValue',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 46,
                   'data' => '$>',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '==',
                   'line' => 46,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'EqualEqual',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_EqualEqual
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int',
                   'line' => 46,
                   'has_warnings' => 0,
                   'data' => '0'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 46,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 46,
                   'data' => '{',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'eval',
                   'has_warnings' => 0,
                   'line' => 49,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 49,
                   'data' => '$> = 1',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 49,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'skip',
                   'line' => 51,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 51,
                   'has_warnings' => 0,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 51,
                   'has_warnings' => 0,
                   'data' => 'Can\'t drop root privs to test read-only files',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 51
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'name' => 'IfStmt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'has_warnings' => 0,
                   'data' => 'if',
                   'line' => 51
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'SpecificValue',
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '$>',
                   'line' => 51
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'EqualEqual',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_EqualEqual,
                   'data' => '==',
                   'has_warnings' => 0,
                   'line' => 51
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'data' => '0',
                   'has_warnings' => 0,
                   'line' => 51
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'line' => 51,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 52,
                   'data' => 'note',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 52,
                   'has_warnings' => 0,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 52,
                   'data' => 'Dropped root privs to test read-only files. \\$> == $>',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 52,
                   'has_warnings' => 0,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 52,
                   'has_warnings' => 0,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 53,
                   'data' => '++',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Inc,
                   'name' => 'Inc',
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$restore_root',
                   'has_warnings' => 0,
                   'line' => 53,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 53
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 54,
                   'data' => '}',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 56,
                   'data' => 'isnt',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'has_warnings' => 0,
                   'line' => 56,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'line' => 56,
                   'data' => '-w',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$ro_empty_file',
                   'has_warnings' => 0,
                   'line' => 56,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 56,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '1',
                   'line' => 56,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 56
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 56,
                   'data' => '-w: file writable by effective uid/gid',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 56
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'line' => 56,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'name' => 'IfStmt',
                   'line' => 58,
                   'has_warnings' => 0,
                   'data' => 'if'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 58,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 58,
                   'data' => '$restore_root',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 58
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 58,
                   'data' => '{',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 60,
                   'data' => '$>',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SpecificValue',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 60,
                   'data' => '=',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'kind' => Compiler::Lexer::Kind::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'data' => '0',
                   'has_warnings' => 0,
                   'line' => 60
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 60,
                   'has_warnings' => 0,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'note',
                   'has_warnings' => 1,
                   'line' => 61,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 61
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'Restored root privs after testing read-only files. \\$> == $>',
                   'line' => 61,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 61,
                   'data' => ')',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 61,
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 62,
                   'has_warnings' => 0,
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 63,
                   'data' => '}',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'is',
                   'has_warnings' => 1,
                   'line' => 67,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 67,
                   'has_warnings' => 0,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-r',
                   'line' => 67,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => 'op',
                   'has_warnings' => 0,
                   'line' => 67
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 67,
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 67,
                   'data' => '1',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 67,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-r: directory readable by effective uid/gid',
                   'line' => 67,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 67,
                   'data' => ')',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 67,
                   'has_warnings' => 0,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 68,
                   'data' => 'is',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 68
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'data' => '-w',
                   'has_warnings' => 0,
                   'line' => 68
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 68,
                   'data' => 'op',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 68,
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 68,
                   'has_warnings' => 0,
                   'data' => '1',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 68,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-w: directory writable by effective uid/gid',
                   'has_warnings' => 0,
                   'line' => 68,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 68,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 68
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'is',
                   'has_warnings' => 1,
                   'line' => 69,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 69,
                   'has_warnings' => 0,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 69,
                   'data' => '-x',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'op',
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'line' => 69,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int',
                   'line' => 69,
                   'has_warnings' => 0,
                   'data' => '1'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 69,
                   'data' => '-x: executable by effective uid/gid',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 69,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'is',
                   'has_warnings' => 1,
                   'line' => 71,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'has_warnings' => 0,
                   'line' => 71
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '@{[grep -r, qw(foo io noo op zoo)]}',
                   'line' => 71,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 71
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'data' => 'io op',
                   'line' => 71
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 71,
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '-r: found directories readable by effective uid/gid',
                   'line' => 72
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'line' => 72,
                   'has_warnings' => 0,
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 72,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'is',
                   'line' => 76,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 76,
                   'has_warnings' => 0,
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'defined',
                   'line' => 76,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle',
                   'line' => 76,
                   'has_warnings' => 0,
                   'data' => '-f'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 76,
                   'data' => '-d',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 76,
                   'data' => 'TEST',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'line' => 76,
                   'has_warnings' => 0,
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 76,
                   'has_warnings' => 0,
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '1',
                   'has_warnings' => 0,
                   'line' => 76,
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-f and -d stackable: plain file found',
                   'has_warnings' => 0,
                   'line' => 76,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 76,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'data' => 'isnt',
                   'line' => 77
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 77,
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 77,
                   'data' => '-f',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-d',
                   'line' => 77,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle',
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => '_',
                   'line' => 77,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 77,
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int',
                   'line' => 77,
                   'has_warnings' => 0,
                   'data' => '1'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 77,
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-f and -d stackable: no plain file found',
                   'line' => 77,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'line' => 77,
                   'has_warnings' => 0,
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 77,
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'isnt',
                   'has_warnings' => 1,
                   'line' => 78
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 78
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'data' => 'defined',
                   'line' => 78
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 78
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle',
                   'line' => 78,
                   'has_warnings' => 0,
                   'data' => '-e'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'line' => 78,
                   'has_warnings' => 0,
                   'data' => 'zoo'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 78,
                   'data' => ')',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 78,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 78,
                   'data' => '1',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 78,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-e: file does not exist',
                   'line' => 78,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 78,
                   'data' => ')',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 78,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'isnt',
                   'line' => 79,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'has_warnings' => 0,
                   'line' => 79,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'line' => 79,
                   'has_warnings' => 0,
                   'data' => 'defined'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'line' => 79,
                   'has_warnings' => 0,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle',
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '-e',
                   'line' => 79
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle',
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '-d',
                   'line' => 79
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => 'zoo',
                   'has_warnings' => 0,
                   'line' => 79
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 79,
                   'data' => ')',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 79,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 79,
                   'data' => '1',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 79,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'line' => 79,
                   'has_warnings' => 0,
                   'data' => '-e and -d: neither file nor directory exists'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 79,
                   'data' => ')',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 79,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'isnt',
                   'has_warnings' => 1,
                   'line' => 80,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'line' => 80,
                   'has_warnings' => 0,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'line' => 80,
                   'has_warnings' => 0,
                   'data' => 'defined'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 80,
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '-f',
                   'has_warnings' => 0,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle',
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '-e',
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'zoo',
                   'has_warnings' => 0,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 80,
                   'has_warnings' => 0,
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 80,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 80,
                   'data' => '1',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 80,
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 80,
                   'data' => '-f and -e: not a plain file and does not exist',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 80,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 80,
                   'data' => ';',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'is',
                   'has_warnings' => 1,
                   'line' => 81
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'has_warnings' => 0,
                   'line' => 81
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 81,
                   'has_warnings' => 0,
                   'data' => '-f',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 81,
                   'data' => '-e',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'TEST',
                   'line' => 81,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 81,
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '1',
                   'line' => 81,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 81,
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-f and -e: plain file and exists',
                   'line' => 81,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 81,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 81
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 82,
                   'data' => 'is',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 82,
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'line' => 82,
                   'data' => '-e',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-f',
                   'has_warnings' => 0,
                   'line' => 82,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 82,
                   'has_warnings' => 0,
                   'data' => 'TEST',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 82
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 82,
                   'has_warnings' => 0,
                   'data' => '1',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'line' => 82,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-e and -f: exists and is plain file',
                   'line' => 82,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 82,
                   'data' => ')',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 82,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 83,
                   'data' => 'is',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'line' => 83,
                   'has_warnings' => 0,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 83,
                   'data' => 'defined',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 83,
                   'has_warnings' => 0,
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'has_warnings' => 0,
                   'data' => '-d',
                   'line' => 83
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-e',
                   'has_warnings' => 0,
                   'line' => 83,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 83,
                   'data' => 'TEST',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 83,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'line' => 83,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'data' => '1',
                   'has_warnings' => 0,
                   'line' => 83
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 83,
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-d and -e: file at least exists',
                   'line' => 83,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 83,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 83,
                   'has_warnings' => 0,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'is',
                   'has_warnings' => 1,
                   'line' => 84,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'line' => 84,
                   'has_warnings' => 0,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'defined',
                   'line' => 84
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 84,
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-e',
                   'has_warnings' => 0,
                   'line' => 84,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'line' => 84,
                   'data' => '-d',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => 'TEST',
                   'has_warnings' => 0,
                   'line' => 84
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 84,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 84,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int',
                   'line' => 84,
                   'has_warnings' => 0,
                   'data' => '1'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 84
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => '-e and -d: file at least exists',
                   'has_warnings' => 0,
                   'line' => 84
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'line' => 84,
                   'has_warnings' => 0,
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 84
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'line' => 85,
                   'has_warnings' => 1,
                   'data' => 'isnt'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 85,
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-f',
                   'has_warnings' => 0,
                   'line' => 85,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-d',
                   'has_warnings' => 0,
                   'line' => 85,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'op',
                   'line' => 85,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 85,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 85,
                   'data' => '1',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 85,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 85,
                   'has_warnings' => 0,
                   'data' => '-f and -d: directory found but is not a plain file',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 85
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 85,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'is',
                   'has_warnings' => 1,
                   'line' => 86,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'has_warnings' => 0,
                   'line' => 86
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-x',
                   'line' => 86,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle',
                   'line' => 86,
                   'has_warnings' => 0,
                   'data' => '-d'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 86,
                   'data' => '-x',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 86,
                   'data' => 'op',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'line' => 86,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 86,
                   'data' => '1',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 86,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 86,
                   'has_warnings' => 0,
                   'data' => '-x, -d and -x again: directory exists and is executable',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 86,
                   'has_warnings' => 0,
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 86,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'my',
                   'line' => 87,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'VarDecl',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 87,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 87,
                   'has_warnings' => 0,
                   'data' => '$size',
                   'type' => Compiler::Lexer::TokenType::T_GlobalVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'GlobalVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 87
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'data' => '=',
                   'has_warnings' => 0,
                   'line' => 87
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 87,
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 87,
                   'data' => 'stat',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'TEST',
                   'line' => 87,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 87,
                   'data' => ')',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 87,
                   'has_warnings' => 0,
                   'data' => '[',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBracket'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '7',
                   'line' => 87
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBracket',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'data' => ']',
                   'has_warnings' => 0,
                   'line' => 87
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 87,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 88,
                   'has_warnings' => 1,
                   'data' => 'cmp_ok',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 88,
                   'data' => '(',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$size',
                   'has_warnings' => 0,
                   'line' => 88
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 88
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'data' => '>',
                   'line' => 88
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 88,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '1',
                   'has_warnings' => 0,
                   'line' => 88,
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 88,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 88,
                   'data' => 'TEST is longer than 1 byte',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 88
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 88
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 89,
                   'data' => 'is',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 89
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 89
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-s',
                   'has_warnings' => 0,
                   'line' => 89,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 89,
                   'has_warnings' => 0,
                   'data' => '-f',
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'TEST',
                   'has_warnings' => 0,
                   'line' => 89
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 89,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 89,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$size',
                   'line' => 89,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 89
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => '-s returns real size',
                   'has_warnings' => 0,
                   'line' => 89
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 89,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 89
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 90,
                   'data' => 'is',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 90,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 90,
                   'data' => '-f',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle',
                   'line' => 90,
                   'has_warnings' => 0,
                   'data' => '-s'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'TEST',
                   'line' => 90,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 90,
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '1',
                   'has_warnings' => 0,
                   'line' => 90
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 90
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-f and -s: plain file with non-zero size',
                   'has_warnings' => 0,
                   'line' => 90,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 90,
                   'data' => ')',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 90
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 93,
                   'data' => 'is',
                   'has_warnings' => 1,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 93,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '-f',
                   'has_warnings' => 0,
                   'line' => 93
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 93,
                   'data' => '$ro_empty_file',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 93,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 93,
                   'has_warnings' => 0,
                   'data' => '1',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 93,
                   'data' => ',',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 93,
                   'data' => '-f: plain file found',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 93
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 93,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'is',
                   'line' => 94,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 94,
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle',
                   'line' => 94,
                   'has_warnings' => 0,
                   'data' => '-s'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$ro_empty_file',
                   'has_warnings' => 0,
                   'line' => 94,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 94
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 94,
                   'has_warnings' => 0,
                   'data' => '0',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 94
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 94,
                   'data' => '-s: file has 0 bytes',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 94,
                   'has_warnings' => 0,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 94,
                   'data' => ';',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'is',
                   'has_warnings' => 1,
                   'line' => 95,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'has_warnings' => 0,
                   'line' => 95,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'line' => 95,
                   'data' => '-f',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'line' => 95,
                   'data' => '-s',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$ro_empty_file',
                   'line' => 95,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 95,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 95,
                   'data' => '0',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 95
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 95,
                   'has_warnings' => 0,
                   'data' => '-f and -s: plain file with 0 bytes',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 95
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 95,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'is',
                   'line' => 96,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 96,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle',
                   'line' => 96,
                   'has_warnings' => 0,
                   'data' => '-s'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'line' => 96,
                   'data' => '-f',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 96,
                   'data' => '$ro_empty_file',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 96,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int',
                   'line' => 96,
                   'has_warnings' => 0,
                   'data' => '0'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 96
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-s and -f: file with 0 bytes is plain file',
                   'has_warnings' => 0,
                   'line' => 96,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 96,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 96,
                   'data' => ';',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'data' => 'eval',
                   'has_warnings' => 0,
                   'line' => 99
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 99,
                   'data' => '{',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 99,
                   'has_warnings' => 0,
                   'data' => '-l',
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 99,
                   'has_warnings' => 0,
                   'data' => '-e',
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'TEST',
                   'has_warnings' => 0,
                   'line' => 99
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 99,
                   'data' => '}',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 99
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 100,
                   'has_warnings' => 1,
                   'data' => 'like',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 100,
                   'data' => '$@',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'name' => 'SpecificValue',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 100,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegDecl',
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'line' => 100,
                   'data' => 'qr',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 100,
                   'data' => '/',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegDelim',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '^The stat preceding -l _ wasn\'t an lstat at ',
                   'line' => 100,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegExp',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegExp
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '/',
                   'line' => 100,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 100
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 101,
                   'data' => 'stacked -l non-lstat error with warnings off',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 101
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 102,
                   'data' => '{',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'local',
                   'has_warnings' => 0,
                   'line' => 103,
                   'name' => 'LocalDecl',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_LocalDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 103,
                   'data' => '$^W',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SpecificValue',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 103,
                   'data' => '=',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Assign',
                   'kind' => Compiler::Lexer::Kind::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '1',
                   'line' => 103,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 103,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 104,
                   'data' => 'eval',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'has_warnings' => 0,
                   'line' => 104,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'has_warnings' => 0,
                   'data' => '-l',
                   'line' => 104
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-e',
                   'line' => 104,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'TEST',
                   'has_warnings' => 0,
                   'line' => 104
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 104,
                   'has_warnings' => 0,
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 104,
                   'data' => ';',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 105,
                   'data' => 'like',
                   'has_warnings' => 1,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SpecificValue',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'data' => '$@',
                   'has_warnings' => 0,
                   'line' => 105
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'line' => 105,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'qr',
                   'has_warnings' => 0,
                   'line' => 105,
                   'name' => 'RegDecl',
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'type' => Compiler::Lexer::TokenType::T_RegDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 105,
                   'has_warnings' => 0,
                   'data' => '/',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegDelim'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'name' => 'RegExp',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 105,
                   'data' => '^The stat preceding -l _ wasn\'t an lstat at ',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '/',
                   'line' => 105,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegDelim',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 105,
                   'has_warnings' => 0,
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => 'stacked -l non-lstat error with warnings on',
                   'has_warnings' => 0,
                   'line' => 106
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 106
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}',
                   'has_warnings' => 0,
                   'line' => 107
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 111,
                   'has_warnings' => 1,
                   'data' => 'SKIP',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 111,
                   'data' => ':',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Colon,
                   'name' => 'Colon',
                   'kind' => Compiler::Lexer::Kind::T_Colon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'has_warnings' => 0,
                   'line' => 111
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 112,
                   'has_warnings' => 0,
                   'data' => 'use',
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'UseDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'Perl',
                   'has_warnings' => 0,
                   'line' => 112,
                   'name' => 'Namespace',
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Namespace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'NamespaceResolver',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_NamespaceResolver,
                   'has_warnings' => 0,
                   'data' => '::',
                   'line' => 112
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'OSType',
                   'has_warnings' => 0,
                   'line' => 112,
                   'name' => 'Namespace',
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Namespace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'os_type',
                   'has_warnings' => 0,
                   'line' => 112,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'line' => 112,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 113,
                   'has_warnings' => 0,
                   'data' => 'if',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'name' => 'IfStmt'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'has_warnings' => 0,
                   'line' => 113
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'os_type',
                   'line' => 113,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 113,
                   'has_warnings' => 0,
                   'data' => 'ne',
                   'type' => Compiler::Lexer::TokenType::T_StringNotEqual,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'StringNotEqual'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 113,
                   'data' => 'Unix',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 113,
                   'data' => ')',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'has_warnings' => 0,
                   'line' => 113
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 113,
                   'has_warnings' => 1,
                   'data' => 'skip',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'Not Unix',
                   'line' => 113,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 113,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int',
                   'line' => 113,
                   'has_warnings' => 0,
                   'data' => '3'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '}',
                   'line' => 113,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'name' => 'IfStmt',
                   'line' => 114,
                   'has_warnings' => 0,
                   'data' => 'if'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 114,
                   'data' => '(',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SpecificValue',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'data' => '$^O',
                   'has_warnings' => 0,
                   'line' => 114
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegOK,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'RegOK',
                   'line' => 114,
                   'has_warnings' => 0,
                   'data' => '=~'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegDelim',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 114,
                   'data' => '/',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegExp',
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'android',
                   'line' => 114
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegDelim',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 114,
                   'data' => '/',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 114,
                   'data' => ')',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '{',
                   'line' => 114,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_GlobalVar,
                   'name' => 'GlobalVar',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 117,
                   'data' => '$ln',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'name' => 'Assign',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0,
                   'data' => '=',
                   'line' => 117
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 117,
                   'has_warnings' => 0,
                   'data' => 'ln',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'line' => 117,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 118,
                   'data' => '}',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_ElseStmt,
                   'name' => 'ElseStmt',
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'line' => 119,
                   'data' => 'else',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 119,
                   'data' => '{',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'chomp',
                   'line' => 120,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'has_warnings' => 0,
                   'line' => 120
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'VarDecl',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'has_warnings' => 0,
                   'line' => 120
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LocalVar',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$ln',
                   'has_warnings' => 0,
                   'line' => 120
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=',
                   'has_warnings' => 0,
                   'line' => 120
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'ExecString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_ExecString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'which ln',
                   'has_warnings' => 0,
                   'line' => 120
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 120
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 120,
                   'has_warnings' => 0,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'name' => 'IfStmt',
                   'line' => 121,
                   'has_warnings' => 0,
                   'data' => 'if'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'has_warnings' => 0,
                   'line' => 121
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Not,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_SingleTerm,
                   'name' => 'Not',
                   'line' => 121,
                   'has_warnings' => 0,
                   'data' => '!'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 121,
                   'data' => '-e',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$ln',
                   'has_warnings' => 0,
                   'line' => 121,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'line' => 121,
                   'has_warnings' => 0,
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBrace',
                   'line' => 121,
                   'has_warnings' => 0,
                   'data' => '{'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'data' => 'skip',
                   'line' => 121
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 121,
                   'data' => 'No ln',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 121
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '3',
                   'has_warnings' => 0,
                   'line' => 121
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace',
                   'line' => 121,
                   'has_warnings' => 0,
                   'data' => '}'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace',
                   'line' => 122,
                   'has_warnings' => 0,
                   'data' => '}'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 123,
                   'data' => 'lstat',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'data' => '$ro_empty_file',
                   'line' => 123
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 123,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'ln -s $ro_empty_file 1',
                   'has_warnings' => 0,
                   'line' => 124,
                   'name' => 'ExecString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_ExecString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 124,
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'isnt',
                   'has_warnings' => 1,
                   'line' => 125
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 125,
                   'has_warnings' => 0,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 125,
                   'has_warnings' => 0,
                   'data' => '-l',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-e',
                   'has_warnings' => 0,
                   'line' => 125,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => '_',
                   'line' => 125,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 125,
                   'has_warnings' => 0,
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 125,
                   'has_warnings' => 0,
                   'data' => '1',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'line' => 125,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 125,
                   'data' => 'stacked -l uses previous stat, not previous retval',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 125
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 125,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 126,
                   'data' => 'unlink',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '1',
                   'has_warnings' => 0,
                   'line' => 126,
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 126,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 131,
                   'has_warnings' => 0,
                   'data' => 'system',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'ln',
                   'has_warnings' => 0,
                   'line' => 131,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 131
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-s',
                   'has_warnings' => 0,
                   'line' => 131,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'line' => 131,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '$ro_empty_file',
                   'line' => 131
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 131,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Ref,
                   'name' => 'Ref',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 131,
                   'data' => '\\',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Glob,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Glob',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 131,
                   'data' => '*foo',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 131,
                   'has_warnings' => 0,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 132,
                   'has_warnings' => 0,
                   'data' => 'local',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LocalDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'LocalDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SpecificValue',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'data' => '$^W',
                   'has_warnings' => 0,
                   'line' => 132
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 132,
                   'data' => '=',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Assign',
                   'kind' => Compiler::Lexer::Kind::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 132,
                   'data' => '1',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'line' => 132,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'VarDecl',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'has_warnings' => 0,
                   'line' => 133
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LocalArrayVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'LocalArrayVar',
                   'line' => 133,
                   'has_warnings' => 0,
                   'data' => '@warnings'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'line' => 133,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 134,
                   'has_warnings' => 0,
                   'data' => 'local',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LocalDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'LocalDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_GlobalVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'GlobalVar',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 134,
                   'data' => '$SIG',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 134,
                   'data' => '{',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '__WARN__',
                   'has_warnings' => 0,
                   'line' => 134
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 134,
                   'data' => '}',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'has_warnings' => 0,
                   'line' => 134,
                   'name' => 'Assign',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 134,
                   'has_warnings' => 0,
                   'data' => 'sub',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'FunctionDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'has_warnings' => 0,
                   'line' => 134
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'push',
                   'line' => 134,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'ArrayVar',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '@warnings',
                   'has_warnings' => 0,
                   'line' => 134
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'line' => 134,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_ArgumentArray,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'ArgumentArray',
                   'line' => 134,
                   'has_warnings' => 0,
                   'data' => '@_'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'has_warnings' => 0,
                   'line' => 134,
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 134
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'is',
                   'has_warnings' => 1,
                   'line' => 135
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 135,
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle',
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '-l',
                   'line' => 135
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Ref,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'Ref',
                   'line' => 135,
                   'has_warnings' => 0,
                   'data' => '\\'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '*foo',
                   'line' => 135,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'Glob',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Glob
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 135
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 135,
                   'data' => '1',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 135,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'line' => 135,
                   'has_warnings' => 0,
                   'data' => '-l \\*foo is a file name'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 135,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 135,
                   'has_warnings' => 0,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'ok',
                   'has_warnings' => 1,
                   'line' => 136
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'line' => 136,
                   'has_warnings' => 0,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$warnings',
                   'line' => 136,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'GlobalVar',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_GlobalVar
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 136,
                   'data' => '[',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int',
                   'line' => 136,
                   'has_warnings' => 0,
                   'data' => '0'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBracket',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'has_warnings' => 0,
                   'data' => ']',
                   'line' => 136
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegOK,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegOK',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 136,
                   'data' => '=~',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '/',
                   'has_warnings' => 0,
                   'line' => 136,
                   'name' => 'RegDelim',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegExp',
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '-l on filehandle foo',
                   'line' => 136
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 136,
                   'data' => '/',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 136
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'warning for -l $handle',
                   'line' => 136
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 136,
                   'data' => ')',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'line' => 136,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'line' => 137,
                   'has_warnings' => 0,
                   'data' => 'unlink'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '\\',
                   'has_warnings' => 0,
                   'line' => 137,
                   'name' => 'Ref',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_Ref,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'Glob',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Glob,
                   'has_warnings' => 0,
                   'data' => '*foo',
                   'line' => 137
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 137
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '}',
                   'line' => 138,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '{',
                   'line' => 140
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'local',
                   'has_warnings' => 0,
                   'line' => 141,
                   'name' => 'LocalDecl',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_LocalDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$^W',
                   'line' => 141,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'SpecificValue',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'has_warnings' => 0,
                   'line' => 141,
                   'name' => 'Assign',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 141,
                   'data' => '1',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 141,
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'VarDecl',
                   'line' => 142,
                   'has_warnings' => 0,
                   'data' => 'my'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 142,
                   'data' => '@warnings',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalArrayVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LocalArrayVar',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 142,
                   'data' => ';',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 143,
                   'has_warnings' => 0,
                   'data' => 'local',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LocalDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'LocalDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$SIG',
                   'line' => 143,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '{',
                   'line' => 143,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 143,
                   'data' => '__WARN__',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 143,
                   'data' => '}',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '=',
                   'line' => 143
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'FunctionDecl',
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'sub',
                   'line' => 143
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 143,
                   'has_warnings' => 0,
                   'data' => '{',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 143,
                   'has_warnings' => 0,
                   'data' => 'push',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'ArrayVar',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '@warnings',
                   'has_warnings' => 0,
                   'line' => 143
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 143,
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'ArgumentArray',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_ArgumentArray,
                   'data' => '@_',
                   'has_warnings' => 0,
                   'line' => 143
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}',
                   'has_warnings' => 0,
                   'line' => 143
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 143,
                   'data' => ';',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 144
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 144,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '=',
                   'line' => 144,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'line' => 144,
                   'data' => '-l',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '\\',
                   'has_warnings' => 0,
                   'line' => 144,
                   'name' => 'Ref',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Ref
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 144,
                   'has_warnings' => 0,
                   'data' => '*',
                   'type' => Compiler::Lexer::TokenType::T_Glob,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'Glob'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '{',
                   'line' => 144
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '\\x{3c6}oo',
                   'has_warnings' => 0,
                   'line' => 144
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace',
                   'line' => 144,
                   'has_warnings' => 0,
                   'data' => '}'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 144
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'like',
                   'has_warnings' => 1,
                   'line' => 145,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 145,
                   'data' => '(',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'line' => 145,
                   'has_warnings' => 0,
                   'data' => '$warnings'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '[',
                   'line' => 145
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 145,
                   'has_warnings' => 0,
                   'data' => '0',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBracket',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'has_warnings' => 0,
                   'data' => ']',
                   'line' => 145
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 145
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegDecl,
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'name' => 'RegDecl',
                   'line' => 145,
                   'has_warnings' => 0,
                   'data' => 'qr'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegDelim',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 145,
                   'data' => '/',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegExp',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'data' => '-l on filehandle \\x{3c6}oo',
                   'has_warnings' => 0,
                   'line' => 145
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 145,
                   'data' => '/',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 145,
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '-l $handle warning is utf8-clean',
                   'has_warnings' => 0,
                   'line' => 146
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 146,
                   'data' => ')',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 146
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 147,
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 147
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'name' => 'Assign',
                   'line' => 147,
                   'has_warnings' => 0,
                   'data' => '='
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 147,
                   'has_warnings' => 0,
                   'data' => '-l',
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '*foo',
                   'has_warnings' => 0,
                   'line' => 147,
                   'name' => 'Mul',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_Mul,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 147,
                   'data' => ';',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'like',
                   'has_warnings' => 1,
                   'line' => 148
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'has_warnings' => 0,
                   'line' => 148,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 148,
                   'has_warnings' => 0,
                   'data' => '$warnings',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 148,
                   'data' => '[',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'data' => '1',
                   'has_warnings' => 0,
                   'line' => 148
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 148,
                   'has_warnings' => 0,
                   'data' => ']',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBracket'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 148,
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegDecl,
                   'name' => 'RegDecl',
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'line' => 148,
                   'data' => 'qr',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 148,
                   'data' => '/',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegExp',
                   'line' => 148,
                   'has_warnings' => 0,
                   'data' => '-l on filehandle foo'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegDelim',
                   'line' => 148,
                   'has_warnings' => 0,
                   'data' => '/'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 148,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-l $handle warning occurs for globs, not just globrefs',
                   'line' => 149,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 149,
                   'data' => ')',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 149,
                   'data' => ';',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'tell',
                   'line' => 150
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 150,
                   'data' => 'foo',
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 150,
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'line' => 151,
                   'has_warnings' => 0,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 151,
                   'data' => ')',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 151,
                   'has_warnings' => 0,
                   'data' => '=',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-l',
                   'has_warnings' => 0,
                   'line' => 151,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '*foo',
                   'line' => 151,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'Mul',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Mul
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'has_warnings' => 0,
                   'data' => '{',
                   'line' => 151
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'IO',
                   'has_warnings' => 0,
                   'line' => 151,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}',
                   'has_warnings' => 0,
                   'line' => 151
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 151,
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'data' => 'like',
                   'line' => 153
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 153,
                   'has_warnings' => 0,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$warnings',
                   'has_warnings' => 0,
                   'line' => 153
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBracket',
                   'line' => 153,
                   'has_warnings' => 0,
                   'data' => '['
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 153,
                   'data' => '3',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ']',
                   'has_warnings' => 0,
                   'line' => 153,
                   'name' => 'RightBracket',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 153,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 153,
                   'data' => 'qr',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegDecl,
                   'name' => 'RegDecl',
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 153,
                   'data' => '/',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegDelim',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegExp',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'data' => '-l on filehandle at',
                   'has_warnings' => 0,
                   'line' => 153
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 153,
                   'data' => '/',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'line' => 153,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-l $handle warning occurs for iorefs as well',
                   'line' => 154,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 154,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 154,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'has_warnings' => 0,
                   'line' => 155,
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 159,
                   'data' => '-f',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 159,
                   'has_warnings' => 0,
                   'data' => 'TEST',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 159
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 160,
                   'data' => 'is',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 160,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'data' => '-f',
                   'has_warnings' => 0,
                   'line' => 160
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '_',
                   'has_warnings' => 1,
                   'line' => 160
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 160,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 160,
                   'data' => '1',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 160,
                   'has_warnings' => 0,
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'line' => 160,
                   'has_warnings' => 0,
                   'data' => '_ is bareword after filetest operator'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 160,
                   'data' => ')',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'line' => 160,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'FunctionDecl',
                   'line' => 161,
                   'has_warnings' => 0,
                   'data' => 'sub'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Function,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'Function',
                   'line' => 161,
                   'has_warnings' => 0,
                   'data' => '_'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBrace',
                   'line' => 161,
                   'has_warnings' => 0,
                   'data' => '{'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => 'this is not a file name',
                   'has_warnings' => 0,
                   'line' => 161
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 161,
                   'has_warnings' => 0,
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'is',
                   'has_warnings' => 1,
                   'line' => 162,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'has_warnings' => 0,
                   'line' => 162,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'line' => 162,
                   'data' => '-f',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '_',
                   'line' => 162,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'Call',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Call
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 162,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 162,
                   'data' => '1',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 162,
                   'data' => ',',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => '_ is bareword after filetest operator',
                   'has_warnings' => 0,
                   'line' => 162
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 162,
                   'has_warnings' => 0,
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 162,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'VarDecl',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'data' => 'my',
                   'has_warnings' => 0,
                   'line' => 164
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$over',
                   'line' => 164,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'LocalVar',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 164,
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 165,
                   'has_warnings' => 0,
                   'data' => '{',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 166,
                   'has_warnings' => 0,
                   'data' => 'package',
                   'type' => Compiler::Lexer::TokenType::T_Package,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Package,
                   'name' => 'Package'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Class,
                   'name' => 'Class',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Class,
                   'has_warnings' => 0,
                   'data' => 'OverFtest',
                   'line' => 166
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 166
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 168,
                   'data' => 'use',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'UseDecl',
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'overload',
                   'has_warnings' => 0,
                   'line' => 168,
                   'name' => 'UsedName',
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'fallback',
                   'line' => 169,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'Arrow',
                   'line' => 169,
                   'has_warnings' => 0,
                   'data' => '=>'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 169,
                   'has_warnings' => 0,
                   'data' => '1',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 169,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 170,
                   'data' => '-X',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 170,
                   'data' => '=>',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'sub',
                   'line' => 170,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'FunctionDecl',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'has_warnings' => 0,
                   'data' => '{',
                   'line' => 170
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'line' => 171,
                   'has_warnings' => 0,
                   'data' => '$over'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'has_warnings' => 0,
                   'line' => 171,
                   'name' => 'Assign',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '[',
                   'line' => 171,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegDoubleQuote,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'name' => 'RegDoubleQuote',
                   'line' => 171,
                   'has_warnings' => 0,
                   'data' => 'qq'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'has_warnings' => 0,
                   'line' => 171,
                   'name' => 'RegDelim',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegExp',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'has_warnings' => 0,
                   'data' => '$_[0]',
                   'line' => 171
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegDelim',
                   'line' => 171,
                   'has_warnings' => 0,
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 171,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$_',
                   'has_warnings' => 0,
                   'line' => 171,
                   'name' => 'SpecificValue',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '[',
                   'has_warnings' => 0,
                   'line' => 171,
                   'name' => 'LeftBracket',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'data' => '1',
                   'line' => 171
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 171,
                   'has_warnings' => 0,
                   'data' => ']',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBracket'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 171,
                   'has_warnings' => 0,
                   'data' => ']',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBracket'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'line' => 171,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '-$_[1]',
                   'has_warnings' => 0,
                   'line' => 172
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 172,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 173,
                   'has_warnings' => 0,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 173,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 174,
                   'has_warnings' => 0,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBrace',
                   'line' => 175,
                   'has_warnings' => 0,
                   'data' => '{'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'package',
                   'has_warnings' => 0,
                   'line' => 176,
                   'name' => 'Package',
                   'kind' => Compiler::Lexer::Kind::T_Package,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Package
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 176,
                   'has_warnings' => 0,
                   'data' => 'OverString',
                   'type' => Compiler::Lexer::TokenType::T_Class,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Class,
                   'name' => 'Class'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'line' => 176,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 180,
                   'has_warnings' => 0,
                   'data' => 'use',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'UseDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'UsedName',
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'data' => 'overload',
                   'has_warnings' => 0,
                   'line' => 180
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 180,
                   'data' => 'q',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegQuote,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegQuote',
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegDelim',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'data' => '/',
                   'has_warnings' => 0,
                   'line' => 180
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 180,
                   'data' => '""',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegExp',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '/',
                   'line' => 180,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegDelim',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 180,
                   'has_warnings' => 0,
                   'data' => '=>',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'Arrow'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'FunctionDecl',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 180,
                   'data' => 'sub',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBrace',
                   'line' => 180,
                   'has_warnings' => 0,
                   'data' => '{'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$over',
                   'has_warnings' => 0,
                   'line' => 180
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'name' => 'Assign',
                   'line' => 180,
                   'has_warnings' => 0,
                   'data' => '='
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'data' => '1',
                   'line' => 180
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 180
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => 'TEST',
                   'has_warnings' => 0,
                   'line' => 180
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '}',
                   'line' => 180
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 180,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '}',
                   'line' => 181
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBrace',
                   'line' => 182,
                   'has_warnings' => 0,
                   'data' => '{'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 183,
                   'has_warnings' => 0,
                   'data' => 'package',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Package,
                   'kind' => Compiler::Lexer::Kind::T_Package,
                   'name' => 'Package'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Class',
                   'kind' => Compiler::Lexer::Kind::T_Class,
                   'type' => Compiler::Lexer::TokenType::T_Class,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'OverBoth',
                   'has_warnings' => 0,
                   'line' => 183
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 183,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 185,
                   'data' => 'use',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'name' => 'UseDecl',
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'name' => 'UsedName',
                   'line' => 186,
                   'has_warnings' => 0,
                   'data' => 'overload'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 186,
                   'has_warnings' => 0,
                   'data' => 'q',
                   'type' => Compiler::Lexer::TokenType::T_RegQuote,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'name' => 'RegQuote'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegDelim',
                   'line' => 186,
                   'has_warnings' => 0,
                   'data' => '/'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 186,
                   'has_warnings' => 0,
                   'data' => '""',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegExp'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '/',
                   'line' => 186
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 186,
                   'data' => '=>',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Arrow',
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 186,
                   'has_warnings' => 0,
                   'data' => 'sub',
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'FunctionDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 186,
                   'data' => '{',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'data' => 'TEST',
                   'line' => 186
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 186,
                   'has_warnings' => 0,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 186,
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-X',
                   'line' => 187,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle',
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Arrow',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 187,
                   'data' => '=>',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'FunctionDecl',
                   'line' => 187,
                   'has_warnings' => 0,
                   'data' => 'sub'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 187,
                   'data' => '{',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-$_[1]',
                   'line' => 187,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '}',
                   'line' => 187,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'line' => 187,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 188,
                   'data' => '}',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBrace',
                   'line' => 189,
                   'has_warnings' => 0,
                   'data' => '{'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 190,
                   'data' => 'package',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Package,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Package',
                   'kind' => Compiler::Lexer::Kind::T_Package
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Class,
                   'name' => 'Class',
                   'type' => Compiler::Lexer::TokenType::T_Class,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'OverNeither',
                   'line' => 190
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 190
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'use',
                   'has_warnings' => 0,
                   'line' => 194,
                   'name' => 'UseDecl',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 194,
                   'data' => 'overload',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'name' => 'UsedName',
                   'kind' => Compiler::Lexer::Kind::T_Module
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'data' => '+',
                   'line' => 195
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 195,
                   'data' => '=>',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Arrow',
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'FunctionDecl',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 195,
                   'data' => 'sub',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 195,
                   'data' => '{',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'data' => '1',
                   'has_warnings' => 0,
                   'line' => 195
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace',
                   'line' => 195,
                   'has_warnings' => 0,
                   'data' => '}'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 195,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 0,
                   'data' => 'fallback',
                   'line' => 196
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Arrow',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 196,
                   'data' => '=>',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '1',
                   'has_warnings' => 0,
                   'line' => 196
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 196
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace',
                   'line' => 197,
                   'has_warnings' => 0,
                   'data' => '}'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 199,
                   'has_warnings' => 0,
                   'data' => 'my',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$ft',
                   'has_warnings' => 0,
                   'line' => 199,
                   'name' => 'LocalVar',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 199,
                   'has_warnings' => 0,
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'bless',
                   'has_warnings' => 0,
                   'line' => 199
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 199,
                   'has_warnings' => 0,
                   'data' => '[',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBracket'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'name' => 'RightBracket',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 199,
                   'data' => ']',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 199
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 199,
                   'data' => 'OverFtest',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 199
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 200,
                   'data' => 'my',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'VarDecl',
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LocalVar',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'data' => '$ftstr',
                   'has_warnings' => 0,
                   'line' => 200
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 200,
                   'data' => '=',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'kind' => Compiler::Lexer::Kind::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'qq',
                   'line' => 200,
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'name' => 'RegDoubleQuote',
                   'type' => Compiler::Lexer::TokenType::T_RegDoubleQuote,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'has_warnings' => 0,
                   'line' => 200,
                   'name' => 'RegDelim',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$ft',
                   'has_warnings' => 0,
                   'line' => 200,
                   'name' => 'RegExp',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegDelim',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 200
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 200,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'VarDecl',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'data' => 'my',
                   'has_warnings' => 0,
                   'line' => 201
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 201,
                   'data' => '$str',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'has_warnings' => 0,
                   'line' => 201,
                   'name' => 'Assign',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'bless',
                   'line' => 201,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftBracket',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 201,
                   'data' => '[',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBracket',
                   'line' => 201,
                   'has_warnings' => 0,
                   'data' => ']'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 201,
                   'data' => ',',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'OverString',
                   'line' => 201,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 201,
                   'data' => ';',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'my',
                   'line' => 202,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'VarDecl',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$both',
                   'has_warnings' => 0,
                   'line' => 202,
                   'name' => 'LocalVar',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'has_warnings' => 0,
                   'line' => 202,
                   'name' => 'Assign',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 202,
                   'has_warnings' => 0,
                   'data' => 'bless',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 202,
                   'data' => '[',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBracket',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ']',
                   'has_warnings' => 0,
                   'line' => 202
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 202,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 202,
                   'has_warnings' => 0,
                   'data' => 'OverBoth',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 202
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'VarDecl',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'has_warnings' => 0,
                   'data' => 'my',
                   'line' => 203
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 203,
                   'has_warnings' => 0,
                   'data' => '$neither',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'LocalVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Assign',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 203,
                   'data' => '=',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'bless',
                   'line' => 203
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 203,
                   'has_warnings' => 0,
                   'data' => '[',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBracket'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 203,
                   'has_warnings' => 0,
                   'data' => ']',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBracket'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 203
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'OverNeither',
                   'line' => 203,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 203,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'my',
                   'line' => 204,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'VarDecl',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 204,
                   'data' => '$nstr',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 204,
                   'has_warnings' => 0,
                   'data' => '=',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegDoubleQuote,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegDoubleQuote',
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'line' => 204,
                   'data' => 'qq',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegDelim',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'has_warnings' => 0,
                   'line' => 204
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegExp',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 204,
                   'data' => '$neither',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 204
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'line' => 204,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 206,
                   'data' => 'open',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'my',
                   'line' => 206
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 206,
                   'data' => '$gv',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LocalVar',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'line' => 206,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 206,
                   'data' => '<',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 206
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 206,
                   'data' => 'TEST',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 206,
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 207,
                   'data' => 'bless',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$gv',
                   'has_warnings' => 0,
                   'line' => 207,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 207,
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'OverString',
                   'has_warnings' => 0,
                   'line' => 207
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 207,
                   'data' => ';',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 208,
                   'data' => 'open',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'VarDecl',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'data' => 'my',
                   'has_warnings' => 0,
                   'line' => 208
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 208,
                   'has_warnings' => 0,
                   'data' => '$io',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'LocalVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 208,
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => '<',
                   'has_warnings' => 0,
                   'line' => 208
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 208,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'TEST',
                   'line' => 208,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 208,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$io',
                   'has_warnings' => 0,
                   'line' => 209,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 209,
                   'data' => '=',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'kind' => Compiler::Lexer::Kind::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Glob,
                   'name' => 'Glob',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 209,
                   'data' => '*',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 209,
                   'has_warnings' => 0,
                   'data' => '{',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$io',
                   'line' => 209,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 209,
                   'data' => '}',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 209,
                   'has_warnings' => 0,
                   'data' => '{',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 209,
                   'data' => 'IO',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0,
                   'data' => '}',
                   'line' => 209
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'line' => 209,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 210,
                   'data' => 'bless',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$io',
                   'has_warnings' => 0,
                   'line' => 210
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 210
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'OverString',
                   'line' => 210,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 210,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'VarDecl',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 212,
                   'data' => 'my',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LocalVar',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'data' => '$fcntl_not_available',
                   'has_warnings' => 0,
                   'line' => 212
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 212,
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'eval',
                   'has_warnings' => 0,
                   'line' => 213,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 213,
                   'data' => '{',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 213,
                   'data' => 'require',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RequireDecl,
                   'name' => 'RequireDecl',
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RequiredName,
                   'name' => 'RequiredName',
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'line' => 213,
                   'data' => 'Fcntl',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '}',
                   'line' => 213,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'or',
                   'has_warnings' => 0,
                   'line' => 213,
                   'name' => 'AlphabetOr',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 213,
                   'has_warnings' => 0,
                   'data' => '$fcntl_not_available',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'has_warnings' => 0,
                   'line' => 213,
                   'name' => 'Assign',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'data' => '1',
                   'has_warnings' => 0,
                   'line' => 213
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 213
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 215,
                   'data' => 'for',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ForStmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'ForStmt',
                   'kind' => Compiler::Lexer::Kind::T_Stmt
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'my',
                   'line' => 215
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'LocalVar',
                   'line' => 215,
                   'has_warnings' => 0,
                   'data' => '$op'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 215,
                   'has_warnings' => 0,
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'line' => 215,
                   'has_warnings' => 0,
                   'data' => 'split'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 215,
                   'data' => '/',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegDelim',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'name' => 'RegExp',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 215,
                   'data' => '',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegDelim',
                   'line' => 215,
                   'has_warnings' => 0,
                   'data' => '/'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 215
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'rwxoRWXOezsfdlpSbctugkTMBAC',
                   'has_warnings' => 0,
                   'line' => 215,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 215,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'has_warnings' => 0,
                   'line' => 215,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 216,
                   'data' => '$over',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '=',
                   'line' => 216,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '[',
                   'line' => 216,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBracket',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'name' => 'RightBracket',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 216,
                   'data' => ']',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 216,
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'VarDecl',
                   'line' => 217,
                   'has_warnings' => 0,
                   'data' => 'my'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 217,
                   'has_warnings' => 0,
                   'data' => '$rv',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'LocalVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'name' => 'Assign',
                   'line' => 217,
                   'has_warnings' => 0,
                   'data' => '='
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'eval',
                   'line' => 217
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => '-$op \\$ft',
                   'has_warnings' => 0,
                   'line' => 217
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 217
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 218,
                   'data' => 'isnt',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'has_warnings' => 0,
                   'line' => 218
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '$rv',
                   'line' => 218
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 218
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'undef',
                   'has_warnings' => 0,
                   'line' => 218,
                   'name' => 'Default',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Default,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 218,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 218,
                   'data' => 'overloaded -$op succeeds',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'line' => 218,
                   'has_warnings' => 0,
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'AlphabetOr',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'or',
                   'has_warnings' => 0,
                   'line' => 219
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 219,
                   'data' => 'diag',
                   'has_warnings' => 1,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 219,
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SpecificValue',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 219,
                   'data' => '$@',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 219,
                   'data' => ')',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 219,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 220,
                   'has_warnings' => 1,
                   'data' => 'is',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 220,
                   'has_warnings' => 0,
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'line' => 220,
                   'has_warnings' => 0,
                   'data' => '$over'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Pointer',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_Pointer,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '->',
                   'has_warnings' => 0,
                   'line' => 220
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftBracket',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 220,
                   'data' => '[',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '0',
                   'line' => 220,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ']',
                   'has_warnings' => 0,
                   'line' => 220,
                   'name' => 'RightBracket',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 220
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'line' => 220,
                   'has_warnings' => 0,
                   'data' => '$ftstr'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 220,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'correct object for overloaded -$op',
                   'line' => 220
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'line' => 220,
                   'has_warnings' => 0,
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 220,
                   'has_warnings' => 0,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'is',
                   'line' => 221,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 221,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'data' => '$over',
                   'line' => 221
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 221,
                   'data' => '->',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Pointer,
                   'name' => 'Pointer',
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 221,
                   'has_warnings' => 0,
                   'data' => '[',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBracket'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '1',
                   'has_warnings' => 0,
                   'line' => 221
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBracket',
                   'line' => 221,
                   'has_warnings' => 0,
                   'data' => ']'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 221,
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'line' => 221,
                   'has_warnings' => 0,
                   'data' => '$op'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 221,
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'correct op for overloaded -$op',
                   'has_warnings' => 0,
                   'line' => 221
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'line' => 221,
                   'has_warnings' => 0,
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 221,
                   'data' => ';',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'data' => 'is',
                   'line' => 222
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 222,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'line' => 222,
                   'has_warnings' => 0,
                   'data' => '$rv'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 222,
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => '-$op',
                   'has_warnings' => 0,
                   'line' => 222
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 222,
                   'data' => ',',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 222,
                   'data' => 'correct return value for overloaded -$op',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 222
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 222
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'my',
                   'has_warnings' => 0,
                   'line' => 224,
                   'name' => 'VarDecl',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 224
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_GlobalVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'GlobalVar',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 224,
                   'data' => '$exp',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 224,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$is',
                   'line' => 224,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'GlobalVar',
                   'type' => Compiler::Lexer::TokenType::T_GlobalVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 224,
                   'has_warnings' => 0,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'has_warnings' => 0,
                   'line' => 224,
                   'name' => 'Assign',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'has_warnings' => 0,
                   'line' => 224
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 224,
                   'data' => '1',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 224,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 224,
                   'data' => 'is',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 224,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 224,
                   'has_warnings' => 0,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'name' => 'IfStmt',
                   'line' => 225,
                   'has_warnings' => 0,
                   'data' => 'if'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 225
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'has_warnings' => 0,
                   'line' => 226,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Not,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_SingleTerm,
                   'name' => 'Not',
                   'line' => 227,
                   'has_warnings' => 0,
                   'data' => '!'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 227,
                   'data' => '$fcntl_not_available',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'and',
                   'has_warnings' => 0,
                   'line' => 228,
                   'name' => 'AlphabetAnd',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetAnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'line' => 228,
                   'has_warnings' => 0,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 229,
                   'data' => '$op',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 229,
                   'data' => 'eq',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'name' => 'StringEqual',
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'u',
                   'line' => 229,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'AlphabetAnd',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetAnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'and',
                   'has_warnings' => 0,
                   'line' => 229
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_SingleTerm,
                   'name' => 'AlphabetNot',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetNot,
                   'has_warnings' => 0,
                   'data' => 'not',
                   'line' => 229
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 229,
                   'data' => 'eval',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'has_warnings' => 0,
                   'line' => 229,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'name' => 'Namespace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'has_warnings' => 0,
                   'data' => 'Fcntl',
                   'line' => 229
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '::',
                   'has_warnings' => 0,
                   'line' => 229,
                   'name' => 'NamespaceResolver',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_NamespaceResolver,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'name' => 'Namespace',
                   'line' => 229,
                   'has_warnings' => 0,
                   'data' => 'S_ISUID'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 229,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 229,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '}',
                   'line' => 229,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'AlphabetOr',
                   'line' => 230,
                   'has_warnings' => 0,
                   'data' => 'or'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$op',
                   'has_warnings' => 0,
                   'line' => 230,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 230,
                   'data' => 'eq',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'name' => 'StringEqual',
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => 'g',
                   'has_warnings' => 0,
                   'line' => 230
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'AlphabetAnd',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetAnd,
                   'data' => 'and',
                   'has_warnings' => 0,
                   'line' => 230
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_SingleTerm,
                   'name' => 'AlphabetNot',
                   'type' => Compiler::Lexer::TokenType::T_AlphabetNot,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'not',
                   'line' => 230
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'eval',
                   'has_warnings' => 0,
                   'line' => 230,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 230,
                   'has_warnings' => 0,
                   'data' => '{',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 230,
                   'has_warnings' => 0,
                   'data' => 'Fcntl',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'name' => 'Namespace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'NamespaceResolver',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_NamespaceResolver,
                   'data' => '::',
                   'has_warnings' => 0,
                   'line' => 230
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Namespace',
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'S_ISGID',
                   'has_warnings' => 0,
                   'line' => 230
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 230,
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 230,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'has_warnings' => 0,
                   'line' => 230,
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'or',
                   'line' => 231,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'AlphabetOr',
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$op',
                   'has_warnings' => 0,
                   'line' => 231,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 231,
                   'data' => 'eq',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'name' => 'StringEqual',
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 231,
                   'data' => 'k',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'and',
                   'has_warnings' => 0,
                   'line' => 231,
                   'name' => 'AlphabetAnd',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetAnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_AlphabetNot,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_SingleTerm,
                   'name' => 'AlphabetNot',
                   'line' => 231,
                   'has_warnings' => 0,
                   'data' => 'not'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'eval',
                   'line' => 231,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'has_warnings' => 0,
                   'line' => 231,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'name' => 'Namespace',
                   'line' => 231,
                   'has_warnings' => 0,
                   'data' => 'Fcntl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_NamespaceResolver,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'NamespaceResolver',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 231,
                   'data' => '::',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 231,
                   'data' => 'S_ISVTX',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Namespace',
                   'kind' => Compiler::Lexer::Kind::T_Namespace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 231,
                   'data' => '(',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 231
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '}',
                   'line' => 231,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 232,
                   'has_warnings' => 0,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 233,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '||',
                   'line' => 234,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'Or',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Or
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 237,
                   'has_warnings' => 0,
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$^O',
                   'line' => 237,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'SpecificValue',
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 237,
                   'has_warnings' => 0,
                   'data' => 'eq',
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'StringEqual'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'MSWin32',
                   'has_warnings' => 0,
                   'line' => 237,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_And,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'And',
                   'line' => 237,
                   'has_warnings' => 0,
                   'data' => '&&'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$op',
                   'has_warnings' => 0,
                   'line' => 237
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'StringEqual',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'has_warnings' => 0,
                   'data' => 'eq',
                   'line' => 237
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'data' => 'k',
                   'line' => 237
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '&&',
                   'line' => 237,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'And',
                   'type' => Compiler::Lexer::TokenType::T_And,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'is_miniperl',
                   'has_warnings' => 1,
                   'line' => 237
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 237,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 238,
                   'has_warnings' => 0,
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '{',
                   'line' => 238,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 239,
                   'has_warnings' => 0,
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'data' => '$exp',
                   'line' => 239
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'line' => 239,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$is',
                   'has_warnings' => 0,
                   'line' => 239
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 239,
                   'data' => ')',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '=',
                   'line' => 239
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'line' => 239,
                   'has_warnings' => 0,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '0',
                   'line' => 239,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 239
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'not',
                   'has_warnings' => 0,
                   'line' => 239,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 239,
                   'data' => ')',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 239,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace',
                   'line' => 240,
                   'has_warnings' => 0,
                   'data' => '}'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 242,
                   'has_warnings' => 0,
                   'data' => '$over',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 242,
                   'data' => '=',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '0',
                   'has_warnings' => 0,
                   'line' => 242
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 242,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'data' => '$rv',
                   'line' => 243
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Assign',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 243,
                   'data' => '=',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'eval',
                   'line' => 243
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '-$op \\$str',
                   'line' => 243
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 243,
                   'has_warnings' => 0,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'is',
                   'line' => 244,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 244,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'SpecificValue',
                   'line' => 244,
                   'has_warnings' => 0,
                   'data' => '$@'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 244,
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 244,
                   'data' => '',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 244,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'data' => '-$op succeeds with string overloading',
                   'line' => 244
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 244,
                   'has_warnings' => 0,
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 244
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'is',
                   'line' => 245,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'line' => 245,
                   'has_warnings' => 0,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$rv',
                   'has_warnings' => 0,
                   'line' => 245
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 245,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'eval',
                   'has_warnings' => 0,
                   'line' => 245,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'data' => '-$op \'TEST\'',
                   'line' => 245
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 245,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'correct -$op on string overload',
                   'line' => 245
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 245,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 245
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'is',
                   'has_warnings' => 1,
                   'line' => 246
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 246,
                   'data' => '(',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'line' => 246,
                   'has_warnings' => 0,
                   'data' => '$over'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 246,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'line' => 246,
                   'has_warnings' => 0,
                   'data' => '$exp'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'line' => 246,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 246,
                   'data' => 'string overload $is called for -$op',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 246,
                   'data' => ')',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 246,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 248,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$exp',
                   'has_warnings' => 0,
                   'line' => 248
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 248
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '$is',
                   'line' => 248
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 248,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Assign',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 248,
                   'data' => '=',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$op',
                   'line' => 248,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'eq',
                   'has_warnings' => 0,
                   'line' => 248,
                   'name' => 'StringEqual',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_StringEqual
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 248,
                   'data' => 'l',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 248,
                   'data' => '?',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ThreeTermOperator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'ThreeTermOperator',
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'has_warnings' => 0,
                   'line' => 248,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '1',
                   'line' => 248
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 248,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'line' => 248,
                   'has_warnings' => 0,
                   'data' => 'is'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'line' => 248,
                   'has_warnings' => 0,
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ':',
                   'line' => 248,
                   'kind' => Compiler::Lexer::Kind::T_Colon,
                   'name' => 'Colon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Colon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 248,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 248,
                   'data' => '0',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 248,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 248,
                   'data' => 'not',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 248,
                   'has_warnings' => 0,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 248,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'line' => 250,
                   'has_warnings' => 0,
                   'data' => '$over'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '=',
                   'line' => 250
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int',
                   'line' => 250,
                   'has_warnings' => 0,
                   'data' => '0'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 250
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'eval',
                   'has_warnings' => 0,
                   'line' => 251,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 251,
                   'data' => '-$op \\$gv',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 251,
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'is',
                   'has_warnings' => 1,
                   'line' => 252,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 252
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$over',
                   'line' => 252,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 252,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$exp',
                   'has_warnings' => 0,
                   'line' => 252
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 252,
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 252,
                   'data' => 'string overload $is called for -$op on GLOB',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 252
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 252,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 255,
                   'data' => '$op',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'StringEqual',
                   'line' => 255,
                   'has_warnings' => 0,
                   'data' => 'eq'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 255,
                   'data' => 't',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Or,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'Or',
                   'line' => 255,
                   'has_warnings' => 0,
                   'data' => '||'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 255,
                   'data' => '$op',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'name' => 'StringEqual',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 255,
                   'data' => 'eq',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'T',
                   'has_warnings' => 0,
                   'line' => 255,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Or,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'Or',
                   'line' => 255,
                   'has_warnings' => 0,
                   'data' => '||'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$op',
                   'has_warnings' => 0,
                   'line' => 255
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 255,
                   'has_warnings' => 0,
                   'data' => 'eq',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'StringEqual'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'B',
                   'has_warnings' => 0,
                   'line' => 255
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 256,
                   'data' => 'and',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetAnd,
                   'name' => 'AlphabetAnd',
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 256,
                   'has_warnings' => 0,
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 256,
                   'has_warnings' => 0,
                   'data' => '$exp',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 256,
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 256,
                   'data' => '$is',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 256
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 256,
                   'has_warnings' => 0,
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 256,
                   'data' => '(',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 256,
                   'data' => '1',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'line' => 256,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 256,
                   'has_warnings' => 0,
                   'data' => 'is',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 256
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 256,
                   'data' => ';',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '$over',
                   'line' => 258
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'data' => '=',
                   'has_warnings' => 0,
                   'line' => 258
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'data' => '0',
                   'line' => 258
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 258,
                   'has_warnings' => 0,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'eval',
                   'has_warnings' => 0,
                   'line' => 259,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'line' => 259,
                   'has_warnings' => 0,
                   'data' => '-$op \\$io'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 259,
                   'data' => ';',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 260,
                   'data' => 'is',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 260,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$over',
                   'has_warnings' => 0,
                   'line' => 260,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'line' => 260,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 260,
                   'data' => '$exp',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 260,
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'string overload $is called for -$op on IO',
                   'line' => 260,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 260,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 260,
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$rv',
                   'line' => 262,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 262,
                   'data' => '=',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'kind' => Compiler::Lexer::Kind::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'eval',
                   'line' => 262
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '-$op \\$both',
                   'has_warnings' => 0,
                   'line' => 262
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 262,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 263,
                   'has_warnings' => 1,
                   'data' => 'is',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'has_warnings' => 0,
                   'line' => 263
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 263,
                   'data' => '$rv',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 263,
                   'has_warnings' => 0,
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '-$op',
                   'line' => 263
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 263,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'data' => 'correct -$op on string/-X overload',
                   'line' => 263
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'line' => 263,
                   'has_warnings' => 0,
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'line' => 263,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$rv',
                   'line' => 265,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 265,
                   'has_warnings' => 0,
                   'data' => '=',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'line' => 265,
                   'has_warnings' => 0,
                   'data' => 'eval'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'line' => 265,
                   'has_warnings' => 0,
                   'data' => '-$op \\$neither'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 265,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'is',
                   'has_warnings' => 1,
                   'line' => 266
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 266
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$@',
                   'has_warnings' => 0,
                   'line' => 266,
                   'name' => 'SpecificValue',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 266
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 266,
                   'data' => '',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 266,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 266,
                   'has_warnings' => 0,
                   'data' => '-$op succeeds with random overloading',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 266,
                   'data' => ')',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 266,
                   'data' => ';',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 267,
                   'has_warnings' => 1,
                   'data' => 'is',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 267,
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 267,
                   'data' => '$rv',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'line' => 267,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 267,
                   'has_warnings' => 0,
                   'data' => 'eval',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => '-$op \\$nstr',
                   'has_warnings' => 0,
                   'line' => 267
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 267,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'line' => 267,
                   'has_warnings' => 0,
                   'data' => 'correct -$op with random overloading'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 267,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 267
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'is',
                   'has_warnings' => 1,
                   'line' => 269,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'line' => 269,
                   'has_warnings' => 0,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 269,
                   'data' => 'eval',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'line' => 269,
                   'has_warnings' => 0,
                   'data' => '-r -$op \\$ft'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 269,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'line' => 269,
                   'has_warnings' => 0,
                   'data' => '-r'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 269,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'stacked overloaded -$op',
                   'line' => 269,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 269
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 269,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 270,
                   'has_warnings' => 1,
                   'data' => 'is',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'line' => 270,
                   'has_warnings' => 0,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'data' => 'eval',
                   'line' => 270
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 270,
                   'has_warnings' => 0,
                   'data' => '-$op -r \\$ft',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 270,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '-$op',
                   'has_warnings' => 0,
                   'line' => 270
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 270
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 270,
                   'has_warnings' => 0,
                   'data' => 'overloaded stacked -$op',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 270,
                   'has_warnings' => 0,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 270
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 271,
                   'data' => '}',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'has_warnings' => 0,
                   'line' => 274,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 275,
                   'has_warnings' => 0,
                   'data' => 'push',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'my',
                   'has_warnings' => 0,
                   'line' => 275,
                   'name' => 'VarDecl',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LocalArrayVar,
                   'name' => 'LocalArrayVar',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 275,
                   'data' => '@foo',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 275,
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 275,
                   'data' => 'bar',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'line' => 275,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-l',
                   'has_warnings' => 0,
                   'line' => 275,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'baz',
                   'line' => 275,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 275,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'is',
                   'has_warnings' => 1,
                   'line' => 276,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 276,
                   'data' => '$foo',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_GlobalVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'GlobalVar',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 276,
                   'data' => '[',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftBracket',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '0',
                   'has_warnings' => 0,
                   'line' => 276,
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ']',
                   'line' => 276,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 276
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 276,
                   'data' => 'bar',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 276,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 276,
                   'has_warnings' => 0,
                   'data' => '-l bareword does not corrupt the stack',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 276,
                   'data' => ';',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 277,
                   'data' => '}',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 280,
                   'data' => 'stat',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'line' => 280,
                   'has_warnings' => 0,
                   'data' => 'test.pl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'line' => 280,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 281,
                   'has_warnings' => 0,
                   'data' => 'eval',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBrace',
                   'line' => 281,
                   'has_warnings' => 0,
                   'data' => '{'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'UseDecl',
                   'line' => 281,
                   'has_warnings' => 0,
                   'data' => 'use'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'warnings',
                   'line' => 281,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'name' => 'UsedName',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_UsedName
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'FATAL',
                   'has_warnings' => 0,
                   'line' => 281,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'Arrow',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'has_warnings' => 0,
                   'data' => '=>',
                   'line' => 281
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'io',
                   'line' => 281,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 281,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-l',
                   'has_warnings' => 0,
                   'line' => 281,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 281,
                   'data' => 'cradd',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace',
                   'line' => 281,
                   'has_warnings' => 0,
                   'data' => '}'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 281,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 282,
                   'data' => 'isnt',
                   'has_warnings' => 1,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 282,
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'data' => 'stat',
                   'has_warnings' => 0,
                   'line' => 282
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'Call',
                   'type' => Compiler::Lexer::TokenType::T_Call,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '_',
                   'line' => 282
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 282,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 282,
                   'data' => '1',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'line' => 282,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'fatal warnings do not prevent -l HANDLE from setting stat status',
                   'has_warnings' => 0,
                   'line' => 283,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 283
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 283,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'has_warnings' => 0,
                   'line' => 287
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 288,
                   'has_warnings' => 0,
                   'data' => 'my',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'LocalVar',
                   'line' => 288,
                   'has_warnings' => 0,
                   'data' => '$w'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 288
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 289,
                   'data' => 'sub',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'FunctionDecl',
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 289,
                   'has_warnings' => 0,
                   'data' => 'oon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'name' => 'Namespace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_NamespaceResolver,
                   'name' => 'NamespaceResolver',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 289,
                   'data' => '::',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Namespace',
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'line' => 289,
                   'data' => 'TIESCALAR',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'has_warnings' => 0,
                   'line' => 289,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 289,
                   'data' => 'bless',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '[',
                   'has_warnings' => 0,
                   'line' => 289,
                   'name' => 'LeftBracket',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ']',
                   'line' => 289,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 289
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 289,
                   'has_warnings' => 0,
                   'data' => 'oon',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'has_warnings' => 0,
                   'line' => 289,
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'FunctionDecl',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'sub',
                   'has_warnings' => 0,
                   'line' => 290
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 290,
                   'data' => 'oon',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'name' => 'Namespace',
                   'kind' => Compiler::Lexer::Kind::T_Namespace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '::',
                   'line' => 290,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'NamespaceResolver',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_NamespaceResolver
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 290,
                   'data' => 'FETCH',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Namespace',
                   'kind' => Compiler::Lexer::Kind::T_Namespace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'has_warnings' => 0,
                   'line' => 290,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 290,
                   'data' => '$w',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 290,
                   'data' => '++',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Inc,
                   'name' => 'Inc',
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 290,
                   'data' => '}',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 291,
                   'data' => 'tie',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'my',
                   'line' => 291,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'VarDecl',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 291,
                   'has_warnings' => 0,
                   'data' => '$t',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'LocalVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 291
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 291,
                   'data' => 'oon',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 291,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'line' => 292,
                   'has_warnings' => 0,
                   'data' => 'push'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 292,
                   'data' => 'my',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'VarDecl',
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '@a',
                   'has_warnings' => 0,
                   'line' => 292,
                   'name' => 'LocalArrayVar',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LocalArrayVar
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 292,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'line' => 292,
                   'has_warnings' => 0,
                   'data' => '$t'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 292,
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'data' => '-t',
                   'has_warnings' => 0,
                   'line' => 292
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 292,
                   'has_warnings' => 0,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'is',
                   'has_warnings' => 1,
                   'line' => 293
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '$w',
                   'line' => 293
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 293,
                   'data' => ',',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '1',
                   'has_warnings' => 0,
                   'line' => 293,
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 293
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'file test does not call FETCH on stack item not its own',
                   'has_warnings' => 0,
                   'line' => 293,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 293
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 294,
                   'data' => '}',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 298,
                   'has_warnings' => 0,
                   'data' => 'my',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'LocalVar',
                   'line' => 298,
                   'has_warnings' => 0,
                   'data' => '$Perl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'data' => '=',
                   'has_warnings' => 0,
                   'line' => 298
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'which_perl',
                   'has_warnings' => 1,
                   'line' => 298
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 298,
                   'data' => '(',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 298,
                   'data' => ')',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 298,
                   'has_warnings' => 0,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'SKIP',
                   'line' => 300,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ':',
                   'line' => 300,
                   'kind' => Compiler::Lexer::Kind::T_Colon,
                   'name' => 'Colon',
                   'type' => Compiler::Lexer::TokenType::T_Colon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 300,
                   'data' => '{',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'skip',
                   'line' => 301,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'data' => 'no -T on filehandles',
                   'line' => 301
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 301,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'data' => '8',
                   'has_warnings' => 0,
                   'line' => 301
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'name' => 'UnlessStmt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_UnlessStmt,
                   'has_warnings' => 0,
                   'data' => 'unless',
                   'line' => 301
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'line' => 301,
                   'has_warnings' => 0,
                   'data' => 'eval'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '{',
                   'line' => 301
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle',
                   'line' => 301,
                   'has_warnings' => 0,
                   'data' => '-T'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 301,
                   'data' => 'STDERR',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_STDERR,
                   'name' => 'STDERR',
                   'kind' => Compiler::Lexer::Kind::T_Handle
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 301,
                   'has_warnings' => 0,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '1',
                   'has_warnings' => 0,
                   'line' => 301,
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'has_warnings' => 0,
                   'line' => 301,
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 301,
                   'has_warnings' => 0,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-l',
                   'has_warnings' => 0,
                   'line' => 304,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'perl.c',
                   'has_warnings' => 0,
                   'line' => 304,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 304,
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-T',
                   'line' => 305,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle',
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'STDERR',
                   'line' => 305,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'STDERR',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_STDERR
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 305,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 306,
                   'data' => 'eval',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '{',
                   'line' => 306
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 306,
                   'data' => '-l',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'Call',
                   'type' => Compiler::Lexer::TokenType::T_Call,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '_',
                   'line' => 306
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '}',
                   'line' => 306,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 306,
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 307,
                   'data' => 'like',
                   'has_warnings' => 1,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SpecificValue',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'data' => '$@',
                   'has_warnings' => 0,
                   'line' => 307
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 307,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 307,
                   'data' => 'qr',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegDecl',
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegDelim',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '/',
                   'has_warnings' => 0,
                   'line' => 307
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegExp',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'has_warnings' => 0,
                   'data' => '^The stat preceding -l _ wasn\'t an lstat at ',
                   'line' => 307
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegDelim',
                   'line' => 307,
                   'has_warnings' => 0,
                   'data' => '/'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 307,
                   'data' => ',',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 308,
                   'has_warnings' => 0,
                   'data' => '-T HANDLE sets the stat type',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 308,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'data' => 'fresh_perl_is',
                   'line' => 312
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 312,
                   'has_warnings' => 0,
                   'data' => 'open my $fh, "test.pl"; -r $fh; undef $fh; open my $fh2, ',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'StringAdd',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_StringAdd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '.',
                   'has_warnings' => 0,
                   'line' => 313
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'line' => 313,
                   'has_warnings' => 0,
                   'data' => 'q\\0$Perl\\0; print -B _'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 313,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 314,
                   'has_warnings' => 0,
                   'data' => '',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 314,
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 315,
                   'data' => '{',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'switches',
                   'line' => 315,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 315,
                   'has_warnings' => 0,
                   'data' => '=>',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'Arrow'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBracket',
                   'line' => 315,
                   'has_warnings' => 0,
                   'data' => '['
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-l',
                   'has_warnings' => 0,
                   'line' => 315,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 315,
                   'has_warnings' => 0,
                   'data' => ']',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBracket'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'data' => '}',
                   'has_warnings' => 0,
                   'line' => 315
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 315
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'PL_statgv should not point to freed-and-reused SV',
                   'line' => 316,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'line' => 316,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 320,
                   'data' => 'fresh_perl_is',
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 320,
                   'data' => 'open Fh, "test.pl"; -r($h{i} = *Fh); $h{i} = 3; undef %h;',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '.',
                   'has_warnings' => 0,
                   'line' => 321,
                   'name' => 'StringAdd',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_StringAdd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => 'open my $fh2, ',
                   'has_warnings' => 0,
                   'line' => 321
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '.',
                   'line' => 321,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'StringAdd',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_StringAdd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 321,
                   'data' => 'q\\0',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_StringAdd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'StringAdd',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 321,
                   'data' => '.',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 321,
                   'data' => 'which_perl',
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 321
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 321,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 321,
                   'data' => '.',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_StringAdd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'StringAdd',
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '\\0; print -B _',
                   'has_warnings' => 0,
                   'line' => 321,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 321
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '',
                   'line' => 322,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 322,
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 323,
                   'data' => '{',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'line' => 323,
                   'has_warnings' => 0,
                   'data' => 'switches'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 323,
                   'data' => '=>',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Arrow',
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '[',
                   'line' => 323,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-l',
                   'has_warnings' => 0,
                   'line' => 323,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBracket',
                   'line' => 323,
                   'has_warnings' => 0,
                   'data' => ']'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '}',
                   'line' => 323,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 323
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 324,
                   'data' => 'PL_statgv should not point to coerced-freed-and-reused GV',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 324
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'open',
                   'has_warnings' => 0,
                   'line' => 327,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'my',
                   'has_warnings' => 0,
                   'line' => 327,
                   'name' => 'VarDecl',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 327,
                   'data' => '$fh',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 327,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'test.pl',
                   'line' => 327,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 327,
                   'data' => ';',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 328,
                   'has_warnings' => 0,
                   'data' => 'stat',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 328,
                   'data' => '$Perl',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 328,
                   'data' => ';',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'stat',
                   'has_warnings' => 0,
                   'line' => 329,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 329,
                   'data' => '*',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Mul,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Mul',
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$fh',
                   'line' => 329,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 329,
                   'data' => '{',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'IO',
                   'has_warnings' => 0,
                   'line' => 329
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'has_warnings' => 0,
                   'line' => 329,
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'line' => 329,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'is',
                   'line' => 330,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 330
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle',
                   'line' => 330,
                   'has_warnings' => 0,
                   'data' => '-T'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '_',
                   'line' => 330,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'Call',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Call
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'line' => 330,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '1',
                   'has_warnings' => 0,
                   'line' => 330,
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 330
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 330,
                   'has_warnings' => 0,
                   'data' => '-T _ works after stat $ioref',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 330,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 330,
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-r',
                   'has_warnings' => 0,
                   'line' => 333,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '*',
                   'line' => 333,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'Mul',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Mul
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$fh',
                   'has_warnings' => 0,
                   'line' => 333
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 333,
                   'data' => '{',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 333,
                   'data' => 'IO',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0,
                   'data' => '}',
                   'line' => 333
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 333,
                   'has_warnings' => 0,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'data' => 'is',
                   'line' => 334
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 334,
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'has_warnings' => 0,
                   'data' => '-T',
                   'line' => 334
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 334,
                   'data' => '_',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Call,
                   'name' => 'Call',
                   'kind' => Compiler::Lexer::Kind::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'line' => 334,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '1',
                   'has_warnings' => 0,
                   'line' => 334
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 334
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'data' => '-T _ works after -r $ioref',
                   'line' => 334
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 334
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 334,
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 337,
                   'data' => 'stat',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '$fh',
                   'line' => 337
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 337
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'close',
                   'has_warnings' => 0,
                   'line' => 338,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$fh',
                   'has_warnings' => 0,
                   'line' => 338,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 338,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-T',
                   'has_warnings' => 0,
                   'line' => 339,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '_',
                   'has_warnings' => 0,
                   'line' => 339,
                   'name' => 'Call',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Call
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 339,
                   'has_warnings' => 0,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'line' => 340,
                   'has_warnings' => 1,
                   'data' => 'isnt'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 340,
                   'has_warnings' => 0,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'data' => 'stat',
                   'has_warnings' => 0,
                   'line' => 340
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 340,
                   'has_warnings' => 0,
                   'data' => '_',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Call,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'Call'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 340
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '1',
                   'line' => 340
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'line' => 340,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => '-T _ on closed filehandle resets stat info',
                   'has_warnings' => 0,
                   'line' => 340
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 340,
                   'data' => ')',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 340,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 342,
                   'data' => 'lstat',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 342,
                   'data' => 'test.pl',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'line' => 342,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'data' => '-T',
                   'has_warnings' => 0,
                   'line' => 343
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 343,
                   'has_warnings' => 0,
                   'data' => '$fh',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 343,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'eval',
                   'line' => 344,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'has_warnings' => 0,
                   'line' => 344
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'lstat',
                   'line' => 344,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Call,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'Call',
                   'line' => 344,
                   'has_warnings' => 0,
                   'data' => '_'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 344,
                   'data' => '}',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 344,
                   'data' => ';',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'like',
                   'line' => 345,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SpecificValue',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 345,
                   'data' => '$@',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 345
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 345,
                   'has_warnings' => 0,
                   'data' => 'qr',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegDecl,
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'name' => 'RegDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '/',
                   'has_warnings' => 0,
                   'line' => 345,
                   'name' => 'RegDelim',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegExp',
                   'line' => 345,
                   'has_warnings' => 0,
                   'data' => '^The stat preceding lstat\\(\\) wasn\'t an lstat at '
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegDelim',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 345,
                   'data' => '/',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 345,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 346,
                   'data' => '-T on closed handle resets last stat type',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 346,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$!',
                   'line' => 349,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'SpecificValue',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '=',
                   'line' => 349,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '7',
                   'line' => 349,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 349
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '-T',
                   'has_warnings' => 0,
                   'line' => 350
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 350,
                   'data' => 'cradd',
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 350
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'VarDecl',
                   'line' => 351,
                   'has_warnings' => 0,
                   'data' => 'my'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 351,
                   'data' => '$errno',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LocalVar',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 351,
                   'data' => '=',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Assign',
                   'kind' => Compiler::Lexer::Kind::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$!',
                   'line' => 351,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'SpecificValue',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 351,
                   'data' => ';',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$!',
                   'line' => 352,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'SpecificValue',
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 352,
                   'data' => '=',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'kind' => Compiler::Lexer::Kind::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 352,
                   'data' => '7',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 352,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'data' => 'eval',
                   'line' => 353
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '{',
                   'line' => 353
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'UseDecl',
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'use',
                   'line' => 353
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 353,
                   'has_warnings' => 0,
                   'data' => 'warnings',
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'name' => 'UsedName'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'FATAL',
                   'has_warnings' => 0,
                   'line' => 353,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Arrow',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'data' => '=>',
                   'has_warnings' => 0,
                   'line' => 353
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 353,
                   'data' => 'unopened',
                   'has_warnings' => 1,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 353,
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'line' => 353,
                   'data' => '-T',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'data' => 'cradd',
                   'line' => 353
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '}',
                   'line' => 353,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 353,
                   'has_warnings' => 0,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'my',
                   'line' => 354,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'VarDecl',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LocalVar',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 354,
                   'data' => '$errno2',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '=',
                   'line' => 354,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'name' => 'Assign',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'SpecificValue',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'has_warnings' => 0,
                   'data' => '$!',
                   'line' => 354
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 354
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'is',
                   'has_warnings' => 1,
                   'line' => 355
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$errno2',
                   'has_warnings' => 0,
                   'line' => 355,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 355,
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '$errno',
                   'line' => 355
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 355
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'fatal warnings do not affect errno after -T BADHADNLE',
                   'line' => 356
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 356
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 357,
                   'data' => '}',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'is',
                   'has_warnings' => 1,
                   'line' => 359
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'line' => 359,
                   'has_warnings' => 1,
                   'data' => 'runperl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'line' => 359,
                   'has_warnings' => 0,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'prog',
                   'has_warnings' => 0,
                   'line' => 359
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 359,
                   'has_warnings' => 0,
                   'data' => '=>',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'Arrow'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 359,
                   'data' => '-T _',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 359,
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'switches',
                   'has_warnings' => 0,
                   'line' => 359,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'Arrow',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'has_warnings' => 0,
                   'data' => '=>',
                   'line' => 359
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 359,
                   'data' => '[',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '-w',
                   'has_warnings' => 0,
                   'line' => 359
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 359,
                   'data' => ']',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightBracket',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'line' => 359,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'stderr',
                   'has_warnings' => 0,
                   'line' => 359,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '=>',
                   'line' => 359,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '1',
                   'line' => 359,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 359,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'line' => 359,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '',
                   'line' => 359
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 359,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 360,
                   'has_warnings' => 0,
                   'data' => 'no uninit warnings from -T with no preceding stat',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 360,
                   'has_warnings' => 0,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'line' => 362,
                   'has_warnings' => 1,
                   'data' => 'SKIP'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 362,
                   'data' => ':',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Colon,
                   'name' => 'Colon',
                   'kind' => Compiler::Lexer::Kind::T_Colon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 362,
                   'data' => '{',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'VarDecl',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'has_warnings' => 0,
                   'line' => 363
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LocalVar',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 363,
                   'data' => '$rand_file_name',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 363,
                   'data' => '=',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Assign',
                   'kind' => Compiler::Lexer::Kind::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 363,
                   'data' => 'filetest-',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_StringAdd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'StringAdd',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 363,
                   'data' => '.',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'data' => 'rand',
                   'has_warnings' => 0,
                   'line' => 363
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '=~',
                   'line' => 363,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'RegOK',
                   'type' => Compiler::Lexer::TokenType::T_RegOK,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegAllReplace',
                   'kind' => Compiler::Lexer::Kind::T_RegReplacePrefix,
                   'type' => Compiler::Lexer::TokenType::T_RegAllReplace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'y',
                   'has_warnings' => 0,
                   'line' => 363
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 363,
                   'data' => '/',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegReplaceFrom,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegReplaceFrom',
                   'line' => 363,
                   'has_warnings' => 0,
                   'data' => '.'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '/',
                   'has_warnings' => 0,
                   'line' => 363,
                   'name' => 'RegMiddleDelim',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegMiddleDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegReplaceTo,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegReplaceTo',
                   'line' => 363,
                   'has_warnings' => 0,
                   'data' => ''
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 363,
                   'has_warnings' => 0,
                   'data' => '/',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegDelim'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'dr',
                   'line' => 363,
                   'kind' => Compiler::Lexer::Kind::T_RegOpt,
                   'name' => 'RegOpt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegOpt
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 363,
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'IfStmt',
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'line' => 364,
                   'data' => 'if',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'has_warnings' => 0,
                   'line' => 364
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-e',
                   'has_warnings' => 0,
                   'line' => 364,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$rand_file_name',
                   'line' => 364,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 364,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 364,
                   'data' => '{',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'skip',
                   'has_warnings' => 1,
                   'line' => 364
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'line' => 364,
                   'has_warnings' => 0,
                   'data' => 'File $rand_file_name exists'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'line' => 364,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 364,
                   'data' => '1',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'has_warnings' => 0,
                   'line' => 364,
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'stat',
                   'line' => 365,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 365,
                   'data' => 'test.pl',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 365,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 366,
                   'has_warnings' => 0,
                   'data' => '-T',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 366,
                   'data' => '$rand_file_name',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 366
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'isnt',
                   'has_warnings' => 1,
                   'line' => 367
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 367,
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'line' => 367,
                   'has_warnings' => 0,
                   'data' => 'stat'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 367,
                   'has_warnings' => 0,
                   'data' => '_',
                   'type' => Compiler::Lexer::TokenType::T_Call,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'Call'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 367
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'data' => '1',
                   'has_warnings' => 0,
                   'line' => 367
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 367,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-T "nonexistent" resets stat success status',
                   'has_warnings' => 0,
                   'line' => 367,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 367,
                   'has_warnings' => 0,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 367
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace',
                   'line' => 368,
                   'has_warnings' => 0,
                   'data' => '}'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '{',
                   'line' => 372,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'stat',
                   'has_warnings' => 0,
                   'line' => 373,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'test.pl',
                   'has_warnings' => 0,
                   'line' => 373
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 373
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-r',
                   'line' => 375,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 375,
                   'data' => '*phlon',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Mul,
                   'name' => 'Mul',
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 375,
                   'has_warnings' => 0,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 376,
                   'has_warnings' => 0,
                   'data' => 'my',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LocalVar',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 376,
                   'data' => '$failed_stat1',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 376,
                   'has_warnings' => 0,
                   'data' => '=',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'stat',
                   'line' => 376
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '_',
                   'line' => 376,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'Call',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Call
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 376,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 378,
                   'data' => 'stat',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'test.pl',
                   'line' => 378,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 378
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'data' => 'eval',
                   'line' => 379
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'has_warnings' => 0,
                   'line' => 379,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'UseDecl',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'data' => 'use',
                   'has_warnings' => 0,
                   'line' => 379
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'name' => 'UsedName',
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'line' => 379,
                   'data' => 'warnings',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 379,
                   'data' => 'FATAL',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '=>',
                   'line' => 379,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'unopened',
                   'has_warnings' => 1,
                   'line' => 379,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 379,
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-r',
                   'has_warnings' => 0,
                   'line' => 379,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Mul,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Mul',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 379,
                   'data' => '*phlon',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 379,
                   'data' => '}',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'line' => 379,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'my',
                   'line' => 380,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 380,
                   'has_warnings' => 0,
                   'data' => '$failed_stat2',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'LocalVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'data' => '=',
                   'has_warnings' => 0,
                   'line' => 380
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'stat',
                   'has_warnings' => 0,
                   'line' => 380
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Call,
                   'name' => 'Call',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 380,
                   'data' => '_',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'line' => 380,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'line' => 382,
                   'has_warnings' => 1,
                   'data' => 'is'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 382,
                   'has_warnings' => 0,
                   'data' => '$failed_stat2',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 382
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$failed_stat1',
                   'line' => 382,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 382,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 383,
                   'data' => 'failed -r($gv_without_io) with and w/out fatal warnings',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 383,
                   'data' => ';',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'stat',
                   'has_warnings' => 0,
                   'line' => 385,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 385,
                   'data' => 'test.pl',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'line' => 385,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'name' => 'Handle',
                   'line' => 386,
                   'has_warnings' => 0,
                   'data' => '-r'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'cength',
                   'line' => 386,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 386,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$failed_stat1',
                   'line' => 387,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '=',
                   'line' => 387
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'data' => 'stat',
                   'has_warnings' => 0,
                   'line' => 387
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Call',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Call,
                   'data' => '_',
                   'has_warnings' => 0,
                   'line' => 387
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 387
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'stat',
                   'line' => 389,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'test.pl',
                   'line' => 389,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 389,
                   'has_warnings' => 0,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'eval',
                   'line' => 390,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 390,
                   'data' => '{',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'UseDecl',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 390,
                   'data' => 'use',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'name' => 'UsedName',
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'line' => 390,
                   'data' => 'warnings',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 390,
                   'has_warnings' => 0,
                   'data' => 'FATAL',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Arrow',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 390,
                   'data' => '=>',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'unopened',
                   'line' => 390,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 390
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '-r',
                   'has_warnings' => 0,
                   'line' => 390
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'cength',
                   'has_warnings' => 1,
                   'line' => 390
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBrace',
                   'line' => 390,
                   'has_warnings' => 0,
                   'data' => '}'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 390,
                   'has_warnings' => 0,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$failed_stat2',
                   'line' => 391,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'name' => 'Assign',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0,
                   'data' => '=',
                   'line' => 391
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'data' => 'stat',
                   'has_warnings' => 0,
                   'line' => 391
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '_',
                   'line' => 391,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'Call',
                   'type' => Compiler::Lexer::TokenType::T_Call,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 391
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'line' => 393,
                   'has_warnings' => 1,
                   'data' => 'is'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$failed_stat2',
                   'has_warnings' => 0,
                   'line' => 393
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 393,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 393,
                   'data' => '$failed_stat1',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 393
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'failed -r($gv_with_io_but_no_fp) with and w/out fatal warnings',
                   'has_warnings' => 0,
                   'line' => 394
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 394,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 395,
                   'data' => '}',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
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
            'end_line' => 7,
            'start_line' => 7,
            'src' => ' chdir \'t\' if -d \'t\' ;',
            'indent' => 1,
            'has_warnings' => 0,
            'block_id' => 1,
            'token_num' => 6
          },
          {
            'end_line' => 8,
            'start_line' => 8,
            'src' => ' require \'./test.pl\' ;',
            'indent' => 1,
            'block_id' => 1,
            'has_warnings' => 0,
            'token_num' => 3
          },
          {
            'indent' => 1,
            'src' => ' set_up_inc ( qw \'../lib ../cpan/Perl-OSType/lib\' ) ;',
            'end_line' => 9,
            'start_line' => 9,
            'token_num' => 6,
            'has_warnings' => 1,
            'block_id' => 1
          },
          {
            'indent' => 0,
            'src' => ' plan ( tests => 53 + 27 * 14 ) ;',
            'start_line' => 12,
            'end_line' => 12,
            'token_num' => 11,
            'has_warnings' => 1,
            'block_id' => 0
          },
          {
            'start_line' => 14,
            'end_line' => 16,
            'indent' => 0,
            'src' => ' if ( $^O =~/MSWin32|cygwin|msys/ && ! is_miniperl ) { require Win32 ; }',
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 16
          },
          {
            'token_num' => 3,
            'has_warnings' => 0,
            'block_id' => 2,
            'src' => ' require Win32 ;',
            'indent' => 1,
            'start_line' => 15,
            'end_line' => 15
          },
          {
            'indent' => 0,
            'src' => ' is ( -d \'op\' , 1 , "-d: directory correctly identified" ) ;',
            'start_line' => 20,
            'end_line' => 20,
            'token_num' => 10,
            'block_id' => 0,
            'has_warnings' => 1
          },
          {
            'src' => ' is ( -f \'TEST\' , 1 , "-f: plain file correctly identified" ) ;',
            'indent' => 0,
            'start_line' => 21,
            'end_line' => 21,
            'token_num' => 10,
            'has_warnings' => 1,
            'block_id' => 0
          },
          {
            'src' => ' isnt ( -f \'op\' , 1 , "-f: directory is not a plain file" ) ;',
            'indent' => 0,
            'start_line' => 22,
            'end_line' => 22,
            'token_num' => 10,
            'has_warnings' => 1,
            'block_id' => 0
          },
          {
            'start_line' => 23,
            'end_line' => 23,
            'src' => ' isnt ( -d \'TEST\' , 1 , "-d: plain file is not a directory" ) ;',
            'indent' => 0,
            'block_id' => 0,
            'has_warnings' => 1,
            'token_num' => 10
          },
          {
            'indent' => 0,
            'src' => ' is ( -r \'TEST\' , 1 , "-r: file readable by effective uid/gid not found" ) ;',
            'start_line' => 24,
            'end_line' => 24,
            'token_num' => 10,
            'has_warnings' => 1,
            'block_id' => 0
          },
          {
            'start_line' => 27,
            'end_line' => 27,
            'indent' => 0,
            'src' => ' my $ro_empty_file = tempfile ( ) ;',
            'block_id' => 0,
            'has_warnings' => 1,
            'token_num' => 7
          },
          {
            'token_num' => 19,
            'block_id' => 0,
            'has_warnings' => 1,
            'src' => ' { open my $fh , \'>\' , $ro_empty_file or die "open $fh: $!" ; close $fh or die "close $fh: $!" ; }',
            'indent' => 0,
            'end_line' => 32,
            'start_line' => 29
          },
          {
            'end_line' => 30,
            'start_line' => 30,
            'src' => ' open my $fh , \'>\' , $ro_empty_file or die "open $fh: $!" ;',
            'indent' => 1,
            'has_warnings' => 1,
            'block_id' => 3,
            'token_num' => 11
          },
          {
            'end_line' => 31,
            'start_line' => 31,
            'indent' => 1,
            'src' => ' close $fh or die "close $fh: $!" ;',
            'has_warnings' => 1,
            'block_id' => 3,
            'token_num' => 6
          },
          {
            'src' => ' chmod 0555 , $ro_empty_file or die "chmod 0555, \'$ro_empty_file\' failed: $!" ;',
            'indent' => 0,
            'start_line' => 34,
            'end_line' => 34,
            'token_num' => 8,
            'block_id' => 0,
            'has_warnings' => 1
          },
          {
            'indent' => 1,
            'src' => ' my $restore_root ;',
            'start_line' => 37,
            'end_line' => 37,
            'token_num' => 3,
            'block_id' => 4,
            'has_warnings' => 0
          },
          {
            'token_num' => 15,
            'block_id' => 4,
            'has_warnings' => 1,
            'src' => ' skip "Need Win32::IsAdminUser() on $^O" , 1 if $^O =~/MSWin32|cygwin|msys/ && is_miniperl ( ) ;',
            'indent' => 1,
            'start_line' => 38,
            'end_line' => 39
          },
          {
            'block_id' => 4,
            'has_warnings' => 1,
            'token_num' => 19,
            'end_line' => 40,
            'start_line' => 40,
            'indent' => 1,
            'src' => ' my $Is_WinAdminUser = ( $^O =~/MSWin32|cygwin|msys/ and Win32::IsAdminUser ( ) ) ? 1 : 0 ;'
          },
          {
            'start_line' => 43,
            'end_line' => 45,
            'src' => ' if ( $Is_WinAdminUser ) { skip ( "As Windows Administrator we cannot rely on -w via uid/gid" ) ; }',
            'indent' => 1,
            'has_warnings' => 1,
            'block_id' => 4,
            'token_num' => 11
          },
          {
            'has_warnings' => 1,
            'block_id' => 5,
            'token_num' => 5,
            'end_line' => 44,
            'start_line' => 44,
            'indent' => 2,
            'src' => ' skip ( "As Windows Administrator we cannot rely on -w via uid/gid" ) ;'
          },
          {
            'end_line' => 54,
            'start_line' => 46,
            'src' => ' elsif ( $> == 0 ) { eval \'$> = 1\' ; skip ( "Can\'t drop root privs to test read-only files" ) if $> == 0 ; note ( "Dropped root privs to test read-only files. \\$> == $>" ) ; ++ $restore_root ; }',
            'indent' => 1,
            'block_id' => 4,
            'has_warnings' => 1,
            'token_num' => 28
          },
          {
            'end_line' => 49,
            'start_line' => 49,
            'indent' => 2,
            'src' => ' eval \'$> = 1\' ;',
            'has_warnings' => 0,
            'block_id' => 6,
            'token_num' => 3
          },
          {
            'start_line' => 51,
            'end_line' => 51,
            'indent' => 2,
            'src' => ' skip ( "Can\'t drop root privs to test read-only files" ) if $> == 0 ;',
            'has_warnings' => 1,
            'block_id' => 6,
            'token_num' => 9
          },
          {
            'block_id' => 6,
            'has_warnings' => 1,
            'token_num' => 5,
            'end_line' => 52,
            'start_line' => 52,
            'src' => ' note ( "Dropped root privs to test read-only files. \\$> == $>" ) ;',
            'indent' => 2
          },
          {
            'end_line' => 53,
            'start_line' => 53,
            'indent' => 2,
            'src' => ' ++ $restore_root ;',
            'block_id' => 6,
            'has_warnings' => 1,
            'token_num' => 3
          },
          {
            'token_num' => 10,
            'block_id' => 4,
            'has_warnings' => 1,
            'src' => ' isnt ( -w $ro_empty_file , 1 , "-w: file writable by effective uid/gid" ) ;',
            'indent' => 1,
            'end_line' => 56,
            'start_line' => 56
          },
          {
            'token_num' => 15,
            'has_warnings' => 1,
            'block_id' => 4,
            'indent' => 1,
            'src' => ' if ( $restore_root ) { $> = 0 ; note ( "Restored root privs after testing read-only files. \\$> == $>" ) ; }',
            'end_line' => 62,
            'start_line' => 58
          },
          {
            'indent' => 2,
            'src' => ' $> = 0 ;',
            'end_line' => 60,
            'start_line' => 60,
            'token_num' => 4,
            'has_warnings' => 0,
            'block_id' => 7
          },
          {
            'end_line' => 61,
            'start_line' => 61,
            'indent' => 2,
            'src' => ' note ( "Restored root privs after testing read-only files. \\$> == $>" ) ;',
            'block_id' => 7,
            'has_warnings' => 1,
            'token_num' => 5
          },
          {
            'start_line' => 67,
            'end_line' => 67,
            'src' => ' is ( -r \'op\' , 1 , "-r: directory readable by effective uid/gid" ) ;',
            'indent' => 0,
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 10
          },
          {
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 10,
            'end_line' => 68,
            'start_line' => 68,
            'indent' => 0,
            'src' => ' is ( -w \'op\' , 1 , "-w: directory writable by effective uid/gid" ) ;'
          },
          {
            'end_line' => 69,
            'start_line' => 69,
            'src' => ' is ( -x \'op\' , 1 , "-x: executable by effective uid/gid" ) ;',
            'indent' => 0,
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 10
          },
          {
            'block_id' => 0,
            'has_warnings' => 1,
            'token_num' => 9,
            'end_line' => 72,
            'start_line' => 71,
            'src' => ' is ( "@{[grep -r, qw(foo io noo op zoo)]}" , "io op" , "-r: found directories readable by effective uid/gid" ) ;',
            'indent' => 0
          },
          {
            'end_line' => 76,
            'start_line' => 76,
            'indent' => 0,
            'src' => ' is ( defined ( -f -d \'TEST\' ) , 1 , "-f and -d stackable: plain file found" ) ;',
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 14
          },
          {
            'start_line' => 77,
            'end_line' => 77,
            'indent' => 0,
            'src' => ' isnt ( -f -d _ , 1 , "-f and -d stackable: no plain file found" ) ;',
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 11
          },
          {
            'indent' => 0,
            'src' => ' isnt ( defined ( -e \'zoo\' ) , 1 , "-e: file does not exist" ) ;',
            'end_line' => 78,
            'start_line' => 78,
            'token_num' => 13,
            'has_warnings' => 1,
            'block_id' => 0
          },
          {
            'token_num' => 14,
            'has_warnings' => 1,
            'block_id' => 0,
            'src' => ' isnt ( defined ( -e -d \'zoo\' ) , 1 , "-e and -d: neither file nor directory exists" ) ;',
            'indent' => 0,
            'start_line' => 79,
            'end_line' => 79
          },
          {
            'block_id' => 0,
            'has_warnings' => 1,
            'token_num' => 14,
            'end_line' => 80,
            'start_line' => 80,
            'indent' => 0,
            'src' => ' isnt ( defined ( -f -e \'zoo\' ) , 1 , "-f and -e: not a plain file and does not exist" ) ;'
          },
          {
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 11,
            'end_line' => 81,
            'start_line' => 81,
            'src' => ' is ( -f -e \'TEST\' , 1 , "-f and -e: plain file and exists" ) ;',
            'indent' => 0
          },
          {
            'start_line' => 82,
            'end_line' => 82,
            'src' => ' is ( -e -f \'TEST\' , 1 , "-e and -f: exists and is plain file" ) ;',
            'indent' => 0,
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 11
          },
          {
            'src' => ' is ( defined ( -d -e \'TEST\' ) , 1 , "-d and -e: file at least exists" ) ;',
            'indent' => 0,
            'end_line' => 83,
            'start_line' => 83,
            'token_num' => 14,
            'block_id' => 0,
            'has_warnings' => 1
          },
          {
            'start_line' => 84,
            'end_line' => 84,
            'indent' => 0,
            'src' => ' is ( defined ( -e -d \'TEST\' ) , 1 , "-e and -d: file at least exists" ) ;',
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 14
          },
          {
            'indent' => 0,
            'src' => ' isnt ( -f -d \'op\' , 1 , "-f and -d: directory found but is not a plain file" ) ;',
            'start_line' => 85,
            'end_line' => 85,
            'token_num' => 11,
            'block_id' => 0,
            'has_warnings' => 1
          },
          {
            'src' => ' is ( -x -d -x \'op\' , 1 , "-x, -d and -x again: directory exists and is executable" ) ;',
            'indent' => 0,
            'end_line' => 86,
            'start_line' => 86,
            'token_num' => 12,
            'block_id' => 0,
            'has_warnings' => 1
          },
          {
            'token_num' => 13,
            'has_warnings' => 1,
            'block_id' => 0,
            'src' => ' my ( $size ) = ( stat \'TEST\' ) [ 7 ] ;',
            'indent' => 0,
            'end_line' => 87,
            'start_line' => 87
          },
          {
            'indent' => 0,
            'src' => ' cmp_ok ( $size , \'>\' , 1 , \'TEST is longer than 1 byte\' ) ;',
            'start_line' => 88,
            'end_line' => 88,
            'token_num' => 11,
            'has_warnings' => 1,
            'block_id' => 0
          },
          {
            'block_id' => 0,
            'has_warnings' => 1,
            'token_num' => 13,
            'start_line' => 89,
            'end_line' => 89,
            'src' => ' is ( ( -s -f \'TEST\' ) , $size , "-s returns real size" ) ;',
            'indent' => 0
          },
          {
            'indent' => 0,
            'src' => ' is ( -f -s \'TEST\' , 1 , "-f and -s: plain file with non-zero size" ) ;',
            'end_line' => 90,
            'start_line' => 90,
            'token_num' => 11,
            'block_id' => 0,
            'has_warnings' => 1
          },
          {
            'token_num' => 10,
            'block_id' => 0,
            'has_warnings' => 1,
            'src' => ' is ( -f $ro_empty_file , 1 , "-f: plain file found" ) ;',
            'indent' => 0,
            'start_line' => 93,
            'end_line' => 93
          },
          {
            'indent' => 0,
            'src' => ' is ( -s $ro_empty_file , 0 , "-s: file has 0 bytes" ) ;',
            'end_line' => 94,
            'start_line' => 94,
            'token_num' => 10,
            'block_id' => 0,
            'has_warnings' => 1
          },
          {
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 11,
            'start_line' => 95,
            'end_line' => 95,
            'src' => ' is ( -f -s $ro_empty_file , 0 , "-f and -s: plain file with 0 bytes" ) ;',
            'indent' => 0
          },
          {
            'indent' => 0,
            'src' => ' is ( -s -f $ro_empty_file , 0 , "-s and -f: file with 0 bytes is plain file" ) ;',
            'end_line' => 96,
            'start_line' => 96,
            'token_num' => 11,
            'has_warnings' => 1,
            'block_id' => 0
          },
          {
            'block_id' => 0,
            'has_warnings' => 0,
            'token_num' => 7,
            'end_line' => 99,
            'start_line' => 99,
            'src' => ' eval { -l -e "TEST" } ;',
            'indent' => 0
          },
          {
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 10,
            'end_line' => 101,
            'start_line' => 100,
            'indent' => 0,
            'src' => ' like $@ , qr/^The stat preceding -l _ wasn\'t an lstat at / , \'stacked -l non-lstat error with warnings off\' ;'
          },
          {
            'indent' => 0,
            'src' => ' { local $^W = 1 ; eval { -l -e "TEST" } ; like $@ , qr/^The stat preceding -l _ wasn\'t an lstat at / , \'stacked -l non-lstat error with warnings on\' ; }',
            'end_line' => 107,
            'start_line' => 102,
            'token_num' => 24,
            'has_warnings' => 1,
            'block_id' => 0
          },
          {
            'start_line' => 103,
            'end_line' => 103,
            'src' => ' local $^W = 1 ;',
            'indent' => 1,
            'block_id' => 8,
            'has_warnings' => 0,
            'token_num' => 5
          },
          {
            'end_line' => 104,
            'start_line' => 104,
            'indent' => 1,
            'src' => ' eval { -l -e "TEST" } ;',
            'block_id' => 8,
            'has_warnings' => 0,
            'token_num' => 7
          },
          {
            'start_line' => 105,
            'end_line' => 106,
            'src' => ' like $@ , qr/^The stat preceding -l _ wasn\'t an lstat at / , \'stacked -l non-lstat error with warnings on\' ;',
            'indent' => 1,
            'block_id' => 8,
            'has_warnings' => 1,
            'token_num' => 10
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'block_id' => 9,
            'indent' => 1,
            'src' => ' use Perl::OSType \'os_type\' ;',
            'end_line' => 112,
            'start_line' => 112
          },
          {
            'token_num' => 12,
            'has_warnings' => 1,
            'block_id' => 9,
            'indent' => 1,
            'src' => ' if ( os_type ne \'Unix\' ) { skip "Not Unix" , 3 }',
            'start_line' => 113,
            'end_line' => 113
          },
          {
            'token_num' => 14,
            'block_id' => 9,
            'has_warnings' => 1,
            'indent' => 1,
            'src' => ' if ( $^O =~/android/ ) { $ln = "ln" ; }',
            'start_line' => 114,
            'end_line' => 118
          },
          {
            'src' => ' $ln = "ln" ;',
            'indent' => 2,
            'end_line' => 117,
            'start_line' => 117,
            'token_num' => 4,
            'has_warnings' => 1,
            'block_id' => 11
          },
          {
            'indent' => 1,
            'src' => ' else { chomp ( my $ln = `which ln` ) ; if ( ! -e $ln ) { skip "No ln" , 3 } }',
            'end_line' => 122,
            'start_line' => 119,
            'token_num' => 23,
            'has_warnings' => 1,
            'block_id' => 9
          },
          {
            'has_warnings' => 0,
            'block_id' => 12,
            'token_num' => 8,
            'end_line' => 120,
            'start_line' => 120,
            'src' => ' chomp ( my $ln = `which ln` ) ;',
            'indent' => 2
          },
          {
            'block_id' => 12,
            'has_warnings' => 1,
            'token_num' => 12,
            'start_line' => 121,
            'end_line' => 121,
            'src' => ' if ( ! -e $ln ) { skip "No ln" , 3 }',
            'indent' => 2
          },
          {
            'has_warnings' => 1,
            'block_id' => 9,
            'token_num' => 3,
            'start_line' => 123,
            'end_line' => 123,
            'indent' => 1,
            'src' => ' lstat $ro_empty_file ;'
          },
          {
            'has_warnings' => 0,
            'block_id' => 9,
            'token_num' => 2,
            'end_line' => 124,
            'start_line' => 124,
            'indent' => 1,
            'src' => ' `ln -s $ro_empty_file 1` ;'
          },
          {
            'has_warnings' => 1,
            'block_id' => 9,
            'token_num' => 11,
            'end_line' => 125,
            'start_line' => 125,
            'indent' => 1,
            'src' => ' isnt ( -l -e _ , 1 , \'stacked -l uses previous stat, not previous retval\' ) ;'
          },
          {
            'src' => ' unlink 1 ;',
            'indent' => 1,
            'start_line' => 126,
            'end_line' => 126,
            'token_num' => 3,
            'has_warnings' => 0,
            'block_id' => 9
          },
          {
            'block_id' => 9,
            'has_warnings' => 1,
            'token_num' => 10,
            'end_line' => 131,
            'start_line' => 131,
            'indent' => 1,
            'src' => ' system \'ln\' , \'-s\' , $ro_empty_file , \\ *foo ;'
          },
          {
            'token_num' => 5,
            'has_warnings' => 0,
            'block_id' => 9,
            'src' => ' local $^W = 1 ;',
            'indent' => 1,
            'start_line' => 132,
            'end_line' => 132
          },
          {
            'src' => ' my @warnings ;',
            'indent' => 1,
            'start_line' => 133,
            'end_line' => 133,
            'token_num' => 3,
            'has_warnings' => 0,
            'block_id' => 9
          },
          {
            'src' => ' local $SIG { __WARN__ } = sub { push @warnings , @_ } ;',
            'indent' => 1,
            'start_line' => 134,
            'end_line' => 134,
            'token_num' => 14,
            'block_id' => 9,
            'has_warnings' => 1
          },
          {
            'start_line' => 134,
            'end_line' => 134,
            'indent' => 1,
            'src' => ' sub { push @warnings , @_ }',
            'has_warnings' => 0,
            'block_id' => 13,
            'token_num' => 7
          },
          {
            'start_line' => 135,
            'end_line' => 135,
            'indent' => 1,
            'src' => ' is ( -l \\ *foo , 1 , \'-l \\*foo is a file name\' ) ;',
            'block_id' => 9,
            'has_warnings' => 1,
            'token_num' => 11
          },
          {
            'token_num' => 14,
            'block_id' => 9,
            'has_warnings' => 1,
            'src' => ' ok ( $warnings [ 0 ] =~/-l on filehandle foo/ , \'warning for -l $handle\' ) ;',
            'indent' => 1,
            'end_line' => 136,
            'start_line' => 136
          },
          {
            'has_warnings' => 0,
            'block_id' => 9,
            'token_num' => 4,
            'end_line' => 137,
            'start_line' => 137,
            'src' => ' unlink \\ *foo ;',
            'indent' => 1
          },
          {
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 97,
            'start_line' => 140,
            'end_line' => 155,
            'indent' => 0,
            'src' => ' { local $^W = 1 ; my @warnings ; local $SIG { __WARN__ } = sub { push @warnings , @_ } ; ( ) = -l \\ * { "\\x{3c6}oo" } ; like ( $warnings [ 0 ] , qr/-l on filehandle \\x{3c6}oo/ , \'-l $handle warning is utf8-clean\' ) ; ( ) = -l *foo ; like ( $warnings [ 1 ] , qr/-l on filehandle foo/ , \'-l $handle warning occurs for globs, not just globrefs\' ) ; tell foo ; ( ) = -l *foo { IO } ; like ( $warnings [ 3 ] , qr/-l on filehandle at/ , \'-l $handle warning occurs for iorefs as well\' ) ; }'
          },
          {
            'end_line' => 141,
            'start_line' => 141,
            'src' => ' local $^W = 1 ;',
            'indent' => 1,
            'block_id' => 15,
            'has_warnings' => 0,
            'token_num' => 5
          },
          {
            'end_line' => 142,
            'start_line' => 142,
            'indent' => 1,
            'src' => ' my @warnings ;',
            'block_id' => 15,
            'has_warnings' => 0,
            'token_num' => 3
          },
          {
            'token_num' => 14,
            'block_id' => 15,
            'has_warnings' => 1,
            'src' => ' local $SIG { __WARN__ } = sub { push @warnings , @_ } ;',
            'indent' => 1,
            'start_line' => 143,
            'end_line' => 143
          },
          {
            'start_line' => 143,
            'end_line' => 143,
            'indent' => 1,
            'src' => ' sub { push @warnings , @_ }',
            'block_id' => 15,
            'has_warnings' => 0,
            'token_num' => 7
          },
          {
            'src' => ' ( ) = -l \\ * { "\\x{3c6}oo" } ;',
            'indent' => 1,
            'start_line' => 144,
            'end_line' => 144,
            'token_num' => 10,
            'has_warnings' => 0,
            'block_id' => 15
          },
          {
            'token_num' => 15,
            'has_warnings' => 1,
            'block_id' => 15,
            'indent' => 1,
            'src' => ' like ( $warnings [ 0 ] , qr/-l on filehandle \\x{3c6}oo/ , \'-l $handle warning is utf8-clean\' ) ;',
            'start_line' => 145,
            'end_line' => 146
          },
          {
            'token_num' => 6,
            'block_id' => 15,
            'has_warnings' => 0,
            'src' => ' ( ) = -l *foo ;',
            'indent' => 1,
            'end_line' => 147,
            'start_line' => 147
          },
          {
            'indent' => 1,
            'src' => ' like ( $warnings [ 1 ] , qr/-l on filehandle foo/ , \'-l $handle warning occurs for globs, not just globrefs\' ) ;',
            'end_line' => 149,
            'start_line' => 148,
            'token_num' => 15,
            'has_warnings' => 1,
            'block_id' => 15
          },
          {
            'has_warnings' => 1,
            'block_id' => 15,
            'token_num' => 3,
            'end_line' => 150,
            'start_line' => 150,
            'indent' => 1,
            'src' => ' tell foo ;'
          },
          {
            'src' => ' ( ) = -l *foo { IO } ;',
            'indent' => 1,
            'end_line' => 151,
            'start_line' => 151,
            'token_num' => 9,
            'block_id' => 15,
            'has_warnings' => 0
          },
          {
            'end_line' => 154,
            'start_line' => 153,
            'indent' => 1,
            'src' => ' like ( $warnings [ 3 ] , qr/-l on filehandle at/ , \'-l $handle warning occurs for iorefs as well\' ) ;',
            'block_id' => 15,
            'has_warnings' => 1,
            'token_num' => 15
          },
          {
            'token_num' => 3,
            'block_id' => 0,
            'has_warnings' => 0,
            'src' => ' -f \'TEST\' ;',
            'indent' => 0,
            'end_line' => 159,
            'start_line' => 159
          },
          {
            'end_line' => 160,
            'start_line' => 160,
            'indent' => 0,
            'src' => ' is ( -f _ , 1 , "_ is bareword after filetest operator" ) ;',
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 10
          },
          {
            'token_num' => 5,
            'has_warnings' => 0,
            'block_id' => 0,
            'indent' => 0,
            'src' => ' sub _ { "this is not a file name" }',
            'end_line' => 161,
            'start_line' => 161
          },
          {
            'indent' => 0,
            'src' => ' is ( -f _ , 1 , "_ is bareword after filetest operator" ) ;',
            'end_line' => 162,
            'start_line' => 162,
            'token_num' => 10,
            'block_id' => 0,
            'has_warnings' => 1
          },
          {
            'token_num' => 3,
            'has_warnings' => 0,
            'block_id' => 0,
            'src' => ' my $over ;',
            'indent' => 0,
            'end_line' => 164,
            'start_line' => 164
          },
          {
            'end_line' => 174,
            'start_line' => 165,
            'indent' => 0,
            'src' => ' { package OverFtest ; use overload fallback => 1 , -X => sub { $over = [ qq($_[0]) , $_ [ 1 ] ] ; "-$_[1]" ; } ; }',
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 33
          },
          {
            'src' => ' package OverFtest ;',
            'indent' => 1,
            'start_line' => 166,
            'end_line' => 166,
            'token_num' => 3,
            'has_warnings' => 1,
            'block_id' => 18
          },
          {
            'src' => ' use overload fallback => 1 , -X => sub { $over = [ qq($_[0]) , $_ [ 1 ] ] ; "-$_[1]" ; } ;',
            'indent' => 1,
            'start_line' => 168,
            'end_line' => 173,
            'token_num' => 28,
            'block_id' => 18,
            'has_warnings' => 1
          },
          {
            'start_line' => 170,
            'end_line' => 173,
            'indent' => 1,
            'src' => ' sub { $over = [ qq($_[0]) , $_ [ 1 ] ] ; "-$_[1]" ; }',
            'has_warnings' => 1,
            'block_id' => 18,
            'token_num' => 19
          },
          {
            'has_warnings' => 1,
            'block_id' => 19,
            'token_num' => 14,
            'end_line' => 171,
            'start_line' => 171,
            'indent' => 2,
            'src' => ' $over = [ qq($_[0]) , $_ [ 1 ] ] ;'
          },
          {
            'has_warnings' => 0,
            'block_id' => 19,
            'token_num' => 2,
            'start_line' => 172,
            'end_line' => 172,
            'indent' => 2,
            'src' => ' "-$_[1]" ;'
          },
          {
            'src' => ' { package OverString ; use overload q/""/ => sub { $over = 1 ; "TEST" } ; }',
            'indent' => 0,
            'end_line' => 181,
            'start_line' => 175,
            'token_num' => 21,
            'has_warnings' => 1,
            'block_id' => 0
          },
          {
            'token_num' => 3,
            'block_id' => 20,
            'has_warnings' => 1,
            'indent' => 1,
            'src' => ' package OverString ;',
            'start_line' => 176,
            'end_line' => 176
          },
          {
            'src' => ' use overload q/""/ => sub { $over = 1 ; "TEST" } ;',
            'indent' => 1,
            'end_line' => 180,
            'start_line' => 180,
            'token_num' => 16,
            'has_warnings' => 1,
            'block_id' => 20
          },
          {
            'start_line' => 180,
            'end_line' => 180,
            'src' => ' sub { $over = 1 ; "TEST" }',
            'indent' => 1,
            'has_warnings' => 1,
            'block_id' => 20,
            'token_num' => 8
          },
          {
            'token_num' => 4,
            'block_id' => 21,
            'has_warnings' => 1,
            'src' => ' $over = 1 ;',
            'indent' => 2,
            'start_line' => 180,
            'end_line' => 180
          },
          {
            'end_line' => 188,
            'start_line' => 182,
            'indent' => 0,
            'src' => ' { package OverBoth ; use overload q/""/ => sub { "TEST" } , -X => sub { "-$_[1]" } ; }',
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 24
          },
          {
            'token_num' => 3,
            'block_id' => 22,
            'has_warnings' => 1,
            'indent' => 1,
            'src' => ' package OverBoth ;',
            'end_line' => 183,
            'start_line' => 183
          },
          {
            'token_num' => 19,
            'block_id' => 22,
            'has_warnings' => 0,
            'src' => ' use overload q/""/ => sub { "TEST" } , -X => sub { "-$_[1]" } ;',
            'indent' => 1,
            'start_line' => 185,
            'end_line' => 187
          },
          {
            'end_line' => 186,
            'start_line' => 186,
            'src' => ' sub { "TEST" }',
            'indent' => 1,
            'has_warnings' => 0,
            'block_id' => 22,
            'token_num' => 4
          },
          {
            'token_num' => 4,
            'has_warnings' => 0,
            'block_id' => 22,
            'indent' => 1,
            'src' => ' sub { "-$_[1]" }',
            'end_line' => 187,
            'start_line' => 187
          },
          {
            'end_line' => 197,
            'start_line' => 189,
            'src' => ' { package OverNeither ; use overload \'+\' => sub { 1 } , fallback => 1 ; }',
            'indent' => 0,
            'block_id' => 0,
            'has_warnings' => 1,
            'token_num' => 18
          },
          {
            'block_id' => 25,
            'has_warnings' => 1,
            'token_num' => 3,
            'start_line' => 190,
            'end_line' => 190,
            'indent' => 1,
            'src' => ' package OverNeither ;'
          },
          {
            'start_line' => 194,
            'end_line' => 196,
            'src' => ' use overload \'+\' => sub { 1 } , fallback => 1 ;',
            'indent' => 1,
            'block_id' => 25,
            'has_warnings' => 0,
            'token_num' => 13
          },
          {
            'indent' => 1,
            'src' => ' sub { 1 }',
            'end_line' => 195,
            'start_line' => 195,
            'token_num' => 4,
            'block_id' => 25,
            'has_warnings' => 0
          },
          {
            'src' => ' my $ft = bless [ ] , "OverFtest" ;',
            'indent' => 0,
            'end_line' => 199,
            'start_line' => 199,
            'token_num' => 9,
            'has_warnings' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 8,
            'has_warnings' => 0,
            'block_id' => 0,
            'indent' => 0,
            'src' => ' my $ftstr = qq($ft) ;',
            'start_line' => 200,
            'end_line' => 200
          },
          {
            'block_id' => 0,
            'has_warnings' => 0,
            'token_num' => 9,
            'end_line' => 201,
            'start_line' => 201,
            'src' => ' my $str = bless [ ] , "OverString" ;',
            'indent' => 0
          },
          {
            'has_warnings' => 0,
            'block_id' => 0,
            'token_num' => 9,
            'end_line' => 202,
            'start_line' => 202,
            'indent' => 0,
            'src' => ' my $both = bless [ ] , "OverBoth" ;'
          },
          {
            'indent' => 0,
            'src' => ' my $neither = bless [ ] , "OverNeither" ;',
            'end_line' => 203,
            'start_line' => 203,
            'token_num' => 9,
            'has_warnings' => 0,
            'block_id' => 0
          },
          {
            'block_id' => 0,
            'has_warnings' => 0,
            'token_num' => 8,
            'start_line' => 204,
            'end_line' => 204,
            'src' => ' my $nstr = qq($neither) ;',
            'indent' => 0
          },
          {
            'start_line' => 206,
            'end_line' => 206,
            'indent' => 0,
            'src' => ' open my $gv , "<" , "TEST" ;',
            'block_id' => 0,
            'has_warnings' => 0,
            'token_num' => 8
          },
          {
            'block_id' => 0,
            'has_warnings' => 1,
            'token_num' => 5,
            'end_line' => 207,
            'start_line' => 207,
            'src' => ' bless $gv , "OverString" ;',
            'indent' => 0
          },
          {
            'has_warnings' => 0,
            'block_id' => 0,
            'token_num' => 8,
            'start_line' => 208,
            'end_line' => 208,
            'indent' => 0,
            'src' => ' open my $io , "<" , "TEST" ;'
          },
          {
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 10,
            'end_line' => 209,
            'start_line' => 209,
            'indent' => 0,
            'src' => ' $io = * { $io } { IO } ;'
          },
          {
            'indent' => 0,
            'src' => ' bless $io , "OverString" ;',
            'end_line' => 210,
            'start_line' => 210,
            'token_num' => 5,
            'block_id' => 0,
            'has_warnings' => 1
          },
          {
            'src' => ' my $fcntl_not_available ;',
            'indent' => 0,
            'start_line' => 212,
            'end_line' => 212,
            'token_num' => 3,
            'has_warnings' => 0,
            'block_id' => 0
          },
          {
            'start_line' => 213,
            'end_line' => 213,
            'indent' => 0,
            'src' => ' eval { require Fcntl } or $fcntl_not_available = 1 ;',
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 10
          },
          {
            'start_line' => 215,
            'end_line' => 271,
            'src' => ' for my $op ( split// , "rwxoRWXOezsfdlpSbctugkTMBAC" ) { $over = [ ] ; my $rv = eval "-$op \\$ft" ; isnt ( $rv , undef , "overloaded -$op succeeds" ) or diag ( $@ ) ; is ( $over-> [ 0 ] , $ftstr , "correct object for overloaded -$op" ) ; is ( $over-> [ 1 ] , $op , "correct op for overloaded -$op" ) ; is ( $rv , "-$op" , "correct return value for overloaded -$op" ) ; my ( $exp , $is ) = ( 1 , "is" ) ; if ( ( ! $fcntl_not_available and ( $op eq "u" and not eval { Fcntl::S_ISUID ( ) } or $op eq "g" and not eval { Fcntl::S_ISGID ( ) } or $op eq "k" and not eval { Fcntl::S_ISVTX ( ) } ) ) || ( $^O eq \'MSWin32\' && $op eq \'k\' && is_miniperl ) ) { ( $exp , $is ) = ( 0 , "not" ) ; } $over = 0 ; $rv = eval "-$op \\$str" ; is ( $@ , "" , "-$op succeeds with string overloading" ) ; is ( $rv , eval "-$op \'TEST\'" , "correct -$op on string overload" ) ; is ( $over , $exp , "string overload $is called for -$op" ) ; ( $exp , $is ) = $op eq "l" ? ( 1 , "is" ) : ( 0 , "not" ) ; $over = 0 ; eval "-$op \\$gv" ; is ( $over , $exp , "string overload $is called for -$op on GLOB" ) ; $op eq "t" || $op eq "T" || $op eq "B" and ( $exp , $is ) = ( 1 , "is" ) ; $over = 0 ; eval "-$op \\$io" ; is ( $over , $exp , "string overload $is called for -$op on IO" ) ; $rv = eval "-$op \\$both" ; is ( $rv , "-$op" , "correct -$op on string/-X overload" ) ; $rv = eval "-$op \\$neither" ; is ( $@ , "" , "-$op succeeds with random overloading" ) ; is ( $rv , eval "-$op \\$nstr" , "correct -$op with random overloading" ) ; is ( eval "-r -$op \\$ft" , "-r" , "stacked overloaded -$op" ) ; is ( eval "-$op -r \\$ft" , "-$op" , "overloaded stacked -$op" ) ; }',
            'indent' => 0,
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 330
          },
          {
            'token_num' => 5,
            'block_id' => 27,
            'has_warnings' => 1,
            'src' => ' $over = [ ] ;',
            'indent' => 1,
            'start_line' => 216,
            'end_line' => 216
          },
          {
            'indent' => 1,
            'src' => ' my $rv = eval "-$op \\$ft" ;',
            'start_line' => 217,
            'end_line' => 217,
            'token_num' => 6,
            'has_warnings' => 0,
            'block_id' => 27
          },
          {
            'indent' => 1,
            'src' => ' isnt ( $rv , undef , "overloaded -$op succeeds" ) or diag ( $@ ) ;',
            'start_line' => 218,
            'end_line' => 219,
            'token_num' => 14,
            'has_warnings' => 1,
            'block_id' => 27
          },
          {
            'indent' => 1,
            'src' => ' is ( $over-> [ 0 ] , $ftstr , "correct object for overloaded -$op" ) ;',
            'end_line' => 220,
            'start_line' => 220,
            'token_num' => 13,
            'has_warnings' => 1,
            'block_id' => 27
          },
          {
            'token_num' => 13,
            'has_warnings' => 1,
            'block_id' => 27,
            'src' => ' is ( $over-> [ 1 ] , $op , "correct op for overloaded -$op" ) ;',
            'indent' => 1,
            'end_line' => 221,
            'start_line' => 221
          },
          {
            'block_id' => 27,
            'has_warnings' => 1,
            'token_num' => 9,
            'start_line' => 222,
            'end_line' => 222,
            'indent' => 1,
            'src' => ' is ( $rv , "-$op" , "correct return value for overloaded -$op" ) ;'
          },
          {
            'src' => ' my ( $exp , $is ) = ( 1 , "is" ) ;',
            'indent' => 1,
            'end_line' => 224,
            'start_line' => 224,
            'token_num' => 13,
            'has_warnings' => 1,
            'block_id' => 27
          },
          {
            'token_num' => 71,
            'has_warnings' => 1,
            'block_id' => 27,
            'src' => ' if ( ( ! $fcntl_not_available and ( $op eq "u" and not eval { Fcntl::S_ISUID ( ) } or $op eq "g" and not eval { Fcntl::S_ISGID ( ) } or $op eq "k" and not eval { Fcntl::S_ISVTX ( ) } ) ) || ( $^O eq \'MSWin32\' && $op eq \'k\' && is_miniperl ) ) { ( $exp , $is ) = ( 0 , "not" ) ; }',
            'indent' => 1,
            'start_line' => 225,
            'end_line' => 240
          },
          {
            'src' => ' ( $exp , $is ) = ( 0 , "not" ) ;',
            'indent' => 2,
            'end_line' => 239,
            'start_line' => 239,
            'token_num' => 12,
            'block_id' => 28,
            'has_warnings' => 1
          },
          {
            'indent' => 1,
            'src' => ' $over = 0 ;',
            'start_line' => 242,
            'end_line' => 242,
            'token_num' => 4,
            'has_warnings' => 1,
            'block_id' => 27
          },
          {
            'token_num' => 5,
            'block_id' => 27,
            'has_warnings' => 1,
            'indent' => 1,
            'src' => ' $rv = eval "-$op \\$str" ;',
            'start_line' => 243,
            'end_line' => 243
          },
          {
            'block_id' => 27,
            'has_warnings' => 1,
            'token_num' => 9,
            'start_line' => 244,
            'end_line' => 244,
            'src' => ' is ( $@ , "" , "-$op succeeds with string overloading" ) ;',
            'indent' => 1
          },
          {
            'end_line' => 245,
            'start_line' => 245,
            'src' => ' is ( $rv , eval "-$op \'TEST\'" , "correct -$op on string overload" ) ;',
            'indent' => 1,
            'has_warnings' => 1,
            'block_id' => 27,
            'token_num' => 10
          },
          {
            'has_warnings' => 1,
            'block_id' => 27,
            'token_num' => 9,
            'start_line' => 246,
            'end_line' => 246,
            'indent' => 1,
            'src' => ' is ( $over , $exp , "string overload $is called for -$op" ) ;'
          },
          {
            'token_num' => 22,
            'block_id' => 27,
            'has_warnings' => 1,
            'src' => ' ( $exp , $is ) = $op eq "l" ? ( 1 , "is" ) : ( 0 , "not" ) ;',
            'indent' => 1,
            'start_line' => 248,
            'end_line' => 248
          },
          {
            'start_line' => 250,
            'end_line' => 250,
            'indent' => 1,
            'src' => ' $over = 0 ;',
            'block_id' => 27,
            'has_warnings' => 1,
            'token_num' => 4
          },
          {
            'token_num' => 3,
            'block_id' => 27,
            'has_warnings' => 0,
            'src' => ' eval "-$op \\$gv" ;',
            'indent' => 1,
            'start_line' => 251,
            'end_line' => 251
          },
          {
            'token_num' => 9,
            'block_id' => 27,
            'has_warnings' => 1,
            'indent' => 1,
            'src' => ' is ( $over , $exp , "string overload $is called for -$op on GLOB" ) ;',
            'start_line' => 252,
            'end_line' => 252
          },
          {
            'token_num' => 24,
            'has_warnings' => 1,
            'block_id' => 27,
            'src' => ' $op eq "t" || $op eq "T" || $op eq "B" and ( $exp , $is ) = ( 1 , "is" ) ;',
            'indent' => 1,
            'start_line' => 255,
            'end_line' => 256
          },
          {
            'start_line' => 258,
            'end_line' => 258,
            'indent' => 1,
            'src' => ' $over = 0 ;',
            'has_warnings' => 1,
            'block_id' => 27,
            'token_num' => 4
          },
          {
            'end_line' => 259,
            'start_line' => 259,
            'src' => ' eval "-$op \\$io" ;',
            'indent' => 1,
            'block_id' => 27,
            'has_warnings' => 0,
            'token_num' => 3
          },
          {
            'start_line' => 260,
            'end_line' => 260,
            'indent' => 1,
            'src' => ' is ( $over , $exp , "string overload $is called for -$op on IO" ) ;',
            'has_warnings' => 1,
            'block_id' => 27,
            'token_num' => 9
          },
          {
            'has_warnings' => 1,
            'block_id' => 27,
            'token_num' => 5,
            'start_line' => 262,
            'end_line' => 262,
            'indent' => 1,
            'src' => ' $rv = eval "-$op \\$both" ;'
          },
          {
            'block_id' => 27,
            'has_warnings' => 1,
            'token_num' => 9,
            'end_line' => 263,
            'start_line' => 263,
            'src' => ' is ( $rv , "-$op" , "correct -$op on string/-X overload" ) ;',
            'indent' => 1
          },
          {
            'indent' => 1,
            'src' => ' $rv = eval "-$op \\$neither" ;',
            'end_line' => 265,
            'start_line' => 265,
            'token_num' => 5,
            'block_id' => 27,
            'has_warnings' => 1
          },
          {
            'token_num' => 9,
            'block_id' => 27,
            'has_warnings' => 1,
            'src' => ' is ( $@ , "" , "-$op succeeds with random overloading" ) ;',
            'indent' => 1,
            'start_line' => 266,
            'end_line' => 266
          },
          {
            'indent' => 1,
            'src' => ' is ( $rv , eval "-$op \\$nstr" , "correct -$op with random overloading" ) ;',
            'start_line' => 267,
            'end_line' => 267,
            'token_num' => 10,
            'has_warnings' => 1,
            'block_id' => 27
          },
          {
            'token_num' => 10,
            'has_warnings' => 1,
            'block_id' => 27,
            'indent' => 1,
            'src' => ' is ( eval "-r -$op \\$ft" , "-r" , "stacked overloaded -$op" ) ;',
            'start_line' => 269,
            'end_line' => 269
          },
          {
            'end_line' => 270,
            'start_line' => 270,
            'indent' => 1,
            'src' => ' is ( eval "-$op -r \\$ft" , "-$op" , "overloaded stacked -$op" ) ;',
            'block_id' => 27,
            'has_warnings' => 1,
            'token_num' => 10
          },
          {
            'token_num' => 21,
            'has_warnings' => 1,
            'block_id' => 0,
            'src' => ' { push my @foo , "bar" , -l baz ; is $foo [ 0 ] , "bar" , \'-l bareword does not corrupt the stack\' ; }',
            'indent' => 0,
            'start_line' => 274,
            'end_line' => 277
          },
          {
            'indent' => 1,
            'src' => ' push my @foo , "bar" , -l baz ;',
            'start_line' => 275,
            'end_line' => 275,
            'token_num' => 9,
            'has_warnings' => 1,
            'block_id' => 29
          },
          {
            'src' => ' is $foo [ 0 ] , "bar" , \'-l bareword does not corrupt the stack\' ;',
            'indent' => 1,
            'start_line' => 276,
            'end_line' => 276,
            'token_num' => 10,
            'has_warnings' => 1,
            'block_id' => 29
          },
          {
            'block_id' => 0,
            'has_warnings' => 0,
            'token_num' => 3,
            'start_line' => 280,
            'end_line' => 280,
            'src' => ' stat "test.pl" ;',
            'indent' => 0
          },
          {
            'token_num' => 12,
            'has_warnings' => 1,
            'block_id' => 0,
            'indent' => 0,
            'src' => ' eval { use warnings FATAL => io ; -l cradd } ;',
            'start_line' => 281,
            'end_line' => 281
          },
          {
            'indent' => 0,
            'src' => ' use warnings FATAL => io ;',
            'end_line' => 281,
            'start_line' => 281,
            'token_num' => 6,
            'has_warnings' => 1,
            'block_id' => 29
          },
          {
            'indent' => 0,
            'src' => ' isnt ( stat _ , 1 , \'fatal warnings do not prevent -l HANDLE from setting stat status\' ) ;',
            'end_line' => 283,
            'start_line' => 282,
            'token_num' => 10,
            'has_warnings' => 1,
            'block_id' => 0
          },
          {
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 41,
            'end_line' => 294,
            'start_line' => 287,
            'src' => ' { my $w ; sub oon::TIESCALAR { bless [ ] , \'oon\' } sub oon::FETCH { $w ++ } tie my $t , \'oon\' ; push my @a , $t , -t ; is $w , 1 , \'file test does not call FETCH on stack item not its own\' ; }',
            'indent' => 0
          },
          {
            'token_num' => 3,
            'block_id' => 30,
            'has_warnings' => 0,
            'indent' => 1,
            'src' => ' my $w ;',
            'start_line' => 288,
            'end_line' => 288
          },
          {
            'has_warnings' => 0,
            'block_id' => 30,
            'token_num' => 6,
            'end_line' => 291,
            'start_line' => 291,
            'src' => ' tie my $t , \'oon\' ;',
            'indent' => 1
          },
          {
            'token_num' => 8,
            'has_warnings' => 1,
            'block_id' => 30,
            'src' => ' push my @a , $t , -t ;',
            'indent' => 1,
            'start_line' => 292,
            'end_line' => 292
          },
          {
            'src' => ' is $w , 1 , \'file test does not call FETCH on stack item not its own\' ;',
            'indent' => 1,
            'end_line' => 293,
            'start_line' => 293,
            'token_num' => 7,
            'block_id' => 30,
            'has_warnings' => 1
          },
          {
            'start_line' => 298,
            'end_line' => 298,
            'indent' => 0,
            'src' => ' my $Perl = which_perl ( ) ;',
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 7
          },
          {
            'token_num' => 13,
            'block_id' => 33,
            'has_warnings' => 1,
            'indent' => 1,
            'src' => ' skip "no -T on filehandles" , 8 unless eval { -T STDERR ; 1 } ;',
            'end_line' => 301,
            'start_line' => 301
          },
          {
            'token_num' => 3,
            'block_id' => 33,
            'has_warnings' => 0,
            'src' => ' -T STDERR ;',
            'indent' => 1,
            'start_line' => 301,
            'end_line' => 301
          },
          {
            'end_line' => 304,
            'start_line' => 304,
            'src' => ' -l "perl.c" ;',
            'indent' => 1,
            'has_warnings' => 0,
            'block_id' => 33,
            'token_num' => 3
          },
          {
            'start_line' => 305,
            'end_line' => 305,
            'indent' => 1,
            'src' => ' -T STDERR ;',
            'has_warnings' => 0,
            'block_id' => 33,
            'token_num' => 3
          },
          {
            'token_num' => 6,
            'block_id' => 33,
            'has_warnings' => 0,
            'src' => ' eval { -l _ } ;',
            'indent' => 1,
            'start_line' => 306,
            'end_line' => 306
          },
          {
            'block_id' => 33,
            'has_warnings' => 1,
            'token_num' => 10,
            'start_line' => 307,
            'end_line' => 308,
            'indent' => 1,
            'src' => ' like $@ , qr/^The stat preceding -l _ wasn\'t an lstat at / , \'-T HANDLE sets the stat type\' ;'
          },
          {
            'src' => ' fresh_perl_is \'open my $fh, "test.pl"; -r $fh; undef $fh; open my $fh2, \' . "q\\0$Perl\\0; print -B _" , \'\' , { switches => [ \'-l\' ] } , \'PL_statgv should not point to freed-and-reused SV\' ;',
            'indent' => 1,
            'end_line' => 316,
            'start_line' => 312,
            'token_num' => 17,
            'block_id' => 33,
            'has_warnings' => 1
          },
          {
            'indent' => 1,
            'src' => ' fresh_perl_is \'open Fh, "test.pl"; -r($h{i} = *Fh); $h{i} = 3; undef %h;\' . \'open my $fh2, \' . "q\\0" . which_perl ( ) . "\\0; print -B _" , \'\' , { switches => [ \'-l\' ] } , \'PL_statgv should not point to coerced-freed-and-reused GV\' ;',
            'start_line' => 320,
            'end_line' => 324,
            'token_num' => 25,
            'block_id' => 33,
            'has_warnings' => 1
          },
          {
            'token_num' => 6,
            'has_warnings' => 0,
            'block_id' => 33,
            'src' => ' open my $fh , \'test.pl\' ;',
            'indent' => 1,
            'end_line' => 327,
            'start_line' => 327
          },
          {
            'token_num' => 3,
            'has_warnings' => 1,
            'block_id' => 33,
            'indent' => 1,
            'src' => ' stat $Perl ;',
            'end_line' => 328,
            'start_line' => 328
          },
          {
            'token_num' => 7,
            'block_id' => 33,
            'has_warnings' => 1,
            'src' => ' stat * $fh { IO } ;',
            'indent' => 1,
            'end_line' => 329,
            'start_line' => 329
          },
          {
            'end_line' => 330,
            'start_line' => 330,
            'indent' => 1,
            'src' => ' is ( -T _ , 1 , \'-T _ works after stat $ioref\' ) ;',
            'has_warnings' => 1,
            'block_id' => 33,
            'token_num' => 10
          },
          {
            'end_line' => 333,
            'start_line' => 333,
            'indent' => 1,
            'src' => ' -r * $fh { IO } ;',
            'has_warnings' => 1,
            'block_id' => 33,
            'token_num' => 7
          },
          {
            'end_line' => 334,
            'start_line' => 334,
            'src' => ' is ( -T _ , 1 , \'-T _ works after -r $ioref\' ) ;',
            'indent' => 1,
            'block_id' => 33,
            'has_warnings' => 1,
            'token_num' => 10
          },
          {
            'block_id' => 33,
            'has_warnings' => 1,
            'token_num' => 3,
            'end_line' => 337,
            'start_line' => 337,
            'indent' => 1,
            'src' => ' stat $fh ;'
          },
          {
            'start_line' => 338,
            'end_line' => 338,
            'src' => ' close $fh ;',
            'indent' => 1,
            'block_id' => 33,
            'has_warnings' => 1,
            'token_num' => 3
          },
          {
            'indent' => 1,
            'src' => ' -T _ ;',
            'end_line' => 339,
            'start_line' => 339,
            'token_num' => 3,
            'has_warnings' => 0,
            'block_id' => 33
          },
          {
            'indent' => 1,
            'src' => ' isnt ( stat _ , 1 , \'-T _ on closed filehandle resets stat info\' ) ;',
            'start_line' => 340,
            'end_line' => 340,
            'token_num' => 10,
            'has_warnings' => 1,
            'block_id' => 33
          },
          {
            'token_num' => 3,
            'block_id' => 33,
            'has_warnings' => 0,
            'indent' => 1,
            'src' => ' lstat "test.pl" ;',
            'end_line' => 342,
            'start_line' => 342
          },
          {
            'start_line' => 343,
            'end_line' => 343,
            'src' => ' -T $fh ;',
            'indent' => 1,
            'has_warnings' => 1,
            'block_id' => 33,
            'token_num' => 3
          },
          {
            'indent' => 1,
            'src' => ' eval { lstat _ } ;',
            'end_line' => 344,
            'start_line' => 344,
            'token_num' => 6,
            'has_warnings' => 0,
            'block_id' => 33
          },
          {
            'token_num' => 10,
            'has_warnings' => 1,
            'block_id' => 33,
            'src' => ' like $@ , qr/^The stat preceding lstat\\(\\) wasn\'t an lstat at / , \'-T on closed handle resets last stat type\' ;',
            'indent' => 1,
            'end_line' => 346,
            'start_line' => 345
          },
          {
            'start_line' => 349,
            'end_line' => 349,
            'src' => ' $! = 7 ;',
            'indent' => 1,
            'block_id' => 33,
            'has_warnings' => 0,
            'token_num' => 4
          },
          {
            'token_num' => 3,
            'has_warnings' => 1,
            'block_id' => 33,
            'indent' => 1,
            'src' => ' -T cradd ;',
            'end_line' => 350,
            'start_line' => 350
          },
          {
            'indent' => 1,
            'src' => ' my $errno = $! ;',
            'end_line' => 351,
            'start_line' => 351,
            'token_num' => 5,
            'has_warnings' => 0,
            'block_id' => 33
          },
          {
            'token_num' => 4,
            'has_warnings' => 0,
            'block_id' => 33,
            'indent' => 1,
            'src' => ' $! = 7 ;',
            'start_line' => 352,
            'end_line' => 352
          },
          {
            'has_warnings' => 1,
            'block_id' => 33,
            'token_num' => 12,
            'start_line' => 353,
            'end_line' => 353,
            'src' => ' eval { use warnings FATAL => unopened ; -T cradd } ;',
            'indent' => 1
          },
          {
            'token_num' => 6,
            'block_id' => 33,
            'has_warnings' => 1,
            'indent' => 1,
            'src' => ' use warnings FATAL => unopened ;',
            'start_line' => 353,
            'end_line' => 353
          },
          {
            'end_line' => 354,
            'start_line' => 354,
            'src' => ' my $errno2 = $! ;',
            'indent' => 1,
            'has_warnings' => 0,
            'block_id' => 33,
            'token_num' => 5
          },
          {
            'start_line' => 355,
            'end_line' => 356,
            'src' => ' is $errno2 , $errno , \'fatal warnings do not affect errno after -T BADHADNLE\' ;',
            'indent' => 1,
            'has_warnings' => 1,
            'block_id' => 33,
            'token_num' => 7
          },
          {
            'end_line' => 360,
            'start_line' => 359,
            'src' => ' is runperl ( prog => \'-T _\' , switches => [ \'-w\' ] , stderr => 1 ) , "" , \'no uninit warnings from -T with no preceding stat\' ;',
            'indent' => 0,
            'block_id' => 0,
            'has_warnings' => 1,
            'token_num' => 22
          },
          {
            'has_warnings' => 0,
            'block_id' => 34,
            'token_num' => 15,
            'start_line' => 363,
            'end_line' => 363,
            'indent' => 1,
            'src' => ' my $rand_file_name = \'filetest-\' . rand =~ y/.//dr ;'
          },
          {
            'indent' => 1,
            'src' => ' if ( -e $rand_file_name ) { skip "File $rand_file_name exists" , 1 }',
            'end_line' => 364,
            'start_line' => 364,
            'token_num' => 11,
            'block_id' => 34,
            'has_warnings' => 1
          },
          {
            'token_num' => 3,
            'block_id' => 34,
            'has_warnings' => 0,
            'src' => ' stat \'test.pl\' ;',
            'indent' => 1,
            'end_line' => 365,
            'start_line' => 365
          },
          {
            'has_warnings' => 1,
            'block_id' => 34,
            'token_num' => 3,
            'end_line' => 366,
            'start_line' => 366,
            'src' => ' -T $rand_file_name ;',
            'indent' => 1
          },
          {
            'token_num' => 10,
            'has_warnings' => 1,
            'block_id' => 34,
            'indent' => 1,
            'src' => ' isnt ( stat _ , 1 , \'-T "nonexistent" resets stat success status\' ) ;',
            'start_line' => 367,
            'end_line' => 367
          },
          {
            'block_id' => 0,
            'has_warnings' => 1,
            'token_num' => 80,
            'start_line' => 372,
            'end_line' => 395,
            'src' => ' { stat "test.pl" ; -r *phlon ; my $failed_stat1 = stat _ ; stat "test.pl" ; eval { use warnings FATAL => unopened ; -r *phlon } ; my $failed_stat2 = stat _ ; is $failed_stat2 , $failed_stat1 , \'failed -r($gv_without_io) with and w/out fatal warnings\' ; stat "test.pl" ; -r cength ; $failed_stat1 = stat _ ; stat "test.pl" ; eval { use warnings FATAL => unopened ; -r cength } ; $failed_stat2 = stat _ ; is $failed_stat2 , $failed_stat1 , \'failed -r($gv_with_io_but_no_fp) with and w/out fatal warnings\' ; }',
            'indent' => 0
          },
          {
            'block_id' => 36,
            'has_warnings' => 0,
            'token_num' => 3,
            'start_line' => 373,
            'end_line' => 373,
            'indent' => 1,
            'src' => ' stat "test.pl" ;'
          },
          {
            'block_id' => 36,
            'has_warnings' => 0,
            'token_num' => 3,
            'start_line' => 375,
            'end_line' => 375,
            'src' => ' -r *phlon ;',
            'indent' => 1
          },
          {
            'token_num' => 6,
            'block_id' => 36,
            'has_warnings' => 0,
            'indent' => 1,
            'src' => ' my $failed_stat1 = stat _ ;',
            'start_line' => 376,
            'end_line' => 376
          },
          {
            'has_warnings' => 0,
            'block_id' => 36,
            'token_num' => 3,
            'end_line' => 378,
            'start_line' => 378,
            'src' => ' stat "test.pl" ;',
            'indent' => 1
          },
          {
            'has_warnings' => 1,
            'block_id' => 36,
            'token_num' => 12,
            'end_line' => 379,
            'start_line' => 379,
            'indent' => 1,
            'src' => ' eval { use warnings FATAL => unopened ; -r *phlon } ;'
          },
          {
            'token_num' => 6,
            'block_id' => 36,
            'has_warnings' => 1,
            'src' => ' use warnings FATAL => unopened ;',
            'indent' => 1,
            'end_line' => 379,
            'start_line' => 379
          },
          {
            'indent' => 1,
            'src' => ' my $failed_stat2 = stat _ ;',
            'start_line' => 380,
            'end_line' => 380,
            'token_num' => 6,
            'has_warnings' => 0,
            'block_id' => 36
          },
          {
            'indent' => 1,
            'src' => ' is $failed_stat2 , $failed_stat1 , \'failed -r($gv_without_io) with and w/out fatal warnings\' ;',
            'start_line' => 382,
            'end_line' => 383,
            'token_num' => 7,
            'has_warnings' => 1,
            'block_id' => 36
          },
          {
            'end_line' => 385,
            'start_line' => 385,
            'src' => ' stat "test.pl" ;',
            'indent' => 1,
            'block_id' => 36,
            'has_warnings' => 0,
            'token_num' => 3
          },
          {
            'token_num' => 3,
            'block_id' => 36,
            'has_warnings' => 1,
            'indent' => 1,
            'src' => ' -r cength ;',
            'end_line' => 386,
            'start_line' => 386
          },
          {
            'end_line' => 387,
            'start_line' => 387,
            'src' => ' $failed_stat1 = stat _ ;',
            'indent' => 1,
            'block_id' => 36,
            'has_warnings' => 1,
            'token_num' => 5
          },
          {
            'indent' => 1,
            'src' => ' stat "test.pl" ;',
            'start_line' => 389,
            'end_line' => 389,
            'token_num' => 3,
            'has_warnings' => 0,
            'block_id' => 36
          },
          {
            'has_warnings' => 1,
            'block_id' => 36,
            'token_num' => 12,
            'start_line' => 390,
            'end_line' => 390,
            'indent' => 1,
            'src' => ' eval { use warnings FATAL => unopened ; -r cength } ;'
          },
          {
            'start_line' => 390,
            'end_line' => 390,
            'indent' => 1,
            'src' => ' use warnings FATAL => unopened ;',
            'block_id' => 36,
            'has_warnings' => 1,
            'token_num' => 6
          },
          {
            'has_warnings' => 1,
            'block_id' => 36,
            'token_num' => 5,
            'start_line' => 391,
            'end_line' => 391,
            'src' => ' $failed_stat2 = stat _ ;',
            'indent' => 1
          },
          {
            'start_line' => 393,
            'end_line' => 394,
            'indent' => 1,
            'src' => ' is $failed_stat2 , $failed_stat1 , \'failed -r($gv_with_io_but_no_fp) with and w/out fatal warnings\' ;',
            'has_warnings' => 1,
            'block_id' => 36,
            'token_num' => 7
          }
        ]
, 'Compiler::Lexer::get_groups_by_syntax_level');
};

subtest 'get_used_modules' => sub {
    my $modules = Compiler::Lexer->new('')->get_used_modules($script);
    is_deeply($modules, [
          {
            'name' => 'Perl::OSType',
            'args' => '  \'os_type\''
          },
          {
            'name' => 'overload',
            'args' => '  fallback  =>  1  ,  -X  =>  sub  { $over = [ qq($_[0]) , $_ [ 1 ] ] ; "-$_[1]" ; }'
          },
          {
            'args' => '  q / "" /  =>  sub  { $over = 1 ; "TEST" }',
            'name' => 'overload'
          },
          {
            'args' => '  q / "" /  =>  sub  { "TEST" }  ,  -X  =>  sub  { "-$_[1]" }',
            'name' => 'overload'
          },
          {
            'args' => '  \'+\'  =>  sub  { 1 }  ,  fallback  =>  1',
            'name' => 'overload'
          },
          {
            'name' => 'warnings',
            'args' => '  FATAL  =>  io'
          },
          {
            'args' => '  FATAL  =>  unopened',
            'name' => 'warnings'
          },
          {
            'name' => 'warnings',
            'args' => '  FATAL  =>  unopened'
          },
          {
            'args' => '  FATAL  =>  unopened',
            'name' => 'warnings'
          }
        ]
, 'Compiler::Lexer::get_used_modules');
};

done_testing;
