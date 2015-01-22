#include <iostream>
#include <string>
#include <lexer.hpp>

typedef Lexer * Compiler_Lexer;
int show_token( Token *token );

int main() {
	const char *filename = "foo.pl";
	bool verbose = false;
	Lexer *lexer = new Lexer(filename, verbose);

	const char *script = "$array->@*";
	Tokens *tokens = lexer->tokenize( (char *)script);

	size_t size = tokens->size();
	for (size_t i = 0; i < size; i++) {
		Token *token = tokens->at(i);
		show_token( token );
		}

	return 0;
	}

int show_token( Token *token ) {
	printf( 
		"------------\nStype: %d\nType: %d\nKind: %d\nName: %s\nData: %s\n",
		token->stype,
		token->info.type,
		token->info.kind,
		token->info.name,
		token->_data
		);
	return 1;
	}	

/*

		HV *hash = (HV*)new_Hash();
		(void)hv_stores(hash, "stype", set(new_Int(token->stype)));
		(void)hv_stores(hash, "type", set(new_Int(token->info.type)));
		(void)hv_stores(hash, "kind", set(new_Int(token->info.kind)));
		(void)hv_stores(hash, "line", set(new_Int(token->finfo.start_line_num)));
		(void)hv_stores(hash, "has_warnings", set(new_Int(token->info.has_warnings)));
		(void)hv_stores(hash, "name", set(new_String(token->info.name, strlen(token->info.name))));
		(void)hv_stores(hash, "data", set(new_String(token->_data, strlen(token->_data))));

*/
