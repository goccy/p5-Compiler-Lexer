#include <lexer.hpp>

TokenManager::TokenManager(void) : max_token_size(0)
{
	tokens = new Tokens();
}

Token *TokenManager::getTokenByBase(Token *base, int offset)
{
	Tokens *tks = this->tokens;
	size_t size = tks->size();
	int wanted_idx = -1;
	for (size_t i = 0; i < size; i++) {
		if (tks->at(i) == base) {
			wanted_idx = i + offset;
		}
	}
	return (0 <= wanted_idx && (size_t)wanted_idx < size) ?
		tks->at(wanted_idx) : NULL;
}

Token *TokenManager::getTokenByIdx(size_t idx)
{
	size_t size = tokens->size();
	return (idx < size) ? tokens->at(idx) : NULL;
}

Token *TokenManager::beforePreviousToken(void)
{
	size_t current_idx = this->idx;
	size_t size = tokens->size();
	int wanted_idx = current_idx - 2;
	return (0 <= wanted_idx && (size_t)wanted_idx < size) ?
		tokens->at(wanted_idx) : NULL;
}

Token *TokenManager::previousToken(void)
{
	size_t current_idx = this->idx;
	size_t size = tokens->size();
	int wanted_idx = current_idx - 1;
	return (0 <= wanted_idx && (size_t)wanted_idx < size) ?
		tokens->at(wanted_idx) : NULL;
}

Token *TokenManager::currentToken(void)
{
	size_t current_idx = this->idx;
	size_t size = tokens->size();
	return (current_idx < size) ? tokens->at(current_idx) : NULL;
}

Token *TokenManager::nextToken(void)
{
	size_t current_idx = this->idx;
	size_t size = tokens->size();
	int wanted_idx = current_idx + 1;
	return (0 <= wanted_idx && (size_t)wanted_idx < size) ?
		tokens->at(wanted_idx) : NULL;
}

Token *TokenManager::afterNextToken(void)
{
	size_t current_idx = this->idx;
	size_t size = tokens->size();
	int wanted_idx = current_idx + 2;
	return (0 <= wanted_idx && (size_t)wanted_idx < size) ?
		tokens->at(wanted_idx) : NULL;
}

Token *TokenManager::next(void)
{
	this->idx++;
	return currentToken();
}

Token *TokenManager::back(void)
{
	this->idx--;
	return currentToken();
}

ScriptManager::ScriptManager(char *script) :
	_script(script), raw_script(script), idx(0)
{
	script_size = strlen(script) + 1;
}

char ScriptManager::getCharByOffset(int offset)
{
	size_t current_idx = this->idx;
	int wanted_idx = current_idx + offset;
	return (0 <= wanted_idx && (size_t)wanted_idx < script_size) ?
		raw_script[wanted_idx] : EOL;
}

char ScriptManager::beforePreviousChar(void)
{
	size_t current_idx = this->idx;
	int wanted_idx = current_idx - 2;
	return (0 <= wanted_idx && (size_t)wanted_idx < script_size) ?
		raw_script[wanted_idx] : EOL;
}

char ScriptManager::previousChar(void)
{
	size_t current_idx = this->idx;
	int wanted_idx = current_idx - 1;
	return (0 <= wanted_idx && (size_t)wanted_idx < script_size) ?
		raw_script[wanted_idx] : EOL;
}

char ScriptManager::currentChar(void)
{
	size_t current_idx = this->idx;
	return (current_idx < script_size) ? raw_script[current_idx] : EOL;
}

char ScriptManager::nextChar(void)
{
	size_t current_idx = this->idx;
	int wanted_idx = current_idx + 1;
	return (0 <= wanted_idx && (size_t)wanted_idx < script_size) ?
		raw_script[wanted_idx] : EOL;
}

char ScriptManager::afterNextChar(void)
{
	size_t current_idx = this->idx;
	int wanted_idx = current_idx + 2;
	return (0 <= wanted_idx && (size_t)wanted_idx < script_size) ?
		raw_script[wanted_idx] : EOL;
}

char ScriptManager::next(void)
{
	this->idx++;
	return currentChar();
}

char ScriptManager::forward(size_t progress)
{
	this->idx += progress;
	return currentChar();
}

char ScriptManager::back(void)
{
	this->idx--;
	return currentChar();
}

bool ScriptManager::end(void)
{
	return currentChar() == EOL;
}
