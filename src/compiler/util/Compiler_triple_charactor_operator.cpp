/* C++ code produced by gperf version 3.0.4 */
/* Command-line: gperf -L C++ gen/triple_charactor_operator.gperf  */
/* Computed positions: -k'1,3' */

#include <lexer.hpp>

/* maximum key range = 51, duplicates = 0 */

inline /*ARGSUSED*/
unsigned int TripleCharactorOperatorMap::hash(register const char *str)
{
	static unsigned char triple_asso_values[] = {
		51, 51, 51, 51, 51, 51, 51, 51, 51, 51,
		51, 51, 51, 51, 51, 51, 51, 51, 51, 51,
		51, 51, 51, 51, 51, 51, 51, 51, 51, 51,
		51, 51, 51, 51, 51, 51,  5, 51, 21, 51,
		51, 51,  1, 51, 51, 51, 25,  3, 51, 51,
		51, 51, 51, 51, 51, 51, 51, 51, 51, 51,
		20,  0, 20, 51, 51, 11, 51, 51,  6,  1,
		28, 23, 18, 13, 51, 51,  8,  3, 51, 30,
		25, 51, 20, 51, 15, 51, 51, 10,  5, 51,
		51, 51, 51, 51, 51, 51, 51, 51, 51, 51,
		51, 51, 51, 51, 51, 51, 51, 51, 51, 51,
		51, 51, 51, 51, 51, 51, 51, 51, 51, 51,
		51, 51, 51,  0,  0, 51, 51, 51, 51, 51,
		51, 51, 51, 51, 51, 51, 51, 51, 51, 51,
		51, 51, 51, 51, 51, 51, 51, 51, 51, 51,
		51, 51, 51, 51, 51, 51, 51, 51, 51, 51,
		51, 51, 51, 51, 51, 51, 51, 51, 51, 51,
		51, 51, 51, 51, 51, 51, 51, 51, 51, 51,
		51, 51, 51, 51, 51, 51, 51, 51, 51, 51,
		51, 51, 51, 51, 51, 51, 51, 51, 51, 51,
		51, 51, 51, 51, 51, 51, 51, 51, 51, 51,
		51, 51, 51, 51, 51, 51, 51, 51, 51, 51,
		51, 51, 51, 51, 51, 51, 51, 51, 51, 51,
		51, 51, 51, 51, 51, 51, 51, 51, 51, 51,
		51, 51, 51, 51, 51, 51, 51, 51, 51, 51,
		51, 51, 51, 51, 51, 51
	};
	return triple_asso_values[(unsigned char)str[2]] + triple_asso_values[(unsigned char)str[0]];
}

const char *TripleCharactorOperatorMap::in_word_set(register const char *str)
{
	static const char * triple_charactor_operators[] = {
		"||=",
		"**=",
		"",
		"//=",
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
		"&&=",
		"",
		"$^H",
		"",
		"$^R",
		"", "",
		"$^G",
		"",
		"$^P",
		"", "",
		"$^F",
		"",
		"$^O",
		"", "", "", "",
		"<=>",
		"", "", "", "", "", "", "", "", "",
		"..."
    };

	register int key = hash(str);
	if (key <= TRIPLE_OPERATOR_MAX_HASH_VALUE && key >= 0) {
		register const char *s = triple_charactor_operators[key];
		if (*str == *s && !strcmp(str + 1, s + 1)) return s;
	}
	return 0;
}
