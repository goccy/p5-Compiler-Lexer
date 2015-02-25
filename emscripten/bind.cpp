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

CompilerLexerToken tokenize(std::string script)
{
	Lexer lexer("", false);
	Tokens *tokens = lexer.tokenize((char *)script.c_str());
	CompilerLexerToken *token = new CompilerLexerToken();
	if (tokens->size() == 0) return *token;
	token->name = std::string(((Token *)tokens->at(0))->info.name);
	token->data = std::string(((Token *)tokens->at(0))->_data);
	return *token;
}

EMSCRIPTEN_BINDINGS(compiler_lexer) {
	class_<CompilerLexerToken>("Token").constructor()
		.function("setData", &CompilerLexerToken::setData)
		.function("getData", &CompilerLexerToken::getData)
		.function("setName", &CompilerLexerToken::setName)
		.function("getName", &CompilerLexerToken::getName);
	function("tokenize", &tokenize);
}
