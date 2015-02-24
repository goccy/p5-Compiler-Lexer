CC = clang++
CFLAGS = -O3 -g3 -Wall -W -I../include
target = perl_lexer

objs = build/main.o \
	build/annotator.o\
	build/lexer.o\
	build/manager.o\
	build/scanner.o\
	build/double_character_operator.o\
	build/triple_character_operator.o\
	build/reserved_keyword.o\
	build/gen_token_decl.o\
	build/util.o\
	build/token.o\

.PHONY: all
all: $(target)

$(target): $(objs)
	$(CC) -o $@ $^ $(LDLIBS)

build/main.o : main.cpp
	$(CC) $(CFLAGS) -o $@ -c $^

build/annotator.o : ../src/compiler/lexer/Compiler_annotator.cpp
	$(CC) $(CFLAGS) -o $@ -c $^

build/lexer.o : ../src/compiler/lexer/Compiler_lexer.cpp
	$(CC) $(CFLAGS) -o $@ -c $^

build/manager.o : ../src/compiler/lexer/Compiler_manager.cpp
	$(CC) $(CFLAGS) -o $@ -c $^

build/scanner.o : ../src/compiler/lexer/Compiler_scanner.cpp
	$(CC) $(CFLAGS) -o $@ -c $^

build/double_character_operator.o : ../src/compiler/util/Compiler_double_charactor_operator.cpp
	$(CC) $(CFLAGS) -o $@ -c $^

build/triple_character_operator.o : ../src/compiler/util/Compiler_triple_charactor_operator.cpp
	$(CC) $(CFLAGS) -o $@ -c $^

build/reserved_keyword.o : ../src/compiler/util/Compiler_reserved_keyword.cpp
	$(CC) $(CFLAGS) -o $@ -c $^

build/gen_token_decl.o : ../src/compiler/util/Compiler_gen_token_decl.cpp
	$(CC) $(CFLAGS) -o $@ -c $^

build/util.o : ../src/compiler/util/Compiler_util.cpp
	$(CC) $(CFLAGS) -o $@ -c $^

build/token.o : ../src/compiler/util/Compiler_token.cpp
	$(CC) $(CFLAGS) -o $@ -c $^


.PHONY: clean
clean:
	$(RM) -rf $(objs) $(target) *~
