#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <stdint.h>
#include <iostream>
#include <vector>
#include <string>
#include <queue>
#include <map>
#include <new>
#include <unistd.h>
#include <algorithm>
#include <assert.h>
#include <memory>

#define EOL '\0'
#define MAX_TOKEN_SIZE 4096

#define cstr(s) s.c_str()

#ifdef DEBUG_MODE
#define DBG_P(fmt, ...) {\
	fprintf(stderr, fmt, ## __VA_ARGS__);	\
	}
#define DBG_PL(fmt, ...) {\
	fprintf(stderr, fmt, ## __VA_ARGS__);	\
	fprintf(stderr, "\n");						\
	}
#else
#define DBG_P(fmt, ...) {}
#define DBG_PL(fmt, ...) {}
#endif
#define DECL(T, S) {T, #T, S}
#define PTR_SIZE sizeof(void*)

class TokenInfo;
class Token;
class Tokens;
class RawTokens;
class Module;
class Annotator;
class AnnotateMethods;
class AnnotateMethodIterator;
typedef std::vector<Module *> Modules;
typedef std::map<std::string, std::string> StringMap;
typedef std::vector<Token *>::iterator TokenPos;
extern void *safe_malloc(size_t size);
extern void safe_free(void *ptr, size_t size);

#include <gen_token.hpp>
#include <token.hpp>

typedef std::map<Enum::Token::Type::Type, TokenInfo> TypeMap;
typedef std::map<std::string, TokenInfo> TypeDataMap;
typedef std::queue<std::string> StringsQueue;