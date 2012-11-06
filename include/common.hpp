#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <memory.h>
#include <iostream>
#include <vector>
#include <string>
#include <map>
#include <new>
#include <unistd.h>
#include <algorithm>

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
typedef std::vector<Token *> Tokens;
typedef std::vector<Token *>::iterator TokenPos;
