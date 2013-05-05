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

class Tokens : public std::vector<Token *> {
public:
	Tokens(void);
	void add(Token *token);
	void remove(size_t idx);
	Token *lastToken(void);
};

class TokenManager {
public:
	Tokens *tokens;
	size_t max_token_size;
	size_t idx;

	TokenManager(void);
	Token *getTokenByBase(Token *base, int offset);
	Token *getTokenByIdx(size_t idx);
	Token *beforePreviousToken(void);
	Token *previousToken(void);
	Token *currentToken(void);
	Token *nextToken(void);
	Token *afterNextToken(void);
	Token *next(void);
	Token *back(void);
};

class ScriptManager {
public:
	char *_script;
	char *raw_script;
	size_t script_size;
	size_t idx;

	ScriptManager(char *script);
	char getCharByOffset(int offset);
	char beforePreviousChar(void);
	char previousChar(void);
	char currentChar(void);
	char nextChar(void);
	char afterNextChar(void);
	char next(void);
	char back(void);
	bool end(void);
	char forward(size_t progress);
};

extern TokenInfo decl_tokens[];
class LexContext {
public:
	ScriptManager *smgr;
	TokenManager  *tmgr;
	FileInfo finfo;
	Tokens *tokens;
	Tokens *tks;
	int progress;
	char *token_buffer;
	size_t buffer_idx;
	size_t script_size;
	TokenPos itr;
	Enum::Lexer::Token::Type prev_type;

	LexContext(const char *filename, char *script);
	LexContext(Tokens *tokens);
	Token *tk(void);
	Token *nextToken(void);
	char *buffer(void);
	void clearBuffer(void);
	void writeBuffer(char ch);
	bool existsBuffer(void);
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
	char start_string_ch;
	char regex_delim;
	char regex_middle_delim;
	int brace_count_inner_regex;
	int bracket_count_inner_regex;
	int cury_brace_count_inner_regex;
	std::string here_document_tag;

	Scanner(void);
	bool isRegexStartDelim(LexContext *ctx, const StringMap &list);
	bool isRegexDelim(Token *prev_token, char symbol);
	bool isHereDocument(LexContext *ctx, Token *prev_token);
	bool isSkip(LexContext *ctx);
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
	Token *scanNumber(LexContext *ctx);
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
	const char *filename;

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

