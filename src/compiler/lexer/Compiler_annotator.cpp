#include <lexer.hpp>

namespace TokenType = Enum::Token::Type;
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
	methods->add(&Annotator::annotateNamespace);
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
	methods->add(&Annotator::annotateModuleName);
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
	vector<AnnotateMethod>::iterator end = methods->end();
	for (; itr != end; itr++) {
		AnnotateMethod method = *itr;
		info = (this->*method)(ctx, tk);
		if (info.type != Undefined) break;
	}
	tk->info = info;
	ctx->prev_type = info.type;
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
	TokenInfo ret = ctx->tmgr->getTokenInfo(Undefined);
	string data = tk->data;
	if (ctx->prev_type == RegDelim && isalpha(data[0]) &&
		data != "if"      && data != "while" &&
		data != "foreach" && data != "for") {
		//(data == "g" || data == "m" || data == "s" || data == "x")) {
		ret = ctx->tmgr->getTokenInfo(RegOpt);
	}
	return ret;
}

TokenInfo Annotator::annotateNamespace(LexContext *ctx, Token *tk)
{
	TokenInfo ret = ctx->tmgr->getTokenInfo(Undefined);
	Token *next_tk = ctx->tmgr->nextToken();
	string data = tk->data;
	if (next_tk && next_tk->data == "::" &&
		next_tk->info.type != String && next_tk->info.type != RawString) {
		ret = ctx->tmgr->getTokenInfo(Namespace);
	} else if (ctx->prev_type == NamespaceResolver) {
		ret = ctx->tmgr->getTokenInfo(Namespace);
	}
	return ret;
}

TokenInfo Annotator::annotateMethod(LexContext *ctx, Token *tk)
{
	TokenInfo ret = ctx->tmgr->getTokenInfo(Undefined);
	string data = tk->data;
	if (ctx->prev_type == Pointer && isalpha(data[0])) {
		ret = ctx->tmgr->getTokenInfo(Method);
	}
	return ret;
}

TokenInfo Annotator::annotateKey(LexContext *ctx, Token *tk)
{
	TokenInfo ret = ctx->tmgr->getTokenInfo(Undefined);
	Token *next_tk = ctx->tmgr->nextToken();
	string data = tk->data;
	if (ctx->prev_type == LeftBrace && next_tk &&
		(isalpha(data[0]) || data[0] == '_') &&
		next_tk->data == "}") {
		ret = ctx->tmgr->getTokenInfo(Key);
	} else if (next_tk &&
			   (isalpha(data[0]) || data[0] == '_') &&
			   next_tk->data == "=>") {
		ret = ctx->tmgr->getTokenInfo(Key);
	}
	return ret;
}

TokenInfo Annotator::annotateShortScalarDereference(LexContext *ctx, Token *tk)
{
	TokenInfo ret = ctx->tmgr->getTokenInfo(Undefined);
	Token *next_tk = ctx->tmgr->nextToken();
	string data = tk->data;
	if (next_tk && data == "$$" &&
		(isalpha(next_tk->data[0]) || next_tk->data[0] == '_')) {
		ret = ctx->tmgr->getTokenInfo(ShortScalarDereference);
	}
	return ret;
}

bool Annotator::isReservedKeyword(LexContext *ctx, string word)
{
	TokenInfo info = ctx->tmgr->getTokenInfo(word.c_str());
	return (info.type != TokenType::Undefined) ? true : false;
}

TokenInfo Annotator::annotateReservedKeyword(LexContext *ctx, Token *tk)
{
	TokenInfo ret = ctx->tmgr->getTokenInfo(Undefined);
	string data = tk->data;
	if (isReservedKeyword(ctx, data) && ctx->prev_type != FunctionDecl) {
		ret = ctx->tmgr->getTokenInfo(cstr(data));
	}
	return ret;
}

TokenInfo Annotator::annotateNamelessFunction(LexContext *ctx, Token *tk)
{
	TokenInfo ret = ctx->tmgr->getTokenInfo(Undefined);
	string data = tk->data;
	if (ctx->prev_type == FunctionDecl && data == "{") {
		ret = ctx->tmgr->getTokenInfo(cstr(data));
	}
	return ret;
}

TokenInfo Annotator::annotateLocalVariable(LexContext *ctx, Token *tk)
{
	TokenInfo ret = ctx->tmgr->getTokenInfo(Undefined);
	string data = tk->data;
	if (ctx->prev_type == VarDecl && data.find("$") != string::npos) {
		ret = ctx->tmgr->getTokenInfo(LocalVar);
		vardecl_list.push_back(data);
	} else if (ctx->prev_type == VarDecl && data.find("@") != string::npos) {
		ret = ctx->tmgr->getTokenInfo(LocalArrayVar);
		vardecl_list.push_back(data);
	} else if (ctx->prev_type == VarDecl && data.find("%") != string::npos) {
		ret = ctx->tmgr->getTokenInfo(LocalHashVar);
		vardecl_list.push_back(data);
	}
	return ret;
}

TokenInfo Annotator::annotateVariable(LexContext *ctx, Token *tk)
{
	TokenInfo ret = ctx->tmgr->getTokenInfo(Undefined);
	string data = tk->data;
	if (!search(vardecl_list, data)) return ret;
	if (data.find("@") != string::npos) {
		ret = ctx->tmgr->getTokenInfo(ArrayVar);
	} else if (data.find("%") != string::npos) {
		ret = ctx->tmgr->getTokenInfo(HashVar);
	} else {
		ret = ctx->tmgr->getTokenInfo(Var);
	}
	return ret;
}

TokenInfo Annotator::annotateGlobalVariable(LexContext *ctx, Token *tk)
{
	TokenInfo ret = ctx->tmgr->getTokenInfo(Undefined);
	string data = tk->data;
	if (data.find("$") != string::npos) {
		ret = ctx->tmgr->getTokenInfo(GlobalVar);
		vardecl_list.push_back(data);
	} else if (data.find("@") != string::npos) {
		ret = ctx->tmgr->getTokenInfo(GlobalArrayVar);
		vardecl_list.push_back(data);
	} else if (data.find("%") != string::npos) {
		ret = ctx->tmgr->getTokenInfo(GlobalHashVar);
		vardecl_list.push_back(data);
	}
	return ret;
}

TokenInfo Annotator::annotateFunction(LexContext *ctx, Token *tk)
{
	TokenInfo ret = ctx->tmgr->getTokenInfo(Undefined);
	string data = tk->data;
	if (ctx->prev_type == FunctionDecl) {
		ret = ctx->tmgr->getTokenInfo(Function);
		funcdecl_list.push_back(data);
	}
	return ret;
}

TokenInfo Annotator::annotateCall(LexContext *ctx, Token *tk)
{
	TokenInfo ret = ctx->tmgr->getTokenInfo(Undefined);
	string data = tk->data;
	if (search(funcdecl_list, data)) {
		ret = ctx->tmgr->getTokenInfo(Call);
	}
	return ret;
}

TokenInfo Annotator::annotateClass(LexContext *ctx, Token *tk)
{
	TokenInfo ret = ctx->tmgr->getTokenInfo(Undefined);
	string data = tk->data;
	if (ctx->prev_type == Package) {
		ret = ctx->tmgr->getTokenInfo(Class);
		pkgdecl_list.push_back(data);
	} else if (search(pkgdecl_list, data)) {
		ret = ctx->tmgr->getTokenInfo(Class);
	}
	return ret;
}

TokenInfo Annotator::annotateModuleName(LexContext *ctx, Token *)
{
	TokenInfo ret = ctx->tmgr->getTokenInfo(Undefined);
	if (ctx->prev_type == UseDecl) {
		ret = ctx->tmgr->getTokenInfo(UsedName);
	} else if (ctx->prev_type == RequireDecl) {
		ret = ctx->tmgr->getTokenInfo(RequiredName);
	}
	return ret;
}

TokenInfo Annotator::annotateBareWord(LexContext *ctx, Token *)
{
	TokenInfo ret = ctx->tmgr->getTokenInfo(Key);//BareWord);
	ret.has_warnings = true;
	return ret;
}
