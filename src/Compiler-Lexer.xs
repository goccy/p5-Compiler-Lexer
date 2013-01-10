#include <lexer.hpp>
#ifdef __cplusplus
extern "C" {
#endif
#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#define new_Array() (AV*)sv_2mortal((SV*)newAV())
#define new_Hash() (HV*)sv_2mortal((SV*)newHV())
#define new_String(s, len) sv_2mortal(newSVpv(s, len))
#define new_Int(u) sv_2mortal(newSVuv(u))
#define new_Ref(sv) sv_2mortal(newRV_inc((SV*)sv))
#define set(e) SvREFCNT_inc(e)
#define get_value(hash, key) *hv_fetchs(hash, key, strlen(key))
#ifdef __cplusplus
};
#endif
typedef Lexer * Compiler_Lexer;

MODULE = Compiler::Lexer PACKAGE = Compiler::Lexer
PROTOTYPES: DISABLE

Compiler_Lexer
new(classname, filename)
	char *classname
	const char *filename
CODE:
{
	Lexer *lexer = new Lexer(filename);
	RETVAL = lexer;
}
OUTPUT:
	RETVAL

AV *
tokenize(self, script)
	Compiler_Lexer self
	const char *script
CODE:
{
	Tokens *tokens = self->tokenize((char *)script);
	self->annotateTokens(tokens);
	AV* ret  = new_Array();
	for (size_t i = 0; i < tokens->size(); i++) {
		Token *token = tokens->at(i);
		HV *hash = (HV*)new_Hash();
		hv_stores(hash, "stype", set(new_Int(token->stype)));
		hv_stores(hash, "type", set(new_Int(token->info.type)));
		hv_stores(hash, "kind", set(new_Int(token->info.kind)));
		hv_stores(hash, "line", set(new_Int(token->finfo.start_line_num)));
		hv_stores(hash, "name", set(new_String(token->info.name, strlen(token->info.name))));
		hv_stores(hash, "data", set(new_String(token->data.c_str(), strlen(token->data.c_str()))));
		HV *stash = (HV *)gv_stashpv("Compiler::Lexer::Token", sizeof("Compiler::Lexer::Token") + 1);
		av_push(ret, set(sv_bless(new_Ref(hash), stash)));
	}
    RETVAL = (AV *)new_Ref(ret);
}
OUTPUT:
RETVAL

AV *
get_groups_by_syntax_level(self, tokens_, syntax_level)
	Compiler_Lexer self
	AV *tokens_
	int syntax_level
CODE:
{
	SV **tokens = tokens_->sv_u.svu_array;
	size_t tokens_size = av_len(tokens_);
	Tokens tks;
	for (size_t i = 0; i <= tokens_size; i++) {
		HV *token = (HV *)SvRV(tokens[i]);
		const char *name = SvPVX(get_value(token, "name"));
		const char *data = SvPVX(get_value(token, "data"));
		int line = SvIVX(get_value(token, "line"));
		Enum::Lexer::Token::Type type = (Enum::Lexer::Token::Type)SvIVX(get_value(token, "type"));
		Enum::Lexer::Kind kind = (Enum::Lexer::Kind)SvIVX(get_value(token, "kind"));
		FileInfo finfo;
		finfo.start_line_num = line;
		finfo.end_line_num = line;
		finfo.filename = self->finfo.filename;
		TokenInfo info;
		info.type = type;
		info.kind = kind;
		info.name = name;
		info.data = data;
		Token *tk = new Token(std::string(data), finfo);
		tk->info = info;
		tk->type = type;
		tks.push_back(tk);
	}
	self->grouping(&tks);
	self->prepare(&tks);
	Token *root = self->parseSyntax(NULL, &tks);
	self->parseSpecificStmt(root);
	//self->dumpSyntax(root, 0);
	self->setIndent(root, NULL);
	size_t block_id = 0;
	self->setBlockIDWithDepthFirst(root, &block_id);
	Tokens *stmts = self->getTokensBySyntaxLevel(root, (Enum::Lexer::Syntax::Type)syntax_level);
	AV* ret  = new_Array();
	for (size_t i = 0; i < stmts->size(); i++) {
		Token *stmt = stmts->at(i);
		const char *src = stmt->deparse();
		size_t len = strlen(src);
		HV *hash = (HV*)new_Hash();
		hv_stores(hash, "src", set(new_String(src, len)));
		hv_stores(hash, "token_num", set(new_Int(stmt->total_token_num)));
		hv_stores(hash, "indent", set(new_Int(stmt->finfo.indent)));
		hv_stores(hash, "block_id", set(new_Int(stmt->finfo.block_id)));
		hv_stores(hash, "start_line", set(new_Int(stmt->finfo.start_line_num)));
		hv_stores(hash, "end_line", set(new_Int(stmt->finfo.end_line_num)));
		av_push(ret, set(new_Ref(hash)));
	}
	RETVAL = (AV *)new_Ref(ret);
}
OUTPUT:
	RETVAL

AV *
get_used_modules(self, script)
   Compiler_Lexer self
   const char *script
CODE:
{
	Tokens *tokens = self->tokenize((char *)script);
	self->annotateTokens(tokens);
	self->grouping(tokens);
	self->prepare(tokens);
	Token *root = self->parseSyntax(NULL, tokens);
	Tokens *modules = self->getUsedModules(root);
	AV* ret = new_Array();
	for (size_t i = 0; i < modules->size(); i++) {
		Token *module = modules->at(i);
		const char *module_name = cstr(module->data);
		size_t len = strlen(module_name);
		av_push(ret, set(new_String(module_name, len)));
	}
	RETVAL = ret;
}
OUTPUT:
    RETVAL

SV *
deparse(filename, script)
    const char *filename
    const char *script
CODE:
{
	Lexer lexer(filename);
	Tokens *tokens = lexer.tokenize((char *)script);
	lexer.annotateTokens(tokens);
	lexer.grouping(tokens);
	lexer.prepare(tokens);
	Token *root = lexer.parseSyntax(NULL, tokens);
	const char *src = root->deparse();
	size_t len = strlen(src) + 1;
	size_t token_size = tokens->size();
	//delete root;
	//lexer.deleteTokens(tokens);
	//lexer.deleteToken(root);
	RETVAL = newSVpv(src, len);
}
OUTPUT:
    RETVAL
