namespace Enum {
	namespace Parser {
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
	Enum::Token::Type::Type type;
	Enum::Token::Kind::Kind kind;
	const char *name;
	const char *data;
	bool has_warnings;
};

class Token {
public:
	Enum::Parser::Syntax::Type stype;
	Enum::Token::Type::Type type;
	TokenInfo info;
	FileInfo finfo;
	Token **tks;
	const char *_data;
	std::string data;
	size_t token_num;
	size_t total_token_num;
	const char *deparsed_data;
	bool isDeparsed;
	bool isDeleted;

	Token(std::string data_, FileInfo finfo);
	Token(Tokens *tokens);
	const char *deparse(void);
};

class Tokens : public std::vector<Token *> {
public:

	Tokens(void) {}
	inline void add(Token *token) {
		if (token) push_back(token);
	}

	inline void remove(size_t) {
		//erase(idx);
	}

	inline Token *lastToken(void) {
		return (size() > 0) ? back() : NULL;
	}
};

extern TokenInfo decl_tokens[];
extern TokenInfo type_to_info[];
