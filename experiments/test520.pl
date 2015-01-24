use lib qw(blib/lib);
use v5.20;
use Data::Dumper;

use Compiler::Lexer;

=pod

  use Compiler::Lexer;
  use Data::Dumper;

  my $filename = $ARGV[0];
  open my $fh, '<', $filename or die "Cannot open $filename: $!";
  my $script = do { local $/; <$fh> };

  my $lexer = Compiler::Lexer->new($filename);
  my $tokens = $lexer->tokenize($script);
  print Dumper $tokens;

  my $modules = $lexer->get_used_modules($script);
  print Dumper $modules;

=cut

my $lexer = Compiler::Lexer->new( 'foo' );

my $script = '$array->@*';
my $tokens = $lexer->tokenize( $script );

say Dumper( $tokens );
