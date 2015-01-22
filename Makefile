OBJS= \
 src/compiler/lexer/Compiler_manager.o \
 src/compiler/lexer/Compiler_scanner.o \
 src/compiler/lexer/Compiler_lexer.o \
 src/compiler/lexer/Compiler_annotator.o \
 src/compiler/util/Compiler_util.o \
 src/compiler/util/Compiler_double_charactor_operator.o \
 src/compiler/util/Compiler_gen_token_decl.o \
 src/compiler/util/Compiler_reserved_keyword.o \
 src/compiler/util/Compiler_token.o \
 src/compiler/util/Compiler_triple_charactor_operator.o

all: clean lexer main
	g++ -o token_test token_test.o ${OBJS} 
	./token_test

main:
	g++ -c -Iinclude -Wall token_test.cc -o token_test.o

lexer:
	g++ -c -Iinclude -I/usr/local/include -Wall src/compiler/lexer/Compiler_manager.cpp -o src/compiler/lexer/Compiler_manager.o
	g++ -c -Iinclude -I/usr/local/include -Wall src/compiler/lexer/Compiler_scanner.cpp -o src/compiler/lexer/Compiler_scanner.o
	g++ -c -Iinclude -I/usr/local/include -Wall src/compiler/lexer/Compiler_lexer.cpp -o src/compiler/lexer/Compiler_lexer.o
	g++ -c -Iinclude -I/usr/local/include -Wall src/compiler/lexer/Compiler_annotator.cpp -o src/compiler/lexer/Compiler_annotator.o
	g++ -c -Iinclude -I/usr/local/include -Wall src/compiler/util/Compiler_double_charactor_operator.cpp -o src/compiler/util/Compiler_double_charactor_operator.o
	g++ -c -Iinclude -I/usr/local/include -Wall src/compiler/util/Compiler_gen_token_decl.cpp -o src/compiler/util/Compiler_gen_token_decl.o
	g++ -c -Iinclude -I/usr/local/include -Wall src/compiler/util/Compiler_reserved_keyword.cpp -o src/compiler/util/Compiler_reserved_keyword.o
	g++ -c -Iinclude -I/usr/local/include -Wall src/compiler/util/Compiler_token.cpp -o src/compiler/util/Compiler_token.o
	g++ -c -Iinclude -I/usr/local/include -Wall src/compiler/util/Compiler_triple_charactor_operator.cpp -o src/compiler/util/Compiler_triple_charactor_operator.o
	g++ -c -Iinclude -I/usr/local/include -Wall src/compiler/util/Compiler_util.cpp -o src/compiler/util/Compiler_util.o

clean:
	rm -f src/compiler/lexer/*.o src/compiler/util/*.o test.o token_test.o token_test
