#include <lexer.hpp>

namespace TokenType = Enum::Lexer::Token;
using namespace TokenType;
using namespace std;

AnnotateMethods::AnnotateMethods(void){}
void AnnotateMethods::add(AnnotateMethod method){ push_back(method); }
void AnnotateMethods::setAnnotator(Annotator *executor){ this->executor = executor; }

Annotator::Annotator(void)
{
	methods = new AnnotateMethods();
	setAnnotateMethods(methods);
}

void Annotator::setAnnotateMethods(AnnotateMethods *methods)
{
	/* annotate order is important */
	methods->add(&Annotator::annotateRegOpt);
	methods->add(&Annotator::annotateMethod);
	methods->add(&Annotator::annotateKey);
	methods->add(&Annotator::annotateShortScalarDereference);
	methods->add(&Annotator::annotateReservedKeyword);
	methods->add(&Annotator::annotateNamelessFunction);
	methods->add(&Annotator::annotateLocalVariable);
	methods->add(&Annotator::annotateVariable);
	methods->add(&Annotator::annotateGlobalVariable);
	methods->add(&Annotator::annotateFunction);
	methods->add(&Annotator::annotateCall);
	methods->add(&Annotator::annotateClass);
	methods->add(&Annotator::annotateUsedName);
	methods->add(&Annotator::annotateBareWord);
	methods->setAnnotator(this);
}

void Annotator::annotate(LexContext *ctx, Token *tk)
{
	if (tk->info.type != Undefined) {
		ctx->prev_type = tk->info.type;
		return;
	}
	TokenInfo info;
	vector<AnnotateMethod>::iterator itr = methods->begin();
	for (; itr != methods->end(); itr++) {
		AnnotateMethod method = *itr;
		info = (this->*method)(ctx, tk);
		if (info.type != Undefined) break;
	}
	tk->info = info;
	ctx->prev_type = info.type;
}

TokenInfo Annotator::getTokenInfo(TokenType::Type type)
{
	size_t i = 0;
	for (; decl_tokens[i].type != TokenType::Undefined; i++) {
		if (type == decl_tokens[i].type) {
			return decl_tokens[i];
		}
	}
	return decl_tokens[i];
}

TokenInfo Annotator::getTokenInfo(const char *data)
{
	size_t i = 0;
	size_t dsize = strlen(data);
	for (; decl_tokens[i].type != TokenType::Undefined; i++) {
		const char *token_data = decl_tokens[i].data;
		size_t tsize = strlen(token_data);
		if (dsize == tsize && !strncmp(token_data, data, dsize)) {
			return decl_tokens[i];
		}
	}
	return decl_tokens[i];
}

bool Annotator::search(vector<string> list, string target)
{
	bool ret = false;
	vector<string>::iterator it = find(list.begin(), list.end(), target);
	if (it != list.end()){
		ret = true;
	}
	return ret;
}

TokenInfo Annotator::annotateRegOpt(LexContext *ctx, Token *tk)
{
	TokenInfo ret = getTokenInfo(Undefined);
	string data = tk->data;
	if (ctx->prev_type == RegDelim && isalpha(data[0]) &&
		data != "if"      && data != "while" &&
		data != "foreach" && data != "for") {
		//(data == "g" || data == "m" || data == "s" || data == "x")) {
		ret = getTokenInfo(RegOpt);
	}
	return ret;
}

TokenInfo Annotator::annotateNamespace(LexContext *ctx, Token *tk)
{
	TokenInfo ret = getTokenInfo(Undefined);
	Token *next_tk = ctx->nextToken();
	string data = tk->data;
	if (!ctx->end() && next_tk->data == "::" &&
		next_tk->info.type != String && next_tk->info.type != RawString) {
		ret = getTokenInfo(Namespace);
	} else if (ctx->prev_type == NamespaceResolver) {
		ret = getTokenInfo(Namespace);
	}
	return ret;
}

TokenInfo Annotator::annotateMethod(LexContext *ctx, Token *tk)
{
	TokenInfo ret = getTokenInfo(Undefined);
	string data = tk->data;
	if (ctx->prev_type == Pointer && isalpha(data[0])) {
		ret = getTokenInfo(Method);
	}
	return ret;
}

TokenInfo Annotator::annotateKey(LexContext *ctx, Token *tk)
{
	TokenInfo ret = getTokenInfo(Undefined);
	Token *next_tk = ctx->nextToken();
	string data = tk->data;
	if (ctx->prev_type == LeftBrace && !ctx->end() &&
		(isalpha(data[0]) || data[0] == '_') &&
		next_tk->data == "}") {
		ret = getTokenInfo(Key);
	} else if (!ctx->end() &&
			   (isalpha(data[0]) || data[0] == '_') &&
			   next_tk->data == "=>") {
		ret = getTokenInfo(Key);
	}
	return ret;
}

TokenInfo Annotator::annotateShortScalarDereference(LexContext *ctx, Token *tk)
{
	TokenInfo ret = getTokenInfo(Undefined);
	Token *next_tk = ctx->nextToken();
	string data = tk->data;
	if (!ctx->end() && data == "$$" &&
		(isalpha(next_tk->data[0]) || next_tk->data[0] == '_')) {
		ret = getTokenInfo(ShortScalarDereference);
	}
	return ret;
}

bool Annotator::isReservedKeyword(string word)
{
	for (int i = 0; decl_tokens[i].type != Undefined; i++) {
		if (word == decl_tokens[i].data) {
			return true;
		}
	}
	return false;
}

TokenInfo Annotator::annotateReservedKeyword(LexContext *ctx, Token *tk)
{
	TokenInfo ret = getTokenInfo(Undefined);
	string data = tk->data;
	if (isReservedKeyword(data) && ctx->prev_type != FunctionDecl) {
		ret = getTokenInfo(cstr(data));
	}
	return ret;
}

TokenInfo Annotator::annotateNamelessFunction(LexContext *ctx, Token *tk)
{
	TokenInfo ret = getTokenInfo(Undefined);
	string data = tk->data;
	if (ctx->prev_type == FunctionDecl && data == "{") {
		ret = getTokenInfo(cstr(data));
	}
	return ret;
}

TokenInfo Annotator::annotateLocalVariable(LexContext *ctx, Token *tk)
{
	TokenInfo ret = getTokenInfo(Undefined);
	string data = tk->data;
	if (ctx->prev_type == VarDecl && data.find("$") != string::npos) {
		ret = getTokenInfo(LocalVar);
		vardecl_list.push_back(data);
	} else if (ctx->prev_type == VarDecl && data.find("@") != string::npos) {
		ret = getTokenInfo(LocalArrayVar);
		vardecl_list.push_back(data);
	} else if (ctx->prev_type == VarDecl && data.find("%") != string::npos) {
		ret = getTokenInfo(LocalHashVar);
		vardecl_list.push_back(data);
	}
	return ret;
}

TokenInfo Annotator::annotateVariable(LexContext *, Token *tk)
{
	TokenInfo ret = getTokenInfo(Undefined);
	string data = tk->data;
	if (!search(vardecl_list, data)) return ret;
	if (data.find("@") != string::npos) {
		ret = getTokenInfo(ArrayVar);
	} else if (data.find("%") != string::npos) {
		ret = getTokenInfo(HashVar);
	} else {
		ret = getTokenInfo(Var);
	}
	return ret;
}

TokenInfo Annotator::annotateGlobalVariable(LexContext *, Token *tk)
{
	TokenInfo ret = getTokenInfo(Undefined);
	string data = tk->data;
	if (data.find("$") != string::npos) {
		ret = getTokenInfo(GlobalVar);
		vardecl_list.push_back(data);
	} else if (data.find("@") != string::npos) {
		ret = getTokenInfo(GlobalArrayVar);
		vardecl_list.push_back(data);
	} else if (data.find("%") != string::npos) {
		ret = getTokenInfo(GlobalHashVar);
		vardecl_list.push_back(data);
	}
	return ret;
}

TokenInfo Annotator::annotateFunction(LexContext *ctx, Token *tk)
{
	TokenInfo ret = getTokenInfo(Undefined);
	string data = tk->data;
	if (ctx->prev_type == FunctionDecl) {
		ret = getTokenInfo(Function);
		funcdecl_list.push_back(data);
	}
	return ret;
}

TokenInfo Annotator::annotateCall(LexContext *, Token *tk)
{
	TokenInfo ret = getTokenInfo(Undefined);
	string data = tk->data;
	if (search(funcdecl_list, data)) {
		ret = getTokenInfo(Call);
	}
	return ret;
}

TokenInfo Annotator::annotateClass(LexContext *ctx, Token *tk)
{
	TokenInfo ret = getTokenInfo(Undefined);
	string data = tk->data;
	if (ctx->prev_type == Package) {
		ret = getTokenInfo(Class);
		pkgdecl_list.push_back(data);
	} else if (search(pkgdecl_list, data)) {
		ret = getTokenInfo(Class);
	}
	return ret;
}

TokenInfo Annotator::annotateUsedName(LexContext *ctx, Token *)
{
	TokenInfo ret = getTokenInfo(Undefined);
	if (ctx->prev_type == UseDecl) {
		ret = getTokenInfo(UsedName);
	}
	return ret;
}

TokenInfo Annotator::annotateBareWord(LexContext *, Token *)
{
	TokenInfo ret = getTokenInfo(Key);//BareWord);
	ret.has_warnings = true;
	return ret;
}
