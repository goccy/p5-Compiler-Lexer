#include <lexer.hpp>
using namespace std;
namespace TokenType = Enum::Token::Type;
namespace SyntaxType = Enum::Parser::Syntax;
namespace TokenKind = Enum::Token::Kind;

Scanner::Scanner() :
	isStringStarted(false), isRegexStarted(false), isPrototypeStarted(false), isFormatStarted(false),
	isFormatDeclared(false), commentFlag(false), hereDocumentFlag(false), skipFlag(false),
	regex_delim(0), regex_middle_delim(0),
	brace_count_inner_regex(0), bracket_count_inner_regex(0), cury_brace_count_inner_regex(0)
{
	const char *regex_prefixes[] = {
		"q", "qq", "qw", "qx", "qr", "m", NULL
	};
	const char *regex_replaces[] = {
		"s", "y", "tr", NULL
	};
	const char *enable_regex_argument_funcs[] = {
		"map", "grep", "split", NULL
	};
	const char *operators[] = {
		"<=>", "**=", "//=", "||=", "&&=", "...", "$#{",
		"$^A", "$^D", "$^E", "$^F", "$^G", "$^H", "$^I",
		"$^L", "$^M", "$^O", "$^P", "$^R", "$^T", "$^W", "$^X",
		"<=",  ">=",  ".=",  "!=",  "==",  "+=",  "-=",
		"*=",  "%=",  "|=",  "&=",  "^=",  "<<",  ">>",
		"++",  "--",  "**",  "//",  "&&",  "||",  "::",
		"..",  "=>",  "->",  "@{",  "%{",  "${",  "@$",
		"%$",  "%-",  "%+",  "@-",  "@+",  "&$",  "$#",
		"<>",  "!~",  "~~",  "=~",
		"$0",  "$1",  "$2",  "$3",  "$4",  "$5",  "$6",
		"$7",  "$8",  "$9",
		"$&",  "$`",  "$'",  "$+",  "$.",  "$/",  "$|",
		"$,",  "$\\", "$\"", "$%",  "$=",  "$-",  "$~",
		"$^",  "$*",  "$:",  "$;",  "$?",  "$!",  "$@",
		/*"$$",*/  "$<",  "$>",  "$(",  "$)",  "$[",  "$]",
		NULL
	};
	for (size_t i = 0; regex_prefixes[i] != NULL; i++) {
		regex_prefix_map.insert(StringMap::value_type(regex_prefixes[i], ""));
	}
	for (size_t i = 0; regex_replaces[i] != NULL; i++) {
		enable_regex_argument_func_map.insert(StringMap::value_type(enable_regex_argument_funcs[i], ""));
	}
	for (size_t i = 0; regex_replaces[i] != NULL; i++) {
		regex_replace_map.insert(StringMap::value_type(regex_replaces[i], ""));
	}
	for (size_t i = 0; operators[i] != NULL; i++) {
		operator_map.insert(StringMap::value_type(operators[i], ""));
	}
}

Token *Scanner::scanQuote(LexContext *ctx, char quote)
{
	TokenManager *tmgr = ctx->tmgr;
	ScriptManager *smgr = ctx->smgr;
	char prev_ch = smgr->previousChar();
	Token *prev_token = tmgr->lastToken();
	if (prev_token && prev_token->info.type == TokenType::RegExp) {
		return scanSymbol(ctx);
	}
	if (isalnum(prev_ch) || prev_ch == '_') {
		char *token = ctx->buffer();
		TokenInfo info = tmgr->getTokenInfo(token);
		char cur_ch = smgr->currentChar();
		if (cur_ch == '\'' && info.type == TokenType::Undefined) {
			Token *namespace_tk = tmgr->new_Token(token, ctx->finfo);
			namespace_tk->info = tmgr->getTokenInfo(TokenType::Namespace);
			tmgr->add(namespace_tk);
			ctx->clearBuffer();

			ctx->writeBuffer(cur_ch);
			Token *namespace_resolver = tmgr->new_Token(ctx->buffer(), ctx->finfo);
			namespace_resolver->info  = tmgr->getTokenInfo(TokenType::NamespaceResolver);
			ctx->clearBuffer();
			return namespace_resolver;
		} else if (info.kind == TokenKind::RegPrefix || info.kind == TokenKind::RegReplacePrefix) {
			Token *tk = tmgr->new_Token(token, ctx->finfo);
			tk->info = info;
			tmgr->add(tk);
			ctx->clearBuffer();
			return scanSymbol(ctx);
		} else {
			Token *tk = tmgr->new_Token(token, ctx->finfo);
			tk->info = info;
			tmgr->add(tk);
			ctx->clearBuffer();
		}
	}
	for (smgr->next(); !smgr->end(); smgr->next()) {
		char ch = smgr->currentChar();
		if (ch == '\n') {
			ctx->writeBuffer(ch);
			ctx->finfo.start_line_num++;
			continue;
		} else if (ch == quote) {
			char prev_ch = smgr->previousChar();
			char before_prev_ch = smgr->beforePreviousChar();
			if ((prev_ch == '\\' && before_prev_ch == '\\') || prev_ch != '\\') break;
			ctx->writeBuffer(ch);
		} else {
			ctx->writeBuffer(ch);
		}
	}
	if (smgr->end()) smgr->back();
	Token *prev_tk = ctx->tmgr->lastToken();
	int idx = ctx->tmgr->size() - 2;
	string prev_data = (prev_tk) ? string(prev_tk->_data) : "";
	string before_prev_data = (idx >= 0) ? string(ctx->tmgr->beforeLastToken()->_data) : "";

	char *token = ctx->buffer();
	Token *ret = ctx->tmgr->new_Token(token, ctx->finfo);
	switch (quote) {
	case '\'':
		ret->info = tmgr->getTokenInfo(TokenType::RawString);
		break;
	case '"':
		ret->info = tmgr->getTokenInfo(TokenType::String);
		break;
	case '`':
		ret->info = tmgr->getTokenInfo(TokenType::ExecString);
		break;
	default:
		break;
	}
	ctx->clearBuffer();

	if (prev_data == "<<" || (before_prev_data == "<<" && prev_data == "\\")) {
		/* String is HereDocument */
		here_document_tag = string(ret->_data);
		here_document_tag_tk = ret;
		if (here_document_tag == "") {
			here_document_tag = "\n";
			here_document_tag_tk->_data = "\n";
		}
		switch (quote) {
		case '\'':
			ret->info = tmgr->getTokenInfo(TokenType::HereDocumentRawTag);
			break;
		case '"':
			ret->info = tmgr->getTokenInfo(TokenType::HereDocumentTag);
			break;
		case '`':
			ret->info = tmgr->getTokenInfo(TokenType::HereDocumentExecTag);
			break;
		default:
			break;
		}
	}
	return ret;
}

bool Scanner::scanNegativeNumber(LexContext *ctx, char number)
{
	char num_buffer[2] = {0};
	if (number != EOL) {
		num_buffer[0] = number;
		if (atoi(num_buffer) > 0 || number == '0') {
			//negative number
			ctx->writeBuffer('-');
			return true;
		}
	}
	return false;
}

bool Scanner::isRegexStartDelim(LexContext *ctx, const StringMap &map)
{
	/* exclude { m } or { m => ... } or { m, ... } or *m or //m */
	string prev_data = string(ctx->buffer());
	//... [before_prev_token] [prev_token] [symbol] ...
	if (map.find(prev_data) == map.end()) return false;
	Token *before_prev_token = ctx->tmgr->lastToken();
	string before_prev_data = (before_prev_token) ? string(before_prev_token->_data) : "";
	TokenType::Type before_prev_type = (before_prev_token) ?
		before_prev_token->info.type : TokenType::Undefined;
	TokenKind::Kind before_prev_kind = (before_prev_token) ?
		before_prev_token->info.kind : TokenKind::Undefined;
	char symbol = ctx->smgr->currentChar();
	if (before_prev_type == TokenType::RegDelim) return false; /* regex option */
	if (before_prev_data == "*") return false;  /* glob */
	if (before_prev_data == "&") return false;  /* function call */
	if (before_prev_data == "::") return false; /* method call */
	if (symbol == '}' || symbol == '=' || symbol == ')') return false;
	if (before_prev_kind == TokenKind::Modifier) return false; /* dereference */
	return true;
}

bool Scanner::isRegexEndDelim(LexContext *ctx)
{
	Token *token = ctx->tmgr->lastToken();
	TokenType::Type type = (token) ? token->info.type : TokenType::Undefined;
	if (isRegexStarted) return true;
	if (type == TokenType::RegExp) return true;
	if (type == TokenType::RegReplaceTo) return true;
	return false;
}

char Scanner::getRegexDelim(LexContext *ctx)
{
	char ret = EOL;
	char symbol = ctx->smgr->currentChar();
	switch (symbol) {
	case '{':
		ret = '}';
		brace_count_inner_regex++;
		break;
	case '(':
		ret = ')';
		cury_brace_count_inner_regex++;
		break;
	case '[':
		ret = ']';
		bracket_count_inner_regex++;
		break;
	case '<':
		ret = '>';
		break;
	default:
		ret = symbol;
		break;
	}
	return ret;
}

bool Scanner::isPrototype(LexContext *ctx)
{
	Token *prev_token = ctx->tmgr->lastToken();
	string prev_data = (prev_token) ? string(prev_token->_data) : "";
	int idx = ctx->tmgr->size() - 2;
	string before_prev_data = (idx >= 0) ? string(ctx->tmgr->beforeLastToken()->_data) : "";
	char symbol = ctx->smgr->currentChar();
	if (symbol != '(') return false;
	if (prev_data == "sub") return true;
	if (prev_data != "{" && before_prev_data == "sub") return true;
	return false;
}

bool Scanner::isHereDocument(LexContext *ctx, Token *tk)
{
	int idx = ctx->tmgr->size() - 2;
	string prev_tk_data = (idx >= 0) ? string(ctx->tmgr->beforeLastToken()->_data) : "";
	string tk_data = (tk) ? string(tk->_data) : "";
	char *token = ctx->buffer();
	if ((tk_data == "<<" || (prev_tk_data == "<<" && tk_data == "\\")) &&
		strtod(token, NULL) == 0 && string(token) != "0" &&
		(isupper(token[0]) || token[0] == '_')) {
		return true;
	}
	return false;
}

bool Scanner::isFormat(LexContext *, Token *tk)
{
	return (string(tk->_data) == "format") ? true : false;
}

bool Scanner::isRegexDelim(Token *prev_token, char symbol)
{
	const char *prev_data = (prev_token) ? prev_token->_data : "";
	/* [^0-9] && !"0" && !CONST && !{hash} && ![array] && !func() && !$var */
	string prev_tk = string(prev_data);
	if (regex_delim == 0 && prev_token && prev_token->info.type == TokenType::Undefined &&
		(symbol != '-' && symbol != '=' && symbol != ',' && symbol != ')') &&
		regex_prefix_map.find(prev_tk) != regex_prefix_map.end()) {
		return true;
	} else if (regex_delim == 0 && prev_token &&
			   (prev_token->info.kind == TokenKind::RegPrefix || prev_token->info.kind == TokenKind::RegReplacePrefix)) {
		return true;
	}
	TokenType::Type prev_type = (prev_token) ? prev_token->info.type : TokenType::Undefined;
	if (prev_type == TokenType::RawString ||
		prev_type == TokenType::String    ||
		prev_type == TokenType::ExecString) return false;
	if (symbol != '/') return false;
	if (!prev_token) return true;
	if (symbol == '/' && (prev_tk == "xor" || prev_tk == "and" || prev_tk == "not" || prev_tk == "or")) return true;
	if (strtod(prev_data, NULL)) return false;
	if (prev_tk == "0") return false;
	if (enable_regex_argument_func_map.find(prev_tk) != enable_regex_argument_func_map.end()) return true;
	if (!isupper(prev_data[0]) && prev_data[0] != '_' &&
		prev_data[0] != '}' && prev_data[0] != ']' && prev_data[0] != ')' &&
		prev_data[0] != '$' && prev_data[0] != '@' && prev_data[0] != '%') {
		if (isalpha(prev_data[0]) && prev_tk != "if" &&
			prev_tk != "unless" && prev_tk != "ok") return false;
		return true;
	}
	return false;
}

Token *Scanner::scanPrevSymbol(LexContext *ctx, char )
{
	char *token = ctx->buffer();
	TokenManager *tmgr = ctx->tmgr;
	Token *ret = NULL;
	Token *prev_tk = ctx->tmgr->lastToken();
	bool isPointer = (prev_tk && prev_tk->info.type == TokenType::Pointer) ? true : false;
	if (!isPointer && isRegexStartDelim(ctx, regex_prefix_map)) {
		//RegexPrefix
		ret = ctx->tmgr->new_Token(token, ctx->finfo);
		ret->info = tmgr->getTokenInfo(token);
		regex_delim = getRegexDelim(ctx);
		isRegexStarted = true;
		skipFlag = true;
	} else if (!isPointer && isRegexStartDelim(ctx, regex_replace_map)) {
		//ReplaceRegexPrefix
		ret = ctx->tmgr->new_Token(token, ctx->finfo);
		ret->info = tmgr->getTokenInfo(token);
		char delim = getRegexDelim(ctx);
		regex_delim = delim;
		regex_middle_delim = delim;
		isRegexStarted = true;
		skipFlag = true;
	} else if (isPrototype(ctx)) {
		ret = ctx->tmgr->new_Token(token, ctx->finfo);
		isPrototypeStarted = true;
		skipFlag = true;
	} else {
		Token *prev_before_tk = ctx->tmgr->lastToken();
		if (isHereDocument(ctx, prev_before_tk)) {
			/* Key is HereDocument */
			ret = ctx->tmgr->new_Token(token, ctx->finfo);
			here_document_tag = string(token);
			here_document_tag_tk = ret;
			ret->info = tmgr->getTokenInfo(TokenType::HereDocumentBareTag);
		} else {
			ret = ctx->tmgr->new_Token(token, ctx->finfo);
		}
	}
	ctx->clearBuffer();
	return ret;
}

bool Scanner::isRegexOption(const char *opt)
{
	size_t len = strlen(opt);
	for (size_t i = 0; i < len; i++) {
		char ch = opt[i];
		switch (ch) {
		case 'a': case 'c': case 'd': case 'e':
		case 'g': case 'i': case 'm': case 'l':
		case 'o': case 'p': case 'r': case 's':
		case 'u': case 'x':
			break;
		default:
			return false;
			break;
		}
	}
	return true;
}

bool Scanner::isRegexOptionPrevToken(LexContext *ctx)
{
	if (ctx->tmgr->size() < 2) return false;
	Token *before_prev_token = ctx->tmgr->beforeLastToken();
	Token *prev_token        = ctx->tmgr->lastToken();
	const char *data         = prev_token->_data;
	if (before_prev_token->info.type == TokenType::RegDelim &&
		isalpha(data[0]) &&
		string(data) != "or" &&
		isRegexOption(data)) {
		return true;
	}
	return false;
}

Token *Scanner::scanCurSymbol(LexContext *ctx, char symbol)
{
	Token *ret = NULL;
	TokenManager *tmgr = ctx->tmgr;
	Token *prev_tk = ctx->tmgr->lastToken();
	string prev_data = (prev_tk) ? prev_tk->_data : "";
	int idx = ctx->tmgr->size() - 2;
	string prev_before = (idx >= 0) ? string(ctx->tmgr->beforeLastToken()->_data) : "";
	if ((prev_before != "sub" && !isRegexOptionPrevToken(ctx) &&
		 isRegexDelim(prev_tk, symbol)) ||
		(prev_data   == "{"   && symbol == '/')) {
		if (!isRegexEndDelim(ctx)) {
			regex_delim = getRegexDelim(ctx);
			isRegexStarted = true;
			skipFlag = true;
		} else {
			regex_delim = 0;
		}
		ctx->writeBuffer(symbol);
		ret = ctx->tmgr->new_Token(ctx->buffer(), ctx->finfo);
		ret->info = tmgr->getTokenInfo(TokenType::RegDelim);
		ctx->clearBuffer();
	} else if (isRegexEndDelim(ctx)) {
		ctx->writeBuffer(symbol);
		ret = ctx->tmgr->new_Token(ctx->buffer(), ctx->finfo);
		ret->info = tmgr->getTokenInfo(TokenType::RegDelim);
		ctx->clearBuffer();
	} else if (symbol == '@' || symbol == '$' || symbol == '%') { //|| symbol == '&')
		ctx->writeBuffer(symbol);
	} else if (symbol == ';') {
		ctx->writeBuffer(symbol);
		ret = ctx->tmgr->new_Token(ctx->buffer(), ctx->finfo);
		ctx->clearBuffer();
	} else if (isPrototype(ctx)) {
		ctx->writeBuffer(symbol);
		ret = ctx->tmgr->new_Token(ctx->buffer(), ctx->finfo);
		ctx->clearBuffer();
		isPrototypeStarted = true;
		skipFlag = true;
	} else if (symbol != '\n') {
		ctx->writeBuffer(symbol);
		ret = ctx->tmgr->new_Token(ctx->buffer(), ctx->finfo);
		ctx->clearBuffer();
	}
	return ret;
}

Token *Scanner::scanTripleCharacterOperator(LexContext *ctx, char symbol, char next_ch, char after_next_ch)
{
	Token *ret = NULL;
	char op[4] = { symbol, next_ch, after_next_ch, EOL };
	if (triple_operator_map.in_word_set(op)) {// != operator_map.end()) {
		ctx->writeBuffer(symbol);
		ctx->writeBuffer(next_ch);
		ctx->writeBuffer(after_next_ch);
		ret = ctx->tmgr->new_Token(ctx->buffer(), ctx->finfo);
		ret->info = ctx->tmgr->getTokenInfo(op);
		ctx->clearBuffer();
		ctx->progress = 2;
	} else if (symbol == '$' && next_ch == '$') {
		ret = ctx->tmgr->new_Token((char *)"$$", ctx->finfo);
		TokenManager *tmgr = ctx->tmgr;
		ret->info = (isalpha(after_next_ch) || after_next_ch == '_') ?
			tmgr->getTokenInfo(TokenType::ShortScalarDereference) :
			tmgr->getTokenInfo("$$");
		ctx->progress = 1;
	}
	return ret;
}

Token *Scanner::scanDoubleCharacterOperator(LexContext *ctx, char symbol, char next_ch)
{
	Token *ret = NULL;
	char op[3] = { symbol, next_ch, EOL };
	if (double_operator_map.in_word_set(op)) {
		ctx->writeBuffer(symbol);
		ctx->writeBuffer(next_ch);
		ret = ctx->tmgr->new_Token(ctx->buffer(), ctx->finfo);
		ret->info = ctx->tmgr->getTokenInfo(op);
		ctx->clearBuffer();
		ctx->progress = 1;
	} else if (symbol == '/' && next_ch == '=') {
		Token *prev_tk = ctx->tmgr->lastToken();
		const char *prev_data = prev_tk->_data;
		/* '/=' is RegDelim + RegExp or DivEqual */
		if (strtod(prev_data, NULL) != 0 || string(prev_data) == "0" || isupper(prev_data[0]) ||
			prev_data[0] == '}' || prev_data[0] == ']' ||
			prev_data[0] == ')' || prev_data[0] == '$') {
			ctx->writeBuffer(symbol);
			ctx->writeBuffer(next_ch);
			ret = ctx->tmgr->new_Token(ctx->buffer(), ctx->finfo);
			ctx->clearBuffer();
			ctx->progress = 1;
		}
	}
	return ret;
}

/* Scanner::scanPostDeref

The postfix dereference is a bit odd because we have to treat a sigil
a bit special.

Scalars are simple:

	$scalar->$*

Arrays have a special case with the last index, and support single
element access and slices:

	$array->@*
	$array->$#*
	$array->@[0]
	$array->@[0,1]

Hashes support single element access and slices:

	$hash->%*
	$array->%{key}
	$array->%{key,key2}

Code supports argument lists:

	$code->&*
	$code->&( arg, arg2 )

Typeglobs have "keys" into the symbol table

	$gref->**
	$gref->*{SCALAR}

*/

Token *Scanner::scanPostDeref(LexContext *ctx)
{
	Token *ret      = NULL;
	Token *sigil_tk = NULL;

	if (!isPostDeref(ctx)) return ret;

	char symbol = ctx->smgr->currentChar();
	ctx->writeBuffer(symbol);

	if (symbol == '$') {
		char next_ch = ctx->smgr->nextChar();
		if (next_ch=='#') { // we have the last array index
			symbol = ctx->smgr->forward(1);
			ctx->writeBuffer(next_ch);
			}
	}

	sigil_tk = ctx->tmgr->new_Token(ctx->buffer(), ctx->finfo);
	sigil_tk->info = ctx->tmgr->getTokenInfo(TokenType::PostDeref);
	ctx->clearBuffer();

	// This is a bit odd because we add a Token directly instead of
	// returning it and letting the rest of the system figure it out
	ctx->tmgr->add(sigil_tk);

	// We only care if it's a *. We'll let the rest of the tokenizer
	// handle the slices, which would have [, {, (
	char next_ch = ctx->smgr->nextChar();
	if (next_ch != '*') return ret;

	symbol = ctx->smgr->forward(1);
	ctx->writeBuffer(symbol);
	ret = ctx->tmgr->new_Token(ctx->buffer(), ctx->finfo);
	ctx->clearBuffer();
	ret->info = ctx->tmgr->getTokenInfo(TokenType::PostDerefStar);

	return ret;
}

/* Scanner::isPostDeref

See Scanner::scanPostDeref for the rules

*/

bool Scanner::isPostDeref(LexContext *ctx)
{
	Token *prev_token = ctx->tmgr->lastToken();
	string prev_data = (prev_token) ? string(prev_token->_data) : "";
	char symbol = ctx->smgr->currentChar();

	// Should I check that the previous Token was Pointer
	// instead of looking at the data
	if (prev_data != "->") return false;

	// do we need an isSigil method?
	if (symbol != '$' && symbol != '@' && symbol != '%' && symbol != '&' && symbol != '*')
		return false;

	char next_ch = ctx->smgr->nextChar();

	// scalar and array index case
	if (symbol == '$' && ! ( next_ch == '*' || next_ch == '#' )) return false;

	// array case
	if (symbol == '@' && ! ( next_ch == '*' || next_ch == '[' )) return false;

	// hash case
	if (symbol == '%' && ! ( next_ch == '*' || next_ch == '{' )) return false;

	// code case
	if (symbol == '&' && ! ( next_ch == '*' || next_ch == '(' )) return false;

	// typeglob case
	if (symbol == '*' && ! ( next_ch == '*' || next_ch == '{' )) return false;

	return true;
}

Token *Scanner::scanSymbol(LexContext *ctx)
{
	Token *ret = NULL;
	ScriptManager *smgr = ctx->smgr;
	char symbol = smgr->currentChar();
	char next_ch = smgr->nextChar();
	char after_next_ch = smgr->afterNextChar();
	if (ctx->existsBuffer()) ctx->tmgr->add(scanPrevSymbol(ctx, symbol));

	if (!isRegexStarted) {
		ret = scanPostDeref(ctx);
		if (!ret) ret = scanTripleCharacterOperator(ctx, symbol, next_ch, after_next_ch);
		if (!ret) ret = scanDoubleCharacterOperator(ctx, symbol, next_ch);
	}
	if (!ret) ret = scanCurSymbol(ctx, symbol);
	return ret;
}

Token *Scanner::scanWordDelimiter(LexContext *ctx)
{
	TokenManager *tmgr = ctx->tmgr;
	Token *ret = NULL;
	if (ctx->existsBuffer()) {
		char *token = ctx->buffer();
		if (isHereDocument(ctx, ctx->tmgr->lastToken())) {
			ret = ctx->tmgr->new_Token(token, ctx->finfo);
			/* Key is HereDocument */
			here_document_tag = string(token);
			here_document_tag_tk = ret;
			ret->info = tmgr->getTokenInfo(TokenType::HereDocumentBareTag);
		} else if (string(token) == "format") {
			isFormatDeclared = true;
			ret = ctx->tmgr->new_Token(token, ctx->finfo);
			ret->info = tmgr->getTokenInfo(TokenType::FormatDecl);
		} else if (token[0] != '\n' || token[1] != EOL) {
			ret = ctx->tmgr->new_Token(token, ctx->finfo);
		}
		ctx->clearBuffer();
	}
	return ret;
}

Token *Scanner::scanReference(LexContext *ctx)
{
	Token *ret = NULL;
	char next_ch = ctx->smgr->nextChar();
	if (next_ch == '$' || next_ch == '@' ||
		next_ch == '%' || next_ch == '&') {
		ret = ctx->tmgr->new_Token((char *)"\\", ctx->finfo);
	}
	return ret;
}

Token *Scanner::scanSingleLineComment(LexContext *ctx)
{
	Token *ret = NULL;
	ScriptManager *smgr = ctx->smgr;
	TokenManager *tmgr = ctx->tmgr;
	if (ctx->existsBuffer()) tmgr->add(scanPrevSymbol(ctx, '#'));
	Token *prev_tk = ctx->tmgr->lastToken();
	TokenType::Type prev_type = (prev_tk) ?  prev_tk->info.type : TokenType::Undefined;
	if (isRegexStarted || prev_type == TokenType::RegExp || prev_type ==  TokenType::RegReplaceTo) {
		ctx->writeBuffer('#');
		ret = ctx->tmgr->new_Token(ctx->buffer(), ctx->finfo);
		ret->info = tmgr->getTokenInfo(TokenType::RegDelim);
		ctx->clearBuffer();
	} else {
		if (verbose) {
			for (; smgr->currentChar() != '\n' && !smgr->end(); smgr->next()) {
				ctx->writeBuffer(smgr->currentChar());
			}
			Token *tk = tmgr->new_Token(ctx->buffer(), ctx->finfo);
			tk->info = tmgr->getTokenInfo(TokenType::Comment);
			ctx->clearBuffer();
			tmgr->add(tk);
		} else {
			for (; smgr->currentChar() != '\n' && !smgr->end(); smgr->next()) {}
		}
		tmgr->add(scanWhiteSpace(ctx));
		ctx->finfo.start_line_num++;
	}
	return ret;
}

Token *Scanner::scanLineDelimiter(LexContext *ctx)
{
	Token *ret = scanWordDelimiter(ctx);
	Token *last_tk = ctx->tmgr->lastToken();
	string data = (ret) ? string(ret->_data) :
		(last_tk) ? string(last_tk->_data) : "";
	if (isFormatDeclared && data == "=") {
		isFormatDeclared = false;
		isFormatStarted = true;
		skipFlag = true;
	} else if (here_document_tag != "") {
		hereDocumentFlag = true;
		skipFlag = true;
	}
	ctx->clearBuffer();
	return ret;
}

static inline char next(LexContext *ctx, char *src, size_t &i)
{
	ctx->writeBuffer((src+i)[0]);
	return *(src + i++);
}

#define PREDICT() (*(src + i))
#define is_number(ch) ('0' <= ch && ch <= '9')
#define is_number_literal(ch) ((is_number(ch) || ch == '_') && ch != EOL)
#define is_hexchar(ch) (('a' <= ch && ch <= 'f') || ('A' <= ch && ch <= 'F'))

bool Scanner::isVersionString(LexContext *ctx)
{
	if (!ctx->existsBuffer()) return false;
	char *token = ctx->buffer();
	if (token[0] != 'v') return false;
	for (int i = 1; token[i] != EOL; i++) {
		if (!is_number(token[i])) return false;
	}
	return true;
}

Token *Scanner::scanVersionString(LexContext *ctx)
{
	TokenManager *tmgr = ctx->tmgr;
	char *src = ctx->smgr->raw_script;
	size_t i = ctx->smgr->idx;
	// char *begin = src + i;
	char c = next(ctx, src, i);//NEXT();
	Token *token = NULL;
	for (;(is_number(c) || c == '.' || c == '_') && c != EOL; c = next(ctx, src, i)) {}
	i -= 1;
	char *buf = ctx->buffer();
	buf[ctx->buffer_idx-1] = EOL;

	token = ctx->tmgr->new_Token(buf, ctx->finfo);
	token->info = tmgr->getTokenInfo(TokenType::VersionString);
	ctx->smgr->idx = --i;
	return token;
}

Token *Scanner::scanNumber(LexContext *ctx)
{
	TokenManager *tmgr = ctx->tmgr;
	char *src = ctx->smgr->raw_script;
	size_t i = ctx->smgr->idx;
	// char *begin = src + i;
	int c = next(ctx, src, i);
	Token *token = NULL;
	assert((c == '.' || is_number(c)) && "It do not seem as Number");
	bool isFloat = false;
	if (is_number(c)) {
		/* first char */
		if (is_number_literal(c)) c = next(ctx, src, i);
		/* second char is includes 'b' or 'x' */
		if ((is_number(c) || c == 'b' || c == 'x' || c == '_') && c != EOL) c = next(ctx, src, i);
		for (;(is_number(c) || is_hexchar(c) || c == '_') && c != EOL; c = next(ctx, src, i)) {}
	}
	if (c != '.' && c != 'e' && c != 'E') goto L_emit;
	if (c == '.') {
		c = PREDICT();
		if (c == '.') {
			goto L_emit; /* Number .. */
		}
		isFloat = true;
		for (; is_number_literal(c); c = next(ctx, src, i)) {}
	}
	if (c == 'e' || c == 'E') {
		isFloat = true;
		c = next(ctx, src, i);
		if (c == '+' || c == '-') c = next(ctx, src, i);
		for (; is_number_literal(c); c = next(ctx, src, i)) {}
	}
	L_emit:;
	i -= 1;
	char *buf = ctx->buffer();
	buf[ctx->buffer_idx-1] = EOL;
	token = ctx->tmgr->new_Token(buf, ctx->finfo);
	token->info = isFloat ? tmgr->getTokenInfo(TokenType::Double) : tmgr->getTokenInfo(TokenType::Int);
	ctx->smgr->idx = --i;
	return token;
}

Token *Scanner::scanWhiteSpace(LexContext *ctx)
{
	TokenManager *tmgr = ctx->tmgr;
	Token *prev_tk = tmgr->lastToken();
	TokenType::Type prev_type = (prev_tk) ? prev_tk->info.type : TokenType::Undefined;

	if (prev_type == TokenType::Comment || prev_type == TokenType::Pod) {
		// Add WhiteSpace token (data: '\n') for Comment or Pod token
		// Because the newline character is not on the trailing of those tokens
		ctx->writeBuffer('\n');
		ctx->finfo.start_line_num = prev_tk->finfo.start_line_num;
	} else {
		bool does_ws_continue = false;
		ScriptManager *smgr = ctx->smgr;
		for (; !smgr->end(); smgr->next()) {
			char ch = smgr->currentChar();
			if (ch == ' ' || ch == '\t') {
				// For normal whitespace.
				// It collects into one token when a whitespace continues.
				ctx->writeBuffer(ch);
				does_ws_continue = true;
				continue;
			} else if (!does_ws_continue && ch == '\n') {
				// For newline character.
				// It should be on the same line to before token.
				ctx->writeBuffer(ch);
				if (verbose && prev_type != TokenType::HereDocumentEnd) {
					ctx->finfo.start_line_num = prev_tk->finfo.start_line_num;
				}
				break;
			}
			smgr->back();
			break;
		}
	}

	if (!verbose) {
		ctx->clearBuffer();
		return NULL;
	}

	Token *token = tmgr->new_Token(ctx->buffer(), ctx->finfo);
	token->info = tmgr->getTokenInfo(TokenType::WhiteSpace);
	ctx->clearBuffer();
	return token;
}

#undef NEXT
#undef PREDICT

bool Scanner::isSkip(LexContext *ctx)
{
	using namespace TokenType;
	bool ret = commentFlag;

	ScriptManager *smgr = ctx->smgr;
	TokenManager *tmgr = ctx->tmgr;
	char *script = smgr->raw_script;
	size_t idx = smgr->idx;
	char prev_ch = smgr->previousChar();
	char cur_ch = smgr->currentChar();

	if (prev_ch == '\n' && cur_ch == '=' &&
		isalnum(smgr->nextChar())) {
		if (smgr->compare(1, 3, "cut")) {
			DBG_PL("commentFlag => OFF");
			ctx->progress = 4;
			commentFlag = false;
			ret = false;
			if (verbose) {
				ctx->finfo.start_line_num++;
				ctx->writeBuffer("=cut");
				Token *tk = tmgr->new_Token(ctx->buffer(), ctx->finfo);
				tk->info = tmgr->getTokenInfo(TokenType::Pod);
				ctx->clearBuffer();
				tmgr->add(tk);
				tmgr->add(scanWhiteSpace(ctx));
			}
			ctx->finfo.start_line_num++;
		} else {
			DBG_PL("commentFlag => ON");
			commentFlag = true;
			ret = true;
		}
	}
	if (commentFlag) {
		if (verbose) ctx->writeBuffer(cur_ch);
		return ret;
	}
	if (prev_ch == '\n' && cur_ch == '_' && !hereDocumentFlag &&
			   smgr->compare(0, 7, "__END__")) {
		int progress_to_end = ctx->script_size - idx - 1;
		ctx->progress = progress_to_end;
		ret = false;
	} else if (prev_ch == '\n' && cur_ch == '_' && !hereDocumentFlag &&
			   smgr->compare(0, 8, "__DATA__")) {
		int progress_to_end = ctx->script_size - idx - 1;
		ctx->progress = progress_to_end;
		ret = false;
	}
	if (!skipFlag) return ret;

	if (isFormatStarted) {
		if (prev_ch == '\n' && cur_ch == '.') {
			Token *tk = ctx->tmgr->new_Token(ctx->buffer(), ctx->finfo);
			tk->info = tmgr->getTokenInfo(Format);
			ctx->clearBuffer();
			tmgr->add(tk);

			tk = ctx->tmgr->new_Token((char *)".", ctx->finfo);
			tk->info = tmgr->getTokenInfo(TokenType::FormatEnd);
			tmgr->add(tk);

			ctx->progress = 1;
			isFormatStarted = false;
			skipFlag = false;
			ret = false;
		} else {
			ctx->writeBuffer(script[idx]);
			ret = true;
		}
    } else if (isRegexStarted) {
		char before_prev_ch = smgr->beforePreviousChar();
		if (prev_ch != '\\' || (prev_ch == '\\' && before_prev_ch == '\\')) {
			switch (cur_ch) {
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
		if (prev_ch == '\\' && before_prev_ch != '\\') {
			ctx->writeBuffer(cur_ch);
			ret = true;
		} else if (cur_ch != regex_delim && cur_ch != regex_middle_delim) {
			ctx->writeBuffer(cur_ch);
			ret = true;
		} else if (cur_ch == regex_middle_delim) {
			if ((regex_middle_delim == '}' && brace_count_inner_regex != 0) ||
				(regex_middle_delim == ')' && cury_brace_count_inner_regex != 0) ||
				(regex_middle_delim == ']' && bracket_count_inner_regex != 0)) {
				ctx->writeBuffer(cur_ch);
				ret = true;
			} else {
				Token *tk = NULL;
				if (regex_middle_delim != '{' &&
					regex_middle_delim != '(' &&
					regex_middle_delim != '<' &&
					regex_middle_delim != '[') {
					tk = ctx->tmgr->new_Token(ctx->buffer(), ctx->finfo);
					tk->info = tmgr->getTokenInfo(RegReplaceFrom);
					ctx->clearBuffer();
					tmgr->add(tk);
				}
				ctx->writeBuffer(regex_middle_delim);
				tk = ctx->tmgr->new_Token(ctx->buffer(), ctx->finfo);
				tk->info = tmgr->getTokenInfo(RegMiddleDelim);
				ctx->clearBuffer();
				tmgr->add(tk);

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
				ctx->writeBuffer(cur_ch);
				ret = true;
			} else {
				Token *prev_tk = ctx->tmgr->lastToken();
				Token *tk = ctx->tmgr->new_Token(ctx->buffer(), ctx->finfo);
				tk->info = (prev_tk->info.type == RegMiddleDelim) ? tmgr->getTokenInfo(RegReplaceTo) : tmgr->getTokenInfo(RegExp);
				ctx->clearBuffer();
				tmgr->add(tk);

				ret = false;
				isRegexStarted = false;
				skipFlag = false;
				regex_delim = 0;
				brace_count_inner_regex = 0;
				cury_brace_count_inner_regex = 0;
				bracket_count_inner_regex = 0;
			}
		}
	} else if (isPrototypeStarted) {
		if (script[idx] == ')') {
			Token *tk = ctx->tmgr->new_Token(ctx->buffer(), ctx->finfo);
			tk->info = tmgr->getTokenInfo(Prototype);
			ctx->clearBuffer();
			tmgr->add(tk);

			isPrototypeStarted = false;
			skipFlag = false;
			ret = false;
		} else {
			ctx->writeBuffer(script[idx]);
			ret = true;
		}
	} else if (hereDocumentFlag) {
		size_t len = here_document_tag.size();
		if (smgr->previousChar() == '\n' && idx + len < ctx->script_size) {
			size_t i;
			for (i = 0; i < len && script[idx + i] == here_document_tag.at(i); i++) {}
			if (i == len) {
				ctx->progress = len;
				if (verbose) ctx->finfo.start_line_num++;
				Token *tk = ctx->tmgr->new_Token(ctx->buffer(), ctx->finfo);
				tk->info = tmgr->getTokenInfo(TokenType::HereDocument);
				ctx->clearBuffer();
				tmgr->add(tk);

				tk = ctx->tmgr->new_Token((char *)here_document_tag_tk->_data, ctx->finfo);
				tk->info = tmgr->getTokenInfo(TokenType::HereDocumentEnd);
				tmgr->add(tk);
				if (!verbose) ctx->finfo.start_line_num++;
				here_document_tag = "";
				hereDocumentFlag = false;
				skipFlag = false;
				ret = false;
			} else {
				ctx->writeBuffer(script[idx]);
				ret = true;
			}
		} else {
			ctx->writeBuffer(script[idx]);
			ret = true;
		}
	}
	return ret;
}
