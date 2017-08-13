#include <lexer.hpp>

namespace TokenType = Enum::Token::Type;

TokenManager::TokenManager(size_t script_size) : max_token_size(0), idx(0)
{
	size_t token_size = sizeof(Token);
	tokens = new Tokens();
	pool = (TokenPool *)calloc(script_size, token_size);
	head = pool;
	undefined_info = getTokenInfo(TokenType::Undefined);
}

Token *TokenManager::at(size_t i)
{
	return head + i;
}

Token *TokenManager::nextToken(Token *tk)
{
	return (tk + 1 < pool) ? tk + 1 : NULL;
}

Token *TokenManager::previousToken(Token *tk)
{
	return (tk != head) ? tk - 1 : NULL;
}

Token *TokenManager::beforePreviousToken(Token *tk)
{
	return (tk != head && (tk-1) != head) ? tk - 2 : NULL;
}

Token *TokenManager::lastToken(void)
{
	return (head != pool) ? pool-1 : NULL;
}

Token *TokenManager::beforeLastToken(void)
{
	return (head + 2 <= pool) ? pool-2 : NULL;
}

size_t TokenManager::size(void)
{
	return (pool - head);
}

void TokenManager::dump(void)
{
	size_t size = pool - head;
	for (size_t i = 0; i < size; i++) {
		Token *tk = (head + i);
		fprintf(stdout, "[%-12s] : %12s \n", tk->_data, tk->info.name);
	}
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

bool TokenManager::end(void)
{
	return (idx >= tokens->size()) ? true : false;
}

void TokenManager::remove(size_t idx)
{
	this->tokens->erase(this->tokens->begin() + idx);
}

Token *TokenManager::back(void)
{
	this->idx--;
	return currentToken();
}

ScriptManager::ScriptManager(char *script) :
	_script(script), raw_script(script), idx(0)
{
	raw_script_size = strlen(script);
	script_size = raw_script_size + 1;
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
