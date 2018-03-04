use strict;
use warnings;
use Test::More;
BEGIN {
    use_ok('Compiler::Lexer');
}
my $script =<<'__SCRIPT__';
#!./perl

BEGIN {
    chdir 't' if -d 't';
    @INC = '../lib';
    require './test.pl';
}

use strict;
use warnings;

plan 10;

# Need to run this in a quiet private directory as it assumes that it can read
# the contents twice and get the same result.
my $tempdir = tempfile;

mkdir $tempdir, 0700 or die "Can't mkdir '$tempdir': $!";
chdir $tempdir or die die "Can't chdir '$tempdir': $!";

my $cleanup = 1;
my %tempfiles;

END {
    if ($cleanup) {
	foreach my $file (keys %tempfiles) {
	    # We only wrote each of these once so 1 delete should work:
	    if (unlink $file) {
		warn "unlink tempfile '$file' passed but it's still there"
		    if -e $file;
	    } else {
		warn "Couldn't unlink tempfile '$file': $!";
	    }
	}
	chdir '..' or die "Couldn't chdir .. for cleanup: $!";
	rmdir $tempdir or die "Couldn't unlink tempdir '$tempdir': $!";
    }
}

# This is intentionally not random (per run), but intentionally will try to
# give different file names for different people running this test.
srand $< * $];

my @chars = ('A' .. 'Z', 'a' .. 'z', 0 .. 9);

sub make_file {
    my $name = shift;

    return if $tempfiles{$name}++;

    print "# Writing to $name in $tempdir\n";

    open my $fh, '>', $name or die "Can't open '$name' for writing: $!\n";
    print $fh <<'FILE0';
This file is here for testing

while(readdir $dir){...}
... while readdir $dir

etc
FILE0
    close $fh or die "Can't close '$name': $!";
}

sub make_some_files {
    for (1..int rand 10) {
	my $name;
	$name .= $chars[rand $#chars] for 1..int(10 + rand 5);
	make_file($name);
    }
}

make_some_files();
make_file('0');
make_some_files();

ok(-f '0', "'0' file is here");

opendir my $dirhandle, '.'
    or die "Failed test: unable to open directory: $!\n";

my @dir = readdir $dirhandle;
rewinddir $dirhandle;

{
    my @list;
    while(readdir $dirhandle){
	push @list, $_;
    }
    ok( eq_array( \@dir, \@list ), 'while(readdir){push}' );
    rewinddir $dirhandle;
}

{
    my @list;
    push @list, $_ while readdir $dirhandle;
    ok( eq_array( \@dir, \@list ), 'push while readdir' );
    rewinddir $dirhandle;
}

{
    my $tmp;
    my @list;
    push @list, $tmp while $tmp = readdir $dirhandle;
    ok( eq_array( \@dir, \@list ), 'push $dir while $dir = readdir' );
    rewinddir $dirhandle;
}

{
    my @list;
    while( my $dir = readdir $dirhandle){
	push @list, $dir;
    }
    ok( eq_array( \@dir, \@list ), 'while($dir=readdir){push}' );
    rewinddir $dirhandle;
}


{
    my @list;
    my $sub = sub{
	push @list, $_;
    };
    $sub->($_) while readdir $dirhandle;
    ok( eq_array( \@dir, \@list ), '$sub->($_) while readdir' );
    rewinddir $dirhandle;
}

{
    my $works = 0;
    while(readdir $dirhandle){
        $_ =~ s/\.$// if defined $_ && $^O eq 'VMS'; # may have zero-length extension
        if( defined $_ && $_ eq '0'){
            $works = 1;
            last;
        }
    }
    ok( $works, 'while(readdir){} with file named "0"' );
    rewinddir $dirhandle;
}

{
    my $works = 0;
    my $sub = sub{
        $_ =~ s/\.$// if defined $_ && $^O eq 'VMS'; # may have zero-length extension
        if( defined $_ && $_ eq '0' ){
            $works = 1;
        }
    };
    $sub->($_) while readdir $dirhandle;
    ok( $works, '$sub->($_) while readdir; with file named "0"' );
    rewinddir $dirhandle;
}

{
    my $works = 0;
    while( my $dir = readdir $dirhandle ){
        $dir =~ s/\.$// if defined $dir && $^O eq 'VMS'; # may have zero-length extension
        if( defined $dir && $dir eq '0'){
            $works = 1;
            last;
        }
    }
    ok( $works, 'while($dir=readdir){} with file named "0"');
    rewinddir $dirhandle;
}

{
    my $tmp;
    my $ok;
    my @list;
    while( $tmp = readdir $dirhandle ){
        $tmp =~ s/\.$// if defined $tmp && $^O eq 'VMS'; # may have zero-length extension
        last if defined($tmp)&& !$tmp && ($ok=1) 
    }
    ok( $ok, '$dir while $dir = readdir; with file named "0"'  );
    rewinddir $dirhandle;
}

closedir $dirhandle;


__SCRIPT__

subtest 'tokenize' => sub {
    my $tokens = Compiler::Lexer->new('')->tokenize($script);
    is_deeply($tokens, [
          bless( {
                   'data' => 'BEGIN',
                   'name' => 'ModWord',
                   'line' => 3,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_ModWord,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ModWord
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'line' => 3,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 4,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'BuiltinFunc',
                   'data' => 'chdir'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 't',
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 4
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 4,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'if',
                   'name' => 'IfStmt'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-d',
                   'name' => 'Handle',
                   'line' => 4,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'type' => Compiler::Lexer::TokenType::T_Handle
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 4,
                   'data' => 't',
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'line' => 4,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '@INC',
                   'name' => 'LibraryDirectories',
                   'line' => 5,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LibraryDirectories,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'name' => 'Assign',
                   'line' => 5,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 5,
                   'data' => '../lib',
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 5
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RequireDecl,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 6,
                   'data' => 'require',
                   'name' => 'RequireDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 6,
                   'name' => 'RawString',
                   'data' => './test.pl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 6,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 7,
                   'data' => '}',
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 9,
                   'name' => 'UseDecl',
                   'data' => 'use'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 9,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'strict',
                   'name' => 'UsedName'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 9,
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
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 10,
                   'name' => 'UseDecl',
                   'data' => 'use'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'line' => 10,
                   'data' => 'warnings',
                   'name' => 'UsedName'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'line' => 10,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 12,
                   'name' => 'Key',
                   'data' => 'plan'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 12,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '10',
                   'name' => 'Int'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 12,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 16,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'data' => 'my',
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$tempdir',
                   'name' => 'LocalVar',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'line' => 16
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 16,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'data' => '=',
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 16,
                   'name' => 'Key',
                   'data' => 'tempfile'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 16,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 18,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'data' => 'mkdir'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$tempdir',
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'line' => 18
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 18,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'data' => '0700',
                   'line' => 18,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 18,
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
                   'line' => 18,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 18,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'data' => 'Can\'t mkdir \'$tempdir\': $!'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 18,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 19,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'data' => 'chdir',
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$tempdir',
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'line' => 19
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'line' => 19,
                   'data' => 'or',
                   'name' => 'AlphabetOr'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'die',
                   'name' => 'BuiltinFunc',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 19
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'die',
                   'name' => 'BuiltinFunc',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 19
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 19,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'String',
                   'data' => 'Can\'t chdir \'$tempdir\': $!'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 19
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'line' => 21,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LocalVar',
                   'data' => '$cleanup',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 21
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'name' => 'Assign',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 21
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '1',
                   'name' => 'Int',
                   'line' => 21,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 21,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 22,
                   'data' => 'my',
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalHashVar,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 22,
                   'name' => 'LocalHashVar',
                   'data' => '%tempfiles'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 22,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'ModWord',
                   'data' => 'END',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_ModWord,
                   'type' => Compiler::Lexer::TokenType::T_ModWord,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 24
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'line' => 24,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'line' => 25,
                   'name' => 'IfStmt',
                   'data' => 'if'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 25
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'data' => '$cleanup',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'line' => 25
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 25,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 25,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 26,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'type' => Compiler::Lexer::TokenType::T_ForeachStmt,
                   'name' => 'ForeachStmt',
                   'data' => 'foreach'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'line' => 26,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LocalVar',
                   'data' => '$file',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'line' => 26
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 26,
                   'data' => '(',
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 26,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'data' => 'keys',
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 26,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_HashVar,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'HashVar',
                   'data' => '%tempfiles'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 26,
                   'name' => 'RightParenthesis',
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 26,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 28,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'if',
                   'name' => 'IfStmt'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'line' => 28,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 28,
                   'data' => 'unlink',
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 28,
                   'name' => 'Var',
                   'data' => '$file'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 28,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'name' => 'LeftBrace',
                   'line' => 28,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 29,
                   'data' => 'warn',
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 29,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'unlink tempfile \'$file\' passed but it\'s still there',
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'if',
                   'name' => 'IfStmt',
                   'line' => 30,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Stmt
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 30,
                   'name' => 'Handle',
                   'data' => '-e'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 30,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$file',
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 30,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'line' => 31,
                   'name' => 'RightBrace',
                   'data' => '}'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 31,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'type' => Compiler::Lexer::TokenType::T_ElseStmt,
                   'data' => 'else',
                   'name' => 'ElseStmt'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'name' => 'LeftBrace',
                   'line' => 31,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'warn',
                   'line' => 32,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'Couldn\'t unlink tempfile \'$file\': $!',
                   'name' => 'String',
                   'line' => 32,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 32,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'line' => 33,
                   'name' => 'RightBrace',
                   'data' => '}'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 34
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 35,
                   'name' => 'BuiltinFunc',
                   'data' => 'chdir'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 35,
                   'data' => '..',
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'or',
                   'name' => 'AlphabetOr',
                   'line' => 35,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'die',
                   'name' => 'BuiltinFunc',
                   'line' => 35,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'line' => 35,
                   'name' => 'String',
                   'data' => 'Couldn\'t chdir .. for cleanup: $!'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 35,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 36,
                   'name' => 'BuiltinFunc',
                   'data' => 'rmdir'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'line' => 36,
                   'data' => '$tempdir',
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 36,
                   'name' => 'AlphabetOr',
                   'data' => 'or'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 36,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'data' => 'die'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'data' => 'Couldn\'t unlink tempdir \'$tempdir\': $!',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 36
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 36,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 37,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightBrace',
                   'data' => '}'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 38,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'data' => '}'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'srand',
                   'name' => 'BuiltinFunc',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 42
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'line' => 42,
                   'data' => '$<',
                   'name' => 'SpecificValue'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '*',
                   'name' => 'Mul',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Mul,
                   'line' => 42
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 42,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$]',
                   'name' => 'SpecificValue'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 42,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 44,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'VarDecl',
                   'data' => 'my'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 44,
                   'type' => Compiler::Lexer::TokenType::T_LocalArrayVar,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LocalArrayVar',
                   'data' => '@chars'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'line' => 44,
                   'name' => 'Assign',
                   'data' => '='
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'line' => 44,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'line' => 44,
                   'data' => 'A',
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '..',
                   'name' => 'Slice',
                   'line' => 44,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_Slice
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'Z',
                   'name' => 'RawString',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'line' => 44
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 44,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'data' => ',',
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'data' => 'a',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 44
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Slice',
                   'data' => '..',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Slice,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 44
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'data' => 'z',
                   'line' => 44,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'data' => ',',
                   'line' => 44,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'data' => '0',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 44
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '..',
                   'name' => 'Slice',
                   'line' => 44,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Slice,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'data' => '9',
                   'line' => 44,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Int
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'line' => 44,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 44,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'FunctionDecl',
                   'data' => 'sub',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_Function,
                   'line' => 46,
                   'name' => 'Function',
                   'data' => 'make_file'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 46,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'data' => '{'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 47,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$name',
                   'name' => 'LocalVar',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 47
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 47
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 47,
                   'name' => 'BuiltinFunc',
                   'data' => 'shift'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 47,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Return,
                   'kind' => Compiler::Lexer::Kind::T_Return,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 49,
                   'data' => 'return',
                   'name' => 'Return'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'if',
                   'name' => 'IfStmt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'line' => 49
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$tempfiles',
                   'name' => 'GlobalVar',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_GlobalVar,
                   'line' => 49
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 49,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'data' => '{'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$name',
                   'name' => 'Var',
                   'line' => 49,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'name' => 'RightBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 49
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 49,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Inc,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '++',
                   'name' => 'Inc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 49,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 51,
                   'data' => 'print',
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'data' => '# Writing to $name in $tempdir\\n',
                   'line' => 51,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 51
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 53,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'data' => 'open',
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 53
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'line' => 53,
                   'data' => '$fh',
                   'name' => 'LocalVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 53,
                   'data' => ',',
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 53,
                   'name' => 'RawString',
                   'data' => '>'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 53,
                   'data' => ',',
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'line' => 53,
                   'name' => 'Var',
                   'data' => '$name'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 53,
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
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 53
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'data' => 'Can\'t open \'$name\' for writing: $!\\n',
                   'line' => 53,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 53,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
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
                   'line' => 54,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$fh',
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_LeftShift,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 54,
                   'name' => 'LeftShift',
                   'data' => '<<'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_HereDocumentRawTag,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 54,
                   'name' => 'HereDocumentRawTag',
                   'data' => 'FILE0'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 54,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 61,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_HereDocument,
                   'data' => 'This file is here for testing

while(readdir $dir){...}
... while readdir $dir

etc
',
                   'name' => 'HereDocument'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'HereDocumentEnd',
                   'data' => 'FILE0',
                   'line' => 61,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_HereDocumentEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'close',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 62
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 62,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'data' => '$fh'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'or',
                   'name' => 'AlphabetOr',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 62
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 62,
                   'name' => 'BuiltinFunc',
                   'data' => 'die'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 62,
                   'name' => 'String',
                   'data' => 'Can\'t close \'$name\': $!'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 62
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'name' => 'RightBrace',
                   'line' => 63,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'sub',
                   'name' => 'FunctionDecl',
                   'line' => 65,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'make_some_files',
                   'name' => 'Function',
                   'type' => Compiler::Lexer::TokenType::T_Function,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 65
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 65,
                   'data' => '{',
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'ForStmt',
                   'data' => 'for',
                   'line' => 66,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ForStmt,
                   'kind' => Compiler::Lexer::Kind::T_Stmt
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 66
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 66,
                   'name' => 'Int',
                   'data' => '1'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 66,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Slice,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Slice',
                   'data' => '..'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'line' => 66,
                   'data' => 'int',
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'rand',
                   'name' => 'BuiltinFunc',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 66
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'line' => 66,
                   'data' => '10',
                   'name' => 'Int'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'line' => 66,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 66,
                   'name' => 'LeftBrace',
                   'data' => '{'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 67,
                   'name' => 'VarDecl',
                   'data' => 'my'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LocalVar',
                   'data' => '$name',
                   'line' => 67,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 67,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 68,
                   'name' => 'Var',
                   'data' => '$name'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_StringAddEqual,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 68,
                   'data' => '.=',
                   'name' => 'StringAddEqual'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 68,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_GlobalVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'GlobalVar',
                   'data' => '$chars'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 68,
                   'data' => '[',
                   'name' => 'LeftBracket'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 68,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'data' => 'rand',
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 68,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_SingleTerm,
                   'type' => Compiler::Lexer::TokenType::T_ArraySize,
                   'name' => 'ArraySize',
                   'data' => '$#'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 68,
                   'name' => 'Key',
                   'data' => 'chars'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 68,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'name' => 'RightBracket',
                   'data' => ']'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'for',
                   'name' => 'ForStmt',
                   'line' => 68,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'type' => Compiler::Lexer::TokenType::T_ForStmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '1',
                   'name' => 'Int',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'line' => 68
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Slice',
                   'data' => '..',
                   'type' => Compiler::Lexer::TokenType::T_Slice,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 68
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 68,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'data' => 'int'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'line' => 68,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '10',
                   'name' => 'Int',
                   'line' => 68,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_Add,
                   'line' => 68,
                   'data' => '+',
                   'name' => 'Add'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'rand',
                   'name' => 'BuiltinFunc',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'line' => 68
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'line' => 68,
                   'name' => 'Int',
                   'data' => '5'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 68,
                   'data' => ')',
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 68,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Call,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 69,
                   'data' => 'make_file',
                   'name' => 'Call'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 69,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 69,
                   'data' => '$name',
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'line' => 69,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 69,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 70,
                   'data' => '}',
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 71,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'data' => '}'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'make_some_files',
                   'name' => 'Call',
                   'line' => 73,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_Call,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 73,
                   'data' => '(',
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'line' => 73,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 73,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Call',
                   'data' => 'make_file',
                   'line' => 74,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_Call,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 74
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 74,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '0',
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 74,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 74,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'make_some_files',
                   'name' => 'Call',
                   'line' => 75,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_Call
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 75,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'line' => 75
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'line' => 75,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 77,
                   'name' => 'Key',
                   'data' => 'ok'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'line' => 77
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 77,
                   'name' => 'Handle',
                   'data' => '-f'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'data' => '0',
                   'line' => 77,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 77,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '\'0\' file is here',
                   'name' => 'String',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 77
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 77,
                   'name' => 'RightParenthesis',
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'line' => 77,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'opendir',
                   'name' => 'BuiltinFunc',
                   'line' => 79,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'my',
                   'name' => 'VarDecl',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'line' => 79
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$dirhandle',
                   'name' => 'LocalVar',
                   'line' => 79,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 79,
                   'data' => ',',
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '.',
                   'name' => 'RawString',
                   'line' => 79,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'AlphabetOr',
                   'data' => 'or',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'die',
                   'line' => 80,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 80,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'data' => 'Failed test: unable to open directory: $!\\n'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 80,
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
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 82
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 82,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_LocalArrayVar,
                   'data' => '@dir',
                   'name' => 'LocalArrayVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'name' => 'Assign',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'line' => 82
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 82,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'readdir',
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'data' => '$dirhandle',
                   'line' => 82,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'line' => 82,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'rewinddir',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 83
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'data' => '$dirhandle',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 83
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 83,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'name' => 'LeftBrace',
                   'line' => 85,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'line' => 86,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '@list',
                   'name' => 'LocalArrayVar',
                   'line' => 86,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalArrayVar,
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
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'type' => Compiler::Lexer::TokenType::T_WhileStmt,
                   'line' => 87,
                   'name' => 'WhileStmt',
                   'data' => 'while'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 87
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'readdir',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 87
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$dirhandle',
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 87
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'line' => 87,
                   'data' => ')',
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'line' => 87,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 88,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'data' => 'push'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 88,
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '@list',
                   'name' => 'ArrayVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 88,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'data' => ',',
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 88,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$_',
                   'name' => 'SpecificValue'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 88
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBrace',
                   'data' => '}',
                   'line' => 89,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 90,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'ok',
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 90,
                   'data' => '(',
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 90,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'eq_array',
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 90,
                   'data' => '(',
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 90,
                   'type' => Compiler::Lexer::TokenType::T_Ref,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '\\',
                   'name' => 'Ref'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 90,
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'ArrayVar',
                   'data' => '@dir'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 90,
                   'data' => ',',
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Ref,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 90,
                   'data' => '\\',
                   'name' => 'Ref'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'ArrayVar',
                   'data' => '@list',
                   'line' => 90,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 90,
                   'data' => ')',
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'name' => 'Comma',
                   'line' => 90,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'data' => 'while(readdir){push}',
                   'line' => 90,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 90,
                   'data' => ')',
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'line' => 90,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'rewinddir',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 91
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 91,
                   'data' => '$dirhandle',
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 91
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'name' => 'RightBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'line' => 92
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'name' => 'LeftBrace',
                   'line' => 94,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'my',
                   'name' => 'VarDecl',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'line' => 95
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 95,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_LocalArrayVar,
                   'name' => 'LocalArrayVar',
                   'data' => '@list'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 95,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 96,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'BuiltinFunc',
                   'data' => 'push'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '@list',
                   'name' => 'ArrayVar',
                   'line' => 96,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 96,
                   'name' => 'Comma',
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'line' => 96,
                   'name' => 'SpecificValue',
                   'data' => '$_'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'WhileStmt',
                   'data' => 'while',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_WhileStmt,
                   'line' => 96
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 96,
                   'data' => 'readdir',
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 96,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'data' => '$dirhandle'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 96,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'ok',
                   'name' => 'Key',
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 97
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'line' => 97,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 97,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'eq_array',
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 97
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 97,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_Ref,
                   'data' => '\\',
                   'name' => 'Ref'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 97,
                   'name' => 'ArrayVar',
                   'data' => '@dir'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 97,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Ref,
                   'line' => 97,
                   'name' => 'Ref',
                   'data' => '\\'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 97,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'ArrayVar',
                   'data' => '@list'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'line' => 97,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 97,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'push while readdir',
                   'name' => 'RawString',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 97
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 97,
                   'data' => ')',
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 97,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 98,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'data' => 'rewinddir'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 98,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'data' => '$dirhandle'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 98,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBrace',
                   'data' => '}',
                   'line' => 99,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 101,
                   'data' => '{',
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 102,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl',
                   'data' => 'my'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$tmp',
                   'name' => 'LocalVar',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 102
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 102,
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
                   'line' => 103,
                   'name' => 'VarDecl',
                   'data' => 'my'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LocalArrayVar',
                   'data' => '@list',
                   'line' => 103,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_LocalArrayVar
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 103
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'line' => 104,
                   'data' => 'push',
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 104,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '@list',
                   'name' => 'ArrayVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'data' => ',',
                   'line' => 104,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 104,
                   'name' => 'Var',
                   'data' => '$tmp'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'while',
                   'name' => 'WhileStmt',
                   'line' => 104,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_WhileStmt,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Stmt
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 104,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$tmp',
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 104,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=',
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'readdir',
                   'name' => 'BuiltinFunc',
                   'line' => 104,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'line' => 104,
                   'name' => 'Var',
                   'data' => '$dirhandle'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 104,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'ok',
                   'name' => 'Key',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 105
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'line' => 105,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 105,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'eq_array',
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 105
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Ref',
                   'data' => '\\',
                   'line' => 105,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Ref,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '@dir',
                   'name' => 'ArrayVar',
                   'line' => 105,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 105
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Ref',
                   'data' => '\\',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Ref,
                   'line' => 105
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '@list',
                   'name' => 'ArrayVar',
                   'line' => 105,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'line' => 105,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'data' => ',',
                   'line' => 105,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 105,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'push $dir while $dir = readdir',
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 105,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightParenthesis',
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'line' => 105,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'rewinddir',
                   'name' => 'BuiltinFunc',
                   'line' => 106,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'data' => '$dirhandle',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 106
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 106,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'name' => 'RightBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'line' => 107
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'line' => 109,
                   'data' => '{',
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'line' => 110,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 110,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalArrayVar,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LocalArrayVar',
                   'data' => '@list'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 110
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'while',
                   'name' => 'WhileStmt',
                   'line' => 111,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_WhileStmt
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 111
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 111,
                   'name' => 'VarDecl',
                   'data' => 'my'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'line' => 111,
                   'name' => 'LocalVar',
                   'data' => '$dir'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 111,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=',
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 111,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'BuiltinFunc',
                   'data' => 'readdir'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'data' => '$dirhandle',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'line' => 111
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 111,
                   'data' => ')',
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'line' => 111,
                   'data' => '{',
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'push',
                   'name' => 'BuiltinFunc',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'line' => 112
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '@list',
                   'name' => 'ArrayVar',
                   'line' => 112,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 112,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'data' => '$dir',
                   'line' => 112,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 112
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'line' => 113,
                   'name' => 'RightBrace',
                   'data' => '}'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 114,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'Key',
                   'data' => 'ok'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'line' => 114,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'eq_array',
                   'name' => 'Key',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 114
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'line' => 114,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '\\',
                   'name' => 'Ref',
                   'line' => 114,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Ref,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 114,
                   'name' => 'ArrayVar',
                   'data' => '@dir'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'data' => ',',
                   'line' => 114,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_Ref,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 114,
                   'name' => 'Ref',
                   'data' => '\\'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 114,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'ArrayVar',
                   'data' => '@list'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 114,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'name' => 'RightParenthesis',
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 114
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'data' => 'while($dir=readdir){push}',
                   'line' => 114,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 114,
                   'data' => ')',
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 114,
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
                   'line' => 115,
                   'name' => 'BuiltinFunc',
                   'data' => 'rewinddir'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'data' => '$dirhandle',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'line' => 115
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 115
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'name' => 'RightBrace',
                   'line' => 116,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'name' => 'LeftBrace',
                   'line' => 119,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 120,
                   'name' => 'VarDecl',
                   'data' => 'my'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 120,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalArrayVar,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LocalArrayVar',
                   'data' => '@list'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 120,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 121,
                   'data' => 'my',
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$sub',
                   'name' => 'LocalVar',
                   'line' => 121,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 121,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=',
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'FunctionDecl',
                   'data' => 'sub',
                   'line' => 121,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'line' => 121,
                   'data' => '{',
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 122,
                   'data' => 'push',
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 122,
                   'data' => '@list',
                   'name' => 'ArrayVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'name' => 'Comma',
                   'line' => 122,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 122,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$_',
                   'name' => 'SpecificValue'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 122,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'name' => 'RightBrace',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 123
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 123,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 124,
                   'name' => 'Var',
                   'data' => '$sub'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_Pointer,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 124,
                   'data' => '->',
                   'name' => 'Pointer'
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
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 124,
                   'name' => 'SpecificValue',
                   'data' => '$_'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'line' => 124,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'WhileStmt',
                   'data' => 'while',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'type' => Compiler::Lexer::TokenType::T_WhileStmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 124
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'readdir',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'line' => 124
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 124,
                   'data' => '$dirhandle',
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 124,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'ok',
                   'name' => 'Key',
                   'line' => 125,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 125
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'eq_array',
                   'name' => 'Key',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 125
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'line' => 125,
                   'name' => 'LeftParenthesis',
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 125,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Ref,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Ref',
                   'data' => '\\'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 125,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar,
                   'name' => 'ArrayVar',
                   'data' => '@dir'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 125,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 125,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Ref,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Ref',
                   'data' => '\\'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 125,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'ArrayVar',
                   'data' => '@list'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 125
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 125
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 125,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'data' => '$sub->($_) while readdir'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 125,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 125,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 126,
                   'data' => 'rewinddir',
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'line' => 126,
                   'data' => '$dirhandle',
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 126,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 127,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'data' => '}',
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 129
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 130,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'VarDecl',
                   'data' => 'my'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LocalVar',
                   'data' => '$works',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'line' => 130
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 130,
                   'name' => 'Assign',
                   'data' => '='
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '0',
                   'name' => 'Int',
                   'line' => 130,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Int
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 130
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'while',
                   'name' => 'WhileStmt',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'type' => Compiler::Lexer::TokenType::T_WhileStmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 131
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 131,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '(',
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 131,
                   'name' => 'BuiltinFunc',
                   'data' => 'readdir'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'data' => '$dirhandle',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 131
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'line' => 131,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 131,
                   'name' => 'LeftBrace',
                   'data' => '{'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SpecificValue',
                   'data' => '$_',
                   'line' => 132,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegOK,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 132,
                   'data' => '=~',
                   'name' => 'RegOK'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 132,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_RegReplacePrefix,
                   'type' => Compiler::Lexer::TokenType::T_RegReplace,
                   'name' => 'RegReplace',
                   'data' => 's'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 132,
                   'data' => '/',
                   'name' => 'RegDelim'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegReplaceFrom,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 132,
                   'data' => '\\.$',
                   'name' => 'RegReplaceFrom'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegMiddleDelim',
                   'data' => '/',
                   'line' => 132,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegMiddleDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegReplaceTo',
                   'data' => '',
                   'line' => 132,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegReplaceTo
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegDelim',
                   'data' => '/',
                   'line' => 132,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'if',
                   'name' => 'IfStmt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'line' => 132
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'defined',
                   'name' => 'BuiltinFunc',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'line' => 132
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SpecificValue',
                   'data' => '$_',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 132
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'And',
                   'data' => '&&',
                   'line' => 132,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_And,
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 132,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$^O',
                   'name' => 'SpecificValue'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 132,
                   'data' => 'eq',
                   'name' => 'StringEqual'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 132,
                   'data' => 'VMS',
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 132
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'IfStmt',
                   'data' => 'if',
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 133
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 133,
                   'data' => '(',
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'defined',
                   'name' => 'BuiltinFunc',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 133
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 133,
                   'data' => '$_',
                   'name' => 'SpecificValue'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '&&',
                   'name' => 'And',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_And,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 133
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 133,
                   'data' => '$_',
                   'name' => 'SpecificValue'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 133,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'name' => 'StringEqual',
                   'data' => 'eq'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '0',
                   'name' => 'RawString',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'line' => 133
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 133,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'line' => 133,
                   'name' => 'LeftBrace',
                   'data' => '{'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 134,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$works',
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 134,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=',
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 134,
                   'name' => 'Int',
                   'data' => '1'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 134,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Last',
                   'data' => 'last',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Control,
                   'type' => Compiler::Lexer::TokenType::T_Last,
                   'line' => 135
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 135,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 136,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}',
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 137,
                   'name' => 'RightBrace',
                   'data' => '}'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 138,
                   'data' => 'ok',
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 138,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 138,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$works',
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 138,
                   'name' => 'Comma',
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 138,
                   'name' => 'RawString',
                   'data' => 'while(readdir){} with file named "0"'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 138,
                   'name' => 'RightParenthesis',
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 138,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'rewinddir',
                   'line' => 139,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'data' => '$dirhandle',
                   'line' => 139,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'line' => 139,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 140,
                   'data' => '}',
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'line' => 142,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'line' => 143
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$works',
                   'name' => 'LocalVar',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 143
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'name' => 'Assign',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 143
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'line' => 143,
                   'data' => '0',
                   'name' => 'Int'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 143,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'my',
                   'name' => 'VarDecl',
                   'line' => 144,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 144,
                   'name' => 'LocalVar',
                   'data' => '$sub'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 144
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'FunctionDecl',
                   'data' => 'sub',
                   'line' => 144,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 144
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$_',
                   'name' => 'SpecificValue',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 145
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 145,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_RegOK,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=~',
                   'name' => 'RegOK'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 's',
                   'name' => 'RegReplace',
                   'line' => 145,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_RegReplacePrefix,
                   'type' => Compiler::Lexer::TokenType::T_RegReplace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '/',
                   'name' => 'RegDelim',
                   'line' => 145,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegReplaceFrom,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 145,
                   'name' => 'RegReplaceFrom',
                   'data' => '\\.$'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegMiddleDelim,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 145,
                   'name' => 'RegMiddleDelim',
                   'data' => '/'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegReplaceTo,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 145,
                   'name' => 'RegReplaceTo',
                   'data' => ''
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegDelim',
                   'data' => '/',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 145
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'IfStmt',
                   'data' => 'if',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 145
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 145,
                   'data' => 'defined',
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SpecificValue',
                   'data' => '$_',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 145
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 145,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_And,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'data' => '&&',
                   'name' => 'And'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 145,
                   'data' => '$^O',
                   'name' => 'SpecificValue'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'line' => 145,
                   'name' => 'StringEqual',
                   'data' => 'eq'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 145,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'data' => 'VMS'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 145,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'if',
                   'name' => 'IfStmt',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 146
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'line' => 146,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 146,
                   'name' => 'BuiltinFunc',
                   'data' => 'defined'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SpecificValue',
                   'data' => '$_',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 146
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 146,
                   'type' => Compiler::Lexer::TokenType::T_And,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '&&',
                   'name' => 'And'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 146,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$_',
                   'name' => 'SpecificValue'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'eq',
                   'name' => 'StringEqual',
                   'line' => 146,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'line' => 146,
                   'data' => '0',
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'line' => 146,
                   'name' => 'RightParenthesis',
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 146
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$works',
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 147
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'name' => 'Assign',
                   'line' => 147,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'kind' => Compiler::Lexer::Kind::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 147,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '1',
                   'name' => 'Int'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 147,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBrace',
                   'data' => '}',
                   'line' => 148,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'name' => 'RightBrace',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 149
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 149
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'data' => '$sub',
                   'line' => 150,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_Pointer,
                   'line' => 150,
                   'data' => '->',
                   'name' => 'Pointer'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'line' => 150,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SpecificValue',
                   'data' => '$_',
                   'line' => 150,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 150,
                   'data' => ')',
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'WhileStmt',
                   'data' => 'while',
                   'line' => 150,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'type' => Compiler::Lexer::TokenType::T_WhileStmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'readdir',
                   'line' => 150,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 150,
                   'data' => '$dirhandle',
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 150
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'ok',
                   'name' => 'Key',
                   'line' => 151,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'name' => 'LeftParenthesis',
                   'line' => 151,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 151,
                   'data' => '$works',
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 151,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 151,
                   'name' => 'RawString',
                   'data' => '$sub->($_) while readdir; with file named "0"'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'line' => 151,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
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
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 152,
                   'name' => 'BuiltinFunc',
                   'data' => 'rewinddir'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'data' => '$dirhandle',
                   'line' => 152,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'line' => 152,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 153,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '}',
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 155,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'data' => '{'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 156
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 156,
                   'data' => '$works',
                   'name' => 'LocalVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'name' => 'Assign',
                   'line' => 156,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '0',
                   'name' => 'Int',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 156
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 156
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'while',
                   'name' => 'WhileStmt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'type' => Compiler::Lexer::TokenType::T_WhileStmt,
                   'line' => 157
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 157,
                   'name' => 'LeftParenthesis',
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 157,
                   'name' => 'VarDecl',
                   'data' => 'my'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LocalVar',
                   'data' => '$dir',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 157
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 157,
                   'name' => 'Assign',
                   'data' => '='
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 157,
                   'data' => 'readdir',
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 157,
                   'data' => '$dirhandle',
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 157,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'name' => 'LeftBrace',
                   'line' => 157,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 158,
                   'name' => 'Var',
                   'data' => '$dir'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegOK',
                   'data' => '=~',
                   'line' => 158,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegOK,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegReplace',
                   'data' => 's',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_RegReplacePrefix,
                   'type' => Compiler::Lexer::TokenType::T_RegReplace,
                   'line' => 158
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 158,
                   'name' => 'RegDelim',
                   'data' => '/'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegReplaceFrom,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 158,
                   'name' => 'RegReplaceFrom',
                   'data' => '\\.$'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 158,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegMiddleDelim,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '/',
                   'name' => 'RegMiddleDelim'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegReplaceTo',
                   'data' => '',
                   'line' => 158,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegReplaceTo,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 158,
                   'data' => '/',
                   'name' => 'RegDelim'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'if',
                   'name' => 'IfStmt',
                   'line' => 158,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Stmt
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'defined',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 158
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'line' => 158,
                   'name' => 'Var',
                   'data' => '$dir'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'And',
                   'data' => '&&',
                   'line' => 158,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_And
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$^O',
                   'name' => 'SpecificValue',
                   'line' => 158,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'eq',
                   'name' => 'StringEqual',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'line' => 158
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 158,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'data' => 'VMS'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 158
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'if',
                   'name' => 'IfStmt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'line' => 159
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 159,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 159,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'defined',
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 159,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$dir',
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 159,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_And,
                   'name' => 'And',
                   'data' => '&&'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 159,
                   'data' => '$dir',
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 159,
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'eq',
                   'name' => 'StringEqual'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 159,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '0',
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'line' => 159,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 159
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'data' => '$works',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 160
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'line' => 160,
                   'data' => '=',
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '1',
                   'name' => 'Int',
                   'line' => 160,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 160
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Control,
                   'type' => Compiler::Lexer::TokenType::T_Last,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 161,
                   'data' => 'last',
                   'name' => 'Last'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 161,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 162,
                   'name' => 'RightBrace',
                   'data' => '}'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'name' => 'RightBrace',
                   'line' => 163,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'data' => 'ok',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'line' => 164
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 164,
                   'name' => 'LeftParenthesis',
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$works',
                   'name' => 'Var',
                   'line' => 164,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'data' => ',',
                   'line' => 164,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 164,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'while($dir=readdir){} with file named "0"',
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'line' => 164,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 164
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 165,
                   'name' => 'BuiltinFunc',
                   'data' => 'rewinddir'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 165,
                   'name' => 'Var',
                   'data' => '$dirhandle'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 165
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 166,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'data' => '}',
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'line' => 168,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 169,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'VarDecl',
                   'data' => 'my'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 169,
                   'name' => 'LocalVar',
                   'data' => '$tmp'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 169,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'line' => 170,
                   'name' => 'VarDecl',
                   'data' => 'my'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 170,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LocalVar',
                   'data' => '$ok'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 170,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'line' => 171,
                   'data' => 'my',
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '@list',
                   'name' => 'LocalArrayVar',
                   'line' => 171,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalArrayVar
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 171,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'while',
                   'name' => 'WhileStmt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'type' => Compiler::Lexer::TokenType::T_WhileStmt,
                   'line' => 172
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'line' => 172,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'data' => '$tmp',
                   'line' => 172,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'data' => '=',
                   'line' => 172,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'readdir',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 172
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$dirhandle',
                   'name' => 'Var',
                   'line' => 172,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 172
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'name' => 'LeftBrace',
                   'line' => 172,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 173,
                   'data' => '$tmp',
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegOK',
                   'data' => '=~',
                   'line' => 173,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegOK,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegReplace',
                   'data' => 's',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegReplace,
                   'kind' => Compiler::Lexer::Kind::T_RegReplacePrefix,
                   'line' => 173
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 173,
                   'name' => 'RegDelim',
                   'data' => '/'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegReplaceFrom',
                   'data' => '\\.$',
                   'line' => 173,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegReplaceFrom,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegMiddleDelim',
                   'data' => '/',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegMiddleDelim,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 173
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '',
                   'name' => 'RegReplaceTo',
                   'line' => 173,
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
                   'line' => 173,
                   'name' => 'RegDelim',
                   'data' => '/'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 173,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'data' => 'if',
                   'name' => 'IfStmt'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 173,
                   'data' => 'defined',
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 173,
                   'name' => 'Var',
                   'data' => '$tmp'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_And,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 173,
                   'name' => 'And',
                   'data' => '&&'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 173,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SpecificValue',
                   'data' => '$^O'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 173,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'eq',
                   'name' => 'StringEqual'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 173,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'VMS',
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 173
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Last',
                   'data' => 'last',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Last,
                   'kind' => Compiler::Lexer::Kind::T_Control,
                   'line' => 174
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 174,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'if',
                   'name' => 'IfStmt'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 174,
                   'data' => 'defined',
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 174,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$tmp',
                   'name' => 'Var',
                   'line' => 174,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'line' => 174,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 174,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_And,
                   'data' => '&&',
                   'name' => 'And'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Not,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_SingleTerm,
                   'line' => 174,
                   'data' => '!',
                   'name' => 'Not'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 174,
                   'data' => '$tmp',
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '&&',
                   'name' => 'And',
                   'line' => 174,
                   'type' => Compiler::Lexer::TokenType::T_And,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 174,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'data' => '$ok',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 174
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 174,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'data' => '=',
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 174,
                   'data' => '1',
                   'name' => 'Int'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'line' => 174
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 175,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'data' => '}',
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 176,
                   'data' => 'ok',
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 176
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$ok',
                   'name' => 'Var',
                   'line' => 176,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 176,
                   'name' => 'Comma',
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 176,
                   'name' => 'RawString',
                   'data' => '$dir while $dir = readdir; with file named "0"'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 176
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 176,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'rewinddir',
                   'name' => 'BuiltinFunc',
                   'line' => 177,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 177,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$dirhandle',
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 177,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBrace',
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'line' => 178
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 180,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'name' => 'BuiltinFunc',
                   'data' => 'closedir'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'data' => '$dirhandle',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'line' => 180
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 180,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'name' => 'SemiColon'
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
            'src' => ' chdir \'t\' if -d \'t\' ;',
            'start_line' => 4,
            'end_line' => 4,
            'has_warnings' => 0,
            'token_num' => 6,
            'block_id' => 1
          },
          {
            'end_line' => 5,
            'has_warnings' => 0,
            'token_num' => 4,
            'block_id' => 1,
            'indent' => 1,
            'src' => ' @INC = \'../lib\' ;',
            'start_line' => 5
          },
          {
            'start_line' => 6,
            'indent' => 1,
            'src' => ' require \'./test.pl\' ;',
            'end_line' => 6,
            'has_warnings' => 0,
            'token_num' => 3,
            'block_id' => 1
          },
          {
            'block_id' => 0,
            'token_num' => 3,
            'has_warnings' => 0,
            'end_line' => 9,
            'src' => ' use strict ;',
            'indent' => 0,
            'start_line' => 9
          },
          {
            'end_line' => 10,
            'has_warnings' => 0,
            'token_num' => 3,
            'block_id' => 0,
            'start_line' => 10,
            'indent' => 0,
            'src' => ' use warnings ;'
          },
          {
            'indent' => 0,
            'src' => ' plan 10 ;',
            'start_line' => 12,
            'end_line' => 12,
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 3
          },
          {
            'has_warnings' => 1,
            'end_line' => 16,
            'block_id' => 0,
            'token_num' => 5,
            'start_line' => 16,
            'src' => ' my $tempdir = tempfile ;',
            'indent' => 0
          },
          {
            'indent' => 0,
            'src' => ' mkdir $tempdir , 0700 or die "Can\'t mkdir \'$tempdir\': $!" ;',
            'start_line' => 18,
            'token_num' => 8,
            'block_id' => 0,
            'has_warnings' => 1,
            'end_line' => 18
          },
          {
            'start_line' => 19,
            'indent' => 0,
            'src' => ' chdir $tempdir or die die "Can\'t chdir \'$tempdir\': $!" ;',
            'has_warnings' => 1,
            'end_line' => 19,
            'token_num' => 7,
            'block_id' => 0
          },
          {
            'start_line' => 21,
            'src' => ' my $cleanup = 1 ;',
            'indent' => 0,
            'token_num' => 5,
            'block_id' => 0,
            'has_warnings' => 0,
            'end_line' => 21
          },
          {
            'indent' => 0,
            'src' => ' my %tempfiles ;',
            'start_line' => 22,
            'has_warnings' => 0,
            'end_line' => 22,
            'block_id' => 0,
            'token_num' => 3
          },
          {
            'end_line' => 37,
            'has_warnings' => 1,
            'block_id' => 2,
            'token_num' => 46,
            'start_line' => 25,
            'src' => ' if ( $cleanup ) { foreach my $file ( keys %tempfiles ) { if ( unlink $file ) { warn "unlink tempfile \'$file\' passed but it\'s still there" if -e $file ; } else { warn "Couldn\'t unlink tempfile \'$file\': $!" ; } } chdir \'..\' or die "Couldn\'t chdir .. for cleanup: $!" ; rmdir $tempdir or die "Couldn\'t unlink tempdir \'$tempdir\': $!" ; }',
            'indent' => 1
          },
          {
            'end_line' => 34,
            'has_warnings' => 1,
            'token_num' => 28,
            'block_id' => 3,
            'start_line' => 26,
            'src' => ' foreach my $file ( keys %tempfiles ) { if ( unlink $file ) { warn "unlink tempfile \'$file\' passed but it\'s still there" if -e $file ; } else { warn "Couldn\'t unlink tempfile \'$file\': $!" ; } }',
            'indent' => 2
          },
          {
            'token_num' => 13,
            'block_id' => 4,
            'end_line' => 31,
            'has_warnings' => 1,
            'start_line' => 28,
            'indent' => 3,
            'src' => ' if ( unlink $file ) { warn "unlink tempfile \'$file\' passed but it\'s still there" if -e $file ; }'
          },
          {
            'src' => ' warn "unlink tempfile \'$file\' passed but it\'s still there" if -e $file ;',
            'indent' => 4,
            'start_line' => 29,
            'block_id' => 5,
            'token_num' => 6,
            'end_line' => 30,
            'has_warnings' => 1
          },
          {
            'start_line' => 31,
            'indent' => 3,
            'src' => ' else { warn "Couldn\'t unlink tempfile \'$file\': $!" ; }',
            'has_warnings' => 0,
            'end_line' => 33,
            'block_id' => 4,
            'token_num' => 6
          },
          {
            'indent' => 4,
            'src' => ' warn "Couldn\'t unlink tempfile \'$file\': $!" ;',
            'start_line' => 32,
            'block_id' => 6,
            'token_num' => 3,
            'has_warnings' => 0,
            'end_line' => 32
          },
          {
            'indent' => 2,
            'src' => ' chdir \'..\' or die "Couldn\'t chdir .. for cleanup: $!" ;',
            'start_line' => 35,
            'has_warnings' => 0,
            'end_line' => 35,
            'block_id' => 3,
            'token_num' => 6
          },
          {
            'src' => ' rmdir $tempdir or die "Couldn\'t unlink tempdir \'$tempdir\': $!" ;',
            'indent' => 2,
            'start_line' => 36,
            'has_warnings' => 1,
            'end_line' => 36,
            'token_num' => 6,
            'block_id' => 3
          },
          {
            'start_line' => 42,
            'src' => ' srand $< * $] ;',
            'indent' => 0,
            'end_line' => 42,
            'has_warnings' => 0,
            'block_id' => 0,
            'token_num' => 5
          },
          {
            'end_line' => 44,
            'has_warnings' => 0,
            'block_id' => 0,
            'token_num' => 17,
            'start_line' => 44,
            'src' => ' my @chars = ( \'A\' .. \'Z\' , \'a\' .. \'z\' , 0 .. 9 ) ;',
            'indent' => 0
          },
          {
            'end_line' => 63,
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 41,
            'indent' => 0,
            'src' => ' sub make_file { my $name = shift ; return if $tempfiles { $name } ++ ; print "# Writing to $name in $tempdir\\n" ; open my $fh , \'>\' , $name or die "Can\'t open \'$name\' for writing: $!\\n" ; print $fh q{This file is here for testing

while(readdir $dir){...}
... while readdir $dir

etc
} ; close $fh or die "Can\'t close \'$name\': $!" ; }',
            'start_line' => 46
          },
          {
            'src' => ' my $name = shift ;',
            'indent' => 1,
            'start_line' => 47,
            'block_id' => 7,
            'token_num' => 5,
            'end_line' => 47,
            'has_warnings' => 0
          },
          {
            'src' => ' return if $tempfiles { $name } ++ ;',
            'indent' => 1,
            'start_line' => 49,
            'end_line' => 49,
            'has_warnings' => 1,
            'block_id' => 7,
            'token_num' => 8
          },
          {
            'token_num' => 3,
            'block_id' => 7,
            'has_warnings' => 0,
            'end_line' => 51,
            'start_line' => 51,
            'src' => ' print "# Writing to $name in $tempdir\\n" ;',
            'indent' => 1
          },
          {
            'end_line' => 53,
            'has_warnings' => 1,
            'block_id' => 7,
            'token_num' => 11,
            'indent' => 1,
            'src' => ' open my $fh , \'>\' , $name or die "Can\'t open \'$name\' for writing: $!\\n" ;',
            'start_line' => 53
          },
          {
            'has_warnings' => 1,
            'end_line' => 54,
            'block_id' => 7,
            'token_num' => 4,
            'src' => ' print $fh q{This file is here for testing

while(readdir $dir){...}
... while readdir $dir

etc
} ;',
            'indent' => 1,
            'start_line' => 54
          },
          {
            'src' => ' close $fh or die "Can\'t close \'$name\': $!" ;',
            'indent' => 1,
            'start_line' => 62,
            'token_num' => 6,
            'block_id' => 7,
            'has_warnings' => 1,
            'end_line' => 62
          },
          {
            'block_id' => 0,
            'token_num' => 40,
            'end_line' => 71,
            'has_warnings' => 1,
            'indent' => 0,
            'src' => ' sub make_some_files { for ( 1 .. int rand 10 ) { my $name ; $name .= $chars [ rand $#chars ] for 1 .. int ( 10 + rand 5 ) ; make_file ( $name ) ; } }',
            'start_line' => 65
          },
          {
            'block_id' => 8,
            'token_num' => 36,
            'end_line' => 70,
            'has_warnings' => 1,
            'start_line' => 66,
            'indent' => 1,
            'src' => ' for ( 1 .. int rand 10 ) { my $name ; $name .= $chars [ rand $#chars ] for 1 .. int ( 10 + rand 5 ) ; make_file ( $name ) ; }'
          },
          {
            'indent' => 2,
            'src' => ' my $name ;',
            'start_line' => 67,
            'end_line' => 67,
            'has_warnings' => 0,
            'token_num' => 3,
            'block_id' => 9
          },
          {
            'start_line' => 68,
            'indent' => 2,
            'src' => ' $name .= $chars [ rand $#chars ] for 1 .. int ( 10 + rand 5 ) ;',
            'has_warnings' => 1,
            'end_line' => 68,
            'block_id' => 9,
            'token_num' => 18
          },
          {
            'indent' => 2,
            'src' => ' make_file ( $name ) ;',
            'start_line' => 69,
            'token_num' => 5,
            'block_id' => 9,
            'has_warnings' => 1,
            'end_line' => 69
          },
          {
            'end_line' => 73,
            'has_warnings' => 0,
            'token_num' => 4,
            'block_id' => 0,
            'start_line' => 73,
            'src' => ' make_some_files ( ) ;',
            'indent' => 0
          },
          {
            'block_id' => 0,
            'token_num' => 5,
            'end_line' => 74,
            'has_warnings' => 0,
            'src' => ' make_file ( \'0\' ) ;',
            'indent' => 0,
            'start_line' => 74
          },
          {
            'token_num' => 4,
            'block_id' => 0,
            'has_warnings' => 0,
            'end_line' => 75,
            'start_line' => 75,
            'src' => ' make_some_files ( ) ;',
            'indent' => 0
          },
          {
            'has_warnings' => 1,
            'end_line' => 77,
            'block_id' => 0,
            'token_num' => 8,
            'start_line' => 77,
            'src' => ' ok ( -f \'0\' , "\'0\' file is here" ) ;',
            'indent' => 0
          },
          {
            'block_id' => 0,
            'token_num' => 9,
            'has_warnings' => 0,
            'end_line' => 80,
            'start_line' => 79,
            'indent' => 0,
            'src' => ' opendir my $dirhandle , \'.\' or die "Failed test: unable to open directory: $!\\n" ;'
          },
          {
            'start_line' => 82,
            'indent' => 0,
            'src' => ' my @dir = readdir $dirhandle ;',
            'block_id' => 0,
            'token_num' => 6,
            'has_warnings' => 1,
            'end_line' => 82
          },
          {
            'start_line' => 83,
            'indent' => 0,
            'src' => ' rewinddir $dirhandle ;',
            'end_line' => 83,
            'has_warnings' => 1,
            'token_num' => 3,
            'block_id' => 0
          },
          {
            'start_line' => 85,
            'indent' => 0,
            'src' => ' { my @list ; while ( readdir $dirhandle ) { push @list , $_ ; } ok ( eq_array ( \\ @dir , \\ @list ) , \'while(readdir){push}\' ) ; rewinddir $dirhandle ; }',
            'has_warnings' => 1,
            'end_line' => 92,
            'token_num' => 34,
            'block_id' => 0
          },
          {
            'has_warnings' => 0,
            'end_line' => 86,
            'token_num' => 3,
            'block_id' => 10,
            'start_line' => 86,
            'src' => ' my @list ;',
            'indent' => 1
          },
          {
            'start_line' => 87,
            'src' => ' while ( readdir $dirhandle ) { push @list , $_ ; }',
            'indent' => 1,
            'has_warnings' => 1,
            'end_line' => 89,
            'block_id' => 10,
            'token_num' => 12
          },
          {
            'start_line' => 88,
            'src' => ' push @list , $_ ;',
            'indent' => 2,
            'token_num' => 5,
            'block_id' => 11,
            'has_warnings' => 0,
            'end_line' => 88
          },
          {
            'token_num' => 14,
            'block_id' => 10,
            'has_warnings' => 1,
            'end_line' => 90,
            'src' => ' ok ( eq_array ( \\ @dir , \\ @list ) , \'while(readdir){push}\' ) ;',
            'indent' => 1,
            'start_line' => 90
          },
          {
            'token_num' => 3,
            'block_id' => 10,
            'end_line' => 91,
            'has_warnings' => 1,
            'src' => ' rewinddir $dirhandle ;',
            'indent' => 1,
            'start_line' => 91
          },
          {
            'indent' => 0,
            'src' => ' { my @list ; push @list , $_ while readdir $dirhandle ; ok ( eq_array ( \\ @dir , \\ @list ) , \'push while readdir\' ) ; rewinddir $dirhandle ; }',
            'start_line' => 94,
            'has_warnings' => 1,
            'end_line' => 99,
            'block_id' => 0,
            'token_num' => 30
          },
          {
            'start_line' => 95,
            'src' => ' my @list ;',
            'indent' => 1,
            'token_num' => 3,
            'block_id' => 12,
            'has_warnings' => 0,
            'end_line' => 95
          },
          {
            'end_line' => 96,
            'has_warnings' => 1,
            'token_num' => 8,
            'block_id' => 12,
            'start_line' => 96,
            'indent' => 1,
            'src' => ' push @list , $_ while readdir $dirhandle ;'
          },
          {
            'has_warnings' => 1,
            'end_line' => 97,
            'block_id' => 12,
            'token_num' => 14,
            'indent' => 1,
            'src' => ' ok ( eq_array ( \\ @dir , \\ @list ) , \'push while readdir\' ) ;',
            'start_line' => 97
          },
          {
            'has_warnings' => 1,
            'end_line' => 98,
            'block_id' => 12,
            'token_num' => 3,
            'src' => ' rewinddir $dirhandle ;',
            'indent' => 1,
            'start_line' => 98
          },
          {
            'start_line' => 101,
            'src' => ' { my $tmp ; my @list ; push @list , $tmp while $tmp = readdir $dirhandle ; ok ( eq_array ( \\ @dir , \\ @list ) , \'push $dir while $dir = readdir\' ) ; rewinddir $dirhandle ; }',
            'indent' => 0,
            'block_id' => 0,
            'token_num' => 35,
            'end_line' => 107,
            'has_warnings' => 1
          },
          {
            'start_line' => 102,
            'src' => ' my $tmp ;',
            'indent' => 1,
            'has_warnings' => 0,
            'end_line' => 102,
            'block_id' => 13,
            'token_num' => 3
          },
          {
            'block_id' => 13,
            'token_num' => 3,
            'end_line' => 103,
            'has_warnings' => 0,
            'start_line' => 103,
            'indent' => 1,
            'src' => ' my @list ;'
          },
          {
            'end_line' => 104,
            'has_warnings' => 1,
            'token_num' => 10,
            'block_id' => 13,
            'start_line' => 104,
            'indent' => 1,
            'src' => ' push @list , $tmp while $tmp = readdir $dirhandle ;'
          },
          {
            'has_warnings' => 1,
            'end_line' => 105,
            'token_num' => 14,
            'block_id' => 13,
            'start_line' => 105,
            'src' => ' ok ( eq_array ( \\ @dir , \\ @list ) , \'push $dir while $dir = readdir\' ) ;',
            'indent' => 1
          },
          {
            'end_line' => 106,
            'has_warnings' => 1,
            'token_num' => 3,
            'block_id' => 13,
            'start_line' => 106,
            'src' => ' rewinddir $dirhandle ;',
            'indent' => 1
          },
          {
            'indent' => 0,
            'src' => ' { my @list ; while ( my $dir = readdir $dirhandle ) { push @list , $dir ; } ok ( eq_array ( \\ @dir , \\ @list ) , \'while($dir=readdir){push}\' ) ; rewinddir $dirhandle ; }',
            'start_line' => 109,
            'token_num' => 37,
            'block_id' => 0,
            'has_warnings' => 1,
            'end_line' => 116
          },
          {
            'has_warnings' => 0,
            'end_line' => 110,
            'block_id' => 14,
            'token_num' => 3,
            'indent' => 1,
            'src' => ' my @list ;',
            'start_line' => 110
          },
          {
            'block_id' => 14,
            'token_num' => 15,
            'has_warnings' => 1,
            'end_line' => 113,
            'indent' => 1,
            'src' => ' while ( my $dir = readdir $dirhandle ) { push @list , $dir ; }',
            'start_line' => 111
          },
          {
            'end_line' => 112,
            'has_warnings' => 1,
            'block_id' => 15,
            'token_num' => 5,
            'indent' => 2,
            'src' => ' push @list , $dir ;',
            'start_line' => 112
          },
          {
            'src' => ' ok ( eq_array ( \\ @dir , \\ @list ) , \'while($dir=readdir){push}\' ) ;',
            'indent' => 1,
            'start_line' => 114,
            'block_id' => 14,
            'token_num' => 14,
            'end_line' => 114,
            'has_warnings' => 1
          },
          {
            'token_num' => 3,
            'block_id' => 14,
            'end_line' => 115,
            'has_warnings' => 1,
            'indent' => 1,
            'src' => ' rewinddir $dirhandle ;',
            'start_line' => 115
          },
          {
            'has_warnings' => 1,
            'end_line' => 127,
            'token_num' => 43,
            'block_id' => 0,
            'indent' => 0,
            'src' => ' { my @list ; my $sub = sub { push @list , $_ ; } ; $sub-> ( $_ ) while readdir $dirhandle ; ok ( eq_array ( \\ @dir , \\ @list ) , \'$sub->($_) while readdir\' ) ; rewinddir $dirhandle ; }',
            'start_line' => 119
          },
          {
            'token_num' => 3,
            'block_id' => 16,
            'end_line' => 120,
            'has_warnings' => 0,
            'indent' => 1,
            'src' => ' my @list ;',
            'start_line' => 120
          },
          {
            'end_line' => 123,
            'has_warnings' => 0,
            'token_num' => 12,
            'block_id' => 16,
            'start_line' => 121,
            'indent' => 1,
            'src' => ' my $sub = sub { push @list , $_ ; } ;'
          },
          {
            'token_num' => 8,
            'block_id' => 16,
            'end_line' => 123,
            'has_warnings' => 0,
            'start_line' => 121,
            'indent' => 1,
            'src' => ' sub { push @list , $_ ; }'
          },
          {
            'has_warnings' => 0,
            'end_line' => 122,
            'block_id' => 17,
            'token_num' => 5,
            'src' => ' push @list , $_ ;',
            'indent' => 2,
            'start_line' => 122
          },
          {
            'start_line' => 124,
            'indent' => 1,
            'src' => ' $sub-> ( $_ ) while readdir $dirhandle ;',
            'end_line' => 124,
            'has_warnings' => 1,
            'token_num' => 9,
            'block_id' => 16
          },
          {
            'indent' => 1,
            'src' => ' ok ( eq_array ( \\ @dir , \\ @list ) , \'$sub->($_) while readdir\' ) ;',
            'start_line' => 125,
            'block_id' => 16,
            'token_num' => 14,
            'end_line' => 125,
            'has_warnings' => 1
          },
          {
            'start_line' => 126,
            'src' => ' rewinddir $dirhandle ;',
            'indent' => 1,
            'block_id' => 16,
            'token_num' => 3,
            'has_warnings' => 1,
            'end_line' => 126
          },
          {
            'has_warnings' => 1,
            'end_line' => 140,
            'token_num' => 57,
            'block_id' => 0,
            'indent' => 0,
            'src' => ' { my $works = 0 ; while ( readdir $dirhandle ) { $_ =~ s/\\.$// if defined $_ && $^O eq \'VMS\' ; if ( defined $_ && $_ eq \'0\' ) { $works = 1 ; last ; } } ok ( $works , \'while(readdir){} with file named "0"\' ) ; rewinddir $dirhandle ; }',
            'start_line' => 129
          },
          {
            'has_warnings' => 0,
            'end_line' => 130,
            'token_num' => 5,
            'block_id' => 18,
            'indent' => 1,
            'src' => ' my $works = 0 ;',
            'start_line' => 130
          },
          {
            'src' => ' while ( readdir $dirhandle ) { $_ =~ s/\\.$// if defined $_ && $^O eq \'VMS\' ; if ( defined $_ && $_ eq \'0\' ) { $works = 1 ; last ; } }',
            'indent' => 1,
            'start_line' => 131,
            'has_warnings' => 1,
            'end_line' => 137,
            'token_num' => 40,
            'block_id' => 18
          },
          {
            'start_line' => 132,
            'indent' => 2,
            'src' => ' $_ =~ s/\\.$// if defined $_ && $^O eq \'VMS\' ;',
            'has_warnings' => 0,
            'end_line' => 132,
            'block_id' => 19,
            'token_num' => 16
          },
          {
            'src' => ' if ( defined $_ && $_ eq \'0\' ) { $works = 1 ; last ; }',
            'indent' => 2,
            'start_line' => 133,
            'end_line' => 136,
            'has_warnings' => 1,
            'block_id' => 19,
            'token_num' => 17
          },
          {
            'start_line' => 134,
            'src' => ' $works = 1 ;',
            'indent' => 3,
            'end_line' => 134,
            'has_warnings' => 1,
            'token_num' => 4,
            'block_id' => 20
          },
          {
            'start_line' => 135,
            'indent' => 3,
            'src' => ' last ;',
            'token_num' => 2,
            'block_id' => 20,
            'end_line' => 135,
            'has_warnings' => 0
          },
          {
            'block_id' => 18,
            'token_num' => 7,
            'end_line' => 138,
            'has_warnings' => 1,
            'src' => ' ok ( $works , \'while(readdir){} with file named "0"\' ) ;',
            'indent' => 1,
            'start_line' => 138
          },
          {
            'start_line' => 139,
            'indent' => 1,
            'src' => ' rewinddir $dirhandle ;',
            'has_warnings' => 1,
            'end_line' => 139,
            'block_id' => 18,
            'token_num' => 3
          },
          {
            'block_id' => 0,
            'token_num' => 64,
            'has_warnings' => 1,
            'end_line' => 153,
            'start_line' => 142,
            'indent' => 0,
            'src' => ' { my $works = 0 ; my $sub = sub { $_ =~ s/\\.$// if defined $_ && $^O eq \'VMS\' ; if ( defined $_ && $_ eq \'0\' ) { $works = 1 ; } } ; $sub-> ( $_ ) while readdir $dirhandle ; ok ( $works , \'$sub->($_) while readdir; with file named "0"\' ) ; rewinddir $dirhandle ; }'
          },
          {
            'has_warnings' => 0,
            'end_line' => 143,
            'block_id' => 21,
            'token_num' => 5,
            'indent' => 1,
            'src' => ' my $works = 0 ;',
            'start_line' => 143
          },
          {
            'src' => ' my $sub = sub { $_ =~ s/\\.$// if defined $_ && $^O eq \'VMS\' ; if ( defined $_ && $_ eq \'0\' ) { $works = 1 ; } } ;',
            'indent' => 1,
            'start_line' => 144,
            'has_warnings' => 1,
            'end_line' => 149,
            'token_num' => 38,
            'block_id' => 21
          },
          {
            'src' => ' sub { $_ =~ s/\\.$// if defined $_ && $^O eq \'VMS\' ; if ( defined $_ && $_ eq \'0\' ) { $works = 1 ; } }',
            'indent' => 1,
            'start_line' => 144,
            'end_line' => 149,
            'has_warnings' => 1,
            'block_id' => 21,
            'token_num' => 34
          },
          {
            'start_line' => 145,
            'src' => ' $_ =~ s/\\.$// if defined $_ && $^O eq \'VMS\' ;',
            'indent' => 2,
            'block_id' => 22,
            'token_num' => 16,
            'end_line' => 145,
            'has_warnings' => 0
          },
          {
            'end_line' => 148,
            'has_warnings' => 1,
            'block_id' => 22,
            'token_num' => 15,
            'indent' => 2,
            'src' => ' if ( defined $_ && $_ eq \'0\' ) { $works = 1 ; }',
            'start_line' => 146
          },
          {
            'block_id' => 23,
            'token_num' => 4,
            'end_line' => 147,
            'has_warnings' => 1,
            'src' => ' $works = 1 ;',
            'indent' => 3,
            'start_line' => 147
          },
          {
            'start_line' => 150,
            'src' => ' $sub-> ( $_ ) while readdir $dirhandle ;',
            'indent' => 1,
            'end_line' => 150,
            'has_warnings' => 1,
            'block_id' => 21,
            'token_num' => 9
          },
          {
            'has_warnings' => 1,
            'end_line' => 151,
            'token_num' => 7,
            'block_id' => 21,
            'start_line' => 151,
            'src' => ' ok ( $works , \'$sub->($_) while readdir; with file named "0"\' ) ;',
            'indent' => 1
          },
          {
            'end_line' => 152,
            'has_warnings' => 1,
            'block_id' => 21,
            'token_num' => 3,
            'start_line' => 152,
            'indent' => 1,
            'src' => ' rewinddir $dirhandle ;'
          },
          {
            'start_line' => 155,
            'src' => ' { my $works = 0 ; while ( my $dir = readdir $dirhandle ) { $dir =~ s/\\.$// if defined $dir && $^O eq \'VMS\' ; if ( defined $dir && $dir eq \'0\' ) { $works = 1 ; last ; } } ok ( $works , \'while($dir=readdir){} with file named "0"\' ) ; rewinddir $dirhandle ; }',
            'indent' => 0,
            'has_warnings' => 1,
            'end_line' => 166,
            'block_id' => 0,
            'token_num' => 60
          },
          {
            'has_warnings' => 0,
            'end_line' => 156,
            'token_num' => 5,
            'block_id' => 24,
            'src' => ' my $works = 0 ;',
            'indent' => 1,
            'start_line' => 156
          },
          {
            'block_id' => 24,
            'token_num' => 43,
            'end_line' => 163,
            'has_warnings' => 1,
            'start_line' => 157,
            'indent' => 1,
            'src' => ' while ( my $dir = readdir $dirhandle ) { $dir =~ s/\\.$// if defined $dir && $^O eq \'VMS\' ; if ( defined $dir && $dir eq \'0\' ) { $works = 1 ; last ; } }'
          },
          {
            'start_line' => 158,
            'indent' => 2,
            'src' => ' $dir =~ s/\\.$// if defined $dir && $^O eq \'VMS\' ;',
            'end_line' => 158,
            'has_warnings' => 1,
            'block_id' => 25,
            'token_num' => 16
          },
          {
            'token_num' => 17,
            'block_id' => 25,
            'end_line' => 162,
            'has_warnings' => 1,
            'start_line' => 159,
            'indent' => 2,
            'src' => ' if ( defined $dir && $dir eq \'0\' ) { $works = 1 ; last ; }'
          },
          {
            'block_id' => 26,
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 160,
            'start_line' => 160,
            'indent' => 3,
            'src' => ' $works = 1 ;'
          },
          {
            'token_num' => 2,
            'block_id' => 26,
            'has_warnings' => 0,
            'end_line' => 161,
            'indent' => 3,
            'src' => ' last ;',
            'start_line' => 161
          },
          {
            'token_num' => 7,
            'block_id' => 24,
            'end_line' => 164,
            'has_warnings' => 1,
            'src' => ' ok ( $works , \'while($dir=readdir){} with file named "0"\' ) ;',
            'indent' => 1,
            'start_line' => 164
          },
          {
            'src' => ' rewinddir $dirhandle ;',
            'indent' => 1,
            'start_line' => 165,
            'block_id' => 24,
            'token_num' => 3,
            'end_line' => 165,
            'has_warnings' => 1
          },
          {
            'src' => ' { my $tmp ; my $ok ; my @list ; while ( $tmp = readdir $dirhandle ) { $tmp =~ s/\\.$// if defined $tmp && $^O eq \'VMS\' ; last if defined ( $tmp ) && ! $tmp && ( $ok = 1 ) } ok ( $ok , \'$dir while $dir = readdir; with file named "0"\' ) ; rewinddir $dirhandle ; }',
            'indent' => 0,
            'start_line' => 168,
            'token_num' => 61,
            'block_id' => 0,
            'has_warnings' => 1,
            'end_line' => 178
          },
          {
            'has_warnings' => 0,
            'end_line' => 169,
            'block_id' => 27,
            'token_num' => 3,
            'start_line' => 169,
            'src' => ' my $tmp ;',
            'indent' => 1
          },
          {
            'has_warnings' => 0,
            'end_line' => 170,
            'block_id' => 27,
            'token_num' => 3,
            'indent' => 1,
            'src' => ' my $ok ;',
            'start_line' => 170
          },
          {
            'block_id' => 27,
            'token_num' => 3,
            'has_warnings' => 0,
            'end_line' => 171,
            'indent' => 1,
            'src' => ' my @list ;',
            'start_line' => 171
          },
          {
            'indent' => 1,
            'src' => ' while ( $tmp = readdir $dirhandle ) { $tmp =~ s/\\.$// if defined $tmp && $^O eq \'VMS\' ; last if defined ( $tmp ) && ! $tmp && ( $ok = 1 ) }',
            'start_line' => 172,
            'end_line' => 175,
            'has_warnings' => 1,
            'token_num' => 40,
            'block_id' => 27
          },
          {
            'indent' => 2,
            'src' => ' $tmp =~ s/\\.$// if defined $tmp && $^O eq \'VMS\' ;',
            'start_line' => 173,
            'has_warnings' => 1,
            'end_line' => 173,
            'token_num' => 16,
            'block_id' => 28
          },
          {
            'src' => ' ok ( $ok , \'$dir while $dir = readdir; with file named "0"\' ) ;',
            'indent' => 1,
            'start_line' => 176,
            'has_warnings' => 1,
            'end_line' => 176,
            'token_num' => 7,
            'block_id' => 27
          },
          {
            'block_id' => 27,
            'token_num' => 3,
            'has_warnings' => 1,
            'end_line' => 177,
            'src' => ' rewinddir $dirhandle ;',
            'indent' => 1,
            'start_line' => 177
          },
          {
            'has_warnings' => 1,
            'end_line' => 180,
            'token_num' => 3,
            'block_id' => 0,
            'src' => ' closedir $dirhandle ;',
            'indent' => 0,
            'start_line' => 180
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
          }
        ]
, 'Compiler::Lexer::get_used_modules');
};

done_testing;
