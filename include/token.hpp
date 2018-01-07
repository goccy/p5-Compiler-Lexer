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
	size_t token_num;
	size_t total_token_num;
	const char *deparsed_data;
	bool isDeparsed;
	bool isDeleted;
	size_t idx;

	Token(){}
	Token(std::string data_, FileInfo finfo);
	Token(Tokens *tokens);
	const char *deparse(void);

	inline std::unique_ptr<Token> clone() {
		return std::make_unique<Token>(*this);
	}

};

class Tokens : private std::vector< std::unique_ptr<Token> > {
public:
	using std::vector< std::unique_ptr<Token> >::push_back;
	using std::vector< std::unique_ptr<Token> >::at;
	using std::vector< std::unique_ptr<Token> >::begin;
	using std::vector< std::unique_ptr<Token> >::end;
	using std::vector< std::unique_ptr<Token> >::back;
	using std::vector< std::unique_ptr<Token> >::erase;
	using std::vector< std::unique_ptr<Token> >::size;
	using std::vector< std::unique_ptr<Token> >::pop_back;
	using std::vector< std::unique_ptr<Token> >::insert;
	using std::vector< std::unique_ptr<Token> >::capacity;
	using std::vector< std::unique_ptr<Token> >::emplace_back;

	Tokens(void) {}
	inline void add(Token *token) {
		if (token) emplace_back(token->clone());
	}

	inline Token *get(size_t i) {
		return (i < size()) ? at(i).get() : NULL;
	}

	inline void remove(size_t) {
		//erase(idx);
	}

	inline Token *lastToken(void) {
		return (size() > 0) ? back().get() : NULL;
	}
};

extern TokenInfo decl_tokens[];
extern TokenInfo type_to_info[];
