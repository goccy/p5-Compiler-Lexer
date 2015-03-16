use strict;
use warnings;
use Benchmark qw/timethese cmpthese/;
use PPI::Tokenizer;
use Compiler::Lexer;
use Data::Dumper;
use constant {
    LOOP_COUNT => 1000
};

sub ppi {
    my $filename = $ARGV[0];
    my $tokenizer = PPI::Tokenizer->new($filename);
    $tokenizer->all_tokens;
}


sub compiler_lexer {
    my $filename = $ARGV[0];
    open my $fh, '<', $filename;
    my $script = do { local $/; <$fh> };
    my $lexer = Compiler::Lexer->new($filename);
    $lexer->tokenize($script);
}

my $result = timethese(LOOP_COUNT, {
    PPI => \&ppi,
    COMPILER_LEXER => \&compiler_lexer
});
cmpthese $result;
