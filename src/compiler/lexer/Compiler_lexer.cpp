#include <lexer.hpp>

/* Declare Namespace */
using namespace std;
namespace TokenType = Enum::Token::Type;
namespace SyntaxType = Enum::Parser::Syntax;
namespace TokenKind = Enum::Token::Kind;
#define ITER_CAST(T, it) (T)*(it)
#define EXTEND_BUFFER_SIZE (16) //This parameter is needed to correspond #53

Module::Module(const char *name_, const char *args_)
	: name(name_), args(args_) {}

LexContext::LexContext(const char *filename, char *script)
	: progress(0), buffer_idx(0)
{
	script_size = strlen(script) + 1;
	token_buffer = (char *)malloc((script_size + EXTEND_BUFFER_SIZE) * 2);
	buffer_head = token_buffer;
	token_buffer[0] = EOL;
	prev_type = TokenType::Undefined;
	smgr = new ScriptManager(script);
	tmgr = new TokenManager(script_size + EXTEND_BUFFER_SIZE);
	finfo.start_line_num = 1;
	finfo.filename = filename;
}

Lexer::Lexer(const char *filename, bool verbose)
{
	this->filename = filename;
	this->verbose  = verbose;
}

Lexer::~Lexer(void)
{
	//free((void *)this->filename);
}

Tokens *Lexer::tokenize(char *script)
{
	Scanner scanner;
	scanner.verbose = verbose;
	ctx = new LexContext(filename, script);
	Token *tk = NULL;
	TokenManager *tmgr = ctx->tmgr;
	ScriptManager *smgr = ctx->smgr;
	char ch = smgr->currentChar();
	for (; ch != EOL; smgr->idx++) {
		ch = smgr->currentChar();
		if (smgr->end()) break;
		if (ch == '\n') ctx->finfo.start_line_num++;
		if (scanner.isSkip(ctx)) {
			continue;
		} else {
			smgr->idx += ctx->progress;
			ctx->progress = 0;
			if (smgr->end()) break;
		}
		switch (ch) {
		case '"': case '\'': case '`':
			tmgr->add(scanner.scanQuote(ctx, ch));
			break;
		case ' ': case '\t':
			tmgr->add(scanner.scanWordDelimiter(ctx));
			tmgr->add(scanner.scanWhiteSpace(ctx)); // For newline character
			break;
		case '#':
			tmgr->add(scanner.scanSingleLineComment(ctx));
			break;
		case '-':
			if (scanner.scanNegativeNumber(ctx, smgr->nextChar())) {
				break;
			} else if (isalpha(smgr->nextChar())) {
				ctx->writeBuffer(smgr->currentChar());
				break;
			}
			//fall through
		case '.':
			if (!ctx->existsBuffer() &&
				'0' <= smgr->nextChar() && smgr->nextChar() <= '9') {
				// .01234
				tmgr->add(scanner.scanNumber(ctx));
				ctx->clearBuffer();
				continue;
			} else if (scanner.isVersionString(ctx)) {
				tmgr->add(scanner.scanVersionString(ctx));
				ctx->clearBuffer();
				continue;
			}
			//fall through

		case '$': case '@': case '%': case '&': case '*': // all of the sigils
			if (scanner.isPostDeref(ctx)) {
				tk = scanner.scanPostDeref(ctx);
				tmgr->add(tk);
			} else {
				tmgr->add(scanner.scanSymbol(ctx));
			}
			smgr->idx += ctx->progress;
			ctx->progress = 0;
			break;
		case '=': case '^': case '~':
		case ',': case ':': case ';': case '+':
		case '<': case '>': case '|':
		case '!': case '/':
		case '(': case ')': case '{': case '}':
		case '[': case ']': case '?':
		case '\\':
			tmgr->add(scanner.scanSymbol(ctx));
			smgr->idx += ctx->progress;
			ctx->progress = 0;
			break;
		case 'x': {
			char next_ch = smgr->nextChar();
			char after_next_ch = smgr->afterNextChar();
			if (next_ch != '=' || ctx->existsBuffer() ||
				after_next_ch == '=' ||
				after_next_ch == '>' ||
				after_next_ch == '~') {
				ctx->writeBuffer(ch);
			} else {
				tmgr->add(scanner.scanSymbol(ctx));
				smgr->idx += ctx->progress;
				ctx->progress = 0;
			}
			break;
		}
		case '\n':
			tmgr->add(scanner.scanLineDelimiter(ctx));
			tmgr->add(scanner.scanWhiteSpace(ctx)); // For newline character
			break;
		case '0': case '1': case '2': case '3': case '4':
		case '5': case '6': case '7': case '8': case '9':
			if (!ctx->existsBuffer() ||
				(ctx->buffer_idx == 1 && ctx->buffer()[0] == '-')) {
				tmgr->add(scanner.scanNumber(ctx));
				ctx->clearBuffer();
				continue;
			}
		default: {
			char ch = smgr->currentChar();
			if (ch != '\n') ctx->writeBuffer(ch);
			break;
		}
		}
	}
	if (ctx->existsBuffer()) {
		tmgr->add(tmgr->new_Token(ctx->buffer(), ctx->finfo));
		ctx->clearBuffer();
	}
	annotateTokens(ctx, tmgr->tokens);
	return tmgr->tokens;
}

void Lexer::clearContext(void)
{
	free(ctx->tmgr->head);
	free(ctx->buffer_head);
	delete ctx->tmgr->tokens;
	delete ctx->tmgr;
	delete ctx->smgr;
	delete ctx;
	ctx = NULL;
}

void Lexer::dump(Tokens *tokens)
{
	TokenPos it = tokens->begin();
	while (it != tokens->end()) {
		Token *t = ITER_CAST(Token *, it);
		fprintf(stdout, "[%-12s] : %12s \n", t->_data, t->info.name);
		it++;
	}
}

void Lexer::annotateTokens(LexContext *ctx, Tokens *tokens)
{
	Annotator annotator;
	size_t size = tokens->size();
	for (size_t i = 0; i < size; i++) {
		Token *tk = tokens->at(i);
		annotator.annotate(ctx, tk);
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
				if (tk) ns += string(tk->_data);
				else break;
				pos++;
				move_count++;
				if (pos == tokens->end()) break;
				next_tk = ITER_CAST(Token *, pos);
			} while ((tk->info.type == NamespaceResolver &&
					 (next_tk && next_tk->info.kind != TokenKind::Symbol &&
					  next_tk->info.kind != TokenKind::StmtEnd)) ||
					 (next_tk && next_tk->info.type == NamespaceResolver));
			TokenPos end_pos = pos;
			pos -= move_count;
			//if (ns_token->info.type == Namespace) asm("int3");
			ns_token->_data = (new string(ns))->c_str();
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
				string new_str = string(as_token->_data) + string(next_tk->_data);
				as_token->_data = (new string(new_str))->c_str();
				tokens->erase(pos+1);
			}
			break;
		}
		case ShortScalarDereference: case ShortArrayDereference:
		case ShortHashDereference:   case ShortCodeDereference: {
			Token *next_tk = ITER_CAST(Token *, pos+1);
			if (!next_tk) break;
			Token *sp_token = tk;
			string new_str = string(sp_token->_data) + string(next_tk->_data);
			sp_token->_data = (new string(new_str))->c_str();
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
		case TokenType::HereDocumentExecTag: case TokenType::HereDocumentBareTag:
			tag_pos = it;
			break;
		case TokenType::HereDocument: {
			assert(tag_pos != start_pos && "ERROR!: nothing use HereDocumentTag");
			Token *tag = ITER_CAST(Token *, tag_pos);
			switch (tag->info.type) {
				case TokenType::HereDocumentTag: case TokenType::HereDocumentBareTag:
				tag->info.type = Enum::Token::Type::RegDoubleQuote;
				tag->info.kind = Enum::Token::Kind::RegPrefix;
				tag->info.name = "RegDoubleQuote";
				tag->info.data = "qq";
				//tag->data = "qq{" + string(t->_data) + "}";
				tag->_data = (new string("qq{" + string(t->_data) + "}"))->c_str();
				break;
			case TokenType::HereDocumentRawTag:
				tag->info.type = Enum::Token::Type::RegQuote;
				tag->info.kind = Enum::Token::Kind::RegPrefix;
				tag->info.name = "RegQuote";
				tag->info.data = "q";
				//tag->data = "q{" + string(t->_data) + "}";
				tag->_data = (new string("q{" + string(t->_data) + "}"))->c_str();
				break;
			case TokenType::HereDocumentExecTag:
				tag->info.type = Enum::Token::Type::RegExec;
				tag->info.kind = Enum::Token::Kind::RegPrefix;
				tag->info.name = "RegExec";
				tag->info.data = "qx";
				//tag->data = "qx{" + string(t->_data) + "}";
				tag->_data = (new string("qx{" + string(t->_data) + "}"))->c_str();
				break;
			default:
				break;
			}
			tokens->erase(tag_pos-1);
			tokens->erase(it-1);
			it--;
			continue;
			break;
		}
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

bool Lexer::isExpr(Token *tk, Token *prev_tk, TokenType::Type type, TokenKind::Kind kind)
{
	using namespace TokenType;
	assert(tk->tks[0]->info.type == LeftBrace);
	if (tk->token_num > 3 &&
		(tk->tks[1]->info.type == Key   || tk->tks[1]->info.type == String) &&
		(tk->tks[2]->info.type == Arrow || tk->tks[2]->info.type == Comma)) {
		/* { [key|"key"] [,|=>] value ... */
		return true;
	} else if (type == Pointer || (type == Mul || type == Glob) || kind == TokenKind::Term || kind == TokenKind::Function ||/* type == FunctionDecl ||*/
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
	TokenPos start_pos = pos;
	TokenPos intermediate_pos = pos;
	Token *prev_syntax = NULL;
	if (start_token) {
		new_tokens->push_back(start_token);
		intermediate_pos--;
		start_pos = intermediate_pos;
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
			Token *prev = pos != start_pos ? ITER_CAST(Token *, pos-1) : NULL;
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
			Token *intermediate_tk = ITER_CAST(Token *, intermediate_pos);
			if (start_pos == intermediate_pos && intermediate_tk->info.type != LeftBrace) {
				k++;
			}
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
			const char *module_name = tks[i+1]->_data;
			string args;
			for (i += 2; i < root->token_num && tks[i]->info.type != SemiColon; i++) {
				args += " " + string(tks[i]->deparse());
			}
			ret->push_back(new Module(module_name, (new string(args))->c_str()));
		}
		if (i < root->token_num && tks[i]->token_num > 0) {
			Modules *new_mds = getUsedModules(tks[i]);
			ret->insert(ret->end(), new_mds->begin(), new_mds->end());
		}
	}
	return ret;
}
