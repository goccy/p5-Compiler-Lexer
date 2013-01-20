#include <lexer.hpp>
#include <cassert>

/* Declare Namespace */
using namespace std;
namespace TokenType = Enum::Lexer::Token;
namespace SyntaxType = Enum::Lexer::Syntax;
namespace TokenKind = Enum::Lexer;

Token::Token(string data_, FileInfo finfo_) :
	data(data_), token_num(0), total_token_num(0),
	deparsed_data(""), isDeparsed(false), isDeleted(false)
{
	type = TokenType::Undefined;
	stype = SyntaxType::Value;
	info.type = TokenType::Undefined;
	info.kind = TokenKind::Undefined;
	finfo.start_line_num = finfo_.start_line_num;
	finfo.end_line_num = finfo_.start_line_num;
	finfo.filename = finfo_.filename;
	finfo.indent = 0;
}

Token::Token(Tokens *tokens) :
	data(""), isDeparsed(false), isDeleted(false)
{
	total_token_num = 0;
	stype = SyntaxType::Value;
	type =  TokenType::Undefined;
	info.type = TokenType::Undefined;
	info.kind = TokenKind::Undefined;
	size_t size = tokens->size();
	TokenPos pos = tokens->begin();
	tks = (Token **)safe_malloc(size * PTR_SIZE);
	token_num = size;
	size_t i = 0;
	size_t end_line_num = 0;
	finfo.indent = 0;
	for (; i < size; i++) {
		Token *t = (Token *)*pos;
		tks[i] = t;
		if (i == 0) {
			finfo.start_line_num = tks[i]->finfo.start_line_num;
			finfo.filename = tks[i]->finfo.filename;
		}
		if (t->total_token_num > 1) {
			total_token_num += t->total_token_num;
			if (end_line_num < t->finfo.end_line_num) {
				end_line_num = t->finfo.end_line_num;
			}
		} else {
			total_token_num += 1;
			if (end_line_num < t->finfo.start_line_num) {
				end_line_num = t->finfo.start_line_num;
			}
		}
		pos++;
	}
	finfo.end_line_num = end_line_num;
}

/*

Token::~Token(void)
{
	for (size_t i = 0; i < this->token_num; i++) {
		Token **tks = this->tks;
		if (!tks[i]->isDeleted) {
			delete tks[i];
			tks[i] = NULL;
		}
	}
	this->token_num = 0;
	isDeleted = true;
	//safe_free(tks, PTR_SIZE * this->token_num);
}
*/

const char *Token::deparse(void)
{
	using namespace TokenType;
	if (isDeparsed) return cstr(deparsed_data);
	isDeparsed = true;
	if (this->token_num > 0) {
		for (size_t i = 0; i < this->token_num; i++) {
			deparsed_data += string(this->tks[i]->deparse());
		}
	} else {
		switch (info.type) {
		case String:
			deparsed_data += " \"" + this->data + "\"";
			break;
		case RawString:
			deparsed_data += " '" + this->data + "'";
			break;
		case ExecString:
			deparsed_data += " `" + this->data + "`";
			break;
		case RegReplaceFrom: case RegReplaceTo:
		case RegMiddleDelim: case RegDelim:
		case RegExp:         case RegOpt:
			deparsed_data += this->data;
			break;
		case HereDocument:
			deparsed_data += "\n" + this->data;
			break;
		case HereDocumentEnd:
			deparsed_data += this->data + "\n";
			break;
		default:
			deparsed_data += " " + this->data;
			break;
		}
	}
	return cstr(deparsed_data);
}

Lexer::Lexer(const char *filename) :
	isStringStarted(false), isRegexStarted(false), commentFlag(false), hereDocumentFlag(false),
	regex_delim(0), regex_middle_delim(0),
    brace_count_inner_regex(0), bracket_count_inner_regex(0), cury_brace_count_inner_regex(0)
{
	finfo.start_line_num = 1;
	finfo.filename = filename;
}

/*
Lexer::~Lexer(void)
{
}
*/
void Lexer::writeChar(LexContext *ctx, char *token, char ch)
{
	token[ctx->token_idx] = ch;
	ctx->token_idx++;
}

void Lexer::clearToken(LexContext *ctx, char *token)
{
	memset(token, 0, ctx->max_token_size);
	ctx->token_idx = 0;
}

Token *Lexer::scanQuote(LexContext *ctx, char quote)
{
	Token *ret = NULL;
	if (isStringStarted) {
		ret = new Token(string(ctx->token), finfo);
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
		clearToken(ctx, ctx->token);
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

bool Lexer::scanNegativeNumber(LexContext *ctx, char number)
{
	char num_buffer[2] = {0};
	if (number != EOL && !isStringStarted) {
		num_buffer[0] = number;
		if (atoi(num_buffer) > 0) {
			//negative number
			writeChar(ctx, ctx->token, '-');
			return true;
		}
	}
	return false;
}

Token *Lexer::scanPrevSymbol(LexContext *ctx, char symbol)
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
		prev_before_tk_data != "*" &&
		prev_before_tk_type != TokenType::RegDelim &&
		(prev_token == "q"  || prev_token == "qq" ||
		 prev_token == "qw" || prev_token == "qx" ||
		 prev_token == "qr" || prev_token == "m")) {
		//RegexPrefix
		ret = new Token(string(token), finfo);
		ret->info = getTokenInfo(cstr(prev_token));
		clearToken(ctx, token);
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
			   prev_before_tk_data != "*" &&
			   prev_before_tk_type != TokenType::RegDelim &&
			   (prev_token == "s"  ||
				prev_token == "y"  ||
				prev_token == "tr")) {
		//ReplaceRegexPrefix
		ret = new Token(string(token), finfo);
		ret->info = getTokenInfo(cstr(prev_token));
		clearToken(ctx, token);
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
	} else {
		ret = new Token(string(token), finfo);
		if (prev_before_tk_data == "<<" && (isupper(token[0]) || token[0] == '_')) {
			/* Key is HereDocument */
			here_document_tag = token;
			ret->info = getTokenInfo(TokenType::HereDocumentRawTag);
		}
		clearToken(ctx, token);
	}
	return ret;
}

bool Lexer::isRegexDelim(Token *prev_token, char symbol)
{
	const char *prev_data = (prev_token) ? cstr(prev_token->data) : "";
	/* [^0-9] && !"0" && !CONST && !{hash} && ![array] && !func() && !$var */
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


Token *Lexer::scanCurSymbol(LexContext *ctx, char symbol)
{
	Token *ret = NULL;
	char *token = ctx->token;
	char tmp[2] = {0};
	tmp[0] = symbol;
	Token *prev_tk = (ctx->tokens->size() > 0) ? ctx->tokens->back() : NULL;
	//const char *prev_data = (prev_tk) ? cstr(prev_tk->data) : "";
	if (isRegexDelim(prev_tk, symbol)/* &&
		strtod(prev_data, NULL) == 0 && string(prev_data) != "0" && !isupper(prev_data[0]) &&
		prev_data[0] != '}' && prev_data[0] != ']' && prev_data[0] != ')' && prev_data[0] != '$'*/) {
		ret = new Token(string(tmp), finfo);
		ret->info = getTokenInfo(TokenType::RegDelim);
		clearToken(ctx, token);
		regex_delim = '/';
		if (prev_tk->info.type != TokenType::RegExp &&
			prev_tk->info.type != TokenType::RegReplaceTo) {
			isRegexStarted = true;
		}
	} else if (isRegexStarted ||
			   (prev_tk && prev_tk->info.type == TokenType::RegExp) ||
			   (prev_tk && prev_tk->info.type == TokenType::RegReplaceTo)) {
		ret = new Token(string(tmp), finfo);
		ret->info = getTokenInfo(TokenType::RegDelim);
		clearToken(ctx, token);
	} else if (symbol == '@' || symbol == '$') {
		//for array value
		writeChar(ctx, token, symbol);
	} else if (symbol == ';') {
		ret = new Token(string(tmp), finfo);
		clearToken(ctx, token);
	} else {
		ret = new Token(string(tmp), finfo);
		clearToken(ctx, token);
	}
	return ret;
}

Token *Lexer::scanTripleCharacterOperator(LexContext *ctx, char symbol, char next_ch, char after_next_ch)
{
	Token *ret = NULL;
	char tmp[4] = {0};
	if ((symbol == '<' && next_ch == '=' && after_next_ch == '>') ||
		(symbol == '*' && next_ch == '*' && after_next_ch == '=') ||
		(symbol == '/' && next_ch == '/' && after_next_ch == '=') ||
		(symbol == '|' && next_ch == '|' && after_next_ch == '=') ||
		(symbol == '&' && next_ch == '&' && after_next_ch == '=') ||
		(symbol == '.' && next_ch == '.' && after_next_ch == '.') ||
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
		ret = new Token(string(tmp), finfo);
		ctx->progress = 2;
	}
	return ret;
}

Token *Lexer::scanDoubleCharacterOperator(LexContext *ctx, char symbol, char next_ch)
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
		ret = new Token(string(tmp), finfo);
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
		ret = new Token(string(tmp), finfo);
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
			ret = new Token(string(tmp), finfo);
			ctx->progress = 1;
		}
	}
	return ret;
}

Token *Lexer::scanSymbol(LexContext *ctx, char symbol, char next_ch, char after_next_ch)
{
	Token *ret = NULL;
	char *token = ctx->token;
	if (token[0] != EOL) {
		Token *tk = scanPrevSymbol(ctx, symbol);
		ctx->tokens->push_back(tk);
	}
	if (!isRegexStarted) {
		ret = scanTripleCharacterOperator(ctx, symbol, next_ch, after_next_ch);
		if (!ret) ret = scanDoubleCharacterOperator(ctx, symbol, next_ch);
	}
	if (!ret) ret = scanCurSymbol(ctx, symbol);
	return ret;
}

Token *Lexer::scanSymbol(LexContext *ctx, char symbol, char next_ch)
{
	Token *ret = NULL;
	char *token = ctx->token;
	if (token[0] != EOL) {
		Token *tk = scanPrevSymbol(ctx, symbol);
		ctx->tokens->push_back(tk);
	}
	if (!isRegexStarted) {
		ret = scanDoubleCharacterOperator(ctx, symbol, next_ch);
	}
	if (!ret) ret = scanCurSymbol(ctx, symbol);
	return ret;
}

Token *Lexer::scanSymbol(LexContext *ctx, char symbol)
{
	Token *ret = NULL;
	char *token = ctx->token;
	if (token[0] != EOL) {
		Token *tk = scanPrevSymbol(ctx, symbol);
		ctx->tokens->push_back(tk);
	}
	ret = scanCurSymbol(ctx, symbol);
	return ret;
}

#define NEXT() (*(src + i++))
#define PREDICT() (*(src + i))
#define NCHAR() (*(src+i+1))
Token *Lexer::scanNumber(LexContext *, char *src, size_t &i)
{
	char *begin = src + i;
	int c = NEXT();
	Token *token = NULL;
	assert((c == '.' || ('0' <= c && c <= '9')) && "It do not seem as Number");
	bool isFloat = false;
	if (c == '0') {
		c = NEXT();
	} else if ('1' <= c && c <= '9') {
		for (; '0' <= c && c <= '9' && c != EOL; c = NEXT()) {}
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
	token = new Token(string(begin, src+i), finfo);
	token->info = isFloat ? getTokenInfo(TokenType::Double) : getTokenInfo(TokenType::Int);
	return token;
}
#undef NEXT
#undef PREDICT

bool Lexer::isSkip(LexContext *ctx, char *script, size_t idx)
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
			finfo.start_line_num++;
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
			writeChar(ctx, ctx->token, script[idx]);
			ret = true;
		} else if (script[idx] != regex_delim && script[idx] != regex_middle_delim) {
			writeChar(ctx, ctx->token, script[idx]);
			ret = true;
		} else if (script[idx] == regex_middle_delim) {
			if ((regex_middle_delim == '}' && brace_count_inner_regex != 0) ||
				(regex_middle_delim == ')' && cury_brace_count_inner_regex != 0) ||
				(regex_middle_delim == ']' && bracket_count_inner_regex != 0)) {
				writeChar(ctx, ctx->token, script[idx]);
				ret = true;
			} else {
				Token *tk = NULL;
				if (regex_middle_delim != '{' &&
					regex_middle_delim != '(' &&
					regex_middle_delim != '<' &&
					regex_middle_delim != '[') {
					tk = new Token(string(ctx->token), finfo);
					tk->info = getTokenInfo(RegReplaceFrom);
					clearToken(ctx, ctx->token);
					ctx->tokens->push_back(tk);
				}
				char tmp[] = {regex_middle_delim};
				tk = new Token(string(tmp), finfo);
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
				writeChar(ctx, ctx->token, script[idx]);
				ret = true;
			} else {
				Token *tk = new Token(string(ctx->token), finfo);
				Token *prev_tk = ctx->tokens->back();
				tk->info = (prev_tk->info.type == RegMiddleDelim) ? getTokenInfo(RegReplaceTo) : getTokenInfo(RegExp);
				clearToken(ctx, ctx->token);
				ctx->tokens->push_back(tk);
				ret = false;
				isRegexStarted = false;
				brace_count_inner_regex = 0;
				cury_brace_count_inner_regex = 0;
				bracket_count_inner_regex = 0;
			}
		}
	} else if (isStringStarted) {
		if (script[idx] == start_string_ch &&
			(((0 < idx && script[idx - 1] == '\\') && (1 < idx && script[idx - 2] == '\\')) ||
			 (0 < idx && script[idx-1] != '\\'))) {
			ret = false;
		} else {
			writeChar(ctx, ctx->token, script[idx]);
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
				Token *tk = new Token(string(ctx->token), finfo);
				tk->info = getTokenInfo(TokenType::HereDocument);
				clearToken(ctx, ctx->token);
				ctx->tokens->push_back(tk);
				tk = new Token(here_document_tag, finfo);
				tk->info = getTokenInfo(TokenType::HereDocumentEnd);
				ctx->tokens->push_back(tk);
				//tk = new Token(here_document_tag, finfo);
				//tk->info = getTokenInfo(TokenType::SemiColon);
				//ctx->tokens->push_back(tk);
				finfo.start_line_num++;
				here_document_tag = "";
				hereDocumentFlag = false;
				ret = false;
			} else {
				writeChar(ctx, ctx->token, script[idx]);
				ret = true;
			}
		} else {
			writeChar(ctx, ctx->token, script[idx]);
			ret = true;
		}
	}
	return ret;
}

#define CHECK_CH(i, ch) (i < script_size && script[i] == ch)
Tokens *Lexer::tokenize(char *script)
{
	using namespace Enum::Lexer::Char;
	size_t i = 0;
	LexContext ctx;
	size_t script_size = strlen(script) + 1;
	size_t max_token_size = script_size;
	Tokens *tokens = new Tokens();
	char *token = (char *)safe_malloc(max_token_size);
	ctx.token = token;
	ctx.tokens = tokens;
	ctx.max_token_size = max_token_size;
	ctx.token_idx = 0;
	ctx.progress = 0;
	char ch;
	Token *tk = NULL;
	while ((ch = script[i]) != EOL) {
		if (ch == '\n') finfo.start_line_num++;
		if (isSkip(&ctx, script, i)) {
			i++;
			continue;
		} else {
			i += ctx.progress;
			ctx.progress = 0;
			if (script[i] == EOL) break;
		}
		switch (ch) {
		case '"': case '\'': case '`':
			tk = scanQuote(&ctx, ch);
			if (tk) tokens->push_back(tk);
			break;
		case ' ': case '\t':
			if (token[0] != EOL) {
				tk = new Token(string(token), finfo);
				Token *prev_tk = (tokens->size() > 0) ? tokens->back() : NULL;
				string prev_tk_data = "";
				if (prev_tk) {
					prev_tk_data = prev_tk->data;
				}
				if (prev_tk_data == "<<" &&
					strtod(token, NULL) == 0 && string(token) != "0" &&
					(isupper(token[0]) || token[0] == '_')) {
					/* Key is HereDocument */
					here_document_tag = token;
					tk->info = getTokenInfo(TokenType::HereDocumentRawTag);
				}
				clearToken(&ctx, token);
				if (tk) tokens->push_back(tk);
			}
			break;
		case '\\':
			if (CHECK_CH(i+1, '$') || CHECK_CH(i+1, '@') ||
				CHECK_CH(i+1, '%') || CHECK_CH(i+1, '&')) {
				tokens->push_back(new Token(string("\\") + string(1, script[i+1]), finfo));
				i++;
			}
			break;
		case '#': {
#ifdef ENABLE_ANNOTATION
			if (CHECK_CH(i+1, '@')) {
				tokens->push_back(new Token(string("#@"), finfo));
				i++;
				break;
			}
#endif
			if (token[0] != EOL) {
				Token *tk = scanPrevSymbol(&ctx, '#');
				tokens->push_back(tk);
			}
			Token *prev_tk = (tokens->size() > 0) ? tokens->back() : NULL;
			if (isRegexStarted ||
				(prev_tk && prev_tk->info.type == TokenType::RegExp) ||
				(prev_tk && prev_tk->info.type == TokenType::RegReplaceTo)) {
				char tmp[2] = {'#'};
				Token *tk = new Token(string(tmp), finfo);
				tk->info = getTokenInfo(TokenType::RegDelim);
				clearToken(&ctx, token);
				tokens->push_back(tk);
				break;
			}
			while (script[i] != '\n' && i < script_size) {i++;}
			finfo.start_line_num++;
			break;
		}
		case '-':
			if (scanNegativeNumber(&ctx, script[i + 1])) {
				break;
			}
			//fall through
		case '.':
			if (ctx.token_idx == 0 && i + 1 < script_size &&
				'0' <= script[i+1] && script[i+1] <= '9') {
				// .01234
				tk = scanNumber(&ctx, script, i);
				tokens->push_back(tk);
				clearToken(&ctx, ctx.token);
				continue;
			}
			//fall through
		case '=': case '^': case '~': case '@':
		case ',': case ':': case ';': case '+':
		case '<': case '>': case '&': case '|':
		case '!': case '*': case '/':
		case '(': case ')': case '{': case '}':
		case '[': case ']': case '?': case '$': {
			if (i + 2 < script_size) {
				tk = scanSymbol(&ctx, script[i], script[i + 1], script[i + 2]);
				i += ctx.progress;
				ctx.progress = 0;
				if (tk) tokens->push_back(tk);
			} else if (i + 1 < script_size) {
				tk = scanSymbol(&ctx, script[i], script[i + 1]);
				i += ctx.progress;
				ctx.progress = 0;
				if (tk) tokens->push_back(tk);
			} else {
				tk = scanSymbol(&ctx, script[i]);
				if (tk) tokens->push_back(tk);
			}
			break;
		}
		case '\n':
			if (ctx.token_idx > 0) {
				Token *prev_tk = (tokens->size() > 0) ? tokens->back() : NULL;
				string prev_tk_data = "";
				tokens->push_back(new Token(token, finfo));
				if (prev_tk) {
					prev_tk_data = prev_tk->data;
				}
				if (prev_tk_data == "<<" &&
					strtod(token, NULL) == 0 && string(token) != "0" &&
					(isupper(token[0]) || token[0] == '_')) {
					/* Key is HereDocument */
					tk->info = getTokenInfo(TokenType::HereDocumentRawTag);
					here_document_tag = token;
				}
				clearToken(&ctx, ctx.token);
			}
			if (here_document_tag != "") hereDocumentFlag = true;
			break;
		case '0': case '1': case '2': case '3': case '4':
		case '5': case '6': case '7': case '8': case '9':
			if (ctx.token_idx == 0 || (ctx.token_idx == 1 && token[0] == '-')) {
				tk = scanNumber(&ctx, script, i);
				if (token[0] == '-') tk->data = "-" + tk->data;
				tokens->push_back(tk);
				clearToken(&ctx, ctx.token);
				continue;
			}
		default:
			writeChar(&ctx, ctx.token, script[i]);
			break;
		}
		i++;
	}
	//safe_free(token, max_token_size);
	return tokens;
}

#define ITER_CAST(T, it) (T)*(it)

void Lexer::dump(Tokens *tokens)
{
	TokenPos it = tokens->begin();
	while (it != tokens->end()) {
		Token *t = ITER_CAST(Token *, it);
		fprintf(stdout, "[%-12s] : %12s \n", cstr(t->data), t->info.name);
		it++;
	}
}

TokenInfo Lexer::getTokenInfo(TokenType::Type type)
{
	size_t i = 0;
	for (; decl_tokens[i].type != TokenType::Undefined; i++) {
		if (type == decl_tokens[i].type) {
			return decl_tokens[i];
		}
	}
	return decl_tokens[i];
}

TokenInfo Lexer::getTokenInfo(const char *data)
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

bool Lexer::isReservedKeyword(std::string word)
{
	for (int i = 0; decl_tokens[i].type != TokenType::Undefined; i++) {
		if (word == decl_tokens[i].data) {
			return true;
		}
	}
	return false;
}

void Lexer::annotateTokens(Tokens *tokens)
{
	using namespace TokenType;
	TokenPos it = tokens->begin();
	vector<string> vardecl_list;
	vector<string> funcdecl_list;
	vector<string> pkgdecl_list;
	int cur_type = 0;
	while (it != tokens->end()) {
		Token *t = ITER_CAST(Token *, it);
		Token *next_token = ITER_CAST(Token *, it+1);
		string data = t->data;
		//fprintf(stdout, "TOKEN = [%s]\n", cstr(data));
		if (t->info.type != Undefined) {
			cur_type = t->info.type;
		} else if (isReservedKeyword(data) && cur_type != FunctionDecl) {
			t->info = getTokenInfo(cstr(data));
			cur_type = t->info.type;
		} else if (cur_type == FunctionDecl && data == "{") {
			t->info = getTokenInfo(cstr(data));
			cur_type = t->info.type;
		} else if (cur_type == VarDecl && t->data.find("$") != string::npos) {
			t->info = getTokenInfo(LocalVar);
			vardecl_list.push_back(t->data);
			cur_type = LocalVar;
		} else if (cur_type == VarDecl && t->data.find("@") != string::npos) {
			t->info = getTokenInfo(LocalArrayVar);
			vardecl_list.push_back(t->data);
			cur_type = LocalArrayVar;
		} else if (cur_type == VarDecl && t->data.find("%") != string::npos) {
			t->info = getTokenInfo(LocalHashVar);
			vardecl_list.push_back(t->data);
			cur_type = LocalHashVar;
		} else if (search(vardecl_list, t->data)) {
			if (t->data.find("@") != string::npos) {
				t->info = getTokenInfo(ArrayVar);
				cur_type = ArrayVar;
			} else if (t->data.find("%") != string::npos) {
				t->info = getTokenInfo(HashVar);
				cur_type = HashVar;
			} else {
				t->info = getTokenInfo(Var);
				cur_type = Var;
			}
		} else if (t->data.find("$") != string::npos) {
			t->info = getTokenInfo(GlobalVar);
			vardecl_list.push_back(t->data);
			cur_type = GlobalVar;
		} else if (t->data.find("@") != string::npos) {
			t->info = getTokenInfo(GlobalArrayVar);
			vardecl_list.push_back(t->data);
			cur_type = GlobalArrayVar;
		} else if (t->data.find("%") != string::npos) {
			t->info = getTokenInfo(GlobalHashVar);
			vardecl_list.push_back(t->data);
			cur_type = GlobalHashVar;
		} else if (t->info.type == Double) {
			cur_type = Double;
		} else if (t->info.type == Int) {
			cur_type = Int;
		} else if (t->data == "0" || atoi(cstr(t->data)) != 0) {
			if (t->info.type == String) {
				cur_type = 0; it++;
				continue;
			}
			if (t->data.find(".") != string::npos) {
				t->info = getTokenInfo(Double);
				cur_type = Double;
			} else {
				t->info = getTokenInfo(Int);
				cur_type = Int;
			}
		} else if (cur_type == FunctionDecl) {
			t->info = getTokenInfo(Function);
			cur_type = Function;
			funcdecl_list.push_back(t->data);
		} else if (cur_type == RegDelim) {
			t->info = getTokenInfo(RegOpt);
			cur_type = RegOpt;
		} else if (search(funcdecl_list, t->data)) {
			t->info = getTokenInfo(Call);
			cur_type = Call;
		} else if (cur_type == Package) {
			t->info = getTokenInfo(Class);
			pkgdecl_list.push_back(t->data);
		} else if (search(pkgdecl_list, t->data)) {
			t->info = getTokenInfo(Class);
		} else if (it+1 != tokens->end() && next_token->data == "::") {
			t->info = getTokenInfo(Namespace);
			cur_type = Namespace;
		} else if (cur_type == NamespaceResolver) {
			t->info = getTokenInfo(Namespace);
			cur_type = Namespace;
		} else if (data == "\n") {
			tokens->erase(it);
			it--;
		} else {
			t->info = getTokenInfo(Key);
			cur_type = Key;
		}
		it++;
	}
}

void Lexer::grouping(Tokens *tokens)
{
	using namespace TokenType;
	TokenPos pos = tokens->begin();
	string ns = "";
	Token *next_tk = NULL;
	while (pos != tokens->end()) {
		Token *tk = ITER_CAST(Token *, pos);
		if (!tk) break;
		switch (tk->info.type) {
		case Var: case GlobalVar: case GlobalHashVar:
		case Namespace: case Class: case CORE: {
			Token *ns_token = tk;
			TokenPos start_pos = pos+1;
			size_t move_count = 0;
			do {
				tk = ITER_CAST(Token *, pos);
				if (tk) ns += tk->data;
				else break;
				pos++;
				move_count++;
				next_tk = ITER_CAST(Token *, pos);
			} while ((tk->info.type == NamespaceResolver &&
					 (next_tk && next_tk->info.kind != TokenKind::Symbol &&
					  next_tk->info.kind != TokenKind::StmtEnd)) ||
					 (next_tk && next_tk->info.type == NamespaceResolver));
			TokenPos end_pos = pos;
			pos -= move_count;
			ns_token->data = ns;
			ns = "";
			tokens->erase(start_pos, end_pos);
			break;
		}
		case ArraySize: {
			Token *as_token = tk;
			Token *next_tk = ITER_CAST(Token *, pos+1);
			if (next_tk->info.type == Key) {
				as_token->data += next_tk->data;
				tokens->erase(pos+1);
			}
			break;
		}
		default:
			break;
		}
		pos++;
	}
}

bool Lexer::search(vector<string> list, string target)
{
	bool ret = false;
	vector<string>::iterator it = find(list.begin(), list.end(), target);
	if (it != list.end()){
		ret = true;
	}
	return ret;
}

void Lexer::escapeQuotation(string *from, char quote)
{
	size_t len = from->length();
	for (size_t i = 0; i < len; i++) {
		if ((*from)[i] == quote) {
			from->insert(i, 1, '\\');
			i++;
		}
	}
}

void Lexer::prepare(Tokens *tokens)
{
	pos = tokens->begin();
	start_pos = pos;
	TokenPos it = tokens->begin();
	TokenPos tag_pos = start_pos;
	while (it != tokens->end()) {
		Token *t = ITER_CAST(Token *, it);
		switch (t->info.type) {
		case TokenType::HereDocumentTag: case TokenType::HereDocumentRawTag:
			tag_pos = it;
			break;
		case TokenType::HereDocument:
			if (tag_pos == start_pos) {
				fprintf(stderr, "ERROR!: nothing use HereDocumentTag\n");
				exit(EXIT_FAILURE);
			} else {
				Token *tag = ITER_CAST(Token *, tag_pos);
				switch (tag->info.type) {
				case TokenType::HereDocumentTag:
					tag->info = getTokenInfo(TokenType::String);
					escapeQuotation(&t->data, '"');
					break;
				case TokenType::HereDocumentRawTag:
					tag->info = getTokenInfo(TokenType::RawString);
					escapeQuotation(&t->data, '\'');
					break;
				default:
					break;
				}
				tag->data = t->data;
				tokens->erase(tag_pos-1);
				tokens->erase(it-1);
				it--;
				continue;
			}
			break;
		case TokenType::HereDocumentEnd:
			tokens->erase(it);
			continue;
			break;
		default:
			break;
		}
		it++;
	}
}

bool Lexer::isExpr(Token *tk, Token *prev_tk, Enum::Lexer::Token::Type type, Enum::Lexer::Kind kind)
{
	using namespace TokenType;
	assert(tk->tks[0]->info.type == LeftBrace);
	if (tk->token_num > 3 &&
		(tk->tks[1]->info.type == Key   || tk->tks[1]->info.type == String) &&
		(tk->tks[2]->info.type == Arrow || tk->tks[2]->info.type == Comma)) {
		/* { [key|"key"] [,|=>] value ... */
		return true;
	} else if (type == Pointer || kind == TokenKind::Term || kind == TokenKind::Function || type == FunctionDecl ||
			((prev_tk && prev_tk->stype == SyntaxType::Expr) && (type == RightBrace || type == RightBracket))) {
		/* ->{ or $hash{ or map { or {key}{ or [idx]{ */
		return true;
	}
	return false;
}

Token *Lexer::parseSyntax(Token *start_token, Tokens *tokens)
{
	using namespace TokenType;
	Type prev_type = Undefined;
	TokenKind::Kind prev_kind = TokenKind::Undefined;
	TokenPos end_pos = tokens->end();
	Tokens *new_tokens = new Tokens();
	TokenPos intermediate_pos = pos;
	Token *prev_syntax = NULL;
	if (start_token) {
		new_tokens->push_back(start_token);
		intermediate_pos--;
	}
	while (pos != end_pos) {
		Token *t = ITER_CAST(Token *, pos);
		Type type = t->info.type;
		TokenKind::Kind kind = t->info.kind;
		switch (type) {
		case LeftBracket: case LeftParenthesis:
		case ArrayDereference: case HashDereference: {
			pos++;
			Token *syntax = parseSyntax(t, tokens);
			syntax->stype = SyntaxType::Expr;
			new_tokens->push_back(syntax);
			prev_syntax = syntax;
			break;
		}
		case LeftBrace: {
			Token *prev = ITER_CAST(Token *, pos-1);
			if (prev) prev_type = prev->info.type;
			pos++;
			Token *syntax = parseSyntax(t, tokens);
			if (isExpr(syntax, prev_syntax, prev_type, prev_kind)) {
				syntax->stype = SyntaxType::Expr;
			} else if (prev_kind == TokenKind::Do) {
				syntax->stype = SyntaxType::BlockStmt;
			} else {
				syntax->stype = SyntaxType::BlockStmt;
				Token *next_tk = ITER_CAST(Token *, pos+1);
				if (next_tk && next_tk->info.type != SemiColon) {
					intermediate_pos = pos;
				}
			}
			new_tokens->push_back(syntax);
			prev_syntax = syntax;
			break;
		}
		case RightBrace: case RightBracket: case RightParenthesis:
			new_tokens->push_back(t);
			return new Token(new_tokens);
			break; /* not reached this stmt */
		case SemiColon: {
			size_t k = pos - intermediate_pos;
			if (start_pos == intermediate_pos) k++;
			Tokens *stmt = new Tokens();
			for (size_t j = 0; j < k - 1; j++) {
				Token *tk = new_tokens->back();
				j += (tk->total_token_num > 0) ? tk->total_token_num - 1 : 0;
				stmt->insert(stmt->begin(), tk);
				new_tokens->pop_back();
			}
			stmt->push_back(t);
			Token *stmt_ = new Token(stmt);
			stmt_->stype = SyntaxType::Stmt;
			new_tokens->push_back(stmt_);
			intermediate_pos = pos;
			prev_syntax = stmt_;
			break;
		}
		default:
			new_tokens->push_back(t);
			prev_syntax = NULL;
			break;
		}
		prev_kind = kind;
		prev_type = type;
		pos++;
	}
	return new Token(new_tokens);
}


void Lexer::insertStmt(Token *syntax, int idx, size_t grouping_num)
{
	size_t tk_n = syntax->token_num;
	Token **tks = syntax->tks;
	Token *tk = tks[idx];
	Tokens *stmt = new Tokens();
	stmt->push_back(tk);
	for (size_t i = 1; i < grouping_num; i++) {
		stmt->push_back(tks[idx+i]);
	}
	Token *stmt_ = new Token(stmt);
	stmt_->stype = SyntaxType::Stmt;
	tks[idx] = stmt_;
	if (tk_n == idx+grouping_num) {
		for (size_t i = 1; i < grouping_num; i++) {
			syntax->tks[idx+i] = NULL;
		}
	} else {
		memmove(syntax->tks+idx+1, syntax->tks+idx+grouping_num,
				sizeof(Token *) * (tk_n - (idx+grouping_num)));
		for (size_t i = 1; i < grouping_num; i++) {
			syntax->tks[tk_n-i] = NULL;
		}
	}
	syntax->token_num -= (grouping_num - 1);
}

void Lexer::parseSpecificStmt(Token *syntax)
{
	using namespace TokenType;
	size_t tk_n = syntax->token_num;
	for (size_t i = 0; i < tk_n; i++) {
		Token **tks = syntax->tks;
		Token *tk = tks[i];
		switch (tk->info.type) {
		case IfStmt:    case ElsifStmt: case ForeachStmt:
		case ForStmt:   case WhileStmt: case UnlessStmt:
		case GivenStmt: case UntilStmt: case WhenStmt: {
			if (tk_n > i+2 &&
				tks[i+1]->stype == SyntaxType::Expr &&
				tks[i+2]->stype == SyntaxType::BlockStmt) {
				/* if Expr BlockStmt */
				insertStmt(syntax, i, 3);
				tk_n -= 2;
			} else if ((tk->info.type == ForStmt || tk->info.type == ForeachStmt) &&
					   tk_n > i+3 && tks[i+1]->stype != SyntaxType::Expr) {
				/* for(each) [decl] Term Expr BlockStmt */
				if (tk_n > i+3 &&
					tks[i+1]->info.kind == TokenKind::Term &&
					tks[i+2]->stype == SyntaxType::Expr &&
					tks[i+3]->stype == SyntaxType::BlockStmt) {
					insertStmt(syntax, i, 4);
					tk_n -= 3;
				} else if (tk_n > i+4 &&
					tks[i+1]->info.kind == TokenKind::Decl &&
					tks[i+2]->info.kind == TokenKind::Term &&
					tks[i+3]->stype == SyntaxType::Expr &&
					tks[i+4]->stype == SyntaxType::BlockStmt) {
					insertStmt(syntax, i, 5);
					tk_n -= 4;
				} else {
					//fprintf(stderr, "Syntax Error!: near by line[%lu]\n", tk->finfo.start_line_num);
					//exit(EXIT_FAILURE);
				}
			}
			break;
		}
		case ElseStmt: case Do: case Continue: case DefaultStmt:
			if (tk_n > i+1 && tks[i+1]->stype == SyntaxType::BlockStmt) {
				/* else BlockStmt */
				insertStmt(syntax, i, 2);
				tk_n -= 1;
			}
			break;
		case FunctionDecl:
			if (tk_n > i+2 &&
				tks[i+1]->info.type == Function &&
				tks[i+2]->stype == SyntaxType::BlockStmt) {
				/* sub func BlockStmt */
				insertStmt(syntax, i, 3);
				tk_n -= 2;
			} else if (tk_n > i+3 &&
				tks[i+1]->info.type == Function &&
				tks[i+2]->stype == SyntaxType::Expr &&
				tks[i+3]->stype == SyntaxType::BlockStmt) {
				/* sub func Expr BlockStmt */
				insertStmt(syntax, i, 4);
				tk_n -= 3;
			}
			break;
		default:
			if (tk->stype == SyntaxType::BlockStmt) {
				if (i > 0 &&
					(tks[i-1]->stype == SyntaxType::Stmt ||
					tks[i-1]->stype == SyntaxType::BlockStmt)) {
					/* nameless block */
					insertStmt(syntax, i, 1);
				}
				parseSpecificStmt(tk);
			} else if (tk->stype == SyntaxType::Stmt) {
				parseSpecificStmt(tk);
			}
			break;
		}
	}
}

void Lexer::setIndent(Token *syntax, int indent)
{
	using namespace SyntaxType;
	size_t tk_n = syntax->token_num;
	for (size_t i = 0; i < tk_n; i++) {
		Token *tk = syntax->tks[i];
		switch (tk->stype) {
		case BlockStmt:
			tk->finfo.indent = ++indent;
			setIndent(tk, indent);
			if (indent == 0) {
				fprintf(stderr, "ERROR!!: syntax error near %s:%lu\n", tk->finfo.filename, tk->finfo.start_line_num);
				exit(EXIT_FAILURE);
			}
			indent--;
			break;
		case Expr: case Stmt:
			tk->finfo.indent = indent;
			setIndent(tk, indent);
			break;
		default:
			syntax->tks[i]->finfo.indent = indent;
			break;
		}
	}
}

void Lexer::setBlockIDWithBreadthFirst(Token *syntax, size_t base_id)
{
	using namespace SyntaxType;
	size_t tk_n = syntax->token_num;
	size_t block_num = 0;
	for (size_t i = 0; i < tk_n; i++) {
		Token *tk = syntax->tks[i];
		if (tk->stype == BlockStmt) block_num++;
	}
	size_t total_block_num = block_num;
	block_num = 0;
	for (size_t i = 0; i < tk_n; i++) {
		Token *tk = syntax->tks[i];
		switch (tk->stype) {
		case BlockStmt:
			setBlockIDWithBreadthFirst(tk, base_id + total_block_num + 1);
			block_num++;
			break;
		case Expr: case Stmt:
			setBlockIDWithBreadthFirst(tk, base_id + block_num);
			break;
		default:
			syntax->tks[i]->finfo.block_id = base_id + block_num;
			break;
		}
	}
}

void Lexer::setBlockIDWithDepthFirst(Token *syntax, size_t *block_id)
{
	using namespace SyntaxType;
	size_t tk_n = syntax->token_num;
	size_t base_id = *block_id;
	for (size_t i = 0; i < tk_n; i++) {
		Token *tk = syntax->tks[i];
		switch (tk->stype) {
		case BlockStmt:
			*block_id += 1;
			syntax->tks[i]->finfo.block_id = *block_id;
			setBlockIDWithDepthFirst(tk, block_id);
			break;
		case Expr: case Stmt:
			syntax->tks[i]->finfo.block_id = base_id;
			setBlockIDWithDepthFirst(tk, block_id);
			break;
		default:
			syntax->tks[i]->finfo.block_id = base_id;
			break;
		}
	}
}

void Lexer::dumpSyntax(Token *syntax, int indent)
{
	using namespace SyntaxType;
	size_t tk_n = syntax->token_num;
	for (size_t i = 0; i < tk_n; i++) {
		Token *tk = syntax->tks[i];
		for (int j = 0; j < indent; j++) {
			fprintf(stdout, "----------------");
		}
		switch (tk->stype) {
		case Expr:
			fprintf(stdout, "Expr |\n");
			dumpSyntax(tk, ++indent);
			indent--;
			break;
		case Stmt:
			fprintf(stdout, "Stmt |\n");
			dumpSyntax(tk, ++indent);
			indent--;
			break;
		case BlockStmt:
			fprintf(stdout, "BlockStmt |\n");
			dumpSyntax(tk, ++indent);
			indent--;
			break;
		default:
			fprintf(stdout, "%-12s\n", syntax->tks[i]->info.name);
			break;
		}
	}
}

Tokens *Lexer::getTokensBySyntaxLevel(Token *root, SyntaxType::Type type)
{
	Tokens *ret = new Tokens();
	for (size_t i = 0; i < root->token_num; i++) {
		Token **tks = root->tks;
		if (tks[i]->stype == type) {
			ret->push_back(tks[i]);
		}
		if (tks[i]->token_num > 0) {
			Tokens *new_tks = getTokensBySyntaxLevel(tks[i], type);
			ret->insert(ret->end(), new_tks->begin(), new_tks->end());
		}
	}
	return ret;
}

Tokens *Lexer::getUsedModules(Token *root)
{
	Tokens *ret = new Tokens();
	for (size_t i = 0; i < root->token_num; i++) {
		Token **tks = root->tks;
		if (tks[i]->info.type == TokenType::UseDecl && i + 1 < root->token_num) {
			ret->push_back(tks[i+1]);
		}
		if (tks[i]->token_num > 0) {
			Tokens *new_tks = getUsedModules(tks[i]);
			ret->insert(ret->end(), new_tks->begin(), new_tks->end());
		}
	}
	return ret;
}
