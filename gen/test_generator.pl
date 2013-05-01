use strict;
use warnings;
use Compiler::Lexer;
use Data::Dumper;
sub get_script {
    my ($filename) = @_;
    open(my $fh, '<', $filename);
    return do { local $/; <$fh> };
}

sub generate {
    my $filename = shift;
    my $script = get_script $filename;
    my $lexer = Compiler::Lexer->new($filename);
    my $tokens = $lexer->tokenize($script);
    print Dumper $$tokens;
    my $stmts = $lexer->get_groups_by_syntax_level($$tokens, Compiler::Lexer::SyntaxType::T_Stmt);
    my $modules = Compiler::Lexer->new($filename)->get_used_modules(get_script $filename);
    my $template =<<'TEMPLATE';
use strict;
use warnings;
use Test::More;
BEGIN {
    use_ok('Compiler::Lexer');
}
my $script =<<'SCRIPT';
%s
SCRIPT

subtest 'tokenize' => sub {
    my $tokens = Compiler::Lexer->new('')->tokenize($script);
    is_deeply($$tokens, %s, 'Compiler::Lexer::tokenize');
};

subtest 'get_groups_by_syntax_level' => sub {
    my $lexer = Compiler::Lexer->new('');
    my $tokens = $lexer->tokenize($script);
    my $stmts = $lexer->get_groups_by_syntax_level($$tokens, Compiler::Lexer::SyntaxType::T_Stmt);
    is_deeply($$stmts, %s, 'Compiler::Lexer::get_groups_by_syntax_level');
};

subtest 'get_used_modules' => sub {
    my $modules = Compiler::Lexer->new('')->get_used_modules($script);
    is_deeply($modules, %s, 'Compiler::Lexer::get_used_modules');
};

done_testing;
TEMPLATE
    $filename =~ s|(.*)/||;
    open my $fh, '>', "t/$filename";
    my $tmp1 = Dumper $$tokens;
    my $tmp2 = Dumper $$stmts;
    my $tmp3 = Dumper $modules;
    my @filtered = map { $_ =~ s/\$VAR1 = //; $_ =~ s/;$//; $_; } ($tmp1, $tmp2, $tmp3);
    print $fh sprintf($template, $script, @filtered);
}

generate($_) foreach @ARGV;
