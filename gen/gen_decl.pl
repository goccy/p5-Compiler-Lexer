#!/usr/bin/perl

use strict;
use warnings;
use YAML::XS qw/Dump/;

my (@info, @token_enum, @kind_enum, @syntax_enum, @type_to_info);
foreach (<DATA>) {
    my ($kind, $type, $data) = split /\s+/;
    my $info = { type => "$type", kind => "$kind", data => "$data" };
    push @info, $info;
    unless (grep { $_ eq $type } @token_enum) {
        push @token_enum, $type;
        $type_to_info[scalar @token_enum - 1] = $info;
    }
    unless (grep { $_ eq $kind } @kind_enum) {
        push @kind_enum, $kind if ($kind);
    }
}

@syntax_enum = qw/Value Term Expr Stmt BlockStmt/;

my $token_type = join ",\n", map { "\t$_" } @token_enum;
my $token_kind = join ",\n", map { "\t$_" } @kind_enum;
my $token_info = join ",\n", map {
    sprintf(qq|\t{Enum::Token::Type::%s, Enum::Token::Kind::%s, "%s", "%s"}|,
            $_->{type}, $_->{kind}, $_->{type}, $_->{data});
} @info;

my $type_to_info = join ",\n", map {
    sprintf(qq|\t{Enum::Token::Type::%s, Enum::Token::Kind::%s, "%s", "%s"}|,
            $_->{type}, $_->{kind}, $_->{type}, $_->{data});
} @type_to_info;

my %keyword_map;
$keyword_map{$_->{data}}++ foreach @info;

my $keywords = join "\n", map {
    sprintf(qq|"%s", {Enum::Token::Type::%s, Enum::Token::Kind::%s, "%s", "%s"}|,
            $_->{data}, $_->{type}, $_->{kind}, $_->{type}, $_->{data});
} grep {
    $keyword_map{$_->{data}} == 1
} grep {
    $_->{data}
} @info;

my $count = 0;
my $token_type_enums = join ",\n", map {
    ' ' x 4 . "T_$_ => " . $count++;
} @token_enum;

$count = 0;
my $syntax_type_enums = join ",\n", map {
    ' ' x 4 . "T_$_ => " . $count++;
} @syntax_enum;

$count = 0;
my $token_kind_enums = join ",\n", map {
    ' ' x 4 . "T_$_ => " . $count++;
} @kind_enum;

my %token_type_constants_map;
my %token_kind_constants_map;
my %syntax_type_constants_map;
$count = 0;
$token_type_constants_map{"T_$_"} = $count++ foreach @token_enum;
$count = 0;
$token_kind_constants_map{"T_$_"} = $count++ foreach @kind_enum;
$count = 0;
$syntax_type_constants_map{"T_$_"} = $count++ foreach @syntax_enum;

my $constants = +{
    token_type => \%token_type_constants_map,
    syntax_type => \%syntax_type_constants_map,
    token_kind => \%token_kind_constants_map
};

open(my $fh, '>', 'include/gen_token.hpp');
print $fh <<"CODE";
namespace Enum {
namespace Token {
namespace Type {
typedef enum {
$token_type
} Type;
}

namespace Kind {
typedef enum {
$token_kind
} Kind;
}
}
}
CODE

open($fh, '>', 'src/compiler/util/Compiler_gen_token_decl.cpp');
print $fh <<"CODE";
#include <common.hpp>

TokenInfo decl_tokens[] = {
$token_info
};

TokenInfo type_to_info[] = {
$type_to_info
};

CODE

open($fh, '>', 'lib/Compiler/Lexer/Constants.pm');
print $fh <<CODE;
use strict;
use warnings;

package Compiler::Lexer::TokenType;
use constant {
$token_type_enums
};

package Compiler::Lexer::SyntaxType;
use constant {
$syntax_type_enums
};

package Compiler::Lexer::Kind;
use constant {
$token_kind_enums
};

1;
CODE

open($fh, '>', 'gen/gen_constants.yaml');
print $fh Dump $constants;

open($fh, '>', 'gen/reserved_keywords.gperf');
print $fh <<CODE;
%{

#include <lexer.hpp>

typedef struct _ReservedKeyword {
    const char *name;
    TokenInfo info;
} ReservedKeyword;
%}

ReservedKeyword;
%%
$keywords
%%
CODE

close($fh);

__DATA__
AUTOLOAD            AUTOLOAD                AUTOLOAD
Annotation          Annotation              #@
Assign              AddEqual                +=
Assign              AndBitEqual             &=
Assign              AndEqual                &&=
Assign              Assign                  =
Assign              DefaultEqual            //=
Assign              DivEqual                /=
Assign              LeftShiftEqual          <<=
Assign              ModEqual                %=
Assign              MulEqual                *=
Assign              NotBitEqual             ^=
Assign              OrBitEqual              |=
Assign              OrEqual                 ||=
Assign              PowerEqual              **=
Assign              RightShiftEqual         >>=
Assign              StringAddEqual          .=
Assign              StringMulEqual          x=
Assign              SubEqual                -=
CORE                CORE                    CORE
Class               Class
Colon               Colon                   :
Comma               Comma                   ,
Control             Break                   break
Control             Continue                continue
Control             Goto                    goto
Control             Last                    last
Control             Next                    next
Control             Redo                    redo
DESTROY             DESTROY                 DESTROY
DataWord            DataWord                __DATA__
DataWord            DataWord                __END__
Decl                CallDecl                &
Decl                FieldDecl
Decl                FormatDecl
Decl                Function
Decl                FunctionDecl            sub
Decl                GlobalVarDecl
Decl                LocalDecl               local
Decl                LocalVarDecl
Decl                MultiGlobalVarDecl
Decl                MultiLocalVarDecl
Decl                OurDecl                 our
Decl                RequireDecl             require
Decl                StateDecl               state
Decl                UseDecl                 use
Decl                VarDecl                 my
DefaultStmt         DefaultStmt             default
Do                  Do                      do
Function            BuiltinFunc             abs
Function            BuiltinFunc             accept
Function            BuiltinFunc             alarm
Function            BuiltinFunc             atan2
Function            BuiltinFunc             bind
Function            BuiltinFunc             binmode
Function            BuiltinFunc             bless
Function            BuiltinFunc             caller
Function            BuiltinFunc             chdir
Function            BuiltinFunc             chmod
Function            BuiltinFunc             chomp
Function            BuiltinFunc             chop
Function            BuiltinFunc             chown
Function            BuiltinFunc             chr
Function            BuiltinFunc             chroot
Function            BuiltinFunc             close
Function            BuiltinFunc             closedir
Function            BuiltinFunc             connect
Function            BuiltinFunc             cos
Function            BuiltinFunc             crypt
Function            BuiltinFunc             dbmclose
Function            BuiltinFunc             dbmopen
Function            BuiltinFunc             defined
Function            BuiltinFunc             delete
Function            BuiltinFunc             die
Function            BuiltinFunc             dump
Function            BuiltinFunc             each
Function            BuiltinFunc             endgrent
Function            BuiltinFunc             endhostent
Function            BuiltinFunc             endnetent
Function            BuiltinFunc             endprotoent
Function            BuiltinFunc             endpwent
Function            BuiltinFunc             endservent
Function            BuiltinFunc             eof
Function            BuiltinFunc             eval
Function            BuiltinFunc             exec
Function            BuiltinFunc             exists
Function            BuiltinFunc             exit
Function            BuiltinFunc             exp
Function            BuiltinFunc             fcntl
Function            BuiltinFunc             fileno
Function            BuiltinFunc             flock
Function            BuiltinFunc             fork
Function            BuiltinFunc             format
Function            BuiltinFunc             formline
Function            BuiltinFunc             getc
Function            BuiltinFunc             getgrent
Function            BuiltinFunc             getgrgid
Function            BuiltinFunc             getgrnam
Function            BuiltinFunc             gethostbyaddr
Function            BuiltinFunc             gethostbyname
Function            BuiltinFunc             gethostent
Function            BuiltinFunc             getlogin
Function            BuiltinFunc             getnetbyaddr
Function            BuiltinFunc             getnetbyname
Function            BuiltinFunc             getnetent
Function            BuiltinFunc             getpeername
Function            BuiltinFunc             getpgrp
Function            BuiltinFunc             getppid
Function            BuiltinFunc             getpriority
Function            BuiltinFunc             getprotobyname
Function            BuiltinFunc             getprotobynumber
Function            BuiltinFunc             getprotoent
Function            BuiltinFunc             getpwent
Function            BuiltinFunc             getpwnam
Function            BuiltinFunc             getpwuid
Function            BuiltinFunc             getservbyname
Function            BuiltinFunc             getservbyport
Function            BuiltinFunc             getservent
Function            BuiltinFunc             getsockname
Function            BuiltinFunc             getsockopt
Function            BuiltinFunc             glob
Function            BuiltinFunc             gmtime
Function            BuiltinFunc             grep
Function            BuiltinFunc             hex
Function            BuiltinFunc             index
Function            BuiltinFunc             int
Function            BuiltinFunc             ioctl
Function            BuiltinFunc             join
Function            BuiltinFunc             keys
Function            BuiltinFunc             kill
Function            BuiltinFunc             lc
Function            BuiltinFunc             lcfirst
Function            BuiltinFunc             length
Function            BuiltinFunc             link
Function            BuiltinFunc             listen
Function            BuiltinFunc             localtime
Function            BuiltinFunc             log
Function            BuiltinFunc             lstat
Function            BuiltinFunc             map
Function            BuiltinFunc             mkdir
Function            BuiltinFunc             msgctl
Function            BuiltinFunc             msgget
Function            BuiltinFunc             msgrcv
Function            BuiltinFunc             msgsnd
Function            BuiltinFunc             no
Function            BuiltinFunc             oct
Function            BuiltinFunc             open
Function            BuiltinFunc             opendir
Function            BuiltinFunc             ord
Function            BuiltinFunc             pack
Function            BuiltinFunc             pipe
Function            BuiltinFunc             pop
Function            BuiltinFunc             pos
Function            BuiltinFunc             print
Function            BuiltinFunc             printf
Function            BuiltinFunc             push
Function            BuiltinFunc             quotemeta
Function            BuiltinFunc             rand
Function            BuiltinFunc             read
Function            BuiltinFunc             readdir
Function            BuiltinFunc             readlink
Function            BuiltinFunc             recv
Function            BuiltinFunc             ref
Function            BuiltinFunc             rename
Function            BuiltinFunc             reset
Function            BuiltinFunc             reverse
Function            BuiltinFunc             rewinddir
Function            BuiltinFunc             rindex
Function            BuiltinFunc             rmdir
Function            BuiltinFunc             say
Function            BuiltinFunc             scalar
Function            BuiltinFunc             seek
Function            BuiltinFunc             seekdir
Function            BuiltinFunc             select
Function            BuiltinFunc             semctl
Function            BuiltinFunc             semget
Function            BuiltinFunc             semop
Function            BuiltinFunc             send
Function            BuiltinFunc             setgrent
Function            BuiltinFunc             sethostent
Function            BuiltinFunc             setnetent
Function            BuiltinFunc             setpgrp
Function            BuiltinFunc             setpriority
Function            BuiltinFunc             setprotoent
Function            BuiltinFunc             setpwent
Function            BuiltinFunc             setservent
Function            BuiltinFunc             setsockopt
Function            BuiltinFunc             shift
Function            BuiltinFunc             shmctl
Function            BuiltinFunc             shmget
Function            BuiltinFunc             shmread
Function            BuiltinFunc             shmwrite
Function            BuiltinFunc             shutdown
Function            BuiltinFunc             sin
Function            BuiltinFunc             sleep
Function            BuiltinFunc             socket
Function            BuiltinFunc             socketpair
Function            BuiltinFunc             sort
Function            BuiltinFunc             splice
Function            BuiltinFunc             split
Function            BuiltinFunc             sprintf
Function            BuiltinFunc             sqrt
Function            BuiltinFunc             srand
Function            BuiltinFunc             stat
Function            BuiltinFunc             study
Function            BuiltinFunc             substr
Function            BuiltinFunc             symlink
Function            BuiltinFunc             syscall
Function            BuiltinFunc             sysread
Function            BuiltinFunc             sysseek
Function            BuiltinFunc             system
Function            BuiltinFunc             syswrite
Function            BuiltinFunc             tell
Function            BuiltinFunc             telldir
Function            BuiltinFunc             tie
Function            BuiltinFunc             tied
Function            BuiltinFunc             time
Function            BuiltinFunc             times
Function            BuiltinFunc             truncate
Function            BuiltinFunc             uc
Function            BuiltinFunc             ucfirst
Function            BuiltinFunc             umask
Function            BuiltinFunc             unlink
Function            BuiltinFunc             unpack
Function            BuiltinFunc             unshift
Function            BuiltinFunc             untie
Function            BuiltinFunc             utime
Function            BuiltinFunc             values
Function            BuiltinFunc             vec
Function            BuiltinFunc             wait
Function            BuiltinFunc             waitpid
Function            BuiltinFunc             wantarray
Function            BuiltinFunc             warn
Function            BuiltinFunc             write
Function            Call
Function            Method
Get                 ArrayAt
Get                 HashAt
Handle              Handle                  -A
Handle              Handle                  -B
Handle              Handle                  -C
Handle              Handle                  -M
Handle              Handle                  -O
Handle              Handle                  -R
Handle              Handle                  -S
Handle              Handle                  -T
Handle              Handle                  -W
Handle              Handle                  -X
Handle              Handle                  -b
Handle              Handle                  -c
Handle              Handle                  -d
Handle              Handle                  -e
Handle              Handle                  -f
Handle              Handle                  -g
Handle              Handle                  -k
Handle              Handle                  -l
Handle              Handle                  -o
Handle              Handle                  -p
Handle              Handle                  -r
Handle              Handle                  -s
Handle              Handle                  -t
Handle              Handle                  -u
Handle              Handle                  -w
Handle              Handle                  -x
Handle              Handle                  -z
Handle              STDERR                  STDERR
Handle              STDIN                   STDIN
Handle              STDOUT                  STDOUT
Import              Import                  import
ModWord             ModWord                 BEGIN
ModWord             ModWord                 CHECK
ModWord             ModWord                 END
ModWord             ModWord                 INIT
ModWord             ModWord                 UNITCHECK
Modifier            ArrayDereference        @{
Modifier            ArraySizeDereference    $#{
Modifier            CodeDereference         &{
Modifier            HashDereference         %{
Modifier            ScalarDereference       ${
Modifier            ShortArrayDereference   @$
Modifier            ShortCodeDereference    &$
Modifier            ShortHashDereference    %$
Modifier            ShortScalarDereference
Module              RequiredName
Module              UsedName
Namespace           Namespace
Operator            Add                     +
Operator            AlphabetAnd             and
Operator            AlphabetOr              or
Operator            AlphabetXOr             xor
Operator            And                     &&
Operator            Arrow                   =>
Operator            BitAnd                  &
Operator            BitNot                  ~
Operator            BitOr                   |
Operator            BitXOr                  ^
Operator            Compare                 <=>
Operator            Dec                     --
Operator            DefaultOperator         //
Operator            Diamond                 <>
Operator            Div                     /
Operator            EqualEqual              ==
Operator            Exp                     **
Operator            Glob                    *
Operator            Greater                 >
Operator            GreaterEqual            >=
Operator            Inc                     ++
Operator            LeftShift               <<
Operator            Less                    <
Operator            LessEqual               <=
Operator            Mod                     %
Operator            Mul                     *
Operator            NamespaceResolver       ::
Operator            NotEqual                !=
Operator            Operator
Operator            Or                      ||
Operator            Pointer                 ->
Operator            PolymorphicCompare      ~~
Operator            Ref                     \\
Operator            RegNot                  !~
Operator            RegOK                   =~
Operator            RightShift              >>
Operator            Slice                   ..
Operator            StringAdd               .
Operator            StringCompare           cmp
Operator            StringEqual             eq
Operator            StringGreater           gt
Operator            StringGreaterEqual      ge
Operator            StringLess              lt
Operator            StringLessEqual         le
Operator            StringMul               x
Operator            StringNotEqual          ne
Operator            Sub                     -
Operator            ThreeTermOperator       ?
Operator            ToDo                    ...
Package             Package                 package
Ref                 ArrayRef
Ref                 HashRef
Ref                 LabelRef
Ref                 TypeRef
RegOpt              RegOpt
RegPrefix           RegDecl                 qr
RegPrefix           RegDoubleQuote          qq
RegPrefix           RegExec                 qx
RegPrefix           RegList                 qw
RegPrefix           RegMatch                m
RegPrefix           RegQuote                q
RegReplacePrefix    RegAllReplace           tr
RegReplacePrefix    RegAllReplace           y
RegReplacePrefix    RegReplace              s
Return              Return                  return
Set                 ArraySet
Set                 HashSet
SingleTerm          AlphabetNot             not
SingleTerm          ArraySize               $#
SingleTerm          CodeRef                 \\&
SingleTerm          Is
SingleTerm          Not                     !
SpecificKeyword     SpecificKeyword         __FILE__
SpecificKeyword     SpecificKeyword         __LINE__
SpecificKeyword     SpecificKeyword         __PACKAGE__
SpecificKeyword     SpecificKeyword         __SUB__
Stmt                ElseStmt                else
Stmt                ElsifStmt               elsif
Stmt                ForStmt                 for
Stmt                ForeachStmt             foreach
Stmt                GivenStmt               given
Stmt                IfStmt                  if
Stmt                UnlessStmt              unless
Stmt                UntilStmt               until
Stmt                WhenStmt                when
Stmt                WhileStmt               while
StmtEnd             SemiColon               ;
Symbol              LeftBrace               {
Symbol              LeftBracket             [
Symbol              LeftParenthesis         (
Symbol              PostDeref
Symbol              PostDerefArraySliceCloseBracket
Symbol              PostDerefArraySliceOpenBracket
Symbol              PostDerefCodeCloseParen
Symbol              PostDerefCodeOpenParen
Symbol              PostDerefHashSliceCloseBrace
Symbol              PostDerefHashSliceOpenBrace
Symbol              PostDerefStar
Symbol              RightBrace              }
Symbol              RightBracket            ]
Symbol              RightParenthesis        )
Term                Argument
Term                ArgumentArray           @_
Term                Array
Term                ArrayVar
Term                BareWord
Term                CodeVar
Term                ConstValue
Term                Default                 undef
Term                Double
Term                Environment             %ENV
Term                ExecString
Term                Format
Term                FormatEnd
Term                GlobalArrayVar
Term                GlobalHashVar
Term                GlobalVar
Term                HandleDelim
Term                Hash
Term                HashVar
Term                HereDocument
Term                HereDocumentBareTag
Term                HereDocumentEnd
Term                HereDocumentExecTag
Term                HereDocumentRawTag
Term                HereDocumentTag
Term                Include                 %INC
Term                Int
Term                Key
Term                LibraryDirectories      @INC
Term                List
Term                LocalArrayVar
Term                LocalHashVar
Term                LocalVar
Term                Object
Term                ProgramArgument         @ARGV
Term                Prototype
Term                RawHereDocument
Term                RawString
Term                RegDelim
Term                RegExp
Term                RegMiddleDelim
Term                RegReplaceFrom
Term                RegReplaceTo
Term                Signal                  %SIG
Term                SpecificValue           $!
Term                SpecificValue           $$
Term                SpecificValue           $%
Term                SpecificValue           $&
Term                SpecificValue           $'
Term                SpecificValue           $(
Term                SpecificValue           $)
Term                SpecificValue           $*
Term                SpecificValue           $+
Term                SpecificValue           $,
Term                SpecificValue           $-
Term                SpecificValue           $.
Term                SpecificValue           $/
Term                SpecificValue           $0
Term                SpecificValue           $1
Term                SpecificValue           $2
Term                SpecificValue           $3
Term                SpecificValue           $4
Term                SpecificValue           $5
Term                SpecificValue           $6
Term                SpecificValue           $7
Term                SpecificValue           $8
Term                SpecificValue           $9
Term                SpecificValue           $:
Term                SpecificValue           $;
Term                SpecificValue           $<
Term                SpecificValue           $=
Term                SpecificValue           $>
Term                SpecificValue           $?
Term                SpecificValue           $@
Term                SpecificValue           $[
Term                SpecificValue           $\"
Term                SpecificValue           $\\
Term                SpecificValue           $]
Term                SpecificValue           $^
Term                SpecificValue           $^A
Term                SpecificValue           $^D
Term                SpecificValue           $^E
Term                SpecificValue           $^F
Term                SpecificValue           $^G
Term                SpecificValue           $^H
Term                SpecificValue           $^I
Term                SpecificValue           $^L
Term                SpecificValue           $^M
Term                SpecificValue           $^O
Term                SpecificValue           $^P
Term                SpecificValue           $^R
Term                SpecificValue           $^T
Term                SpecificValue           $^W
Term                SpecificValue           $^X
Term                SpecificValue           $_
Term                SpecificValue           $`
Term                SpecificValue           $|
Term                SpecificValue           $~
Term                String
Term                Var
Term                VersionString
Undefined           Undefined
Verbose             Comment
Verbose             Pod
Verbose             WhiteSpace
