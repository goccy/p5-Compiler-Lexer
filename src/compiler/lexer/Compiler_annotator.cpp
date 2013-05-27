#include <lexer.hpp>

namespace TokenType = Enum::Token::Type;
using namespace TokenType;
using namespace std;

Annotator::Annotator(void)
{
}

#define ANNOTATE(method, info) do {				\
		method(ctx, tk, &info);					\
		if (info.type != Undefined) {			\
			tk->info = info;					\
			ctx->prev_type = info.type;			\
			return;								\
		}										\
	} while (0)

void Annotator::annotate(LexContext *ctx, Token *tk)
{
	if (tk->info.type != Undefined) {
		ctx->prev_type = tk->info.type;
		return;
	}
	TokenInfo info;
	info.type = Undefined;
	ANNOTATE(annotateRegOpt, info);
	ANNOTATE(annotateNamespace, info);
	ANNOTATE(annotateMethod, info);
	ANNOTATE(annotateKey, info);
	ANNOTATE(annotateShortScalarDereference, info);
	ANNOTATE(annotateReservedKeyword, info);
	ANNOTATE(annotateNamelessFunction, info);
	ANNOTATE(annotateLocalVariable, info);
	ANNOTATE(annotateVariable, info);
	ANNOTATE(annotateGlobalVariable, info);
	ANNOTATE(annotateFunction, info);
	ANNOTATE(annotateCall, info);
	ANNOTATE(annotateClass, info);
	ANNOTATE(annotateModuleName, info);
	ANNOTATE(annotateBareWord, info);
}

void Annotator::annotateRegOpt(LexContext *ctx, Token *tk, TokenInfo *info)
{
	string data = tk->data;
	if (ctx->prev_type == RegDelim && isalpha(data[0]) &&
		data != "if"      && data != "while" &&
		data != "foreach" && data != "for") {
		//(data == "g" || data == "m" || data == "s" || data == "x")) {
		*info = ctx->tmgr->getTokenInfo(RegOpt);
	}
}

void Annotator::annotateNamespace(LexContext *ctx, Token *tk, TokenInfo *info)
{
	Token *next_tk = ctx->tmgr->nextToken();
	if (next_tk && next_tk->data == "::" &&
		next_tk->info.type != String && next_tk->info.type != RawString) {
		*info = ctx->tmgr->getTokenInfo(Namespace);
	} else if (ctx->prev_type == NamespaceResolver) {
		*info = ctx->tmgr->getTokenInfo(Namespace);
	}
}

void Annotator::annotateMethod(LexContext *ctx, Token *tk, TokenInfo *info)
{
	string data = tk->data;
	if (ctx->prev_type == Pointer && isalpha(data[0])) {
		*info = ctx->tmgr->getTokenInfo(Method);
	}
}

void Annotator::annotateKey(LexContext *ctx, Token *tk, TokenInfo *info)
{
	Token *next_tk = ctx->tmgr->nextToken();
	string data = tk->data;
	if (ctx->prev_type == LeftBrace && next_tk &&
		(isalpha(data[0]) || data[0] == '_') &&
		next_tk->data == "}") {
		*info = ctx->tmgr->getTokenInfo(Key);
	} else if (next_tk &&
			   (isalpha(data[0]) || data[0] == '_') &&
			   next_tk->data == "=>") {
		*info = ctx->tmgr->getTokenInfo(Key);
	}
}

void Annotator::annotateShortScalarDereference(LexContext *ctx, Token *tk, TokenInfo *info)
{
	Token *next_tk = ctx->tmgr->nextToken();
	string data = tk->data;
	if (next_tk && data == "$$" &&
		(isalpha(next_tk->data[0]) || next_tk->data[0] == '_')) {
		*info = ctx->tmgr->getTokenInfo(ShortScalarDereference);
	}
}

void Annotator::annotateReservedKeyword(LexContext *ctx, Token *tk, TokenInfo *info)
{
	string data = tk->data;
	TokenInfo reserved_info = ctx->tmgr->getTokenInfo(data.c_str());
	if (reserved_info.type != TokenType::Undefined && ctx->prev_type != FunctionDecl) {
		*info = reserved_info;
	}
}

void Annotator::annotateNamelessFunction(LexContext *ctx, Token *tk, TokenInfo *info)
{
	string data = tk->data;
	if (ctx->prev_type == FunctionDecl && data == "{") {
		*info = ctx->tmgr->getTokenInfo(cstr(data));
	}
}

void Annotator::annotateLocalVariable(LexContext *ctx, Token *tk, TokenInfo *info)
{
	string data = tk->data;
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

void Annotator::annotateVariable(LexContext *ctx, Token *tk, TokenInfo *info)
{
	string data = tk->data;
	if (vardecl_map.find(data) == vardecl_map.end()) return;
	if (data.find("@") != string::npos) {
		*info = ctx->tmgr->getTokenInfo(ArrayVar);
	} else if (data.find("%") != string::npos) {
		*info = ctx->tmgr->getTokenInfo(HashVar);
	} else {
		*info = ctx->tmgr->getTokenInfo(Var);
	}
}

void Annotator::annotateGlobalVariable(LexContext *ctx, Token *tk, TokenInfo *info)
{
	string data = tk->data;
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

void Annotator::annotateFunction(LexContext *ctx, Token *tk, TokenInfo *info)
{
	string data = tk->data;
	if (ctx->prev_type == FunctionDecl) {
		*info = ctx->tmgr->getTokenInfo(Function);
		funcdecl_map.insert(StringMap::value_type(data, ""));
	}
}

void Annotator::annotateCall(LexContext *ctx, Token *tk, TokenInfo *info)
{
	string data = tk->data;
	if (funcdecl_map.find(data) != funcdecl_map.end()) {
		*info = ctx->tmgr->getTokenInfo(Call);
	}
}

void Annotator::annotateClass(LexContext *ctx, Token *tk, TokenInfo *info)
{
	string data = tk->data;
	if (ctx->prev_type == Package) {
		*info = ctx->tmgr->getTokenInfo(Class);
		pkgdecl_map.insert(StringMap::value_type(data, ""));
	} else if (pkgdecl_map.find(data) != pkgdecl_map.end()) {
		*info = ctx->tmgr->getTokenInfo(Class);
	}
}

void Annotator::annotateModuleName(LexContext *ctx, Token *, TokenInfo *info)
{
	if (ctx->prev_type == UseDecl) {
		*info = ctx->tmgr->getTokenInfo(UsedName);
	} else if (ctx->prev_type == RequireDecl) {
		*info = ctx->tmgr->getTokenInfo(RequiredName);
	}
}

void Annotator::annotateBareWord(LexContext *ctx, Token *, TokenInfo *info)
{
	*info = ctx->tmgr->getTokenInfo(Key);//BareWord);
	info->has_warnings = true;
}
