#include <lexer.hpp>
using namespace std;
namespace TokenType = Enum::Lexer::Token;
namespace SyntaxType = Enum::Lexer::Syntax;
namespace TokenKind = Enum::Lexer;

Scanner::Scanner() :
	isStringStarted(false), isRegexStarted(false), isPrototypeStarted(false), commentFlag(false), hereDocumentFlag(false),
	regex_delim(0), regex_middle_delim(0),
    brace_count_inner_regex(0), bracket_count_inner_regex(0), cury_brace_count_inner_regex(0)
{
}

Token *Scanner::scanQuote(LexContext *ctx, char quote)
{
	Token *ret = NULL;
	if (isStringStarted) {
		ret = new Token(string(ctx->token), ctx->finfo);
		switch (quote) {
		case '\'':
			ret->info = getTokenInfo(TokenType::RawString);
			break;
		case '"':
			ret->info = getTokenInfo(TokenType::String);
			break;
		case '`':
			ret->info = getTokenInfo(TokenType::ExecString);
			break;
		default:
			break;
		}
		ctx->clearToken(ctx->token);
		Token *prev_tk = (ctx->tokens->size() > 0) ? ctx->tokens->back() : NULL;
		if (prev_tk && prev_tk->data == "<<") {
			/* String is HereDocument */
			here_document_tag = ret->data;
			if (here_document_tag == "") {
				here_document_tag = "\n";
			}
			switch (quote) {
			case '\'':
				ret->info = getTokenInfo(TokenType::HereDocumentRawTag);
				break;
			case '"':
				ret->info = getTokenInfo(TokenType::HereDocumentTag);
				break;
			default:
				break;
			}
		}
		isStringStarted = false;
	} else {
		start_string_ch = quote;
		isStringStarted = true;
	}
	return ret;
}

bool Scanner::scanNegativeNumber(LexContext *ctx, char number)
{
	char num_buffer[2] = {0};
	if (number != EOL && !isStringStarted) {
		num_buffer[0] = number;
		if (atoi(num_buffer) > 0 || number == '0') {
			//negative number
			ctx->writeChar(ctx->token, '-');
			return true;
		}
	}
	return false;
}

Token *Scanner::scanPrevSymbol(LexContext *ctx, char symbol)
{
	Token *ret = NULL;
	char *token = ctx->token;
	string prev_token = string(token);
	Token *prev_before_tk = (ctx->tokens->size() > 0) ? ctx->tokens->back() : NULL;
	TokenType::Type prev_before_tk_type = TokenType::Undefined;
	string prev_before_tk_data = "";
	if (prev_before_tk) {
		prev_before_tk_type = prev_before_tk->info.type;
		prev_before_tk_data = prev_before_tk->data;
	}
	/* exclude { m } or { m => ... } or { m, ... } or *m or //m */
	if (symbol != '}' && symbol != ',' && symbol != '=' &&
		prev_before_tk_data != "*" && prev_before_tk_data != "&" &&
		prev_before_tk_data != "::" &&
		prev_before_tk_type != TokenType::RegDelim &&
		(prev_token == "q"  || prev_token == "qq" ||
		 prev_token == "qw" || prev_token == "qx" ||
		 prev_token == "qr" || prev_token == "m")) {
		//RegexPrefix
		ret = new Token(string(token), ctx->finfo);
		ret->info = getTokenInfo(cstr(prev_token));
		ctx->clearToken(token);
		switch (symbol) {
		case '{': regex_delim = '}';
			brace_count_inner_regex++;
			break;
		case '(': regex_delim = ')';
			cury_brace_count_inner_regex++;
			break;
		case '<': regex_delim = '>';
			break;
		case '[': regex_delim = ']';
			bracket_count_inner_regex++;
			break;
		default:
			regex_delim = symbol;
			break;
		}
		isRegexStarted = true;
	} else if (symbol != '}' && symbol != ',' && symbol != '=' &&
			   prev_before_tk_data != "*" && prev_before_tk_data != "::" &&
			   prev_before_tk_data != "&" &&
			   prev_before_tk_type != TokenType::RegDelim &&
			   (prev_token == "s"  ||
				prev_token == "y"  ||
				prev_token == "tr")) {
		//ReplaceRegexPrefix
		ret = new Token(string(token), ctx->finfo);
		ret->info = getTokenInfo(cstr(prev_token));
		ctx->clearToken(token);
		switch (symbol) {
		case '{':
			regex_delim = '}';
			regex_middle_delim = '}';
			brace_count_inner_regex++;
			break;
		case '(':
			regex_delim = ')';
			regex_middle_delim = ')';
			cury_brace_count_inner_regex++;
			break;
		case '<':
			regex_delim = '>';
			regex_middle_delim = '>';
			break;
		case '[':
			regex_delim = ']';
			regex_middle_delim = ']';
			bracket_count_inner_regex++;
			break;
		default:
			regex_delim = symbol;
			regex_middle_delim = symbol;
			break;
		}
		isRegexStarted = true;
	} else if (symbol == '(' &&
			   (prev_before_tk_data == "sub" ||
				(ctx->tokens->size() > 1 &&
				 ctx->tokens->at(ctx->tokens->size() - 2)->data == "sub"))) {
		ret = new Token(string(token), ctx->finfo);
		ctx->clearToken(token);
		isPrototypeStarted = true;
	} else {
		ret = new Token(string(token), ctx->finfo);
		if (prev_before_tk_data == "<<" && (isupper(token[0]) || token[0] == '_')) {
			/* Key is HereDocument */
			here_document_tag = token;
			ret->info = getTokenInfo(TokenType::HereDocumentRawTag);
		}
		ctx->clearToken(token);
	}
	return ret;
}

bool Scanner::isRegexDelim(Token *prev_token, char symbol)
{
	const char *prev_data = (prev_token) ? cstr(prev_token->data) : "";
	/* [^0-9] && !"0" && !CONST && !{hash} && ![array] && !func() && !$var */
	string prev_tk = string(prev_data);
	if (regex_delim == 0 && prev_token && prev_token->info.type == TokenType::Undefined &&
		(symbol != '-' && symbol != '=' && symbol != ',') &&
		(prev_tk == "q"  || prev_tk == "qq" || prev_tk == "qw" ||
		 prev_tk == "qx" || prev_tk == "qr" || prev_tk == "m")) {
		return true;
	}
	if (symbol == '/' && (prev_tk == "xor" || prev_tk == "and")) return true;
	if (symbol != '/') return false;
	if (!prev_token) return true;
	if (strtod(prev_data, NULL)) return false;
	if (string(prev_data) == "0") return false;
	if (!isupper(prev_data[0]) && prev_data[0] != '_' &&
		prev_data[0] != '}' && prev_data[0] != ']' && prev_data[0] != ')' &&
		prev_data[0] != '$' && prev_data[0] != '@' && prev_data[0] != '%') {
		if (isalpha(prev_data[0]) && string(prev_data) != "split" &&
			string(prev_data) != "if" && string(prev_data) != "unless") return false;
		return true;
	}
	if (string(prev_data) == "split") return true;
	return false;
}

Token *Scanner::scanCurSymbol(LexContext *ctx, char symbol)
{
	Token *ret = NULL;
	char *token = ctx->token;
	char tmp[2] = {0};
	tmp[0] = symbol;
	Token *prev_tk = (ctx->tokens->size() > 0) ? ctx->tokens->back() : NULL;
	string prev_before = (ctx->tokens->size() > 2) ? ctx->tokens->at(ctx->tokens->size() - 2)->data : "";
	if (prev_before != "sub" && isRegexDelim(prev_tk, symbol)) {
		ret = new Token(string(tmp), ctx->finfo);
		ret->info = getTokenInfo(TokenType::RegDelim);
		ctx->clearToken(token);
		if (prev_tk->info.type != TokenType::RegExp &&
			prev_tk->info.type != TokenType::RegReplaceTo) {
			switch (symbol) {
			case '{': regex_delim = '}';
				brace_count_inner_regex++;
				break;
			case '(': regex_delim = ')';
				cury_brace_count_inner_regex++;
				break;
			case '<': regex_delim = '>';
				break;
			case '[': regex_delim = ']';
				bracket_count_inner_regex++;
				break;
			default:
				regex_delim = symbol;
				break;
			}
			isRegexStarted = true;
		} else {
			regex_delim = 0;
		}
	} else if (isRegexStarted ||
			   (prev_tk && prev_tk->info.type == TokenType::RegExp) ||
			   (prev_tk && prev_tk->info.type == TokenType::RegReplaceTo)) {
		ret = new Token(string(tmp), ctx->finfo);
		ret->info = getTokenInfo(TokenType::RegDelim);
		ctx->clearToken(token);
	} else if (symbol == '@' || symbol == '$' || symbol == '%') {// || symbol == '&') {
		ctx->writeChar(token, symbol);
	} else if (symbol == ';') {
		ret = new Token(string(tmp), ctx->finfo);
		ctx->clearToken(token);
	} else if (symbol == '(' &&
			(prev_tk->data == "sub" ||
			(ctx->tokens->size() > 1 &&
			 ctx->tokens->at(ctx->tokens->size() - 2)->data == "sub"))) {
		ret = new Token(string(tmp), ctx->finfo);
		ctx->clearToken(token);
		isPrototypeStarted = true;
	} else {
		ret = new Token(string(tmp), ctx->finfo);
		ctx->clearToken(token);
	}
	return ret;
}

Token *Scanner::scanTripleCharacterOperator(LexContext *ctx, char symbol, char next_ch, char after_next_ch)
{
	Token *ret = NULL;
	char tmp[4] = {0};
	if ((symbol == '<' && next_ch == '=' && after_next_ch == '>') ||
		(symbol == '*' && next_ch == '*' && after_next_ch == '=') ||
		(symbol == '/' && next_ch == '/' && after_next_ch == '=') ||
		(symbol == '|' && next_ch == '|' && after_next_ch == '=') ||
		(symbol == '&' && next_ch == '&' && after_next_ch == '=') ||
		(symbol == '.' && next_ch == '.' && after_next_ch == '.') ||
		(symbol == '$' && next_ch == '#' && after_next_ch == '{') ||
		(symbol == '$' && next_ch == '^' && after_next_ch == 'A') ||
		(symbol == '$' && next_ch == '^' && after_next_ch == 'D') ||
		(symbol == '$' && next_ch == '^' && after_next_ch == 'E') ||
		(symbol == '$' && next_ch == '^' && after_next_ch == 'F') ||
		(symbol == '$' && next_ch == '^' && after_next_ch == 'G') ||
		(symbol == '$' && next_ch == '^' && after_next_ch == 'H') ||
		(symbol == '$' && next_ch == '^' && after_next_ch == 'I') ||
		(symbol == '$' && next_ch == '^' && after_next_ch == 'L') ||
		(symbol == '$' && next_ch == '^' && after_next_ch == 'M') ||
		(symbol == '$' && next_ch == '^' && after_next_ch == 'O') ||
		(symbol == '$' && next_ch == '^' && after_next_ch == 'P') ||
		(symbol == '$' && next_ch == '^' && after_next_ch == 'R') ||
		(symbol == '$' && next_ch == '^' && after_next_ch == 'T') ||
		(symbol == '$' && next_ch == '^' && after_next_ch == 'W') ||
		(symbol == '$' && next_ch == '^' && after_next_ch == 'X')) {
		tmp[0] = symbol;
		tmp[1] = next_ch;
		tmp[2] = after_next_ch;
		ret = new Token(string(tmp), ctx->finfo);
		ctx->progress = 2;
	}
	return ret;
}

Token *Scanner::scanDoubleCharacterOperator(LexContext *ctx, char symbol, char next_ch)
{
	Token *ret = NULL;
	char tmp[3] = {0};
	if ((symbol == '<' && next_ch == '=') || (symbol == '>' && next_ch == '=') ||
		(symbol == '.' && next_ch == '=') || (symbol == '!' && next_ch == '=') ||
		(symbol == '=' && next_ch == '=') || (symbol == '+' && next_ch == '=') ||
		(symbol == '-' && next_ch == '=') || (symbol == '*' && next_ch == '=') ||
		(symbol == '%' && next_ch == '=') || (symbol == '|' && next_ch == '=') ||
		(symbol == '&' && next_ch == '=') || (symbol == '^' && next_ch == '=') ||
		(symbol == '<' && next_ch == '<') || (symbol == '>' && next_ch == '>') ||
		(symbol == '+' && next_ch == '+') || (symbol == '/' && next_ch == '/') ||
		(symbol == '=' && next_ch == '>') || (symbol == '=' && next_ch == '~') ||
		(symbol == '@' && next_ch == '{') || (symbol == '%' && next_ch == '{') ||
		(symbol == '$' && next_ch == '{') || (symbol == '@' && next_ch == '$') ||
		(symbol == '%' && next_ch == '$') || (symbol == '&' && next_ch == '$') ||
		(symbol == '$' && next_ch == '#') || (symbol == '-' && next_ch == '-') ||
		(symbol == '*' && next_ch == '*') || (symbol == '-' && next_ch == '>') ||
		(symbol == '<' && next_ch == '>') || (symbol == '&' && next_ch == '&') ||
		(symbol == '|' && next_ch == '|') || (symbol == ':' && next_ch == ':') ||
		(symbol == '.' && next_ch == '.') || (symbol == '!' && next_ch == '~') ||
		(symbol == '~' && next_ch == '~') || (symbol == '$' && next_ch == '0') ||
		(symbol == '$' && next_ch == '1') || (symbol == '$' && next_ch == '2') ||
		(symbol == '$' && next_ch == '3') || (symbol == '$' && next_ch == '4') ||
		(symbol == '$' && next_ch == '5') || (symbol == '$' && next_ch == '6') ||
		(symbol == '$' && next_ch == '7') || (symbol == '$' && next_ch == '8') ||
		(symbol == '$' && next_ch == '9') || (symbol == '$' && next_ch == '&') ||
		(symbol == '$' && next_ch == '`') || (symbol == '$' && next_ch == '\'') ||
		(symbol == '$' && next_ch == '+') || (symbol == '$' && next_ch == '.') ||
		(symbol == '$' && next_ch == '/') || (symbol == '$' && next_ch == '|') ||
		(symbol == '$' && next_ch == ',') || (symbol == '$' && next_ch == '\\') ||
		(symbol == '$' && next_ch == '"') || (symbol == '$' && next_ch == '%') ||
		(symbol == '$' && next_ch == '=') || (symbol == '$' && next_ch == '-') ||
		(symbol == '$' && next_ch == '~') || (symbol == '$' && next_ch == '^') ||
		(symbol == '$' && next_ch == '*') || (symbol == '$' && next_ch == ':') ||
		(symbol == '$' && next_ch == ';') || (symbol == '$' && next_ch == '?') ||
		(symbol == '$' && next_ch == '!') || (symbol == '$' && next_ch == '@') ||
		(symbol == '$' && next_ch == '$') || (symbol == '$' && next_ch == '<') ||
		(symbol == '$' && next_ch == '>') || (symbol == '$' && next_ch == '(') ||
		(symbol == '$' && next_ch == ')') || (symbol == '$' && next_ch == '[') ||
		(symbol == '$' && next_ch == ']')) {
		tmp[0] = symbol;
		tmp[1] = next_ch;
		ret = new Token(string(tmp), ctx->finfo);
		ctx->progress = 1;
	} else if (symbol == '-' &&
			(next_ch == 'r' || next_ch == 'w' ||
			next_ch == 'x'  || next_ch == 'o' ||
			next_ch == 'R'  || next_ch == 'W' ||
			next_ch == 'X'  || next_ch == 'O' ||
			next_ch == 'e'  || next_ch == 'z' ||
			next_ch == 's'  || next_ch == 'f' ||
			next_ch == 'd'  || next_ch == 'l' ||
			next_ch == 'p'  || next_ch == 'S' ||
			next_ch == 'b'  || next_ch == 'c' ||
			next_ch == 't'  || next_ch == 'u' ||
			next_ch == 'g'  || next_ch == 'k' ||
			next_ch == 'T'  || next_ch == 'B' ||
			next_ch == 'M'  || next_ch == 'A' ||
			next_ch == 'C')) {
		tmp[0] = symbol;
		tmp[1] = next_ch;
		ret = new Token(string(tmp), ctx->finfo);
		ret->info = getTokenInfo(TokenType::Handle);
		ctx->progress = 1;
	} else if (symbol == '/' && next_ch == '=') {
		Token *prev_tk = (ctx->tokens->size() > 0) ? ctx->tokens->back() : NULL;
		const char *prev_data = cstr(prev_tk->data);
		/* '/=' is RegDelim + RegExp or DivEqual */
		if (strtod(prev_data, NULL) != 0 || string(prev_data) == "0" || isupper(prev_data[0]) ||
			prev_data[0] == '}' || prev_data[0] == ']' ||
			prev_data[0] == ')' || prev_data[0] == '$') {
			tmp[0] = symbol;
			tmp[1] = next_ch;
			ret = new Token(string(tmp), ctx->finfo);
			ctx->progress = 1;
		}
	}
	return ret;
}

Token *Scanner::scanSymbol(LexContext *ctx, char symbol, char next_ch, char after_next_ch)
{
	Token *ret = NULL;
	if (ctx->token[0] != EOL) ctx->tokens->push_back(scanPrevSymbol(ctx, symbol));
	if (!isRegexStarted) {
		ret = scanTripleCharacterOperator(ctx, symbol, next_ch, after_next_ch);
		if (!ret) ret = scanDoubleCharacterOperator(ctx, symbol, next_ch);
	}
	if (!ret) ret = scanCurSymbol(ctx, symbol);
	return ret;
}

Token *Scanner::scanSymbol(LexContext *ctx, char symbol, char next_ch)
{
	if (ctx->token[0] != EOL) ctx->tokens->push_back(scanPrevSymbol(ctx, symbol));
	Token *ret = (!isRegexStarted) ?
		scanDoubleCharacterOperator(ctx, symbol, next_ch) : NULL;
	return (ret) ? ret : scanCurSymbol(ctx, symbol);
}

Token *Scanner::scanSymbol(LexContext *ctx, char symbol)
{
	if (ctx->token[0] != EOL) ctx->tokens->push_back(scanPrevSymbol(ctx, symbol));
	return scanCurSymbol(ctx, symbol);
}

#define NEXT() (*(src + i++))
#define PREDICT() (*(src + i))
Token *Scanner::scanNumber(LexContext *ctx, char *src, size_t &i)
{
	char *begin = src + i;
	int c = NEXT();
	Token *token = NULL;
	assert((c == '.' || ('0' <= c && c <= '9')) && "It do not seem as Number");
	bool isFloat = false;
	if ('0' <= c && c <= '9') {
		/* first char */
		if ('0' <= c && c <= '9' && c != EOL) c = NEXT();
		/* second char is includes 'b' or 'x' */
		if ((('0' <= c && c <= '9') || c == 'b' || c == 'x') && c != EOL) c = NEXT();
		for (;(('0' <= c && c <= '9') ||
			   ('a' <= c && c <= 'f') ||
			   ('A' <= c && c <= 'F')) && c != EOL; c = NEXT()) {}
	}
	if (c != '.' && c != 'e' && c != 'E') {
		goto L_emit;
	}
	if (c == '.') {
		c = PREDICT();
		if (c == '.') {
			goto L_emit; /* Number .. */
		}
		isFloat = true;
		for (; '0' <= c && c <= '9' && c != EOL; c = NEXT()) {}
	}
	if (c == 'e' || c == 'E') {
		isFloat = true;
		c = NEXT();
		if (c == '+' || c == '-') {
			c = NEXT();
		}
		for (; '0' <= c && c <= '9' && c != EOL; c = NEXT()) {}
	}
	L_emit:;
	i -= 1;
	token = new Token(string(begin, src+i), ctx->finfo);
	token->info = isFloat ? getTokenInfo(TokenType::Double) : getTokenInfo(TokenType::Int);
	return token;
}
#undef NEXT
#undef PREDICT

bool Scanner::isSkip(LexContext *ctx, char *script, size_t idx)
{
	using namespace Enum::Lexer::Token;
	bool ret = commentFlag;
	if (script[idx] == '=' && idx + 1 < ctx->max_token_size &&
		0 < idx && script[idx - 1] == '\n' && isalnum(script[idx + 1])) {
		//multi-line comment flag
		if (idx + 3 < ctx->max_token_size &&
			script[idx + 1] == 'c' && script[idx + 2] == 'u' && script[idx + 3] == 't')  {
			DBG_PL("commentFlag => OFF");
			ctx->progress = 4;
			commentFlag = false;
			ret = false;
			ctx->finfo.start_line_num++;
		} else {
			DBG_PL("commentFlag => ON");
			commentFlag = true;
			ret = true;
		}
	} else if (here_document_tag != "__END__" &&
			   0 < idx && script[idx - 1] == '\n' && idx + 6 < ctx->max_token_size &&
			   script[idx] == '_' && script[idx+1] == '_' &&
			   script[idx+2] == 'E' && script[idx+3] == 'N' && script[idx+4] == 'D' &&
			   script[idx+5] == '_' && script[idx+6] == '_') {
		/* __END__ */
		int progress_to_end = ctx->max_token_size - idx - 1;
		ctx->progress = progress_to_end;
		ret = false;
	} else if (here_document_tag != "__DATA__" &&
			   0 < idx && script[idx-1] == '\n' && idx + 7 < ctx->max_token_size &&
			   script[idx] == '_' && script[idx+1] == '_' &&
			   script[idx+2] == 'D' && script[idx+3] == 'A' && script[idx+4] == 'T' && script[idx+5] == 'A' &&
			   script[idx+6] == '_' && script[idx+7] == '_') {
		/* __DATA__ */
		int progress_to_end = ctx->max_token_size - idx - 1;
		ctx->progress = progress_to_end;
		ret = false;
    } else if (isRegexStarted) {
		if ((0 < idx && script[idx - 1] != '\\') ||
			((0 < idx && script[idx - 1] == '\\') && (1 < idx && script[idx - 2] == '\\'))) {
			switch (script[idx]) {
			case '{': brace_count_inner_regex++;
				break;
			case '}': brace_count_inner_regex--;
				break;
			case '[': bracket_count_inner_regex++;
				break;
			case ']': bracket_count_inner_regex--;
				break;
			case '(': cury_brace_count_inner_regex++;
				break;
			case ')': cury_brace_count_inner_regex--;
				break;
			default:
				break;
			}
		}
		if ((0 < idx && script[idx - 1] == '\\') && (1 < idx && script[idx - 2] != '\\')) {
			ctx->writeChar(ctx->token, script[idx]);
			ret = true;
		} else if (script[idx] != regex_delim && script[idx] != regex_middle_delim) {
			ctx->writeChar(ctx->token, script[idx]);
			ret = true;
		} else if (script[idx] == regex_middle_delim) {
			if ((regex_middle_delim == '}' && brace_count_inner_regex != 0) ||
				(regex_middle_delim == ')' && cury_brace_count_inner_regex != 0) ||
				(regex_middle_delim == ']' && bracket_count_inner_regex != 0)) {
				ctx->writeChar(ctx->token, script[idx]);
				ret = true;
			} else {
				Token *tk = NULL;
				if (regex_middle_delim != '{' &&
					regex_middle_delim != '(' &&
					regex_middle_delim != '<' &&
					regex_middle_delim != '[') {
					tk = new Token(string(ctx->token), ctx->finfo);
					tk->info = getTokenInfo(RegReplaceFrom);
					ctx->clearToken(ctx->token);
					ctx->tokens->push_back(tk);
				}
				char tmp[2] = {regex_middle_delim, 0};
				tk = new Token(string(tmp), ctx->finfo);
				tk->info = getTokenInfo(RegMiddleDelim);
				ctx->tokens->push_back(tk);
				switch (regex_middle_delim) {
				case '}':
					regex_middle_delim = '{';
					break;
				case ')':
					regex_middle_delim = '(';
					break;
				case '>':
					regex_middle_delim = '<';
					break;
				case ']':
					regex_middle_delim = '[';
					break;
				default:
					regex_middle_delim = '\0';
					break;
				}
				ret = true;
			}
		} else {
			if ((regex_delim == '}' && brace_count_inner_regex != 0) ||
				(regex_delim == ')' && cury_brace_count_inner_regex != 0) ||
				(regex_delim == ']' && bracket_count_inner_regex != 0)) {
				ctx->writeChar(ctx->token, script[idx]);
				ret = true;
			} else {
				Token *tk = new Token(string(ctx->token), ctx->finfo);
				Token *prev_tk = ctx->tokens->back();
				tk->info = (prev_tk->info.type == RegMiddleDelim) ? getTokenInfo(RegReplaceTo) : getTokenInfo(RegExp);
				ctx->clearToken(ctx->token);
				ctx->tokens->push_back(tk);
				ret = false;
				isRegexStarted = false;
				regex_delim = 0;
				brace_count_inner_regex = 0;
				cury_brace_count_inner_regex = 0;
				bracket_count_inner_regex = 0;
			}
		}
	} else if (isPrototypeStarted) {
		if (script[idx] == ')') {
			Token *tk = new Token(string(ctx->token), ctx->finfo);
			tk->info = getTokenInfo(Prototype);
			ctx->clearToken(ctx->token);
			ctx->tokens->push_back(tk);
			isPrototypeStarted = false;
			ret = false;
		} else {
			ctx->writeChar(ctx->token, script[idx]);
			ret = true;
		}
	} else if (isStringStarted) {
		if (script[idx] == start_string_ch &&
			(((0 < idx && script[idx - 1] == '\\') && (1 < idx && script[idx - 2] == '\\')) ||
			 (0 < idx && script[idx-1] != '\\'))) {
			ret = false;
		} else {
			ctx->writeChar(ctx->token, script[idx]);
			ret = true;
		}
	} else if (hereDocumentFlag) {
		size_t len = here_document_tag.size();
		if (0 < idx && script[idx - 1] == '\n' &&
			idx + len < ctx->max_token_size) {
			size_t i;
			for (i = 0; i < len && script[idx + i] == here_document_tag.at(i); i++) {}
			if (i == len) {
				ctx->progress = len;
				Token *tk = new Token(string(ctx->token), ctx->finfo);
				tk->info = getTokenInfo(TokenType::HereDocument);
				ctx->clearToken(ctx->token);
				ctx->tokens->push_back(tk);
				tk = new Token(here_document_tag, ctx->finfo);
				tk->info = getTokenInfo(TokenType::HereDocumentEnd);
				ctx->tokens->push_back(tk);
				ctx->finfo.start_line_num++;
				here_document_tag = "";
				hereDocumentFlag = false;
				ret = false;
			} else {
				ctx->writeChar(ctx->token, script[idx]);
				ret = true;
			}
		} else {
			ctx->writeChar(ctx->token, script[idx]);
			ret = true;
		}
	}
	return ret;
}

TokenInfo Scanner::getTokenInfo(TokenType::Type type)
{
	size_t i = 0;
	for (; decl_tokens[i].type != TokenType::Undefined; i++) {
		if (type == decl_tokens[i].type) {
			return decl_tokens[i];
		}
	}
	return decl_tokens[i];
}

TokenInfo Scanner::getTokenInfo(const char *data)
{
	size_t i = 0;
	size_t dsize = strlen(data);
	for (; decl_tokens[i].type != TokenType::Undefined; i++) {
		const char *token_data = decl_tokens[i].data;
		size_t tsize = strlen(token_data);
		if (dsize == tsize && !strncmp(token_data, data, dsize)) {
			return decl_tokens[i];
		}
	}
	return decl_tokens[i];
}
