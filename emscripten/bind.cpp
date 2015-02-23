#include <emscripten/bind.h>
#include <lexer.hpp>

using namespace emscripten;

Tokens *tokenize(char *script)
{
	Lexer lexer("", false);
	return lexer.tokenize(script);
}

EMSCRIPTEN_BINDINGS(compiler_lexer) {
	class_<Token>("Token");
	class_<std::vector<Token*>>register_vector("Tokens");
	function("tokenize", &tokenize, allow_raw_pointers());
}
