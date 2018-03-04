use strict;
use warnings;
use Test::More;
BEGIN {
    use_ok('Compiler::Lexer');
}
my $script =<<'__SCRIPT__';
#!./perl
#
# Test inheriting file descriptors across exec (close-on-exec).
#
# perlvar describes $^F aka $SYSTEM_FD_MAX as follows:
#
#  The maximum system file descriptor, ordinarily 2.  System file
#  descriptors are passed to exec()ed processes, while higher file
#  descriptors are not.  Also, during an open(), system file descriptors
#  are preserved even if the open() fails.  (Ordinary file descriptors
#  are closed before the open() is attempted.)  The close-on-exec
#  status of a file descriptor will be decided according to the value of
#  C<$^F> when the corresponding file, pipe, or socket was opened, not
#  the time of the exec().
#
# This documented close-on-exec behaviour is typically implemented in
# various places (e.g. pp_sys.c) with code something like:
#
#  #if defined(HAS_FCNTL) && defined(F_SETFD)
#      fcntl(fd, F_SETFD, fd > PL_maxsysfd);  /* ensure close-on-exec */
#  #endif
#
# This behaviour, therefore, is only currently implemented for platforms
# where:
#
#  a) HAS_FCNTL and F_SETFD are both defined
#  b) Integer fds are native OS handles
#
# ... which is typically just the Unix-like platforms.
#
# Notice that though integer fds are supported by the C runtime library
# on Windows, they are not native OS handles, and so are not inherited
# across an exec (though native Windows file handles are).

BEGIN {
    chdir 't' if -d 't';
    @INC = '../lib';
    require './test.pl';
    skip_all_without_config('d_fcntl');
}

use strict;

$|=1;

# When in doubt, skip.
skip_all($^O)
    if $^O eq 'VMS' or $^O eq 'MSWin32' or $^O eq 'amigaos';

sub make_tmp_file {
    my ($fname, $fcontents) = @_;
    local *FHTMP;
    open   FHTMP, ">$fname"  or die "open  '$fname': $!";
    print  FHTMP $fcontents  or die "print '$fname': $!";
    close  FHTMP             or die "close '$fname': $!";
}

my $Perl = which_perl();
my $quote = "'";

my $tmperr             = tempfile();
my $tmpfile1           = tempfile();
my $tmpfile2           = tempfile();
my $tmpfile1_contents  = "tmpfile1 line 1\ntmpfile1 line 2\n";
my $tmpfile2_contents  = "tmpfile2 line 1\ntmpfile2 line 2\n";
make_tmp_file($tmpfile1, $tmpfile1_contents);
make_tmp_file($tmpfile2, $tmpfile2_contents);

# $Child_prog is the program run by the child that inherits the fd.
# Note: avoid using ' or " in $Child_prog since it is run with -e
my $Child_prog = <<'CHILD_PROG';
my $fd = shift;
print qq{childfd=$fd\n};
open INHERIT, qq{<&=$fd} or die qq{open $fd: $!};
my $line = <INHERIT>;
close INHERIT or die qq{close $fd: $!};
print $line
CHILD_PROG
$Child_prog =~ tr/\n//d;

plan(tests => 22);

sub test_not_inherited {
    my $expected_fd = shift;
    ok( -f $tmpfile2, "tmpfile '$tmpfile2' exists" );
    my $cmd = qq{$Perl -e $quote$Child_prog$quote $expected_fd};
    # Expect 'Bad file descriptor' or similar to be written to STDERR.
    local *SAVERR; open SAVERR, ">&STDERR";  # save original STDERR
    open STDERR, ">$tmperr" or die "open '$tmperr': $!";
    my $out = `$cmd`;
    my $rc  = $? >> 8;
    open STDERR, ">&SAVERR" or die "error: restore STDERR: $!";
    close SAVERR or die "error: close SAVERR: $!";
    # XXX: it seems one cannot rely on a non-zero return code,
    # at least not on Tru64.
    # cmp_ok( $rc, '!=', 0,
    #     "child return code=$rc (non-zero means cannot inherit fd=$expected_fd)" );
    cmp_ok( $out =~ tr/\n//, '==', 1,
        "child stdout: has 1 newline (rc=$rc, should be non-zero)" );
    is( $out, "childfd=$expected_fd\n", 'child stdout: fd' );
}

sub test_inherited {
    my $expected_fd = shift;
    ok( -f $tmpfile1, "tmpfile '$tmpfile1' exists" );
    my $cmd = qq{$Perl -e $quote$Child_prog$quote $expected_fd};
    my $out = `$cmd`;
    my $rc  = $? >> 8;
    cmp_ok( $rc, '==', 0,
        "child return code=$rc (zero means inherited fd=$expected_fd ok)" );
    my @lines = split(/^/, $out);
    cmp_ok( $out =~ tr/\n//, '==', 2, 'child stdout: has 2 newlines' );
    cmp_ok( scalar(@lines),  '==', 2, 'child stdout: split into 2 lines' );
    is( $lines[0], "childfd=$expected_fd\n", 'child stdout: fd' );
    is( $lines[1], "tmpfile1 line 1\n",      'child stdout: line 1' );
}

$^F == 2 or print STDERR "# warning: \$^F is $^F (not 2)\n";

# Should not be able to inherit > $^F in the default case.
open FHPARENT2, "<$tmpfile2" or die "open '$tmpfile2': $!";
my $parentfd2 = fileno FHPARENT2;
defined $parentfd2 or die "fileno: $!";
cmp_ok( $parentfd2, '>', $^F, "parent open fd=$parentfd2 (\$^F=$^F)" );
test_not_inherited($parentfd2);
close FHPARENT2 or die "close '$tmpfile2': $!";

# Should be able to inherit $^F after setting to $parentfd2
# Need to set $^F before open because close-on-exec set at time of open.
$^F = $parentfd2;
open FHPARENT1, "<$tmpfile1" or die "open '$tmpfile1': $!";
my $parentfd1 = fileno FHPARENT1;
defined $parentfd1 or die "fileno: $!";
cmp_ok( $parentfd1, '<=', $^F, "parent open fd=$parentfd1 (\$^F=$^F)" );
test_inherited($parentfd1);
close FHPARENT1 or die "close '$tmpfile1': $!";

# ... and test that you cannot inherit fd = $^F+n.
open FHPARENT1, "<$tmpfile1" or die "open '$tmpfile1': $!";
open FHPARENT2, "<$tmpfile2" or die "open '$tmpfile2': $!";
$parentfd2 = fileno FHPARENT2;
defined $parentfd2 or die "fileno: $!";
cmp_ok( $parentfd2, '>', $^F, "parent open fd=$parentfd2 (\$^F=$^F)" );
test_not_inherited($parentfd2);
close FHPARENT2 or die "close '$tmpfile2': $!";
close FHPARENT1 or die "close '$tmpfile1': $!";

# ... and now you can inherit after incrementing.
$^F = $parentfd2;
open FHPARENT2, "<$tmpfile2" or die "open '$tmpfile2': $!";
open FHPARENT1, "<$tmpfile1" or die "open '$tmpfile1': $!";
$parentfd1 = fileno FHPARENT1;
defined $parentfd1 or die "fileno: $!";
cmp_ok( $parentfd1, '<=', $^F, "parent open fd=$parentfd1 (\$^F=$^F)" );
test_inherited($parentfd1);
close FHPARENT1 or die "close '$tmpfile1': $!";
close FHPARENT2 or die "close '$tmpfile2': $!";

__SCRIPT__

subtest 'tokenize' => sub {
    my $tokens = Compiler::Lexer->new('')->tokenize($script);
    is_deeply($tokens, [
          bless( {
                   'line' => 35,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_ModWord,
                   'type' => Compiler::Lexer::TokenType::T_ModWord,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'BEGIN',
                   'name' => 'ModWord'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 35,
                   'data' => '{',
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'chdir',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 36
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'data' => 't',
                   'line' => 36,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 36,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'if',
                   'name' => 'IfStmt'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-d',
                   'name' => 'Handle',
                   'line' => 36,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Handle
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'data' => 't',
                   'line' => 36,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 36
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LibraryDirectories,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 37,
                   'data' => '@INC',
                   'name' => 'LibraryDirectories'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'data' => '=',
                   'line' => 37,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '../lib',
                   'name' => 'RawString',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 37
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 37,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'require',
                   'name' => 'RequireDecl',
                   'line' => 38,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RequireDecl,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'data' => './test.pl',
                   'line' => 38,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 38
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'data' => 'skip_all_without_config',
                   'line' => 39,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 39,
                   'name' => 'LeftParenthesis',
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'd_fcntl',
                   'name' => 'RawString',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 39
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 39
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 39,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'line' => 40,
                   'data' => '}',
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'use',
                   'name' => 'UseDecl',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 42
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'strict',
                   'name' => 'UsedName',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 42
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'line' => 42,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SpecificValue',
                   'data' => '$|',
                   'line' => 44,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'name' => 'Assign',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 44
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'line' => 44,
                   'name' => 'Int',
                   'data' => '1'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 44,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 47,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'data' => 'skip_all'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 47
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SpecificValue',
                   'data' => '$^O',
                   'line' => 47,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 47
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'if',
                   'name' => 'IfStmt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'line' => 48
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SpecificValue',
                   'data' => '$^O',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 48
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'eq',
                   'name' => 'StringEqual',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 48
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 48,
                   'name' => 'RawString',
                   'data' => 'VMS'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 48,
                   'name' => 'AlphabetOr',
                   'data' => 'or'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SpecificValue',
                   'data' => '$^O',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 48
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'eq',
                   'name' => 'StringEqual',
                   'line' => 48,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 48,
                   'data' => 'MSWin32',
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'or',
                   'name' => 'AlphabetOr',
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 48
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$^O',
                   'name' => 'SpecificValue',
                   'line' => 48,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 48,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'data' => 'eq',
                   'name' => 'StringEqual'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'amigaos',
                   'name' => 'RawString',
                   'line' => 48,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 48,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'FunctionDecl',
                   'data' => 'sub',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 50,
                   'type' => Compiler::Lexer::TokenType::T_Function,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'make_tmp_file',
                   'name' => 'Function'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'line' => 50,
                   'name' => 'LeftBrace',
                   'data' => '{'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'my',
                   'name' => 'VarDecl',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 51
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'line' => 51,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'GlobalVar',
                   'data' => '$fname',
                   'line' => 51,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_GlobalVar,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'name' => 'Comma',
                   'line' => 51,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$fcontents',
                   'name' => 'GlobalVar',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_GlobalVar,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 51
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 51
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'line' => 51,
                   'name' => 'Assign',
                   'data' => '='
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 51,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ArgumentArray,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '@_',
                   'name' => 'ArgumentArray'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 51,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LocalDecl,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 52,
                   'name' => 'LocalDecl',
                   'data' => 'local'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Glob,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 52,
                   'name' => 'Glob',
                   'data' => '*FHTMP'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 52,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 53,
                   'name' => 'BuiltinFunc',
                   'data' => 'open'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 53,
                   'name' => 'Key',
                   'data' => 'FHTMP'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'name' => 'Comma',
                   'line' => 53,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'data' => '>$fname',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 53
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'or',
                   'name' => 'AlphabetOr',
                   'line' => 53,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'die',
                   'name' => 'BuiltinFunc',
                   'line' => 53,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'data' => 'open  \'$fname\': $!',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 53
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 53
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'print',
                   'name' => 'BuiltinFunc',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 54
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 54,
                   'data' => 'FHTMP',
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'data' => '$fcontents',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'line' => 54
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'or',
                   'name' => 'AlphabetOr',
                   'line' => 54,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 54,
                   'data' => 'die',
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'data' => 'print \'$fname\': $!',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 54
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 54,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'close',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 55
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 55,
                   'data' => 'FHTMP',
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'AlphabetOr',
                   'data' => 'or',
                   'line' => 55,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 55,
                   'name' => 'BuiltinFunc',
                   'data' => 'die'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 55,
                   'name' => 'String',
                   'data' => 'close \'$fname\': $!'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 55,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 56,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}',
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 58,
                   'name' => 'VarDecl',
                   'data' => 'my'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$Perl',
                   'name' => 'LocalVar',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 58
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 58,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=',
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 58,
                   'data' => 'which_perl',
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 58
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 58,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'line' => 58,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'my',
                   'name' => 'VarDecl',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 59
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 59,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar',
                   'data' => '$quote'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'name' => 'Assign',
                   'line' => 59,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'type' => Compiler::Lexer::TokenType::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 59,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'data' => '\''
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 59,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 61
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 61,
                   'data' => '$tmperr',
                   'name' => 'LocalVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 61,
                   'data' => '=',
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 61,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'data' => 'tempfile'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'line' => 61,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 61,
                   'name' => 'RightParenthesis',
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 61,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 62,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'VarDecl',
                   'data' => 'my'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$tmpfile1',
                   'name' => 'LocalVar',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 62
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'name' => 'Assign',
                   'line' => 62,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 62,
                   'data' => 'tempfile',
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'line' => 62
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'line' => 62,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 62
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 63,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl',
                   'data' => 'my'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 63,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'LocalVar',
                   'data' => '$tmpfile2'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'name' => 'Assign',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 63
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 63,
                   'name' => 'Key',
                   'data' => 'tempfile'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 63,
                   'data' => '(',
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'line' => 63
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 63
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 64,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'data' => 'my',
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 64,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$tmpfile1_contents',
                   'name' => 'LocalVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'data' => '=',
                   'line' => 64,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'data' => 'tmpfile1 line 1\\ntmpfile1 line 2\\n',
                   'line' => 64,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 64
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 65,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'VarDecl',
                   'data' => 'my'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LocalVar',
                   'data' => '$tmpfile2_contents',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 65,
                   'name' => 'Assign',
                   'data' => '='
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 65,
                   'data' => 'tmpfile2 line 1\\ntmpfile2 line 2\\n',
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 65,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Call',
                   'data' => 'make_tmp_file',
                   'line' => 66,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Call
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 66,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 66,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'data' => '$tmpfile1'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'name' => 'Comma',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 66
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$tmpfile1_contents',
                   'name' => 'Var',
                   'line' => 66,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 66,
                   'name' => 'RightParenthesis',
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 66
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'make_tmp_file',
                   'name' => 'Call',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_Call,
                   'line' => 67
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'line' => 67,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'data' => '$tmpfile2',
                   'line' => 67,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 67,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'data' => ',',
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 67,
                   'data' => '$tmpfile2_contents',
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 67,
                   'name' => 'RightParenthesis',
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 67
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'line' => 71,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$Child_prog',
                   'name' => 'LocalVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 71
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'data' => '=',
                   'line' => 71,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftShift,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 71,
                   'name' => 'LeftShift',
                   'data' => '<<'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'HereDocumentRawTag',
                   'data' => 'CHILD_PROG',
                   'line' => 71,
                   'type' => Compiler::Lexer::TokenType::T_HereDocumentRawTag,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'line' => 71,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_HereDocument,
                   'line' => 78,
                   'data' => 'my $fd = shift;
print qq{childfd=$fd\\n};
open INHERIT, qq{<&=$fd} or die qq{open $fd: $!};
my $line = <INHERIT>;
close INHERIT or die qq{close $fd: $!};
print $line
',
                   'name' => 'HereDocument'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_HereDocumentEnd,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 78,
                   'name' => 'HereDocumentEnd',
                   'data' => 'CHILD_PROG'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 79,
                   'data' => '$Child_prog',
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 79,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_RegOK,
                   'data' => '=~',
                   'name' => 'RegOK'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 79,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegAllReplace,
                   'kind' => Compiler::Lexer::Kind::T_RegReplacePrefix,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'tr',
                   'name' => 'RegAllReplace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '/',
                   'name' => 'RegDelim',
                   'line' => 79,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegReplaceFrom,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 79,
                   'name' => 'RegReplaceFrom',
                   'data' => '\\n'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegMiddleDelim,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 79,
                   'name' => 'RegMiddleDelim',
                   'data' => '/'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegReplaceTo,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 79,
                   'data' => '',
                   'name' => 'RegReplaceTo'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegDelim',
                   'data' => '/',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 79
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'd',
                   'name' => 'RegOpt',
                   'line' => 79,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_RegOpt,
                   'type' => Compiler::Lexer::TokenType::T_RegOpt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'line' => 79,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 81,
                   'data' => 'plan',
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'line' => 81,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'tests',
                   'name' => 'Key',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 81
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=>',
                   'name' => 'Arrow',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'line' => 81
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 81,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Int',
                   'data' => '22'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'line' => 81,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'line' => 81,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'FunctionDecl',
                   'data' => 'sub',
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 83
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Function',
                   'data' => 'test_not_inherited',
                   'line' => 83,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Function,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'name' => 'LeftBrace',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 83
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'my',
                   'name' => 'VarDecl',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 84
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$expected_fd',
                   'name' => 'LocalVar',
                   'line' => 84,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'name' => 'Assign',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 84
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'shift',
                   'name' => 'BuiltinFunc',
                   'line' => 84,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 84,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'data' => 'ok',
                   'line' => 85,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 85
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 85,
                   'data' => '-f',
                   'name' => 'Handle'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'data' => '$tmpfile2',
                   'line' => 85,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'name' => 'Comma',
                   'line' => 85,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'data' => 'tmpfile \'$tmpfile2\' exists',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 85
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'line' => 85,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 85,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 86,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LocalVar',
                   'data' => '$cmd',
                   'line' => 86,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'data' => '=',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 86
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 86,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDoubleQuote,
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'data' => 'qq',
                   'name' => 'RegDoubleQuote'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 86,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegDelim',
                   'data' => '{'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 86,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegExp',
                   'data' => '$Perl -e $quote$Child_prog$quote $expected_fd'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegDelim',
                   'data' => '}',
                   'line' => 86,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 86,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_LocalDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 88,
                   'name' => 'LocalDecl',
                   'data' => 'local'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Glob,
                   'line' => 88,
                   'name' => 'Glob',
                   'data' => '*SAVERR'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 88,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'open',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 88
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'SAVERR',
                   'name' => 'Key',
                   'line' => 88,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 88,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'data' => '>&STDERR',
                   'line' => 88,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 88,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'open',
                   'name' => 'BuiltinFunc',
                   'line' => 89,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 89,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_STDERR,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'data' => 'STDERR',
                   'name' => 'STDERR'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'data' => ',',
                   'line' => 89,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '>$tmperr',
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 89
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 89,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'data' => 'or',
                   'name' => 'AlphabetOr'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 89,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'data' => 'die'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'line' => 89,
                   'data' => 'open \'$tmperr\': $!',
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 89,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'my',
                   'name' => 'VarDecl',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 90
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 90,
                   'name' => 'LocalVar',
                   'data' => '$out'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 90,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'name' => 'Assign',
                   'data' => '='
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'ExecString',
                   'data' => '$cmd',
                   'line' => 90,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_ExecString,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'line' => 90,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'my',
                   'name' => 'VarDecl',
                   'line' => 91,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 91,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'LocalVar',
                   'data' => '$rc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 91,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=',
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$?',
                   'name' => 'SpecificValue',
                   'line' => 91,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '>>',
                   'name' => 'RightShift',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightShift,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 91
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '8',
                   'name' => 'Int',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'line' => 91
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 91
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'open',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 92
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_STDERR,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'line' => 92,
                   'data' => 'STDERR',
                   'name' => 'STDERR'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 92
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '>&SAVERR',
                   'name' => 'String',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 92
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'AlphabetOr',
                   'data' => 'or',
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 92
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 92,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'die',
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 92,
                   'name' => 'String',
                   'data' => 'error: restore STDERR: $!'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 92,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'line' => 93,
                   'data' => 'close',
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'data' => 'SAVERR',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 93
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 93,
                   'data' => 'or',
                   'name' => 'AlphabetOr'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'die',
                   'line' => 93,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 93,
                   'name' => 'String',
                   'data' => 'error: close SAVERR: $!'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'line' => 93,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'cmp_ok',
                   'name' => 'Key',
                   'line' => 98,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 98,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$out',
                   'name' => 'Var',
                   'line' => 98,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 98,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_RegOK,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=~',
                   'name' => 'RegOK'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'tr',
                   'name' => 'RegAllReplace',
                   'line' => 98,
                   'kind' => Compiler::Lexer::Kind::T_RegReplacePrefix,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegAllReplace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '/',
                   'name' => 'RegDelim',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 98
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegReplaceFrom',
                   'data' => '\\n',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegReplaceFrom,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 98
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegMiddleDelim',
                   'data' => '/',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegMiddleDelim,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 98
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 98,
                   'type' => Compiler::Lexer::TokenType::T_RegReplaceTo,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '',
                   'name' => 'RegReplaceTo'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 98,
                   'name' => 'RegDelim',
                   'data' => '/'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'name' => 'Comma',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 98
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 98,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'data' => '=='
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'data' => ',',
                   'line' => 98,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '1',
                   'name' => 'Int',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 98
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 98
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'data' => 'child stdout: has 1 newline (rc=$rc, should be non-zero)',
                   'line' => 99,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 99,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 99
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'data' => 'is',
                   'line' => 100,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'line' => 100,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 100,
                   'name' => 'Var',
                   'data' => '$out'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 100,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'line' => 100,
                   'name' => 'String',
                   'data' => 'childfd=$expected_fd\\n'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 100,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'child stdout: fd',
                   'name' => 'RawString',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 100
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 100
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 100,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 101,
                   'data' => '}',
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'FunctionDecl',
                   'data' => 'sub',
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 103
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Function,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 103,
                   'name' => 'Function',
                   'data' => 'test_inherited'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'name' => 'LeftBrace',
                   'line' => 103,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 104,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'data' => 'my',
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LocalVar',
                   'data' => '$expected_fd',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 104
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 104,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=',
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'shift',
                   'name' => 'BuiltinFunc',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 104
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 104,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 105,
                   'data' => 'ok',
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'line' => 105,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 105,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'data' => '-f',
                   'name' => 'Handle'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 105,
                   'name' => 'Var',
                   'data' => '$tmpfile1'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 105
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 105,
                   'name' => 'String',
                   'data' => 'tmpfile \'$tmpfile1\' exists'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 105,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 105,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 106,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'VarDecl',
                   'data' => 'my'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$cmd',
                   'name' => 'LocalVar',
                   'line' => 106,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'name' => 'Assign',
                   'line' => 106,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 106,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDoubleQuote,
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'qq',
                   'name' => 'RegDoubleQuote'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'name' => 'RegDelim',
                   'line' => 106,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegExp',
                   'data' => '$Perl -e $quote$Child_prog$quote $expected_fd',
                   'line' => 106,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegExp
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 106,
                   'name' => 'RegDelim',
                   'data' => '}'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 106,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 107
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$out',
                   'name' => 'LocalVar',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'line' => 107
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 107,
                   'name' => 'Assign',
                   'data' => '='
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ExecString,
                   'line' => 107,
                   'data' => '$cmd',
                   'name' => 'ExecString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 107,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'my',
                   'name' => 'VarDecl',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 108
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'line' => 108,
                   'data' => '$rc',
                   'name' => 'LocalVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 108
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$?',
                   'name' => 'SpecificValue',
                   'line' => 108,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 108,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightShift,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'RightShift',
                   'data' => '>>'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 108,
                   'name' => 'Int',
                   'data' => '8'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 108
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 109,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'cmp_ok',
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 109,
                   'data' => '(',
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 109,
                   'data' => '$rc',
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 109,
                   'data' => ',',
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 109,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '==',
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 109,
                   'data' => ',',
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 109,
                   'name' => 'Int',
                   'data' => '0'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'data' => ',',
                   'line' => 109,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'child return code=$rc (zero means inherited fd=$expected_fd ok)',
                   'name' => 'String',
                   'line' => 110,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'line' => 110
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 110,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'line' => 111,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LocalArrayVar',
                   'data' => '@lines',
                   'line' => 111,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalArrayVar,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 111,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=',
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 111,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'split',
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'line' => 111,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'line' => 111,
                   'name' => 'RegDelim',
                   'data' => '/'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 111,
                   'data' => '^',
                   'name' => 'RegExp'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegDelim',
                   'data' => '/',
                   'line' => 111,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 111
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 111,
                   'name' => 'Var',
                   'data' => '$out'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'line' => 111,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 111,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'data' => 'cmp_ok',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 112
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'line' => 112
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'line' => 112,
                   'name' => 'Var',
                   'data' => '$out'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_RegOK,
                   'line' => 112,
                   'data' => '=~',
                   'name' => 'RegOK'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'tr',
                   'name' => 'RegAllReplace',
                   'line' => 112,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_RegReplacePrefix,
                   'type' => Compiler::Lexer::TokenType::T_RegAllReplace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 112
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegReplaceFrom',
                   'data' => '\\n',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegReplaceFrom,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 112
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 112,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegMiddleDelim,
                   'data' => '/',
                   'name' => 'RegMiddleDelim'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '',
                   'name' => 'RegReplaceTo',
                   'line' => 112,
                   'type' => Compiler::Lexer::TokenType::T_RegReplaceTo,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 112,
                   'name' => 'RegDelim',
                   'data' => '/'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'name' => 'Comma',
                   'line' => 112,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 112,
                   'data' => '==',
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 112
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '2',
                   'name' => 'Int',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'line' => 112
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 112
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 112,
                   'data' => 'child stdout: has 2 newlines',
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 112,
                   'name' => 'RightParenthesis',
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 112,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 113,
                   'name' => 'Key',
                   'data' => 'cmp_ok'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 113
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'scalar',
                   'name' => 'BuiltinFunc',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 113
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 113
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '@lines',
                   'name' => 'ArrayVar',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 113
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 113
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'name' => 'Comma',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 113
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 113,
                   'data' => '==',
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 113
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'data' => '2',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 113
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 113,
                   'data' => ',',
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'data' => 'child stdout: split into 2 lines',
                   'line' => 113,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 113,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 113,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'is',
                   'name' => 'Key',
                   'line' => 114,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 114
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$lines',
                   'name' => 'GlobalVar',
                   'line' => 114,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_GlobalVar,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 114,
                   'data' => '[',
                   'name' => 'LeftBracket'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'data' => '0',
                   'line' => 114,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ']',
                   'name' => 'RightBracket',
                   'line' => 114,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 114,
                   'name' => 'Comma',
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'data' => 'childfd=$expected_fd\\n',
                   'line' => 114,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 114,
                   'name' => 'Comma',
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'child stdout: fd',
                   'name' => 'RawString',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 114
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'line' => 114,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 114,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'is',
                   'name' => 'Key',
                   'line' => 115,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 115,
                   'data' => '(',
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$lines',
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'line' => 115
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'line' => 115,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 115,
                   'name' => 'Int',
                   'data' => '1'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ']',
                   'name' => 'RightBracket',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 115
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 115,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'tmpfile1 line 1\\n',
                   'name' => 'String',
                   'line' => 115,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 115,
                   'name' => 'Comma',
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'data' => 'child stdout: line 1',
                   'line' => 115,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 115,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 115,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 116,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'data' => '}'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 118,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'name' => 'SpecificValue',
                   'data' => '$^F'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 118,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_EqualEqual,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'data' => '==',
                   'name' => 'EqualEqual'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 118,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'data' => '2'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 118,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'AlphabetOr',
                   'data' => 'or'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'print',
                   'line' => 118,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 118,
                   'type' => Compiler::Lexer::TokenType::T_STDERR,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'STDERR',
                   'name' => 'STDERR'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 118,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'data' => '# warning: \\$^F is $^F (not 2)\\n'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 118
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 121,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'open',
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 121,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'FHPARENT2'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 121,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '<$tmpfile2',
                   'name' => 'String',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'line' => 121
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 121,
                   'name' => 'AlphabetOr',
                   'data' => 'or'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 121,
                   'name' => 'BuiltinFunc',
                   'data' => 'die'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'line' => 121,
                   'data' => 'open \'$tmpfile2\': $!',
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 121,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 122,
                   'name' => 'VarDecl',
                   'data' => 'my'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 122,
                   'data' => '$parentfd2',
                   'name' => 'LocalVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 122,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'data' => '=',
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'fileno',
                   'line' => 122,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 122,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'FHPARENT2',
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 122,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'defined',
                   'name' => 'BuiltinFunc',
                   'line' => 123,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'data' => '$parentfd2',
                   'line' => 123,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'AlphabetOr',
                   'data' => 'or',
                   'line' => 123,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'die',
                   'line' => 123,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 123,
                   'name' => 'String',
                   'data' => 'fileno: $!'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 123
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 124,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'data' => 'cmp_ok'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 124,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '(',
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$parentfd2',
                   'name' => 'Var',
                   'line' => 124,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 124
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '>',
                   'name' => 'RawString',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 124
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 124
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 124,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SpecificValue',
                   'data' => '$^F'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'name' => 'Comma',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 124
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'data' => 'parent open fd=$parentfd2 (\\$^F=$^F)',
                   'line' => 124,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'line' => 124
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 124,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'test_not_inherited',
                   'name' => 'Call',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Call,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 125
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'line' => 125,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 125,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$parentfd2',
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 125,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 125
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 126,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'data' => 'close',
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'data' => 'FHPARENT2',
                   'line' => 126,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'AlphabetOr',
                   'data' => 'or',
                   'line' => 126,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 126,
                   'name' => 'BuiltinFunc',
                   'data' => 'die'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'close \'$tmpfile2\': $!',
                   'name' => 'String',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 126
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 126
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$^F',
                   'name' => 'SpecificValue',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 130
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 130,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'data' => '=',
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$parentfd2',
                   'name' => 'Var',
                   'line' => 130,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 130
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'open',
                   'line' => 131,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 131,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'data' => 'FHPARENT1'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 131,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'data' => ',',
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 131,
                   'name' => 'String',
                   'data' => '<$tmpfile1'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'or',
                   'name' => 'AlphabetOr',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 131
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'die',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 131
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'data' => 'open \'$tmpfile1\': $!',
                   'line' => 131,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 131,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 132,
                   'data' => 'my',
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'line' => 132,
                   'name' => 'LocalVar',
                   'data' => '$parentfd1'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 132,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Assign',
                   'data' => '='
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'fileno',
                   'name' => 'BuiltinFunc',
                   'line' => 132,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'data' => 'FHPARENT1',
                   'line' => 132,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 132,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'defined',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 133
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 133,
                   'data' => '$parentfd1',
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 133,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'AlphabetOr',
                   'data' => 'or'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'die',
                   'line' => 133,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'line' => 133,
                   'data' => 'fileno: $!',
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 133,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'cmp_ok',
                   'name' => 'Key',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 134
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'line' => 134
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 134,
                   'name' => 'Var',
                   'data' => '$parentfd1'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 134,
                   'name' => 'Comma',
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'line' => 134,
                   'data' => '<=',
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'name' => 'Comma',
                   'line' => 134,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SpecificValue',
                   'data' => '$^F',
                   'line' => 134,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 134
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 134,
                   'data' => 'parent open fd=$parentfd1 (\\$^F=$^F)',
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'line' => 134,
                   'name' => 'RightParenthesis',
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 134,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 135,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Call,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Call',
                   'data' => 'test_inherited'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 135
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 135,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'data' => '$parentfd1'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 135
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 135,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'close',
                   'line' => 136,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 136,
                   'data' => 'FHPARENT1',
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 136,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'AlphabetOr',
                   'data' => 'or'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 136,
                   'data' => 'die',
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'line' => 136,
                   'data' => 'close \'$tmpfile1\': $!',
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 136,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'open',
                   'name' => 'BuiltinFunc',
                   'line' => 139,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 139,
                   'name' => 'Key',
                   'data' => 'FHPARENT1'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'data' => ',',
                   'line' => 139,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '<$tmpfile1',
                   'name' => 'String',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 139
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 139,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'name' => 'AlphabetOr',
                   'data' => 'or'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'die',
                   'name' => 'BuiltinFunc',
                   'line' => 139,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 139,
                   'name' => 'String',
                   'data' => 'open \'$tmpfile1\': $!'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 139,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'open',
                   'line' => 140,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'FHPARENT2',
                   'name' => 'Key',
                   'line' => 140,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'name' => 'Comma',
                   'line' => 140,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'data' => '<$tmpfile2',
                   'line' => 140,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'line' => 140,
                   'data' => 'or',
                   'name' => 'AlphabetOr'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'die',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 140
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 140,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'data' => 'open \'$tmpfile2\': $!'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 140,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$parentfd2',
                   'name' => 'Var',
                   'line' => 141,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'line' => 141,
                   'data' => '=',
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'fileno',
                   'name' => 'BuiltinFunc',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 141
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'FHPARENT2',
                   'name' => 'Key',
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 141
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 141
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'defined',
                   'name' => 'BuiltinFunc',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 142
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'data' => '$parentfd2',
                   'line' => 142,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 142,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'AlphabetOr',
                   'data' => 'or'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 142,
                   'data' => 'die',
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 142,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'data' => 'fileno: $!'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 142
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 143,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'cmp_ok'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 143,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$parentfd2',
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 143
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'name' => 'Comma',
                   'line' => 143,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 143,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'data' => '>'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 143,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 143,
                   'data' => '$^F',
                   'name' => 'SpecificValue'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 143,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 143,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'data' => 'parent open fd=$parentfd2 (\\$^F=$^F)'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 143
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 143,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 144,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_Call,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Call',
                   'data' => 'test_not_inherited'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 144,
                   'name' => 'LeftParenthesis',
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$parentfd2',
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'line' => 144
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 144
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 144,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 145,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'data' => 'close',
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'data' => 'FHPARENT2',
                   'line' => 145,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 145,
                   'name' => 'AlphabetOr',
                   'data' => 'or'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'die',
                   'name' => 'BuiltinFunc',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 145
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 145,
                   'data' => 'close \'$tmpfile2\': $!',
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 145,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'close',
                   'name' => 'BuiltinFunc',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 146
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'FHPARENT1',
                   'name' => 'Key',
                   'line' => 146,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'AlphabetOr',
                   'data' => 'or',
                   'line' => 146,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 146,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'die',
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'data' => 'close \'$tmpfile1\': $!',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 146
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 146
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SpecificValue',
                   'data' => '$^F',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 149
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'data' => '=',
                   'line' => 149,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'data' => '$parentfd2',
                   'line' => 149,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 149,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 150,
                   'data' => 'open',
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 150,
                   'name' => 'Key',
                   'data' => 'FHPARENT2'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 150,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'data' => ',',
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '<$tmpfile2',
                   'name' => 'String',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 150
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 150,
                   'data' => 'or',
                   'name' => 'AlphabetOr'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'die',
                   'name' => 'BuiltinFunc',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 150
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 150,
                   'name' => 'String',
                   'data' => 'open \'$tmpfile2\': $!'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'line' => 150,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'open',
                   'name' => 'BuiltinFunc',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 151
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 151,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'data' => 'FHPARENT1'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 151,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 151,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'data' => '<$tmpfile1'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 151,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'or',
                   'name' => 'AlphabetOr'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'die',
                   'line' => 151,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'open \'$tmpfile1\': $!',
                   'name' => 'String',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 151
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 151,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'data' => '$parentfd1',
                   'line' => 152,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'name' => 'Assign',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'line' => 152
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 152,
                   'name' => 'BuiltinFunc',
                   'data' => 'fileno'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'data' => 'FHPARENT1',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 152
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 152
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 153,
                   'data' => 'defined',
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$parentfd1',
                   'name' => 'Var',
                   'line' => 153,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 153,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'data' => 'or',
                   'name' => 'AlphabetOr'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'die',
                   'name' => 'BuiltinFunc',
                   'line' => 153,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'fileno: $!',
                   'name' => 'String',
                   'line' => 153,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 153,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'data' => 'cmp_ok',
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 154
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 154
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$parentfd1',
                   'name' => 'Var',
                   'line' => 154,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'data' => ',',
                   'line' => 154,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '<=',
                   'name' => 'RawString',
                   'line' => 154,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 154
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SpecificValue',
                   'data' => '$^F',
                   'line' => 154,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'line' => 154
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'parent open fd=$parentfd1 (\\$^F=$^F)',
                   'name' => 'String',
                   'line' => 154,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 154,
                   'name' => 'RightParenthesis',
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'line' => 154,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'test_inherited',
                   'name' => 'Call',
                   'line' => 155,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Call,
                   'kind' => Compiler::Lexer::Kind::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'line' => 155
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'data' => '$parentfd1',
                   'line' => 155,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 155
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 155
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 156,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'data' => 'close'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 156,
                   'name' => 'Key',
                   'data' => 'FHPARENT1'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'or',
                   'name' => 'AlphabetOr',
                   'line' => 156,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'die',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 156
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'close \'$tmpfile1\': $!',
                   'name' => 'String',
                   'line' => 156,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 156,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'close',
                   'line' => 157,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 157,
                   'name' => 'Key',
                   'data' => 'FHPARENT2'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 157,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'or',
                   'name' => 'AlphabetOr'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 157,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'die',
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'data' => 'close \'$tmpfile2\': $!',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'line' => 157
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 157,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
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
            'end_line' => 36,
            'block_id' => 1,
            'token_num' => 6,
            'start_line' => 36,
            'src' => ' chdir \'t\' if -d \'t\' ;',
            'indent' => 1
          },
          {
            'end_line' => 37,
            'has_warnings' => 0,
            'token_num' => 4,
            'block_id' => 1,
            'start_line' => 37,
            'indent' => 1,
            'src' => ' @INC = \'../lib\' ;'
          },
          {
            'has_warnings' => 0,
            'end_line' => 38,
            'block_id' => 1,
            'token_num' => 3,
            'start_line' => 38,
            'indent' => 1,
            'src' => ' require \'./test.pl\' ;'
          },
          {
            'end_line' => 39,
            'has_warnings' => 1,
            'block_id' => 1,
            'token_num' => 5,
            'start_line' => 39,
            'src' => ' skip_all_without_config ( \'d_fcntl\' ) ;',
            'indent' => 1
          },
          {
            'src' => ' use strict ;',
            'indent' => 0,
            'start_line' => 42,
            'has_warnings' => 0,
            'end_line' => 42,
            'token_num' => 3,
            'block_id' => 0
          },
          {
            'start_line' => 44,
            'indent' => 0,
            'src' => ' $| = 1 ;',
            'end_line' => 44,
            'has_warnings' => 0,
            'block_id' => 0,
            'token_num' => 4
          },
          {
            'end_line' => 48,
            'has_warnings' => 1,
            'token_num' => 17,
            'block_id' => 0,
            'start_line' => 47,
            'src' => ' skip_all ( $^O ) if $^O eq \'VMS\' or $^O eq \'MSWin32\' or $^O eq \'amigaos\' ;',
            'indent' => 0
          },
          {
            'end_line' => 56,
            'has_warnings' => 1,
            'token_num' => 37,
            'block_id' => 0,
            'start_line' => 50,
            'src' => ' sub make_tmp_file { my ( $fname , $fcontents ) = @_ ; local *FHTMP ; open FHTMP , ">$fname" or die "open  \'$fname\': $!" ; print FHTMP $fcontents or die "print \'$fname\': $!" ; close FHTMP or die "close \'$fname\': $!" ; }',
            'indent' => 0
          },
          {
            'end_line' => 51,
            'has_warnings' => 1,
            'token_num' => 9,
            'block_id' => 2,
            'start_line' => 51,
            'src' => ' my ( $fname , $fcontents ) = @_ ;',
            'indent' => 1
          },
          {
            'has_warnings' => 0,
            'end_line' => 52,
            'block_id' => 2,
            'token_num' => 3,
            'indent' => 1,
            'src' => ' local *FHTMP ;',
            'start_line' => 52
          },
          {
            'src' => ' open FHTMP , ">$fname" or die "open  \'$fname\': $!" ;',
            'indent' => 1,
            'start_line' => 53,
            'end_line' => 53,
            'has_warnings' => 1,
            'block_id' => 2,
            'token_num' => 8
          },
          {
            'start_line' => 54,
            'src' => ' print FHTMP $fcontents or die "print \'$fname\': $!" ;',
            'indent' => 1,
            'has_warnings' => 1,
            'end_line' => 54,
            'block_id' => 2,
            'token_num' => 7
          },
          {
            'indent' => 1,
            'src' => ' close FHTMP or die "close \'$fname\': $!" ;',
            'start_line' => 55,
            'block_id' => 2,
            'token_num' => 6,
            'has_warnings' => 1,
            'end_line' => 55
          },
          {
            'start_line' => 58,
            'src' => ' my $Perl = which_perl ( ) ;',
            'indent' => 0,
            'has_warnings' => 1,
            'end_line' => 58,
            'block_id' => 0,
            'token_num' => 7
          },
          {
            'indent' => 0,
            'src' => ' my $quote = "\'" ;',
            'start_line' => 59,
            'block_id' => 0,
            'token_num' => 5,
            'has_warnings' => 0,
            'end_line' => 59
          },
          {
            'end_line' => 61,
            'has_warnings' => 1,
            'token_num' => 7,
            'block_id' => 0,
            'start_line' => 61,
            'indent' => 0,
            'src' => ' my $tmperr = tempfile ( ) ;'
          },
          {
            'start_line' => 62,
            'src' => ' my $tmpfile1 = tempfile ( ) ;',
            'indent' => 0,
            'end_line' => 62,
            'has_warnings' => 1,
            'token_num' => 7,
            'block_id' => 0
          },
          {
            'src' => ' my $tmpfile2 = tempfile ( ) ;',
            'indent' => 0,
            'start_line' => 63,
            'has_warnings' => 1,
            'end_line' => 63,
            'block_id' => 0,
            'token_num' => 7
          },
          {
            'indent' => 0,
            'src' => ' my $tmpfile1_contents = "tmpfile1 line 1\\ntmpfile1 line 2\\n" ;',
            'start_line' => 64,
            'end_line' => 64,
            'has_warnings' => 0,
            'token_num' => 5,
            'block_id' => 0
          },
          {
            'block_id' => 0,
            'token_num' => 5,
            'has_warnings' => 0,
            'end_line' => 65,
            'start_line' => 65,
            'indent' => 0,
            'src' => ' my $tmpfile2_contents = "tmpfile2 line 1\\ntmpfile2 line 2\\n" ;'
          },
          {
            'token_num' => 7,
            'block_id' => 0,
            'end_line' => 66,
            'has_warnings' => 1,
            'start_line' => 66,
            'src' => ' make_tmp_file ( $tmpfile1 , $tmpfile1_contents ) ;',
            'indent' => 0
          },
          {
            'indent' => 0,
            'src' => ' make_tmp_file ( $tmpfile2 , $tmpfile2_contents ) ;',
            'start_line' => 67,
            'has_warnings' => 1,
            'end_line' => 67,
            'token_num' => 7,
            'block_id' => 0
          },
          {
            'indent' => 0,
            'src' => ' my $Child_prog = q{my $fd = shift;
print qq{childfd=$fd\\n};
open INHERIT, qq{<&=$fd} or die qq{open $fd: $!};
my $line = <INHERIT>;
close INHERIT or die qq{close $fd: $!};
print $line
} ;',
            'start_line' => 71,
            'end_line' => 71,
            'has_warnings' => 0,
            'block_id' => 0,
            'token_num' => 5
          },
          {
            'block_id' => 0,
            'token_num' => 10,
            'has_warnings' => 1,
            'end_line' => 79,
            'src' => ' $Child_prog =~ tr/\\n//d ;',
            'indent' => 0,
            'start_line' => 79
          },
          {
            'start_line' => 81,
            'indent' => 0,
            'src' => ' plan ( tests => 22 ) ;',
            'token_num' => 7,
            'block_id' => 0,
            'has_warnings' => 1,
            'end_line' => 81
          },
          {
            'start_line' => 83,
            'src' => ' sub test_not_inherited { my $expected_fd = shift ; ok ( -f $tmpfile2 , "tmpfile \'$tmpfile2\' exists" ) ; my $cmd = qq{$Perl -e $quote$Child_prog$quote $expected_fd} ; local *SAVERR ; open SAVERR , ">&STDERR" ; open STDERR , ">$tmperr" or die "open \'$tmperr\': $!" ; my $out = `$cmd` ; my $rc = $? >> 8 ; open STDERR , ">&SAVERR" or die "error: restore STDERR: $!" ; close SAVERR or die "error: close SAVERR: $!" ; cmp_ok ( $out =~ tr/\\n// , \'==\' , 1 , "child stdout: has 1 newline (rc=$rc, should be non-zero)" ) ; is ( $out , "childfd=$expected_fd\\n" , \'child stdout: fd\' ) ; }',
            'indent' => 0,
            'token_num' => 94,
            'block_id' => 0,
            'end_line' => 101,
            'has_warnings' => 1
          },
          {
            'has_warnings' => 0,
            'end_line' => 84,
            'block_id' => 3,
            'token_num' => 5,
            'indent' => 1,
            'src' => ' my $expected_fd = shift ;',
            'start_line' => 84
          },
          {
            'end_line' => 85,
            'has_warnings' => 1,
            'token_num' => 8,
            'block_id' => 3,
            'src' => ' ok ( -f $tmpfile2 , "tmpfile \'$tmpfile2\' exists" ) ;',
            'indent' => 1,
            'start_line' => 85
          },
          {
            'src' => ' my $cmd = qq{$Perl -e $quote$Child_prog$quote $expected_fd} ;',
            'indent' => 1,
            'start_line' => 86,
            'end_line' => 86,
            'has_warnings' => 0,
            'token_num' => 8,
            'block_id' => 3
          },
          {
            'token_num' => 3,
            'block_id' => 3,
            'end_line' => 88,
            'has_warnings' => 0,
            'start_line' => 88,
            'src' => ' local *SAVERR ;',
            'indent' => 1
          },
          {
            'src' => ' open SAVERR , ">&STDERR" ;',
            'indent' => 1,
            'start_line' => 88,
            'has_warnings' => 1,
            'end_line' => 88,
            'block_id' => 3,
            'token_num' => 5
          },
          {
            'indent' => 1,
            'src' => ' open STDERR , ">$tmperr" or die "open \'$tmperr\': $!" ;',
            'start_line' => 89,
            'has_warnings' => 0,
            'end_line' => 89,
            'token_num' => 8,
            'block_id' => 3
          },
          {
            'src' => ' my $out = `$cmd` ;',
            'indent' => 1,
            'start_line' => 90,
            'has_warnings' => 0,
            'end_line' => 90,
            'token_num' => 5,
            'block_id' => 3
          },
          {
            'start_line' => 91,
            'indent' => 1,
            'src' => ' my $rc = $? >> 8 ;',
            'has_warnings' => 0,
            'end_line' => 91,
            'block_id' => 3,
            'token_num' => 7
          },
          {
            'token_num' => 8,
            'block_id' => 3,
            'has_warnings' => 0,
            'end_line' => 92,
            'indent' => 1,
            'src' => ' open STDERR , ">&SAVERR" or die "error: restore STDERR: $!" ;',
            'start_line' => 92
          },
          {
            'start_line' => 93,
            'indent' => 1,
            'src' => ' close SAVERR or die "error: close SAVERR: $!" ;',
            'has_warnings' => 1,
            'end_line' => 93,
            'block_id' => 3,
            'token_num' => 6
          },
          {
            'start_line' => 98,
            'indent' => 1,
            'src' => ' cmp_ok ( $out =~ tr/\\n// , \'==\' , 1 , "child stdout: has 1 newline (rc=$rc, should be non-zero)" ) ;',
            'block_id' => 3,
            'token_num' => 18,
            'end_line' => 99,
            'has_warnings' => 1
          },
          {
            'src' => ' is ( $out , "childfd=$expected_fd\\n" , \'child stdout: fd\' ) ;',
            'indent' => 1,
            'start_line' => 100,
            'end_line' => 100,
            'has_warnings' => 1,
            'token_num' => 9,
            'block_id' => 3
          },
          {
            'src' => ' sub test_inherited { my $expected_fd = shift ; ok ( -f $tmpfile1 , "tmpfile \'$tmpfile1\' exists" ) ; my $cmd = qq{$Perl -e $quote$Child_prog$quote $expected_fd} ; my $out = `$cmd` ; my $rc = $? >> 8 ; cmp_ok ( $rc , \'==\' , 0 , "child return code=$rc (zero means inherited fd=$expected_fd ok)" ) ; my @lines = split (/^/ , $out ) ; cmp_ok ( $out =~ tr/\\n// , \'==\' , 2 , \'child stdout: has 2 newlines\' ) ; cmp_ok ( scalar ( @lines ) , \'==\' , 2 , \'child stdout: split into 2 lines\' ) ; is ( $lines [ 0 ] , "childfd=$expected_fd\\n" , \'child stdout: fd\' ) ; is ( $lines [ 1 ] , "tmpfile1 line 1\\n" , \'child stdout: line 1\' ) ; }',
            'indent' => 0,
            'start_line' => 103,
            'token_num' => 116,
            'block_id' => 0,
            'has_warnings' => 1,
            'end_line' => 116
          },
          {
            'block_id' => 4,
            'token_num' => 5,
            'end_line' => 104,
            'has_warnings' => 0,
            'start_line' => 104,
            'indent' => 1,
            'src' => ' my $expected_fd = shift ;'
          },
          {
            'start_line' => 105,
            'src' => ' ok ( -f $tmpfile1 , "tmpfile \'$tmpfile1\' exists" ) ;',
            'indent' => 1,
            'has_warnings' => 1,
            'end_line' => 105,
            'block_id' => 4,
            'token_num' => 8
          },
          {
            'indent' => 1,
            'src' => ' my $cmd = qq{$Perl -e $quote$Child_prog$quote $expected_fd} ;',
            'start_line' => 106,
            'token_num' => 8,
            'block_id' => 4,
            'end_line' => 106,
            'has_warnings' => 0
          },
          {
            'src' => ' my $out = `$cmd` ;',
            'indent' => 1,
            'start_line' => 107,
            'end_line' => 107,
            'has_warnings' => 0,
            'block_id' => 4,
            'token_num' => 5
          },
          {
            'start_line' => 108,
            'indent' => 1,
            'src' => ' my $rc = $? >> 8 ;',
            'block_id' => 4,
            'token_num' => 7,
            'has_warnings' => 0,
            'end_line' => 108
          },
          {
            'token_num' => 11,
            'block_id' => 4,
            'has_warnings' => 1,
            'end_line' => 110,
            'src' => ' cmp_ok ( $rc , \'==\' , 0 , "child return code=$rc (zero means inherited fd=$expected_fd ok)" ) ;',
            'indent' => 1,
            'start_line' => 109
          },
          {
            'start_line' => 111,
            'indent' => 1,
            'src' => ' my @lines = split (/^/ , $out ) ;',
            'end_line' => 111,
            'has_warnings' => 1,
            'block_id' => 4,
            'token_num' => 12
          },
          {
            'end_line' => 112,
            'has_warnings' => 1,
            'token_num' => 18,
            'block_id' => 4,
            'start_line' => 112,
            'indent' => 1,
            'src' => ' cmp_ok ( $out =~ tr/\\n// , \'==\' , 2 , \'child stdout: has 2 newlines\' ) ;'
          },
          {
            'has_warnings' => 1,
            'end_line' => 113,
            'block_id' => 4,
            'token_num' => 14,
            'start_line' => 113,
            'src' => ' cmp_ok ( scalar ( @lines ) , \'==\' , 2 , \'child stdout: split into 2 lines\' ) ;',
            'indent' => 1
          },
          {
            'end_line' => 114,
            'has_warnings' => 1,
            'token_num' => 12,
            'block_id' => 4,
            'indent' => 1,
            'src' => ' is ( $lines [ 0 ] , "childfd=$expected_fd\\n" , \'child stdout: fd\' ) ;',
            'start_line' => 114
          },
          {
            'end_line' => 115,
            'has_warnings' => 1,
            'token_num' => 12,
            'block_id' => 4,
            'start_line' => 115,
            'src' => ' is ( $lines [ 1 ] , "tmpfile1 line 1\\n" , \'child stdout: line 1\' ) ;',
            'indent' => 1
          },
          {
            'src' => ' $^F == 2 or print STDERR "# warning: \\$^F is $^F (not 2)\\n" ;',
            'indent' => 0,
            'start_line' => 118,
            'end_line' => 118,
            'has_warnings' => 0,
            'token_num' => 8,
            'block_id' => 0
          },
          {
            'token_num' => 8,
            'block_id' => 0,
            'has_warnings' => 1,
            'end_line' => 121,
            'src' => ' open FHPARENT2 , "<$tmpfile2" or die "open \'$tmpfile2\': $!" ;',
            'indent' => 0,
            'start_line' => 121
          },
          {
            'indent' => 0,
            'src' => ' my $parentfd2 = fileno FHPARENT2 ;',
            'start_line' => 122,
            'end_line' => 122,
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 6
          },
          {
            'indent' => 0,
            'src' => ' defined $parentfd2 or die "fileno: $!" ;',
            'start_line' => 123,
            'end_line' => 123,
            'has_warnings' => 1,
            'token_num' => 6,
            'block_id' => 0
          },
          {
            'start_line' => 124,
            'indent' => 0,
            'src' => ' cmp_ok ( $parentfd2 , \'>\' , $^F , "parent open fd=$parentfd2 (\\$^F=$^F)" ) ;',
            'has_warnings' => 1,
            'end_line' => 124,
            'block_id' => 0,
            'token_num' => 11
          },
          {
            'indent' => 0,
            'src' => ' test_not_inherited ( $parentfd2 ) ;',
            'start_line' => 125,
            'block_id' => 0,
            'token_num' => 5,
            'end_line' => 125,
            'has_warnings' => 1
          },
          {
            'block_id' => 0,
            'token_num' => 6,
            'has_warnings' => 1,
            'end_line' => 126,
            'start_line' => 126,
            'indent' => 0,
            'src' => ' close FHPARENT2 or die "close \'$tmpfile2\': $!" ;'
          },
          {
            'has_warnings' => 1,
            'end_line' => 130,
            'block_id' => 0,
            'token_num' => 4,
            'start_line' => 130,
            'indent' => 0,
            'src' => ' $^F = $parentfd2 ;'
          },
          {
            'end_line' => 131,
            'has_warnings' => 1,
            'token_num' => 8,
            'block_id' => 0,
            'start_line' => 131,
            'src' => ' open FHPARENT1 , "<$tmpfile1" or die "open \'$tmpfile1\': $!" ;',
            'indent' => 0
          },
          {
            'token_num' => 6,
            'block_id' => 0,
            'end_line' => 132,
            'has_warnings' => 1,
            'src' => ' my $parentfd1 = fileno FHPARENT1 ;',
            'indent' => 0,
            'start_line' => 132
          },
          {
            'indent' => 0,
            'src' => ' defined $parentfd1 or die "fileno: $!" ;',
            'start_line' => 133,
            'has_warnings' => 1,
            'end_line' => 133,
            'block_id' => 0,
            'token_num' => 6
          },
          {
            'token_num' => 11,
            'block_id' => 0,
            'has_warnings' => 1,
            'end_line' => 134,
            'src' => ' cmp_ok ( $parentfd1 , \'<=\' , $^F , "parent open fd=$parentfd1 (\\$^F=$^F)" ) ;',
            'indent' => 0,
            'start_line' => 134
          },
          {
            'block_id' => 0,
            'token_num' => 5,
            'end_line' => 135,
            'has_warnings' => 1,
            'indent' => 0,
            'src' => ' test_inherited ( $parentfd1 ) ;',
            'start_line' => 135
          },
          {
            'start_line' => 136,
            'src' => ' close FHPARENT1 or die "close \'$tmpfile1\': $!" ;',
            'indent' => 0,
            'token_num' => 6,
            'block_id' => 0,
            'has_warnings' => 1,
            'end_line' => 136
          },
          {
            'block_id' => 0,
            'token_num' => 8,
            'has_warnings' => 1,
            'end_line' => 139,
            'src' => ' open FHPARENT1 , "<$tmpfile1" or die "open \'$tmpfile1\': $!" ;',
            'indent' => 0,
            'start_line' => 139
          },
          {
            'end_line' => 140,
            'has_warnings' => 1,
            'token_num' => 8,
            'block_id' => 0,
            'start_line' => 140,
            'indent' => 0,
            'src' => ' open FHPARENT2 , "<$tmpfile2" or die "open \'$tmpfile2\': $!" ;'
          },
          {
            'indent' => 0,
            'src' => ' $parentfd2 = fileno FHPARENT2 ;',
            'start_line' => 141,
            'block_id' => 0,
            'token_num' => 5,
            'has_warnings' => 1,
            'end_line' => 141
          },
          {
            'end_line' => 142,
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 6,
            'src' => ' defined $parentfd2 or die "fileno: $!" ;',
            'indent' => 0,
            'start_line' => 142
          },
          {
            'start_line' => 143,
            'src' => ' cmp_ok ( $parentfd2 , \'>\' , $^F , "parent open fd=$parentfd2 (\\$^F=$^F)" ) ;',
            'indent' => 0,
            'has_warnings' => 1,
            'end_line' => 143,
            'token_num' => 11,
            'block_id' => 0
          },
          {
            'block_id' => 0,
            'token_num' => 5,
            'end_line' => 144,
            'has_warnings' => 1,
            'indent' => 0,
            'src' => ' test_not_inherited ( $parentfd2 ) ;',
            'start_line' => 144
          },
          {
            'src' => ' close FHPARENT2 or die "close \'$tmpfile2\': $!" ;',
            'indent' => 0,
            'start_line' => 145,
            'token_num' => 6,
            'block_id' => 0,
            'end_line' => 145,
            'has_warnings' => 1
          },
          {
            'end_line' => 146,
            'has_warnings' => 1,
            'token_num' => 6,
            'block_id' => 0,
            'start_line' => 146,
            'src' => ' close FHPARENT1 or die "close \'$tmpfile1\': $!" ;',
            'indent' => 0
          },
          {
            'src' => ' $^F = $parentfd2 ;',
            'indent' => 0,
            'start_line' => 149,
            'end_line' => 149,
            'has_warnings' => 1,
            'token_num' => 4,
            'block_id' => 0
          },
          {
            'indent' => 0,
            'src' => ' open FHPARENT2 , "<$tmpfile2" or die "open \'$tmpfile2\': $!" ;',
            'start_line' => 150,
            'block_id' => 0,
            'token_num' => 8,
            'has_warnings' => 1,
            'end_line' => 150
          },
          {
            'start_line' => 151,
            'src' => ' open FHPARENT1 , "<$tmpfile1" or die "open \'$tmpfile1\': $!" ;',
            'indent' => 0,
            'end_line' => 151,
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 8
          },
          {
            'has_warnings' => 1,
            'end_line' => 152,
            'block_id' => 0,
            'token_num' => 5,
            'start_line' => 152,
            'src' => ' $parentfd1 = fileno FHPARENT1 ;',
            'indent' => 0
          },
          {
            'start_line' => 153,
            'indent' => 0,
            'src' => ' defined $parentfd1 or die "fileno: $!" ;',
            'block_id' => 0,
            'token_num' => 6,
            'has_warnings' => 1,
            'end_line' => 153
          },
          {
            'block_id' => 0,
            'token_num' => 11,
            'has_warnings' => 1,
            'end_line' => 154,
            'src' => ' cmp_ok ( $parentfd1 , \'<=\' , $^F , "parent open fd=$parentfd1 (\\$^F=$^F)" ) ;',
            'indent' => 0,
            'start_line' => 154
          },
          {
            'has_warnings' => 1,
            'end_line' => 155,
            'block_id' => 0,
            'token_num' => 5,
            'start_line' => 155,
            'indent' => 0,
            'src' => ' test_inherited ( $parentfd1 ) ;'
          },
          {
            'start_line' => 156,
            'indent' => 0,
            'src' => ' close FHPARENT1 or die "close \'$tmpfile1\': $!" ;',
            'token_num' => 6,
            'block_id' => 0,
            'end_line' => 156,
            'has_warnings' => 1
          },
          {
            'end_line' => 157,
            'has_warnings' => 1,
            'token_num' => 6,
            'block_id' => 0,
            'src' => ' close FHPARENT2 or die "close \'$tmpfile2\': $!" ;',
            'indent' => 0,
            'start_line' => 157
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
          }
        ]
, 'Compiler::Lexer::get_used_modules');
};

done_testing;
