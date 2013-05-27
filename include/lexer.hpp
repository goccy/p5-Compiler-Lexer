#include <common.hpp>

class TokenManager {
public:
	Tokens *tokens;
	size_t max_token_size;
	size_t idx;
	TypeMap type_to_info_map;
	TypeDataMap data_to_info_map;

	TokenManager(void);
	Token *getTokenByBase(Token *base, int offset);
	Token *getTokenByIdx(size_t idx);
	Token *beforePreviousToken(void);
	Token *previousToken(void);
	Token *currentToken(void);
	Token *nextToken(void);
	Token *afterNextToken(void);
	void remove(size_t idx);
	TokenInfo getTokenInfo(Enum::Token::Type::Type type);
	TokenInfo getTokenInfo(const char *data);
	void add(Token *tk);
	bool end(void);
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
	bool compare(int start, int end, std::string target);
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

class LexContext {
public:
	ScriptManager *smgr;
	TokenManager  *tmgr;
	FileInfo finfo;
	Tokens *tks;
	int progress;
	char *token_buffer;
	size_t buffer_idx;
	size_t script_size;
	TokenPos itr;
	Enum::Token::Type::Type prev_type;

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
	bool isFormatStarted;
	bool isFormatDeclared;
	bool commentFlag;
	bool hereDocumentFlag;
	bool skipFlag;
	char start_string_ch;
	char regex_delim;
	char regex_middle_delim;
	int brace_count_inner_regex;
	int bracket_count_inner_regex;
	int cury_brace_count_inner_regex;
	std::string here_document_tag;
	StringMap regex_prefix_map;
	StringMap regex_replace_map;
	StringMap operator_map;

	Scanner(void);
	bool isRegexStartDelim(LexContext *ctx, const StringMap &list);
	bool isRegexEndDelim(LexContext *ctx);
	bool isRegexDelim(Token *prev_token, char symbol);
	bool isHereDocument(LexContext *ctx, Token *prev_token);
	bool isFormat(LexContext *ctx, Token *tk);
	bool isVersionString(LexContext *ctx);
	bool isSkip(LexContext *ctx);
	bool isPrototype(LexContext *ctx);
	char getRegexDelim(LexContext *ctx);
	Token *scanQuote(LexContext *ctx, char quote);
	Token *scanNewLineKeyword(LexContext *ctx);
	Token *scanTabKeyword(LexContext *ctx);
	Token *scanPrevSymbol(LexContext *ctx, char symbol);
	Token *scanCurSymbol(LexContext *ctx, char symbol);
	Token *scanDoubleCharacterOperator(LexContext *ctx, char symbol, char next_ch);
	Token *scanTripleCharacterOperator(LexContext *ctx, char symbol, char next_ch, char after_next_ch);
	Token *scanSymbol(LexContext *ctx);
	Token *scanWordDelimiter(LexContext *ctx);
	Token *scanReference(LexContext *ctx);
	Token *scanSingleLineComment(LexContext *ctx);
	Token *scanLineDelimiter(LexContext *ctx);
	Token *scanNumber(LexContext *ctx);
	Token *scanVersionString(LexContext *ctx);
	bool scanNegativeNumber(LexContext *ctx, char num);
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
	void grouping(Tokens *tokens);
	void prepare(Tokens *tokens);
	Token *parseSyntax(Token *start_token, Tokens *tokens);
	void parseSpecificStmt(Token *root);
	void setIndent(Token *tk, int indent);
	void setBlockIDWithBreadthFirst(Token *tk, size_t base_id);
	void setBlockIDWithDepthFirst(Token *tk, size_t *block_id);
	void dump(Tokens *tokens);
	void dumpSyntax(Token *tk, int indent);
	Tokens *getTokensBySyntaxLevel(Token *root, Enum::Parser::Syntax::Type type);
	Modules *getUsedModules(Token *root);
private:
	void annotateTokens(LexContext *ctx);
	bool isExpr(Token *tk, Token *prev_tk, Enum::Token::Type::Type type, Enum::Token::Kind::Kind kind);
	void insertStmt(Token *tk, int idx, size_t grouping_num);
	void insertParenthesis(Tokens *tokens);
};

class Annotator {
public:
	StringMap vardecl_map;
	StringMap funcdecl_map;
	StringMap pkgdecl_map;
	Annotator(void);
	void annotate(LexContext *ctx, Token *tk);
private:
	void annotateRegOpt(LexContext *ctx, Token *tk, TokenInfo *info);
	void annotateNamespace(LexContext *ctx, Token *tk, TokenInfo *info);
	void annotateMethod(LexContext *ctx, Token *tk, TokenInfo *info);
	void annotateKey(LexContext *ctx, Token *tk, TokenInfo *info);
	void annotateShortScalarDereference(LexContext *ctx, Token *tk, TokenInfo *info);
	void annotateReservedKeyword(LexContext *ctx, Token *tk, TokenInfo *info);
	void annotateNamelessFunction(LexContext *ctx, Token *tk, TokenInfo *info);
	void annotateLocalVariable(LexContext *ctx, Token *tk, TokenInfo *info);
	void annotateVariable(LexContext *ctx, Token *tk, TokenInfo *info);
	void annotateGlobalVariable(LexContext *ctx, Token *tk, TokenInfo *info);
	void annotateFunction(LexContext *ctx, Token *tk, TokenInfo *info);
	void annotateCall(LexContext *ctx, Token *tk, TokenInfo *info);
	void annotateClass(LexContext *ctx, Token *tk, TokenInfo *info);
	void annotateModuleName(LexContext *ctx, Token *tk, TokenInfo *info);
	void annotateBareWord(LexContext *ctx, Token *tk, TokenInfo *info);
};

#define isSKIP() commentFlag
