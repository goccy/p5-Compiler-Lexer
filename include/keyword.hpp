#define TRIPLE_OPERATOR_TOTAL_KEYWORDS 24
#define TRIPLE_OPERATOR_MIN_WORD_LENGTH 3
#define TRIPLE_OPERATOR_MAX_WORD_LENGTH 3
#define TRIPLE_OPERATOR_MIN_HASH_VALUE 3
#define TRIPLE_OPERATOR_MAX_HASH_VALUE 50

#define DOUBLE_OPERATOR_TOTAL_KEYWORDS 79
#define DOUBLE_OPERATOR_MIN_WORD_LENGTH 2
#define DOUBLE_OPERATOR_MAX_WORD_LENGTH 2
#define DOUBLE_OPERATOR_MIN_HASH_VALUE 2
#define DOUBLE_OPERATOR_MAX_HASH_VALUE 200

class TripleCharactorOperatorMap {
private:
	static inline unsigned int hash(const char *str);
public:
	static const char *in_word_set(const char *str);
};

class DoubleCharactorOperatorMap {
private:
	static inline unsigned int hash(const char *str);
public:
	static const char *in_word_set(const char *str);
};

typedef struct _ReservedKeyword {
    const char *name;
    TokenInfo info;
} ReservedKeyword;

class ReservedKeywordMap
{
private:
  static inline unsigned int hash (const char *str, unsigned int len);
public:
  static ReservedKeyword *in_word_set (const char *str, unsigned int len);
};

