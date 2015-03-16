/* C++ code produced by gperf version 3.0.3 */
/* Command-line: gperf -L C++ gen/triple_charactor_operator.gperf  */
/* Computed positions: -k'1,3' */

#include <lexer.hpp>

/* maximum key range = 51, duplicates = 0 */

inline unsigned int
TripleCharactorOperatorMap::hash(register const char *str)
{
	static unsigned char asso_values[] = {
		54, 54, 54, 54, 54, 54, 54, 54, 54, 54,
		54, 54, 54, 54, 54, 54, 54, 54, 54, 54,
		54, 54, 54, 54, 54, 54, 54, 54, 54, 54,
		54, 54, 54, 54, 54, 54, 10, 54,  1, 54,
		54, 54,  8, 54, 54, 54, 25,  3, 54, 54,
		54, 54, 54, 54, 54, 54, 54, 54, 54, 54,
		10,  0,  5, 54, 54, 21, 54, 54, 16, 11,
		6,  1, 28, 23, 54, 54, 18, 13, 54,  8,
		3, 54, 30, 54, 25, 54, 54, 20, 15, 54,
		54, 54, 54, 54, 54, 54, 54, 54, 54, 54,
		54, 54, 54, 54, 54, 54, 54, 54, 54, 54,
		54, 54, 54, 54, 54, 54, 54, 54, 54, 54,
		54, 54, 54, 10,  0, 54, 54, 54, 54, 54,
		54, 54, 54, 54, 54, 54, 54, 54, 54, 54,
		54, 54, 54, 54, 54, 54, 54, 54, 54, 54,
		54, 54, 54, 54, 54, 54, 54, 54, 54, 54,
		54, 54, 54, 54, 54, 54, 54, 54, 54, 54,
		54, 54, 54, 54, 54, 54, 54, 54, 54, 54,
		54, 54, 54, 54, 54, 54, 54, 54, 54, 54,
		54, 54, 54, 54, 54, 54, 54, 54, 54, 54,
		54, 54, 54, 54, 54, 54, 54, 54, 54, 54,
		54, 54, 54, 54, 54, 54, 54, 54, 54, 54,
		54, 54, 54, 54, 54, 54, 54, 54, 54, 54,
		54, 54, 54, 54, 54, 54, 54, 54, 54, 54,
		54, 54, 54, 54, 54, 54, 54, 54, 54, 54,
		54, 54, 54, 54, 54, 54
	};
	return asso_values[(unsigned char)str[2]] + asso_values[(unsigned char)str[0]];
}

const char *TripleCharactorOperatorMap::in_word_set(register const char *str)
{
	static const char * triple_charactor_operators[] = {
		"||=",
		"&&=",
		"",
		"//=",
		"",
		">>=",
		"", "",
		"**=",
		"",
		"<<=",
		"$^G",
		"",
		"$^P",
		"",
		"<=>",
		"$^F",
		"",
		"$^O",
		"",
		"$#{",
		"$^E",
		"",
		"$^M",
		"",
		"$^X",
		"$^D",
		"",
		"$^L",
		"",
		"$^W",
		"$^A",
		"",
		"$^I",
		"",
		"$^T",
		"", "",
		"$^H",
		"",
		"$^R",
		"", "", "", "", "", "", "", "", "",
		"..."
	};

	register int key = hash(str);
	if (key <= TRIPLE_OPERATOR_MAX_HASH_VALUE && key >= 0) {
		register const char *s = triple_charactor_operators[key];
		if (*str == *s && !strcmp (str + 1, s + 1)) return s;
	}
	return 0;
}

