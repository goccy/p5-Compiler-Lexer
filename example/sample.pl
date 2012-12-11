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
print Dumper Lexer::get_stmt_codes($filename, get_script($filename));
print Dumper Lexer::get_used_modules($filename, get_script($filename));
