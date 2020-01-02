#include <common.hpp>
#include <keyword.hpp>

typedef Token TokenPool;

class TokenManager {
public:
	Tokens *tokens;
	size_t max_token_size;
	TypeMap type_to_info_map;
	TypeDataMap data_to_info_map;
	TypeMap::iterator type_to_info_map_end;
	TypeDataMap::iterator data_to_info_map_end;
	ReservedKeywordMap keyword_map;
	TokenInfo undefined_info;
	Token *head;
	TokenPool *pool;
	bool verbose;

	TokenManager(void);
	TokenManager(size_t script_size, bool verbose);
	inline Token *new_Token(char *data, FileInfo finfo) {
		Token *ret = pool++;
		ret->stype = Enum::Parser::Syntax::Value;
		ret->type = Enum::Token::Type::Undefined;
		ret->finfo = finfo;
		ret->info = undefined_info;
		ret->_data = data;
		ret->token_num = 0;
		ret->total_token_num = 0;
		ret->deparsed_data = "";
		return ret;
	}
	Token *at(size_t i);
	size_t size(void);
	void dump(void);
	size_t currentIdx();
	Token *getTokenByBase(size_t base, int offset);
	Token *getTokenByIdx(size_t idx);
	Token *beforePreviousToken(void);
	Token *beforePreviousToken(size_t i);
	Token *previousToken(void);
	Token *previousToken(size_t i);
	Token *nextToken(void);
	Token *nextToken(size_t i);
	Token *beforeLastToken(void);
	Token *lastToken(void);
	inline TokenInfo getTokenInfo(Enum::Token::Type::Type type) {
		return type_to_info[type];
	}

	inline TokenInfo getTokenInfo(const char *data) {
		ReservedKeyword *ret = keyword_map.in_word_set(data, strlen(data));
		if (ret) return ret->info;
		return undefined_info;
	}

	inline void add(Token *tk) {
		if (tk) tokens->add(tk);
	}
};

class ScriptManager {
public:
	char *_script;
	char *raw_script;
	size_t script_size;
	size_t idx;

	ScriptManager(char *script);
	bool compare(int start, int end, std::string target);
	inline char getCharByOffset(int offset) {
		size_t current_idx = this->idx;
		int wanted_idx = current_idx + offset;
		return (0 <= wanted_idx && (size_t)wanted_idx < script_size) ?
			raw_script[wanted_idx] : EOL;
	}

	inline char beforePreviousChar(void) {
		size_t current_idx = this->idx;
		int wanted_idx = current_idx - 2;
		return (0 <= wanted_idx) ? raw_script[wanted_idx] : EOL;
	}

	inline char previousChar(void) {
		size_t current_idx = this->idx;
		int wanted_idx = current_idx - 1;
		return (0 <= wanted_idx) ? raw_script[wanted_idx] : EOL;
	}

	inline char currentChar(void) {
		return idx < script_size ? raw_script[idx] : EOL;
	}

	inline char nextChar(void) {
		size_t current_idx = this->idx;
		int wanted_idx = current_idx + 1;
		return ((size_t)wanted_idx < script_size) ?	raw_script[wanted_idx] : EOL;
	}

	inline char afterNextChar(void) {
		size_t current_idx = this->idx;
		int wanted_idx = current_idx + 2;
		return ((size_t)wanted_idx < script_size) ?	raw_script[wanted_idx] : EOL;
	}

	inline char next(void) {
		return raw_script[++idx];
	}

	inline char back(void) {
		return raw_script[--idx];
	}

	inline bool end(void) {
		return idx >= script_size;
	}

	inline char forward(size_t progress) {
		this->idx += progress;
		return raw_script[idx];
	}
};

class LexContext {
public:
	ScriptManager *smgr;
	TokenManager  *tmgr;
	FileInfo finfo;
	int progress;
	char *buffer_head;
	char *token_buffer;
	size_t buffer_idx;
	size_t script_size;
	TokenPos itr;
	Enum::Token::Type::Type prev_type;

	LexContext(const char *filename, char *script, bool verbose);
	LexContext(Tokens *tokens);

	inline char *buffer(void) {
		return token_buffer;
	}

	inline void clearBuffer(void) {
		token_buffer += buffer_idx;
		token_buffer[0] = EOL;
		buffer_idx = 0;
		token_buffer++;
		token_buffer[0] = EOL;
	}

	inline void writeBuffer(char ch) {
		token_buffer[buffer_idx++] = ch;
		token_buffer[buffer_idx] = EOL;
	}

	inline void writeBuffer(const char *str) {
		for (size_t i = 0; str[i] != EOL; i++) {
			token_buffer[buffer_idx++] = str[i];
		}
		token_buffer[buffer_idx] = EOL;
	}

	inline bool existsBuffer(void) {
		return token_buffer[0] != EOL;
	}

	Token *tk(void);
	Token *nextToken(void);
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
	size_t formatDeclaredTokenIdx;
	bool formatDeclaredTokenFlag;
	bool commentFlag;
	bool skipFlag;
	char start_string_ch;
	char regex_delim;
	char regex_middle_delim;
	int brace_count_inner_regex;
	int bracket_count_inner_regex;
	int cury_brace_count_inner_regex;
	Token *here_document_tag_tk;
	StringsQueue here_document_tags;
	StringMap regex_prefix_map;
	StringMap regex_replace_map;
	StringMap enable_regex_argument_func_map;
	StringMap dereference_prefix_map;
	DoubleCharactorOperatorMap double_operator_map;
	TripleCharactorOperatorMap triple_operator_map;
	StringMap operator_map;
	bool verbose;

	Scanner(void);
	bool isRegexStartDelim(LexContext *ctx, const StringMap &list);
	bool isRegexEndDelim(LexContext *ctx);
	bool isRegexDelim(LexContext *ctx, Token *prev_token, char symbol);
	bool isHereDocument(LexContext *ctx, Token *prev_token);
	bool isPostDeref(LexContext *ctx);
	bool isFormat(LexContext *ctx, Token *tk);
	bool isVersionString(LexContext *ctx);
	bool isRegex(LexContext *ctx);
	bool isSkip(LexContext *ctx);
	bool isPrototype(LexContext *ctx);
	bool isRegexOptionPrevToken(LexContext *ctx);
	bool isRegexOption(const char *opt);
	char getRegexDelim(LexContext *ctx);
	Token *scanQuote(LexContext *ctx, char quote);
	Token *scanRegQuote(LexContext *ctx, char delim);
	Token *scanNewLineKeyword(LexContext *ctx);
	Token *scanTabKeyword(LexContext *ctx);
	Token *scanPrevSymbol(LexContext *ctx, char symbol);
	Token *scanCurSymbol(LexContext *ctx, char symbol);
	Token *scanDoubleCharacterOperator(LexContext *ctx, char symbol, char next_ch);
	Token *scanTripleCharacterOperator(LexContext *ctx, char symbol, char next_ch, char after_next_ch);
	Token *scanPostDeref(LexContext *ctx);
	Token *scanSymbol(LexContext *ctx);
	Token *scanWordDelimiter(LexContext *ctx);
	Token *scanReference(LexContext *ctx);
	Token *scanSingleLineComment(LexContext *ctx);
	Token *scanLineDelimiter(LexContext *ctx);
	Token *scanNumber(LexContext *ctx);
	Token *scanVersionString(LexContext *ctx);
	Token *scanWhiteSpace(LexContext *ctx);
	bool scanNegativeNumber(LexContext *ctx, char num);

	inline bool hereDocumentFlag(void) {
		return here_document_tags.size() > 0;
	}
};

class Lexer {
public:
	TokenPos head;
	size_t start_pos;
	size_t pos;
	FileInfo finfo;
	const char *filename;
	bool verbose;
	LexContext *ctx;

	Lexer(const char *filename, bool verbose);
	~Lexer(void);
	Tokens *tokenize(char *script);
	void clearContext(void);
	void grouping(RawTokens *tokens);
	void prepare(RawTokens *tokens);
	Token *parseSyntax(Token *start_token, RawTokens *tokens);
	void parseSpecificStmt(Token *root);
	void setIndent(Token *tk, int indent);
	void setBlockIDWithBreadthFirst(Token *tk, size_t base_id);
	void setBlockIDWithDepthFirst(Token *tk, size_t *block_id);
	void dump(RawTokens *tokens);
	void dumpSyntax(Token *tk, int indent);
	RawTokens *getTokensBySyntaxLevel(Token *root, Enum::Parser::Syntax::Type type);
	Modules *getUsedModules(Token *root);
private:
	void annotateTokens(LexContext *ctx, Tokens *tokens);
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
	void annotate(LexContext *ctx, size_t idx);
private:
	bool isRegexOption(const char *opt);
	void annotateRegOpt(LexContext *ctx, const std::string &data, Token *tk, size_t idx, TokenInfo *info);
	void annotateNamespace(LexContext *ctx, const std::string &data, Token *tk, size_t idx, TokenInfo *info);
	void annotateMethod(LexContext *ctx, const std::string &data, Token *tk, size_t idx, TokenInfo *info);
	void annotateKey(LexContext *ctx, const std::string &data, Token *tk, size_t idx, TokenInfo *info);
	void annotateShortScalarDereference(LexContext *ctx, const std::string &data, Token *tk, size_t idx, TokenInfo *info);
	void annotateCallDecl(LexContext *ctx, const std::string &data, Token *tk, size_t idx, TokenInfo *info);
	void annotateHandleDelimiter(LexContext *ctx, const std::string &data, Token *tk, size_t idx, TokenInfo *info);
	void annotateReservedKeyword(LexContext *ctx, const std::string &data, Token *tk, size_t idx, TokenInfo *info);
	void annotateGlobOrMul(LexContext *ctx, const std::string &data, Token *tk, size_t idx, TokenInfo *info);
	void annotateNamelessFunction(LexContext *ctx, const std::string &data, Token *tk, size_t idx, TokenInfo *info);
	void annotateLocalVariable(LexContext *ctx, const std::string &data, Token *tk, size_t idx, TokenInfo *info);
	void annotateVariable(LexContext *ctx, const std::string &data, Token *tk, size_t idx, TokenInfo *info);
	void annotateGlobalVariable(LexContext *ctx, const std::string &data, Token *tk, size_t idx, TokenInfo *info);
	void annotateFunction(LexContext *ctx, const std::string &data, Token *tk, size_t idx, TokenInfo *info);
	void annotateCall(LexContext *ctx, const std::string &data, Token *tk, size_t idx, TokenInfo *info);
	void annotateClass(LexContext *ctx, const std::string &data, Token *tk, size_t idx, TokenInfo *info);
	void annotateModuleName(LexContext *ctx, const std::string &data, Token *tk, size_t idx, TokenInfo *info);
	void annotateBareWord(LexContext *ctx, const std::string &data, Token *tk, size_t idx, TokenInfo *info);
};

#define isSKIP() commentFlag
