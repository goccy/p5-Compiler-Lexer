#include <iostream>
#include <string>
#include <lexer.hpp>

using namespace std;

typedef Lexer * Compiler_Lexer;
int show_token( Token *token );
int just_toke_it( Lexer *lexer, const char *script );

int main() {
	const char *filename = "foo.pl";
	bool verbose = false;
	Lexer *lexer = new Lexer(filename, verbose);

	just_toke_it( lexer, "$scalar->$*" );

	just_toke_it( lexer, "$array->@*" );
	just_toke_it( lexer, "$array->@[0]" );
	just_toke_it( lexer, "$array->@[0,1]" );
	just_toke_it( lexer, "$array->@[@indices]" );
	just_toke_it( lexer, "$array->$#*" );

	just_toke_it( lexer, "$hash->%*" );
	just_toke_it( lexer, "$hash->%{'key'}" );
	just_toke_it( lexer, "$hash->%{'key','key2'}" );
	just_toke_it( lexer, "$hash->%{@keys}" );

	just_toke_it( lexer, "$coderef->&('arg','arg2')" );
	just_toke_it( lexer, "$coderef->&*" );

	just_toke_it( lexer, "$typeglob->**" );
	just_toke_it( lexer, "$typeglob->*{SCALAR}" );

	return 0;
	}

int just_toke_it( Lexer *lexer, const char *script ) {
	Tokens *tokens = lexer->tokenize((char *)script);

	cout << "==================" 
		<< endl 
		<< script 
		<< endl 
		<< "-------------------" 
		<< endl;

	size_t size = tokens->size();
	for (size_t i = 0; i < size; i++) {
		Token *token = tokens->at(i);
		show_token( token );
		}
	
	return 1;
	}

int show_token( Token *token ) {
	printf( 
		"%-20s | %-s\n",
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
