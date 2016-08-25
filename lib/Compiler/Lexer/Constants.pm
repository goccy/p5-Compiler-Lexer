use strict;
use warnings;

package Compiler::Lexer::TokenType;
use constant {
    T_AUTOLOAD => 0,
    T_Annotation => 1,
    T_AddEqual => 2,
    T_AndBitEqual => 3,
    T_AndEqual => 4,
    T_Assign => 5,
    T_DefaultEqual => 6,
    T_DivEqual => 7,
    T_LeftShiftEqual => 8,
    T_ModEqual => 9,
    T_MulEqual => 10,
    T_NotBitEqual => 11,
    T_OrBitEqual => 12,
    T_OrEqual => 13,
    T_PowerEqual => 14,
    T_RightShiftEqual => 15,
    T_StringAddEqual => 16,
    T_StringMulEqual => 17,
    T_SubEqual => 18,
    T_CORE => 19,
    T_Class => 20,
    T_Colon => 21,
    T_Comma => 22,
    T_Break => 23,
    T_Continue => 24,
    T_Goto => 25,
    T_Last => 26,
    T_Next => 27,
    T_Redo => 28,
    T_DESTROY => 29,
    T_DataWord => 30,
    T_CallDecl => 31,
    T_FieldDecl => 32,
    T_FormatDecl => 33,
    T_Function => 34,
    T_FunctionDecl => 35,
    T_GlobalVarDecl => 36,
    T_LocalDecl => 37,
    T_LocalVarDecl => 38,
    T_MultiGlobalVarDecl => 39,
    T_MultiLocalVarDecl => 40,
    T_OurDecl => 41,
    T_RequireDecl => 42,
    T_StateDecl => 43,
    T_UseDecl => 44,
    T_VarDecl => 45,
    T_DefaultStmt => 46,
    T_Do => 47,
    T_BuiltinFunc => 48,
    T_Call => 49,
    T_Method => 50,
    T_ArrayAt => 51,
    T_HashAt => 52,
    T_Handle => 53,
    T_STDERR => 54,
    T_STDIN => 55,
    T_STDOUT => 56,
    T_Import => 57,
    T_ModWord => 58,
    T_ArrayDereference => 59,
    T_ArraySizeDereference => 60,
    T_CodeDereference => 61,
    T_HashDereference => 62,
    T_ScalarDereference => 63,
    T_ShortArrayDereference => 64,
    T_ShortCodeDereference => 65,
    T_ShortHashDereference => 66,
    T_ShortScalarDereference => 67,
    T_RequiredName => 68,
    T_UsedName => 69,
    T_Namespace => 70,
    T_Add => 71,
    T_AlphabetAnd => 72,
    T_AlphabetOr => 73,
    T_AlphabetXOr => 74,
    T_And => 75,
    T_Arrow => 76,
    T_BitAnd => 77,
    T_BitNot => 78,
    T_BitOr => 79,
    T_BitXOr => 80,
    T_Compare => 81,
    T_Dec => 82,
    T_DefaultOperator => 83,
    T_Diamond => 84,
    T_Div => 85,
    T_EqualEqual => 86,
    T_Exp => 87,
    T_Glob => 88,
    T_Greater => 89,
    T_GreaterEqual => 90,
    T_Inc => 91,
    T_LeftShift => 92,
    T_Less => 93,
    T_LessEqual => 94,
    T_Mod => 95,
    T_Mul => 96,
    T_NamespaceResolver => 97,
    T_NotEqual => 98,
    T_Operator => 99,
    T_Or => 100,
    T_Pointer => 101,
    T_PolymorphicCompare => 102,
    T_Ref => 103,
    T_RegNot => 104,
    T_RegOK => 105,
    T_RightShift => 106,
    T_Slice => 107,
    T_StringAdd => 108,
    T_StringCompare => 109,
    T_StringEqual => 110,
    T_StringGreater => 111,
    T_StringGreaterEqual => 112,
    T_StringLess => 113,
    T_StringLessEqual => 114,
    T_StringMul => 115,
    T_StringNotEqual => 116,
    T_Sub => 117,
    T_ThreeTermOperator => 118,
    T_ToDo => 119,
    T_Package => 120,
    T_ArrayRef => 121,
    T_HashRef => 122,
    T_LabelRef => 123,
    T_TypeRef => 124,
    T_RegOpt => 125,
    T_RegDecl => 126,
    T_RegDoubleQuote => 127,
    T_RegExec => 128,
    T_RegList => 129,
    T_RegMatch => 130,
    T_RegQuote => 131,
    T_RegAllReplace => 132,
    T_RegReplace => 133,
    T_Return => 134,
    T_ArraySet => 135,
    T_HashSet => 136,
    T_AlphabetNot => 137,
    T_ArraySize => 138,
    T_CodeRef => 139,
    T_Is => 140,
    T_Not => 141,
    T_SpecificKeyword => 142,
    T_ElseStmt => 143,
    T_ElsifStmt => 144,
    T_ForStmt => 145,
    T_ForeachStmt => 146,
    T_GivenStmt => 147,
    T_IfStmt => 148,
    T_UnlessStmt => 149,
    T_UntilStmt => 150,
    T_WhenStmt => 151,
    T_WhileStmt => 152,
    T_SemiColon => 153,
    T_LeftBrace => 154,
    T_LeftBracket => 155,
    T_LeftParenthesis => 156,
    T_PostDeref => 157,
    T_PostDerefArraySliceCloseBracket => 158,
    T_PostDerefArraySliceOpenBracket => 159,
    T_PostDerefCodeCloseParen => 160,
    T_PostDerefCodeOpenParen => 161,
    T_PostDerefHashSliceCloseBrace => 162,
    T_PostDerefHashSliceOpenBrace => 163,
    T_PostDerefStar => 164,
    T_RightBrace => 165,
    T_RightBracket => 166,
    T_RightParenthesis => 167,
    T_Argument => 168,
    T_ArgumentArray => 169,
    T_Array => 170,
    T_ArrayVar => 171,
    T_BareWord => 172,
    T_CodeVar => 173,
    T_ConstValue => 174,
    T_Default => 175,
    T_Double => 176,
    T_Environment => 177,
    T_ExecString => 178,
    T_Format => 179,
    T_FormatEnd => 180,
    T_GlobalArrayVar => 181,
    T_GlobalHashVar => 182,
    T_GlobalVar => 183,
    T_HandleDelim => 184,
    T_Hash => 185,
    T_HashVar => 186,
    T_HereDocument => 187,
    T_HereDocumentBareTag => 188,
    T_HereDocumentEnd => 189,
    T_HereDocumentExecTag => 190,
    T_HereDocumentRawTag => 191,
    T_HereDocumentTag => 192,
    T_Include => 193,
    T_Int => 194,
    T_Key => 195,
    T_LibraryDirectories => 196,
    T_List => 197,
    T_LocalArrayVar => 198,
    T_LocalHashVar => 199,
    T_LocalVar => 200,
    T_Object => 201,
    T_ProgramArgument => 202,
    T_Prototype => 203,
    T_RawHereDocument => 204,
    T_RawString => 205,
    T_RegDelim => 206,
    T_RegExp => 207,
    T_RegMiddleDelim => 208,
    T_RegReplaceFrom => 209,
    T_RegReplaceTo => 210,
    T_Signal => 211,
    T_SpecificValue => 212,
    T_String => 213,
    T_Var => 214,
    T_VersionString => 215,
    T_Undefined => 216,
    T_Comment => 217,
    T_Pod => 218,
    T_WhiteSpace => 219
};

package Compiler::Lexer::SyntaxType;
use constant {
    T_Value => 0,
    T_Term => 1,
    T_Expr => 2,
    T_Stmt => 3,
    T_BlockStmt => 4
};

package Compiler::Lexer::Kind;
use constant {
    T_AUTOLOAD => 0,
    T_Annotation => 1,
    T_Assign => 2,
    T_CORE => 3,
    T_Class => 4,
    T_Colon => 5,
    T_Comma => 6,
    T_Control => 7,
    T_DESTROY => 8,
    T_DataWord => 9,
    T_Decl => 10,
    T_DefaultStmt => 11,
    T_Do => 12,
    T_Function => 13,
    T_Get => 14,
    T_Handle => 15,
    T_Import => 16,
    T_ModWord => 17,
    T_Modifier => 18,
    T_Module => 19,
    T_Namespace => 20,
    T_Operator => 21,
    T_Package => 22,
    T_Ref => 23,
    T_RegOpt => 24,
    T_RegPrefix => 25,
    T_RegReplacePrefix => 26,
    T_Return => 27,
    T_Set => 28,
    T_SingleTerm => 29,
    T_SpecificKeyword => 30,
    T_Stmt => 31,
    T_StmtEnd => 32,
    T_Symbol => 33,
    T_Term => 34,
    T_Undefined => 35,
    T_Verbose => 36
};

1;
