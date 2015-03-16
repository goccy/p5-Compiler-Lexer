#include <emscripten/bind.h>
#include <lexer.hpp>

using namespace emscripten;

class CompilerLexerToken {
public:
	std::string data;
	std::string name;
    CompilerLexerToken();
    void setData(std::string data);
    const std::string& getData();
    void setName(std::string name);
    const std::string& getName();
};

typedef std::vector<CompilerLexerToken> CompilerLexerTokens;

CompilerLexerToken::CompilerLexerToken()
{
}

void CompilerLexerToken::setData(std::string data)
{
	this->data = data;
}

const std::string &CompilerLexerToken::getData()
{
	return this->data;
}

void CompilerLexerToken::setName(std::string name)
{
	this->name = name;
}

const std::string& CompilerLexerToken::getName()
{
	return this->name;
}

CompilerLexerTokens tokenize(std::string script)
{
	Lexer lexer("", false);
	Tokens *tokens = lexer.tokenize((char *)script.c_str());
	CompilerLexerTokens *ret = new CompilerLexerTokens();
	for (size_t i = 0; i < tokens->size(); i++) {
		CompilerLexerToken *token = new CompilerLexerToken();
		token->name = std::string(((Token *)tokens->at(i))->info.name);
		token->data = std::string(((Token *)tokens->at(i))->_data);
		ret->push_back(*token);
	}
	return *ret;
}

EMSCRIPTEN_BINDINGS(compiler_lexer) {
	class_<CompilerLexerToken>("Token").constructor()
		.function("setData", &CompilerLexerToken::setData)
		.function("getData", &CompilerLexerToken::getData)
		.function("setName", &CompilerLexerToken::setName)
		.function("getName", &CompilerLexerToken::getName);
	register_vector<CompilerLexerToken>("Tokens");
	function("tokenize", &tokenize);
}
