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

#ifdef __cplusplus
};
#endif


MODULE = Lexer		PACKAGE = Lexer		
PROTOTYPES: DISABLE

AV *
get_stmt_codes(filename, script)
    const char *filename
    const char *script
CODE:
	Lexer lexer(filename);
	Tokens *tokens = lexer.tokenize((char *)script);
	lexer.annotateTokens(tokens);
	lexer.grouping(tokens);
	lexer.prepare(tokens);
	Token *root = lexer.parseSyntax(NULL, tokens);
	Tokens *stmts = lexer.getTokensBySyntaxLevel(root, Enum::Lexer::Syntax::Stmt);
    AV* ret  = new_Array();
	for (size_t i = 0; i < stmts->size(); i++) {
		Token *stmt = stmts->at(i);
		const char *src = stmt->deparse();
        size_t len = strlen(src) + 1;
		HV *hash = (HV*)new_Hash();
		hv_stores(hash, "src", set(new_String(src, len)));
		hv_stores(hash, "start_line", set(new_Int(stmt->finfo.start_line_num)));
		hv_stores(hash, "end_line", set(new_Int(stmt->finfo.end_line_num)));
		av_push(ret, set(new_Ref(hash)));
	}
    RETVAL = (AV *)new_Ref(ret);
OUTPUT:
    RETVAL

AV *
get_used_modules(filename, script)
    const char *filename
    const char *script
CODE:
	Lexer lexer(filename);
	Tokens *tokens = lexer.tokenize((char *)script);
	lexer.annotateTokens(tokens);
	lexer.grouping(tokens);
	lexer.prepare(tokens);
	Token *root = lexer.parseSyntax(NULL, tokens);
	Tokens *modules = lexer.getUsedModules(root);
    AV* ret = new_Array();
	for (size_t i = 0; i < modules->size(); i++) {
		Token *module = modules->at(i);
		const char *module_name = cstr(module->data);
        size_t len = strlen(module_name) + 1;
		av_push(ret, newSVpv(module_name, len));
	}
    RETVAL = ret;
OUTPUT:
    RETVAL

SV *
deparse(filename, script)
    const char *filename
    const char *script
CODE:
	Lexer lexer(filename);
	Tokens *tokens = lexer.tokenize((char *)script);
	lexer.annotateTokens(tokens);
	lexer.grouping(tokens);
	lexer.prepare(tokens);
	Token *root = lexer.parseSyntax(NULL, tokens);
    const char *src = root->deparse();
    size_t len = strlen(src) + 1;
    RETVAL = newSVpv(src, len);
OUTPUT:
    RETVAL
