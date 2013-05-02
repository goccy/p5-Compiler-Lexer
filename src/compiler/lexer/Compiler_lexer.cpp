#include <lexer.hpp>
#include <cassert>

/* Declare Namespace */
using namespace std;
namespace TokenType = Enum::Lexer::Token;
namespace SyntaxType = Enum::Lexer::Syntax;
namespace TokenKind = Enum::Lexer;
#define ITER_CAST(T, it) (T)*(it)

Module::Module(const char *name_, const char *args_)
	: name(name_), args(args_) {}

/************ LexContext *************/

LexContext::LexContext(void) {}
LexContext::LexContext(Tokens *tks)
{
	this->tks = tks;
	this->itr = tks->begin();
}
void LexContext::clearToken(char *token)
{
	memset(token, 0, max_token_size);
	token_idx = 0;
}
void LexContext::writeChar(char *token, char ch)
{
	token[token_idx] = ch;
	token_idx++;
}
Token *LexContext::tk(void) { return ITER_CAST(Token *, itr); }
Token *LexContext::nextToken(void) { return ITER_CAST(Token *, itr+1); }
void LexContext::next(void) { ++itr; }
bool LexContext::end(void) { return itr == tks->end(); }

/*************** Lexer ***************/

Lexer::Lexer(const char *filename)
{
	finfo.start_line_num = 1;
	finfo.filename = filename;
	scanner = new Scanner();
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
		if (scanner->isSkip(&ctx, script, i)) {
			i++;
			continue;
		} else {
			i += ctx.progress;
			ctx.progress = 0;
			if (script[i] == EOL) break;
		}
		switch (ch) {
		case '"': case '\'': case '`':
			tk = scanner->scanQuote(&ctx, ch);
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
					scanner->here_document_tag = token;
					tk->info = scanner->getTokenInfo(TokenType::HereDocumentRawTag);
				}
				ctx.clearToken(token);
				if (tk) tokens->push_back(tk);
			}
			break;
		case '\\':
			if (CHECK_CH(i+1, '$') || CHECK_CH(i+1, '@') ||
				CHECK_CH(i+1, '%') || CHECK_CH(i+1, '&')) {
				//tokens->push_back(new Token(string("\\") + string(1, script[i+1]), finfo));
				tokens->push_back(new Token(string("\\"), finfo));
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
				Token *tk = scanner->scanPrevSymbol(&ctx, '#');
				tokens->push_back(tk);
			}
			Token *prev_tk = (tokens->size() > 0) ? tokens->back() : NULL;
			if (scanner->isRegexStarted ||
				(prev_tk && prev_tk->info.type == TokenType::RegExp) ||
				(prev_tk && prev_tk->info.type == TokenType::RegReplaceTo)) {
				char tmp[2] = {'#'};
				Token *tk = new Token(string(tmp), finfo);
				tk->info = scanner->getTokenInfo(TokenType::RegDelim);
				ctx.clearToken(token);
				tokens->push_back(tk);
				break;
			}
			while (script[i] != '\n' && i < script_size) {i++;}
			finfo.start_line_num++;
			break;
		}
		case '-':
			if (scanner->scanNegativeNumber(&ctx, script[i + 1])) {
				break;
			} else if (i + 1 < script_size && isalpha(script[i+1])) {
				ctx.writeChar(ctx.token, script[i]);
				break;
			}
			//fall through
		case '.':
			if (ctx.token_idx == 0 && i + 1 < script_size &&
				'0' <= script[i+1] && script[i+1] <= '9') {
				// .01234
				tk = scanner->scanNumber(&ctx, script, i);
				tokens->push_back(tk);
				ctx.clearToken(ctx.token);
				continue;
			}
			//fall through
		case '=': case '^': case '~': case '@':
		case ',': case ':': case ';': case '+':
		case '<': case '>': case '&': case '|':
		case '!': case '*': case '/': case '%':
		case '(': case ')': case '{': case '}':
		case '[': case ']': case '?': case '$': {
			if (i + 2 < script_size) {
				tk = scanner->scanSymbol(&ctx, script[i], script[i + 1], script[i + 2]);
				i += ctx.progress;
				ctx.progress = 0;
				if (tk) tokens->push_back(tk);
			} else if (i + 1 < script_size) {
				tk = scanner->scanSymbol(&ctx, script[i], script[i + 1]);
				i += ctx.progress;
				ctx.progress = 0;
				if (tk) tokens->push_back(tk);
			} else {
				tk = scanner->scanSymbol(&ctx, script[i]);
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
					tk->info = scanner->getTokenInfo(TokenType::HereDocumentRawTag);
					scanner->here_document_tag = token;
				}
				ctx.clearToken(ctx.token);
			}
			if (scanner->here_document_tag != "") scanner->hereDocumentFlag = true;
			break;
		case '0': case '1': case '2': case '3': case '4':
		case '5': case '6': case '7': case '8': case '9':
			if (ctx.token_idx == 0 || (ctx.token_idx == 1 && token[0] == '-')) {
				tk = scanner->scanNumber(&ctx, script, i);
				if (token[0] == '-') tk->data = "-" + tk->data;
				tokens->push_back(tk);
				ctx.clearToken(ctx.token);
				continue;
			}
		default:
			ctx.writeChar(ctx.token, script[i]);
			break;
		}
		i++;
	}
	//safe_free(token, max_token_size);
	return tokens;
}

void Lexer::dump(Tokens *tokens)
{
	TokenPos it = tokens->begin();
	while (it != tokens->end()) {
		Token *t = ITER_CAST(Token *, it);
		fprintf(stdout, "[%-12s] : %12s \n", cstr(t->data), t->info.name);
		it++;
	}
}

void Lexer::annotateTokens(Tokens *tokens)
{
	LexContext *ctx = new LexContext(tokens);
	Annotator *annotator = new Annotator();
	for (; !ctx->end(); ctx->next()) {
		Token *tk = ctx->tk();
		annotator->annotate(ctx, tk);
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
			ns_token->info.has_warnings = true;
			ns = "";
			tokens->erase(start_pos, end_pos);
			break;
		}
		case ArraySize: {
			Token *as_token = tk;
			Token *next_tk = ITER_CAST(Token *, pos+1);
			TokenType::Type type = next_tk->info.type;
			if (type == Key || type == Var || type == GlobalVar) {
				as_token->data += next_tk->data;
				tokens->erase(pos+1);
			}
			break;
		}
		case ShortScalarDereference: case ShortArrayDereference:
		case ShortHashDereference:   case ShortCodeDereference: {
			Token *next_tk = ITER_CAST(Token *, pos+1);
			if (!next_tk) break;
			Token *sp_token = tk;
			sp_token->data += next_tk->data;
			tokens->erase(pos+1);
			break;
		}
		default:
			break;
		}
		pos++;
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
					tag->info = scanner->getTokenInfo(TokenType::RegDoubleQuote);
					tag->data = "qq{" + t->data + "}";
					break;
				case TokenType::HereDocumentRawTag:
					tag->info = scanner->getTokenInfo(TokenType::RegQuote);//RawString);
					tag->data = "q{" + t->data + "}";
					break;
				default:
					break;
				}
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
	} else if (type == Pointer || type == Mul || kind == TokenKind::Term || kind == TokenKind::Function ||/* type == FunctionDecl ||*/
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
		case ArrayDereference: case HashDereference: case ScalarDereference:
		case ArraySizeDereference: {
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
			} else if (prev_type == FunctionDecl) {
				/* LeftBrace is Expr but assign stype of BlockStmt */
				syntax->stype = SyntaxType::BlockStmt;
			} else if (prev_kind == TokenKind::Do) {
				syntax->stype = SyntaxType::BlockStmt;
			} else {
				syntax->stype = SyntaxType::BlockStmt;
				if (pos+1 != tokens->end()) {
					Token *next_tk = ITER_CAST(Token *, pos+1);
					if (next_tk && next_tk->info.type != SemiColon) {
						intermediate_pos = pos;
					}
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
		memmove(syntax->tks+(idx+1), syntax->tks+(idx+grouping_num),
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
				Token *expr = tks[i+1];
				if (expr->token_num > 3 && tk->info.type == ForStmt &&
					expr->tks[1]->stype == SyntaxType::Stmt &&
					expr->tks[2]->stype == SyntaxType::Stmt &&
					expr->tks[3]->stype != SyntaxType::Stmt &&
					expr->tks[3]->info.type != RightParenthesis) {
					insertStmt(expr, 3, expr->token_num - 4);
				}
				insertStmt(syntax, i, 3);
				tk_n -= 2;
				parseSpecificStmt(tks[i]->tks[2]);
				//i += 2;
			} else if ((tk->info.type == ForStmt || tk->info.type == ForeachStmt) &&
					   tk_n > i+3 && tks[i+1]->stype != SyntaxType::Expr) {
				/* for(each) [decl] Term Expr BlockStmt */
				if (tk_n > i+3 &&
					tks[i+1]->info.kind == TokenKind::Term &&
					tks[i+2]->stype == SyntaxType::Expr &&
					tks[i+3]->stype == SyntaxType::BlockStmt) {
					insertStmt(syntax, i, 4);
					tk_n -= 3;
					parseSpecificStmt(tks[i]->tks[3]);
					//i += 3;
				} else if (tk_n > i+4 &&
					tks[i+1]->info.kind == TokenKind::Decl &&
					tks[i+2]->info.kind == TokenKind::Term &&
					tks[i+3]->stype == SyntaxType::Expr &&
					tks[i+4]->stype == SyntaxType::BlockStmt) {
					insertStmt(syntax, i, 5);
					tk_n -= 4;
					parseSpecificStmt(tks[i]->tks[4]);
					//i += 4;
				} else {
					//fprintf(stderr, "Syntax Error!: near by line[%lu]\n", tk->finfo.start_line_num);
					//exit(EXIT_FAILURE);
				}
			}
			break;
		}
		case ElseStmt: case Do: case Continue: case DefaultStmt:
			if (tk_n > i+1 &&
				tks[i+1]->stype == SyntaxType::BlockStmt) {
				/* else BlockStmt */
				insertStmt(syntax, i, 2);
				tk_n -= 1;
				parseSpecificStmt(tks[i]->tks[1]);
				//i += 1;
			}
			break;
		case FunctionDecl:
			if (tk_n > i+1 &&
				tks[i+1]->info.type == SyntaxType::BlockStmt) {
				/* sub BlockStmt */
				insertStmt(syntax, i, 2);
				tk_n -= 1;
				parseSpecificStmt(tks[i]->tks[1]);
			} else if (tk_n > i+2 &&
				tks[i+1]->info.type == Function &&
				tks[i+2]->stype == SyntaxType::BlockStmt) {
				/* sub func BlockStmt */
				insertStmt(syntax, i, 3);
				tk_n -= 2;
				parseSpecificStmt(tks[i]->tks[2]);
			} else if (tk_n > i+3 &&
				tks[i+1]->info.type == Function &&
				tks[i+2]->stype == SyntaxType::Expr &&
				tks[i+3]->stype == SyntaxType::BlockStmt) {
				/* sub func Expr BlockStmt */
				insertStmt(syntax, i, 4);
				tk_n -= 3;
				parseSpecificStmt(tks[i]->tks[3]);
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
			} else if (tk->stype == SyntaxType::Stmt || tk->stype == SyntaxType::Expr) {
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
		case Term:
			fprintf(stdout, "Term |\n");
			dumpSyntax(tk, ++indent);
			indent--;
			break;
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

Modules *Lexer::getUsedModules(Token *root)
{
	using namespace TokenType;
	Modules *ret = new Modules();
	for (size_t i = 0; i < root->token_num; i++) {
		Token **tks = root->tks;
		if (tks[i]->info.type == UseDecl && i + 1 < root->token_num) {
			const char *module_name = cstr(tks[i+1]->data);
			string args;
			for (i += 2; tks[i]->info.type != SemiColon; i++) {
				args += " " + string(tks[i]->deparse());
			}
			ret->push_back(new Module(module_name, (new string(args))->c_str()));
		}
		if (tks[i]->token_num > 0) {
			Modules *new_mds = getUsedModules(tks[i]);
			ret->insert(ret->end(), new_mds->begin(), new_mds->end());
		}
	}
	return ret;
}
