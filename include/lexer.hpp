#include "common.hpp"
#include "gen_token.hpp"

namespace Enum {
	namespace Lexer {
		namespace Char {
			typedef enum {
				DoubleQuote = '"',
				Hash        = '#',
				Space       = ' ',
				Tab         = '\t',
				BackSlash   = '\\',
				Amp         = '&',
			} Type;
		}
		namespace Syntax {
			typedef enum {
				Value,
				Term,
				Expr,
				Stmt,
				BlockStmt
			} Type;
		}
	}
}

class FileInfo {
public:
	size_t start_line_num;
	size_t end_line_num;
	size_t indent;
	size_t block_id;
	const char *filename;
};

class TokenInfo {
public:
	Enum::Lexer::Token::Type type;
	Enum::Lexer::Kind kind;
	const char *name;
	const char *data;
	bool has_warnings;
};

class Token {
public:
	Enum::Lexer::Syntax::Type stype;
	Enum::Lexer::Token::Type type;
	TokenInfo info;
	FileInfo finfo;
	Token **tks;
	std::string data;
	int idx;
	size_t token_num;
	size_t total_token_num;
	std::string deparsed_data;
	bool isDeparsed;
	bool isDeleted;

	Token(std::string data_, FileInfo finfo);
	Token(Tokens *tokens);
	//~Token(void);
	const char *deparse(void);
};

extern TokenInfo decl_tokens[];
class LexContext {
public:
	char *token;
	size_t max_token_size;
	int token_idx;
	Tokens *tokens;
	Tokens *tks;
	int progress;
	TokenPos itr;

	Enum::Lexer::Token::Type prev_type;
	LexContext(void);
	LexContext(Tokens *tokens);
	Token *tk(void);
	Token *nextToken(void);
	void clearToken(char *token);
	void writeChar(char *token, char ch);
	void next(void);
	bool end(void);
};

class Module {
public:
	const char *name;
	const char *args;
	Module(const char *name, const char *args);
};

class Scanner {
public:
	bool isStringStarted;
	bool isRegexStarted;
	bool isPrototypeStarted;
	bool commentFlag;
	bool hereDocumentFlag;
	FileInfo finfo;
	char start_string_ch;
	char regex_delim;
	char regex_middle_delim;
	int brace_count_inner_regex;
	int bracket_count_inner_regex;
	int cury_brace_count_inner_regex;
	std::string here_document_tag;

	Scanner(void);
	bool isRegexDelim(Token *prev_token, char symbol);
	bool isSkip(LexContext *ctx, char *script, size_t idx);
	Token *scanQuote(LexContext *ctx, char quote);
	Token *scanNewLineKeyword(LexContext *ctx);
	Token *scanTabKeyword(LexContext *ctx);
	Token *scanPrevSymbol(LexContext *ctx, char symbol);
	Token *scanCurSymbol(LexContext *ctx, char symbol);
	Token *scanDoubleCharacterOperator(LexContext *ctx, char symbol, char next_ch);
	Token *scanTripleCharacterOperator(LexContext *ctx, char symbol, char next_ch, char after_next_ch);
	Token *scanSymbol(LexContext *ctx, char symbol);
	Token *scanSymbol(LexContext *ctx, char symbol, char next_ch);
	Token *scanSymbol(LexContext *ctx, char symbol, char next_ch, char after_next_ch);
	Token *scanNumber(LexContext *ctx, char *src, size_t &i);
	bool scanNegativeNumber(LexContext *ctx, char num);
	TokenInfo getTokenInfo(Enum::Lexer::Token::Type type);
	TokenInfo getTokenInfo(const char *data);
};

class Lexer {
public:
	TokenPos start_pos;
	TokenPos pos;
	FileInfo finfo;
	Scanner *scanner;

	Lexer(const char *filename);
	Tokens *tokenize(char *script);
	void annotateTokens(Tokens *tokens);
	void grouping(Tokens *tokens);
	void prepare(Tokens *tokens);
	Token *parseSyntax(Token *start_token, Tokens *tokens);
	void parseSpecificStmt(Token *root);
	void setIndent(Token *tk, int indent);
	void setBlockIDWithBreadthFirst(Token *tk, size_t base_id);
	void setBlockIDWithDepthFirst(Token *tk, size_t *block_id);
	void dump(Tokens *tokens);
	void dumpSyntax(Token *tk, int indent);
	Tokens *getTokensBySyntaxLevel(Token *root, Enum::Lexer::Syntax::Type type);
	Modules *getUsedModules(Token *root);
private:
	bool isExpr(Token *tk, Token *prev_tk, Enum::Lexer::Token::Type type, Enum::Lexer::Kind kind);
	void insertStmt(Token *tk, int idx, size_t grouping_num);
	void insertParenthesis(Tokens *tokens);
};

class Annotator {
public:
	AnnotateMethods *methods;
	std::vector<std::string> vardecl_list;
	std::vector<std::string> funcdecl_list;
	std::vector<std::string> pkgdecl_list;
	Annotator(void);
	void annotate(LexContext *ctx, Token *tk);
private:
	TokenInfo getTokenInfo(Enum::Lexer::Token::Type type);
	TokenInfo getTokenInfo(const char *data);
	bool search(std::vector<std::string> list, std::string target);
	void setAnnotateMethods(AnnotateMethods *methods);
	bool isReservedKeyword(std::string word);
	TokenInfo annotateRegOpt(LexContext *ctx, Token *tk);
	TokenInfo annotateNamespace(LexContext *ctx, Token *tk);
	TokenInfo annotateMethod(LexContext *ctx, Token *tk);
	TokenInfo annotateKey(LexContext *ctx, Token *tk);
	TokenInfo annotateShortScalarDereference(LexContext *ctx, Token *tk);
	TokenInfo annotateReservedKeyword(LexContext *ctx, Token *tk);
	TokenInfo annotateNamelessFunction(LexContext *ctx, Token *tk);
	TokenInfo annotateLocalVariable(LexContext *ctx, Token *tk);
	TokenInfo annotateVariable(LexContext *ctx, Token *tk);
	TokenInfo annotateGlobalVariable(LexContext *ctx, Token *tk);
	TokenInfo annotateFunction(LexContext *ctx, Token *tk);
	TokenInfo annotateCall(LexContext *ctx, Token *tk);
	TokenInfo annotateClass(LexContext *ctx, Token *tk);
	TokenInfo annotateUsedName(LexContext *ctx, Token *tk);
	TokenInfo annotateBareWord(LexContext *ctx, Token *tk);
};

typedef TokenInfo (Annotator::*AnnotateMethod)(LexContext *ctx, Token *tk);
class AnnotateMethods : public std::vector<AnnotateMethod> {
public:
	Annotator *executor;

	AnnotateMethods(void);
	void add(AnnotateMethod method);
	void setAnnotator(Annotator *executor);
	std::vector<AnnotateMethod>::iterator iterator(void);
};

#define isSKIP() commentFlag
extern void *safe_malloc(size_t size);
extern void safe_free(void *ptr, size_t size);

