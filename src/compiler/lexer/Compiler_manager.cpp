#include <lexer.hpp>

namespace TokenType = Enum::Token::Type;
TokenManager::TokenManager(void) : max_token_size(0), idx(0)
{
	tokens = new Tokens();
	size_t i = 0;
	for (i = 0; decl_tokens[i].type != TokenType::Undefined; i++) {
		type_to_info_map.insert(TypeMap::value_type(decl_tokens[i].type, decl_tokens[i]));
		data_to_info_map.insert(TypeDataMap::value_type(decl_tokens[i].data, decl_tokens[i]));
	}
	type_to_info_map.insert(TypeMap::value_type(decl_tokens[i].type, decl_tokens[i]));
	data_to_info_map.insert(TypeDataMap::value_type(decl_tokens[i].data, decl_tokens[i]));
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

TokenInfo TokenManager::getTokenInfo(TokenType::Type type)
{
	TypeMap::iterator it = type_to_info_map.find(type);
	return (it != type_to_info_map.end()) ? it->second : getTokenInfo(TokenType::Undefined);
}

TokenInfo TokenManager::getTokenInfo(const char *data)
{
	TypeDataMap::iterator it = data_to_info_map.find(data);
	return (it != data_to_info_map.end()) ? it->second : getTokenInfo(TokenType::Undefined);
}

Token *TokenManager::next(void)
{
	this->idx++;
	return currentToken();
}

bool TokenManager::end(void)
{
	return (idx >= tokens->size()) ? true : false;
}

void TokenManager::remove(size_t idx)
{
	this->tokens->erase(this->tokens->begin() + idx);
}

void TokenManager::add(Token *tk)
{
	this->tokens->add(tk);
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

bool ScriptManager::compare(int start, int len, std::string target)
{
	size_t current_idx = this->idx;
	int s = current_idx + start;
	int e = s + len;
	if (0 <= s && (size_t)e < script_size) {
		char buffer[len + 1];
		memset(buffer, 0, len + 1);
		memcpy(buffer, raw_script + s, len);
		return std::string(buffer) == target;
	}
	return false;
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
	return raw_script[idx];
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
