CC = em++
CFLAGS = -O3 -g3 -Wall -W -I../include --bind -s DEMANGLE_SUPPORT=1
target = perl_lexer.js

objs = build/bind.bc \
	build/annotator.bc\
	build/lexer.bc\
	build/manager.bc\
	build/scanner.bc\
	build/double_character_operator.bc\
	build/triple_character_operator.bc\
	build/reserved_keyword.bc\
	build/gen_token_decl.bc\
	build/util.bc\
	build/token.bc\

.PHONY: all
all: $(target)

$(target): $(objs)
	$(CC) $(CFLAGS) -o $@ $^ $(LDLIBS)

build/bind.bc : bind.cpp
	$(CC) $(CFLAGS) -o $@ -c $^

build/annotator.bc : ../src/compiler/lexer/Compiler_annotator.cpp
	$(CC) $(CFLAGS) -o $@ -c $^

build/lexer.bc : ../src/compiler/lexer/Compiler_lexer.cpp
	$(CC) $(CFLAGS) -o $@ -c $^

build/manager.bc : ../src/compiler/lexer/Compiler_manager.cpp
	$(CC) $(CFLAGS) -o $@ -c $^

build/scanner.bc : ../src/compiler/lexer/Compiler_scanner.cpp
	$(CC) $(CFLAGS) -o $@ -c $^

build/double_character_operator.bc : ../src/compiler/util/Compiler_double_charactor_operator.cpp
	$(CC) $(CFLAGS) -o $@ -c $^

build/triple_character_operator.bc : ../src/compiler/util/Compiler_triple_charactor_operator.cpp
	$(CC) $(CFLAGS) -o $@ -c $^

build/reserved_keyword.bc : ../src/compiler/util/Compiler_reserved_keyword.cpp
	$(CC) $(CFLAGS) -o $@ -c $^

build/gen_token_decl.bc : ../src/compiler/util/Compiler_gen_token_decl.cpp
	$(CC) $(CFLAGS) -o $@ -c $^

build/util.bc : ../src/compiler/util/Compiler_util.cpp
	$(CC) $(CFLAGS) -o $@ -c $^

build/token.bc : ../src/compiler/util/Compiler_token.cpp
	$(CC) $(CFLAGS) -o $@ -c $^


.PHONY: clean
clean:
	$(RM) -rf $(objs) $(target) *~
