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
_new(classname, _options)
	char *classname
	HV   *_options
CODE:
{
	const char *filename = SvPVX(get_value(_options, "filename"));
	bool verbose = SvIVX(get_value(_options, "verbose"));
	Lexer *lexer = new Lexer(filename, verbose);
	RETVAL = lexer;
}
OUTPUT:
	RETVAL

void
DESTROY(self)
	Compiler_Lexer self
CODE:
{
	delete self;
}

AV *
tokenize(self, script)
	Compiler_Lexer self
	const char *script
CODE:
{
	Tokens *tokens = self->tokenize((char *)script);
	AV* ret  = new_Array();
	size_t size = tokens->size();
	for (size_t i = 0; i < size; i++) {
		Token *token = tokens->at(i);
		HV *hash = (HV*)new_Hash();
		(void)hv_stores(hash, "stype", set(new_Int(token->stype)));
		(void)hv_stores(hash, "type", set(new_Int(token->info.type)));
		(void)hv_stores(hash, "kind", set(new_Int(token->info.kind)));
		(void)hv_stores(hash, "line", set(new_Int(token->finfo.start_line_num)));
		(void)hv_stores(hash, "has_warnings", set(new_Int(token->info.has_warnings)));
		(void)hv_stores(hash, "name", set(new_String(token->info.name, strlen(token->info.name))));
		(void)hv_stores(hash, "data", set(new_String(token->_data, strlen(token->_data))));
		HV *stash = (HV *)gv_stashpv("Compiler::Lexer::Token", sizeof("Compiler::Lexer::Token"));
		av_push(ret, set(sv_bless(new_Ref(hash), stash)));
	}
	self->clearContext();
    RETVAL = ret;
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
	int tokens_size = av_len(tokens_);
	if (tokens_size < 0) {
		RETVAL = NULL;
		return;
	}
	Tokens tks;
	for (int i = 0; i <= tokens_size; i++) {
		SV *token_ = (SV *)*av_fetch(tokens_, i, FALSE);
		if (sv_isa(token_, "Compiler::Lexer::Token")) {
			token_ = SvRV(token_);
		}
		HV *token = (HV *)token_;
		const char *name = SvPVX(get_value(token, "name"));
		const char *data = SvPVX(get_value(token, "data"));
		int line = SvIVX(get_value(token, "line"));
		int has_warnings = SvIVX(get_value(token, "has_warnings"));
		Enum::Token::Type::Type type = (Enum::Token::Type::Type)SvIVX(get_value(token, "type"));
		Enum::Token::Kind::Kind kind = (Enum::Token::Kind::Kind)SvIVX(get_value(token, "kind"));
		FileInfo finfo;
		finfo.start_line_num = line;
		finfo.end_line_num = line;
		finfo.filename = self->finfo.filename;
		TokenInfo info;
		info.type = type;
		info.kind = kind;
		info.name = name;
		info.data = data;
		info.has_warnings = has_warnings;
		Token *tk = new Token(std::string(data), finfo);
		tk->info = info;
		tk->type = type;
		tk->_data = data;
		tks.push_back(tk);
	}
	self->grouping(&tks);
	self->prepare(&tks);
	//self->dump(&tks);
	Token *root = self->parseSyntax(NULL, &tks);
	//self->dumpSyntax(root, 0);
	self->parseSpecificStmt(root);
	//self->dumpSyntax(root, 0);
	self->setIndent(root, 0);
	size_t block_id = 0;
	self->setBlockIDWithDepthFirst(root, &block_id);
	Tokens *stmts = self->getTokensBySyntaxLevel(root, (Enum::Parser::Syntax::Type)syntax_level);
	AV* ret  = new_Array();
	for (size_t i = 0; i < stmts->size(); i++) {
		Token *stmt = stmts->at(i);
		const char *src = stmt->deparse();
		size_t len = strlen(src);
		HV *hash = (HV*)new_Hash();
		(void)hv_stores(hash, "src", set(new_String(src, len)));
		(void)hv_stores(hash, "token_num", set(new_Int(stmt->total_token_num)));
		(void)hv_stores(hash, "indent", set(new_Int(stmt->finfo.indent)));
		(void)hv_stores(hash, "block_id", set(new_Int(stmt->finfo.block_id)));
		(void)hv_stores(hash, "start_line", set(new_Int(stmt->finfo.start_line_num)));
		(void)hv_stores(hash, "end_line", set(new_Int(stmt->finfo.end_line_num)));
		(void)hv_stores(hash, "has_warnings", set(new_Int(stmt->info.has_warnings)));
		av_push(ret, set(new_Ref(hash)));
	}
	RETVAL = ret;
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
	self->grouping(tokens);
	self->prepare(tokens);
	Token *root = self->parseSyntax(NULL, tokens);
	Modules *modules = self->getUsedModules(root);
	AV* ret = new_Array();
	for (size_t i = 0; i < modules->size(); i++) {
		Module *module = modules->at(i);
		const char *module_name = module->name;
		const char *module_args = module->args;
		size_t module_name_len = strlen(module_name);
		size_t module_args_len = (module_args) ? strlen(module_args) : 0;
		HV *hash = (HV*)new_Hash();
		(void)hv_stores(hash, "name", set(new_String(module_name, module_name_len)));
		(void)hv_stores(hash, "args", set(new_String(module_args, module_args_len)));
		av_push(ret, set(new_Ref(hash)));
	}
	self->clearContext();
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
	Lexer lexer(filename, false);
	Tokens *tokens = lexer.tokenize((char *)script);
	lexer.grouping(tokens);
	lexer.prepare(tokens);
	Token *root = lexer.parseSyntax(NULL, tokens);
	const char *src = root->deparse();
	size_t len = strlen(src) + 1;
	size_t token_size = tokens->size();
	RETVAL = newSVpv(src, len);
}
OUTPUT:
    RETVAL
