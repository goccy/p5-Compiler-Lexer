use strict;
use warnings;
use Compiler::Lexer;
use Test::More;

is_deeply([ map { $_->name } @{Compiler::Lexer->new->tokenize("q'foobar'")} ], [qw/RegQuote RegDelim RegExp RegDelim/]);
is_deeply([ map { $_->name } @{Compiler::Lexer->new->tokenize('q"foobar"')} ], [qw/RegQuote RegDelim RegExp RegDelim/]);
is_deeply([ map { $_->name } @{Compiler::Lexer->new->tokenize("qq'foobar'")} ], [qw/RegDoubleQuote RegDelim RegExp RegDelim/]);
is_deeply([ map { $_->name } @{Compiler::Lexer->new->tokenize('qq"foobar"')} ], [qw/RegDoubleQuote RegDelim RegExp RegDelim/]);
is_deeply([ map { $_->name } @{Compiler::Lexer->new->tokenize("qw'foobar'")} ], [qw/RegList RegDelim RegExp RegDelim/]);
is_deeply([ map { $_->name } @{Compiler::Lexer->new->tokenize('qw"foobar"')} ], [qw/RegList RegDelim RegExp RegDelim/]);

done_testing;
