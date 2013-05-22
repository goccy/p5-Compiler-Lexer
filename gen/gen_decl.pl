#!/usr/bin/perl
open(ous, ">", "include/gen_token.hpp");
my @array = ();
my @token_enum = ();
my @kind_enum = ();
foreach (<DATA>) {
    my ($kind,$type,$data) = split /\s+/;
    push @array, {type => "$type", kind => "$kind", data => "$data"};
    unless (grep{$_ eq $type} @token_enum) {
        push(@token_enum, $type);
    }
    unless (grep{$_ eq $kind} @kind_enum) {
        push(@kind_enum, $kind) if ($kind);
    }
}
close $data;

print ous "namespace Enum {\n";
print ous "namespace Token {\n";
print ous "namespace Type {\n";
print ous "typedef enum {\n";
foreach (@token_enum) {
	print ous "\t$_,\n";
}
print ous "} Type;\n";
print ous "}\n";
print ous "\n";

print ous "namespace Kind {\n";
print ous "typedef enum {\n";
foreach (@kind_enum) {
	print ous "\t$_,\n";
}
print ous "} Kind;\n";
print ous "}\n";

print ous "}\n";
print ous "}\n";

open(ous, ">", "gen_token_decl.cpp");
print ous "#include <common.hpp>\n";
print ous "TokenInfo decl_tokens[] = {\n";
foreach my $elem (@array) {
    my $type = $elem->{type};
    my $kind = $elem->{kind};
    my $data = $elem->{data};
    print ous "\t{Enum::Token::Type::${type}, Enum::Token::Kind::${kind}, \"${type}\", \"${data}\"},\n";
}
print ous "};\n";
print ous "\n";

open(ous, ">", "lib/Compiler/Lexer/Constants.pm");
my $token_type_enums = "";
my $count = 0;
foreach my $tk (@token_enum) {
    $token_type_enums .= " " x 4 . "T_$tk => $count,\n";
    $count++;
}

my $kind_enums = "";
$count = 0;
foreach my $kind (@kind_enum) {
    $kind_enums .= " " x 4 . "T_$kind => $count,\n";
    $count++;
}

print ous <<CODE;
package Compiler::Lexer::TokenType;
use strict;
use warnings;
use constant {
$token_type_enums
};
1;

package Compiler::Lexer::SyntaxType;
use strict;
use warnings;
use constant {
    T_Value     => 0,
    T_Term      => 1,
    T_Expr      => 2,
    T_Stmt      => 3,
    T_BlockStmt => 4
};
1;

package Compiler::Lexer::Kind;
use strict;
use warnings;
use constant {
$kind_enums
};
1;
CODE
close(ous);

__DATA__
Return          	Return              	return
Operator        	Add                 	+
Operator        	Sub                 	-
Operator        	Mul                 	*
Operator        	Div                 	/
Operator        	Mod                 	%
Operator        	ThreeTermOperator   	?
Operator        	Greater             	>
Operator        	Less                	<
Operator        	StringAdd           	.
Operator        	Ref                 	\\
Operator        	Glob                	*
Operator        	BitNot              	~
Operator        	BitOr               	|
Operator        	Or                  	or
Operator        	BitAnd              	&
Operator        	And                 	and
Operator        	BitXOr              	^
Operator        	XOr                 	xor
Operator        	StringMul           	x
Assign          	AddEqual            	+=
Assign          	SubEqual            	-=
Assign          	MulEqual            	*=
Assign          	DivEqual            	/=
Assign          	ModEqual            	%=
Assign          	StringAdd           	.=
Operator        	GreaterEqual        	>=
Operator        	LessEqual           	<=
Operator        	EqualEqual          	==
Operator        	Diamond             	<>
Operator        	Compare             	<=>
Operator        	PolymorphicCompare  	~~
Operator        	RegOK               	=~
Operator        	RegNot              	!~
Operator        	NotEqual            	!=
Operator        	ArraySize           	$#
Operator        	StringLess          	lt
Operator        	StringLessEqual     	le
Operator        	StringGreater       	gt
Operator        	StringGreaterEqual  	ge
Operator        	StringEqual         	eq
Operator        	StringNotEqual      	ne
Operator        	StringCompare       	cmp
Operator        	Inc                 	++
Operator        	Dec                 	--
Operator        	Exp                 	**
Assign          	PowerEqual          	**=
Assign          	DefaultEqual        	//=
Operator        	LeftShift           	<<
Operator        	RightShift          	>>
Operator        	And                 	&&
Operator        	Or                  	||
Assign          	AndBitEqual         	&=
Assign          	OrBitEqual          	|=
Assign          	NotBitEqual         	^=
Assign          	OrEqual             	||=
Assign          	AndEqual            	&&=
Operator        	Slice               	..
Operator        	DefaultOperator     	//
Operator        	ToDo                	...
Decl            	VarDecl             	my
Decl            	FunctionDecl        	sub
Function        	Method              	
Assign          	Assign              	=
SingleTerm      	Is                  	
SingleTerm      	IsNot               	!
SingleTerm      	Not                 	not
Function        	BuiltinFunc         	chomp
Function        	BuiltinFunc         	chop
Function        	BuiltinFunc         	chr
Function        	BuiltinFunc         	crypt
Function        	BuiltinFunc         	index
Function        	BuiltinFunc         	lc
Function        	BuiltinFunc         	lcfirst
Function        	BuiltinFunc         	length
Function        	BuiltinFunc         	ord
Function        	BuiltinFunc         	pack
Function        	BuiltinFunc         	unpack
Function        	BuiltinFunc         	sort
Function        	BuiltinFunc         	reverse
Function        	BuiltinFunc         	rindex
Function        	BuiltinFunc         	sprintf
Function        	BuiltinFunc         	substr
Function        	BuiltinFunc         	uc
Function        	BuiltinFunc         	ucfirst
Function        	BuiltinFunc         	pos
Function        	BuiltinFunc         	quotemeta
Function        	BuiltinFunc         	split
Function        	BuiltinFunc         	study
Function        	BuiltinFunc         	pop
Function        	BuiltinFunc         	pop
Function        	BuiltinFunc         	push
Function        	BuiltinFunc         	splice
Function        	BuiltinFunc         	shift
Function        	BuiltinFunc         	unshift
Function        	BuiltinFunc         	grep
Function        	BuiltinFunc         	join
Function        	BuiltinFunc         	map
Function        	BuiltinFunc         	delete
Function        	BuiltinFunc         	each
Function        	BuiltinFunc         	exists
Function        	BuiltinFunc         	keys
Function        	BuiltinFunc         	values
Function        	BuiltinFunc         	binmode
Function        	BuiltinFunc         	close
Function        	BuiltinFunc         	closedir
Function        	BuiltinFunc         	dbmclose
Function        	BuiltinFunc         	dbmopen
Function        	BuiltinFunc         	die
Function        	BuiltinFunc         	eof
Function        	BuiltinFunc         	fileno
Function        	BuiltinFunc         	flock
Function        	BuiltinFunc         	format
Function        	BuiltinFunc         	getc
Function        	BuiltinFunc         	print
Function        	BuiltinFunc         	say
Function        	BuiltinFunc         	printf
Function        	BuiltinFunc         	read
Function        	BuiltinFunc         	readdir
Function        	BuiltinFunc         	rewinddir
Function        	BuiltinFunc         	seek
Function        	BuiltinFunc         	seekdir
Function        	BuiltinFunc         	select
Function        	BuiltinFunc         	syscall
Function        	BuiltinFunc         	sysread
Function        	BuiltinFunc         	sysseek
Function        	BuiltinFunc         	syswrite
Function        	BuiltinFunc         	tell
Function        	BuiltinFunc         	telldir
Function        	BuiltinFunc         	truncate
Function        	BuiltinFunc         	warn
Function        	BuiltinFunc         	write
Function        	BuiltinFunc         	syswrite
Function        	BuiltinFunc         	vec
Function        	BuiltinFunc         	chdir
Function        	BuiltinFunc         	chmod
Function        	BuiltinFunc         	chown
Function        	BuiltinFunc         	chroot
Function        	BuiltinFunc         	fcntl
Function        	BuiltinFunc         	glob
Function        	BuiltinFunc         	ioctl
Function        	BuiltinFunc         	link
Function        	BuiltinFunc         	lstat
Function        	BuiltinFunc         	mkdir
Function        	BuiltinFunc         	open
Function        	BuiltinFunc         	opendir
Function        	BuiltinFunc         	readlink
Function        	BuiltinFunc         	rename
Function        	BuiltinFunc         	rmdir
Function        	BuiltinFunc         	stat
Function        	BuiltinFunc         	symlink
Function        	BuiltinFunc         	umask
Function        	BuiltinFunc         	unlink
Function        	BuiltinFunc         	utime
Function        	BuiltinFunc         	caller
Function        	BuiltinFunc         	dump
Function        	BuiltinFunc         	eval
Function        	BuiltinFunc         	exit
Function        	BuiltinFunc         	wantarray
Function        	BuiltinFunc         	formline
Function        	BuiltinFunc         	reset
Function        	BuiltinFunc         	scalar
Function        	BuiltinFunc         	alarm
Function        	BuiltinFunc         	exec
Function        	BuiltinFunc         	fork
Function        	BuiltinFunc         	getpgrp
Function        	BuiltinFunc         	getppid
Function        	BuiltinFunc         	getpriority
Function        	BuiltinFunc         	kill
Function        	BuiltinFunc         	pipe
Function        	BuiltinFunc         	setpgrp
Function        	BuiltinFunc         	setpriority
Function        	BuiltinFunc         	sleep
Function        	BuiltinFunc         	system
Function        	BuiltinFunc         	times
Function        	BuiltinFunc         	wait
Function        	BuiltinFunc         	waitpid
Function        	BuiltinFunc         	no
Function        	BuiltinFunc         	tie
Function        	BuiltinFunc         	tied
Function        	BuiltinFunc         	untie
Function        	BuiltinFunc         	accept
Function        	BuiltinFunc         	bind
Function        	BuiltinFunc         	connect
Function        	BuiltinFunc         	getpeername
Function        	BuiltinFunc         	getsockname
Function        	BuiltinFunc         	getsockopt
Function        	BuiltinFunc         	listen
Function        	BuiltinFunc         	recv
Function        	BuiltinFunc         	send
Function        	BuiltinFunc         	setsockopt
Function        	BuiltinFunc         	shutdown
Function        	BuiltinFunc         	socket
Function        	BuiltinFunc         	socketpair
Function        	BuiltinFunc         	msgctl
Function        	BuiltinFunc         	msgget
Function        	BuiltinFunc         	msgrcv
Function        	BuiltinFunc         	msgsnd
Function        	BuiltinFunc         	semctl
Function        	BuiltinFunc         	semget
Function        	BuiltinFunc         	semop
Function        	BuiltinFunc         	shmctl
Function        	BuiltinFunc         	shmget
Function        	BuiltinFunc         	shmread
Function        	BuiltinFunc         	shmwrite
Function        	BuiltinFunc         	endgrent
Function        	BuiltinFunc         	endhostent
Function        	BuiltinFunc         	endnetent
Function        	BuiltinFunc         	endpwent
Function        	BuiltinFunc         	getgrent
Function        	BuiltinFunc         	getgrent
Function        	BuiltinFunc         	getgrgid
Function        	BuiltinFunc         	getgrnam
Function        	BuiltinFunc         	getlogin
Function        	BuiltinFunc         	getpwent
Function        	BuiltinFunc         	getpwnam
Function        	BuiltinFunc         	getpwuid
Function        	BuiltinFunc         	setgrent
Function        	BuiltinFunc         	setpwent
Function        	BuiltinFunc         	endprotoent
Function        	BuiltinFunc         	endservent
Function        	BuiltinFunc         	gethostbyaddr
Function        	BuiltinFunc         	gethostbyname
Function        	BuiltinFunc         	gethostent
Function        	BuiltinFunc         	getnetbyaddr
Function        	BuiltinFunc         	getnetbyname
Function        	BuiltinFunc         	getnetent
Function        	BuiltinFunc         	getprotobyname
Function        	BuiltinFunc         	getprotobynumber
Function        	BuiltinFunc         	getprotoent
Function        	BuiltinFunc         	getservbyname
Function        	BuiltinFunc         	getservbyport
Function        	BuiltinFunc         	getservent
Function        	BuiltinFunc         	sethostent
Function        	BuiltinFunc         	setnetent
Function        	BuiltinFunc         	setprotoent
Function        	BuiltinFunc         	setservent
Function        	BuiltinFunc         	gmtime
Function        	BuiltinFunc         	localtime
Function        	BuiltinFunc         	time
Function        	BuiltinFunc         	times
Function        	BuiltinFunc         	ref
Function        	BuiltinFunc         	bless
Function        	BuiltinFunc         	defined
Function        	BuiltinFunc         	abs
Function        	BuiltinFunc         	atan2
Function        	BuiltinFunc         	cos
Function        	BuiltinFunc         	exp
Function        	BuiltinFunc         	hex
Function        	BuiltinFunc         	int
Function        	BuiltinFunc         	log
Function        	BuiltinFunc         	oct
Function        	BuiltinFunc         	rand
Function        	BuiltinFunc         	sin
Function        	BuiltinFunc         	sqrt
Function        	BuiltinFunc         	srand
Decl            	RequireDecl         	require
Import          	Import              	import
SpecificKeyword 	SpecificKeyword     	__PACKAGE__
SpecificKeyword 	SpecificKeyword     	__FILE__
SpecificKeyword 	SpecificKeyword     	__LINE__
SpecificKeyword 	SpecificKeyword     	__SUB__
DataWord        	DataWord            	__DATA__
DataWord        	DataWord            	__END__
ModWord         	ModWord             	BEGIN
ModWord         	ModWord             	CHECK
ModWord         	ModWord             	INIT
ModWord         	ModWord             	END
ModWord         	ModWord             	UNITCHECK
AUTOLOAD        	AUTOLOAD            	AUTOLOAD
CORE            	CORE                	CORE
DESTROY         	DESTROY             	DESTROY
Handle          	STDIN               	STDIN
Handle          	STDOUT              	STDOUT
Handle          	STDERR              	STDERR
Redo            	Redo                	redo
Next            	Next                	next
Last            	Last                	last
Goto            	Goto                	goto
Continue        	Continue            	continue
Do              	Do                  	do
Break           	Break               	break
Handle          	Handle              	-b
Handle          	Handle              	-c
Handle          	Handle              	-d
Handle          	Handle              	-e
Handle          	Handle              	-f
Handle          	Handle              	-g
Handle          	Handle              	-k
Handle          	Handle              	-l
Handle          	Handle              	-o
Handle          	Handle              	-p
Handle          	Handle              	-r
Handle          	Handle              	-s
Handle          	Handle              	-t
Handle          	Handle              	-u
Handle          	Handle              	-w
Handle          	Handle              	-x
Handle          	Handle              	-z
Handle          	Handle              	-A
Handle          	Handle              	-B
Handle          	Handle              	-C
Handle          	Handle              	-M
Handle          	Handle              	-O
Handle          	Handle              	-R
Handle          	Handle              	-S
Handle          	Handle              	-T
Handle          	Handle              	-W
Handle          	Handle              	-X
Decl            	LocalDecl           	local
Decl            	OurDecl             	our
Decl            	StateDecl           	state
Decl            	UseDecl             	use
Term            	UsedName            	
Stmt            	IfStmt              	if
Stmt            	ElseStmt            	else
Stmt            	ElsifStmt           	elsif
Stmt            	UnlessStmt          	unless
Stmt            	UntilStmt           	until
Stmt            	WhenStmt            	when
Stmt            	GivenStmt           	given
DefaultStmt     	DefaultStmt         	default
Comma           	Comma               	,
Colon           	Colon               	:
StmtEnd         	SemiColon           	;
Symbol          	LeftParenthesis     	(
Symbol          	RightParenthesis    	)
Symbol          	LeftBrace           	{
Symbol          	RightBrace          	}
Symbol          	LeftBracket         	[
Symbol          	RightBracket        	]
Modifier        	ArrayDereference    	@{
Modifier        	HashDereference     	%{
Modifier        	ScalarDereference   	${
Modifier        	ShortScalarDereference	
Modifier        	ShortArrayDereference	@$
Modifier        	ShortHashDereference	%$
Modifier        	ShortCodeDereference	&$
Modifier        	ArraySizeDereference	$#{
Term            	Key                 	
Term            	BareWord            	
Operator        	Arrow               	=>
Operator        	Pointer             	->
Operator        	NamespaceResolver   	::
Namespace       	Namespace           	
Package         	Package             	package
Class           	Class               	
Decl            	CallDecl            	&
SingleTerm      	CodeRef             	\\&
Stmt            	WhileStmt           	while
Stmt            	ForStmt             	for
Stmt            	ForeachStmt         	foreach
Annotation      	Annotation          	#@
Term            	ArgumentArray       	@_
Term            	SpecificValue       	$_
Term            	SpecificValue       	$0
Term            	SpecificValue       	$1
Term            	SpecificValue       	$2
Term            	SpecificValue       	$3
Term            	SpecificValue       	$4
Term            	SpecificValue       	$5
Term            	SpecificValue       	$6
Term            	SpecificValue       	$7
Term            	SpecificValue       	$8
Term            	SpecificValue       	$9
Term            	SpecificValue       	$&
Term            	SpecificValue       	$`
Term            	SpecificValue       	$'
Term            	SpecificValue       	$+
Term            	SpecificValue       	$.
Term            	SpecificValue       	$/
Term            	SpecificValue       	$|
Term            	SpecificValue       	$*
Term            	SpecificValue       	$,
Term            	SpecificValue       	$\\
Term            	SpecificValue       	$\"
Term            	SpecificValue       	$%
Term            	SpecificValue       	$=
Term            	SpecificValue       	$-
Term            	SpecificValue       	$~
Term            	SpecificValue       	$^
Term            	SpecificValue       	$:
Term            	SpecificValue       	$?
Term            	SpecificValue       	$!
Term            	SpecificValue       	$@
Term            	SpecificValue       	$$
Term            	SpecificValue       	$<
Term            	SpecificValue       	$>
Term            	SpecificValue       	$(
Term            	SpecificValue       	$)
Term            	SpecificValue       	$[
Term            	SpecificValue       	$]
Term            	SpecificValue       	$;
Term            	SpecificValue       	$^A
Term            	SpecificValue       	$^D
Term            	SpecificValue       	$^E
Term            	SpecificValue       	$^F
Term            	SpecificValue       	$^G
Term            	SpecificValue       	$^H
Term            	SpecificValue       	$^I
Term            	SpecificValue       	$^L
Term            	SpecificValue       	$^M
Term            	SpecificValue       	$^O
Term            	SpecificValue       	$^P
Term            	SpecificValue       	$^R
Term            	SpecificValue       	$^T
Term            	SpecificValue       	$^W
Term            	SpecificValue       	$^X
Term            	ConstValue          	
Term            	ProgramArgument     	@ARGV
Term            	LibraryDirectories  	@INC
Term            	Environment         	%ENV
Term            	Include             	%INC
Term            	Signal              	%SIG
RegOpt          	RegOpt              	
RegPrefix       	RegQuote            	q
RegPrefix       	RegDoubleQuote      	qq
RegPrefix       	RegList             	qw
RegPrefix       	RegExec             	qx
RegPrefix       	RegDecl             	qr
RegPrefix       	RegMatch            	m
Term            	RegDelim            	
Term            	RegMiddleDelim      	
RegReplacePrefix	RegAllReplace       	tr
RegReplacePrefix	RegAllReplace       	y
RegReplacePrefix	RegReplace          	s
Term            	RegReplaceFrom      	
Term            	RegReplaceTo        	
Decl            	FieldDecl           	
Ref             	TypeRef             	
Ref             	LabelRef            	
Decl            	LocalVarDecl        	
Decl            	GlobalVarDecl       	
Decl            	MultiLocalVarDecl   	
Decl            	MultiGlobalVarDecl  	
Term            	Prototype           	
Term            	Var                 	
Term            	CodeVar             	
Term            	ArrayVar            	
Term            	HashVar             	
Term            	Int                 	
Term            	Double              	
Term            	String              	
Term            	RawString           	
Term            	ExecString          	
Term            	HereDocumentTag     	
Term            	HereDocumentRawTag  	
Term            	RawHereDocument     	
Term            	HereDocument        	
Term            	HereDocumentEnd     	
Decl            	FormatDecl          	
Term            	Format              	
Term            	FormatEnd           	
Term            	Object              	
Term            	RegExp              	
Term            	Array               	
Term            	Hash                	
Operator        	Operator            	
Term            	LocalVar            	
Term            	LocalArrayVar       	
Term            	LocalHashVar        	
Term            	GlobalVar           	
Term            	GlobalArrayVar      	
Term            	GlobalHashVar       	
Ref             	ArrayRef            	
Ref             	HashRef             	
Get             	ArrayAt             	
Get             	HashAt              	
Set             	ArraySet            	
Set             	HashSet             	
Decl            	Function            	
Function        	Call                	
Term            	Argument            	
Term            	List                	
Term            	Default             	undef
Undefined       	Undefined           	
