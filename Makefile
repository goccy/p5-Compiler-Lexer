
all: clean lexer main
	g++ -o final test.o src/compiler/util/*.o src/compiler/lexer/*.o 
	./final

main:
	g++ -c -Iinclude -Wall test.cc

%.o: %.c 
	$(CC) $(CFLAGS) $(CPPFLAGS) -c $<

lexer:
	g++ -c -Iinclude -I/usr/local/include -Wall src/compiler/lexer/Compiler_manager.cpp -o src/compiler/lexer/Compiler_manager.o
	g++ -c -Iinclude -I/usr/local/include -Wall src/compiler/lexer/Compiler_scanner.cpp -o src/compiler/lexer/Compiler_scanner.o
	g++ -c -Iinclude -I/usr/local/include -Wall src/compiler/util/Compiler_double_charactor_operator.cpp -o src/compiler/util/Compiler_double_charactor_operator.o
	g++ -c -Iinclude -I/usr/local/include -Wall src/compiler/util/Compiler_gen_token_decl.cpp -o src/compiler/util/Compiler_gen_token_decl.o
	g++ -c -Iinclude -I/usr/local/include -Wall src/compiler/util/Compiler_reserved_keyword.cpp -o src/compiler/util/Compiler_reserved_keyword.o
	g++ -c -Iinclude -I/usr/local/include -Wall src/compiler/util/Compiler_token.cpp -o src/compiler/util/Compiler_token.o
	g++ -c -Iinclude -I/usr/local/include -Wall src/compiler/util/Compiler_triple_charactor_operator.cpp -o src/compiler/util/Compiler_triple_charactor_operator.o

clean:
	rm -f src/compiler/lexer/*.o src/compiler/util/*.o test.o final
