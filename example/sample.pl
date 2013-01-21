use strict;
use warnings;
use Compiler::Lexer;
use Data::Dumper;

sub get_script {
    my ($filename) = @_;
    my $script = "";
    open(FP, "<", $filename) or die("Error");
    $script .= $_ foreach (<FP>);
    close(FP);
    return $script;
}

my $filename = $ARGV[0];
#print Dumper Lexer::deparse($filename, get_script($filename));
my $lexer = Compiler::Lexer->new($filename);
my $tokens = $lexer->tokenize(get_script($filename));
#print Dumper $tokens;
print Dumper $lexer->get_groups_by_syntax_level($$tokens, Compiler::Lexer::SyntaxType::T_Stmt);
print Dumper $lexer->get_used_modules(get_script($filename));
