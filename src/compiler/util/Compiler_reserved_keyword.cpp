/* C++ code produced by gperf version 3.0.3 */
/* Command-line: gperf -L C++ -Z ReservedKeywordMap -t gen/reserved_keywords.gperf  */
/* Computed positions: -k'1-2,4-5,$' */

#if !((' ' == 32) && ('!' == 33) && ('"' == 34) && ('#' == 35) \
      && ('%' == 37) && ('&' == 38) && ('\'' == 39) && ('(' == 40) \
      && (')' == 41) && ('*' == 42) && ('+' == 43) && (',' == 44) \
      && ('-' == 45) && ('.' == 46) && ('/' == 47) && ('0' == 48) \
      && ('1' == 49) && ('2' == 50) && ('3' == 51) && ('4' == 52) \
      && ('5' == 53) && ('6' == 54) && ('7' == 55) && ('8' == 56) \
      && ('9' == 57) && (':' == 58) && (';' == 59) && ('<' == 60) \
      && ('=' == 61) && ('>' == 62) && ('?' == 63) && ('A' == 65) \
      && ('B' == 66) && ('C' == 67) && ('D' == 68) && ('E' == 69) \
      && ('F' == 70) && ('G' == 71) && ('H' == 72) && ('I' == 73) \
      && ('J' == 74) && ('K' == 75) && ('L' == 76) && ('M' == 77) \
      && ('N' == 78) && ('O' == 79) && ('P' == 80) && ('Q' == 81) \
      && ('R' == 82) && ('S' == 83) && ('T' == 84) && ('U' == 85) \
      && ('V' == 86) && ('W' == 87) && ('X' == 88) && ('Y' == 89) \
      && ('Z' == 90) && ('[' == 91) && ('\\' == 92) && (']' == 93) \
      && ('^' == 94) && ('_' == 95) && ('a' == 97) && ('b' == 98) \
      && ('c' == 99) && ('d' == 100) && ('e' == 101) && ('f' == 102) \
      && ('g' == 103) && ('h' == 104) && ('i' == 105) && ('j' == 106) \
      && ('k' == 107) && ('l' == 108) && ('m' == 109) && ('n' == 110) \
      && ('o' == 111) && ('p' == 112) && ('q' == 113) && ('r' == 114) \
      && ('s' == 115) && ('t' == 116) && ('u' == 117) && ('v' == 118) \
      && ('w' == 119) && ('x' == 120) && ('y' == 121) && ('z' == 122) \
      && ('{' == 123) && ('|' == 124) && ('}' == 125) && ('~' == 126))
/* The character set is not based on ISO-646.  */
#error "gperf generated tables don't work with this execution character set. Please report a bug to <bug-gnu-gperf@gnu.org>."
#endif

#include <lexer.hpp>

#define TOTAL_KEYWORDS 411
#define MIN_WORD_LENGTH 1
#define MAX_WORD_LENGTH 16
#define MIN_HASH_VALUE 1
#define MAX_HASH_VALUE 1262
/* maximum key range = 1262, duplicates = 0 */

inline unsigned int
ReservedKeywordMap::hash (register const char *str, register unsigned int len)
{
  static unsigned short asso_values[] =
    {
      1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263,
      1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263,
      1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263,
      1263, 1263, 1263,  140,  400,  195,   25,  185,   20,  395,
       325,  320,  200,  235,  315,  420,  190,  285,  380,  370,
        40,  365,  360,  350,  345,  335,  245,   95,   80,  305,
       250,    5,  215,  290,   60,  140,   65,   20,  200,   70,
        85,   40,   25,    5, 1263,   15,   15,  230,   60,  185,
        45, 1263,  110,   85,   55,  200,   15,  225,  205,   45,
      1263,  260,  165,  210,  125,  120,   65,  245,  270,   50,
       150,    0,  280,   25,  125,  150,   20,  160,  120,  115,
        20,   80,   35,   95,   40,   15,   10,  155,   65,  240,
       220,  345,  125,  295,  280,    0,  170, 1263, 1263, 1263,
      1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263,
      1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263,
      1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263,
      1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263,
      1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263,
      1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263,
      1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263,
      1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263,
      1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263,
      1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263,
      1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263,
      1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263, 1263,
      1263, 1263, 1263, 1263, 1263, 1263
    };
  register int hval = (int)len;

  switch (hval)
    {
      default:
        hval += asso_values[(unsigned char)str[4]];
      /*FALLTHROUGH*/
      case 4:
        hval += asso_values[(unsigned char)str[3]];
      /*FALLTHROUGH*/
      case 3:
      case 2:
        hval += asso_values[(unsigned char)str[1]];
      /*FALLTHROUGH*/
      case 1:
        hval += asso_values[(unsigned char)str[0]];
        break;
    }
  return hval + asso_values[(unsigned char)str[len - 1]];
}

ReservedKeyword *
ReservedKeywordMap::in_word_set (register const char *str, register unsigned int len)
{
  static ReservedKeyword wordlist[] =
    {
      {""},
#line 334 "gen/reserved_keywords.gperf"
      {"}", {Enum::Token::Type::RightBrace, Enum::Token::Kind::Symbol, "RightBrace", "}"}},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
#line 74 "gen/reserved_keywords.gperf"
      {"=", {Enum::Token::Type::Assign, Enum::Token::Kind::Assign, "Assign", "="}},
      {""}, {""}, {""}, {""}, {""},
#line 41 "gen/reserved_keywords.gperf"
      {"==", {Enum::Token::Type::EqualEqual, Enum::Token::Kind::Operator, "EqualEqual", "=="}},
      {""}, {""}, {""}, {""},
#line 53 "gen/reserved_keywords.gperf"
      {"ne", {Enum::Token::Type::StringNotEqual, Enum::Token::Kind::Operator, "StringNotEqual", "ne"}},
      {""}, {""}, {""}, {""},
#line 51 "gen/reserved_keywords.gperf"
      {"ge", {Enum::Token::Type::StringGreaterEqual, Enum::Token::Kind::Operator, "StringGreaterEqual", "ge"}},
      {""}, {""}, {""},
#line 422 "gen/reserved_keywords.gperf"
      {"s", {Enum::Token::Type::RegReplace, Enum::Token::Kind::RegReplacePrefix, "RegReplace", "s"}},
#line 64 "gen/reserved_keywords.gperf"
      {"&=", {Enum::Token::Type::AndBitEqual, Enum::Token::Kind::Assign, "AndBitEqual", "&="}},
      {""}, {""}, {""}, {""},
#line 378 "gen/reserved_keywords.gperf"
      {"$=", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$="}},
      {""}, {""},
#line 318 "gen/reserved_keywords.gperf"
      {"state", {Enum::Token::Type::StateDecl, Enum::Token::Kind::Decl, "StateDecl", "state"}},
      {""}, {""}, {""},
#line 283 "gen/reserved_keywords.gperf"
      {"next", {Enum::Token::Type::Next, Enum::Token::Kind::Control, "Next", "next"}},
      {""}, {""},
#line 50 "gen/reserved_keywords.gperf"
      {"gt", {Enum::Token::Type::StringGreater, Enum::Token::Kind::Operator, "StringGreater", "gt"}},
#line 68 "gen/reserved_keywords.gperf"
      {"&&=", {Enum::Token::Type::AndEqual, Enum::Token::Kind::Assign, "AndEqual", "&&="}},
#line 158 "gen/reserved_keywords.gperf"
      {"stat", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "stat"}},
#line 244 "gen/reserved_keywords.gperf"
      {"setservent", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "setservent"}},
      {""}, {""},
#line 238 "gen/reserved_keywords.gperf"
      {"getservbyname", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "getservbyname"}},
#line 242 "gen/reserved_keywords.gperf"
      {"setnetent", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "setnetent"}},
#line 228 "gen/reserved_keywords.gperf"
      {"endservent", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "endservent"}},
#line 208 "gen/reserved_keywords.gperf"
      {"semget", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "semget"}},
#line 233 "gen/reserved_keywords.gperf"
      {"getnetbyname", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "getnetbyname"}},
      {""},
#line 216 "gen/reserved_keywords.gperf"
      {"endnetent", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "endnetent"}},
#line 240 "gen/reserved_keywords.gperf"
      {"getservent", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "getservent"}},
      {""},
#line 62 "gen/reserved_keywords.gperf"
      {"&&", {Enum::Token::Type::And, Enum::Token::Kind::Operator, "And", "&&"}},
#line 239 "gen/reserved_keywords.gperf"
      {"getservbyport", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "getservbyport"}},
#line 234 "gen/reserved_keywords.gperf"
      {"getnetent", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "getnetent"}},
#line 169 "gen/reserved_keywords.gperf"
      {"reset", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "reset"}},
      {""},
#line 366 "gen/reserved_keywords.gperf"
      {"$&", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$&"}},
      {""}, {""}, {""},
#line 193 "gen/reserved_keywords.gperf"
      {"getpeername", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "getpeername"}},
#line 343 "gen/reserved_keywords.gperf"
      {"&$", {Enum::Token::Type::ShortCodeDereference, Enum::Token::Kind::Modifier, "ShortCodeDereference", "&$"}},
      {""}, {""}, {""}, {""},
#line 386 "gen/reserved_keywords.gperf"
      {"$$", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$$"}},
      {""}, {""}, {""},
#line 132 "gen/reserved_keywords.gperf"
      {"select", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "select"}},
      {""}, {""}, {""}, {""}, {""},
#line 90 "gen/reserved_keywords.gperf"
      {"reverse", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "reverse"}},
      {""}, {""}, {""}, {""},
#line 420 "gen/reserved_keywords.gperf"
      {"tr", {Enum::Token::Type::RegAllReplace, Enum::Token::Kind::RegReplacePrefix, "RegAllReplace", "tr"}},
      {""}, {""}, {""}, {""},
#line 232 "gen/reserved_keywords.gperf"
      {"getnetbyaddr", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "getnetbyaddr"}},
#line 225 "gen/reserved_keywords.gperf"
      {"setgrent", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "setgrent"}},
      {""},
#line 272 "gen/reserved_keywords.gperf"
      {"CHECK", {Enum::Token::Type::ModWord, Enum::Token::Kind::ModWord, "ModWord", "CHECK"}},
      {""}, {""},
#line 214 "gen/reserved_keywords.gperf"
      {"endgrent", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "endgrent"}},
      {""}, {""}, {""},
#line 358 "gen/reserved_keywords.gperf"
      {"$2", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$2"}},
#line 218 "gen/reserved_keywords.gperf"
      {"getgrent", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "getgrent"}},
#line 410 "gen/reserved_keywords.gperf"
      {"@INC", {Enum::Token::Type::LibraryDirectories, Enum::Token::Kind::Term, "LibraryDirectories", "@INC"}},
      {""},
#line 243 "gen/reserved_keywords.gperf"
      {"setprotoent", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "setprotoent"}},
#line 341 "gen/reserved_keywords.gperf"
      {"@$", {Enum::Token::Type::ShortArrayDereference, Enum::Token::Kind::Modifier, "ShortArrayDereference", "@$"}},
#line 77 "gen/reserved_keywords.gperf"
      {"not", {Enum::Token::Type::AlphabetNot, Enum::Token::Kind::SingleTerm, "AlphabetNot", "not"}},
#line 235 "gen/reserved_keywords.gperf"
      {"getprotobyname", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "getprotobyname"}},
      {""},
#line 227 "gen/reserved_keywords.gperf"
      {"endprotoent", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "endprotoent"}},
#line 179 "gen/reserved_keywords.gperf"
      {"setpgrp", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "setpgrp"}},
#line 142 "gen/reserved_keywords.gperf"
      {"vec", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "vec"}},
#line 89 "gen/reserved_keywords.gperf"
      {"sort", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "sort"}},
#line 124 "gen/reserved_keywords.gperf"
      {"print", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "print"}},
#line 237 "gen/reserved_keywords.gperf"
      {"getprotoent", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "getprotoent"}},
#line 49 "gen/reserved_keywords.gperf"
      {"le", {Enum::Token::Type::StringLessEqual, Enum::Token::Kind::Operator, "StringLessEqual", "le"}},
      {""},
#line 321 "gen/reserved_keywords.gperf"
      {"else", {Enum::Token::Type::ElseStmt, Enum::Token::Kind::Stmt, "ElseStmt", "else"}},
      {""}, {""},
#line 174 "gen/reserved_keywords.gperf"
      {"getpgrp", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "getpgrp"}},
#line 139 "gen/reserved_keywords.gperf"
      {"truncate", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "truncate"}},
#line 123 "gen/reserved_keywords.gperf"
      {"getc", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "getc"}},
#line 199 "gen/reserved_keywords.gperf"
      {"setsockopt", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "setsockopt"}},
#line 194 "gen/reserved_keywords.gperf"
      {"getsockname", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "getsockname"}},
      {""},
#line 96 "gen/reserved_keywords.gperf"
      {"pos", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "pos"}},
#line 261 "gen/reserved_keywords.gperf"
      {"sqrt", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "sqrt"}},
      {""}, {""},
#line 66 "gen/reserved_keywords.gperf"
      {"^=", {Enum::Token::Type::NotBitEqual, Enum::Token::Kind::Assign, "NotBitEqual", "^="}},
      {""},
#line 105 "gen/reserved_keywords.gperf"
      {"grep", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "grep"}},
#line 195 "gen/reserved_keywords.gperf"
      {"getsockopt", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "getsockopt"}},
      {""},
#line 48 "gen/reserved_keywords.gperf"
      {"lt", {Enum::Token::Type::StringLess, Enum::Token::Kind::Operator, "StringLess", "lt"}},
#line 258 "gen/reserved_keywords.gperf"
      {"oct", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "oct"}},
#line 106 "gen/reserved_keywords.gperf"
      {"join", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "join"}},
      {""}, {""},
#line 385 "gen/reserved_keywords.gperf"
      {"$@", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$@"}},
#line 253 "gen/reserved_keywords.gperf"
      {"cos", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "cos"}},
      {""},
#line 81 "gen/reserved_keywords.gperf"
      {"crypt", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "crypt"}},
      {""},
#line 47 "gen/reserved_keywords.gperf"
      {"!=", {Enum::Token::Type::NotEqual, Enum::Token::Kind::Operator, "NotEqual", "!="}},
#line 100 "gen/reserved_keywords.gperf"
      {"pop", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "pop"}},
      {""}, {""},
#line 236 "gen/reserved_keywords.gperf"
      {"getprotobynumber", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "getprotobynumber"}},
#line 367 "gen/reserved_keywords.gperf"
      {"$`", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$`"}},
#line 400 "gen/reserved_keywords.gperf"
      {"$^I", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$^I"}},
#line 153 "gen/reserved_keywords.gperf"
      {"open", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "open"}},
      {""},
#line 329 "gen/reserved_keywords.gperf"
      {":", {Enum::Token::Type::Colon, Enum::Token::Kind::Colon, "Colon", ":"}},
#line 25 "gen/reserved_keywords.gperf"
      {"or", {Enum::Token::Type::AlphabetOr, Enum::Token::Kind::Operator, "AlphabetOr", "or"}},
#line 187 "gen/reserved_keywords.gperf"
      {"tie", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "tie"}},
#line 247 "gen/reserved_keywords.gperf"
      {"time", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "time"}},
      {""},
#line 108 "gen/reserved_keywords.gperf"
      {"delete", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "delete"}},
#line 192 "gen/reserved_keywords.gperf"
      {"connect", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "connect"}},
#line 401 "gen/reserved_keywords.gperf"
      {"$^L", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$^L"}},
      {""},
#line 209 "gen/reserved_keywords.gperf"
      {"semop", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "semop"}},
#line 204 "gen/reserved_keywords.gperf"
      {"msgget", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "msgget"}},
      {""},
#line 319 "gen/reserved_keywords.gperf"
      {"use", {Enum::Token::Type::UseDecl, Enum::Token::Kind::Decl, "UseDecl", "use"}},
#line 197 "gen/reserved_keywords.gperf"
      {"recv", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "recv"}},
      {""}, {""},
#line 418 "gen/reserved_keywords.gperf"
      {"qr", {Enum::Token::Type::RegDecl, Enum::Token::Kind::RegPrefix, "RegDecl", "qr"}},
#line 399 "gen/reserved_keywords.gperf"
      {"$^H", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$^H"}},
#line 273 "gen/reserved_keywords.gperf"
      {"INIT", {Enum::Token::Type::ModWord, Enum::Token::Kind::ModWord, "ModWord", "INIT"}},
      {""},
#line 211 "gen/reserved_keywords.gperf"
      {"shmget", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "shmget"}},
#line 186 "gen/reserved_keywords.gperf"
      {"no", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "no"}},
#line 256 "gen/reserved_keywords.gperf"
      {"int", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "int"}},
      {""}, {""}, {""},
#line 382 "gen/reserved_keywords.gperf"
      {"$:", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$:"}},
#line 260 "gen/reserved_keywords.gperf"
      {"sin", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "sin"}},
#line 178 "gen/reserved_keywords.gperf"
      {"pipe", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "pipe"}},
#line 114 "gen/reserved_keywords.gperf"
      {"close", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "close"}},
#line 414 "gen/reserved_keywords.gperf"
      {"q", {Enum::Token::Type::RegQuote, Enum::Token::Kind::RegPrefix, "RegQuote", "q"}},
#line 52 "gen/reserved_keywords.gperf"
      {"eq", {Enum::Token::Type::StringEqual, Enum::Token::Kind::Operator, "StringEqual", "eq"}},
#line 398 "gen/reserved_keywords.gperf"
      {"$^G", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$^G"}},
#line 111 "gen/reserved_keywords.gperf"
      {"keys", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "keys"}},
#line 183 "gen/reserved_keywords.gperf"
      {"times", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "times"}},
      {""},
#line 34 "gen/reserved_keywords.gperf"
      {"%=", {Enum::Token::Type::ModEqual, Enum::Token::Kind::Assign, "ModEqual", "%="}},
#line 404 "gen/reserved_keywords.gperf"
      {"$^P", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$^P"}},
      {""}, {""},
#line 207 "gen/reserved_keywords.gperf"
      {"semctl", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "semctl"}},
#line 35 "gen/reserved_keywords.gperf"
      {".=", {Enum::Token::Type::StringAddEqual, Enum::Token::Kind::Assign, "StringAddEqual", ".="}},
#line 54 "gen/reserved_keywords.gperf"
      {"cmp", {Enum::Token::Type::StringCompare, Enum::Token::Kind::Operator, "StringCompare", "cmp"}},
#line 282 "gen/reserved_keywords.gperf"
      {"redo", {Enum::Token::Type::Redo, Enum::Token::Kind::Control, "Redo", "redo"}},
      {""}, {""},
#line 349 "gen/reserved_keywords.gperf"
      {"\\&", {Enum::Token::Type::CodeRef, Enum::Token::Kind::SingleTerm, "CodeRef", "\\&"}},
#line 406 "gen/reserved_keywords.gperf"
      {"$^T", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$^T"}},
      {""},
#line 181 "gen/reserved_keywords.gperf"
      {"sleep", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "sleep"}},
#line 323 "gen/reserved_keywords.gperf"
      {"unless", {Enum::Token::Type::UnlessStmt, Enum::Token::Kind::Stmt, "UnlessStmt", "unless"}},
#line 32 "gen/reserved_keywords.gperf"
      {"*=", {Enum::Token::Type::MulEqual, Enum::Token::Kind::Assign, "MulEqual", "*="}},
#line 220 "gen/reserved_keywords.gperf"
      {"getgrnam", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "getgrnam"}},
      {""}, {""}, {""},
#line 365 "gen/reserved_keywords.gperf"
      {"$9", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$9"}},
#line 80 "gen/reserved_keywords.gperf"
      {"chr", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "chr"}},
      {""},
#line 326 "gen/reserved_keywords.gperf"
      {"given", {Enum::Token::Type::GivenStmt, Enum::Token::Kind::Stmt, "GivenStmt", "given"}},
      {""},
#line 83 "gen/reserved_keywords.gperf"
      {"lc", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "lc"}},
#line 396 "gen/reserved_keywords.gperf"
      {"$^E", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$^E"}},
      {""},
#line 98 "gen/reserved_keywords.gperf"
      {"split", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "split"}},
      {""},
#line 39 "gen/reserved_keywords.gperf"
      {">=", {Enum::Token::Type::GreaterEqual, Enum::Token::Kind::Operator, "GreaterEqual", ">="}},
#line 257 "gen/reserved_keywords.gperf"
      {"log", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "log"}},
      {""}, {""},
#line 419 "gen/reserved_keywords.gperf"
      {"m", {Enum::Token::Type::RegMatch, Enum::Token::Kind::RegPrefix, "RegMatch", "m"}},
#line 38 "gen/reserved_keywords.gperf"
      {"x=", {Enum::Token::Type::StringMulEqual, Enum::Token::Kind::Assign, "StringMulEqual", "x="}},
#line 115 "gen/reserved_keywords.gperf"
      {"closedir", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "closedir"}},
#line 412 "gen/reserved_keywords.gperf"
      {"%INC", {Enum::Token::Type::Include, Enum::Token::Kind::Term, "Include", "%INC"}},
      {""}, {""},
#line 342 "gen/reserved_keywords.gperf"
      {"%$", {Enum::Token::Type::ShortHashDereference, Enum::Token::Kind::Modifier, "ShortHashDereference", "%$"}},
#line 397 "gen/reserved_keywords.gperf"
      {"$^F", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$^F"}},
      {""},
#line 241 "gen/reserved_keywords.gperf"
      {"sethostent", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "sethostent"}},
#line 93 "gen/reserved_keywords.gperf"
      {"substr", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "substr"}},
#line 347 "gen/reserved_keywords.gperf"
      {"::", {Enum::Token::Type::NamespaceResolver, Enum::Token::Kind::Operator, "NamespaceResolver", "::"}},
#line 230 "gen/reserved_keywords.gperf"
      {"gethostbyname", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "gethostbyname"}},
#line 166 "gen/reserved_keywords.gperf"
      {"exit", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "exit"}},
#line 215 "gen/reserved_keywords.gperf"
      {"endhostent", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "endhostent"}},
      {""},
#line 30 "gen/reserved_keywords.gperf"
      {"+=", {Enum::Token::Type::AddEqual, Enum::Token::Kind::Assign, "AddEqual", "+="}},
#line 219 "gen/reserved_keywords.gperf"
      {"getgrgid", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "getgrgid"}},
#line 79 "gen/reserved_keywords.gperf"
      {"chop", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "chop"}},
#line 231 "gen/reserved_keywords.gperf"
      {"gethostent", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "gethostent"}},
#line 27 "gen/reserved_keywords.gperf"
      {"^", {Enum::Token::Type::BitXOr, Enum::Token::Kind::Operator, "BitXOr", "^"}},
#line 175 "gen/reserved_keywords.gperf"
      {"getppid", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "getppid"}},
#line 221 "gen/reserved_keywords.gperf"
      {"getlogin", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "getlogin"}},
#line 137 "gen/reserved_keywords.gperf"
      {"tell", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "tell"}},
      {""},
#line 102 "gen/reserved_keywords.gperf"
      {"splice", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "splice"}},
#line 94 "gen/reserved_keywords.gperf"
      {"uc", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "uc"}},
#line 254 "gen/reserved_keywords.gperf"
      {"exp", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "exp"}},
#line 129 "gen/reserved_keywords.gperf"
      {"rewinddir", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "rewinddir"}},
      {""},
#line 13 "gen/reserved_keywords.gperf"
      {"return", {Enum::Token::Type::Return, Enum::Token::Kind::Return, "Return", "return"}},
#line 40 "gen/reserved_keywords.gperf"
      {"<=", {Enum::Token::Type::LessEqual, Enum::Token::Kind::Operator, "LessEqual", "<="}},
#line 405 "gen/reserved_keywords.gperf"
      {"$^R", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$^R"}},
      {""},
#line 271 "gen/reserved_keywords.gperf"
      {"BEGIN", {Enum::Token::Type::ModWord, Enum::Token::Kind::ModWord, "ModWord", "BEGIN"}},
#line 110 "gen/reserved_keywords.gperf"
      {"exists", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "exists"}},
#line 355 "gen/reserved_keywords.gperf"
      {"$_", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$_"}},
      {""},
#line 285 "gen/reserved_keywords.gperf"
      {"goto", {Enum::Token::Type::Goto, Enum::Token::Kind::Control, "Goto", "goto"}},
#line 279 "gen/reserved_keywords.gperf"
      {"STDIN", {Enum::Token::Type::STDIN, Enum::Token::Kind::Handle, "STDIN", "STDIN"}},
#line 201 "gen/reserved_keywords.gperf"
      {"socket", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "socket"}},
      {""},
#line 86 "gen/reserved_keywords.gperf"
      {"ord", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "ord"}},
      {""},
#line 409 "gen/reserved_keywords.gperf"
      {"@ARGV", {Enum::Token::Type::ProgramArgument, Enum::Token::Kind::Term, "ProgramArgument", "@ARGV"}},
      {""},
#line 381 "gen/reserved_keywords.gperf"
      {"$^", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$^"}},
#line 317 "gen/reserved_keywords.gperf"
      {"our", {Enum::Token::Type::OurDecl, Enum::Token::Kind::Decl, "OurDecl", "our"}},
      {""}, {""},
#line 76 "gen/reserved_keywords.gperf"
      {"!", {Enum::Token::Type::Not, Enum::Token::Kind::SingleTerm, "Not", "!"}},
      {""},
#line 229 "gen/reserved_keywords.gperf"
      {"gethostbyaddr", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "gethostbyaddr"}},
      {""},
#line 162 "gen/reserved_keywords.gperf"
      {"utime", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "utime"}},
#line 85 "gen/reserved_keywords.gperf"
      {"length", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "length"}},
#line 415 "gen/reserved_keywords.gperf"
      {"qq", {Enum::Token::Type::RegDoubleQuote, Enum::Token::Kind::RegPrefix, "RegDoubleQuote", "qq"}},
      {""},
#line 411 "gen/reserved_keywords.gperf"
      {"%ENV", {Enum::Token::Type::Environment, Enum::Token::Kind::Term, "Environment", "%ENV"}},
      {""},
#line 205 "gen/reserved_keywords.gperf"
      {"msgrcv", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "msgrcv"}},
#line 65 "gen/reserved_keywords.gperf"
      {"|=", {Enum::Token::Type::OrBitEqual, Enum::Token::Kind::Assign, "OrBitEqual", "|="}},
#line 394 "gen/reserved_keywords.gperf"
      {"$^A", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$^A"}},
      {""},
#line 141 "gen/reserved_keywords.gperf"
      {"write", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "write"}},
      {""},
#line 33 "gen/reserved_keywords.gperf"
      {"/=", {Enum::Token::Type::DivEqual, Enum::Token::Kind::Assign, "DivEqual", "/="}},
#line 286 "gen/reserved_keywords.gperf"
      {"continue", {Enum::Token::Type::Continue, Enum::Token::Kind::Control, "Continue", "continue"}},
      {""}, {""}, {""},
#line 354 "gen/reserved_keywords.gperf"
      {"@_", {Enum::Token::Type::ArgumentArray, Enum::Token::Kind::Term, "ArgumentArray", "@_"}},
#line 118 "gen/reserved_keywords.gperf"
      {"die", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "die"}},
      {""},
#line 202 "gen/reserved_keywords.gperf"
      {"socketpair", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "socketpair"}},
#line 196 "gen/reserved_keywords.gperf"
      {"listen", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "listen"}},
#line 384 "gen/reserved_keywords.gperf"
      {"$!", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$!"}},
#line 226 "gen/reserved_keywords.gperf"
      {"setpwent", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "setpwent"}},
#line 165 "gen/reserved_keywords.gperf"
      {"eval", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "eval"}},
      {""}, {""},
#line 287 "gen/reserved_keywords.gperf"
      {"do", {Enum::Token::Type::Do, Enum::Token::Kind::Do, "Do", "do"}},
#line 217 "gen/reserved_keywords.gperf"
      {"endpwent", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "endpwent"}},
      {""}, {""},
#line 203 "gen/reserved_keywords.gperf"
      {"msgctl", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "msgctl"}},
#line 353 "gen/reserved_keywords.gperf"
      {"#@", {Enum::Token::Type::Annotation, Enum::Token::Kind::Annotation, "Annotation", "#@"}},
#line 222 "gen/reserved_keywords.gperf"
      {"getpwent", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "getpwent"}},
#line 198 "gen/reserved_keywords.gperf"
      {"send", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "send"}},
      {""},
#line 206 "gen/reserved_keywords.gperf"
      {"msgsnd", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "msgsnd"}},
      {""},
#line 248 "gen/reserved_keywords.gperf"
      {"ref", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "ref"}},
#line 172 "gen/reserved_keywords.gperf"
      {"exec", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "exec"}},
      {""},
#line 210 "gen/reserved_keywords.gperf"
      {"shmctl", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "shmctl"}},
#line 138 "gen/reserved_keywords.gperf"
      {"telldir", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "telldir"}},
#line 200 "gen/reserved_keywords.gperf"
      {"shutdown", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "shutdown"}},
      {""},
#line 189 "gen/reserved_keywords.gperf"
      {"untie", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "untie"}},
#line 22 "gen/reserved_keywords.gperf"
      {"\\", {Enum::Token::Type::Ref, Enum::Token::Kind::Operator, "Ref", "\\"}},
#line 154 "gen/reserved_keywords.gperf"
      {"opendir", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "opendir"}},
#line 274 "gen/reserved_keywords.gperf"
      {"END", {Enum::Token::Type::ModWord, Enum::Token::Kind::ModWord, "ModWord", "END"}},
      {""}, {""}, {""},
#line 212 "gen/reserved_keywords.gperf"
      {"shmread", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "shmread"}},
#line 403 "gen/reserved_keywords.gperf"
      {"$^O", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$^O"}},
#line 130 "gen/reserved_keywords.gperf"
      {"seek", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "seek"}},
      {""},
#line 23 "gen/reserved_keywords.gperf"
      {"~", {Enum::Token::Type::BitNot, Enum::Token::Kind::Operator, "BitNot", "~"}},
      {""},
#line 28 "gen/reserved_keywords.gperf"
      {"xor", {Enum::Token::Type::AlphabetXOr, Enum::Token::Kind::Operator, "AlphabetXOr", "xor"}},
#line 127 "gen/reserved_keywords.gperf"
      {"read", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "read"}},
      {""},
#line 190 "gen/reserved_keywords.gperf"
      {"accept", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "accept"}},
#line 45 "gen/reserved_keywords.gperf"
      {"=~", {Enum::Token::Type::RegOK, Enum::Token::Kind::Operator, "RegOK", "=~"}},
#line 255 "gen/reserved_keywords.gperf"
      {"hex", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "hex"}},
#line 277 "gen/reserved_keywords.gperf"
      {"CORE", {Enum::Token::Type::CORE, Enum::Token::Kind::CORE, "CORE", "CORE"}},
      {""},
#line 146 "gen/reserved_keywords.gperf"
      {"chroot", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "chroot"}},
#line 263 "gen/reserved_keywords.gperf"
      {"require", {Enum::Token::Type::RequireDecl, Enum::Token::Kind::Decl, "RequireDecl", "require"}},
#line 395 "gen/reserved_keywords.gperf"
      {"$^D", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$^D"}},
#line 413 "gen/reserved_keywords.gperf"
      {"%SIG", {Enum::Token::Type::Signal, Enum::Token::Kind::Term, "Signal", "%SIG"}},
      {""}, {""},
#line 375 "gen/reserved_keywords.gperf"
      {"$\\", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$\\"}},
#line 408 "gen/reserved_keywords.gperf"
      {"$^X", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$^X"}},
#line 275 "gen/reserved_keywords.gperf"
      {"UNITCHECK", {Enum::Token::Type::ModWord, Enum::Token::Kind::ModWord, "ModWord", "UNITCHECK"}},
#line 252 "gen/reserved_keywords.gperf"
      {"atan2", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "atan2"}},
      {""}, {""},
#line 119 "gen/reserved_keywords.gperf"
      {"eof", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "eof"}},
      {""},
#line 78 "gen/reserved_keywords.gperf"
      {"chomp", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "chomp"}},
      {""},
#line 380 "gen/reserved_keywords.gperf"
      {"$~", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$~"}},
      {""}, {""}, {""},
#line 17 "gen/reserved_keywords.gperf"
      {"%", {Enum::Token::Type::Mod, Enum::Token::Kind::Operator, "Mod", "%"}},
#line 131 "gen/reserved_keywords.gperf"
      {"seekdir", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "seekdir"}},
      {""}, {""}, {""}, {""},
#line 84 "gen/reserved_keywords.gperf"
      {"lcfirst", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "lcfirst"}},
#line 407 "gen/reserved_keywords.gperf"
      {"$^W", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$^W"}},
#line 164 "gen/reserved_keywords.gperf"
      {"dump", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "dump"}},
#line 262 "gen/reserved_keywords.gperf"
      {"srand", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "srand"}},
#line 21 "gen/reserved_keywords.gperf"
      {".", {Enum::Token::Type::StringAdd, Enum::Token::Kind::Operator, "StringAdd", "."}},
      {""},
#line 402 "gen/reserved_keywords.gperf"
      {"$^M", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$^M"}},
      {""}, {""}, {""},
#line 128 "gen/reserved_keywords.gperf"
      {"readdir", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "readdir"}},
#line 266 "gen/reserved_keywords.gperf"
      {"__FILE__", {Enum::Token::Type::SpecificKeyword, Enum::Token::Kind::SpecificKeyword, "SpecificKeyword", "__FILE__"}},
#line 284 "gen/reserved_keywords.gperf"
      {"last", {Enum::Token::Type::Last, Enum::Token::Kind::Control, "Last", "last"}},
#line 157 "gen/reserved_keywords.gperf"
      {"rmdir", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "rmdir"}},
#line 126 "gen/reserved_keywords.gperf"
      {"printf", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "printf"}},
      {""}, {""}, {""}, {""}, {""},
#line 377 "gen/reserved_keywords.gperf"
      {"$%", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$%"}},
#line 107 "gen/reserved_keywords.gperf"
      {"map", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "map"}},
      {""}, {""},
#line 264 "gen/reserved_keywords.gperf"
      {"import", {Enum::Token::Type::Import, Enum::Token::Kind::Import, "Import", "import"}},
      {""},
#line 351 "gen/reserved_keywords.gperf"
      {"for", {Enum::Token::Type::ForStmt, Enum::Token::Kind::Stmt, "ForStmt", "for"}},
      {""},
#line 151 "gen/reserved_keywords.gperf"
      {"lstat", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "lstat"}},
#line 156 "gen/reserved_keywords.gperf"
      {"rename", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "rename"}},
#line 370 "gen/reserved_keywords.gperf"
      {"$.", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$."}},
#line 58 "gen/reserved_keywords.gperf"
      {"**=", {Enum::Token::Type::PowerEqual, Enum::Token::Kind::Assign, "PowerEqual", "**="}},
#line 325 "gen/reserved_keywords.gperf"
      {"when", {Enum::Token::Type::WhenStmt, Enum::Token::Kind::Stmt, "WhenStmt", "when"}},
#line 143 "gen/reserved_keywords.gperf"
      {"chdir", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "chdir"}},
#line 245 "gen/reserved_keywords.gperf"
      {"gmtime", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "gmtime"}},
#line 95 "gen/reserved_keywords.gperf"
      {"ucfirst", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "ucfirst"}},
      {""}, {""}, {""}, {""},
#line 75 "gen/reserved_keywords.gperf"
      {"$#", {Enum::Token::Type::ArraySize, Enum::Token::Kind::SingleTerm, "ArraySize", "$#"}},
#line 26 "gen/reserved_keywords.gperf"
      {"and", {Enum::Token::Type::AlphabetAnd, Enum::Token::Kind::Operator, "AlphabetAnd", "and"}},
      {""}, {""},
#line 336 "gen/reserved_keywords.gperf"
      {"]", {Enum::Token::Type::RightBracket, Enum::Token::Kind::Symbol, "RightBracket", "]"}},
#line 292 "gen/reserved_keywords.gperf"
      {"-e", {Enum::Token::Type::Handle, Enum::Token::Kind::Handle, "Handle", "-e"}},
#line 223 "gen/reserved_keywords.gperf"
      {"getpwnam", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "getpwnam"}},
      {""}, {""}, {""},
#line 373 "gen/reserved_keywords.gperf"
      {"$*", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$*"}},
#line 213 "gen/reserved_keywords.gperf"
      {"shmwrite", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "shmwrite"}},
      {""}, {""},
#line 19 "gen/reserved_keywords.gperf"
      {">", {Enum::Token::Type::Greater, Enum::Token::Kind::Operator, "Greater", ">"}},
#line 31 "gen/reserved_keywords.gperf"
      {"-=", {Enum::Token::Type::SubEqual, Enum::Token::Kind::Assign, "SubEqual", "-="}},
#line 267 "gen/reserved_keywords.gperf"
      {"__LINE__", {Enum::Token::Type::SpecificKeyword, Enum::Token::Kind::SpecificKeyword, "SpecificKeyword", "__LINE__"}},
      {""}, {""},
#line 281 "gen/reserved_keywords.gperf"
      {"STDERR", {Enum::Token::Type::STDERR, Enum::Token::Kind::Handle, "STDERR", "STDERR"}},
#line 345 "gen/reserved_keywords.gperf"
      {"=>", {Enum::Token::Type::Arrow, Enum::Token::Kind::Operator, "Arrow", "=>"}},
#line 37 "gen/reserved_keywords.gperf"
      {">>=", {Enum::Token::Type::RightShiftEqual, Enum::Token::Kind::Assign, "RightShiftEqual", ">>="}},
      {""},
#line 249 "gen/reserved_keywords.gperf"
      {"bless", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "bless"}},
#line 29 "gen/reserved_keywords.gperf"
      {"x", {Enum::Token::Type::StringMul, Enum::Token::Kind::Operator, "StringMul", "x"}},
#line 301 "gen/reserved_keywords.gperf"
      {"-t", {Enum::Token::Type::Handle, Enum::Token::Kind::Handle, "Handle", "-t"}},
#line 73 "gen/reserved_keywords.gperf"
      {"sub", {Enum::Token::Type::FunctionDecl, Enum::Token::Kind::Decl, "FunctionDecl", "sub"}},
#line 101 "gen/reserved_keywords.gperf"
      {"push", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "push"}},
#line 103 "gen/reserved_keywords.gperf"
      {"shift", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "shift"}},
#line 180 "gen/reserved_keywords.gperf"
      {"setpriority", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "setpriority"}},
#line 392 "gen/reserved_keywords.gperf"
      {"$]", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$]"}},
      {""}, {""}, {""}, {""},
#line 300 "gen/reserved_keywords.gperf"
      {"-s", {Enum::Token::Type::Handle, Enum::Token::Kind::Handle, "Handle", "-s"}},
      {""}, {""}, {""},
#line 176 "gen/reserved_keywords.gperf"
      {"getpriority", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "getpriority"}},
#line 388 "gen/reserved_keywords.gperf"
      {"$>", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$>"}},
#line 224 "gen/reserved_keywords.gperf"
      {"getpwuid", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "getpwuid"}},
      {""},
#line 145 "gen/reserved_keywords.gperf"
      {"chown", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "chown"}},
#line 163 "gen/reserved_keywords.gperf"
      {"caller", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "caller"}},
#line 308 "gen/reserved_keywords.gperf"
      {"-C", {Enum::Token::Type::Handle, Enum::Token::Kind::Handle, "Handle", "-C"}},
      {""},
#line 188 "gen/reserved_keywords.gperf"
      {"tied", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "tied"}},
      {""}, {""},
#line 104 "gen/reserved_keywords.gperf"
      {"unshift", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "unshift"}},
      {""}, {""}, {""},
#line 14 "gen/reserved_keywords.gperf"
      {"+", {Enum::Token::Type::Add, Enum::Token::Kind::Operator, "Add", "+"}},
#line 294 "gen/reserved_keywords.gperf"
      {"-g", {Enum::Token::Type::Handle, Enum::Token::Kind::Handle, "Handle", "-g"}},
#line 43 "gen/reserved_keywords.gperf"
      {"<=>", {Enum::Token::Type::Compare, Enum::Token::Kind::Operator, "Compare", "<=>"}},
      {""}, {""},
#line 170 "gen/reserved_keywords.gperf"
      {"scalar", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "scalar"}},
#line 250 "gen/reserved_keywords.gperf"
      {"defined", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "defined"}},
#line 155 "gen/reserved_keywords.gperf"
      {"readlink", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "readlink"}},
      {""}, {""}, {""},
#line 46 "gen/reserved_keywords.gperf"
      {"!~", {Enum::Token::Type::RegNot, Enum::Token::Kind::Operator, "RegNot", "!~"}},
      {""}, {""},
#line 149 "gen/reserved_keywords.gperf"
      {"ioctl", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "ioctl"}},
#line 112 "gen/reserved_keywords.gperf"
      {"values", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "values"}},
#line 278 "gen/reserved_keywords.gperf"
      {"DESTROY", {Enum::Token::Type::DESTROY, Enum::Token::Kind::DESTROY, "DESTROY", "DESTROY"}},
      {""}, {""},
#line 350 "gen/reserved_keywords.gperf"
      {"while", {Enum::Token::Type::WhileStmt, Enum::Token::Kind::Stmt, "WhileStmt", "while"}},
#line 182 "gen/reserved_keywords.gperf"
      {"system", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "system"}},
#line 298 "gen/reserved_keywords.gperf"
      {"-p", {Enum::Token::Type::Handle, Enum::Token::Kind::Handle, "Handle", "-p"}},
      {""}, {""}, {""}, {""},
#line 369 "gen/reserved_keywords.gperf"
      {"$+", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$+"}},
      {""},
#line 109 "gen/reserved_keywords.gperf"
      {"each", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "each"}},
      {""},
#line 20 "gen/reserved_keywords.gperf"
      {"<", {Enum::Token::Type::Less, Enum::Token::Kind::Operator, "Less", "<"}},
#line 299 "gen/reserved_keywords.gperf"
      {"-r", {Enum::Token::Type::Handle, Enum::Token::Kind::Handle, "Handle", "-r"}},
      {""}, {""}, {""}, {""},
#line 92 "gen/reserved_keywords.gperf"
      {"sprintf", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "sprintf"}},
#line 36 "gen/reserved_keywords.gperf"
      {"<<=", {Enum::Token::Type::LeftShiftEqual, Enum::Token::Kind::Assign, "LeftShiftEqual", "<<="}},
#line 184 "gen/reserved_keywords.gperf"
      {"wait", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "wait"}},
#line 152 "gen/reserved_keywords.gperf"
      {"mkdir", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "mkdir"}},
#line 161 "gen/reserved_keywords.gperf"
      {"unlink", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "unlink"}},
#line 44 "gen/reserved_keywords.gperf"
      {"~~", {Enum::Token::Type::PolymorphicCompare, Enum::Token::Kind::Operator, "PolymorphicCompare", "~~"}},
      {""},
#line 97 "gen/reserved_keywords.gperf"
      {"quotemeta", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "quotemeta"}},
      {""}, {""},
#line 364 "gen/reserved_keywords.gperf"
      {"$8", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$8"}},
#line 344 "gen/reserved_keywords.gperf"
      {"$#{", {Enum::Token::Type::ArraySizeDereference, Enum::Token::Kind::Modifier, "ArraySizeDereference", "$#{"}},
      {""}, {""},
#line 335 "gen/reserved_keywords.gperf"
      {"[", {Enum::Token::Type::LeftBracket, Enum::Token::Kind::Symbol, "LeftBracket", "["}},
#line 290 "gen/reserved_keywords.gperf"
      {"-c", {Enum::Token::Type::Handle, Enum::Token::Kind::Handle, "Handle", "-c"}},
      {""}, {""}, {""}, {""},
#line 387 "gen/reserved_keywords.gperf"
      {"$<", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$<"}},
      {""},
#line 140 "gen/reserved_keywords.gperf"
      {"warn", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "warn"}},
      {""},
#line 265 "gen/reserved_keywords.gperf"
      {"__PACKAGE__", {Enum::Token::Type::SpecificKeyword, Enum::Token::Kind::SpecificKeyword, "SpecificKeyword", "__PACKAGE__"}},
#line 313 "gen/reserved_keywords.gperf"
      {"-T", {Enum::Token::Type::Handle, Enum::Token::Kind::Handle, "Handle", "-T"}},
#line 251 "gen/reserved_keywords.gperf"
      {"abs", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "abs"}},
      {""}, {""},
#line 120 "gen/reserved_keywords.gperf"
      {"fileno", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "fileno"}},
#line 417 "gen/reserved_keywords.gperf"
      {"qx", {Enum::Token::Type::RegExec, Enum::Token::Kind::RegPrefix, "RegExec", "qx"}},
      {""}, {""}, {""}, {""},
#line 135 "gen/reserved_keywords.gperf"
      {"sysseek", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "sysseek"}},
      {""}, {""}, {""}, {""},
#line 391 "gen/reserved_keywords.gperf"
      {"$[", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$["}},
      {""}, {""}, {""}, {""},
#line 307 "gen/reserved_keywords.gperf"
      {"-B", {Enum::Token::Type::Handle, Enum::Token::Kind::Handle, "Handle", "-B"}},
      {""},
#line 177 "gen/reserved_keywords.gperf"
      {"kill", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "kill"}},
      {""}, {""},
#line 134 "gen/reserved_keywords.gperf"
      {"sysread", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "sysread"}},
      {""}, {""},
#line 144 "gen/reserved_keywords.gperf"
      {"chmod", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "chmod"}},
#line 24 "gen/reserved_keywords.gperf"
      {"|", {Enum::Token::Type::BitOr, Enum::Token::Kind::Operator, "BitOr", "|"}},
#line 117 "gen/reserved_keywords.gperf"
      {"dbmopen", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "dbmopen"}},
#line 269 "gen/reserved_keywords.gperf"
      {"__DATA__", {Enum::Token::Type::DataWord, Enum::Token::Kind::DataWord, "DataWord", "__DATA__"}},
      {""}, {""},
#line 91 "gen/reserved_keywords.gperf"
      {"rindex", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "rindex"}},
#line 327 "gen/reserved_keywords.gperf"
      {"default", {Enum::Token::Type::DefaultStmt, Enum::Token::Kind::DefaultStmt, "DefaultStmt", "default"}},
#line 67 "gen/reserved_keywords.gperf"
      {"||=", {Enum::Token::Type::OrEqual, Enum::Token::Kind::Assign, "OrEqual", "||="}},
      {""},
#line 324 "gen/reserved_keywords.gperf"
      {"until", {Enum::Token::Type::UntilStmt, Enum::Token::Kind::Stmt, "UntilStmt", "until"}},
#line 16 "gen/reserved_keywords.gperf"
      {"/", {Enum::Token::Type::Div, Enum::Token::Kind::Operator, "Div", "/"}},
#line 69 "gen/reserved_keywords.gperf"
      {"..", {Enum::Token::Type::Slice, Enum::Token::Kind::Operator, "Slice", ".."}},
#line 71 "gen/reserved_keywords.gperf"
      {"...", {Enum::Token::Type::ToDo, Enum::Token::Kind::Operator, "ToDo", "..."}},
#line 246 "gen/reserved_keywords.gperf"
      {"localtime", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "localtime"}},
      {""}, {""},
#line 416 "gen/reserved_keywords.gperf"
      {"qw", {Enum::Token::Type::RegList, Enum::Token::Kind::RegPrefix, "RegList", "qw"}},
#line 59 "gen/reserved_keywords.gperf"
      {"//=", {Enum::Token::Type::DefaultEqual, Enum::Token::Kind::Assign, "DefaultEqual", "//="}},
      {""}, {""},
#line 18 "gen/reserved_keywords.gperf"
      {"?", {Enum::Token::Type::ThreeTermOperator, Enum::Token::Kind::Operator, "ThreeTermOperator", "?"}},
#line 297 "gen/reserved_keywords.gperf"
      {"-o", {Enum::Token::Type::Handle, Enum::Token::Kind::Handle, "Handle", "-o"}},
      {""}, {""},
#line 147 "gen/reserved_keywords.gperf"
      {"fcntl", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "fcntl"}},
#line 280 "gen/reserved_keywords.gperf"
      {"STDOUT", {Enum::Token::Type::STDOUT, Enum::Token::Kind::Handle, "STDOUT", "STDOUT"}},
#line 372 "gen/reserved_keywords.gperf"
      {"$|", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$|"}},
      {""},
#line 259 "gen/reserved_keywords.gperf"
      {"rand", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "rand"}},
      {""},
#line 333 "gen/reserved_keywords.gperf"
      {"{", {Enum::Token::Type::LeftBrace, Enum::Token::Kind::Symbol, "LeftBrace", "{"}},
#line 312 "gen/reserved_keywords.gperf"
      {"-S", {Enum::Token::Type::Handle, Enum::Token::Kind::Handle, "Handle", "-S"}},
      {""},
#line 150 "gen/reserved_keywords.gperf"
      {"link", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "link"}},
      {""}, {""},
#line 371 "gen/reserved_keywords.gperf"
      {"$/", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$/"}},
#line 116 "gen/reserved_keywords.gperf"
      {"dbmclose", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "dbmclose"}},
      {""}, {""}, {""},
#line 57 "gen/reserved_keywords.gperf"
      {"**", {Enum::Token::Type::Exp, Enum::Token::Kind::Operator, "Exp", "**"}},
#line 168 "gen/reserved_keywords.gperf"
      {"formline", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "formline"}},
#line 87 "gen/reserved_keywords.gperf"
      {"pack", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "pack"}},
      {""}, {""},
#line 383 "gen/reserved_keywords.gperf"
      {"$?", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$?"}},
#line 125 "gen/reserved_keywords.gperf"
      {"say", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "say"}},
      {""},
#line 160 "gen/reserved_keywords.gperf"
      {"umask", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "umask"}},
#line 330 "gen/reserved_keywords.gperf"
      {";", {Enum::Token::Type::SemiColon, Enum::Token::Kind::StmtEnd, "SemiColon", ";"}},
#line 340 "gen/reserved_keywords.gperf"
      {"&{", {Enum::Token::Type::CodeDereference, Enum::Token::Kind::Modifier, "CodeDereference", "&{"}},
      {""}, {""},
#line 82 "gen/reserved_keywords.gperf"
      {"index", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "index"}},
      {""},
#line 339 "gen/reserved_keywords.gperf"
      {"${", {Enum::Token::Type::ScalarDereference, Enum::Token::Kind::Modifier, "ScalarDereference", "${"}},
      {""}, {""}, {""}, {""},
#line 113 "gen/reserved_keywords.gperf"
      {"binmode", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "binmode"}},
      {""}, {""}, {""}, {""},
#line 270 "gen/reserved_keywords.gperf"
      {"__END__", {Enum::Token::Type::DataWord, Enum::Token::Kind::DataWord, "DataWord", "__END__"}},
      {""}, {""}, {""},
#line 328 "gen/reserved_keywords.gperf"
      {",", {Enum::Token::Type::Comma, Enum::Token::Kind::Comma, "Comma", ","}},
#line 268 "gen/reserved_keywords.gperf"
      {"__SUB__", {Enum::Token::Type::SpecificKeyword, Enum::Token::Kind::SpecificKeyword, "SpecificKeyword", "__SUB__"}},
      {""}, {""}, {""},
#line 88 "gen/reserved_keywords.gperf"
      {"unpack", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "unpack"}},
#line 393 "gen/reserved_keywords.gperf"
      {"$;", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$;"}},
      {""}, {""},
#line 171 "gen/reserved_keywords.gperf"
      {"alarm", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "alarm"}},
#line 332 "gen/reserved_keywords.gperf"
      {")", {Enum::Token::Type::RightParenthesis, Enum::Token::Kind::Symbol, "RightParenthesis", ")"}},
#line 311 "gen/reserved_keywords.gperf"
      {"-R", {Enum::Token::Type::Handle, Enum::Token::Kind::Handle, "Handle", "-R"}},
      {""}, {""}, {""}, {""},
#line 61 "gen/reserved_keywords.gperf"
      {">>", {Enum::Token::Type::RightShift, Enum::Token::Kind::Operator, "RightShift", ">>"}},
#line 136 "gen/reserved_keywords.gperf"
      {"syswrite", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "syswrite"}},
      {""}, {""},
#line 331 "gen/reserved_keywords.gperf"
      {"(", {Enum::Token::Type::LeftParenthesis, Enum::Token::Kind::Symbol, "LeftParenthesis", "("}},
#line 337 "gen/reserved_keywords.gperf"
      {"@{", {Enum::Token::Type::ArrayDereference, Enum::Token::Kind::Modifier, "ArrayDereference", "@{"}},
      {""}, {""}, {""}, {""},
#line 374 "gen/reserved_keywords.gperf"
      {"$,", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$,"}},
      {""}, {""}, {""}, {""},
#line 296 "gen/reserved_keywords.gperf"
      {"-l", {Enum::Token::Type::Handle, Enum::Token::Kind::Handle, "Handle", "-l"}},
      {""}, {""}, {""}, {""},
#line 390 "gen/reserved_keywords.gperf"
      {"$)", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$)"}},
      {""}, {""}, {""}, {""},
#line 305 "gen/reserved_keywords.gperf"
      {"-z", {Enum::Token::Type::Handle, Enum::Token::Kind::Handle, "Handle", "-z"}},
      {""}, {""}, {""}, {""},
#line 389 "gen/reserved_keywords.gperf"
      {"$(", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$("}},
      {""}, {""}, {""}, {""},
#line 42 "gen/reserved_keywords.gperf"
      {"<>", {Enum::Token::Type::Diamond, Enum::Token::Kind::Operator, "Diamond", "<>"}},
      {""},
#line 173 "gen/reserved_keywords.gperf"
      {"fork", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "fork"}},
      {""}, {""},
#line 185 "gen/reserved_keywords.gperf"
      {"waitpid", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "waitpid"}},
      {""},
#line 148 "gen/reserved_keywords.gperf"
      {"glob", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "glob"}},
#line 316 "gen/reserved_keywords.gperf"
      {"local", {Enum::Token::Type::LocalDecl, Enum::Token::Kind::Decl, "LocalDecl", "local"}},
#line 421 "gen/reserved_keywords.gperf"
      {"y", {Enum::Token::Type::RegAllReplace, Enum::Token::Kind::RegReplacePrefix, "RegAllReplace", "y"}},
#line 348 "gen/reserved_keywords.gperf"
      {"package", {Enum::Token::Type::Package, Enum::Token::Kind::Package, "Package", "package"}},
      {""}, {""}, {""}, {""},
#line 363 "gen/reserved_keywords.gperf"
      {"$7", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$7"}},
      {""}, {""}, {""}, {""},
#line 306 "gen/reserved_keywords.gperf"
      {"-A", {Enum::Token::Type::Handle, Enum::Token::Kind::Handle, "Handle", "-A"}},
      {""}, {""}, {""}, {""},
#line 55 "gen/reserved_keywords.gperf"
      {"++", {Enum::Token::Type::Inc, Enum::Token::Kind::Operator, "Inc", "++"}},
      {""}, {""}, {""}, {""},
#line 320 "gen/reserved_keywords.gperf"
      {"if", {Enum::Token::Type::IfStmt, Enum::Token::Kind::Stmt, "IfStmt", "if"}},
      {""}, {""}, {""}, {""},
#line 362 "gen/reserved_keywords.gperf"
      {"$6", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$6"}},
      {""}, {""}, {""}, {""},
#line 291 "gen/reserved_keywords.gperf"
      {"-d", {Enum::Token::Type::Handle, Enum::Token::Kind::Handle, "Handle", "-d"}},
      {""},
#line 191 "gen/reserved_keywords.gperf"
      {"bind", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "bind"}},
      {""}, {""},
#line 361 "gen/reserved_keywords.gperf"
      {"$5", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$5"}},
      {""}, {""}, {""}, {""},
#line 302 "gen/reserved_keywords.gperf"
      {"-u", {Enum::Token::Type::Handle, Enum::Token::Kind::Handle, "Handle", "-u"}},
      {""}, {""}, {""},
#line 122 "gen/reserved_keywords.gperf"
      {"format", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "format"}},
#line 352 "gen/reserved_keywords.gperf"
      {"foreach", {Enum::Token::Type::ForeachStmt, Enum::Token::Kind::Stmt, "ForeachStmt", "foreach"}},
      {""}, {""},
#line 423 "gen/reserved_keywords.gperf"
      {"undef", {Enum::Token::Type::Default, Enum::Token::Kind::Term, "Default", "undef"}},
      {""},
#line 295 "gen/reserved_keywords.gperf"
      {"-k", {Enum::Token::Type::Handle, Enum::Token::Kind::Handle, "Handle", "-k"}},
      {""}, {""}, {""}, {""},
#line 360 "gen/reserved_keywords.gperf"
      {"$4", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$4"}},
#line 276 "gen/reserved_keywords.gperf"
      {"AUTOLOAD", {Enum::Token::Type::AUTOLOAD, Enum::Token::Kind::AUTOLOAD, "AUTOLOAD", "AUTOLOAD"}},
      {""}, {""}, {""},
#line 60 "gen/reserved_keywords.gperf"
      {"<<", {Enum::Token::Type::LeftShift, Enum::Token::Kind::Operator, "LeftShift", "<<"}},
      {""}, {""}, {""}, {""},
#line 359 "gen/reserved_keywords.gperf"
      {"$3", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$3"}},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
#line 357 "gen/reserved_keywords.gperf"
      {"$1", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$1"}},
      {""}, {""}, {""}, {""}, {""}, {""}, {""},
#line 121 "gen/reserved_keywords.gperf"
      {"flock", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "flock"}},
      {""},
#line 338 "gen/reserved_keywords.gperf"
      {"%{", {Enum::Token::Type::HashDereference, Enum::Token::Kind::Modifier, "HashDereference", "%{"}},
      {""}, {""}, {""}, {""},
#line 133 "gen/reserved_keywords.gperf"
      {"syscall", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "syscall"}},
      {""}, {""}, {""}, {""},
#line 356 "gen/reserved_keywords.gperf"
      {"$0", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$0"}},
      {""}, {""}, {""}, {""},
#line 310 "gen/reserved_keywords.gperf"
      {"-O", {Enum::Token::Type::Handle, Enum::Token::Kind::Handle, "Handle", "-O"}},
      {""}, {""}, {""}, {""},
#line 159 "gen/reserved_keywords.gperf"
      {"symlink", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "symlink"}},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
#line 72 "gen/reserved_keywords.gperf"
      {"my", {Enum::Token::Type::VarDecl, Enum::Token::Kind::Decl, "VarDecl", "my"}},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
#line 368 "gen/reserved_keywords.gperf"
      {"$'", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$'"}},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
#line 376 "gen/reserved_keywords.gperf"
      {"$\"", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$\""}},
      {""}, {""}, {""}, {""},
#line 315 "gen/reserved_keywords.gperf"
      {"-X", {Enum::Token::Type::Handle, Enum::Token::Kind::Handle, "Handle", "-X"}},
      {""}, {""},
#line 322 "gen/reserved_keywords.gperf"
      {"elsif", {Enum::Token::Type::ElsifStmt, Enum::Token::Kind::Stmt, "ElsifStmt", "elsif"}},
      {""}, {""}, {""}, {""}, {""},
#line 15 "gen/reserved_keywords.gperf"
      {"-", {Enum::Token::Type::Sub, Enum::Token::Kind::Operator, "Sub", "-"}},
#line 63 "gen/reserved_keywords.gperf"
      {"||", {Enum::Token::Type::Or, Enum::Token::Kind::Operator, "Or", "||"}},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
#line 346 "gen/reserved_keywords.gperf"
      {"->", {Enum::Token::Type::Pointer, Enum::Token::Kind::Operator, "Pointer", "->"}},
      {""}, {""}, {""}, {""},
#line 70 "gen/reserved_keywords.gperf"
      {"//", {Enum::Token::Type::RegExp, Enum::Token::Kind::Term, "RegExp", "//"}},
      {""}, {""}, {""}, {""},
#line 304 "gen/reserved_keywords.gperf"
      {"-x", {Enum::Token::Type::Handle, Enum::Token::Kind::Handle, "Handle", "-x"}},
      {""}, {""}, {""}, {""},
#line 379 "gen/reserved_keywords.gperf"
      {"$-", {Enum::Token::Type::SpecificValue, Enum::Token::Kind::Term, "SpecificValue", "$-"}},
      {""}, {""},
#line 99 "gen/reserved_keywords.gperf"
      {"study", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "study"}},
      {""},
#line 314 "gen/reserved_keywords.gperf"
      {"-W", {Enum::Token::Type::Handle, Enum::Token::Kind::Handle, "Handle", "-W"}},
      {""}, {""}, {""}, {""}, {""}, {""}, {""},
#line 288 "gen/reserved_keywords.gperf"
      {"break", {Enum::Token::Type::Break, Enum::Token::Kind::Control, "Break", "break"}},
      {""},
#line 309 "gen/reserved_keywords.gperf"
      {"-M", {Enum::Token::Type::Handle, Enum::Token::Kind::Handle, "Handle", "-M"}},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""},
#line 303 "gen/reserved_keywords.gperf"
      {"-w", {Enum::Token::Type::Handle, Enum::Token::Kind::Handle, "Handle", "-w"}},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""},
#line 289 "gen/reserved_keywords.gperf"
      {"-b", {Enum::Token::Type::Handle, Enum::Token::Kind::Handle, "Handle", "-b"}},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""},
#line 293 "gen/reserved_keywords.gperf"
      {"-f", {Enum::Token::Type::Handle, Enum::Token::Kind::Handle, "Handle", "-f"}},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""},
#line 167 "gen/reserved_keywords.gperf"
      {"wantarray", {Enum::Token::Type::BuiltinFunc, Enum::Token::Kind::Function, "BuiltinFunc", "wantarray"}},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""},
#line 56 "gen/reserved_keywords.gperf"
      {"--", {Enum::Token::Type::Dec, Enum::Token::Kind::Operator, "Dec", "--"}}
    };

  if (len <= MAX_WORD_LENGTH && len >= MIN_WORD_LENGTH)
    {
      register int key = hash (str, len);

      if (key <= MAX_HASH_VALUE && key >= 0)
        {
          register const char *s = wordlist[key].name;

          if (*str == *s && !strcmp (str + 1, s + 1))
            return &wordlist[key];
        }
    }
  return 0;
}
#line 424 "gen/reserved_keywords.gperf"

