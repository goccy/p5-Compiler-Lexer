use strict;
use warnings;
use Compiler::Lexer;
use File::Basename qw/basename dirname/;
use YAML::XS qw/LoadFile/;
use File::Find qw//;
use Data::Dumper;
use Cwd qw/getcwd/;

use constant CURRENT_DIR => getcwd;
use constant YAML_PATH => CURRENT_DIR . '/gen/gen_constants.yaml';
use constant PERL_DIR => '/path/to/perl-5.16.3';

my $template = template();

sub slurp {
    my ($filename) = @_;
    open(my $fh, '<', $filename);
    return do { local $/; <$fh> };
}

sub template {
    return do { local $/; <DATA> };
}

sub get_constants_map {
    return LoadFile YAML_PATH;
}

sub generate {
    my $filename = shift;
    my $script = slurp $filename;
    my $lexer = Compiler::Lexer->new($filename);
    my ($tokens, $stmts, $modules);
    eval {
        $tokens = $lexer->tokenize($script);
        $stmts = $lexer->get_groups_by_syntax_level($tokens, Compiler::Lexer::SyntaxType::T_Stmt);
        $modules = Compiler::Lexer->new($filename)->get_used_modules($script);
    };
    if ($@) {
        warn "[ERROR] $filename [$@]\n";
    }

    my $dirname = dirname $filename;
    my $basename = basename $filename;
    $dirname =~ s|(.*)/||;
    open my $fh, '>', CURRENT_DIR . "/t/perl/$dirname/$basename";
    my $constans_map = get_constants_map;
    my $type = $constans_map->{token_type};
    my $kind = $constans_map->{token_kind};
    my $stype = $constans_map->{syntax_type};

    foreach my $token (@$tokens) {
        foreach my $key (keys %$type) {
            if ($token->type eq $type->{$key}) {
                $token->type("Compiler::Lexer::TokenType::$key");
            }
        }
        foreach my $key (keys %$kind) {
            if ($token->kind eq $kind->{$key}) {
                $token->kind("Compiler::Lexer::Kind::$key");
            }
        }
        foreach my $key (keys %$stype) {
            if ($token->stype eq $stype->{$key}) {
                $token->stype("Compiler::Lexer::SyntaxType::$key");
            }
        }
    }
    my $tmp1 = Dumper $tokens;
    $tmp1 =~ s/'type' => '(.*)'/'type' => $1/g;
    $tmp1 =~ s/'kind' => '(.*)'/'kind' => $1/g;
    $tmp1 =~ s/'stype' => '(.*)'/'stype' => $1/g;
    my $tmp2 = (ref $stmts eq 'ARRAY') ? Dumper $stmts : '';
    my $tmp3 = Dumper $modules;
    my @filtered = map { $_ =~ s/\$VAR1 = //; $_ =~ s/;$//; $_; } ($tmp1, $tmp2, $tmp3);
    print $fh sprintf($template, $script, @filtered);
    print "generated ", CURRENT_DIR . "/t/perl/$dirname/$basename\n";
}

if (@ARGV) {
    generate($ARGV[0]);
} else {
    File::Find::find(sub {
        return unless $_ =~ /\.t$/;
        generate("$File::Find::dir/$_");
    }, PERL_DIR . '/t');
}

__DATA__
use strict;
use warnings;
use Test::More;
BEGIN {
    use_ok('Compiler::Lexer');
}
my $script =<<'__SCRIPT__';
%s
__SCRIPT__

subtest 'tokenize' => sub {
    my $tokens = Compiler::Lexer->new('')->tokenize($script);
    is_deeply($tokens, %s, 'Compiler::Lexer::tokenize');
};

subtest 'get_groups_by_syntax_level' => sub {
    my $lexer = Compiler::Lexer->new('');
    my $tokens = $lexer->tokenize($script);
    my $stmts = $lexer->get_groups_by_syntax_level($tokens, Compiler::Lexer::SyntaxType::T_Stmt);
    is_deeply($stmts, %s, 'Compiler::Lexer::get_groups_by_syntax_level');
};

subtest 'get_used_modules' => sub {
    my $modules = Compiler::Lexer->new('')->get_used_modules($script);
    is_deeply($modules, %s, 'Compiler::Lexer::get_used_modules');
};

done_testing;
