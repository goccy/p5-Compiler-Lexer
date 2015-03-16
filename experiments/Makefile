SRC=../src/compiler
OBJS= \
 ${SRC}/lexer/Compiler_manager.o \
 ${SRC}/lexer/Compiler_scanner.o \
 ${SRC}/lexer/Compiler_lexer.o \
 ${SRC}/lexer/Compiler_annotator.o \
 ${SRC}/util/Compiler_util.o \
 ${SRC}/util/Compiler_double_charactor_operator.o \
 ${SRC}/util/Compiler_gen_token_decl.o \
 ${SRC}/util/Compiler_reserved_keyword.o \
 ${SRC}/util/Compiler_token.o \
 ${SRC}/util/Compiler_triple_charactor_operator.o

all: clean lexer main
	g++ -o token_test token_test.o ${OBJS}
	./token_test

main:
	g++ -c -I../include -Wall token_test.cc -o token_test.o

lexer:
	g++ -c -I../include -I/usr/local/include -Wall ${SRC}/lexer/Compiler_manager.cpp -o ${SRC}/lexer/Compiler_manager.o
	g++ -c -I../include -I/usr/local/include -Wall ${SRC}/lexer/Compiler_scanner.cpp -o ${SRC}/lexer/Compiler_scanner.o
	g++ -c -I../include -I/usr/local/include -Wall ${SRC}/lexer/Compiler_lexer.cpp -o ${SRC}/lexer/Compiler_lexer.o
	g++ -c -I../include -I/usr/local/include -Wall ${SRC}/lexer/Compiler_annotator.cpp -o ${SRC}/lexer/Compiler_annotator.o
	g++ -c -I../include -I/usr/local/include -Wall ${SRC}/util/Compiler_double_charactor_operator.cpp -o ${SRC}/util/Compiler_double_charactor_operator.o
	g++ -c -I../include -I/usr/local/include -Wall ${SRC}/util/Compiler_gen_token_decl.cpp -o ${SRC}/util/Compiler_gen_token_decl.o
	g++ -c -I../include -I/usr/local/include -Wall ${SRC}/util/Compiler_reserved_keyword.cpp -o ${SRC}/util/Compiler_reserved_keyword.o
	g++ -c -I../include -I/usr/local/include -Wall ${SRC}/util/Compiler_token.cpp -o ${SRC}/util/Compiler_token.o
	g++ -c -I../include -I/usr/local/include -Wall ${SRC}/util/Compiler_triple_charactor_operator.cpp -o ${SRC}/util/Compiler_triple_charactor_operator.o
	g++ -c -I../include -I/usr/local/include -Wall ${SRC}/util/Compiler_util.cpp -o ${SRC}/util/Compiler_util.o

clean:
	rm -f ${SRC}/lexer/*.o ${SRC}/util/*.o test.o token_test.o token_test

include/gen_token.hpp:
	${PERL} gen/gen_decl.pl
