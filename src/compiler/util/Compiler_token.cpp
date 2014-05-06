#include <lexer.hpp>

using namespace std;
namespace TokenType = Enum::Token::Type;
namespace SyntaxType = Enum::Parser::Syntax;
namespace TokenKind = Enum::Token::Kind;

Token::Token(string data_, FileInfo finfo_) :
	token_num(0), total_token_num(0),
	deparsed_data(""), isDeparsed(false), isDeleted(false)
{
	type = TokenType::Undefined;
	stype = SyntaxType::Value;
	info.type = TokenType::Undefined;
	info.kind = TokenKind::Undefined;
	info.name = "";
	info.data = NULL;
	info.has_warnings = false;
	finfo.start_line_num = finfo_.start_line_num;
	finfo.end_line_num = finfo_.start_line_num;
	finfo.filename = finfo_.filename;
	finfo.indent = 0;
}

Token::Token(Tokens *tokens) :
	deparsed_data(""), isDeparsed(false), isDeleted(false)
{
	total_token_num = 0;
	stype = SyntaxType::Value;
	type =  TokenType::Undefined;
	info.type = TokenType::Undefined;
	info.kind = TokenKind::Undefined;
	info.name = "";
	info.data = NULL;
	info.has_warnings = false;
	_data = "";
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
		if (t->info.has_warnings) {
			info.has_warnings = true;
		}
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

const char *Token::deparse(void)
{
	using namespace TokenType;
	if (isDeparsed) return deparsed_data;
	string data;
	isDeparsed = true;
	if (this->token_num > 0) {
		if (stype == SyntaxType::Expr) {
			//deparsed_data += "(";
		}
		for (size_t i = 0; i < this->token_num; i++) {
			data += string(this->tks[i]->deparse());
		}
		if (stype == SyntaxType::Expr) {
			//deparsed_data += ")";
		}
	} else {
		switch (info.type) {
		case String:
			data += " \"" + string(this->_data) + "\"";
			break;
		case RawString:
			data += " '" + string(this->_data) + "'";
			break;
		case ExecString:
			data += " `" + string(this->_data) + "`";
			break;
		case RegExp: case Pointer:
		case RegReplaceFrom: case RegReplaceTo:
		case RegMiddleDelim: case RegDelim:
		case RegOpt:
			data += string(this->_data);
			break;
		case HereDocument:
			data += "\n" + string(this->_data);
			break;
		case HereDocumentEnd:
			data += string(this->_data) + "\n";
			break;
		default:
			data += " " + string(this->_data);
			break;
		}
	}
	deparsed_data = (new string(data))->c_str();//cstr(deparsed_data);
	return deparsed_data;
}
