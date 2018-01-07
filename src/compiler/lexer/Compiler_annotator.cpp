#include <lexer.hpp>

namespace TokenType = Enum::Token::Type;
namespace TokenKind = Enum::Token::Kind;
using namespace TokenType;
using namespace std;

Annotator::Annotator(void)
{
}

#define ANNOTATE(method, data, info) do {		\
		method(ctx, data, tk, idx, &info);			\
		if (info.type != Undefined) {			\
			tk->info = info;					\
			ctx->prev_type = info.type;			\
			return;								\
		}										\
	} while (0)

void Annotator::annotate(LexContext *ctx, size_t idx)
{
	Token *tk = ctx->tmgr->at(idx);
	// Ignore WhiteSpace tokens to annotate
	if (tk->info.type == WhiteSpace) {
		return;
	}
	if (tk->info.type != Undefined) {
		ctx->prev_type = tk->info.type;
		return;
	}
	TokenInfo info;
	info.type = Undefined;
	string data = string(tk->_data);
	ANNOTATE(annotateRegOpt, data, info);
	ANNOTATE(annotateNamespace, data, info);
	ANNOTATE(annotateMethod, data, info);
	ANNOTATE(annotateKey, data, info);
	ANNOTATE(annotateShortScalarDereference, data, info);
	ANNOTATE(annotateCallDecl, data, info);
	ANNOTATE(annotateHandleDelimiter, data, info);
	ANNOTATE(annotateReservedKeyword, data, info);
	ANNOTATE(annotateGlobOrMul, data, info);
	ANNOTATE(annotateNamelessFunction, data, info);
	ANNOTATE(annotateLocalVariable, data, info);
	ANNOTATE(annotateVariable, data, info);
	ANNOTATE(annotateGlobalVariable, data, info);
	ANNOTATE(annotateFunction, data, info);
	ANNOTATE(annotateCall, data, info);
	ANNOTATE(annotateClass, data, info);
	ANNOTATE(annotateModuleName, data, info);
	ANNOTATE(annotateBareWord, data, info);
}

bool Annotator::isRegexOption(const char *opt)
{
	size_t len = strlen(opt);
	for (size_t i = 0; i < len; i++) {
		char ch = opt[i];
		switch (ch) {
		case 'a': case 'c': case 'd': case 'e':
		case 'g': case 'i': case 'm': case 'l':
		case 'o': case 'p': case 'r': case 's':
		case 'u': case 'x':
			break;
		default:
			return false;
			break;
		}
	}
	return true;
}

void Annotator::annotateRegOpt(LexContext *ctx, const string &data, Token *tk, size_t, TokenInfo *info)
{
	if (ctx->prev_type == RegDelim && isalpha(tk->_data[0]) &&
		data != "or" &&
		isRegexOption(data.c_str())) {
		*info = ctx->tmgr->getTokenInfo(RegOpt);
	}
}

void Annotator::annotateNamespace(LexContext *ctx, const string &data, Token *tk, size_t idx, TokenInfo *info)
{
	Token *next_tk = ctx->tmgr->nextToken(idx);
	if (next_tk && next_tk->_data[0] == ':' && next_tk->_data[1] == ':' &&
		next_tk->info.type != String && next_tk->info.type != RawString) {
		char data_front = tk->_data[0];
		if (data_front == '$' || data_front == '@' || data_front == '%') {
			annotateLocalVariable(ctx, data, tk, idx, info);
			if (info->type != Undefined) return;
			annotateVariable(ctx, data, tk, idx, info);
			if (info->type != Undefined) return;
			annotateGlobalVariable(ctx, data, tk, idx, info);
			if (info->type != Undefined) return;
		} else if (data_front > 0 && !isalnum(data_front) && data_front != '_') {
			return;
		}
		*info = ctx->tmgr->getTokenInfo(Namespace);
	} else if (ctx->prev_type == NamespaceResolver) {
		TokenInfo tk_info = ctx->tmgr->getTokenInfo(tk->_data);
		if (tk_info.kind == TokenKind::Symbol) return;
		*info = ctx->tmgr->getTokenInfo(Namespace);
	}
}

void Annotator::annotateMethod(LexContext *ctx, const string &, Token *tk, size_t, TokenInfo *info)
{
	if (ctx->prev_type == Pointer && (isalpha(tk->_data[0]) || tk->_data[0] == '_')) {
		*info = ctx->tmgr->getTokenInfo(Method);
	}
}

void Annotator::annotateKey(LexContext *ctx, const string &, Token *tk, size_t idx, TokenInfo *info)
{
	Token *prev_before_tk = ctx->tmgr->beforePreviousToken(idx);
	TokenType::Type prev_before_type = (prev_before_tk) ? prev_before_tk->info.type : Undefined;
	Token *next_tk = ctx->tmgr->nextToken(idx);
	if (prev_before_type != Function &&
		ctx->prev_type == LeftBrace && next_tk &&
		(isalpha(tk->_data[0]) || tk->_data[0] == '_') &&
		next_tk->_data[0] == '}') {
		*info = ctx->tmgr->getTokenInfo(Key);
	} else if (next_tk &&
			   (isalpha(tk->_data[0]) || tk->_data[0] == '_') &&
			   (next_tk->_data[0] == '=' && next_tk->_data[1] == '>')) {
		*info = ctx->tmgr->getTokenInfo(Key);
	} else if (ctx->prev_type == ArraySize && (isalpha(tk->_data[0]) || tk->_data[0] == '_')) {
		*info = ctx->tmgr->getTokenInfo(Key);
	}
}

void Annotator::annotateShortScalarDereference(LexContext *ctx, const string &, Token *tk, size_t idx, TokenInfo *info)
{
	Token *next_tk = ctx->tmgr->nextToken(idx);
	if (next_tk && (tk->_data[0] == '$' && tk->_data[1] == '$') &&
		(isalpha(next_tk->_data[0]) || next_tk->_data[0] == '_')) {
		*info = ctx->tmgr->getTokenInfo(ShortScalarDereference);
	}
}

void Annotator::annotateCallDecl(LexContext *ctx, const string &, Token *tk, size_t idx, TokenInfo *info)
{
	Token *prev_tk = ctx->tmgr->previousToken(idx);
	if (prev_tk && prev_tk->info.type == TokenType::Ref && tk->_data[0] == '&') {
		*info = ctx->tmgr->getTokenInfo(CallDecl);
	} else if (tk->_data[0] == '&') {
		*info = ctx->tmgr->getTokenInfo(BitAnd);
	}
}

void Annotator::annotateHandleDelimiter(LexContext *ctx, const string &, Token *tk, size_t idx, TokenInfo *info)
{
	if (tk->_data[0] != '<') return;
	Token *prev_tk = ctx->tmgr->previousToken(idx);
	TokenKind::Kind prev_kind = (prev_tk) ? prev_tk->info.kind : TokenKind::Undefined;
	TokenType::Type prev_type = (prev_tk) ? prev_tk->info.type : TokenType::Undefined;
	if (prev_type == SemiColon || prev_type == LeftParenthesis || prev_type == Comma ||
		prev_kind == TokenKind::Assign ||
		(prev_type != Inc && prev_type != Dec && prev_kind == TokenKind::Operator) ||
		prev_kind == TokenKind::Decl) {
		*info = ctx->tmgr->getTokenInfo(HandleDelim);
		Token *handle_end_delimiter = ctx->tmgr->getTokenByBase(idx, 2);
		if (handle_end_delimiter && handle_end_delimiter->_data[0] == '>') {
			handle_end_delimiter->info = ctx->tmgr->getTokenInfo(HandleDelim);
		}
	}
}

void Annotator::annotateReservedKeyword(LexContext *ctx, const string &, Token *tk, size_t idx, TokenInfo *info)
{
	TokenInfo reserved_info = ctx->tmgr->getTokenInfo(tk->_data);

	TokenManager *tmgr = ctx->tmgr;
	Token *prev_tk = tmgr->previousToken(idx);
	if (reserved_info.type == IfStmt && prev_tk && prev_tk->info.type == UseDecl) {
		// For `if` statement which is used at `use` declaration.
		// It should be treated as a `UsedName` instead of `IfStmt`.
		// e.g.
		//     use if $] < 5.009_005, 'MRO::Compat';
		*info = tmgr->getTokenInfo(UsedName);
		return;
	}

	if (reserved_info.type != TokenType::Undefined && ctx->prev_type != FunctionDecl) {
		switch (ctx->prev_type) {
		/* ${m} or @{m} or %{m} or &{m} or $#{m} */
		case ArrayDereference:
		case HashDereference:
		case ScalarDereference:
		case CodeDereference:
		case ArraySizeDereference:
			*info = tmgr->getTokenInfo(Key);
			break;
		case HandleDelim: {
			/* <m> or <tr> */
			Token *next_tk = ctx->tmgr->nextToken(idx);
			if (next_tk && next_tk->info.type == HandleDelim &&
				(reserved_info.type == RegMatch || reserved_info.type == RegAllReplace)) {
				*info = tmgr->getTokenInfo(Key);
				break;
			}
			/* fallthrough */
		}
		default:
			*info = reserved_info;
			break;
		}
	}
}

void Annotator::annotateGlobOrMul(LexContext *ctx, const string &, Token *tk, size_t idx, TokenInfo *info)
{
	if (tk->_data[0] != '*') return;
	Token *prev_tk = ctx->tmgr->previousToken(idx);
	TokenType::Type prev_type = (prev_tk) ? prev_tk->info.type : TokenType::Undefined;
	TokenKind::Kind prev_kind = (prev_tk) ? prev_tk->info.kind : TokenKind::Undefined;
	Token *next_tk = ctx->tmgr->nextToken(idx);

	if ((next_tk && next_tk->_data[0] == '=') ||
		prev_type == SemiColon || prev_type == LeftParenthesis ||
		prev_type == LeftBrace || prev_type == Comma ||
		prev_type == ScalarDereference ||
		prev_kind == TokenKind::Assign ||
		(prev_type != Inc && prev_type != Dec && prev_kind == TokenKind::Operator) ||
		prev_kind == TokenKind::Decl) {
		*info = ctx->tmgr->getTokenInfo(Glob);
	} else {
		*info = ctx->tmgr->getTokenInfo(Mul);
	}
}

void Annotator::annotateNamelessFunction(LexContext *ctx, const string &, Token *tk, size_t, TokenInfo *info)
{
	if (ctx->prev_type == FunctionDecl && tk->_data[0] == '{') {
		*info = ctx->tmgr->getTokenInfo(tk->_data);
	}
}

void Annotator::annotateLocalVariable(LexContext *ctx, const string &data, Token *, size_t, TokenInfo *info)
{
	if (ctx->prev_type == VarDecl && data.find("$") != string::npos) {
		*info = ctx->tmgr->getTokenInfo(LocalVar);
		vardecl_map.insert(StringMap::value_type(data, ""));
	} else if (ctx->prev_type == VarDecl && data.find("@") != string::npos) {
		*info = ctx->tmgr->getTokenInfo(LocalArrayVar);
		vardecl_map.insert(StringMap::value_type(data, ""));
	} else if (ctx->prev_type == VarDecl && data.find("%") != string::npos) {
		*info = ctx->tmgr->getTokenInfo(LocalHashVar);
		vardecl_map.insert(StringMap::value_type(data, ""));
	}
}

void Annotator::annotateVariable(LexContext *ctx, const string &data, Token *, size_t, TokenInfo *info)
{
	if (vardecl_map.find(data) == vardecl_map.end()) return;
	if (data.find("@") != string::npos) {
		*info = ctx->tmgr->getTokenInfo(ArrayVar);
	} else if (data.find("%") != string::npos) {
		*info = ctx->tmgr->getTokenInfo(HashVar);
	} else {
		*info = ctx->tmgr->getTokenInfo(Var);
	}
}

void Annotator::annotateGlobalVariable(LexContext *ctx, const string &data, Token *, size_t, TokenInfo *info)
{
	if (data.find("$") != string::npos) {
		*info = ctx->tmgr->getTokenInfo(GlobalVar);
		vardecl_map.insert(StringMap::value_type(data, ""));
	} else if (data.find("@") != string::npos) {
		*info = ctx->tmgr->getTokenInfo(GlobalArrayVar);
		vardecl_map.insert(StringMap::value_type(data, ""));
	} else if (data.find("%") != string::npos) {
		*info = ctx->tmgr->getTokenInfo(GlobalHashVar);
		vardecl_map.insert(StringMap::value_type(data, ""));
	}
}

void Annotator::annotateFunction(LexContext *ctx, const string &data, Token *, size_t, TokenInfo *info)
{
	if (ctx->prev_type == FunctionDecl) {
		*info = ctx->tmgr->getTokenInfo(Function);
		funcdecl_map.insert(StringMap::value_type(data, ""));
	}
}

void Annotator::annotateCall(LexContext *ctx, const string &data, Token *, size_t, TokenInfo *info)
{
	if (funcdecl_map.find(data) != funcdecl_map.end()) {
		*info = ctx->tmgr->getTokenInfo(Call);
	}
}

void Annotator::annotateClass(LexContext *ctx, const string &data, Token *, size_t, TokenInfo *info)
{
	if (ctx->prev_type == Package) {
		*info = ctx->tmgr->getTokenInfo(Class);
		pkgdecl_map.insert(StringMap::value_type(data, ""));
	} else if (pkgdecl_map.find(data) != pkgdecl_map.end()) {
		*info = ctx->tmgr->getTokenInfo(Class);
	}
}

void Annotator::annotateModuleName(LexContext *ctx, const string &, Token *, size_t, TokenInfo *info)
{
	if (ctx->prev_type == UseDecl) {
		*info = ctx->tmgr->getTokenInfo(UsedName);
	} else if (ctx->prev_type == RequireDecl) {
		*info = ctx->tmgr->getTokenInfo(RequiredName);
	}
}

void Annotator::annotateBareWord(LexContext *ctx, const string &, Token *, size_t, TokenInfo *info)
{
	*info = ctx->tmgr->getTokenInfo(Key);//BareWord);
	info->has_warnings = true;
}
