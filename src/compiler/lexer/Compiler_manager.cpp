#include <lexer.hpp>

namespace TokenType = Enum::Token::Type;

TokenManager::TokenManager(size_t script_size, bool verbose) : max_token_size(0)
{
	tokens = new Tokens();
	pool = (TokenPool *)new Token[script_size];
	undefined_info = getTokenInfo(TokenType::Undefined);
	this->verbose = verbose;
}

Token *TokenManager::at(size_t i)
{
	return tokens->get(i);
}

Token *TokenManager::nextToken(size_t i)
{
	if (!verbose) {
		return tokens->get(i + 1);
	}
	Token *next_tk = tokens->get(++i);
	/* refetch is necessary when verbose mode */
	while (next_tk != NULL && next_tk->info.type == TokenType::WhiteSpace) {
		next_tk = tokens->get(++i);
	}
	return next_tk;
}

Token *TokenManager::previousToken(size_t i)
{
	if (!verbose) {
		return tokens->get(i - 1);
	}
	Token *prev_tk = tokens->get(--i);
	/* refetch is necessary when verbose mode */
	while (prev_tk != NULL && prev_tk->info.type == TokenType::WhiteSpace) {
		prev_tk = tokens->get(--i);
	}
	return prev_tk;
}

Token *TokenManager::beforePreviousToken(size_t i)
{
	if (!verbose) {
		 return tokens->get(i - 2);
	}
	Token *prev_tk = tokens->get(--i);
	while (prev_tk != NULL && prev_tk->info.type == TokenType::WhiteSpace) {
		prev_tk = tokens->get(--i);
	}
	Token *before_prev_tk = tokens->get(--i);
	while (before_prev_tk != NULL && before_prev_tk->info.type == TokenType::WhiteSpace) {
		before_prev_tk = tokens->get(--i);
	}
	return before_prev_tk;
}

Token *TokenManager::lastToken(void)
{
	return tokens->get(currentIdx());
}

Token *TokenManager::beforeLastToken(void)
{
	return previousToken();
}

size_t TokenManager::size(void)
{
	return tokens->size();
}

void TokenManager::dump(void)
{
	size_t size = tokens->size();
	for (size_t i = 0; i < size; i++) {
		Token *tk = tokens->get(i);
		fprintf(stdout, "[%-12s] : %12s \n", tk->_data, tk->info.name);
	}
}

Token *TokenManager::getTokenByBase(size_t base, int offset)
{
	return tokens->get(base + offset);
}

Token *TokenManager::getTokenByIdx(size_t idx)
{
	return tokens->get(idx);
}

Token *TokenManager::beforePreviousToken(void)
{
	return beforePreviousToken(currentIdx());
}

Token *TokenManager::previousToken(void)
{
	return previousToken(currentIdx());
}

Token *TokenManager::nextToken(void)
{
	return this->nextToken(currentIdx());
}

size_t TokenManager::currentIdx()
{
	return size() - 1;
}

/*
Token *TokenManager::currentToken(void)
{
	return tokens->get(currentIdx());
}

bool TokenManager::end(void)
{
	return (idx >= tokens->size()) ? true : false;
}

void TokenManager::remove(size_t idx)
{
	this->tokens->erase(his->tokens->begin() + idx);
}

Token *TokenManager::back(void)
{
	this->idx--;
	return currentToken();
}
*/
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
