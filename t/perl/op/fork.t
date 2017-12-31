use strict;
use warnings;
use Test::More;
BEGIN {
    use_ok('Compiler::Lexer');
}
my $script =<<'__SCRIPT__';
#!./perl

# tests for both real and emulated fork()

BEGIN {
    chdir 't' if -d 't';
    @INC = '../lib';
    require './test.pl';
    require Config;
    skip_all('no fork')
	unless ($Config::Config{d_fork} or $Config::Config{d_pseudofork});
    skip_all('no fork')
        if $^O eq 'MSWin32' && is_miniperl;
}

$|=1;

run_multiple_progs('', \*DATA);

my $shell = $ENV{SHELL} || '';
SKIP: {
    skip "This test can only be run under bash or zsh"
        unless $shell =~ m{/(?:ba|z)sh$};
    my $probe = qx{
        $shell -c 'ulimit -u 1 2>&1 && echo good'
    };
    chomp $probe;
    skip "Can't set ulimit -u on this system: $probe"
	unless $probe eq 'good';

    my $out = qx{
        $shell -c 'ulimit -u 1; exec $^X -e "
            print((() = fork) == 1 ? q[ok] : q[not ok])
        "'
    };
    # perl #117141
    skip "fork() didn't fail, maybe you're running as root", 1
      if $out eq "okok";
    is($out, "ok", "bash/zsh-only test for 'fork' returning undef on failure");
}

done_testing();

__END__
$| = 1;
if ($cid = fork) {
    sleep 1;
    if ($result = (kill 9, $cid)) {
	print "ok 2\n";
    }
    else {
	print "not ok 2 $result\n";
    }
    sleep 1 if $^O eq 'MSWin32';	# avoid WinNT race bug
}
else {
    print "ok 1\n";
    sleep 10;
}
EXPECT
OPTION random
ok 1
ok 2
########
$| = 1;
if ($cid = fork) {
    sleep 1;
    print "not " unless kill 'INT', $cid;
    print "ok 2\n";
}
else {
    # XXX On Windows the default signal handler kills the
    # XXX whole process, not just the thread (pseudo-process)
    $SIG{INT} = sub { exit };
    print "ok 1\n";
    sleep 5;
    die;
}
EXPECT
OPTION random
ok 1
ok 2
########
$| = 1;
sub forkit {
    print "iteration $i start\n";
    my $x = fork;
    if (defined $x) {
	if ($x) {
	    print "iteration $i parent\n";
	}
	else {
	    print "iteration $i child\n";
	}
    }
    else {
	print "pid $$ failed to fork\n";
    }
}
while ($i++ < 3) { do { forkit(); }; }
EXPECT
OPTION random
iteration 1 start
iteration 1 parent
iteration 1 child
iteration 2 start
iteration 2 parent
iteration 2 child
iteration 2 start
iteration 2 parent
iteration 2 child
iteration 3 start
iteration 3 parent
iteration 3 child
iteration 3 start
iteration 3 parent
iteration 3 child
iteration 3 start
iteration 3 parent
iteration 3 child
iteration 3 start
iteration 3 parent
iteration 3 child
########
$| = 1;
fork()
 ? (print("parent\n"),sleep(1))
 : (print("child\n"),exit) ;
EXPECT
OPTION random
parent
child
########
$| = 1;
fork()
 ? (print("parent\n"),exit)
 : (print("child\n"),sleep(1)) ;
EXPECT
OPTION random
parent
child
########
$| = 1;
@a = (1..3);
for (@a) {
    if (fork) {
	print "parent $_\n";
	$_ = "[$_]";
    }
    else {
	print "child $_\n";
	$_ = "-$_-";
    }
}
print "@a\n";
EXPECT
OPTION random
parent 1
child 1
parent 2
child 2
parent 2
child 2
parent 3
child 3
parent 3
child 3
parent 3
child 3
parent 3
child 3
[1] [2] [3]
-1- [2] [3]
[1] -2- [3]
[1] [2] -3-
-1- -2- [3]
-1- [2] -3-
[1] -2- -3-
-1- -2- -3-
########
$| = 1;
foreach my $c (1,2,3) {
    if (fork) {
	print "parent $c\n";
    }
    else {
	print "child $c\n";
	exit;
    }
}
while (wait() != -1) { print "waited\n" }
EXPECT
OPTION random
child 1
child 2
child 3
parent 1
parent 2
parent 3
waited
waited
waited
########
use Config;
$| = 1;
$\ = "\n";
fork()
 ? print($Config{osname} eq $^O)
 : print($Config{osname} eq $^O) ;
EXPECT
OPTION random
1
1
########
$| = 1;
$\ = "\n";
fork()
 ? do { require Config; print($Config::Config{osname} eq $^O); }
 : do { require Config; print($Config::Config{osname} eq $^O); }
EXPECT
OPTION random
1
1
########
$| = 1;
use Cwd;
my $cwd = cwd(); # Make sure we load Win32.pm while "../lib" still works.
$\ = "\n";
my $dir;
if (fork) {
    $dir = "f$$.tst";
    mkdir $dir, 0755;
    chdir $dir;
    print cwd() =~ /\Q$dir/i ? "ok 1 parent" : "not ok 1 parent";
    chdir "..";
    rmdir $dir;
}
else {
    sleep 2;
    $dir = "f$$.tst";
    mkdir $dir, 0755;
    chdir $dir;
    print cwd() =~ /\Q$dir/i ? "ok 1 child" : "not ok 1 child";
    chdir "..";
    rmdir $dir;
}
EXPECT
OPTION random
ok 1 parent
ok 1 child
########
$| = 1;
$\ = "\n";
my $getenv;
if ($^O eq 'MSWin32' || $^O eq 'NetWare') {
    $getenv = qq[$^X -e "print \$ENV{TST}"];
}
else {
    $getenv = qq[$^X -e 'print \$ENV{TST}'];
}
$ENV{TST} = 'foo';
if (fork) {
    sleep 1;
    print "parent before: " . `$getenv`;
    $ENV{TST} = 'bar';
    print "parent after: " . `$getenv`;
}
else {
    print "child before: " . `$getenv`;
    $ENV{TST} = 'baz';
    print "child after: " . `$getenv`;
}
EXPECT
OPTION random
child before: foo
child after: baz
parent before: foo
parent after: bar
########
$| = 1;
$\ = "\n";
if ($pid = fork) {
    waitpid($pid,0);
    print "parent got $?"
}
else {
    exit(42);
}
EXPECT
OPTION random
parent got 10752
########
$| = 1;
$\ = "\n";
my $echo = 'echo';
if ($^O =~ /android/) {
    $echo = q{sh -c 'echo $@' -- };
}
if ($pid = fork) {
    waitpid($pid,0);
    print "parent got $?"
}
else {
    exec("$echo foo");
}
EXPECT
OPTION random
foo
parent got 0
########
if (fork) {
    die "parent died";
}
else {
    die "child died";
}
EXPECT
OPTION random
parent died at - line 2.
child died at - line 5.
########
if ($pid = fork) {
    eval { die "parent died" };
    print $@;
}
else {
    eval { die "child died" };
    print $@;
}
EXPECT
OPTION random
parent died at - line 2.
child died at - line 6.
########
if (eval q{$pid = fork}) {
    eval q{ die "parent died" };
    print $@;
}
else {
    eval q{ die "child died" };
    print $@;
}
EXPECT
OPTION random
parent died at (eval 2) line 1.
child died at (eval 2) line 1.
########
BEGIN {
    $| = 1;
    fork and exit;
    print "inner\n";
}
# XXX In emulated fork(), the child will not execute anything after
# the BEGIN block, due to difficulties in recreating the parse stacks
# and restarting yyparse() midstream in the child.  This can potentially
# be overcome by treating what's after the BEGIN{} as a brand new parse.
#print "outer\n"
EXPECT
OPTION random
inner
########
sub pipe_to_fork ($$) {
    my $parent = shift;
    my $child = shift;
    pipe($child, $parent) or die;
    my $pid = fork();
    die "fork() failed: $!" unless defined $pid;
    close($pid ? $child : $parent);
    $pid;
}

if (pipe_to_fork('PARENT','CHILD')) {
    # parent
    print PARENT "pipe_to_fork\n";
    close PARENT;
}
else {
    # child
    while (<CHILD>) { print; }
    close CHILD;
    exit;
}

sub pipe_from_fork ($$) {
    my $parent = shift;
    my $child = shift;
    pipe($parent, $child) or die;
    my $pid = fork();
    die "fork() failed: $!" unless defined $pid;
    close($pid ? $child : $parent);
    $pid;
}

if (pipe_from_fork('PARENT','CHILD')) {
    # parent
    while (<PARENT>) { print; }
    close PARENT;
}
else {
    # child
    print CHILD "pipe_from_fork\n";
    close CHILD;
    exit;
}
EXPECT
OPTION random
pipe_from_fork
pipe_to_fork
########
$|=1;
if ($pid = fork()) {
    print "forked first kid\n";
    print "waitpid() returned ok\n" if waitpid($pid,0) == $pid;
}
else {
    print "first child\n";
    exit(0);
}
if ($pid = fork()) {
    print "forked second kid\n";
    print "wait() returned ok\n" if wait() == $pid;
}
else {
    print "second child\n";
    exit(0);
}
EXPECT
OPTION random
forked first kid
first child
waitpid() returned ok
forked second kid
second child
wait() returned ok
########
pipe(RDR,WTR) or die $!;
my $pid = fork;
die "fork: $!" if !defined $pid;
if ($pid == 0) {
    close RDR;
    print WTR "STRING_FROM_CHILD\n";
    close WTR;
} else {
    close WTR;
    chomp(my $string_from_child  = <RDR>);
    close RDR;
    print $string_from_child eq "STRING_FROM_CHILD", "\n";
}
EXPECT
OPTION random
1
########
# [perl #39145] Perl_dounwind() crashing with Win32's fork() emulation
sub { @_ = 3; fork ? die "1\n" : die "1\n" }->(2);
EXPECT
OPTION random
1
1
########
# [perl #72604] @DB::args stops working across Win32 fork
$|=1;
sub f {
    if ($pid = fork()) {
	print "waitpid() returned ok\n" if waitpid($pid,0) == $pid;
    }
    else {
	package DB;
	my @c = caller(0);
	print "child: called as [$c[3](", join(',',@DB::args), ")]\n";
	exit(0);
    }
}
f("foo", "bar");
EXPECT
OPTION random
child: called as [main::f(foo,bar)]
waitpid() returned ok
########
# Windows 2000: https://rt.cpan.org/Ticket/Display.html?id=66016#txn-908976
system $^X,  "-e", "if (\$pid=fork){sleep 1;kill(9, \$pid)} else {sleep 5}";
print $?>>8, "\n";
EXPECT
0
########
# Windows 7: https://rt.cpan.org/Ticket/Display.html?id=66016#txn-908976
system $^X,  "-e", "if (\$pid=fork){kill(9, \$pid)} else {sleep 5}";
print $?>>8, "\n";
EXPECT
0
########
# Windows fork() emulation: can we still waitpid() after signalling SIGTERM?
$|=1;
if (my $pid = fork) {
    sleep 1;
    print "1\n";
    kill 'TERM', $pid;
    waitpid($pid, 0);
    print "4\n";
}
else {
    $SIG{TERM} = sub { print "2\n" };
    sleep 10;
    print "3\n";
}
EXPECT
1
2
3
4
########
# this used to SEGV. RT # 121721
$|=1;
&main;
sub main {
    if (my $pid = fork) {
	waitpid($pid, 0);
    }
    else {
        print "foo\n";
    }
}
EXPECT
foo
########
# ${^GLOBAL_PHASE} at the end of a pseudo-fork
if (my $pid = fork) {
    waitpid $pid, 0;
} else {
    eval 'END { print "${^GLOBAL_PHASE}\n" }';
    exit;
}
EXPECT
END

__SCRIPT__

subtest 'tokenize' => sub {
    my $tokens = Compiler::Lexer->new('')->tokenize($script);
    is_deeply($tokens, [
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_ModWord,
                   'data' => 'BEGIN',
                   'type' => Compiler::Lexer::TokenType::T_ModWord,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'ModWord',
                   'line' => 5
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'line' => 5,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'data' => 'chdir',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'BuiltinFunc',
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'line' => 6,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => 't',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'if',
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'IfStmt',
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 6,
                   'name' => 'Handle',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'data' => '-d',
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 6,
                   'name' => 'RawString',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 't',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 6,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 7,
                   'name' => 'LibraryDirectories',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '@INC',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_LibraryDirectories
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'data' => '=',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 7,
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '../lib',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'line' => 7
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'line' => 7,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'require',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_RequireDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'RequireDecl',
                   'line' => 8
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => './test.pl',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 8,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'line' => 8
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RequireDecl',
                   'line' => 9,
                   'data' => 'require',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_RequireDecl,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RequiredName',
                   'line' => 9,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'data' => 'Config',
                   'type' => Compiler::Lexer::TokenType::T_RequiredName,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'line' => 9,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'skip_all',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 10,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'line' => 10,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'line' => 10,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'no fork',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'line' => 10
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_UnlessStmt,
                   'data' => 'unless',
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 11,
                   'name' => 'UnlessStmt'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 11,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'GlobalVar',
                   'line' => 11,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_GlobalVar,
                   'data' => '$Config',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'NamespaceResolver',
                   'line' => 11,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '::',
                   'type' => Compiler::Lexer::TokenType::T_NamespaceResolver,
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 11,
                   'name' => 'Namespace',
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'data' => 'Config',
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBrace',
                   'line' => 11
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'line' => 11,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'd_fork',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightBrace',
                   'line' => 11
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 11,
                   'name' => 'AlphabetOr',
                   'data' => 'or',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 11,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$Config',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 11,
                   'name' => 'NamespaceResolver',
                   'type' => Compiler::Lexer::TokenType::T_NamespaceResolver,
                   'data' => '::',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Namespace',
                   'line' => 11,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'data' => 'Config',
                   'type' => Compiler::Lexer::TokenType::T_Namespace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '{',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'LeftBrace',
                   'line' => 11
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 11,
                   'name' => 'Key',
                   'data' => 'd_pseudofork',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 11,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 11,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'line' => 11
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'skip_all',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 1,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'line' => 12
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'line' => 12
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'no fork',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'line' => 12
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 12,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'data' => 'if',
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'IfStmt',
                   'line' => 13
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 13,
                   'name' => 'SpecificValue',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'data' => '$^O',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 13,
                   'name' => 'StringEqual',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'data' => 'eq',
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => 'MSWin32',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'RawString',
                   'line' => 13
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '&&',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_And,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 13,
                   'name' => 'And'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'data' => 'is_miniperl',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 13,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 13,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightBrace',
                   'line' => 14
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'data' => '$|',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SpecificValue',
                   'line' => 16
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'line' => 16,
                   'data' => '=',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '1',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'line' => 16,
                   'name' => 'Int'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 16,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'line' => 18,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'run_multiple_progs',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 1,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'LeftParenthesis',
                   'line' => 18
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'line' => 18
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 18,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 18,
                   'name' => 'Ref',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'data' => '\\',
                   'type' => Compiler::Lexer::TokenType::T_Ref,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '*DATA',
                   'type' => Compiler::Lexer::TokenType::T_Glob,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 18,
                   'name' => 'Glob'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'line' => 18,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'line' => 18
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'data' => 'my',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'line' => 20,
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$shell',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar',
                   'line' => 20
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'data' => '=',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'name' => 'Assign',
                   'line' => 20
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_GlobalVar,
                   'data' => '$ENV',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'GlobalVar',
                   'line' => 20
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 20,
                   'name' => 'LeftBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'line' => 20,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'SHELL',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBrace',
                   'line' => 20,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '||',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_Or,
                   'line' => 20,
                   'name' => 'Or'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'line' => 20
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'line' => 20,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'line' => 21,
                   'has_warnings' => 1,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'SKIP',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Colon,
                   'data' => ':',
                   'type' => Compiler::Lexer::TokenType::T_Colon,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Colon',
                   'line' => 21
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'line' => 21,
                   'data' => '{',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'line' => 22,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'data' => 'skip',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 22,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => 'This test can only be run under bash or zsh',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'unless',
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'type' => Compiler::Lexer::TokenType::T_UnlessStmt,
                   'line' => 23,
                   'name' => 'UnlessStmt'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'line' => 23,
                   'data' => '$shell',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'data' => '=~',
                   'type' => Compiler::Lexer::TokenType::T_RegOK,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 23,
                   'name' => 'RegOK'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegMatch',
                   'line' => 23,
                   'type' => Compiler::Lexer::TokenType::T_RegMatch,
                   'data' => 'm',
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegDelim',
                   'line' => 23,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 23,
                   'name' => 'RegExp',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '/(?:ba|z)sh$',
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 23,
                   'name' => 'RegDelim'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'line' => 23,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'data' => 'my',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'VarDecl',
                   'line' => 24
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'data' => '$probe',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'LocalVar',
                   'line' => 24
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'data' => '=',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 24,
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegExec',
                   'line' => 24,
                   'data' => 'qx',
                   'type' => Compiler::Lexer::TokenType::T_RegExec,
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegDelim',
                   'line' => 24,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '{',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 27,
                   'name' => 'RegExp',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '
        $shell -c \'ulimit -u 1 2>&1 && echo good\'
    ',
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 27,
                   'name' => 'RegDelim',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'chomp',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'line' => 28,
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 28,
                   'name' => 'Var',
                   'data' => '$probe',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 28,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'skip',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'line' => 29
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 29,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'Can\'t set ulimit -u on this system: $probe',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'unless',
                   'type' => Compiler::Lexer::TokenType::T_UnlessStmt,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'UnlessStmt',
                   'line' => 30
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$probe',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'line' => 30
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 30,
                   'name' => 'StringEqual',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'eq',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_StringEqual
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => 'good',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 30,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 30,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'line' => 32,
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$out',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 32,
                   'name' => 'LocalVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 32,
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegExec,
                   'data' => 'qx',
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 32,
                   'name' => 'RegExec'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegDelim',
                   'line' => 32,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'data' => '
        $shell -c \'ulimit -u 1; exec $^X -e "
            print((() = fork) == 1 ? q[ok] : q[not ok])
        "\'
    ',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 37,
                   'name' => 'RegExp'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'data' => '}',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegDelim',
                   'line' => 37
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'line' => 37,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'skip',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'name' => 'Key',
                   'line' => 39
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'line' => 39,
                   'data' => 'fork() didn\'t fail, maybe you\'re running as root',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 39,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'data' => '1',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int',
                   'line' => 39
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 40,
                   'name' => 'IfStmt',
                   'data' => 'if',
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'line' => 40,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$out',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'eq',
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 40,
                   'name' => 'StringEqual'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 40,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => 'okok',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 40,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'is',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 41,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 41,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'line' => 41,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$out',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'line' => 41
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'ok',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'line' => 41
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'line' => 41,
                   'data' => ',',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 41,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'bash/zsh-only test for \'fork\' returning undef on failure',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'line' => 41,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 41,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'data' => '}',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 42,
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'line' => 44,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'done_testing',
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 44,
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 44,
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 44,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
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
            'end_line' => 6,
            'has_warnings' => 0,
            'start_line' => 6,
            'indent' => 1,
            'block_id' => 1,
            'token_num' => 6,
            'src' => ' chdir \'t\' if -d \'t\' ;'
          },
          {
            'end_line' => 7,
            'has_warnings' => 0,
            'start_line' => 7,
            'indent' => 1,
            'block_id' => 1,
            'token_num' => 4,
            'src' => ' @INC = \'../lib\' ;'
          },
          {
            'src' => ' require \'./test.pl\' ;',
            'token_num' => 3,
            'block_id' => 1,
            'start_line' => 8,
            'indent' => 1,
            'has_warnings' => 0,
            'end_line' => 8
          },
          {
            'block_id' => 1,
            'start_line' => 9,
            'indent' => 1,
            'token_num' => 3,
            'src' => ' require Config ;',
            'end_line' => 9,
            'has_warnings' => 0
          },
          {
            'start_line' => 10,
            'indent' => 1,
            'block_id' => 1,
            'src' => ' skip_all ( \'no fork\' ) unless ( $Config::Config { d_fork } or $Config::Config { d_pseudofork } ) ;',
            'token_num' => 17,
            'end_line' => 11,
            'has_warnings' => 1
          },
          {
            'end_line' => 13,
            'has_warnings' => 1,
            'start_line' => 12,
            'indent' => 1,
            'block_id' => 1,
            'token_num' => 11,
            'src' => ' skip_all ( \'no fork\' ) if $^O eq \'MSWin32\' && is_miniperl ;'
          },
          {
            'has_warnings' => 0,
            'end_line' => 16,
            'src' => ' $| = 1 ;',
            'token_num' => 4,
            'indent' => 0,
            'start_line' => 16,
            'block_id' => 0
          },
          {
            'end_line' => 18,
            'has_warnings' => 1,
            'start_line' => 18,
            'block_id' => 0,
            'indent' => 0,
            'token_num' => 8,
            'src' => ' run_multiple_progs ( \'\' , \\ *DATA ) ;'
          },
          {
            'end_line' => 20,
            'has_warnings' => 1,
            'start_line' => 20,
            'block_id' => 0,
            'indent' => 0,
            'token_num' => 10,
            'src' => ' my $shell = $ENV { SHELL } || \'\' ;'
          },
          {
            'block_id' => 2,
            'start_line' => 22,
            'indent' => 1,
            'token_num' => 10,
            'src' => ' skip "This test can only be run under bash or zsh" unless $shell =~ m{/(?:ba|z)sh$} ;',
            'end_line' => 23,
            'has_warnings' => 1
          },
          {
            'src' => ' my $probe = qx{
        $shell -c \'ulimit -u 1 2>&1 && echo good\'
    } ;',
            'token_num' => 8,
            'indent' => 1,
            'start_line' => 24,
            'block_id' => 2,
            'has_warnings' => 0,
            'end_line' => 27
          },
          {
            'start_line' => 28,
            'block_id' => 2,
            'indent' => 1,
            'token_num' => 3,
            'src' => ' chomp $probe ;',
            'end_line' => 28,
            'has_warnings' => 1
          },
          {
            'block_id' => 2,
            'start_line' => 29,
            'indent' => 1,
            'token_num' => 7,
            'src' => ' skip "Can\'t set ulimit -u on this system: $probe" unless $probe eq \'good\' ;',
            'end_line' => 30,
            'has_warnings' => 1
          },
          {
            'token_num' => 8,
            'src' => ' my $out = qx{
        $shell -c \'ulimit -u 1; exec $^X -e "
            print((() = fork) == 1 ? q[ok] : q[not ok])
        "\'
    } ;',
            'block_id' => 2,
            'start_line' => 32,
            'indent' => 1,
            'has_warnings' => 0,
            'end_line' => 37
          },
          {
            'src' => ' skip "fork() didn\'t fail, maybe you\'re running as root" , 1 if $out eq "okok" ;',
            'token_num' => 9,
            'block_id' => 2,
            'start_line' => 39,
            'indent' => 1,
            'has_warnings' => 1,
            'end_line' => 40
          },
          {
            'src' => ' is ( $out , "ok" , "bash/zsh-only test for \'fork\' returning undef on failure" ) ;',
            'token_num' => 9,
            'indent' => 1,
            'start_line' => 41,
            'block_id' => 2,
            'has_warnings' => 1,
            'end_line' => 41
          },
          {
            'indent' => 0,
            'start_line' => 44,
            'block_id' => 0,
            'src' => ' done_testing ( ) ;',
            'token_num' => 4,
            'end_line' => 44,
            'has_warnings' => 1
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
