use strict;
use warnings;
use Compiler::Lexer;
use Data::Dumper;

my $filename = $ARGV[0];
my $lexer = Compiler::Lexer->new($filename);
open my $fh, '<', $filename;
my $script = do { local $/; <$fh> };
my $tokens = $lexer->tokenize($script);
print Dumper $tokens;
print Dumper $lexer->get_groups_by_syntax_level($$tokens, Compiler::Lexer::SyntaxType::T_Stmt);
print Dumper $lexer->get_used_modules($script);
