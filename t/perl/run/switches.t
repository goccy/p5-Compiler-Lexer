use strict;
use warnings;
use Test::More;
BEGIN {
    use_ok('Compiler::Lexer');
}
my $script =<<'__SCRIPT__';
#!./perl -w

# Tests for the command-line switches:
# -0, -c, -l, -s, -m, -M, -V, -v, -h, -i, -E and all unknown
# Some switches have their own tests, see MANIFEST.

BEGIN {
    chdir 't' if -d 't';
    @INC = '../lib';
    require Config; import Config;
}

BEGIN { require "./test.pl";  require "./loc_tools.pl"; }

plan(tests => 115);

use Config;

# due to a bug in VMS's piping which makes it impossible for runperl()
# to emulate echo -n (ie. stdin always winds up with a newline), these 
# tests almost totally fail.
$TODO = "runperl() unable to emulate echo -n due to pipe bug" if $^O eq 'VMS';

my $r;
my @tmpfiles = ();
END { unlink_all @tmpfiles }

# Tests for -0

$r = runperl(
    switches	=> [ '-0', ],
    stdin	=> 'foo\0bar\0baz\0',
    prog	=> 'print qq(<$_>) while <>',
);
is( $r, "<foo\0><bar\0><baz\0>", "-0" );

$r = runperl(
    switches	=> [ '-l', '-0', '-p' ],
    stdin	=> 'foo\0bar\0baz\0',
    prog	=> '1',
);
is( $r, "foo\nbar\nbaz\n", "-0 after a -l" );

$r = runperl(
    switches	=> [ '-0', '-l', '-p' ],
    stdin	=> 'foo\0bar\0baz\0',
    prog	=> '1',
);
is( $r, "foo\0bar\0baz\0", "-0 before a -l" );

$r = runperl(
    switches	=> [ sprintf("-0%o", ord 'x') ],
    stdin	=> 'fooxbarxbazx',
    prog	=> 'print qq(<$_>) while <>',
);
is( $r, "<foox><barx><bazx>", "-0 with octal number" );

$r = runperl(
    switches	=> [ '-00', '-p' ],
    stdin	=> 'abc\ndef\n\nghi\njkl\nmno\n\npq\n',
    prog	=> 's/\n/-/g;$_.=q(/)',
);
is( $r, 'abc-def--/ghi-jkl-mno--/pq-/', '-00 (paragraph mode)' );

$r = runperl(
    switches	=> [ '-0777', '-p' ],
    stdin	=> 'abc\ndef\n\nghi\njkl\nmno\n\npq\n',
    prog	=> 's/\n/-/g;$_.=q(/)',
);
is( $r, 'abc-def--ghi-jkl-mno--pq-/', '-0777 (slurp mode)' );

$r = runperl(
    switches	=> [ '-066' ],
    prog	=> 'BEGIN { print qq{($/)} } print qq{[$/]}',
);
is( $r, "(\066)[\066]", '$/ set at compile-time' );

# Tests for -c

my $filename = tempfile();
SKIP: {
    local $TODO = '';   # this one works on VMS

    open my $f, ">$filename" or skip( "Can't write temp file $filename: $!" );
    print $f <<'SWTEST';
BEGIN { print "block 1\n"; }
CHECK { print "block 2\n"; }
INIT  { print "block 3\n"; }
	print "block 4\n";
END   { print "block 5\n"; }
SWTEST
    close $f or die "Could not close: $!";
    $r = runperl(
	switches	=> [ '-c' ],
	progfile	=> $filename,
	stderr		=> 1,
    );
    # Because of the stderr redirection, we can't tell reliably the order
    # in which the output is given
    ok(
	$r =~ /$filename syntax OK/
	&& $r =~ /\bblock 1\b/
	&& $r =~ /\bblock 2\b/
	&& $r !~ /\bblock 3\b/
	&& $r !~ /\bblock 4\b/
	&& $r !~ /\bblock 5\b/,
	'-c'
    );
}

SKIP: {
    skip 'locales not available', 1 unless locales_enabled('LC_ALL');

    my $tempdir = tempfile;
    mkdir $tempdir, 0700 or die "Can't mkdir '$tempdir': $!";

    local $ENV{'LC_ALL'} = 'C'; # Keep the test simple: expect English
    local $ENV{LANGUAGE} = 'C';
    setlocale(LC_ALL, "C");

    # Win32 won't let us open the directory, so we never get to die with
    # EISDIR, which happens after open.
    require Errno;
    import Errno qw(EACCES EISDIR);
    my $error  = do {
        local $! = $^O eq 'MSWin32' ? &EACCES : &EISDIR; "$!"
    };
    like(
        runperl( switches => [ '-c' ], args  => [ $tempdir ], stderr => 1),
        qr/Can't open perl script.*$tempdir.*\Q$error/s,
        "RT \#61362: Cannot syntax-check a directory"
    );
    rmdir $tempdir or die "Can't rmdir '$tempdir': $!";
}

# Tests for -l

$r = runperl(
    switches	=> [ sprintf("-l%o", ord 'x') ],
    prog	=> 'print for qw/foo bar/'
);
is( $r, 'fooxbarx', '-l with octal number' );

# Tests for -s

$r = runperl(
    switches	=> [ '-s' ],
    prog	=> 'for (qw/abc def ghi/) {print defined $$_ ? $$_ : q(-)}',
    args	=> [ '--', '-abc=2', '-def', ],
);
is( $r, '21-', '-s switch parsing' );

$filename = tempfile();
SKIP: {
    open my $f, ">$filename" or skip( "Can't write temp file $filename: $!" );
    print $f <<'SWTEST';
#!perl -s
BEGIN { print $x,$y; exit }
SWTEST
    close $f or die "Could not close: $!";
    $r = runperl(
	progfile    => $filename,
	args	    => [ '-x=foo -y' ],
    );
    is( $r, 'foo1', '-s on the shebang line' );
}

# Bug ID 20011106.084
$filename = tempfile();
SKIP: {
    open my $f, ">$filename" or skip( "Can't write temp file $filename: $!" );
    print $f <<'SWTEST';
#!perl -sn
BEGIN { print $x; exit }
SWTEST
    close $f or die "Could not close: $!";
    $r = runperl(
	progfile    => $filename,
	args	    => [ '-x=foo' ],
    );
    is( $r, 'foo', '-sn on the shebang line' );
}

# Tests for -m and -M

my $package = tempfile();
$filename = "$package.pm";
SKIP: {
    open my $f, ">$filename" or skip( "Can't write temp file $filename: $!",4 );
    print $f <<"SWTESTPM";
package $package;
sub import { print map "<\$_>", \@_ }
1;
SWTESTPM
    close $f or die "Could not close: $!";
    $r = runperl(
	switches    => [ "-M$package" ],
	prog	    => '1',
    );
    is( $r, "<$package>", '-M' );
    $r = runperl(
	switches    => [ "-M$package=foo" ],
	prog	    => '1',
    );
    is( $r, "<$package><foo>", '-M with import parameter' );
    $r = runperl(
	switches    => [ "-m$package" ],
	prog	    => '1',
    );

    {
        local $TODO = '';  # this one works on VMS
        is( $r, '', '-m' );
    }
    $r = runperl(
	switches    => [ "-m$package=foo,bar" ],
	prog	    => '1',
    );
    is( $r, "<$package><foo><bar>", '-m with import parameters' );
    push @tmpfiles, $filename;

  {
    local $TODO = '';  # these work on VMS

    is( runperl( switches => [ '-MTie::Hash' ], stderr => 1, prog => 1 ),
	  '', "-MFoo::Bar allowed" );

    like( runperl( switches => [ "-M:$package" ], stderr => 1,
		   prog => 'die q{oops}' ),
	  qr/Invalid module name [\w:]+ with -M option\b/,
          "-M:Foo not allowed" );

    like( runperl( switches => [ '-mA:B:C' ], stderr => 1,
		   prog => 'die q{oops}' ),
	  qr/Invalid module name [\w:]+ with -m option\b/,
          "-mFoo:Bar not allowed" );

    like( runperl( switches => [ '-m-A:B:C' ], stderr => 1,
		   prog => 'die q{oops}' ),
	  qr/Invalid module name [\w:]+ with -m option\b/,
          "-m-Foo:Bar not allowed" );

    like( runperl( switches => [ '-m-' ], stderr => 1,
		   prog => 'die q{oops}' ),
	  qr/Module name required with -m option\b/,
  	  "-m- not allowed" );

    like( runperl( switches => [ '-M-=' ], stderr => 1,
		   prog => 'die q{oops}' ),
	  qr/Module name required with -M option\b/,
  	  "-M- not allowed" );
  }  # disable TODO on VMS
}
is runperl(stderr => 1, prog => '#!perl -m'),
   qq 'Too late for "-m" option at -e line 1.\n', '#!perl -m';
is runperl(stderr => 1, prog => '#!perl -M'),
   qq 'Too late for "-M" option at -e line 1.\n', '#!perl -M';

# Tests for -V

{
    local $TODO = '';   # these ones should work on VMS

    # basic perl -V should generate significant output.
    # we don't test actual format too much since it could change
    like( runperl( switches => ['-V'] ), qr/(\n.*){20}/,
          '-V generates 20+ lines' );

    like( runperl( switches => ['-V'] ),
	  qr/\ASummary of my perl5 .*configuration:/,
          '-V looks okay' );

    # lookup a known config var
    chomp( $r=runperl( switches => ['-V:osname'] ) );
    is( $r, "osname='$^O';", 'perl -V:osname');

    # lookup a nonexistent var
    chomp( $r=runperl( switches => ['-V:this_var_makes_switches_test_fail'] ) );
    is( $r, "this_var_makes_switches_test_fail='UNKNOWN';",
        'perl -V:unknown var');

    # regexp lookup
    # platforms that don't like this quoting can either skip this test
    # or fix test.pl _quote_args
    $r = runperl( switches => ['"-V:i\D+size"'] );
    # should be unlike( $r, qr/^$|not found|UNKNOWN/ );
    like( $r, qr/^(?!.*(not found|UNKNOWN))./, 'perl -V:re got a result' );

    # make sure each line we got matches the re
    ok( !( grep !/^i\D+size=/, split /^/, $r ), '-V:re correct' );
}

# Tests for -v

{
    local $TODO = '';   # these ones should work on VMS
    # there are definitely known build configs where this test will fail
    # DG/UX comes to mind. Maybe we should remove these special cases?
  SKIP:
    {
        skip "Win32 miniperl produces a default archname in -v", 1
	  if $^O eq 'MSWin32' && is_miniperl;
        my $v = sprintf "%vd", $^V;
        my $ver = $Config{PERL_VERSION};
        my $rel = $Config{PERL_SUBVERSION};
        like( runperl( switches => ['-v'] ),
	      qr/This is perl 5, version \Q$ver\E, subversion \Q$rel\E \(v\Q$v\E(?:[-*\w]+| \([^)]+\))?\) built for \Q$Config{archname}\E.+Copyright.+Larry Wall.+Artistic License.+GNU General Public License/s,
              '-v looks okay' );
    }
}

# Tests for -h

{
    local $TODO = '';   # these ones should work on VMS

    like( runperl( switches => ['-h'] ),
	  qr/Usage: .+(?i:perl(?:$Config{_exe})?).+switches.+programfile.+arguments/,
          '-h looks okay' );

}

# Tests for switches which do not exist

foreach my $switch (split //, "ABbGgHJjKkLNOoPQqRrYyZz123456789_")
{
    local $TODO = '';   # these ones should work on VMS

    like( runperl( switches => ["-$switch"], stderr => 1,
		   prog => 'die q{oops}' ),
	  qr/\QUnrecognized switch: -$switch  (-h will show valid options)./,
          "-$switch correctly unknown" );

    # [perl #104288]
    like( runperl( stderr => 1, prog => "#!perl -$switch" ),
	  qr/^Unrecognized switch: -$switch  \(-h will show valid (?x:
	     )options\) at -e line 1\./,
          "-$switch unrecognised on #! line" );
}

# Tests for unshebangable switches
for (qw( e f x E S V )) {
    $r = runperl(
	stderr   => 1,
	prog     => "#!perl -$_",
    );
    is $r, "Can't emulate -$_ on #! line at -e line 1.\n","-$_ on #! line";
}

# Tests for -i

{
    local $TODO = '';   # these ones should work on VMS

    sub do_i_unlink { unlink_all("file", "file.bak") }

    open(FILE, ">file") or die "$0: Failed to create 'file': $!";
    print FILE <<__EOF__;
foo yada dada
bada foo bing
king kong foo
__EOF__
    close FILE;

    END { do_i_unlink() }

    runperl( switches => ['-pi.bak'], prog => 's/foo/bar/', args => ['file'] );

    open(FILE, "file") or die "$0: Failed to open 'file': $!";
    chomp(my @file = <FILE>);
    close FILE;

    open(BAK, "file.bak") or die "$0: Failed to open 'file': $!";
    chomp(my @bak = <BAK>);
    close BAK;

    is(join(":", @file),
       "bar yada dada:bada bar bing:king kong bar",
       "-i new file");
    is(join(":", @bak),
       "foo yada dada:bada foo bing:king kong foo",
       "-i backup file");

    my $out1 = runperl(
        switches => ['-i.bak -p'],
        prog     => 'exit',
        stderr   => 1,
        stdin    => "1\n",
    );
    is(
        $out1,
        "-i used with no filenames on the command line, reading from STDIN.\n",
        "warning when no files given"
    );
    my $out2 = runperl(
        switches => ['-i.bak -p'],
        prog     => 'exit',
        stderr   => 1,
        stdin    => "1\n",
        args     => ['file'],
    );
    is($out2, "", "no warning when files given");
}

# Tests for -E

$TODO = '';  # the -E tests work on VMS

$r = runperl(
    switches	=> [ '-E', '"say q(Hello, world!)"']
);
is( $r, "Hello, world!\n", "-E say" );


$r = runperl(
    switches	=> [ '-E', '"no warnings q{experimental::smartmatch}; undef ~~ undef and say q(Hello, world!)"']
);
is( $r, "Hello, world!\n", "-E ~~" );

$r = runperl(
    switches	=> [ '-E', '"no warnings q{experimental::smartmatch}; given(undef) {when(undef) { say q(Hello, world!)"}}']
);
is( $r, "Hello, world!\n", "-E given" );

$r = runperl(
    switches    => [ '-nE', q("} END { say q/affe/") ],
    stdin       => 'zomtek',
);
is( $r, "affe\n", '-E works outside of the block created by -n' );

$r = runperl(
    switches	=> [ '-E', q("*{'bar'} = sub{}; print 'Hello, world!',qq|\n|;")]
);
is( $r, "Hello, world!\n", "-E does not enable strictures" );

# RT #30660

$filename = tempfile();
SKIP: {
    open my $f, ">$filename" or skip( "Can't write temp file $filename: $!" );
    print $f <<'SWTEST';
#!perl -w    -iok
print "$^I\n";
SWTEST
    close $f or die "Could not close: $!";
    $r = runperl(
	progfile    => $filename,
    );
    like( $r, qr/ok/, 'Spaces on the #! line (#30660)' );
}

__SCRIPT__

subtest 'tokenize' => sub {
    my $tokens = Compiler::Lexer->new('')->tokenize($script);
    is_deeply($tokens, [
          bless( {
                   'name' => 'ModWord',
                   'type' => Compiler::Lexer::TokenType::T_ModWord,
                   'has_warnings' => 0,
                   'data' => 'BEGIN',
                   'line' => 7,
                   'kind' => Compiler::Lexer::Kind::T_ModWord,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 7,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 8,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'chdir',
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'has_warnings' => 0,
                   'data' => 't',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 8
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'if',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'name' => 'IfStmt',
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 8
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Handle',
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'has_warnings' => 0,
                   'data' => '-d',
                   'line' => 8,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Handle
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 't',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 8
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 8
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 9,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'data' => '@INC',
                   'name' => 'LibraryDirectories',
                   'type' => Compiler::Lexer::TokenType::T_LibraryDirectories
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'data' => '=',
                   'has_warnings' => 0,
                   'line' => 9,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 9,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '../lib',
                   'has_warnings' => 0,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 9,
                   'has_warnings' => 0,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'require',
                   'type' => Compiler::Lexer::TokenType::T_RequireDecl,
                   'name' => 'RequireDecl',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 10
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RequiredName',
                   'type' => Compiler::Lexer::TokenType::T_RequiredName,
                   'data' => 'Config',
                   'has_warnings' => 0,
                   'line' => 10,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Module
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 10,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 10,
                   'kind' => Compiler::Lexer::Kind::T_Import,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'import',
                   'name' => 'Import',
                   'type' => Compiler::Lexer::TokenType::T_Import
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 10,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'Config',
                   'has_warnings' => 1,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 10
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 11
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 13,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_ModWord,
                   'name' => 'ModWord',
                   'type' => Compiler::Lexer::TokenType::T_ModWord,
                   'has_warnings' => 0,
                   'data' => 'BEGIN'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 13,
                   'data' => '{',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'require',
                   'has_warnings' => 0,
                   'name' => 'RequireDecl',
                   'type' => Compiler::Lexer::TokenType::T_RequireDecl,
                   'line' => 13,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => './test.pl',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 13
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 13,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RequireDecl,
                   'name' => 'RequireDecl',
                   'data' => 'require',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 13
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 13,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => './loc_tools.pl',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 13,
                   'data' => ';',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0,
                   'data' => '}',
                   'line' => 13,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'plan',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 15
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 15,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'tests',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 15
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=>',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 15
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '115',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 15
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 15,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 15,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'UseDecl',
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'has_warnings' => 0,
                   'data' => 'use',
                   'line' => 17,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'Config',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'name' => 'UsedName',
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 17
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 17,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$TODO',
                   'name' => 'GlobalVar',
                   'type' => Compiler::Lexer::TokenType::T_GlobalVar,
                   'line' => 22,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 22
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'has_warnings' => 0,
                   'data' => 'runperl() unable to emulate echo -n due to pipe bug',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 22
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'name' => 'IfStmt',
                   'data' => 'if',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 22
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 22,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$^O',
                   'has_warnings' => 0,
                   'name' => 'SpecificValue',
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'eq',
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'name' => 'StringEqual',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 22
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'has_warnings' => 0,
                   'data' => 'VMS',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 22
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 22,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'my',
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'line' => 24,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$r',
                   'name' => 'LocalVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'line' => 24,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 24,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 25,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl',
                   'has_warnings' => 0,
                   'data' => 'my'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 25,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '@tmpfiles',
                   'has_warnings' => 0,
                   'name' => 'LocalArrayVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalArrayVar
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '=',
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'line' => 25,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 25,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 25,
                   'data' => ')',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 25,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_ModWord,
                   'name' => 'ModWord',
                   'has_warnings' => 0,
                   'data' => 'END',
                   'kind' => Compiler::Lexer::Kind::T_ModWord,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 26
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 26,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '{',
                   'has_warnings' => 0,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 26,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'unlink_all',
                   'has_warnings' => 1,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'ArrayVar',
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar,
                   'data' => '@tmpfiles',
                   'has_warnings' => 0,
                   'line' => 26,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 26,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'has_warnings' => 0,
                   'data' => '}'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'data' => '$r',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 30
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 30
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'runperl',
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 30
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 30,
                   'data' => '(',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 31,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 0,
                   'data' => 'switches'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'data' => '=>',
                   'has_warnings' => 0,
                   'line' => 31,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '[',
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'line' => 31,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-0',
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'line' => 31,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 31,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 31,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'has_warnings' => 0,
                   'data' => ']'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 31,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'stdin',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 32
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '=>',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 32
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'foo\\0bar\\0baz\\0',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 32
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 32,
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 33,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 0,
                   'data' => 'prog'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 33,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'has_warnings' => 0,
                   'data' => '=>'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 33,
                   'data' => 'print qq(<$_>) while <>',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 33
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'line' => 34,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 34
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 35,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'data' => 'is'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'has_warnings' => 0,
                   'line' => 35,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 35,
                   'has_warnings' => 0,
                   'data' => '$r',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 35,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => '<foo\\0><bar\\0><baz\\0>',
                   'has_warnings' => 0,
                   'line' => 35,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 35,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'has_warnings' => 0,
                   'data' => '-0',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 35
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'has_warnings' => 0,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'line' => 35,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 35,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$r',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 37
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'has_warnings' => 0,
                   'data' => '=',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 37
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 37,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'data' => 'runperl',
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 37
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 38,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'switches',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'data' => '=>',
                   'has_warnings' => 0,
                   'line' => 38,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 38,
                   'has_warnings' => 0,
                   'data' => '[',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-l',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 38
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 38,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 38,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'data' => '-0',
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 38,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-p',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 38
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'name' => 'RightBracket',
                   'has_warnings' => 0,
                   'data' => ']',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 38
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'data' => ',',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 38
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 39,
                   'has_warnings' => 0,
                   'data' => 'stdin',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 39,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'data' => 'foo\\0bar\\0baz\\0',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 39
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 39,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 0,
                   'data' => 'prog',
                   'line' => 40,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 40,
                   'data' => '=>',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'has_warnings' => 0,
                   'data' => '1',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 40
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 40,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 41,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 41,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 42,
                   'data' => 'is',
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 42,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 42,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$r',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 42,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'data' => 'foo\\nbar\\nbaz\\n',
                   'line' => 42,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 42,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => '-0 after a -l',
                   'has_warnings' => 0,
                   'line' => 42,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 42,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 42,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$r',
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'line' => 44,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 44,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '=',
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'runperl',
                   'has_warnings' => 1,
                   'line' => 44,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 44,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'has_warnings' => 0,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 45,
                   'data' => 'switches',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '=>',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 45
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'data' => '[',
                   'has_warnings' => 0,
                   'line' => 45,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'has_warnings' => 0,
                   'data' => '-0',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 45
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 45,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-l',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 45
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'has_warnings' => 0,
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 45
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 45,
                   'has_warnings' => 0,
                   'data' => '-p',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ']',
                   'has_warnings' => 0,
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'line' => 45,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 45,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'stdin',
                   'has_warnings' => 0,
                   'line' => 46,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'data' => 'foo\\0bar\\0baz\\0',
                   'line' => 46,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 46,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 47,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'prog',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'has_warnings' => 0,
                   'data' => '=>',
                   'line' => 47,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '1',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 47
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 47,
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 48
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 48,
                   'data' => ';',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 49,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'data' => 'is'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 49
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 49,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$r',
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 49,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 49,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'data' => 'foo\\0bar\\0baz\\0'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 49,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 49,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => '-0 before a -l',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 49,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => ')',
                   'has_warnings' => 0,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 49,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'data' => '$r',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 51
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'data' => '=',
                   'has_warnings' => 0,
                   'line' => 51,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'runperl',
                   'has_warnings' => 1,
                   'line' => 51,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 51,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 0,
                   'data' => 'switches',
                   'line' => 52,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 52,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 52,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '[',
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'sprintf',
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'line' => 52,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 52,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'data' => '-0%o',
                   'line' => 52,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 52,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 52,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'ord',
                   'has_warnings' => 0,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'x',
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'line' => 52,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 52
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 52,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'data' => ']',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 52,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 53,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 0,
                   'data' => 'stdin'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=>',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 53
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 53,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'fooxbarxbazx',
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 53,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 54,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'prog',
                   'has_warnings' => 0,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '=>',
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'line' => 54,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'print qq(<$_>) while <>',
                   'has_warnings' => 0,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'line' => 54,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 54,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 55,
                   'data' => ')',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 55,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 56,
                   'has_warnings' => 1,
                   'data' => 'is',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 56,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$r',
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'line' => 56,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 56,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 56,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => '<foox><barx><bazx>',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 56,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-0 with octal number',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 56
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 56,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 56,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 58,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'data' => '$r',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'has_warnings' => 0,
                   'data' => '=',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 58
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'runperl',
                   'has_warnings' => 1,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 58,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 58,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 59,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'data' => 'switches',
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 59,
                   'data' => '=>',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 59,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'data' => '[',
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-00',
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'line' => 59,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 59,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 59,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'data' => '-p'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 59,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'data' => ']',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'data' => ',',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 59
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 60,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 0,
                   'data' => 'stdin'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'has_warnings' => 0,
                   'data' => '=>',
                   'line' => 60,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 60,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'abc\\ndef\\n\\nghi\\njkl\\nmno\\n\\npq\\n',
                   'has_warnings' => 0,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 60,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 0,
                   'data' => 'prog',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 61
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'data' => '=>',
                   'has_warnings' => 0,
                   'line' => 61,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 61,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'data' => 's/\\n/-/g;$_.=q(/)',
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 61
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 62,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 62
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 63,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'is',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 63,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$r',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 63
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 63,
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 63,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'abc-def--/ghi-jkl-mno--/pq-/',
                   'has_warnings' => 0,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 63,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-00 (paragraph mode)',
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'line' => 63,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 63,
                   'has_warnings' => 0,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 63,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 65,
                   'data' => '$r',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 1,
                   'data' => 'runperl',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 65,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 66,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 0,
                   'data' => 'switches'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '=>',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 66
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 66
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-0777',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 66
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 66,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-p',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 66
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'has_warnings' => 0,
                   'data' => ']',
                   'line' => 66,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'data' => ',',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 66
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 67,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'stdin',
                   'has_warnings' => 0,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 67,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '=>',
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 67,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'data' => 'abc\\ndef\\n\\nghi\\njkl\\nmno\\n\\npq\\n',
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'data' => ',',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 67
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 0,
                   'data' => 'prog',
                   'line' => 68,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'has_warnings' => 0,
                   'data' => '=>',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 68
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 68,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'data' => 's/\\n/-/g;$_.=q(/)',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 68,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'has_warnings' => 0,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'line' => 69,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 69,
                   'has_warnings' => 0,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 70,
                   'data' => 'is',
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 70,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 70,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'data' => '$r'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 70,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 70,
                   'data' => 'abc-def--ghi-jkl-mno--pq-/',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 70
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-0777 (slurp mode)',
                   'has_warnings' => 0,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'line' => 70,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 70,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 70
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$r',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 72
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 72,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'data' => '=',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'runperl',
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 72
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 72,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'switches',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 73
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 73,
                   'has_warnings' => 0,
                   'data' => '=>',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 73,
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket',
                   'has_warnings' => 0,
                   'data' => '['
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => '-066',
                   'has_warnings' => 0,
                   'line' => 73,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 73,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'name' => 'RightBracket',
                   'has_warnings' => 0,
                   'data' => ']'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 73,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 74,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'prog',
                   'has_warnings' => 0,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 74,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'has_warnings' => 0,
                   'data' => '=>'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 74,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'data' => 'BEGIN { print qq{($/)} } print qq{[$/]}',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 74,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'line' => 75,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 75
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'is',
                   'has_warnings' => 1,
                   'line' => 76,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 76,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 76,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '$r',
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 76,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'data' => '(\\066)[\\066]',
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 76,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 76,
                   'has_warnings' => 0,
                   'data' => '$/ set at compile-time',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 76,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'has_warnings' => 0,
                   'data' => 'my',
                   'line' => 80,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$filename',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 80,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'data' => '=',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 80,
                   'data' => 'tempfile',
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'has_warnings' => 0,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'line' => 80,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 80,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'SKIP',
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 81
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 81,
                   'kind' => Compiler::Lexer::Kind::T_Colon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ':',
                   'has_warnings' => 0,
                   'name' => 'Colon',
                   'type' => Compiler::Lexer::TokenType::T_Colon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 81,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'has_warnings' => 0,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 82,
                   'has_warnings' => 0,
                   'data' => 'local',
                   'type' => Compiler::Lexer::TokenType::T_LocalDecl,
                   'name' => 'LocalDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 82,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'data' => '$TODO',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 82,
                   'has_warnings' => 0,
                   'data' => '=',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 82,
                   'has_warnings' => 0,
                   'data' => '',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 82,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 84,
                   'has_warnings' => 0,
                   'data' => 'open',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 84,
                   'has_warnings' => 0,
                   'data' => 'my',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar',
                   'data' => '$f',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 84
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 84,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 84,
                   'data' => '>$filename',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'name' => 'AlphabetOr',
                   'data' => 'or',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 84
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 84,
                   'has_warnings' => 1,
                   'data' => 'skip',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 84,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'Can\'t write temp file $filename: $!',
                   'has_warnings' => 0,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'line' => 84,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'line' => 84,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 84,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 85,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'data' => 'print',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 85,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'data' => '$f'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 85,
                   'type' => Compiler::Lexer::TokenType::T_LeftShift,
                   'name' => 'LeftShift',
                   'data' => '<<',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'SWTEST',
                   'type' => Compiler::Lexer::TokenType::T_HereDocumentRawTag,
                   'name' => 'HereDocumentRawTag',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 85
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 85,
                   'data' => ';',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'BEGIN { print "block 1\\n"; }
CHECK { print "block 2\\n"; }
INIT  { print "block 3\\n"; }
	print "block 4\\n";
END   { print "block 5\\n"; }
',
                   'has_warnings' => 0,
                   'name' => 'HereDocument',
                   'type' => Compiler::Lexer::TokenType::T_HereDocument,
                   'line' => 91,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 91,
                   'type' => Compiler::Lexer::TokenType::T_HereDocumentEnd,
                   'name' => 'HereDocumentEnd',
                   'has_warnings' => 0,
                   'data' => 'SWTEST'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'close',
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'line' => 92,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$f',
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'line' => 92,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'name' => 'AlphabetOr',
                   'data' => 'or',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 92
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 92,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'data' => 'die',
                   'has_warnings' => 0,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'has_warnings' => 0,
                   'data' => 'Could not close: $!',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 92
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 92,
                   'has_warnings' => 0,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 93,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'data' => '$r',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'has_warnings' => 0,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'line' => 93,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 93,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'runperl',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 93,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 94,
                   'data' => 'switches',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '=>',
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'line' => 94,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'has_warnings' => 0,
                   'data' => '[',
                   'line' => 94,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'data' => '-c',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 94
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ']',
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'line' => 94,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'has_warnings' => 0,
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 94
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 95,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'progfile',
                   'has_warnings' => 0,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 95,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'data' => '=>',
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$filename',
                   'has_warnings' => 0,
                   'line' => 95,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 95,
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 0,
                   'data' => 'stderr',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 96
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '=>',
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'line' => 96,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '1',
                   'has_warnings' => 0,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'line' => 96,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 96
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 97
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 97,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 100,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 1,
                   'data' => 'ok'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 100
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$r',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 101
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 101,
                   'data' => '=~',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegOK,
                   'name' => 'RegOK'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '/',
                   'has_warnings' => 0,
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'line' => 101,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegExp',
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'has_warnings' => 0,
                   'data' => '$filename syntax OK',
                   'line' => 101,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 101,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '/',
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '&&',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_And,
                   'name' => 'And',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 102
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$r',
                   'has_warnings' => 0,
                   'line' => 102,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=~',
                   'has_warnings' => 0,
                   'name' => 'RegOK',
                   'type' => Compiler::Lexer::TokenType::T_RegOK,
                   'line' => 102,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'has_warnings' => 0,
                   'data' => '/',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 102
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 102,
                   'has_warnings' => 0,
                   'data' => '\\bblock 1\\b',
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'name' => 'RegExp'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 102,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '/',
                   'has_warnings' => 0,
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 103,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'And',
                   'type' => Compiler::Lexer::TokenType::T_And,
                   'data' => '&&',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$r',
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'line' => 103,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 103,
                   'type' => Compiler::Lexer::TokenType::T_RegOK,
                   'name' => 'RegOK',
                   'has_warnings' => 0,
                   'data' => '=~'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 103,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'data' => '/',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 103,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '\\bblock 2\\b',
                   'name' => 'RegExp',
                   'type' => Compiler::Lexer::TokenType::T_RegExp
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'has_warnings' => 0,
                   'data' => '/',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 103
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '&&',
                   'has_warnings' => 0,
                   'name' => 'And',
                   'type' => Compiler::Lexer::TokenType::T_And,
                   'line' => 104,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 104,
                   'has_warnings' => 0,
                   'data' => '$r',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 104,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'RegNot',
                   'type' => Compiler::Lexer::TokenType::T_RegNot,
                   'has_warnings' => 0,
                   'data' => '!~'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 104,
                   'data' => '/',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'name' => 'RegExp',
                   'has_warnings' => 0,
                   'data' => '\\bblock 3\\b',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 104
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 104,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 105,
                   'data' => '&&',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_And,
                   'name' => 'And'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$r',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 105
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 105,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'RegNot',
                   'type' => Compiler::Lexer::TokenType::T_RegNot,
                   'has_warnings' => 0,
                   'data' => '!~'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 105,
                   'data' => '/',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 105,
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'name' => 'RegExp',
                   'has_warnings' => 0,
                   'data' => '\\bblock 4\\b'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 105,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '/',
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '&&',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_And,
                   'name' => 'And',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 106
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'data' => '$r',
                   'line' => 106,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegNot,
                   'name' => 'RegNot',
                   'data' => '!~',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 106
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'has_warnings' => 0,
                   'data' => '/',
                   'line' => 106,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'name' => 'RegExp',
                   'data' => '\\bblock 5\\b',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 106
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '/',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 106
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 106,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 107,
                   'has_warnings' => 0,
                   'data' => '-c',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 108,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 108,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'has_warnings' => 0,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'line' => 109,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 1,
                   'data' => 'SKIP',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 111
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ':',
                   'type' => Compiler::Lexer::TokenType::T_Colon,
                   'name' => 'Colon',
                   'kind' => Compiler::Lexer::Kind::T_Colon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 111
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 111,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 112,
                   'data' => 'skip',
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 112,
                   'data' => 'locales not available',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 112,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 112,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '1',
                   'has_warnings' => 0,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'unless',
                   'name' => 'UnlessStmt',
                   'type' => Compiler::Lexer::TokenType::T_UnlessStmt,
                   'line' => 112,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'locales_enabled',
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 112,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'has_warnings' => 0,
                   'line' => 112,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'data' => 'LC_ALL',
                   'line' => 112,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 112,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 112,
                   'data' => ';',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'my',
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'line' => 114,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 114,
                   'data' => '$tempdir',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'data' => '=',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 114
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'tempfile',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 114
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 114,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 115,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'data' => 'mkdir',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$tempdir',
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'line' => 115,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 115,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 115,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '0700',
                   'has_warnings' => 0,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 115,
                   'has_warnings' => 0,
                   'data' => 'or',
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'name' => 'AlphabetOr'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 115,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'die',
                   'has_warnings' => 0,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'data' => 'Can\'t mkdir \'$tempdir\': $!',
                   'line' => 115,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 115,
                   'data' => ';',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LocalDecl,
                   'name' => 'LocalDecl',
                   'data' => 'local',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 117
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 117,
                   'has_warnings' => 0,
                   'data' => '$ENV',
                   'type' => Compiler::Lexer::TokenType::T_GlobalVar,
                   'name' => 'GlobalVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 117,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '{',
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'data' => 'LC_ALL',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 117
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 117,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}',
                   'has_warnings' => 0,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'data' => '=',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 117
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 117,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'data' => 'C'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 117,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 118,
                   'data' => 'local',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalDecl,
                   'name' => 'LocalDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 118,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'data' => '$ENV',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 118,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 118,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 0,
                   'data' => 'LANGUAGE'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 118,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}',
                   'has_warnings' => 0,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 118,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '=',
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 118,
                   'has_warnings' => 0,
                   'data' => 'C',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 118,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 1,
                   'data' => 'setlocale',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 119
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 119,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'LC_ALL',
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 119
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 119,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 119,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'data' => 'C',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 119,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 119,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RequireDecl',
                   'type' => Compiler::Lexer::TokenType::T_RequireDecl,
                   'has_warnings' => 0,
                   'data' => 'require',
                   'line' => 123,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RequiredName',
                   'type' => Compiler::Lexer::TokenType::T_RequiredName,
                   'data' => 'Errno',
                   'has_warnings' => 0,
                   'line' => 123,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Module
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 123,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Import',
                   'type' => Compiler::Lexer::TokenType::T_Import,
                   'has_warnings' => 0,
                   'data' => 'import',
                   'line' => 124,
                   'kind' => Compiler::Lexer::Kind::T_Import,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'Errno',
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 124
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 124,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'has_warnings' => 0,
                   'data' => 'qw',
                   'name' => 'RegList',
                   'type' => Compiler::Lexer::TokenType::T_RegList
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'data' => '(',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 124
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'EACCES EISDIR',
                   'name' => 'RegExp',
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'line' => 124,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 124,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'data' => ')',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 124,
                   'data' => ';',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 125,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'has_warnings' => 0,
                   'data' => 'my'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 125,
                   'has_warnings' => 0,
                   'data' => '$error',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 125,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'data' => '=',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Do',
                   'type' => Compiler::Lexer::TokenType::T_Do,
                   'data' => 'do',
                   'has_warnings' => 0,
                   'line' => 125,
                   'kind' => Compiler::Lexer::Kind::T_Do,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 125
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 126,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'local',
                   'name' => 'LocalDecl',
                   'type' => Compiler::Lexer::TokenType::T_LocalDecl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SpecificValue',
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'has_warnings' => 0,
                   'data' => '$!',
                   'line' => 126,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 126,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=',
                   'has_warnings' => 0,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$^O',
                   'has_warnings' => 0,
                   'name' => 'SpecificValue',
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'line' => 126,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 126,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'eq',
                   'has_warnings' => 0,
                   'name' => 'StringEqual',
                   'type' => Compiler::Lexer::TokenType::T_StringEqual
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 126,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'data' => 'MSWin32'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 126,
                   'data' => '?',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ThreeTermOperator,
                   'name' => 'ThreeTermOperator'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_BitAnd,
                   'name' => 'BitAnd',
                   'has_warnings' => 0,
                   'data' => '&',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 126
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'EACCES',
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 126,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Colon,
                   'name' => 'Colon',
                   'data' => ':',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Colon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 126
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_BitAnd,
                   'name' => 'BitAnd',
                   'has_warnings' => 0,
                   'data' => '&',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 126
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'EISDIR',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 126
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 126,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 126,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'has_warnings' => 0,
                   'data' => '$!'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'has_warnings' => 0,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'line' => 127,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 127,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'like',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 128
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 128,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 129,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'runperl',
                   'has_warnings' => 1,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 129,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 129,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 0,
                   'data' => 'switches'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=>',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 129
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 129,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'data' => '[',
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 129,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '-c',
                   'has_warnings' => 0,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 129,
                   'has_warnings' => 0,
                   'data' => ']',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'name' => 'RightBracket'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 129,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 129,
                   'data' => 'args',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'has_warnings' => 0,
                   'data' => '=>',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 129
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket',
                   'has_warnings' => 0,
                   'data' => '[',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 129
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 129,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$tempdir',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 129,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'name' => 'RightBracket',
                   'data' => ']',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 129,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'stderr',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 129
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 129,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'has_warnings' => 0,
                   'data' => '=>'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 129,
                   'data' => '1',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'has_warnings' => 0,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'line' => 129,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 129,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 130,
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'qr',
                   'name' => 'RegDecl',
                   'type' => Compiler::Lexer::TokenType::T_RegDecl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'data' => '/',
                   'has_warnings' => 0,
                   'line' => 130,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'Can\'t open perl script.*$tempdir.*\\Q$error',
                   'name' => 'RegExp',
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'line' => 130,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'has_warnings' => 0,
                   'data' => '/',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 130
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegOpt',
                   'type' => Compiler::Lexer::TokenType::T_RegOpt,
                   'data' => 's',
                   'has_warnings' => 0,
                   'line' => 130,
                   'kind' => Compiler::Lexer::Kind::T_RegOpt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 130,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'data' => 'RT \\#61362: Cannot syntax-check a directory',
                   'line' => 131,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 132,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'has_warnings' => 0,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 132,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'rmdir',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 133
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 133,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$tempdir',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 133,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'or',
                   'name' => 'AlphabetOr',
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 133,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'has_warnings' => 0,
                   'data' => 'die'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'Can\'t rmdir \'$tempdir\': $!',
                   'has_warnings' => 0,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'line' => 133,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 133,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 134,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0,
                   'data' => '}'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$r',
                   'has_warnings' => 0,
                   'line' => 138,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 138,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'has_warnings' => 0,
                   'data' => '=',
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 138,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'runperl',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'line' => 138,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'switches',
                   'has_warnings' => 0,
                   'line' => 139,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 139
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'has_warnings' => 0,
                   'data' => '[',
                   'line' => 139,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'data' => 'sprintf',
                   'line' => 139,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 139
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => '-l%o',
                   'has_warnings' => 0,
                   'line' => 139,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'data' => ',',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 139
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 139,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'has_warnings' => 0,
                   'data' => 'ord'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 139,
                   'has_warnings' => 0,
                   'data' => 'x',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 139,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'has_warnings' => 0,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'name' => 'RightBracket',
                   'data' => ']',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 139
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 139,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 140,
                   'has_warnings' => 0,
                   'data' => 'prog',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=>',
                   'has_warnings' => 0,
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'line' => 140,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 140,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'has_warnings' => 0,
                   'data' => 'print for qw/foo bar/'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 141,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 141,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 1,
                   'data' => 'is',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 142
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 142,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 142,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'data' => '$r',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 142,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 142,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'data' => 'fooxbarx',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 142,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'has_warnings' => 0,
                   'data' => '-l with octal number',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 142
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0,
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 142
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 142
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 146,
                   'has_warnings' => 0,
                   'data' => '$r',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '=',
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'line' => 146,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'runperl',
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 146
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 146,
                   'has_warnings' => 0,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 147,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'switches',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 147,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'data' => '=>',
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 147
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => '-s',
                   'has_warnings' => 0,
                   'line' => 147,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'has_warnings' => 0,
                   'data' => ']',
                   'line' => 147,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 147,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 148,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'prog',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 148,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'data' => '=>',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 148,
                   'data' => 'for (qw/abc def ghi/) {print defined $$_ ? $$_ : q(-)}',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 148,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 0,
                   'data' => 'args',
                   'line' => 149,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=>',
                   'has_warnings' => 0,
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'line' => 149,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 149
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '--',
                   'has_warnings' => 0,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'line' => 149,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 149,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 149,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => '-abc=2',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 149,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 149,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'data' => '-def'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'data' => ',',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 149
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ']',
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'line' => 149,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 149,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 150,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 150,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 151,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'is',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'has_warnings' => 0,
                   'line' => 151,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 151,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'data' => '$r'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 151,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => '21-',
                   'has_warnings' => 0,
                   'line' => 151,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 151,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'data' => '-s switch parsing',
                   'line' => 151,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 151,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 151,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$filename',
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'line' => 153,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'has_warnings' => 0,
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 153
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 153,
                   'data' => 'tempfile',
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'has_warnings' => 0,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'line' => 153,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0,
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 153
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 153,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'SKIP',
                   'has_warnings' => 1,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 154,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Colon',
                   'type' => Compiler::Lexer::TokenType::T_Colon,
                   'data' => ':',
                   'has_warnings' => 0,
                   'line' => 154,
                   'kind' => Compiler::Lexer::Kind::T_Colon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'has_warnings' => 0,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'line' => 154,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 155,
                   'has_warnings' => 0,
                   'data' => 'open',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl',
                   'has_warnings' => 0,
                   'data' => 'my',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 155
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 155,
                   'data' => '$f',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 155
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '>$filename',
                   'has_warnings' => 0,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'line' => 155,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 155,
                   'has_warnings' => 0,
                   'data' => 'or',
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'name' => 'AlphabetOr'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 155,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'skip',
                   'has_warnings' => 1,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 155,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 155,
                   'has_warnings' => 0,
                   'data' => 'Can\'t write temp file $filename: $!',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 155
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 155
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'data' => 'print',
                   'line' => 156,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$f',
                   'has_warnings' => 0,
                   'line' => 156,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 156,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'LeftShift',
                   'type' => Compiler::Lexer::TokenType::T_LeftShift,
                   'has_warnings' => 0,
                   'data' => '<<'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'SWTEST',
                   'has_warnings' => 0,
                   'name' => 'HereDocumentRawTag',
                   'type' => Compiler::Lexer::TokenType::T_HereDocumentRawTag,
                   'line' => 156,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 156
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 159,
                   'type' => Compiler::Lexer::TokenType::T_HereDocument,
                   'name' => 'HereDocument',
                   'has_warnings' => 0,
                   'data' => '#!perl -s
BEGIN { print $x,$y; exit }
'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 159,
                   'type' => Compiler::Lexer::TokenType::T_HereDocumentEnd,
                   'name' => 'HereDocumentEnd',
                   'has_warnings' => 0,
                   'data' => 'SWTEST'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 160,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'data' => 'close',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$f',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 160
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 160,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'or',
                   'name' => 'AlphabetOr',
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'data' => 'die',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 160
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'Could not close: $!',
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'line' => 160,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 160,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'data' => '$r',
                   'line' => 161,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 161
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 161,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'runperl',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 161
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'progfile',
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 162,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 162
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 162,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$filename',
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 162,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'args',
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 163,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 163,
                   'has_warnings' => 0,
                   'data' => '=>',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '[',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 163
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => '-x=foo -y',
                   'has_warnings' => 0,
                   'line' => 163,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ']',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'name' => 'RightBracket',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 163
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 163,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 164
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 164
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'is',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 165
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 165,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 165,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'data' => '$r'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 165,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'foo1',
                   'has_warnings' => 0,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'line' => 165,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 165,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 165,
                   'data' => '-s on the shebang line',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 165
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 165,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 166
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 169,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'data' => '$filename',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 169,
                   'has_warnings' => 0,
                   'data' => '=',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'tempfile',
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 169,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 169,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 169,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 169,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 1,
                   'data' => 'SKIP',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 170
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Colon,
                   'name' => 'Colon',
                   'data' => ':',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Colon,
                   'line' => 170
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 170,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'open',
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'line' => 171,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 171,
                   'has_warnings' => 0,
                   'data' => 'my',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 171,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$f',
                   'has_warnings' => 0,
                   'name' => 'LocalVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 171,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => '>$filename',
                   'has_warnings' => 0,
                   'line' => 171,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 171,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'name' => 'AlphabetOr',
                   'has_warnings' => 0,
                   'data' => 'or'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'skip',
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 171,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 171,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => 'Can\'t write temp file $filename: $!',
                   'has_warnings' => 0,
                   'line' => 171,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 171,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 171,
                   'has_warnings' => 0,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'print',
                   'has_warnings' => 0,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'line' => 172,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 172,
                   'has_warnings' => 0,
                   'data' => '$f',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 172,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'LeftShift',
                   'type' => Compiler::Lexer::TokenType::T_LeftShift,
                   'has_warnings' => 0,
                   'data' => '<<'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'SWTEST',
                   'has_warnings' => 0,
                   'name' => 'HereDocumentRawTag',
                   'type' => Compiler::Lexer::TokenType::T_HereDocumentRawTag,
                   'line' => 172,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 172
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 175,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'HereDocument',
                   'type' => Compiler::Lexer::TokenType::T_HereDocument,
                   'has_warnings' => 0,
                   'data' => '#!perl -sn
BEGIN { print $x; exit }
'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_HereDocumentEnd,
                   'name' => 'HereDocumentEnd',
                   'data' => 'SWTEST',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 175
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 176,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'data' => 'close',
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 176,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'data' => '$f',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'or',
                   'has_warnings' => 0,
                   'name' => 'AlphabetOr',
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'line' => 176,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'die',
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'line' => 176,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'has_warnings' => 0,
                   'data' => 'Could not close: $!',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 176
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 176,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 177,
                   'has_warnings' => 0,
                   'data' => '$r',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 177,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0,
                   'data' => '='
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'runperl',
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 177
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0,
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 177
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'progfile',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 178
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'has_warnings' => 0,
                   'data' => '=>',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 178
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 178,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'data' => '$filename',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 178,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 179,
                   'has_warnings' => 0,
                   'data' => 'args',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 179,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'has_warnings' => 0,
                   'data' => '=>'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '[',
                   'has_warnings' => 0,
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'line' => 179,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => '-x=foo',
                   'has_warnings' => 0,
                   'line' => 179,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 179,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'data' => ']',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 179,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 180,
                   'has_warnings' => 0,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 180,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'is',
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 181
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 181,
                   'data' => '(',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'data' => '$r',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 181
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 181,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'foo',
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'line' => 181,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 181,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-sn on the shebang line',
                   'has_warnings' => 0,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'line' => 181,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 181
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 181
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'has_warnings' => 0,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'line' => 182,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'has_warnings' => 0,
                   'data' => 'my',
                   'line' => 186,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$package',
                   'has_warnings' => 0,
                   'name' => 'LocalVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'line' => 186,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'data' => '=',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 186
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'tempfile',
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 186,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0,
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 186
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 186,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 186,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 187,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'data' => '$filename'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 187,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'data' => '=',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'data' => '$package.pm',
                   'line' => 187,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 187
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 1,
                   'data' => 'SKIP',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 188
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ':',
                   'has_warnings' => 0,
                   'name' => 'Colon',
                   'type' => Compiler::Lexer::TokenType::T_Colon,
                   'line' => 188,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Colon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 188,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 189,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'data' => 'open'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 189,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'has_warnings' => 0,
                   'data' => 'my'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 189,
                   'data' => '$f',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 189,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 189,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'data' => '>$filename',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'or',
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'name' => 'AlphabetOr',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 189
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 189,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 1,
                   'data' => 'skip'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 189,
                   'data' => '(',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 189,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'Can\'t write temp file $filename: $!',
                   'has_warnings' => 0,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 189,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '4',
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'line' => 189,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 189,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 189,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'data' => 'print',
                   'line' => 190,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$f',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 190
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftShift,
                   'name' => 'LeftShift',
                   'has_warnings' => 0,
                   'data' => '<<',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 190
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'HereDocumentTag',
                   'type' => Compiler::Lexer::TokenType::T_HereDocumentTag,
                   'has_warnings' => 0,
                   'data' => 'SWTESTPM',
                   'line' => 190,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 190,
                   'data' => ';',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 194,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'data' => 'package $package;
sub import { print map "<\\$_>", \\@_ }
1;
',
                   'name' => 'HereDocument',
                   'type' => Compiler::Lexer::TokenType::T_HereDocument
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 194,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'HereDocumentEnd',
                   'type' => Compiler::Lexer::TokenType::T_HereDocumentEnd,
                   'data' => 'SWTESTPM',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 195,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'data' => 'close',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 195,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'data' => '$f'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'or',
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'name' => 'AlphabetOr',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 195
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'die',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 195
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 195,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'Could not close: $!',
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 195
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 196,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$r',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 196,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0,
                   'data' => '='
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 196,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'runperl',
                   'has_warnings' => 1,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 196,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 197,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'switches',
                   'has_warnings' => 0,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 197,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'data' => '=>',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 197,
                   'has_warnings' => 0,
                   'data' => '[',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 197,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '-M$package',
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 197,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'data' => ']',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'data' => ',',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 197
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'prog',
                   'has_warnings' => 0,
                   'line' => 198,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 198,
                   'has_warnings' => 0,
                   'data' => '=>',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 198,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'data' => '1'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 198,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 199,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 199,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 200,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'data' => 'is',
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 200,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$r',
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'line' => 200,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 200,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '<$package>',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 200
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 200,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-M',
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'line' => 200,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 200,
                   'data' => ')',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 200,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'data' => ';',
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 201,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$r',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 201,
                   'data' => '=',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'data' => 'runperl',
                   'line' => 201,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 201,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'switches',
                   'has_warnings' => 0,
                   'line' => 202,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 202,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'has_warnings' => 0,
                   'data' => '=>'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 202,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '[',
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 202,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => '-M$package=foo',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'has_warnings' => 0,
                   'data' => ']',
                   'line' => 202,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 202,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 203,
                   'has_warnings' => 0,
                   'data' => 'prog',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=>',
                   'has_warnings' => 0,
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'line' => 203,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 203,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'data' => '1',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 203,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 204
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 204,
                   'data' => ';',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 205,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'is',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 205,
                   'data' => '(',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 205,
                   'has_warnings' => 0,
                   'data' => '$r',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 205
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '<$package><foo>',
                   'has_warnings' => 0,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'line' => 205,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 205,
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 205,
                   'data' => '-M with import parameter',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 205
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 205
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 206,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'data' => '$r'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0,
                   'data' => '=',
                   'line' => 206,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 206,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'runperl',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 206,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 207,
                   'has_warnings' => 0,
                   'data' => 'switches',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 207,
                   'data' => '=>',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 207,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'data' => '[',
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-m$package',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 207
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ']',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'name' => 'RightBracket',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 207
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 207,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 208,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'data' => 'prog',
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 208
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '1',
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'line' => 208,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 208,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 209,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 209
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 211
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 212,
                   'has_warnings' => 0,
                   'data' => 'local',
                   'type' => Compiler::Lexer::TokenType::T_LocalDecl,
                   'name' => 'LocalDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$TODO',
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'line' => 212,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'data' => '=',
                   'has_warnings' => 0,
                   'line' => 212,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 212,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'data' => ''
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 212,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 213,
                   'data' => 'is',
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 213,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'data' => '$r',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 213
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 213,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 213,
                   'has_warnings' => 0,
                   'data' => '',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 213
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => '-m',
                   'has_warnings' => 0,
                   'line' => 213,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'has_warnings' => 0,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'line' => 213,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 213,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'has_warnings' => 0,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'line' => 214,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'data' => '$r',
                   'line' => 215,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 215,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'has_warnings' => 0,
                   'data' => '=',
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'runperl',
                   'has_warnings' => 1,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 215,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 215
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 0,
                   'data' => 'switches',
                   'line' => 216,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'data' => '=>',
                   'has_warnings' => 0,
                   'line' => 216,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 216,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'data' => '[',
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 216,
                   'data' => '-m$package=foo,bar',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 216,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'name' => 'RightBracket',
                   'data' => ']',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 216,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'prog',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 217
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 217,
                   'data' => '=>',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 217,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'has_warnings' => 0,
                   'data' => '1'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 217,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 218,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'has_warnings' => 0,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 218,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'is',
                   'has_warnings' => 1,
                   'line' => 219,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 219,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 219,
                   'data' => '$r',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 219,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 219,
                   'has_warnings' => 0,
                   'data' => '<$package><foo><bar>',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 219
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-m with import parameters',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 219
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 219,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 219,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 220,
                   'has_warnings' => 0,
                   'data' => 'push',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 220,
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar,
                   'name' => 'ArrayVar',
                   'has_warnings' => 0,
                   'data' => '@tmpfiles'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 220,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 220,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$filename',
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 220,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '{',
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'line' => 222,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'local',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalDecl,
                   'name' => 'LocalDecl',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 223
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 223,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'data' => '$TODO'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 223,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0,
                   'data' => '='
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => '',
                   'has_warnings' => 0,
                   'line' => 223,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 223,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 225,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 1,
                   'data' => 'is'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'has_warnings' => 0,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'line' => 225,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'data' => 'runperl',
                   'line' => 225,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'has_warnings' => 0,
                   'line' => 225,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'switches',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 225
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '=>',
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'line' => 225,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 225,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'has_warnings' => 0,
                   'data' => '['
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => '-MTie::Hash',
                   'has_warnings' => 0,
                   'line' => 225,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 225,
                   'has_warnings' => 0,
                   'data' => ']',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'name' => 'RightBracket'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 225,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 225,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'stderr',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 225,
                   'has_warnings' => 0,
                   'data' => '=>',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 225,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '1',
                   'has_warnings' => 0,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'has_warnings' => 0,
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 225
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 225,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'prog',
                   'has_warnings' => 0,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 225,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 225,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'has_warnings' => 0,
                   'data' => '1'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 225
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 225,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => '',
                   'has_warnings' => 0,
                   'line' => 226,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 226,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-MFoo::Bar allowed',
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'line' => 226,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'line' => 226,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 226,
                   'data' => ';',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'like',
                   'has_warnings' => 1,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 228,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 228
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 228,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'data' => 'runperl',
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 228,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 228,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 0,
                   'data' => 'switches'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 228,
                   'has_warnings' => 0,
                   'data' => '=>',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 228,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '[',
                   'has_warnings' => 0,
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 228,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'has_warnings' => 0,
                   'data' => '-M:$package'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 228,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'data' => ']',
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 228,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 228,
                   'has_warnings' => 0,
                   'data' => 'stderr',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'data' => '=>',
                   'has_warnings' => 0,
                   'line' => 228,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'data' => '1',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 228
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'has_warnings' => 0,
                   'data' => ',',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 228
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 229,
                   'has_warnings' => 0,
                   'data' => 'prog',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 229,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'data' => '=>',
                   'has_warnings' => 0,
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 229,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'die q{oops}',
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 229
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 229,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'line' => 230,
                   'has_warnings' => 0,
                   'data' => 'qr',
                   'type' => Compiler::Lexer::TokenType::T_RegDecl,
                   'name' => 'RegDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '/',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 230
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 230,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'data' => 'Invalid module name [\\w:]+ with -M option\\b',
                   'name' => 'RegExp',
                   'type' => Compiler::Lexer::TokenType::T_RegExp
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 230,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'data' => '/',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 230,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-M:Foo not allowed',
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'line' => 231,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 231,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 231,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 233,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'like',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 233
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 233,
                   'has_warnings' => 1,
                   'data' => 'runperl',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 233,
                   'has_warnings' => 0,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 233,
                   'data' => 'switches',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=>',
                   'has_warnings' => 0,
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'line' => 233,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 233
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 233,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '-mA:B:C',
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 233,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'data' => ']',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 233,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 233,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'data' => 'stderr',
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 233,
                   'data' => '=>',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'has_warnings' => 0,
                   'data' => '1',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 233
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 233,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 234,
                   'data' => 'prog',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '=>',
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'line' => 234,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 234,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => 'die q{oops}',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 234,
                   'data' => ')',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 234,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegDecl,
                   'name' => 'RegDecl',
                   'has_warnings' => 0,
                   'data' => 'qr',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'line' => 235
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '/',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 235
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 235,
                   'has_warnings' => 0,
                   'data' => 'Invalid module name [\\w:]+ with -m option\\b',
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'name' => 'RegExp'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'has_warnings' => 0,
                   'data' => '/',
                   'line' => 235,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 235,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 236,
                   'has_warnings' => 0,
                   'data' => '-mFoo:Bar not allowed',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 236,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 236,
                   'has_warnings' => 0,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 238,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'like',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 238,
                   'data' => '(',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 238,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 1,
                   'data' => 'runperl',
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 238
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 238,
                   'data' => 'switches',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 238,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'data' => '=>',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '[',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 238
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 238,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'has_warnings' => 0,
                   'data' => '-m-A:B:C'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 238,
                   'has_warnings' => 0,
                   'data' => ']',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'name' => 'RightBracket'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 238,
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 238,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'stderr',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 238,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 238,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'has_warnings' => 0,
                   'data' => '1'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 238,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'prog',
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 239,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '=>',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 239
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 239,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'data' => 'die q{oops}',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 239
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 239,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'qr',
                   'has_warnings' => 0,
                   'name' => 'RegDecl',
                   'type' => Compiler::Lexer::TokenType::T_RegDecl,
                   'line' => 240,
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 240,
                   'has_warnings' => 0,
                   'data' => '/',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 240,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegExp',
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'data' => 'Invalid module name [\\w:]+ with -m option\\b',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 240,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 240,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'has_warnings' => 0,
                   'data' => '-m-Foo:Bar not allowed',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 241
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'has_warnings' => 0,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'line' => 241,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 241
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'like',
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 243,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 243,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 243,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'data' => 'runperl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'has_warnings' => 0,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'line' => 243,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'switches',
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 243,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 243
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 243,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '[',
                   'has_warnings' => 0,
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 243,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'data' => '-m-',
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 243,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ']',
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 243
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'stderr',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 243
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'data' => '=>',
                   'has_warnings' => 0,
                   'line' => 243,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '1',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 243
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 243,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'prog',
                   'has_warnings' => 0,
                   'line' => 244,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 244,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'die q{oops}',
                   'has_warnings' => 0,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'line' => 244,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 244,
                   'has_warnings' => 0,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 244,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'qr',
                   'name' => 'RegDecl',
                   'type' => Compiler::Lexer::TokenType::T_RegDecl,
                   'line' => 245,
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '/',
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'line' => 245,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 245,
                   'data' => 'Module name required with -m option\\b',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'name' => 'RegExp'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'has_warnings' => 0,
                   'data' => '/',
                   'line' => 245,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 245,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 246,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '-m- not allowed',
                   'has_warnings' => 0,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 246,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 246,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'like',
                   'has_warnings' => 1,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 248,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 248,
                   'has_warnings' => 0,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 248,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'data' => 'runperl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 248
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'switches',
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 248,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'has_warnings' => 0,
                   'data' => '=>',
                   'line' => 248,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'data' => '[',
                   'has_warnings' => 0,
                   'line' => 248,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'has_warnings' => 0,
                   'data' => '-M-=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 248
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 248,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'name' => 'RightBracket',
                   'data' => ']',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 248
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 248,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'stderr',
                   'has_warnings' => 0,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 248,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'data' => '=>',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '1',
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'line' => 248,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 248,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'prog',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 249
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 249,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'data' => '=>',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 249,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => 'die q{oops}',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 249
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 249,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'qr',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDecl,
                   'name' => 'RegDecl',
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 250
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'data' => '/',
                   'has_warnings' => 0,
                   'line' => 250,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'name' => 'RegExp',
                   'data' => 'Module name required with -M option\\b',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 250
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '/',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 250
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 250,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-M- not allowed',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 251
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 251
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 251,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 252
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '}',
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'line' => 253,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'is',
                   'has_warnings' => 1,
                   'line' => 254,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 1,
                   'data' => 'runperl',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 254
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 254,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 254,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'stderr',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 254,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'has_warnings' => 0,
                   'data' => '=>'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '1',
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'line' => 254,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'data' => ',',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 254
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 254,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 0,
                   'data' => 'prog'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'has_warnings' => 0,
                   'data' => '=>',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 254
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 254,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'data' => '#!perl -m',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 254,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 254,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 255,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'name' => 'RegDoubleQuote',
                   'type' => Compiler::Lexer::TokenType::T_RegDoubleQuote,
                   'has_warnings' => 0,
                   'data' => 'qq'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'data' => 'Too late for "-m" option at -e line 1.\\n',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 255
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 255,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'data' => '#!perl -m',
                   'line' => 255,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 255,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'is',
                   'has_warnings' => 1,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 256,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'runperl',
                   'has_warnings' => 1,
                   'line' => 256,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 256
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'stderr',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 256
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 256,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '=>',
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'data' => '1',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 256
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'data' => ',',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 256
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'prog',
                   'has_warnings' => 0,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 256,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '=>',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 256
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 256,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'data' => '#!perl -M',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 256
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 256,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegDoubleQuote',
                   'type' => Compiler::Lexer::TokenType::T_RegDoubleQuote,
                   'data' => 'qq',
                   'has_warnings' => 0,
                   'line' => 257,
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'Too late for "-M" option at -e line 1.\\n',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 257
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 257,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '#!perl -M',
                   'has_warnings' => 0,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'line' => 257,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 257,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 261,
                   'data' => '{',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LocalDecl,
                   'name' => 'LocalDecl',
                   'data' => 'local',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 262
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'data' => '$TODO',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 262
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 262,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'has_warnings' => 0,
                   'data' => '=',
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => '',
                   'has_warnings' => 0,
                   'line' => 262,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 262,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'like',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 266
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 266,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 266,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 1,
                   'data' => 'runperl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 266,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'has_warnings' => 0,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'switches',
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 266,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 266,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'data' => '=>',
                   'has_warnings' => 0,
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 266,
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'has_warnings' => 0,
                   'data' => '-V',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 266
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ']',
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'line' => 266,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 266,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'data' => ',',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 266
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'line' => 266,
                   'type' => Compiler::Lexer::TokenType::T_RegDecl,
                   'name' => 'RegDecl',
                   'data' => 'qr',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 266,
                   'has_warnings' => 0,
                   'data' => '/',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegExp',
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'has_warnings' => 0,
                   'data' => '(\\n.*){20}',
                   'line' => 266,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 266
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 266,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => '-V generates 20+ lines',
                   'has_warnings' => 0,
                   'line' => 267,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 267
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 267,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'data' => 'like',
                   'line' => 269,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 269,
                   'has_warnings' => 0,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'runperl',
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 269
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 269,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 269,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 0,
                   'data' => 'switches'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 269,
                   'data' => '=>',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '[',
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'line' => 269,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 269,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => '-V',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ']',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'name' => 'RightBracket',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 269
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'line' => 269,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'has_warnings' => 0,
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 269
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'line' => 270,
                   'data' => 'qr',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDecl,
                   'name' => 'RegDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 270,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '/',
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 270,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '\\ASummary of my perl5 .*configuration:',
                   'name' => 'RegExp',
                   'type' => Compiler::Lexer::TokenType::T_RegExp
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 270,
                   'data' => '/',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'has_warnings' => 0,
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 270
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'data' => '-V looks okay',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 271
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 271,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 271,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'chomp',
                   'has_warnings' => 0,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'line' => 274,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 274,
                   'has_warnings' => 0,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$r',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 274
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 274,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'data' => '=',
                   'has_warnings' => 0,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 274,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'runperl',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 274
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'switches',
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 274,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '=>',
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'line' => 274,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 274,
                   'data' => '[',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 274,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'data' => '-V:osname',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 274,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'data' => ']',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 274,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 274,
                   'data' => ')',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 274,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'is',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 275
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 275
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 275,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'data' => '$r'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 275,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'osname=\'$^O\';',
                   'has_warnings' => 0,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'line' => 275,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 275
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 275,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => 'perl -V:osname',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 275,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => ')',
                   'has_warnings' => 0,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 275
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 278,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'data' => 'chomp',
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 278
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$r',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 278
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 278,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'has_warnings' => 0,
                   'data' => '='
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 278,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'runperl',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0,
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 278
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'switches',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 278
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'has_warnings' => 0,
                   'data' => '=>',
                   'line' => 278,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '[',
                   'has_warnings' => 0,
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'line' => 278,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => '-V:this_var_makes_switches_test_fail',
                   'has_warnings' => 0,
                   'line' => 278,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 278,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'has_warnings' => 0,
                   'data' => ']'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 278
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 278
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 278,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 279,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'is',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 279,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 279,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'data' => '$r'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 279,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 279,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => 'this_var_makes_switches_test_fail=\'UNKNOWN\';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 279,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 280,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'perl -V:unknown var',
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 280
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 280
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 285,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'data' => '$r'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 285
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 285,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 1,
                   'data' => 'runperl',
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 285,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 285,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'switches',
                   'has_warnings' => 0,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'has_warnings' => 0,
                   'data' => '=>',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 285
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '[',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 285
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'data' => '"-V:i\\D+size"',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 285
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ']',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'name' => 'RightBracket',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 285
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'line' => 285,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 285,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'like',
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 287,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 287,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'data' => '$r',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 287
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 287,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 287,
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'qr',
                   'has_warnings' => 0,
                   'name' => 'RegDecl',
                   'type' => Compiler::Lexer::TokenType::T_RegDecl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 287,
                   'has_warnings' => 0,
                   'data' => '/',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '^(?!.*(not found|UNKNOWN)).',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'name' => 'RegExp',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 287
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 287,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'data' => '/',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 287,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 287,
                   'has_warnings' => 0,
                   'data' => 'perl -V:re got a result',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 287,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 287,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'ok',
                   'has_warnings' => 1,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 290
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 290
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 290,
                   'kind' => Compiler::Lexer::Kind::T_SingleTerm,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Not',
                   'type' => Compiler::Lexer::TokenType::T_Not,
                   'has_warnings' => 0,
                   'data' => '!'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 290,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'has_warnings' => 0,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'grep',
                   'has_warnings' => 0,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'line' => 290,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Not,
                   'name' => 'Not',
                   'data' => '!',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_SingleTerm,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 290
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 290,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'has_warnings' => 0,
                   'data' => '/'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 290,
                   'data' => '^i\\D+size=',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'name' => 'RegExp'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'has_warnings' => 0,
                   'data' => '/',
                   'line' => 290,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 290,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 290,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'data' => 'split',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 290,
                   'has_warnings' => 0,
                   'data' => '/',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 290,
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'name' => 'RegExp',
                   'has_warnings' => 0,
                   'data' => '^'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 290,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'data' => '/',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 290
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 290,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'data' => '$r',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 290,
                   'data' => ')',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 290,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-V:re correct',
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'line' => 290,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 290,
                   'data' => ')',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 290,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 291,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '}',
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'has_warnings' => 0,
                   'line' => 295,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 296,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'data' => 'local',
                   'name' => 'LocalDecl',
                   'type' => Compiler::Lexer::TokenType::T_LocalDecl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$TODO',
                   'has_warnings' => 0,
                   'line' => 296,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '=',
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'line' => 296,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => '',
                   'has_warnings' => 0,
                   'line' => 296,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 296
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 299,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 1,
                   'data' => 'SKIP'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Colon',
                   'type' => Compiler::Lexer::TokenType::T_Colon,
                   'has_warnings' => 0,
                   'data' => ':',
                   'line' => 299,
                   'kind' => Compiler::Lexer::Kind::T_Colon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'has_warnings' => 0,
                   'line' => 300,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 301,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'skip',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'Win32 miniperl produces a default archname in -v',
                   'has_warnings' => 0,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'line' => 301,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ',',
                   'line' => 301,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 301,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'data' => '1'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 302,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'name' => 'IfStmt',
                   'data' => 'if',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SpecificValue',
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'data' => '$^O',
                   'has_warnings' => 0,
                   'line' => 302,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 302,
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'name' => 'StringEqual',
                   'data' => 'eq',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 302,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'data' => 'MSWin32'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 302,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'And',
                   'type' => Compiler::Lexer::TokenType::T_And,
                   'data' => '&&',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 302,
                   'has_warnings' => 1,
                   'data' => 'is_miniperl',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 302,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'my',
                   'has_warnings' => 0,
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'line' => 303,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar',
                   'has_warnings' => 0,
                   'data' => '$v',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 303
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 303,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0,
                   'data' => '='
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 303,
                   'data' => 'sprintf',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '%vd',
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'line' => 303,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 303
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 303,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'SpecificValue',
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'data' => '$^',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'V',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 303
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 303
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'data' => 'my',
                   'has_warnings' => 0,
                   'line' => 304,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 304,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar',
                   'has_warnings' => 0,
                   'data' => '$ver'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0,
                   'data' => '=',
                   'line' => 304,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$Config',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_GlobalVar,
                   'name' => 'GlobalVar',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 304
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'has_warnings' => 0,
                   'data' => '{',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 304
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 304,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'PERL_VERSION',
                   'has_warnings' => 0,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 304,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'data' => '}',
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 304
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'my',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 305
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 305,
                   'has_warnings' => 0,
                   'data' => '$rel',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 305,
                   'has_warnings' => 0,
                   'data' => '=',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'data' => '$Config',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 305
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 305,
                   'data' => '{',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'PERL_SUBVERSION',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 305
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'has_warnings' => 0,
                   'data' => '}',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 305
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 305
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'like',
                   'has_warnings' => 1,
                   'line' => 306,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 306
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'runperl',
                   'has_warnings' => 1,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 306,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 306,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 306,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'switches',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '=>',
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'line' => 306,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 306,
                   'has_warnings' => 0,
                   'data' => '[',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-v',
                   'has_warnings' => 0,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'line' => 306,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 306,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'data' => ']',
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 306,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 306,
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 307,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'name' => 'RegDecl',
                   'type' => Compiler::Lexer::TokenType::T_RegDecl,
                   'has_warnings' => 0,
                   'data' => 'qr'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 307,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '/',
                   'has_warnings' => 0,
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'name' => 'RegExp',
                   'data' => 'This is perl 5, version \\Q$ver\\E, subversion \\Q$rel\\E \\(v\\Q$v\\E(?:[-*\\w]+| \\([^)]+\\))?\\) built for \\Q$Config{archname}\\E.+Copyright.+Larry Wall.+Artistic License.+GNU General Public License',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 307
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 307,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '/',
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 's',
                   'type' => Compiler::Lexer::TokenType::T_RegOpt,
                   'name' => 'RegOpt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_RegOpt,
                   'line' => 307
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 307,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 308,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'has_warnings' => 0,
                   'data' => '-v looks okay'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'line' => 308,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 308,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '}',
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'line' => 309,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'has_warnings' => 0,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'line' => 310,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 314,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'has_warnings' => 0,
                   'data' => '{'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 315,
                   'type' => Compiler::Lexer::TokenType::T_LocalDecl,
                   'name' => 'LocalDecl',
                   'data' => 'local',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 315,
                   'data' => '$TODO',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '=',
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'line' => 315,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 315,
                   'has_warnings' => 0,
                   'data' => '',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 315
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'like',
                   'has_warnings' => 1,
                   'line' => 317,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 317,
                   'data' => '(',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 1,
                   'data' => 'runperl',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 317
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 317,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 317,
                   'data' => 'switches',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'data' => '=>',
                   'has_warnings' => 0,
                   'line' => 317,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '[',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 317
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'has_warnings' => 0,
                   'data' => '-h',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 317
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ']',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'name' => 'RightBracket',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 317
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 317,
                   'has_warnings' => 0,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 317
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegDecl,
                   'name' => 'RegDecl',
                   'data' => 'qr',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 318
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 318,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'data' => '/',
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 318,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegExp',
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'has_warnings' => 0,
                   'data' => 'Usage: .+(?i:perl(?:$Config{_exe})?).+switches.+programfile.+arguments'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 318,
                   'data' => '/',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 318,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'data' => '-h looks okay',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 319
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 319
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 319,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 321
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'ForeachStmt',
                   'type' => Compiler::Lexer::TokenType::T_ForeachStmt,
                   'data' => 'foreach',
                   'has_warnings' => 0,
                   'line' => 325,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Stmt
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 325,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'has_warnings' => 0,
                   'data' => 'my'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 325,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '$switch',
                   'name' => 'LocalVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 325,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 325,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'has_warnings' => 0,
                   'data' => 'split'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '/',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 325
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '',
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'name' => 'RegExp',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 325
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 325
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 325,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'ABbGgHJjKkLNOoPQqRrYyZz123456789_',
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'line' => 325,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 325,
                   'has_warnings' => 0,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 326
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 327,
                   'type' => Compiler::Lexer::TokenType::T_LocalDecl,
                   'name' => 'LocalDecl',
                   'data' => 'local',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 327,
                   'data' => '$TODO',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '=',
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'line' => 327,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'data' => '',
                   'line' => 327,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 327,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'like',
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 329
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 329
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 329,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'data' => 'runperl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'has_warnings' => 0,
                   'line' => 329,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 329,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 0,
                   'data' => 'switches'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'has_warnings' => 0,
                   'data' => '=>',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 329
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '[',
                   'has_warnings' => 0,
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'line' => 329,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 329,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'data' => '-$switch',
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'has_warnings' => 0,
                   'data' => ']',
                   'line' => 329,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 329,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'stderr',
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 329,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'data' => '=>',
                   'has_warnings' => 0,
                   'line' => 329,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '1',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 329
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 329
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 330,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 0,
                   'data' => 'prog'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 330,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'data' => '=>',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 330,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'has_warnings' => 0,
                   'data' => 'die q{oops}'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 330,
                   'has_warnings' => 0,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 330,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'line' => 331,
                   'type' => Compiler::Lexer::TokenType::T_RegDecl,
                   'name' => 'RegDecl',
                   'has_warnings' => 0,
                   'data' => 'qr'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '/',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 331
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '\\QUnrecognized switch: -$switch  (-h will show valid options).',
                   'name' => 'RegExp',
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'line' => 331,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'data' => '/',
                   'has_warnings' => 0,
                   'line' => 331,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 331
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'has_warnings' => 0,
                   'data' => '-$switch correctly unknown',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 332
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 332
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 332,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 335,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'like',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 335,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 335,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 1,
                   'data' => 'runperl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 335
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'stderr',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 335
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 335,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=>',
                   'has_warnings' => 0,
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '1',
                   'has_warnings' => 0,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'line' => 335,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 335,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 335,
                   'data' => 'prog',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'has_warnings' => 0,
                   'data' => '=>',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 335
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '#!perl -$switch',
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'line' => 335,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 335,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 335,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'line' => 336,
                   'type' => Compiler::Lexer::TokenType::T_RegDecl,
                   'name' => 'RegDecl',
                   'has_warnings' => 0,
                   'data' => 'qr'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 336
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 337,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegExp',
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'has_warnings' => 0,
                   'data' => '^Unrecognized switch: -$switch  \\(-h will show valid (?x:
	     )options\\) at -e line 1\\.'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '/',
                   'has_warnings' => 0,
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'line' => 337,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'data' => ',',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 337
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 338,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'data' => '-$switch unrecognised on #! line'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 338
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 338,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '}',
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'line' => 339,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 342,
                   'type' => Compiler::Lexer::TokenType::T_ForStmt,
                   'name' => 'ForStmt',
                   'has_warnings' => 0,
                   'data' => 'for'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 342,
                   'data' => '(',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegList,
                   'name' => 'RegList',
                   'has_warnings' => 0,
                   'data' => 'qw',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'line' => 342
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 342
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'name' => 'RegExp',
                   'has_warnings' => 0,
                   'data' => ' e f x E S V ',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 342
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 342
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 342,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => ')',
                   'has_warnings' => 0,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'has_warnings' => 0,
                   'data' => '{',
                   'line' => 342,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 343,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'data' => '$r'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 343,
                   'data' => '=',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'runperl',
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 343
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'has_warnings' => 0,
                   'line' => 343,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'stderr',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 344
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 344,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'has_warnings' => 0,
                   'data' => '=>'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'data' => '1',
                   'has_warnings' => 0,
                   'line' => 344,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 344,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'prog',
                   'has_warnings' => 0,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 345,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 345,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'has_warnings' => 0,
                   'data' => '=>'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 345,
                   'data' => '#!perl -$_',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 345,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 346,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 346,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 347,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 1,
                   'data' => 'is',
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 347,
                   'has_warnings' => 0,
                   'data' => '$r',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 347
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'Can\'t emulate -$_ on #! line at -e line 1.\\n',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 347
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 347,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => '-$_ on #! line',
                   'has_warnings' => 0,
                   'line' => 347,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 347
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'has_warnings' => 0,
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 348
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 352,
                   'data' => '{',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'local',
                   'name' => 'LocalDecl',
                   'type' => Compiler::Lexer::TokenType::T_LocalDecl,
                   'line' => 353,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 353,
                   'has_warnings' => 0,
                   'data' => '$TODO',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'data' => '=',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 353
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'has_warnings' => 0,
                   'data' => '',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 353
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 353,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 355,
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl,
                   'name' => 'FunctionDecl',
                   'has_warnings' => 0,
                   'data' => 'sub'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 355,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'data' => 'do_i_unlink',
                   'has_warnings' => 0,
                   'name' => 'Function',
                   'type' => Compiler::Lexer::TokenType::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 355
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'unlink_all',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 355
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 355
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 355,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'data' => 'file',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 355,
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'file.bak',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 355
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 355,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'has_warnings' => 0,
                   'data' => '}',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 355
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'data' => 'open',
                   'has_warnings' => 0,
                   'line' => 357,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 357
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 357,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'FILE',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 357,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => '>file',
                   'has_warnings' => 0,
                   'line' => 357,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 357,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 357,
                   'has_warnings' => 0,
                   'data' => 'or',
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'name' => 'AlphabetOr'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'die',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 357
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 357,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'data' => '$0: Failed to create \'file\': $!',
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 357
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'data' => 'print',
                   'has_warnings' => 0,
                   'line' => 358,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'data' => 'FILE',
                   'line' => 358,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 358,
                   'type' => Compiler::Lexer::TokenType::T_LeftShift,
                   'name' => 'LeftShift',
                   'data' => '<<',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 358,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '__EOF__',
                   'has_warnings' => 0,
                   'name' => 'HereDocumentBareTag',
                   'type' => Compiler::Lexer::TokenType::T_HereDocumentBareTag
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 358,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'foo yada dada
bada foo bing
king kong foo
',
                   'name' => 'HereDocument',
                   'type' => Compiler::Lexer::TokenType::T_HereDocument,
                   'line' => 362,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 362,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'HereDocumentEnd',
                   'type' => Compiler::Lexer::TokenType::T_HereDocumentEnd,
                   'data' => '__EOF__',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'close',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 363
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 363,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 1,
                   'data' => 'FILE'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 363,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_ModWord,
                   'name' => 'ModWord',
                   'has_warnings' => 0,
                   'data' => 'END',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_ModWord,
                   'line' => 365
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 365,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Call',
                   'type' => Compiler::Lexer::TokenType::T_Call,
                   'has_warnings' => 0,
                   'data' => 'do_i_unlink',
                   'line' => 365,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 365
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 365,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 365
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'runperl',
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 367,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 367,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 367,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'switches',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 367,
                   'data' => '=>',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 367,
                   'has_warnings' => 0,
                   'data' => '[',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-pi.bak',
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'line' => 367,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 367,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'data' => ']',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'data' => ',',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 367
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 367,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'prog',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'has_warnings' => 0,
                   'data' => '=>',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 367
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'data' => 's/foo/bar/',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 367
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 367,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'args',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 367
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 367,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'data' => '=>',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'has_warnings' => 0,
                   'data' => '[',
                   'line' => 367,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 367,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'has_warnings' => 0,
                   'data' => 'file'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 367,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'data' => ']',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 367
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 367,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 369,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'data' => 'open',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 369,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'data' => 'FILE',
                   'line' => 369,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 369,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 369,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'has_warnings' => 0,
                   'data' => 'file'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 369,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 369,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'name' => 'AlphabetOr',
                   'data' => 'or',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'die',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 369
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$0: Failed to open \'file\': $!',
                   'has_warnings' => 0,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'line' => 369,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 369,
                   'has_warnings' => 0,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 370,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'data' => 'chomp',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'has_warnings' => 0,
                   'line' => 370,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'has_warnings' => 0,
                   'data' => 'my',
                   'line' => 370,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '@file',
                   'name' => 'LocalArrayVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalArrayVar,
                   'line' => 370,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 370,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'data' => '=',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_HandleDelim,
                   'name' => 'HandleDelim',
                   'data' => '<',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 370
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'FILE',
                   'has_warnings' => 1,
                   'line' => 370,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '>',
                   'type' => Compiler::Lexer::TokenType::T_HandleDelim,
                   'name' => 'HandleDelim',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 370
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 370,
                   'has_warnings' => 0,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 370,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'close',
                   'has_warnings' => 0,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'line' => 371,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 371,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'FILE',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 371,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'data' => 'open',
                   'has_warnings' => 0,
                   'line' => 373,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 373,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 373,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 1,
                   'data' => 'BAK'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 373,
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'data' => 'file.bak',
                   'line' => 373,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 373,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'or',
                   'has_warnings' => 0,
                   'name' => 'AlphabetOr',
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'line' => 373,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'has_warnings' => 0,
                   'data' => 'die',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 373
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 373,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'data' => '$0: Failed to open \'file\': $!',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 373,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'data' => 'chomp',
                   'line' => 374,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 374,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'my',
                   'has_warnings' => 0,
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'line' => 374,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 374,
                   'has_warnings' => 0,
                   'data' => '@bak',
                   'type' => Compiler::Lexer::TokenType::T_LocalArrayVar,
                   'name' => 'LocalArrayVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 374,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '=',
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 374,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '<',
                   'has_warnings' => 0,
                   'name' => 'HandleDelim',
                   'type' => Compiler::Lexer::TokenType::T_HandleDelim
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'BAK',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 374
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '>',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_HandleDelim,
                   'name' => 'HandleDelim',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 374
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 374,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 374
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 375,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'data' => 'close',
                   'has_warnings' => 0,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'BAK',
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 375,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 375,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 377,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'is',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 377,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 377,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'data' => 'join',
                   'has_warnings' => 0,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 377
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 377,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ':',
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'data' => ',',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 377
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '@file',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar,
                   'name' => 'ArrayVar',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 377
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 377,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'has_warnings' => 0,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 377,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => 'bar yada dada:bada bar bing:king kong bar',
                   'has_warnings' => 0,
                   'line' => 378,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 378,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 379,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'has_warnings' => 0,
                   'data' => '-i new file'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 379
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 379,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 380,
                   'has_warnings' => 1,
                   'data' => 'is',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 380,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'join',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 380
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 380,
                   'data' => '(',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => ':',
                   'has_warnings' => 0,
                   'line' => 380,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 380,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '@bak',
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar,
                   'name' => 'ArrayVar',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 380
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 380,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 380,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 381,
                   'has_warnings' => 0,
                   'data' => 'foo yada dada:bada foo bing:king kong foo',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 381,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 382,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'data' => '-i backup file',
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 382
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 382,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'data' => ';',
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'data' => 'my',
                   'has_warnings' => 0,
                   'line' => 384,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LocalVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'data' => '$out1',
                   'has_warnings' => 0,
                   'line' => 384,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 384,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'has_warnings' => 0,
                   'data' => '=',
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 1,
                   'data' => 'runperl',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 384
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 384
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 385,
                   'data' => 'switches',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 385,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 385,
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket',
                   'has_warnings' => 0,
                   'data' => '['
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 385,
                   'has_warnings' => 0,
                   'data' => '-i.bak -p',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 385,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ']',
                   'has_warnings' => 0,
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 385,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 386,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'prog',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 386,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'has_warnings' => 0,
                   'data' => '=>'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => 'exit',
                   'has_warnings' => 0,
                   'line' => 386,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'has_warnings' => 0,
                   'data' => ',',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 386
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 0,
                   'data' => 'stderr',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 387
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=>',
                   'has_warnings' => 0,
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'line' => 387,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '1',
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'line' => 387,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 387,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'stdin',
                   'has_warnings' => 0,
                   'line' => 388,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 388,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'has_warnings' => 0,
                   'data' => '=>'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 388,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '1\\n',
                   'has_warnings' => 0,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'data' => ',',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 388
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 389,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 389,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'is',
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 390
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 390,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '$out1',
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'line' => 391,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'data' => ',',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 391
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-i used with no filenames on the command line, reading from STDIN.\\n',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 392
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 392,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 393,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'data' => 'warning when no files given',
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'has_warnings' => 0,
                   'line' => 394,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 394,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'has_warnings' => 0,
                   'data' => 'my',
                   'line' => 395,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 395,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '$out2',
                   'name' => 'LocalVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 395
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 395,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'runperl',
                   'has_warnings' => 1,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'has_warnings' => 0,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'line' => 395,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 0,
                   'data' => 'switches',
                   'line' => 396,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 396,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '=>',
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 396,
                   'data' => '[',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 396,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => '-i.bak -p',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'data' => ']',
                   'has_warnings' => 0,
                   'line' => 396,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 396,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 397,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'prog',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 397,
                   'has_warnings' => 0,
                   'data' => '=>',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'has_warnings' => 0,
                   'data' => 'exit',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 397
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 397,
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 398,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'data' => 'stderr',
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 398,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'has_warnings' => 0,
                   'data' => '=>'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'data' => '1',
                   'has_warnings' => 0,
                   'line' => 398,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 398,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'stdin',
                   'has_warnings' => 0,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 399,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 399,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'data' => '=>',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 399,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'data' => '1\\n'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'has_warnings' => 0,
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 399
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 400,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'args',
                   'has_warnings' => 0,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'has_warnings' => 0,
                   'data' => '=>',
                   'line' => 400,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '[',
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'line' => 400,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'data' => 'file',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 400
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'has_warnings' => 0,
                   'data' => ']',
                   'line' => 400,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 400
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'data' => ')',
                   'line' => 401,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 401,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 402,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'is',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 402,
                   'has_warnings' => 0,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 402,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'data' => '$out2'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 402,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'data' => '',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 402
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 402,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 402,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'no warning when files given',
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 402,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0,
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 402,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'has_warnings' => 0,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'line' => 403,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 407,
                   'data' => '$TODO',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'has_warnings' => 0,
                   'data' => '=',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 407
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 407,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'data' => '',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 407
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 409,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'data' => '$r'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 409,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=',
                   'has_warnings' => 0,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 409,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 1,
                   'data' => 'runperl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 409,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'switches',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 410
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'has_warnings' => 0,
                   'data' => '=>',
                   'line' => 410,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '[',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 410
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => '-E',
                   'has_warnings' => 0,
                   'line' => 410,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 410,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 410,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'has_warnings' => 0,
                   'data' => '"say q(Hello, world!)"'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 410,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => ']',
                   'has_warnings' => 0,
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 411
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 411,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'is',
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 412
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'line' => 412,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$r',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 412
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 412,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'Hello, world!\\n',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 412
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 412,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-E say',
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'line' => 412,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 412,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0,
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 412,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'data' => '$r',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 415
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 415
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 415,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 1,
                   'data' => 'runperl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 415,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'switches',
                   'has_warnings' => 0,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 416,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 416
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 416
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 416,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'data' => '-E'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 416,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 416,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'data' => '"no warnings q{experimental::smartmatch}; undef ~~ undef and say q(Hello, world!)"'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'has_warnings' => 0,
                   'data' => ']',
                   'line' => 416,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 417
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'data' => ';',
                   'line' => 417,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 418,
                   'has_warnings' => 1,
                   'data' => 'is',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 418
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 418,
                   'has_warnings' => 0,
                   'data' => '$r',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 418,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'Hello, world!\\n',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 418
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 418,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-E ~~',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 418
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 418,
                   'data' => ')',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 418,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'data' => '$r',
                   'line' => 420,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 420,
                   'data' => '=',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 1,
                   'data' => 'runperl',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 420
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 420,
                   'data' => '(',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 0,
                   'data' => 'switches',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 421
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 421,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'data' => '=>',
                   'has_warnings' => 0,
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'data' => '[',
                   'has_warnings' => 0,
                   'line' => 421,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 421,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'data' => '-E'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 421,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 421,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'data' => '"no warnings q{experimental::smartmatch}; given(undef) {when(undef) { say q(Hello, world!)"}}',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 421,
                   'data' => ']',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'name' => 'RightBracket'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 422,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 422,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 423,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'data' => 'is'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 423,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$r',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 423
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0,
                   'line' => 423,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'Hello, world!\\n',
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'line' => 423,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 423,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 423,
                   'has_warnings' => 0,
                   'data' => '-E given',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'line' => 423,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 423,
                   'data' => ';',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 425,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'data' => '$r'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'has_warnings' => 0,
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 425
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 425,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'runperl',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 425,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'switches',
                   'has_warnings' => 0,
                   'line' => 426,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 426,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'Arrow',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'data' => '=>',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '[',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 426
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '-nE',
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'line' => 426,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 426,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'q',
                   'type' => Compiler::Lexer::TokenType::T_RegQuote,
                   'name' => 'RegQuote',
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 426
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 426,
                   'has_warnings' => 0,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '"} END { say q/affe/"',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'name' => 'RegExp',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 426
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 426,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'has_warnings' => 0,
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 426,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ']',
                   'has_warnings' => 0,
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 426,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'stdin',
                   'has_warnings' => 0,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 427,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 427,
                   'data' => '=>',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'has_warnings' => 0,
                   'data' => 'zomtek',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 427
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'has_warnings' => 0,
                   'data' => ',',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 427
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'has_warnings' => 0,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'line' => 428,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 428
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 429,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'is',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 429
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'data' => '$r',
                   'line' => 429,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 429,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'affe\\n',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 429
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 429,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'has_warnings' => 0,
                   'data' => '-E works outside of the block created by -n',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 429
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 429
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 429,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ';',
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 431,
                   'has_warnings' => 0,
                   'data' => '$r',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 431,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'data' => '=',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'runperl',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 431
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 431,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 432,
                   'data' => 'switches',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 432,
                   'has_warnings' => 0,
                   'data' => '=>',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 432,
                   'data' => '[',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 432,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => '-E',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 432,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'line' => 432,
                   'type' => Compiler::Lexer::TokenType::T_RegQuote,
                   'name' => 'RegQuote',
                   'has_warnings' => 0,
                   'data' => 'q'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 432,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '(',
                   'has_warnings' => 0,
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 432,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegExp',
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'has_warnings' => 0,
                   'data' => '"*{\'bar\'} = sub{}; print \'Hello, world!\',qq|\\n|;"'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 432,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'has_warnings' => 0,
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'name' => 'RightBracket',
                   'data' => ']',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 432
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0,
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 433
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 433
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'data' => 'is',
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 434,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 434,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 434,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$r',
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 434,
                   'has_warnings' => 0,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 434,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'Hello, world!\\n',
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 434
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 434,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => '-E does not enable strictures',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 434
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 434,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 438,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'data' => '$filename'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 438,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'data' => '=',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'tempfile',
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 438
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 438,
                   'data' => '(',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 438,
                   'has_warnings' => 0,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'has_warnings' => 0,
                   'line' => 438,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 439,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'data' => 'SKIP'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Colon,
                   'line' => 439,
                   'has_warnings' => 0,
                   'data' => ':',
                   'type' => Compiler::Lexer::TokenType::T_Colon,
                   'name' => 'Colon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 439,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 440,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'data' => 'open',
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 440,
                   'has_warnings' => 0,
                   'data' => 'my',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 440,
                   'data' => '$f',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 440,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => '>$filename',
                   'has_warnings' => 0,
                   'line' => 440,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'AlphabetOr',
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'data' => 'or',
                   'has_warnings' => 0,
                   'line' => 440,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 440,
                   'has_warnings' => 1,
                   'data' => 'skip',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 440
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => 'Can\'t write temp file $filename: $!',
                   'has_warnings' => 0,
                   'line' => 440,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'line' => 440,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 440,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'data' => 'print',
                   'has_warnings' => 0,
                   'line' => 441,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 441,
                   'has_warnings' => 0,
                   'data' => '$f',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 441,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '<<',
                   'has_warnings' => 0,
                   'name' => 'LeftShift',
                   'type' => Compiler::Lexer::TokenType::T_LeftShift
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'SWTEST',
                   'name' => 'HereDocumentRawTag',
                   'type' => Compiler::Lexer::TokenType::T_HereDocumentRawTag,
                   'line' => 441,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 441,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '#!perl -w    -iok
print "$^I\\n";
',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_HereDocument,
                   'name' => 'HereDocument',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 444
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'SWTEST',
                   'type' => Compiler::Lexer::TokenType::T_HereDocumentEnd,
                   'name' => 'HereDocumentEnd',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 444
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 445,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'has_warnings' => 0,
                   'data' => 'close'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$f',
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'line' => 445,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 445,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'or',
                   'has_warnings' => 0,
                   'name' => 'AlphabetOr',
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 445,
                   'data' => 'die',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => 'Could not close: $!',
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'line' => 445,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 445
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$r',
                   'has_warnings' => 0,
                   'line' => 446,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 446,
                   'data' => '=',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'runperl',
                   'has_warnings' => 1,
                   'line' => 446,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'data' => '(',
                   'line' => 446,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'progfile',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 447
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '=>',
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 447
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 447,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'data' => '$filename',
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 447
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'line' => 448,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 448,
                   'has_warnings' => 0,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'like',
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 449
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 449
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 449,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$r',
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 449,
                   'data' => ',',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegDecl,
                   'name' => 'RegDecl',
                   'has_warnings' => 0,
                   'data' => 'qr',
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 449
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 449,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'has_warnings' => 0,
                   'data' => '/'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 449,
                   'data' => 'ok',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'name' => 'RegExp'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'has_warnings' => 0,
                   'data' => '/',
                   'line' => 449,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 449,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'has_warnings' => 0,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'Spaces on the #! line (#30660)',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 449
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 449,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 449,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 450
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
            'indent' => 1,
            'token_num' => 6,
            'end_line' => 8,
            'block_id' => 1,
            'start_line' => 8,
            'has_warnings' => 0,
            'src' => ' chdir \'t\' if -d \'t\' ;'
          },
          {
            'token_num' => 4,
            'indent' => 1,
            'has_warnings' => 0,
            'end_line' => 9,
            'block_id' => 1,
            'start_line' => 9,
            'src' => ' @INC = \'../lib\' ;'
          },
          {
            'has_warnings' => 0,
            'block_id' => 1,
            'end_line' => 10,
            'start_line' => 10,
            'src' => ' require Config ;',
            'token_num' => 3,
            'indent' => 1
          },
          {
            'src' => ' import Config ;',
            'has_warnings' => 1,
            'start_line' => 10,
            'end_line' => 10,
            'block_id' => 1,
            'token_num' => 3,
            'indent' => 1
          },
          {
            'indent' => 1,
            'token_num' => 3,
            'end_line' => 13,
            'block_id' => 2,
            'start_line' => 13,
            'has_warnings' => 0,
            'src' => ' require "./test.pl" ;'
          },
          {
            'indent' => 1,
            'token_num' => 3,
            'src' => ' require "./loc_tools.pl" ;',
            'end_line' => 13,
            'start_line' => 13,
            'block_id' => 2,
            'has_warnings' => 0
          },
          {
            'src' => ' plan ( tests => 115 ) ;',
            'end_line' => 15,
            'block_id' => 0,
            'start_line' => 15,
            'has_warnings' => 1,
            'indent' => 0,
            'token_num' => 7
          },
          {
            'indent' => 0,
            'token_num' => 3,
            'src' => ' use Config ;',
            'start_line' => 17,
            'end_line' => 17,
            'block_id' => 0,
            'has_warnings' => 0
          },
          {
            'src' => ' $TODO = "runperl() unable to emulate echo -n due to pipe bug" if $^O eq \'VMS\' ;',
            'has_warnings' => 1,
            'start_line' => 22,
            'end_line' => 22,
            'block_id' => 0,
            'token_num' => 8,
            'indent' => 0
          },
          {
            'token_num' => 3,
            'indent' => 0,
            'has_warnings' => 0,
            'end_line' => 24,
            'start_line' => 24,
            'block_id' => 0,
            'src' => ' my $r ;'
          },
          {
            'indent' => 0,
            'token_num' => 6,
            'src' => ' my @tmpfiles = ( ) ;',
            'end_line' => 25,
            'start_line' => 25,
            'block_id' => 0,
            'has_warnings' => 0
          },
          {
            'end_line' => 34,
            'start_line' => 30,
            'block_id' => 0,
            'has_warnings' => 1,
            'src' => ' $r = runperl ( switches => [ \'-0\' , ] , stdin => \'foo\\0bar\\0baz\\0\' , prog => \'print qq(<$_>) while <>\' , ) ;',
            'indent' => 0,
            'token_num' => 21
          },
          {
            'src' => ' is ( $r , "<foo\\0><bar\\0><baz\\0>" , "-0" ) ;',
            'has_warnings' => 1,
            'start_line' => 35,
            'end_line' => 35,
            'block_id' => 0,
            'token_num' => 9,
            'indent' => 0
          },
          {
            'indent' => 0,
            'token_num' => 24,
            'src' => ' $r = runperl ( switches => [ \'-l\' , \'-0\' , \'-p\' ] , stdin => \'foo\\0bar\\0baz\\0\' , prog => \'1\' , ) ;',
            'end_line' => 41,
            'start_line' => 37,
            'block_id' => 0,
            'has_warnings' => 1
          },
          {
            'indent' => 0,
            'token_num' => 9,
            'start_line' => 42,
            'end_line' => 42,
            'block_id' => 0,
            'has_warnings' => 1,
            'src' => ' is ( $r , "foo\\nbar\\nbaz\\n" , "-0 after a -l" ) ;'
          },
          {
            'block_id' => 0,
            'end_line' => 48,
            'start_line' => 44,
            'has_warnings' => 1,
            'src' => ' $r = runperl ( switches => [ \'-0\' , \'-l\' , \'-p\' ] , stdin => \'foo\\0bar\\0baz\\0\' , prog => \'1\' , ) ;',
            'indent' => 0,
            'token_num' => 24
          },
          {
            'token_num' => 9,
            'indent' => 0,
            'has_warnings' => 1,
            'end_line' => 49,
            'start_line' => 49,
            'block_id' => 0,
            'src' => ' is ( $r , "foo\\0bar\\0baz\\0" , "-0 before a -l" ) ;'
          },
          {
            'token_num' => 26,
            'indent' => 0,
            'src' => ' $r = runperl ( switches => [ sprintf ( "-0%o" , ord \'x\' ) ] , stdin => \'fooxbarxbazx\' , prog => \'print qq(<$_>) while <>\' , ) ;',
            'has_warnings' => 1,
            'block_id' => 0,
            'end_line' => 55,
            'start_line' => 51
          },
          {
            'indent' => 0,
            'token_num' => 9,
            'block_id' => 0,
            'end_line' => 56,
            'start_line' => 56,
            'has_warnings' => 1,
            'src' => ' is ( $r , "<foox><barx><bazx>" , "-0 with octal number" ) ;'
          },
          {
            'has_warnings' => 1,
            'end_line' => 62,
            'start_line' => 58,
            'block_id' => 0,
            'src' => ' $r = runperl ( switches => [ \'-00\' , \'-p\' ] , stdin => \'abc\\ndef\\n\\nghi\\njkl\\nmno\\n\\npq\\n\' , prog => \'s/\\n/-/g;$_.=q(/)\' , ) ;',
            'token_num' => 22,
            'indent' => 0
          },
          {
            'indent' => 0,
            'token_num' => 9,
            'src' => ' is ( $r , \'abc-def--/ghi-jkl-mno--/pq-/\' , \'-00 (paragraph mode)\' ) ;',
            'block_id' => 0,
            'end_line' => 63,
            'start_line' => 63,
            'has_warnings' => 1
          },
          {
            'end_line' => 69,
            'start_line' => 65,
            'block_id' => 0,
            'has_warnings' => 1,
            'src' => ' $r = runperl ( switches => [ \'-0777\' , \'-p\' ] , stdin => \'abc\\ndef\\n\\nghi\\njkl\\nmno\\n\\npq\\n\' , prog => \'s/\\n/-/g;$_.=q(/)\' , ) ;',
            'indent' => 0,
            'token_num' => 22
          },
          {
            'indent' => 0,
            'token_num' => 9,
            'end_line' => 70,
            'block_id' => 0,
            'start_line' => 70,
            'has_warnings' => 1,
            'src' => ' is ( $r , \'abc-def--ghi-jkl-mno--pq-/\' , \'-0777 (slurp mode)\' ) ;'
          },
          {
            'indent' => 0,
            'token_num' => 16,
            'src' => ' $r = runperl ( switches => [ \'-066\' ] , prog => \'BEGIN { print qq{($/)} } print qq{[$/]}\' , ) ;',
            'start_line' => 72,
            'end_line' => 75,
            'block_id' => 0,
            'has_warnings' => 1
          },
          {
            'block_id' => 0,
            'end_line' => 76,
            'start_line' => 76,
            'has_warnings' => 1,
            'src' => ' is ( $r , "(\\066)[\\066]" , \'$/ set at compile-time\' ) ;',
            'indent' => 0,
            'token_num' => 9
          },
          {
            'token_num' => 7,
            'indent' => 0,
            'src' => ' my $filename = tempfile ( ) ;',
            'has_warnings' => 1,
            'end_line' => 80,
            'block_id' => 0,
            'start_line' => 80
          },
          {
            'has_warnings' => 1,
            'start_line' => 82,
            'end_line' => 82,
            'block_id' => 4,
            'src' => ' local $TODO = \'\' ;',
            'token_num' => 5,
            'indent' => 1
          },
          {
            'token_num' => 11,
            'indent' => 1,
            'has_warnings' => 1,
            'start_line' => 84,
            'end_line' => 84,
            'block_id' => 4,
            'src' => ' open my $f , ">$filename" or skip ( "Can\'t write temp file $filename: $!" ) ;'
          },
          {
            'token_num' => 4,
            'indent' => 1,
            'has_warnings' => 1,
            'end_line' => 85,
            'start_line' => 85,
            'block_id' => 4,
            'src' => ' print $f q{BEGIN { print "block 1\\n"; }
CHECK { print "block 2\\n"; }
INIT  { print "block 3\\n"; }
	print "block 4\\n";
END   { print "block 5\\n"; }
} ;'
          },
          {
            'src' => ' close $f or die "Could not close: $!" ;',
            'block_id' => 4,
            'end_line' => 92,
            'start_line' => 92,
            'has_warnings' => 1,
            'indent' => 1,
            'token_num' => 6
          },
          {
            'has_warnings' => 1,
            'end_line' => 97,
            'start_line' => 93,
            'block_id' => 4,
            'src' => ' $r = runperl ( switches => [ \'-c\' ] , progfile => $filename , stderr => 1 , ) ;',
            'token_num' => 20,
            'indent' => 1
          },
          {
            'has_warnings' => 1,
            'block_id' => 4,
            'end_line' => 108,
            'start_line' => 100,
            'src' => ' ok ( $r =~/$filename syntax OK/ && $r =~/\\bblock 1\\b/ && $r =~/\\bblock 2\\b/ && $r !~/\\bblock 3\\b/ && $r !~/\\bblock 4\\b/ && $r !~/\\bblock 5\\b/ , \'-c\' ) ;',
            'token_num' => 41,
            'indent' => 1
          },
          {
            'indent' => 1,
            'token_num' => 10,
            'src' => ' skip \'locales not available\' , 1 unless locales_enabled ( \'LC_ALL\' ) ;',
            'end_line' => 112,
            'block_id' => 5,
            'start_line' => 112,
            'has_warnings' => 1
          },
          {
            'indent' => 1,
            'token_num' => 5,
            'src' => ' my $tempdir = tempfile ;',
            'end_line' => 114,
            'block_id' => 5,
            'start_line' => 114,
            'has_warnings' => 1
          },
          {
            'has_warnings' => 1,
            'block_id' => 5,
            'end_line' => 115,
            'start_line' => 115,
            'src' => ' mkdir $tempdir , 0700 or die "Can\'t mkdir \'$tempdir\': $!" ;',
            'token_num' => 8,
            'indent' => 1
          },
          {
            'start_line' => 117,
            'end_line' => 117,
            'block_id' => 5,
            'has_warnings' => 1,
            'src' => ' local $ENV { \'LC_ALL\' } = \'C\' ;',
            'indent' => 1,
            'token_num' => 8
          },
          {
            'end_line' => 118,
            'block_id' => 5,
            'start_line' => 118,
            'has_warnings' => 1,
            'src' => ' local $ENV { LANGUAGE } = \'C\' ;',
            'indent' => 1,
            'token_num' => 8
          },
          {
            'src' => ' setlocale ( LC_ALL , "C" ) ;',
            'end_line' => 119,
            'start_line' => 119,
            'block_id' => 5,
            'has_warnings' => 1,
            'indent' => 1,
            'token_num' => 7
          },
          {
            'indent' => 1,
            'token_num' => 3,
            'src' => ' require Errno ;',
            'end_line' => 123,
            'block_id' => 5,
            'start_line' => 123,
            'has_warnings' => 0
          },
          {
            'src' => ' import Errno qw(EACCES EISDIR) ;',
            'start_line' => 124,
            'end_line' => 124,
            'block_id' => 5,
            'has_warnings' => 1,
            'indent' => 1,
            'token_num' => 7
          },
          {
            'token_num' => 21,
            'indent' => 1,
            'has_warnings' => 1,
            'start_line' => 125,
            'end_line' => 127,
            'block_id' => 5,
            'src' => ' my $error = do { local $! = $^O eq \'MSWin32\' ? & EACCES : & EISDIR ; "$!" } ;'
          },
          {
            'indent' => 1,
            'token_num' => 17,
            'end_line' => 127,
            'start_line' => 125,
            'block_id' => 5,
            'has_warnings' => 1,
            'src' => ' do { local $! = $^O eq \'MSWin32\' ? & EACCES : & EISDIR ; "$!" }'
          },
          {
            'indent' => 2,
            'token_num' => 13,
            'src' => ' local $! = $^O eq \'MSWin32\' ? & EACCES : & EISDIR ;',
            'end_line' => 126,
            'start_line' => 126,
            'block_id' => 6,
            'has_warnings' => 1
          },
          {
            'has_warnings' => 1,
            'end_line' => 132,
            'start_line' => 128,
            'block_id' => 5,
            'src' => ' like ( runperl ( switches => [ \'-c\' ] , args => [ $tempdir ] , stderr => 1 ) , qr/Can\'t open perl script.*$tempdir.*\\Q$error/s , "RT \\#61362: Cannot syntax-check a directory" ) ;',
            'token_num' => 30,
            'indent' => 1
          },
          {
            'indent' => 1,
            'token_num' => 6,
            'start_line' => 133,
            'end_line' => 133,
            'block_id' => 5,
            'has_warnings' => 1,
            'src' => ' rmdir $tempdir or die "Can\'t rmdir \'$tempdir\': $!" ;'
          },
          {
            'has_warnings' => 1,
            'end_line' => 141,
            'start_line' => 138,
            'block_id' => 0,
            'src' => ' $r = runperl ( switches => [ sprintf ( "-l%o" , ord \'x\' ) ] , prog => \'print for qw/foo bar/\' ) ;',
            'token_num' => 21,
            'indent' => 0
          },
          {
            'src' => ' is ( $r , \'fooxbarx\' , \'-l with octal number\' ) ;',
            'start_line' => 142,
            'end_line' => 142,
            'block_id' => 0,
            'has_warnings' => 1,
            'indent' => 0,
            'token_num' => 9
          },
          {
            'block_id' => 0,
            'end_line' => 150,
            'start_line' => 146,
            'has_warnings' => 1,
            'src' => ' $r = runperl ( switches => [ \'-s\' ] , prog => \'for (qw/abc def ghi/) {print defined $$_ ? $$_ : q(-)}\' , args => [ \'--\' , \'-abc=2\' , \'-def\' , ] , ) ;',
            'indent' => 0,
            'token_num' => 27
          },
          {
            'src' => ' is ( $r , \'21-\' , \'-s switch parsing\' ) ;',
            'has_warnings' => 1,
            'end_line' => 151,
            'start_line' => 151,
            'block_id' => 0,
            'token_num' => 9,
            'indent' => 0
          },
          {
            'indent' => 0,
            'token_num' => 6,
            'block_id' => 0,
            'end_line' => 153,
            'start_line' => 153,
            'has_warnings' => 1,
            'src' => ' $filename = tempfile ( ) ;'
          },
          {
            'token_num' => 11,
            'indent' => 1,
            'src' => ' open my $f , ">$filename" or skip ( "Can\'t write temp file $filename: $!" ) ;',
            'has_warnings' => 1,
            'block_id' => 7,
            'end_line' => 155,
            'start_line' => 155
          },
          {
            'src' => ' print $f q{#!perl -s
BEGIN { print $x,$y; exit }
} ;',
            'end_line' => 156,
            'start_line' => 156,
            'block_id' => 7,
            'has_warnings' => 1,
            'indent' => 1,
            'token_num' => 4
          },
          {
            'src' => ' close $f or die "Could not close: $!" ;',
            'has_warnings' => 1,
            'block_id' => 7,
            'end_line' => 160,
            'start_line' => 160,
            'token_num' => 6,
            'indent' => 1
          },
          {
            'src' => ' $r = runperl ( progfile => $filename , args => [ \'-x=foo -y\' ] , ) ;',
            'has_warnings' => 1,
            'end_line' => 164,
            'start_line' => 161,
            'block_id' => 7,
            'token_num' => 16,
            'indent' => 1
          },
          {
            'token_num' => 9,
            'indent' => 1,
            'src' => ' is ( $r , \'foo1\' , \'-s on the shebang line\' ) ;',
            'has_warnings' => 1,
            'end_line' => 165,
            'block_id' => 7,
            'start_line' => 165
          },
          {
            'indent' => 0,
            'token_num' => 6,
            'start_line' => 169,
            'end_line' => 169,
            'block_id' => 0,
            'has_warnings' => 1,
            'src' => ' $filename = tempfile ( ) ;'
          },
          {
            'has_warnings' => 1,
            'block_id' => 8,
            'end_line' => 171,
            'start_line' => 171,
            'src' => ' open my $f , ">$filename" or skip ( "Can\'t write temp file $filename: $!" ) ;',
            'token_num' => 11,
            'indent' => 1
          },
          {
            'src' => ' print $f q{#!perl -sn
BEGIN { print $x; exit }
} ;',
            'end_line' => 172,
            'block_id' => 8,
            'start_line' => 172,
            'has_warnings' => 1,
            'indent' => 1,
            'token_num' => 4
          },
          {
            'indent' => 1,
            'token_num' => 6,
            'start_line' => 176,
            'end_line' => 176,
            'block_id' => 8,
            'has_warnings' => 1,
            'src' => ' close $f or die "Could not close: $!" ;'
          },
          {
            'has_warnings' => 1,
            'start_line' => 177,
            'end_line' => 180,
            'block_id' => 8,
            'src' => ' $r = runperl ( progfile => $filename , args => [ \'-x=foo\' ] , ) ;',
            'token_num' => 16,
            'indent' => 1
          },
          {
            'token_num' => 9,
            'indent' => 1,
            'src' => ' is ( $r , \'foo\' , \'-sn on the shebang line\' ) ;',
            'has_warnings' => 1,
            'end_line' => 181,
            'start_line' => 181,
            'block_id' => 8
          },
          {
            'has_warnings' => 1,
            'block_id' => 0,
            'end_line' => 186,
            'start_line' => 186,
            'src' => ' my $package = tempfile ( ) ;',
            'token_num' => 7,
            'indent' => 0
          },
          {
            'has_warnings' => 1,
            'end_line' => 187,
            'start_line' => 187,
            'block_id' => 0,
            'src' => ' $filename = "$package.pm" ;',
            'token_num' => 4,
            'indent' => 0
          },
          {
            'has_warnings' => 1,
            'block_id' => 9,
            'end_line' => 189,
            'start_line' => 189,
            'src' => ' open my $f , ">$filename" or skip ( "Can\'t write temp file $filename: $!" , 4 ) ;',
            'token_num' => 13,
            'indent' => 1
          },
          {
            'has_warnings' => 1,
            'end_line' => 190,
            'block_id' => 9,
            'start_line' => 190,
            'src' => ' print $f qq{package $package;
sub import { print map "<\\$_>", \\@_ }
1;
} ;',
            'token_num' => 4,
            'indent' => 1
          },
          {
            'token_num' => 6,
            'indent' => 1,
            'has_warnings' => 1,
            'end_line' => 195,
            'block_id' => 9,
            'start_line' => 195,
            'src' => ' close $f or die "Could not close: $!" ;'
          },
          {
            'token_num' => 16,
            'indent' => 1,
            'src' => ' $r = runperl ( switches => [ "-M$package" ] , prog => \'1\' , ) ;',
            'has_warnings' => 1,
            'block_id' => 9,
            'end_line' => 199,
            'start_line' => 196
          },
          {
            'src' => ' is ( $r , "<$package>" , \'-M\' ) ;',
            'start_line' => 200,
            'end_line' => 200,
            'block_id' => 9,
            'has_warnings' => 1,
            'indent' => 1,
            'token_num' => 9
          },
          {
            'token_num' => 16,
            'indent' => 1,
            'src' => ' $r = runperl ( switches => [ "-M$package=foo" ] , prog => \'1\' , ) ;',
            'has_warnings' => 1,
            'end_line' => 204,
            'block_id' => 9,
            'start_line' => 201
          },
          {
            'indent' => 1,
            'token_num' => 9,
            'end_line' => 205,
            'start_line' => 205,
            'block_id' => 9,
            'has_warnings' => 1,
            'src' => ' is ( $r , "<$package><foo>" , \'-M with import parameter\' ) ;'
          },
          {
            'indent' => 1,
            'token_num' => 16,
            'end_line' => 209,
            'block_id' => 9,
            'start_line' => 206,
            'has_warnings' => 1,
            'src' => ' $r = runperl ( switches => [ "-m$package" ] , prog => \'1\' , ) ;'
          },
          {
            'indent' => 1,
            'token_num' => 16,
            'src' => ' { local $TODO = \'\' ; is ( $r , \'\' , \'-m\' ) ; }',
            'start_line' => 211,
            'end_line' => 214,
            'block_id' => 9,
            'has_warnings' => 1
          },
          {
            'indent' => 2,
            'token_num' => 5,
            'start_line' => 212,
            'end_line' => 212,
            'block_id' => 10,
            'has_warnings' => 1,
            'src' => ' local $TODO = \'\' ;'
          },
          {
            'token_num' => 9,
            'indent' => 2,
            'has_warnings' => 1,
            'end_line' => 213,
            'start_line' => 213,
            'block_id' => 10,
            'src' => ' is ( $r , \'\' , \'-m\' ) ;'
          },
          {
            'src' => ' $r = runperl ( switches => [ "-m$package=foo,bar" ] , prog => \'1\' , ) ;',
            'end_line' => 218,
            'start_line' => 215,
            'block_id' => 9,
            'has_warnings' => 1,
            'indent' => 1,
            'token_num' => 16
          },
          {
            'has_warnings' => 1,
            'end_line' => 219,
            'start_line' => 219,
            'block_id' => 9,
            'src' => ' is ( $r , "<$package><foo><bar>" , \'-m with import parameters\' ) ;',
            'token_num' => 9,
            'indent' => 1
          },
          {
            'src' => ' push @tmpfiles , $filename ;',
            'start_line' => 220,
            'end_line' => 220,
            'block_id' => 9,
            'has_warnings' => 1,
            'indent' => 1,
            'token_num' => 5
          },
          {
            'indent' => 1,
            'token_num' => 166,
            'end_line' => 252,
            'start_line' => 222,
            'block_id' => 9,
            'has_warnings' => 1,
            'src' => ' { local $TODO = \'\' ; is ( runperl ( switches => [ \'-MTie::Hash\' ] , stderr => 1 , prog => 1 ) , \'\' , "-MFoo::Bar allowed" ) ; like ( runperl ( switches => [ "-M:$package" ] , stderr => 1 , prog => \'die q{oops}\' ) , qr/Invalid module name [\\w:]+ with -M option\\b/ , "-M:Foo not allowed" ) ; like ( runperl ( switches => [ \'-mA:B:C\' ] , stderr => 1 , prog => \'die q{oops}\' ) , qr/Invalid module name [\\w:]+ with -m option\\b/ , "-mFoo:Bar not allowed" ) ; like ( runperl ( switches => [ \'-m-A:B:C\' ] , stderr => 1 , prog => \'die q{oops}\' ) , qr/Invalid module name [\\w:]+ with -m option\\b/ , "-m-Foo:Bar not allowed" ) ; like ( runperl ( switches => [ \'-m-\' ] , stderr => 1 , prog => \'die q{oops}\' ) , qr/Module name required with -m option\\b/ , "-m- not allowed" ) ; like ( runperl ( switches => [ \'-M-=\' ] , stderr => 1 , prog => \'die q{oops}\' ) , qr/Module name required with -M option\\b/ , "-M- not allowed" ) ; }'
          },
          {
            'start_line' => 223,
            'end_line' => 223,
            'block_id' => 11,
            'has_warnings' => 1,
            'src' => ' local $TODO = \'\' ;',
            'indent' => 2,
            'token_num' => 5
          },
          {
            'indent' => 2,
            'token_num' => 24,
            'src' => ' is ( runperl ( switches => [ \'-MTie::Hash\' ] , stderr => 1 , prog => 1 ) , \'\' , "-MFoo::Bar allowed" ) ;',
            'block_id' => 11,
            'end_line' => 226,
            'start_line' => 225,
            'has_warnings' => 1
          },
          {
            'src' => ' like ( runperl ( switches => [ "-M:$package" ] , stderr => 1 , prog => \'die q{oops}\' ) , qr/Invalid module name [\\w:]+ with -M option\\b/ , "-M:Foo not allowed" ) ;',
            'end_line' => 231,
            'start_line' => 228,
            'block_id' => 11,
            'has_warnings' => 1,
            'indent' => 2,
            'token_num' => 27
          },
          {
            'indent' => 2,
            'token_num' => 27,
            'src' => ' like ( runperl ( switches => [ \'-mA:B:C\' ] , stderr => 1 , prog => \'die q{oops}\' ) , qr/Invalid module name [\\w:]+ with -m option\\b/ , "-mFoo:Bar not allowed" ) ;',
            'block_id' => 11,
            'end_line' => 236,
            'start_line' => 233,
            'has_warnings' => 1
          },
          {
            'src' => ' like ( runperl ( switches => [ \'-m-A:B:C\' ] , stderr => 1 , prog => \'die q{oops}\' ) , qr/Invalid module name [\\w:]+ with -m option\\b/ , "-m-Foo:Bar not allowed" ) ;',
            'block_id' => 11,
            'end_line' => 241,
            'start_line' => 238,
            'has_warnings' => 1,
            'indent' => 2,
            'token_num' => 27
          },
          {
            'token_num' => 27,
            'indent' => 2,
            'has_warnings' => 1,
            'end_line' => 246,
            'start_line' => 243,
            'block_id' => 11,
            'src' => ' like ( runperl ( switches => [ \'-m-\' ] , stderr => 1 , prog => \'die q{oops}\' ) , qr/Module name required with -m option\\b/ , "-m- not allowed" ) ;'
          },
          {
            'src' => ' like ( runperl ( switches => [ \'-M-=\' ] , stderr => 1 , prog => \'die q{oops}\' ) , qr/Module name required with -M option\\b/ , "-M- not allowed" ) ;',
            'has_warnings' => 1,
            'block_id' => 11,
            'end_line' => 251,
            'start_line' => 248,
            'token_num' => 27,
            'indent' => 2
          },
          {
            'indent' => 0,
            'token_num' => 17,
            'end_line' => 255,
            'start_line' => 254,
            'block_id' => 0,
            'has_warnings' => 1,
            'src' => ' is runperl ( stderr => 1 , prog => \'#!perl -m\' ) , qq \'Too late for "-m" option at -e line 1.\\n\' , \'#!perl -m\' ;'
          },
          {
            'has_warnings' => 1,
            'end_line' => 257,
            'block_id' => 0,
            'start_line' => 256,
            'src' => ' is runperl ( stderr => 1 , prog => \'#!perl -M\' ) , qq \'Too late for "-M" option at -e line 1.\\n\' , \'#!perl -M\' ;',
            'token_num' => 17,
            'indent' => 0
          },
          {
            'has_warnings' => 1,
            'start_line' => 261,
            'end_line' => 291,
            'block_id' => 0,
            'src' => ' { local $TODO = \'\' ; like ( runperl ( switches => [ \'-V\' ] ) , qr/(\\n.*){20}/ , \'-V generates 20+ lines\' ) ; like ( runperl ( switches => [ \'-V\' ] ) , qr/\\ASummary of my perl5 .*configuration:/ , \'-V looks okay\' ) ; chomp ( $r = runperl ( switches => [ \'-V:osname\' ] ) ) ; is ( $r , "osname=\'$^O\';" , \'perl -V:osname\' ) ; chomp ( $r = runperl ( switches => [ \'-V:this_var_makes_switches_test_fail\' ] ) ) ; is ( $r , "this_var_makes_switches_test_fail=\'UNKNOWN\';" , \'perl -V:unknown var\' ) ; $r = runperl ( switches => [ \'"-V:i\\D+size"\' ] ) ; like ( $r , qr/^(?!.*(not found|UNKNOWN))./ , \'perl -V:re got a result\' ) ; ok ( ! ( grep !/^i\\D+size=/ , split/^/ , $r ) , \'-V:re correct\' ) ; }',
            'token_num' => 135,
            'indent' => 0
          },
          {
            'src' => ' local $TODO = \'\' ;',
            'has_warnings' => 1,
            'block_id' => 12,
            'end_line' => 262,
            'start_line' => 262,
            'token_num' => 5,
            'indent' => 1
          },
          {
            'indent' => 1,
            'token_num' => 19,
            'end_line' => 267,
            'block_id' => 12,
            'start_line' => 266,
            'has_warnings' => 1,
            'src' => ' like ( runperl ( switches => [ \'-V\' ] ) , qr/(\\n.*){20}/ , \'-V generates 20+ lines\' ) ;'
          },
          {
            'token_num' => 19,
            'indent' => 1,
            'has_warnings' => 1,
            'start_line' => 269,
            'end_line' => 271,
            'block_id' => 12,
            'src' => ' like ( runperl ( switches => [ \'-V\' ] ) , qr/\\ASummary of my perl5 .*configuration:/ , \'-V looks okay\' ) ;'
          },
          {
            'indent' => 1,
            'token_num' => 14,
            'start_line' => 274,
            'end_line' => 274,
            'block_id' => 12,
            'has_warnings' => 1,
            'src' => ' chomp ( $r = runperl ( switches => [ \'-V:osname\' ] ) ) ;'
          },
          {
            'token_num' => 9,
            'indent' => 1,
            'src' => ' is ( $r , "osname=\'$^O\';" , \'perl -V:osname\' ) ;',
            'has_warnings' => 1,
            'end_line' => 275,
            'start_line' => 275,
            'block_id' => 12
          },
          {
            'src' => ' chomp ( $r = runperl ( switches => [ \'-V:this_var_makes_switches_test_fail\' ] ) ) ;',
            'block_id' => 12,
            'end_line' => 278,
            'start_line' => 278,
            'has_warnings' => 1,
            'indent' => 1,
            'token_num' => 14
          },
          {
            'token_num' => 9,
            'indent' => 1,
            'src' => ' is ( $r , "this_var_makes_switches_test_fail=\'UNKNOWN\';" , \'perl -V:unknown var\' ) ;',
            'has_warnings' => 1,
            'end_line' => 280,
            'start_line' => 279,
            'block_id' => 12
          },
          {
            'token_num' => 11,
            'indent' => 1,
            'src' => ' $r = runperl ( switches => [ \'"-V:i\\D+size"\' ] ) ;',
            'has_warnings' => 1,
            'block_id' => 12,
            'end_line' => 285,
            'start_line' => 285
          },
          {
            'src' => ' like ( $r , qr/^(?!.*(not found|UNKNOWN))./ , \'perl -V:re got a result\' ) ;',
            'end_line' => 287,
            'block_id' => 12,
            'start_line' => 287,
            'has_warnings' => 1,
            'indent' => 1,
            'token_num' => 12
          },
          {
            'src' => ' ok ( ! ( grep !/^i\\D+size=/ , split/^/ , $r ) , \'-V:re correct\' ) ;',
            'has_warnings' => 1,
            'end_line' => 290,
            'block_id' => 12,
            'start_line' => 290,
            'token_num' => 21,
            'indent' => 1
          },
          {
            'token_num' => 67,
            'indent' => 0,
            'has_warnings' => 1,
            'block_id' => 0,
            'end_line' => 310,
            'start_line' => 295,
            'src' => ' { local $TODO = \'\' ; SKIP : { skip "Win32 miniperl produces a default archname in -v" , 1 if $^O eq \'MSWin32\' && is_miniperl ; my $v = sprintf "%vd" , $^ V ; my $ver = $Config { PERL_VERSION } ; my $rel = $Config { PERL_SUBVERSION } ; like ( runperl ( switches => [ \'-v\' ] ) , qr/This is perl 5, version \\Q$ver\\E, subversion \\Q$rel\\E \\(v\\Q$v\\E(?:[-*\\w]+| \\([^)]+\\))?\\) built for \\Q$Config{archname}\\E.+Copyright.+Larry Wall.+Artistic License.+GNU General Public License/s , \'-v looks okay\' ) ; } }'
          },
          {
            'start_line' => 296,
            'end_line' => 296,
            'block_id' => 13,
            'has_warnings' => 1,
            'src' => ' local $TODO = \'\' ;',
            'indent' => 1,
            'token_num' => 5
          },
          {
            'token_num' => 11,
            'indent' => 2,
            'has_warnings' => 1,
            'end_line' => 302,
            'block_id' => 14,
            'start_line' => 301,
            'src' => ' skip "Win32 miniperl produces a default archname in -v" , 1 if $^O eq \'MSWin32\' && is_miniperl ;'
          },
          {
            'indent' => 2,
            'token_num' => 9,
            'src' => ' my $v = sprintf "%vd" , $^ V ;',
            'end_line' => 303,
            'start_line' => 303,
            'block_id' => 14,
            'has_warnings' => 1
          },
          {
            'token_num' => 8,
            'indent' => 2,
            'has_warnings' => 1,
            'end_line' => 304,
            'block_id' => 14,
            'start_line' => 304,
            'src' => ' my $ver = $Config { PERL_VERSION } ;'
          },
          {
            'indent' => 2,
            'token_num' => 8,
            'src' => ' my $rel = $Config { PERL_SUBVERSION } ;',
            'start_line' => 305,
            'end_line' => 305,
            'block_id' => 14,
            'has_warnings' => 1
          },
          {
            'src' => ' like ( runperl ( switches => [ \'-v\' ] ) , qr/This is perl 5, version \\Q$ver\\E, subversion \\Q$rel\\E \\(v\\Q$v\\E(?:[-*\\w]+| \\([^)]+\\))?\\) built for \\Q$Config{archname}\\E.+Copyright.+Larry Wall.+Artistic License.+GNU General Public License/s , \'-v looks okay\' ) ;',
            'start_line' => 306,
            'end_line' => 308,
            'block_id' => 14,
            'has_warnings' => 1,
            'indent' => 2,
            'token_num' => 20
          },
          {
            'token_num' => 26,
            'indent' => 0,
            'src' => ' { local $TODO = \'\' ; like ( runperl ( switches => [ \'-h\' ] ) , qr/Usage: .+(?i:perl(?:$Config{_exe})?).+switches.+programfile.+arguments/ , \'-h looks okay\' ) ; }',
            'has_warnings' => 1,
            'end_line' => 321,
            'start_line' => 314,
            'block_id' => 0
          },
          {
            'src' => ' local $TODO = \'\' ;',
            'end_line' => 315,
            'start_line' => 315,
            'block_id' => 15,
            'has_warnings' => 1,
            'indent' => 1,
            'token_num' => 5
          },
          {
            'has_warnings' => 1,
            'end_line' => 319,
            'start_line' => 317,
            'block_id' => 15,
            'src' => ' like ( runperl ( switches => [ \'-h\' ] ) , qr/Usage: .+(?i:perl(?:$Config{_exe})?).+switches.+programfile.+arguments/ , \'-h looks okay\' ) ;',
            'token_num' => 19,
            'indent' => 1
          },
          {
            'token_num' => 66,
            'indent' => 0,
            'src' => ' foreach my $switch ( split// , "ABbGgHJjKkLNOoPQqRrYyZz123456789_" ) { local $TODO = \'\' ; like ( runperl ( switches => [ "-$switch" ] , stderr => 1 , prog => \'die q{oops}\' ) , qr/\\QUnrecognized switch: -$switch  (-h will show valid options)./ , "-$switch correctly unknown" ) ; like ( runperl ( stderr => 1 , prog => "#!perl -$switch" ) , qr/^Unrecognized switch: -$switch  \\(-h will show valid (?x:
	     )options\\) at -e line 1\\./ , "-$switch unrecognised on #! line" ) ; }',
            'has_warnings' => 1,
            'start_line' => 325,
            'end_line' => 339,
            'block_id' => 0
          },
          {
            'has_warnings' => 1,
            'end_line' => 327,
            'start_line' => 327,
            'block_id' => 16,
            'src' => ' local $TODO = \'\' ;',
            'token_num' => 5,
            'indent' => 1
          },
          {
            'indent' => 1,
            'token_num' => 27,
            'start_line' => 329,
            'end_line' => 332,
            'block_id' => 16,
            'has_warnings' => 1,
            'src' => ' like ( runperl ( switches => [ "-$switch" ] , stderr => 1 , prog => \'die q{oops}\' ) , qr/\\QUnrecognized switch: -$switch  (-h will show valid options)./ , "-$switch correctly unknown" ) ;'
          },
          {
            'token_num' => 21,
            'indent' => 1,
            'has_warnings' => 1,
            'block_id' => 16,
            'end_line' => 338,
            'start_line' => 335,
            'src' => ' like ( runperl ( stderr => 1 , prog => "#!perl -$switch" ) , qr/^Unrecognized switch: -$switch  \\(-h will show valid (?x:
	     )options\\) at -e line 1\\./ , "-$switch unrecognised on #! line" ) ;'
          },
          {
            'end_line' => 348,
            'start_line' => 342,
            'block_id' => 0,
            'has_warnings' => 1,
            'src' => ' for ( qw( e f x E S V ) ) { $r = runperl ( stderr => 1 , prog => "#!perl -$_" , ) ; is $r , "Can\'t emulate -$_ on #! line at -e line 1.\\n" , "-$_ on #! line" ; }',
            'indent' => 0,
            'token_num' => 30
          },
          {
            'token_num' => 14,
            'indent' => 1,
            'has_warnings' => 1,
            'block_id' => 17,
            'end_line' => 346,
            'start_line' => 343,
            'src' => ' $r = runperl ( stderr => 1 , prog => "#!perl -$_" , ) ;'
          },
          {
            'token_num' => 7,
            'indent' => 1,
            'src' => ' is $r , "Can\'t emulate -$_ on #! line at -e line 1.\\n" , "-$_ on #! line" ;',
            'has_warnings' => 1,
            'block_id' => 17,
            'end_line' => 347,
            'start_line' => 347
          },
          {
            'indent' => 0,
            'token_num' => 207,
            'end_line' => 403,
            'start_line' => 352,
            'block_id' => 0,
            'has_warnings' => 1,
            'src' => ' { local $TODO = \'\' ; sub do_i_unlink { unlink_all ( "file" , "file.bak" ) } open ( FILE , ">file" ) or die "$0: Failed to create \'file\': $!" ; print FILE qq{foo yada dada
bada foo bing
king kong foo
} ; close FILE ; END { do_i_unlink ( ) } runperl ( switches => [ \'-pi.bak\' ] , prog => \'s/foo/bar/\' , args => [ \'file\' ] ) ; open ( FILE , "file" ) or die "$0: Failed to open \'file\': $!" ; chomp ( my @file = < FILE > ) ; close FILE ; open ( BAK , "file.bak" ) or die "$0: Failed to open \'file\': $!" ; chomp ( my @bak = < BAK > ) ; close BAK ; is ( join ( ":" , @file ) , "bar yada dada:bada bar bing:king kong bar" , "-i new file" ) ; is ( join ( ":" , @bak ) , "foo yada dada:bada foo bing:king kong foo" , "-i backup file" ) ; my $out1 = runperl ( switches => [ \'-i.bak -p\' ] , prog => \'exit\' , stderr => 1 , stdin => "1\\n" , ) ; is ( $out1 , "-i used with no filenames on the command line, reading from STDIN.\\n" , "warning when no files given" ) ; my $out2 = runperl ( switches => [ \'-i.bak -p\' ] , prog => \'exit\' , stderr => 1 , stdin => "1\\n" , args => [ \'file\' ] , ) ; is ( $out2 , "" , "no warning when files given" ) ; }'
          },
          {
            'block_id' => 18,
            'end_line' => 353,
            'start_line' => 353,
            'has_warnings' => 1,
            'src' => ' local $TODO = \'\' ;',
            'indent' => 1,
            'token_num' => 5
          },
          {
            'src' => ' sub do_i_unlink { unlink_all ( "file" , "file.bak" ) }',
            'has_warnings' => 1,
            'end_line' => 355,
            'start_line' => 355,
            'block_id' => 18,
            'token_num' => 10,
            'indent' => 1
          },
          {
            'indent' => 1,
            'token_num' => 10,
            'end_line' => 357,
            'block_id' => 18,
            'start_line' => 357,
            'has_warnings' => 1,
            'src' => ' open ( FILE , ">file" ) or die "$0: Failed to create \'file\': $!" ;'
          },
          {
            'start_line' => 358,
            'end_line' => 358,
            'block_id' => 18,
            'has_warnings' => 1,
            'src' => ' print FILE qq{foo yada dada
bada foo bing
king kong foo
} ;',
            'indent' => 1,
            'token_num' => 4
          },
          {
            'token_num' => 3,
            'indent' => 1,
            'has_warnings' => 1,
            'block_id' => 18,
            'end_line' => 363,
            'start_line' => 363,
            'src' => ' close FILE ;'
          },
          {
            'end_line' => 367,
            'block_id' => 18,
            'start_line' => 367,
            'has_warnings' => 1,
            'src' => ' runperl ( switches => [ \'-pi.bak\' ] , prog => \'s/foo/bar/\' , args => [ \'file\' ] ) ;',
            'indent' => 1,
            'token_num' => 19
          },
          {
            'src' => ' open ( FILE , "file" ) or die "$0: Failed to open \'file\': $!" ;',
            'has_warnings' => 1,
            'start_line' => 369,
            'end_line' => 369,
            'block_id' => 18,
            'token_num' => 10,
            'indent' => 1
          },
          {
            'indent' => 1,
            'token_num' => 10,
            'src' => ' chomp ( my @file = < FILE > ) ;',
            'start_line' => 370,
            'end_line' => 370,
            'block_id' => 18,
            'has_warnings' => 1
          },
          {
            'src' => ' close FILE ;',
            'end_line' => 371,
            'start_line' => 371,
            'block_id' => 18,
            'has_warnings' => 1,
            'indent' => 1,
            'token_num' => 3
          },
          {
            'token_num' => 10,
            'indent' => 1,
            'has_warnings' => 1,
            'block_id' => 18,
            'end_line' => 373,
            'start_line' => 373,
            'src' => ' open ( BAK , "file.bak" ) or die "$0: Failed to open \'file\': $!" ;'
          },
          {
            'src' => ' chomp ( my @bak = < BAK > ) ;',
            'has_warnings' => 1,
            'end_line' => 374,
            'start_line' => 374,
            'block_id' => 18,
            'token_num' => 10,
            'indent' => 1
          },
          {
            'token_num' => 3,
            'indent' => 1,
            'src' => ' close BAK ;',
            'has_warnings' => 1,
            'block_id' => 18,
            'end_line' => 375,
            'start_line' => 375
          },
          {
            'has_warnings' => 1,
            'end_line' => 379,
            'block_id' => 18,
            'start_line' => 377,
            'src' => ' is ( join ( ":" , @file ) , "bar yada dada:bada bar bing:king kong bar" , "-i new file" ) ;',
            'token_num' => 14,
            'indent' => 1
          },
          {
            'src' => ' is ( join ( ":" , @bak ) , "foo yada dada:bada foo bing:king kong foo" , "-i backup file" ) ;',
            'end_line' => 382,
            'block_id' => 18,
            'start_line' => 380,
            'has_warnings' => 1,
            'indent' => 1,
            'token_num' => 14
          },
          {
            'token_num' => 25,
            'indent' => 1,
            'has_warnings' => 1,
            'block_id' => 18,
            'end_line' => 389,
            'start_line' => 384,
            'src' => ' my $out1 = runperl ( switches => [ \'-i.bak -p\' ] , prog => \'exit\' , stderr => 1 , stdin => "1\\n" , ) ;'
          },
          {
            'indent' => 1,
            'token_num' => 9,
            'src' => ' is ( $out1 , "-i used with no filenames on the command line, reading from STDIN.\\n" , "warning when no files given" ) ;',
            'start_line' => 390,
            'end_line' => 394,
            'block_id' => 18,
            'has_warnings' => 1
          },
          {
            'token_num' => 31,
            'indent' => 1,
            'has_warnings' => 1,
            'end_line' => 401,
            'block_id' => 18,
            'start_line' => 395,
            'src' => ' my $out2 = runperl ( switches => [ \'-i.bak -p\' ] , prog => \'exit\' , stderr => 1 , stdin => "1\\n" , args => [ \'file\' ] , ) ;'
          },
          {
            'token_num' => 9,
            'indent' => 1,
            'src' => ' is ( $out2 , "" , "no warning when files given" ) ;',
            'has_warnings' => 1,
            'end_line' => 402,
            'start_line' => 402,
            'block_id' => 18
          },
          {
            'token_num' => 4,
            'indent' => 0,
            'src' => ' $TODO = \'\' ;',
            'has_warnings' => 1,
            'end_line' => 407,
            'block_id' => 0,
            'start_line' => 407
          },
          {
            'src' => ' $r = runperl ( switches => [ \'-E\' , \'"say q(Hello, world!)"\' ] ) ;',
            'start_line' => 409,
            'end_line' => 411,
            'block_id' => 0,
            'has_warnings' => 1,
            'indent' => 0,
            'token_num' => 13
          },
          {
            'token_num' => 9,
            'indent' => 0,
            'src' => ' is ( $r , "Hello, world!\\n" , "-E say" ) ;',
            'has_warnings' => 1,
            'start_line' => 412,
            'end_line' => 412,
            'block_id' => 0
          },
          {
            'src' => ' $r = runperl ( switches => [ \'-E\' , \'"no warnings q{experimental::smartmatch}; undef ~~ undef and say q(Hello, world!)"\' ] ) ;',
            'has_warnings' => 1,
            'end_line' => 417,
            'start_line' => 415,
            'block_id' => 0,
            'token_num' => 13,
            'indent' => 0
          },
          {
            'token_num' => 9,
            'indent' => 0,
            'has_warnings' => 1,
            'end_line' => 418,
            'start_line' => 418,
            'block_id' => 0,
            'src' => ' is ( $r , "Hello, world!\\n" , "-E ~~" ) ;'
          },
          {
            'indent' => 0,
            'token_num' => 13,
            'end_line' => 422,
            'start_line' => 420,
            'block_id' => 0,
            'has_warnings' => 1,
            'src' => ' $r = runperl ( switches => [ \'-E\' , \'"no warnings q{experimental::smartmatch}; given(undef) {when(undef) { say q(Hello, world!)"}}\' ] ) ;'
          },
          {
            'indent' => 0,
            'token_num' => 9,
            'start_line' => 423,
            'end_line' => 423,
            'block_id' => 0,
            'has_warnings' => 1,
            'src' => ' is ( $r , "Hello, world!\\n" , "-E given" ) ;'
          },
          {
            'indent' => 0,
            'token_num' => 21,
            'src' => ' $r = runperl ( switches => [ \'-nE\' , q("} END { say q/affe/") ] , stdin => \'zomtek\' , ) ;',
            'end_line' => 428,
            'start_line' => 425,
            'block_id' => 0,
            'has_warnings' => 1
          },
          {
            'token_num' => 9,
            'indent' => 0,
            'src' => ' is ( $r , "affe\\n" , \'-E works outside of the block created by -n\' ) ;',
            'has_warnings' => 1,
            'start_line' => 429,
            'end_line' => 429,
            'block_id' => 0
          },
          {
            'has_warnings' => 1,
            'block_id' => 0,
            'end_line' => 433,
            'start_line' => 431,
            'src' => ' $r = runperl ( switches => [ \'-E\' , q("*{\'bar\'} = sub{}; print \'Hello, world!\',qq|\\n|;") ] ) ;',
            'token_num' => 16,
            'indent' => 0
          },
          {
            'end_line' => 434,
            'start_line' => 434,
            'block_id' => 0,
            'has_warnings' => 1,
            'src' => ' is ( $r , "Hello, world!\\n" , "-E does not enable strictures" ) ;',
            'indent' => 0,
            'token_num' => 9
          },
          {
            'src' => ' $filename = tempfile ( ) ;',
            'block_id' => 0,
            'end_line' => 438,
            'start_line' => 438,
            'has_warnings' => 1,
            'indent' => 0,
            'token_num' => 6
          },
          {
            'block_id' => 21,
            'end_line' => 440,
            'start_line' => 440,
            'has_warnings' => 1,
            'src' => ' open my $f , ">$filename" or skip ( "Can\'t write temp file $filename: $!" ) ;',
            'indent' => 1,
            'token_num' => 11
          },
          {
            'has_warnings' => 1,
            'end_line' => 441,
            'start_line' => 441,
            'block_id' => 21,
            'src' => ' print $f q{#!perl -w    -iok
print "$^I\\n";
} ;',
            'token_num' => 4,
            'indent' => 1
          },
          {
            'block_id' => 21,
            'end_line' => 445,
            'start_line' => 445,
            'has_warnings' => 1,
            'src' => ' close $f or die "Could not close: $!" ;',
            'indent' => 1,
            'token_num' => 6
          },
          {
            'has_warnings' => 1,
            'end_line' => 448,
            'start_line' => 446,
            'block_id' => 21,
            'src' => ' $r = runperl ( progfile => $filename , ) ;',
            'token_num' => 10,
            'indent' => 1
          },
          {
            'indent' => 1,
            'token_num' => 12,
            'src' => ' like ( $r , qr/ok/ , \'Spaces on the #! line (#30660)\' ) ;',
            'end_line' => 449,
            'block_id' => 21,
            'start_line' => 449,
            'has_warnings' => 1
          }
        ]
, 'Compiler::Lexer::get_groups_by_syntax_level');
};

subtest 'get_used_modules' => sub {
    my $modules = Compiler::Lexer->new('')->get_used_modules($script);
    is_deeply($modules, [
          {
            'args' => '',
            'name' => 'Config'
          }
        ]
, 'Compiler::Lexer::get_used_modules');
};

done_testing;
