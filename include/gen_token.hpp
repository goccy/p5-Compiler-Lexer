namespace Enum {
namespace Token {
namespace Type {
typedef enum {
	AUTOLOAD,
	Annotation,
	AddEqual,
	AndBitEqual,
	AndEqual,
	Assign,
	DefaultEqual,
	DivEqual,
	LeftShiftEqual,
	ModEqual,
	MulEqual,
	NotBitEqual,
	OrBitEqual,
	OrEqual,
	PowerEqual,
	RightShiftEqual,
	StringAddEqual,
	StringMulEqual,
	SubEqual,
	CORE,
	Class,
	Colon,
	Comma,
	Break,
	Continue,
	Goto,
	Last,
	Next,
	Redo,
	DESTROY,
	DataWord,
	CallDecl,
	FieldDecl,
	FormatDecl,
	Function,
	FunctionDecl,
	GlobalVarDecl,
	LocalDecl,
	LocalVarDecl,
	MultiGlobalVarDecl,
	MultiLocalVarDecl,
	OurDecl,
	RequireDecl,
	StateDecl,
	UseDecl,
	VarDecl,
	DefaultStmt,
	Do,
	BuiltinFunc,
	Call,
	Method,
	ArrayAt,
	HashAt,
	Handle,
	STDERR,
	STDIN,
	STDOUT,
	Import,
	ModWord,
	ArrayDereference,
	ArraySizeDereference,
	CodeDereference,
	HashDereference,
	ScalarDereference,
	ShortArrayDereference,
	ShortCodeDereference,
	ShortHashDereference,
	ShortScalarDereference,
	RequiredName,
	UsedName,
	Namespace,
	Add,
	AlphabetAnd,
	AlphabetOr,
	AlphabetXOr,
	And,
	Arrow,
	BitAnd,
	BitNot,
	BitOr,
	BitXOr,
	Compare,
	Dec,
	DefaultOperator,
	Diamond,
	Div,
	EqualEqual,
	Exp,
	Glob,
	Greater,
	GreaterEqual,
	Inc,
	LeftShift,
	Less,
	LessEqual,
	Mod,
	Mul,
	NamespaceResolver,
	NotEqual,
	Operator,
	Or,
	Pointer,
	PolymorphicCompare,
	Ref,
	RegNot,
	RegOK,
	RightShift,
	Slice,
	StringAdd,
	StringCompare,
	StringEqual,
	StringGreater,
	StringGreaterEqual,
	StringLess,
	StringLessEqual,
	StringMul,
	StringNotEqual,
	Sub,
	ThreeTermOperator,
	ToDo,
	Package,
	ArrayRef,
	HashRef,
	LabelRef,
	TypeRef,
	RegOpt,
	RegDecl,
	RegDoubleQuote,
	RegExec,
	RegList,
	RegMatch,
	RegQuote,
	RegAllReplace,
	RegReplace,
	Return,
	ArraySet,
	HashSet,
	AlphabetNot,
	ArraySize,
	CodeRef,
	Is,
	Not,
	SpecificKeyword,
	ElseStmt,
	ElsifStmt,
	ForStmt,
	ForeachStmt,
	GivenStmt,
	IfStmt,
	UnlessStmt,
	UntilStmt,
	WhenStmt,
	WhileStmt,
	SemiColon,
	LeftBrace,
	LeftBracket,
	LeftParenthesis,
	PostDeref,
	PostDerefArraySliceCloseBracket,
	PostDerefArraySliceOpenBracket,
	PostDerefCodeCloseParen,
	PostDerefCodeOpenParen,
	PostDerefHashSliceCloseBrace,
	PostDerefHashSliceOpenBrace,
	PostDerefStar,
	RightBrace,
	RightBracket,
	RightParenthesis,
	Argument,
	ArgumentArray,
	Array,
	ArrayVar,
	BareWord,
	CodeVar,
	ConstValue,
	Default,
	Double,
	Environment,
	ExecString,
	Format,
	FormatEnd,
	GlobalArrayVar,
	GlobalHashVar,
	GlobalVar,
	HandleDelim,
	Hash,
	HashVar,
	HereDocument,
	HereDocumentBareTag,
	HereDocumentEnd,
	HereDocumentExecTag,
	HereDocumentRawTag,
	HereDocumentTag,
	Include,
	Int,
	Key,
	LibraryDirectories,
	List,
	LocalArrayVar,
	LocalHashVar,
	LocalVar,
	Object,
	ProgramArgument,
	Prototype,
	RawHereDocument,
	RawString,
	RegDelim,
	RegExp,
	RegMiddleDelim,
	RegReplaceFrom,
	RegReplaceTo,
	Signal,
	SpecificValue,
	String,
	Var,
	VersionString,
	Undefined,
	Comment,
	Pod,
	WhiteSpace
} Type;
}

namespace Kind {
typedef enum {
	AUTOLOAD,
	Annotation,
	Assign,
	CORE,
	Class,
	Colon,
	Comma,
	Control,
	DESTROY,
	DataWord,
	Decl,
	DefaultStmt,
	Do,
	Function,
	Get,
	Handle,
	Import,
	ModWord,
	Modifier,
	Module,
	Namespace,
	Operator,
	Package,
	Ref,
	RegOpt,
	RegPrefix,
	RegReplacePrefix,
	Return,
	Set,
	SingleTerm,
	SpecificKeyword,
	Stmt,
	StmtEnd,
	Symbol,
	Term,
	Undefined,
	Verbose
} Kind;
}
}
}
