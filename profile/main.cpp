#include <lexer.hpp>
using namespace std;

int main(int argc, char **argv)
{
	Lexer lexer("", false);
	FILE *fp = NULL;
	char *filename = argv[1];
	static const int MAX_BUFFER_SIZE = 256;
	char buffer[MAX_BUFFER_SIZE] = {0};
	if ((fp = fopen(filename, "r")) == NULL) {
		fprintf(stderr, "[ERROR] Cannot open file. [%s]\n", filename);
		exit(EXIT_FAILURE);
	}
	string script;
	while (fgets(buffer, MAX_BUFFER_SIZE, fp) != NULL) {
		script += buffer;
	}
	for (size_t i = 0; i < 1000; i++) {
		Tokens *tokens = lexer.tokenize((char *)script.c_str());
	}
	return 0;
}
