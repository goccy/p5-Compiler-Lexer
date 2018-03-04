use strict;
use warnings;
use Test::More;
BEGIN {
    use_ok('Compiler::Lexer');
}
my $script =<<'__SCRIPT__';
#!./perl

#
# test the conversion operators
#
# Notations:
#
# "N p i N vs N N":  Apply op-N, then op-p, then op-i, then reporter-N
# Compare with application of op-N, then reporter-N
# Right below are descriptions of different ops and reporters.

# We do not use these subroutines any more, sub overhead makes a "switch"
# solution better:

# obviously, 0, 1 and 2, 3 are destructive.  (XXXX 64-bit? 4 destructive too)

# *0 = sub {--$_[0]};		# -
# *1 = sub {++$_[0]};		# +

# # Converters
# *2 = sub { $_[0] = $max_uv & $_[0]}; # U
# *3 = sub { use integer; $_[0] += $zero}; # I
# *4 = sub { $_[0] += $zero};	# N
# *5 = sub { $_[0] = "$_[0]" };	# P

# # Side effects
# *6 = sub { $max_uv & $_[0]};	# u
# *7 = sub { use integer; $_[0] + $zero};	# i
# *8 = sub { $_[0] + $zero};	# n
# *9 = sub { $_[0] . "" };	# p

# # Reporters
# sub a2 { sprintf "%u", $_[0] }	# U
# sub a3 { sprintf "%d", $_[0] }	# I
# sub a4 { sprintf "%g", $_[0] }	# N
# sub a5 { "$_[0]" }		# P

BEGIN {
    chdir 't' if -d 't';
    @INC = '../lib';
    require './test.pl';
}

use strict;

my $max_chain = $ENV{PERL_TEST_NUMCONVERTS} || 2;

# Bulk out if unsigned type is hopelessly wrong:
my $max_uv1 = ~0;
my $max_uv2 = sprintf "%u", $max_uv1 ** 6; # 6 is an arbitrary number here
my $big_iv = do {use integer; $max_uv1 * 16}; # 16 is an arbitrary number here
my $max_uv_less3 = $max_uv1 - 3;

print "# max_uv1 = $max_uv1, max_uv2 = $max_uv2, big_iv = $big_iv\n";
print "# max_uv_less3 = $max_uv_less3\n";
if ($max_uv1 ne $max_uv2 or $big_iv > $max_uv1 or $max_uv1 == $max_uv_less3) {
  eval { require Config; };
  my $message = 'unsigned perl arithmetic is not sane';
  $message .= " (common in 64-bit platforms)" if $Config::Config{d_quad};
  skip_all($message);
}
if ($max_uv_less3 =~ tr/0-9//c) {
  skip_all('this perl stringifies large unsigned integers using E notation');
}

my $st_t = 4*4;			# We try 4 initializers and 4 reporters

my $num = 0;
$num += 10**$_ - 4**$_ for 1.. $max_chain;
$num *= $st_t;
$num += $::additional_tests;
plan(tests => $num);		# In fact 15 times more subsubtests...

my $max_uv = ~0;
my $max_iv = int($max_uv/2);
my $zero = 0;

my $l_uv = length $max_uv;
my $l_iv = length $max_iv;

# Hope: the first digits are good
my $larger_than_uv = substr 97 x 100, 0, $l_uv;
my $smaller_than_iv = substr 12 x 100, 0, $l_iv;
my $yet_smaller_than_iv = substr 97 x 100, 0, ($l_iv - 1);

my @list = (1, $yet_smaller_than_iv, $smaller_than_iv, $max_iv, $max_iv + 1,
	    $max_uv, $max_uv + 1);
unshift @list, (reverse map -$_, @list), 0; # 15 elts
@list = map "$_", @list; # Normalize

note("@list");

# need to special case ++ for max_uv, as ++ "magic" on a string gives
# another string, whereas ++ magic on a string used as a number gives
# a number. Not a problem when NV preserves UV, but if it doesn't then
# stringification of the latter gives something in e notation.

my $max_uv_pp = "$max_uv"; $max_uv_pp++;
my $max_uv_p1 = "$max_uv"; $max_uv_p1+=0; $max_uv_p1++;

# Also need to cope with %g notation for max_uv_p1 that actually gives an
# integer less than max_uv because of correct rounding for the limited
# precision. This bites for 12 byte long doubles and 8 byte UVs

my $temp = $max_uv_p1;
my $max_uv_p1_as_iv;
{use integer; $max_uv_p1_as_iv = 0 + sprintf "%s", $temp}
my $max_uv_p1_as_uv = 0 | sprintf "%s", $temp;

my @opnames = split //, "-+UINPuinp";

# @list = map { 2->($_), 3->($_), 4->($_), 5->($_),  } @list; # Prepare input

my $test = 1;
my $nok;
for my $num_chain (1..$max_chain) {
  my @ops = map [split //], grep /[4-9]/,
    map { sprintf "%0${num_chain}d", $_ }  0 .. 10**$num_chain - 1;

  #@ops = ([]) unless $num_chain;
  #@ops = ([6, 4]);

  for my $op (@ops) {
    for my $first (2..5) {
      for my $last (2..5) {
	$nok = 0;
	my @otherops = grep $_ <= 3, @$op;
	my @curops = ($op,\@otherops);

	for my $num (@list) {
	  my $inpt;
	  my @ans;

	  for my $short (0, 1) {
	    # undef $inpt;	# Forget all we had - some bugs were masked

	    $inpt = $num;	# Try to not contaminate $num...
	    $inpt = "$inpt";
	    if ($first == 2) {
	      $inpt = $max_uv & $inpt; # U 2
	    } elsif ($first == 3) {
	      use integer; $inpt += $zero; # I 3
	    } elsif ($first == 4) {
	      $inpt += $zero;	# N 4
	    } else {
	      $inpt = "$inpt";	# P 5
	    }

	    # Saves 20% of time - not with this logic:
	    #my $tmp = $inpt;
	    #my $tmp1 = $num;
	    #next if $num_chain > 1
	    #  and "$tmp" ne "$tmp1"; # Already the coercion gives problems...

	    for my $curop (@{$curops[$short]}) {
	      if ($curop < 5) {
		if ($curop < 3) {
		  if ($curop == 0) {
		    --$inpt;	# - 0
		  } elsif ($curop == 1) {
		    ++$inpt;	# + 1
		  } else {
		    $inpt = $max_uv & $inpt; # U 2
		  }
		} elsif ($curop == 3) {
		  use integer; $inpt += $zero;
		} else {
		  $inpt += $zero; # N 4
		}
	      } elsif ($curop < 8) {
		if ($curop == 5) {
		  $inpt = "$inpt"; # P 5
		} elsif ($curop == 6) {
		  my $dummy = $max_uv & $inpt; # u 6
		} else {
		  use integer; my $dummy = $inpt + $zero;
		}
	      } elsif ($curop == 8) {
		my $dummy = $inpt + $zero;	# n 8
	      } else {
		my $dummy = $inpt . "";	# p 9
	      }
	    }

	    if ($last == 2) {
	      $inpt = sprintf "%u", $inpt; # U 2
	    } elsif ($last == 3) {
	      $inpt = sprintf "%d", $inpt; # I 3
	    } elsif ($last == 4) {
	      $inpt = sprintf "%g", $inpt; # N 4
	    } else {
	      $inpt = "$inpt";	# P 5
	    }
	    push @ans, $inpt;
	  }
	  if ($ans[0] ne $ans[1]) {
	    my $diag = "'$ans[0]' ne '$ans[1]',\t$num\t=> @opnames[$first,@{$curops[0]},$last] vs @opnames[$first,@{$curops[1]},$last]";
	    my $excuse;
	    # XXX ought to check that "+" was in the list of opnames
	    if ((($ans[0] eq $max_uv_pp) and ($ans[1] eq $max_uv_p1))
		or (($ans[1] eq $max_uv_pp) and ($ans[0] eq $max_uv_p1))) {
	      # string ++ versus numeric ++. Tolerate this little
	      # bit of insanity
	      $excuse = "ok, as string ++ of max_uv is \"$max_uv_pp\", numeric is $max_uv_p1";
	    } elsif ($opnames[$last] eq 'I' and $ans[1] eq "-1"
		     and $ans[0] eq $max_uv_p1_as_iv) {
              # Max UV plus 1 is NV. This NV may stringify in E notation.
              # And the number of decimal digits shown in E notation will depend
              # on the binary digits in the mantissa. And it may be that
              # (say)  18446744073709551616 in E notation is truncated to
              # (say) 1.8446744073709551e+19 (say) which gets converted back
              # as    1.8446744073709551000e+19
              # ie    18446744073709551000
              # which isn't the integer we first had.
              # But each step of conversion is correct. So it's not an error.
              # (Only shows up for 64 bit UVs and NVs with 64 bit mantissas,
              #  and on Crays (64 bit integers, 48 bit mantissas) IIRC)
	      $excuse = "ok, \"$max_uv_p1\" correctly converts to IV \"$max_uv_p1_as_iv\"";
	    } elsif ($opnames[$last] eq 'U' and $ans[1] eq ~0
		     and $ans[0] eq $max_uv_p1_as_uv) {
              # as aboce
	      $excuse = "ok, \"$max_uv_p1\" correctly converts to UV \"$max_uv_p1_as_uv\"";
	    } elsif (grep {defined $_ && /^N$/} @opnames[@{$curops[0]}]
		     and $ans[0] == $ans[1] and $ans[0] <= ~0
                     # First must be in E notation (ie not just digits) and
                     # second must still be an integer.
		     # eg 1.84467440737095516e+19
		     # 1.84467440737095516e+19 for 64 bit mantissa is in the
		     # integer range, so 1.84467440737095516e+19 + 0 is treated
		     # as integer addition. [should it be?]
		     # and 18446744073709551600 + 0 is 18446744073709551600
		     # Which isn't the string you first thought of.
                     # I can't remember why there isn't symmetry in this
                     # exception, ie why only the first ops are tested for 'N'
                     and $ans[0] != /^-?\d+$/ and $ans[1] !~ /^-?\d+$/) {
	      $excuse = "ok, numerically equal - notation changed due to adding zero";
	    } else {
	      $nok++,
	      diag($diag);
	    }
	    if ($excuse) {
	      note($diag);
	      note($excuse);
	    }
	  }
	}
	ok($nok == 0);
      }
    }
  }
}

# Tests that use test.pl start here.
BEGIN { $::additional_tests = 4 }

ok(-0.0 eq "0", 'negative zero stringifies as 0');
ok(!-0.0, "neg zero is boolean false");
my $nz = -0.0;
{ my $dummy = "$nz"; }
ok(!$nz, 'previously stringified -0.0 is boolean false');
$nz = -0.0;
is sprintf("%+.f", - -$nz), sprintf("%+.f", - -$nz),
  "negation does not coerce negative zeroes";

__SCRIPT__

subtest 'tokenize' => sub {
    my $tokens = Compiler::Lexer->new('')->tokenize($script);
    is_deeply($tokens, [
          bless( {
                   'data' => 'BEGIN',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 38,
                   'kind' => Compiler::Lexer::Kind::T_ModWord,
                   'has_warnings' => 0,
                   'name' => 'ModWord',
                   'type' => Compiler::Lexer::TokenType::T_ModWord
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 38,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'chdir',
                   'line' => 39,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 't',
                   'line' => 39,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'IfStmt',
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'data' => 'if',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'line' => 39
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'line' => 39,
                   'data' => '-d',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Handle',
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 't',
                   'line' => 39,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'line' => 39,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '@INC',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 40,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LibraryDirectories,
                   'name' => 'LibraryDirectories'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 40,
                   'kind' => Compiler::Lexer::Kind::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '../lib',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 40,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 40,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 41,
                   'data' => 'require',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RequireDecl',
                   'type' => Compiler::Lexer::TokenType::T_RequireDecl,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 41,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => './test.pl',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 41,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 42,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 44,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'use',
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'name' => 'UseDecl',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'line' => 44,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'strict',
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'name' => 'UsedName',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'line' => 44,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'data' => 'my',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$max_chain',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 46,
                   'has_warnings' => 0,
                   'name' => 'LocalVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 46,
                   'has_warnings' => 0,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$ENV',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 46,
                   'has_warnings' => 0,
                   'name' => 'GlobalVar',
                   'type' => Compiler::Lexer::TokenType::T_GlobalVar
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'PERL_TEST_NUMCONVERTS',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 46,
                   'has_warnings' => 0,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 46,
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 46,
                   'data' => '||',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Or',
                   'type' => Compiler::Lexer::TokenType::T_Or,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '2',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 46,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'data' => 'my',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 49
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$max_uv1',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 49,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 49,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '~',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 49,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'name' => 'BitNot',
                   'type' => Compiler::Lexer::TokenType::T_BitNot
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 49,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '0'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 49
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl',
                   'has_warnings' => 0,
                   'line' => 50,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'LocalVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'data' => '$max_uv2',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 50,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 50,
                   'kind' => Compiler::Lexer::Kind::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'sprintf',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 50,
                   'has_warnings' => 0,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 50,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '%u',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 50,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 50,
                   'data' => '$max_uv1',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '**',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 50,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Exp,
                   'name' => 'Exp'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'line' => 50,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '6',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 50,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 51
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$big_iv',
                   'line' => 51,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 51,
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'do',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 51,
                   'kind' => Compiler::Lexer::Kind::T_Do,
                   'has_warnings' => 0,
                   'name' => 'Do',
                   'type' => Compiler::Lexer::TokenType::T_Do
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 51
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'UseDecl',
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'data' => 'use',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 51,
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'integer',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 51,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'has_warnings' => 0,
                   'name' => 'UsedName',
                   'type' => Compiler::Lexer::TokenType::T_UsedName
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 51,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'line' => 51,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$max_uv1'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '*',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 51,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Mul,
                   'name' => 'Mul'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 51,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '16'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 51,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 51,
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 52,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$max_uv_less3',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 52,
                   'has_warnings' => 0,
                   'name' => 'LocalVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 52
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 52,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$max_uv1'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Sub,
                   'name' => 'Sub',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '-',
                   'line' => 52,
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'data' => '3',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 52
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'line' => 52,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'print',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 54
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '# max_uv1 = $max_uv1, max_uv2 = $max_uv2, big_iv = $big_iv\\n',
                   'line' => 54,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 54,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 55,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'print'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => '# max_uv_less3 = $max_uv_less3\\n',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 55
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 55,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'if',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 56,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'has_warnings' => 0,
                   'name' => 'IfStmt',
                   'type' => Compiler::Lexer::TokenType::T_IfStmt
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 56,
                   'has_warnings' => 0,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 56,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$max_uv1',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'StringNotEqual',
                   'type' => Compiler::Lexer::TokenType::T_StringNotEqual,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 56,
                   'data' => 'ne',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$max_uv2',
                   'line' => 56,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 56,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'or',
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'name' => 'AlphabetOr',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'line' => 56,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$big_iv',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Greater',
                   'type' => Compiler::Lexer::TokenType::T_Greater,
                   'data' => '>',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 56
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'line' => 56,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$max_uv1',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'AlphabetOr',
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 56,
                   'data' => 'or',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 56,
                   'data' => '$max_uv1',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_EqualEqual,
                   'name' => 'EqualEqual',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '==',
                   'line' => 56,
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 56,
                   'data' => '$max_uv_less3',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 56,
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 56,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'eval',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 57
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 57,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'RequireDecl',
                   'type' => Compiler::Lexer::TokenType::T_RequireDecl,
                   'data' => 'require',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 57
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RequiredName,
                   'name' => 'RequiredName',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'Config',
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'line' => 57
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 57,
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 57,
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 57
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 58,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 58,
                   'data' => '$message',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LocalVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 58
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 58,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'unsigned perl arithmetic is not sane',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 58,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$message',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 59
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 59,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'data' => '.=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'StringAddEqual',
                   'type' => Compiler::Lexer::TokenType::T_StringAddEqual,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 59,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => ' (common in 64-bit platforms)',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'name' => 'IfStmt',
                   'has_warnings' => 0,
                   'line' => 59,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'if'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 59,
                   'data' => '$Config',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'GlobalVar',
                   'type' => Compiler::Lexer::TokenType::T_GlobalVar,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_NamespaceResolver,
                   'name' => 'NamespaceResolver',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '::',
                   'line' => 59,
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 59,
                   'kind' => Compiler::Lexer::Kind::T_Namespace,
                   'data' => 'Config',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Namespace',
                   'type' => Compiler::Lexer::TokenType::T_Namespace,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 59,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 59,
                   'data' => 'd_quad',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 59,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 59,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'skip_all',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 60,
                   'has_warnings' => 1,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0,
                   'line' => 60,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$message',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 60,
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 60,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 60,
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}',
                   'line' => 61,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'IfStmt',
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'data' => 'if',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 62,
                   'kind' => Compiler::Lexer::Kind::T_Stmt
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'line' => 62,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$max_uv_less3',
                   'line' => 62,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'RegOK',
                   'type' => Compiler::Lexer::TokenType::T_RegOK,
                   'data' => '=~',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 62
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_RegReplacePrefix,
                   'line' => 62,
                   'data' => 'tr',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegAllReplace',
                   'type' => Compiler::Lexer::TokenType::T_RegAllReplace,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 62,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '/',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '0-9',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 62,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegReplaceFrom,
                   'name' => 'RegReplaceFrom'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 62,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '/',
                   'type' => Compiler::Lexer::TokenType::T_RegMiddleDelim,
                   'name' => 'RegMiddleDelim',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 62,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegReplaceTo,
                   'name' => 'RegReplaceTo'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '/',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 62,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_RegOpt,
                   'line' => 62,
                   'data' => 'c',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegOpt',
                   'type' => Compiler::Lexer::TokenType::T_RegOpt,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 62,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 62
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'skip_all',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 63,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 1,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 63,
                   'has_warnings' => 0,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => 'this perl stringifies large unsigned integers using E notation',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 63,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0,
                   'line' => 63,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 63,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 64,
                   'has_warnings' => 0,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'line' => 66,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 66,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$st_t',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LocalVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 66,
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'has_warnings' => 0,
                   'line' => 66,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '4'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Mul,
                   'name' => 'Mul',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 66,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '*'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 66,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '4',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 66,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'line' => 68,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$num',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 68
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 68,
                   'kind' => Compiler::Lexer::Kind::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 68,
                   'data' => '0',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 68,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$num',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 69,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 69,
                   'data' => '+=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'AddEqual',
                   'type' => Compiler::Lexer::TokenType::T_AddEqual,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '10',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 69,
                   'has_warnings' => 0,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Exp,
                   'name' => 'Exp',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 69,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '**'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'name' => 'SpecificValue',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$_',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 69,
                   'data' => '-',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Sub',
                   'type' => Compiler::Lexer::TokenType::T_Sub,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '4',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Exp',
                   'type' => Compiler::Lexer::TokenType::T_Exp,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 69,
                   'data' => '**',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 69,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$_',
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'name' => 'SpecificValue',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'ForStmt',
                   'type' => Compiler::Lexer::TokenType::T_ForStmt,
                   'data' => 'for',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 69,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '1'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Slice',
                   'type' => Compiler::Lexer::TokenType::T_Slice,
                   'data' => '..',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$max_chain',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$num',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 70,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 70,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '*=',
                   'type' => Compiler::Lexer::TokenType::T_MulEqual,
                   'name' => 'MulEqual',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 70,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$st_t',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'line' => 70,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'line' => 71,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$num'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 71,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '+=',
                   'type' => Compiler::Lexer::TokenType::T_AddEqual,
                   'name' => 'AddEqual',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'name' => 'SpecificValue',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 71,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$:'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Colon,
                   'name' => 'Colon',
                   'has_warnings' => 0,
                   'line' => 71,
                   'kind' => Compiler::Lexer::Kind::T_Colon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ':'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'additional_tests',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 71,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 1,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 71
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'plan',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 72,
                   'has_warnings' => 1,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 72,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 72,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'tests',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Arrow,
                   'name' => 'Arrow',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=>',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 72
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'line' => 72,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$num',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 72,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'line' => 72,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'data' => 'my',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 74
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 74,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$max_uv',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0,
                   'line' => 74,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BitNot',
                   'type' => Compiler::Lexer::TokenType::T_BitNot,
                   'has_warnings' => 0,
                   'line' => 74,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'data' => '~',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'data' => '0',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 74,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 74,
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'data' => 'my',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 75
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar',
                   'has_warnings' => 0,
                   'line' => 75,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$max_iv'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 75,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '='
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'data' => 'int',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 75
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 75,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 75,
                   'data' => '$max_uv',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Div',
                   'type' => Compiler::Lexer::TokenType::T_Div,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 75,
                   'data' => '/',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'data' => '2',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 75,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 75,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 75,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'LocalVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'data' => '$zero',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 76,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 76,
                   'kind' => Compiler::Lexer::Kind::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 76,
                   'data' => '0',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'line' => 78,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'LocalVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'data' => '$l_uv',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 78,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 78,
                   'has_warnings' => 0,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'has_warnings' => 0,
                   'line' => 78,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'length'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 78,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$max_uv'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 78,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 79
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'LocalVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'data' => '$l_iv',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 79,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 79,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 79,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'data' => 'length',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$max_iv',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 79,
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 79,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'data' => 'my',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 82,
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 82,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$larger_than_uv'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 82,
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'substr',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 82,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '97',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 82
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'x',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 82,
                   'has_warnings' => 0,
                   'name' => 'StringMul',
                   'type' => Compiler::Lexer::TokenType::T_StringMul
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 82,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '100',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 82,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '0',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 82,
                   'has_warnings' => 0,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 82,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$l_uv',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 82
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 82,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 83,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 83,
                   'data' => '$smaller_than_iv',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LocalVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 83,
                   'kind' => Compiler::Lexer::Kind::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'data' => 'substr',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 83
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 83,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '12'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'x',
                   'line' => 83,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_StringMul,
                   'name' => 'StringMul'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'has_warnings' => 0,
                   'line' => 83,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '100'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 83,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 83,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '0'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'line' => 83,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'line' => 83,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$l_iv'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 83,
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 84,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 84,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$yet_smaller_than_iv',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 84,
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'substr',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 84
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'has_warnings' => 0,
                   'line' => 84,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '97'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_StringMul,
                   'name' => 'StringMul',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 84,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'x'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '100',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 84,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 84,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 84,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '0',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'has_warnings' => 0,
                   'line' => 84,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 84,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$l_iv',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 84,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 84,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '-',
                   'type' => Compiler::Lexer::TokenType::T_Sub,
                   'name' => 'Sub',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 84,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '1',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0,
                   'line' => 84,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 84,
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 86,
                   'data' => 'my',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LocalArrayVar,
                   'name' => 'LocalArrayVar',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 86,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '@list'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 86,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 86
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '1',
                   'line' => 86,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 86,
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$yet_smaller_than_iv',
                   'line' => 86,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 86,
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 86,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$smaller_than_iv',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 86,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$max_iv',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 86,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 86,
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$max_iv',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 86,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '+',
                   'line' => 86,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Add,
                   'name' => 'Add'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '1',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 86,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 86,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$max_uv',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 87,
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'line' => 87,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$max_uv',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 87,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Add,
                   'name' => 'Add',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '+',
                   'line' => 87,
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 87,
                   'data' => '1',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'line' => 87,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 87,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'unshift',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 88,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 88,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '@list',
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar,
                   'name' => 'ArrayVar',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 88,
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 88
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 88,
                   'data' => 'reverse',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 88,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'map'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 88,
                   'data' => '-',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Sub',
                   'type' => Compiler::Lexer::TokenType::T_Sub,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'name' => 'SpecificValue',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$_',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 88
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 88,
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar,
                   'name' => 'ArrayVar',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 88,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '@list'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 88,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 88,
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '0',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 88,
                   'has_warnings' => 0,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 88,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 89,
                   'data' => '@list',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'ArrayVar',
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 89,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 89,
                   'data' => 'map',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 89,
                   'data' => '$_',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 89,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '@list',
                   'line' => 89,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar,
                   'name' => 'ArrayVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'line' => 89,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'note',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 91,
                   'has_warnings' => 1,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'line' => 91,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 91,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '@list',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 91,
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 91,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 98,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'data' => 'my',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$max_uv_pp',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 98,
                   'has_warnings' => 0,
                   'name' => 'LocalVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 98,
                   'has_warnings' => 0,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$max_uv',
                   'line' => 98,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 98,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'line' => 98,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$max_uv_pp'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '++',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 98,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Inc,
                   'name' => 'Inc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'line' => 98,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'line' => 99,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LocalVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'has_warnings' => 0,
                   'line' => 99,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$max_uv_p1',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'has_warnings' => 0,
                   'line' => 99,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '='
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$max_uv',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 99
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 99,
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$max_uv_p1',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 99,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '+=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 99,
                   'has_warnings' => 0,
                   'name' => 'AddEqual',
                   'type' => Compiler::Lexer::TokenType::T_AddEqual
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'data' => '0',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 99
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 99,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$max_uv_p1',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 99,
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Inc,
                   'name' => 'Inc',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 99,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '++'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 99,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 105,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$temp',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 105,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'name' => 'LocalVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 105,
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'line' => 105,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$max_uv_p1'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 105,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 106,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LocalVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 106,
                   'data' => '$max_uv_p1_as_iv',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'line' => 106,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'line' => 107,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 107,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'use',
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'name' => 'UseDecl',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'UsedName',
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'has_warnings' => 0,
                   'line' => 107,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'data' => 'integer',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 107,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$max_uv_p1_as_iv',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 107,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 107,
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'line' => 107,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '0',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Add',
                   'type' => Compiler::Lexer::TokenType::T_Add,
                   'data' => '+',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 107
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'sprintf',
                   'line' => 107,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => '%s',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 107
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 107,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'line' => 107,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$temp'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 107,
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 108
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 108,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$max_uv_p1_as_uv',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 108
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 108,
                   'data' => '0',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_BitOr,
                   'name' => 'BitOr',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 108,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '|'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'sprintf',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 108,
                   'has_warnings' => 0,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 108,
                   'data' => '%s',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 108,
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 108,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$temp'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 108,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 110,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 110,
                   'data' => '@opnames',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LocalArrayVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalArrayVar,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 110,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'data' => 'split',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 110
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'data' => '/',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 110
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'name' => 'RegExp',
                   'has_warnings' => 0,
                   'line' => 110,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ''
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 110,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '/',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 110,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-+UINPuinp',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 110,
                   'has_warnings' => 0,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'line' => 110,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 114,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'LocalVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'data' => '$test',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 114
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 114,
                   'has_warnings' => 0,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '1',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 114,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 114,
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 115,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LocalVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'has_warnings' => 0,
                   'line' => 115,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$nok',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 115,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ForStmt,
                   'name' => 'ForStmt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'for',
                   'line' => 116,
                   'kind' => Compiler::Lexer::Kind::T_Stmt
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'my',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 116,
                   'has_warnings' => 0,
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$num_chain',
                   'line' => 116,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 116,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'line' => 116,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '1',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Slice,
                   'name' => 'Slice',
                   'has_warnings' => 0,
                   'line' => 116,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '..'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$max_chain',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 116,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 116,
                   'has_warnings' => 0,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'line' => 116,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'data' => 'my',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 117
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 117,
                   'data' => '@ops',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LocalArrayVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalArrayVar,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 117
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'map',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 117,
                   'has_warnings' => 0,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 117,
                   'data' => '[',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'split',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 117,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 117,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '/',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'name' => 'RegExp',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '',
                   'line' => 117,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 117,
                   'data' => '/',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'name' => 'RightBracket',
                   'has_warnings' => 0,
                   'line' => 117,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ']'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 117,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'grep',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 117,
                   'has_warnings' => 0,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 117,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '/'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'name' => 'RegExp',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '[4-9]',
                   'line' => 117,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '/',
                   'line' => 117,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 117
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'map',
                   'line' => 118,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 118,
                   'has_warnings' => 0,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'sprintf',
                   'line' => 118,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 118,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '%0${num_chain}d'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 118,
                   'kind' => Compiler::Lexer::Kind::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 118,
                   'data' => '$_',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SpecificValue',
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0,
                   'line' => 118,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'data' => '0',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 118
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Slice',
                   'type' => Compiler::Lexer::TokenType::T_Slice,
                   'data' => '..',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 118
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '10',
                   'line' => 118,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Exp,
                   'name' => 'Exp',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '**',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 118
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$num_chain',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 118
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Sub',
                   'type' => Compiler::Lexer::TokenType::T_Sub,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 118,
                   'data' => '-',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '1',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 118,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 118,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'for',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'line' => 123,
                   'has_warnings' => 0,
                   'name' => 'ForStmt',
                   'type' => Compiler::Lexer::TokenType::T_ForStmt
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'my',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 123,
                   'has_warnings' => 0,
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$op',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 123
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 123,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar,
                   'name' => 'ArrayVar',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 123,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '@ops'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 123,
                   'has_warnings' => 0,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 123,
                   'has_warnings' => 0,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'ForStmt',
                   'type' => Compiler::Lexer::TokenType::T_ForStmt,
                   'data' => 'for',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'line' => 124
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'line' => 124,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$first',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 124,
                   'has_warnings' => 0,
                   'name' => 'LocalVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 124
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'data' => '2',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 124,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 124,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'data' => '..',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Slice',
                   'type' => Compiler::Lexer::TokenType::T_Slice,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '5',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 124,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 124,
                   'has_warnings' => 0,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'has_warnings' => 0,
                   'line' => 124,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'for',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 125,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'has_warnings' => 0,
                   'name' => 'ForStmt',
                   'type' => Compiler::Lexer::TokenType::T_ForStmt
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 125,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 125,
                   'data' => '$last',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LocalVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 125,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 125,
                   'data' => '2',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Slice',
                   'type' => Compiler::Lexer::TokenType::T_Slice,
                   'data' => '..',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 125
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '5',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 125,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 125
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 125,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$nok',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 126,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 126,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'has_warnings' => 0,
                   'line' => 126,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '0'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'line' => 126,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 127,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 127,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '@otherops',
                   'type' => Compiler::Lexer::TokenType::T_LocalArrayVar,
                   'name' => 'LocalArrayVar',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 127,
                   'has_warnings' => 0,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'line' => 127,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'data' => 'grep',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$_',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 127,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'name' => 'SpecificValue'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 127,
                   'data' => '<=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LessEqual',
                   'type' => Compiler::Lexer::TokenType::T_LessEqual,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 127,
                   'data' => '3',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 127,
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ShortArrayDereference,
                   'name' => 'ShortArrayDereference',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '@$',
                   'kind' => Compiler::Lexer::Kind::T_Modifier,
                   'line' => 127
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 127,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'op',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 127,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'my',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 128,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '@curops',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 128,
                   'has_warnings' => 0,
                   'name' => 'LocalArrayVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalArrayVar
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=',
                   'line' => 128,
                   'kind' => Compiler::Lexer::Kind::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 128,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$op',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 128
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 128,
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '\\',
                   'line' => 128,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Ref,
                   'name' => 'Ref'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 128,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '@otherops',
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar,
                   'name' => 'ArrayVar',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 128,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'line' => 128,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'ForStmt',
                   'type' => Compiler::Lexer::TokenType::T_ForStmt,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'line' => 130,
                   'data' => 'for',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'line' => 130,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LocalVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 130,
                   'data' => '$num',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 130,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 130,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '@list',
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar,
                   'name' => 'ArrayVar',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 130,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 130
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 131,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$inpt',
                   'line' => 131,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 131
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 132,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LocalArrayVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalArrayVar,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 132,
                   'data' => '@ans',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 132,
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'for',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'line' => 134,
                   'has_warnings' => 0,
                   'name' => 'ForStmt',
                   'type' => Compiler::Lexer::TokenType::T_ForStmt
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 134,
                   'data' => 'my',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$short',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 134,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 134,
                   'has_warnings' => 0,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 134,
                   'data' => '0',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 134,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '1',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 134
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 134,
                   'has_warnings' => 0,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 134,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$inpt',
                   'line' => 137,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 137,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 137,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$num',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'line' => 137,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'line' => 138,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$inpt'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'has_warnings' => 0,
                   'line' => 138,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '='
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 138,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$inpt'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'line' => 138,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'name' => 'IfStmt',
                   'has_warnings' => 0,
                   'line' => 139,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'if'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 139,
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$first',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 139
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'EqualEqual',
                   'type' => Compiler::Lexer::TokenType::T_EqualEqual,
                   'has_warnings' => 0,
                   'line' => 139,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'data' => '==',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '2',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 139
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 139,
                   'has_warnings' => 0,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 139,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '{',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$inpt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 140
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 140,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'has_warnings' => 0,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$max_uv',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 140,
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BitAnd',
                   'type' => Compiler::Lexer::TokenType::T_BitAnd,
                   'has_warnings' => 0,
                   'line' => 140,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'data' => '&',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$inpt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 140,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 140,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}',
                   'line' => 141,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ElsifStmt,
                   'name' => 'ElsifStmt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'elsif',
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'line' => 141
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 141
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 141,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$first',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 141,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '==',
                   'type' => Compiler::Lexer::TokenType::T_EqualEqual,
                   'name' => 'EqualEqual',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 141,
                   'data' => '3',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 141,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 141,
                   'data' => '{',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'use',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 142,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'name' => 'UseDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'UsedName',
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'data' => 'integer',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 142,
                   'kind' => Compiler::Lexer::Kind::T_Module
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 142,
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 142,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$inpt',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_AddEqual,
                   'name' => 'AddEqual',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 142,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '+='
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$zero',
                   'line' => 142,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 142,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 143,
                   'has_warnings' => 0,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'line' => 143,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'elsif',
                   'type' => Compiler::Lexer::TokenType::T_ElsifStmt,
                   'name' => 'ElsifStmt',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'line' => 143,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 143,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$first',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '==',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 143,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_EqualEqual,
                   'name' => 'EqualEqual'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'line' => 143,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '4',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 143,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 143,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '{',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$inpt',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 144
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '+=',
                   'line' => 144,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_AddEqual,
                   'name' => 'AddEqual'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 144,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$zero'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 144,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 145,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'line' => 145,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'else',
                   'type' => Compiler::Lexer::TokenType::T_ElseStmt,
                   'name' => 'ElseStmt',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'has_warnings' => 0,
                   'line' => 145,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 146,
                   'data' => '$inpt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 146
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 146,
                   'data' => '$inpt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 146,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 147,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'for',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'line' => 155,
                   'has_warnings' => 0,
                   'name' => 'ForStmt',
                   'type' => Compiler::Lexer::TokenType::T_ForStmt
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'my',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 155,
                   'has_warnings' => 0,
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LocalVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 155,
                   'data' => '$curop',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 155,
                   'has_warnings' => 0,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Modifier,
                   'line' => 155,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '@{',
                   'type' => Compiler::Lexer::TokenType::T_ArrayDereference,
                   'name' => 'ArrayDereference',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$curops',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 155,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_GlobalVar,
                   'name' => 'GlobalVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 155,
                   'data' => '[',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 155,
                   'data' => '$short',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'data' => ']',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 155,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 155,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 155,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 155,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '{',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'if',
                   'line' => 156,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'name' => 'IfStmt'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 156,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$curop',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 156
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Less,
                   'name' => 'Less',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '<',
                   'line' => 156,
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '5',
                   'line' => 156,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 156,
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 156
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'name' => 'IfStmt',
                   'has_warnings' => 0,
                   'line' => 157,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'if'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 157,
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$curop',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 157,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Less,
                   'name' => 'Less',
                   'has_warnings' => 0,
                   'line' => 157,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '<'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 157,
                   'data' => '3',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 157,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 157,
                   'data' => '{',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'name' => 'IfStmt',
                   'has_warnings' => 0,
                   'line' => 158,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'if'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0,
                   'line' => 158,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$curop',
                   'line' => 158,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'EqualEqual',
                   'type' => Compiler::Lexer::TokenType::T_EqualEqual,
                   'data' => '==',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 158,
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '0',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 158
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 158,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'line' => 158,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 159,
                   'data' => '--',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Dec',
                   'type' => Compiler::Lexer::TokenType::T_Dec,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 159,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$inpt'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 159
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 160,
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'elsif',
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'line' => 160,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ElsifStmt,
                   'name' => 'ElsifStmt'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'line' => 160,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$curop',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 160
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'EqualEqual',
                   'type' => Compiler::Lexer::TokenType::T_EqualEqual,
                   'data' => '==',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 160,
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 160,
                   'data' => '1',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'line' => 160,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'has_warnings' => 0,
                   'line' => 160,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '{',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '++',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 161,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Inc,
                   'name' => 'Inc'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$inpt',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 161,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 161,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 162,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'line' => 162,
                   'data' => 'else',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'ElseStmt',
                   'type' => Compiler::Lexer::TokenType::T_ElseStmt,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'line' => 162,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 163,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$inpt'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=',
                   'line' => 163,
                   'kind' => Compiler::Lexer::Kind::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 163,
                   'data' => '$max_uv',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '&',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 163,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'name' => 'BitAnd',
                   'type' => Compiler::Lexer::TokenType::T_BitAnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$inpt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 163
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 163,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 164,
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 165,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'ElsifStmt',
                   'type' => Compiler::Lexer::TokenType::T_ElsifStmt,
                   'data' => 'elsif',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 165,
                   'kind' => Compiler::Lexer::Kind::T_Stmt
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 165,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 165,
                   'data' => '$curop',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 165,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '==',
                   'type' => Compiler::Lexer::TokenType::T_EqualEqual,
                   'name' => 'EqualEqual',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 165,
                   'data' => '3',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 165,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 165,
                   'has_warnings' => 0,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'UseDecl',
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 166,
                   'data' => 'use',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'name' => 'UsedName',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'line' => 166,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'integer'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 166,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 166,
                   'data' => '$inpt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 166,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '+=',
                   'type' => Compiler::Lexer::TokenType::T_AddEqual,
                   'name' => 'AddEqual',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 166,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$zero'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 166,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 167,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_ElseStmt,
                   'name' => 'ElseStmt',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'line' => 167,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'else'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 167
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$inpt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 168,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'AddEqual',
                   'type' => Compiler::Lexer::TokenType::T_AddEqual,
                   'has_warnings' => 0,
                   'line' => 168,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'data' => '+=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 168,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$zero',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 168
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0,
                   'line' => 169,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0,
                   'line' => 170,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'ElsifStmt',
                   'type' => Compiler::Lexer::TokenType::T_ElsifStmt,
                   'data' => 'elsif',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'line' => 170
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 170,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 170,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$curop',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Less',
                   'type' => Compiler::Lexer::TokenType::T_Less,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 170,
                   'data' => '<',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'data' => '8',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 170
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 170,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 170,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'IfStmt',
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'has_warnings' => 0,
                   'line' => 171,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'data' => 'if',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 171,
                   'has_warnings' => 0,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 171,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$curop',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'EqualEqual',
                   'type' => Compiler::Lexer::TokenType::T_EqualEqual,
                   'has_warnings' => 0,
                   'line' => 171,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'data' => '==',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '5',
                   'line' => 171,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0,
                   'line' => 171,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 171,
                   'data' => '{',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 172,
                   'data' => '$inpt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 172,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 172,
                   'data' => '$inpt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 172,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 173,
                   'has_warnings' => 0,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ElsifStmt,
                   'name' => 'ElsifStmt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'elsif',
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'line' => 173
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 173
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'line' => 173,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$curop'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 173,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '==',
                   'type' => Compiler::Lexer::TokenType::T_EqualEqual,
                   'name' => 'EqualEqual',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'line' => 173,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '6',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 173
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'has_warnings' => 0,
                   'line' => 173,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 174,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$dummy',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 174,
                   'has_warnings' => 0,
                   'name' => 'LocalVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 174,
                   'has_warnings' => 0,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$max_uv',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 174,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 174,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '&',
                   'type' => Compiler::Lexer::TokenType::T_BitAnd,
                   'name' => 'BitAnd',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$inpt',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 174
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 174,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 175,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 175,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'else',
                   'type' => Compiler::Lexer::TokenType::T_ElseStmt,
                   'name' => 'ElseStmt',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 175,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'name' => 'UseDecl',
                   'has_warnings' => 0,
                   'line' => 176,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'use'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'integer',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'line' => 176,
                   'has_warnings' => 0,
                   'name' => 'UsedName',
                   'type' => Compiler::Lexer::TokenType::T_UsedName
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 176,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'data' => 'my',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 176
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 176,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$dummy'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'has_warnings' => 0,
                   'line' => 176,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '='
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 176,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$inpt'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Add,
                   'name' => 'Add',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 176,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '+'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 176,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$zero'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 176
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 177,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 178,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'elsif',
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'line' => 178,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ElsifStmt,
                   'name' => 'ElsifStmt'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 178,
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$curop',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 178
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '==',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 178,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_EqualEqual,
                   'name' => 'EqualEqual'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 178,
                   'data' => '8',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 178,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 178,
                   'has_warnings' => 0,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'data' => 'my',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 179,
                   'kind' => Compiler::Lexer::Kind::T_Decl
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$dummy',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 179,
                   'has_warnings' => 0,
                   'name' => 'LocalVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 179
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$inpt',
                   'line' => 179,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '+',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 179,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'name' => 'Add',
                   'type' => Compiler::Lexer::TokenType::T_Add
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$zero',
                   'line' => 179,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 179,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}',
                   'line' => 180,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'ElseStmt',
                   'type' => Compiler::Lexer::TokenType::T_ElseStmt,
                   'has_warnings' => 0,
                   'line' => 180,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'data' => 'else',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 180,
                   'data' => '{',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'data' => 'my',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 181
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 181,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$dummy',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 181
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 181,
                   'data' => '$inpt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '.',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 181,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'name' => 'StringAdd',
                   'type' => Compiler::Lexer::TokenType::T_StringAdd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 181,
                   'data' => '',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 181,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 182
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 183,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'if',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 185,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'has_warnings' => 0,
                   'name' => 'IfStmt',
                   'type' => Compiler::Lexer::TokenType::T_IfStmt
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'line' => 185,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$last',
                   'line' => 185,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'EqualEqual',
                   'type' => Compiler::Lexer::TokenType::T_EqualEqual,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 185,
                   'data' => '==',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 185,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '2',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 185,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 185,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 186,
                   'data' => '$inpt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 186,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 186,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'sprintf'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '%u',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 186,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 186,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$inpt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 186
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 186,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 187,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 187,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'elsif',
                   'type' => Compiler::Lexer::TokenType::T_ElsifStmt,
                   'name' => 'ElsifStmt',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'line' => 187,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 187,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$last'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_EqualEqual,
                   'name' => 'EqualEqual',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 187,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=='
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 187,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '3',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 187,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 187,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'line' => 188,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$inpt'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 188,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 188,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'data' => 'sprintf',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 188,
                   'data' => '%d',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'line' => 188,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 188,
                   'data' => '$inpt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'line' => 188,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 189,
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_ElsifStmt,
                   'name' => 'ElsifStmt',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'line' => 189,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'elsif'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'line' => 189,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$last',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 189,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '==',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 189,
                   'has_warnings' => 0,
                   'name' => 'EqualEqual',
                   'type' => Compiler::Lexer::TokenType::T_EqualEqual
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 189,
                   'data' => '4',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 189,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 189,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$inpt',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 190
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 190,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 190,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'sprintf',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 190,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '%g'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 190,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 190,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$inpt',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 190,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 191,
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ElseStmt,
                   'name' => 'ElseStmt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'else',
                   'line' => 191,
                   'kind' => Compiler::Lexer::Kind::T_Stmt
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 191
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 192,
                   'data' => '$inpt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=',
                   'line' => 192,
                   'kind' => Compiler::Lexer::Kind::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => '$inpt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 192,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 192,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 193
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'data' => 'push',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 194,
                   'kind' => Compiler::Lexer::Kind::T_Function
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar,
                   'name' => 'ArrayVar',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '@ans',
                   'line' => 194,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 194
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$inpt',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 194,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'line' => 194,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 195
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'if',
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'line' => 196,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'name' => 'IfStmt'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 196,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$ans',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 196,
                   'has_warnings' => 0,
                   'name' => 'GlobalVar',
                   'type' => Compiler::Lexer::TokenType::T_GlobalVar
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'has_warnings' => 0,
                   'line' => 196,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '[',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 196,
                   'data' => '0',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'name' => 'RightBracket',
                   'has_warnings' => 0,
                   'line' => 196,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ']'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_StringNotEqual,
                   'name' => 'StringNotEqual',
                   'has_warnings' => 0,
                   'line' => 196,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'ne'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$ans',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 196,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'has_warnings' => 0,
                   'line' => 196,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '[',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'data' => '1',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 196
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ']',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 196,
                   'has_warnings' => 0,
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 196,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 196,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'data' => 'my',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 197
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 197,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$diag',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 197,
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 197,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '\'$ans[0]\' ne \'$ans[1]\',\\t$num\\t=> @opnames[$first,@{$curops[0]},$last] vs @opnames[$first,@{$curops[1]},$last]'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'line' => 197,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 198,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$excuse',
                   'line' => 198,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 198
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 200,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'if',
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'name' => 'IfStmt',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 200,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 200,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 200
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 200,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$ans',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'data' => '[',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 200,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 200,
                   'data' => '0',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ']',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 200,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'eq',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 200,
                   'has_warnings' => 0,
                   'name' => 'StringEqual',
                   'type' => Compiler::Lexer::TokenType::T_StringEqual
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 200,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$max_uv_pp',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 200
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_AlphabetAnd,
                   'name' => 'AlphabetAnd',
                   'has_warnings' => 0,
                   'line' => 200,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'and'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 200,
                   'has_warnings' => 0,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 200,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$ans',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'data' => '[',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 200
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '1',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 200
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'name' => 'RightBracket',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ']',
                   'line' => 200,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'eq',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 200,
                   'has_warnings' => 0,
                   'name' => 'StringEqual',
                   'type' => Compiler::Lexer::TokenType::T_StringEqual
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'data' => '$max_uv_p1',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 200
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 200,
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 200,
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'or',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 201,
                   'has_warnings' => 0,
                   'name' => 'AlphabetOr',
                   'type' => Compiler::Lexer::TokenType::T_AlphabetOr
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 201,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 201
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$ans',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 201,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 201,
                   'data' => '[',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 201,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '1',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 201,
                   'data' => ']',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'eq',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 201,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'name' => 'StringEqual'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 201,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$max_uv_pp',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 201,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'and',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 201,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetAnd,
                   'name' => 'AlphabetAnd'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 201,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$ans',
                   'line' => 201,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'has_warnings' => 0,
                   'line' => 201,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '[',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'line' => 201,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '0',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ']',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 201,
                   'has_warnings' => 0,
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'name' => 'StringEqual',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'eq',
                   'line' => 201,
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'line' => 201,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$max_uv_p1'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 201,
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 201
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 201,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 201
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$excuse',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 204
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0,
                   'line' => 204,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'ok, as string ++ of max_uv is \\"$max_uv_pp\\", numeric is $max_uv_p1',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 204,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'line' => 204,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 205,
                   'has_warnings' => 0,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 205,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'elsif',
                   'type' => Compiler::Lexer::TokenType::T_ElsifStmt,
                   'name' => 'ElsifStmt',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 205,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 205,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$opnames',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'GlobalVar',
                   'type' => Compiler::Lexer::TokenType::T_GlobalVar,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '[',
                   'line' => 205,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$last',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 205,
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ']',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 205,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'name' => 'RightBracket'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 205,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'eq',
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'name' => 'StringEqual',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 205,
                   'data' => 'I',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 205,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'and',
                   'type' => Compiler::Lexer::TokenType::T_AlphabetAnd,
                   'name' => 'AlphabetAnd',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$ans',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 205
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '[',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 205,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 205,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '1',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'name' => 'RightBracket',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ']',
                   'line' => 205,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'name' => 'StringEqual',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'eq',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 205
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'line' => 205,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '-1',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 206,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'and',
                   'type' => Compiler::Lexer::TokenType::T_AlphabetAnd,
                   'name' => 'AlphabetAnd',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'line' => 206,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$ans',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket',
                   'has_warnings' => 0,
                   'line' => 206,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '['
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '0',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 206,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'data' => ']',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 206
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'StringEqual',
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'has_warnings' => 0,
                   'line' => 206,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'data' => 'eq',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$max_uv_p1_as_iv',
                   'line' => 206,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 206
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 206,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '{',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 218,
                   'data' => '$excuse',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=',
                   'line' => 218,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'data' => 'ok, \\"$max_uv_p1\\" correctly converts to IV \\"$max_uv_p1_as_iv\\"',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 218
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 218,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 219,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'ElsifStmt',
                   'type' => Compiler::Lexer::TokenType::T_ElsifStmt,
                   'data' => 'elsif',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 219,
                   'kind' => Compiler::Lexer::Kind::T_Stmt
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 219,
                   'has_warnings' => 0,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 219,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$opnames',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'has_warnings' => 0,
                   'line' => 219,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '[',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$last',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 219
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'name' => 'RightBracket',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 219,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ']'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 219,
                   'data' => 'eq',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'StringEqual',
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'U',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 219,
                   'has_warnings' => 0,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'and',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 219,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetAnd,
                   'name' => 'AlphabetAnd'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 219,
                   'data' => '$ans',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 219,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '['
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'data' => '1',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 219
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'name' => 'RightBracket',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 219,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ']'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'name' => 'StringEqual',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'eq',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 219
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BitNot',
                   'type' => Compiler::Lexer::TokenType::T_BitNot,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 219,
                   'data' => '~',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 219,
                   'data' => '0',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 220,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'and',
                   'type' => Compiler::Lexer::TokenType::T_AlphabetAnd,
                   'name' => 'AlphabetAnd',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 220,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$ans',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'data' => '[',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 220
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 220,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '0',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 220,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ']',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'name' => 'RightBracket',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'name' => 'StringEqual',
                   'has_warnings' => 0,
                   'line' => 220,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'eq'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$max_uv_p1_as_uv',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 220,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 220,
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'line' => 220,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'line' => 222,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$excuse'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 222,
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'ok, \\"$max_uv_p1\\" correctly converts to UV \\"$max_uv_p1_as_uv\\"',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 222,
                   'has_warnings' => 0,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'line' => 222,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 223,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'ElsifStmt',
                   'type' => Compiler::Lexer::TokenType::T_ElsifStmt,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'line' => 223,
                   'data' => 'elsif',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0,
                   'line' => 223,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'grep',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 223
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 223,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'defined',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 223
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'SpecificValue',
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'data' => '$_',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 223,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 223,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '&&',
                   'type' => Compiler::Lexer::TokenType::T_And,
                   'name' => 'And',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '/',
                   'line' => 223,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '^N$',
                   'line' => 223,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'name' => 'RegExp'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 223,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '/'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 223,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ArrayVar,
                   'name' => 'ArrayVar',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '@opnames',
                   'line' => 223,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 223,
                   'data' => '[',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '@{',
                   'kind' => Compiler::Lexer::Kind::T_Modifier,
                   'line' => 223,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_ArrayDereference,
                   'name' => 'ArrayDereference'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$curops',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 223,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '[',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 223,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 223,
                   'data' => '0',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'has_warnings' => 0,
                   'line' => 223,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => ']',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 223,
                   'has_warnings' => 0,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ']',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 223,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'and',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 224,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_AlphabetAnd,
                   'name' => 'AlphabetAnd'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 224,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$ans',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '[',
                   'line' => 224,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 224,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '0'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'name' => 'RightBracket',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ']',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 224
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 224,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'data' => '==',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'EqualEqual',
                   'type' => Compiler::Lexer::TokenType::T_EqualEqual,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$ans',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 224,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '[',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 224,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'has_warnings' => 0,
                   'line' => 224,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '1'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'name' => 'RightBracket',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 224,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ']'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 224,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'data' => 'and',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'AlphabetAnd',
                   'type' => Compiler::Lexer::TokenType::T_AlphabetAnd,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 224,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$ans'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '[',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 224,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 224,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '0',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBracket',
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'has_warnings' => 0,
                   'line' => 224,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => ']',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'LessEqual',
                   'type' => Compiler::Lexer::TokenType::T_LessEqual,
                   'data' => '<=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 224
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_BitNot,
                   'name' => 'BitNot',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 224,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '~'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'line' => 224,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '0',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 235,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'and',
                   'type' => Compiler::Lexer::TokenType::T_AlphabetAnd,
                   'name' => 'AlphabetAnd',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 235,
                   'data' => '$ans',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 235,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '[',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket,
                   'name' => 'LeftBracket',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '0',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 235
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'name' => 'RightBracket',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ']',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 235
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_NotEqual,
                   'name' => 'NotEqual',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '!=',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 235
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'data' => '/',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 235
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'name' => 'RegExp',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 235,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '^-?\\d+$'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 235,
                   'data' => '/',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'AlphabetAnd',
                   'type' => Compiler::Lexer::TokenType::T_AlphabetAnd,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 235,
                   'data' => 'and',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$ans',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 235,
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '[',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 235,
                   'has_warnings' => 0,
                   'name' => 'LeftBracket',
                   'type' => Compiler::Lexer::TokenType::T_LeftBracket
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '1',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 235
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBracket,
                   'name' => 'RightBracket',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ']',
                   'line' => 235,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '!~',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 235,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegNot,
                   'name' => 'RegNot'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '/',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 235,
                   'has_warnings' => 0,
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 235,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '^-?\\d+$',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegExp',
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '/',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 235,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 235,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 235
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'line' => 236,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$excuse',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=',
                   'line' => 236,
                   'kind' => Compiler::Lexer::Kind::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 236,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'ok, numerically equal - notation changed due to adding zero',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 236
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0,
                   'line' => 237,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'ElseStmt',
                   'type' => Compiler::Lexer::TokenType::T_ElseStmt,
                   'data' => 'else',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'line' => 237
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 237
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 238,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$nok',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 238,
                   'data' => '++',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Inc',
                   'type' => Compiler::Lexer::TokenType::T_Inc,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 238,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 239,
                   'data' => 'diag',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0,
                   'line' => 239,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$diag',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 239,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'line' => 239,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'line' => 239,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 240,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'name' => 'IfStmt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'if',
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'line' => 241
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0,
                   'line' => 241,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$excuse',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 241,
                   'has_warnings' => 0,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 241,
                   'has_warnings' => 0,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 241
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 242,
                   'data' => 'note',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 242,
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$diag',
                   'line' => 242,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 242
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'line' => 242,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 243,
                   'data' => 'note',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 243,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 243,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$excuse',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 243
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 243,
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 244,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0,
                   'line' => 245,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 246,
                   'has_warnings' => 0,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 247,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'ok',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 247,
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$nok',
                   'line' => 247,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 247,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '==',
                   'type' => Compiler::Lexer::TokenType::T_EqualEqual,
                   'name' => 'EqualEqual',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 247,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '0',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Int',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 247
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'line' => 247,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 248
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 249
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 250,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 251,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'ModWord',
                   'type' => Compiler::Lexer::TokenType::T_ModWord,
                   'data' => 'BEGIN',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_ModWord,
                   'line' => 254
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'name' => 'LeftBrace',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 254
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 254,
                   'data' => '$:',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SpecificValue',
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Colon',
                   'type' => Compiler::Lexer::TokenType::T_Colon,
                   'data' => ':',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Colon,
                   'line' => 254
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 254,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'additional_tests'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 254,
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '4',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 254,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 254,
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 256,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'ok',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 256,
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Double,
                   'name' => 'Double',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 256,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '-0.0'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 256,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'eq',
                   'type' => Compiler::Lexer::TokenType::T_StringEqual,
                   'name' => 'StringEqual',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '0',
                   'line' => 256,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 256
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 256,
                   'data' => 'negative zero stringifies as 0',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 256,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'line' => 256,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 1,
                   'line' => 257,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'ok'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 257,
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Not',
                   'type' => Compiler::Lexer::TokenType::T_Not,
                   'data' => '!',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 257,
                   'kind' => Compiler::Lexer::Kind::T_SingleTerm
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '-0.0',
                   'line' => 257,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Double,
                   'name' => 'Double'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 257,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 257,
                   'data' => 'neg zero is boolean false',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'line' => 257,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 257,
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'VarDecl',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'data' => 'my',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 258
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 258,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$nz',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'name' => 'LocalVar',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'name' => 'Assign',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'line' => 258
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Double,
                   'name' => 'Double',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '-0.0',
                   'line' => 258,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 258,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'LeftBrace',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'data' => '{',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 259,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'my',
                   'line' => 259,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$dummy',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 259,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'name' => 'LocalVar',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 259,
                   'kind' => Compiler::Lexer::Kind::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'name' => 'String',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 259,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$nz'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 259,
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 259,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 260,
                   'data' => 'ok',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 260,
                   'data' => '(',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Not,
                   'name' => 'Not',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_SingleTerm,
                   'line' => 260,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '!'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 260,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$nz'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 260
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'name' => 'RawString',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'data' => 'previously stringified -0.0 is boolean false',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 260,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 260,
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'line' => 260,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 261,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$nz'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 261,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'data' => '=',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Assign',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Double',
                   'type' => Compiler::Lexer::TokenType::T_Double,
                   'has_warnings' => 0,
                   'line' => 261,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '-0.0',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 261,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 262,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'is'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 262,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'data' => 'sprintf',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'BuiltinFunc',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0,
                   'line' => 262,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 262,
                   'data' => '%+.f',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 262,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '-',
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 262,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Sub,
                   'name' => 'Sub'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Sub,
                   'name' => 'Sub',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '-',
                   'line' => 262,
                   'kind' => Compiler::Lexer::Kind::T_Operator
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Var',
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 262,
                   'data' => '$nz',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 262,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 262,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 262,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'sprintf',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 262,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 262,
                   'data' => '%+.f',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 262,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 262,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '-',
                   'type' => Compiler::Lexer::TokenType::T_Sub,
                   'name' => 'Sub',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'line' => 262,
                   'data' => '-',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Sub',
                   'type' => Compiler::Lexer::TokenType::T_Sub,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Var,
                   'name' => 'Var',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 262,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$nz'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'line' => 262,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'line' => 262,
                   'data' => ',',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'String',
                   'type' => Compiler::Lexer::TokenType::T_String,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 263,
                   'data' => 'negation does not coerce negative zeroes',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 263,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' )
        ]
, 'Compiler::Lexer::tokenize');
};

subtest 'get_groups_by_syntax_level' => sub {
    my $lexer = Compiler::Lexer->new('');
    my $tokens = $lexer->tokenize($script);
    my $stmts = $lexer->get_groups_by_syntax_level($tokens, Compiler::Lexer::SyntaxType::T_Stmt);
    is_deeply($stmts, [
          {
            'token_num' => 6,
            'block_id' => 1,
            'has_warnings' => 0,
            'start_line' => 39,
            'src' => ' chdir \'t\' if -d \'t\' ;',
            'indent' => 1,
            'end_line' => 39
          },
          {
            'src' => ' @INC = \'../lib\' ;',
            'start_line' => 40,
            'end_line' => 40,
            'indent' => 1,
            'block_id' => 1,
            'token_num' => 4,
            'has_warnings' => 0
          },
          {
            'token_num' => 3,
            'block_id' => 1,
            'has_warnings' => 0,
            'start_line' => 41,
            'src' => ' require \'./test.pl\' ;',
            'indent' => 1,
            'end_line' => 41
          },
          {
            'end_line' => 44,
            'indent' => 0,
            'src' => ' use strict ;',
            'start_line' => 44,
            'has_warnings' => 0,
            'block_id' => 0,
            'token_num' => 3
          },
          {
            'token_num' => 10,
            'block_id' => 0,
            'has_warnings' => 1,
            'start_line' => 46,
            'src' => ' my $max_chain = $ENV { PERL_TEST_NUMCONVERTS } || 2 ;',
            'indent' => 0,
            'end_line' => 46
          },
          {
            'end_line' => 49,
            'indent' => 0,
            'src' => ' my $max_uv1 = ~ 0 ;',
            'start_line' => 49,
            'has_warnings' => 0,
            'block_id' => 0,
            'token_num' => 6
          },
          {
            'start_line' => 50,
            'src' => ' my $max_uv2 = sprintf "%u" , $max_uv1 ** 6 ;',
            'indent' => 0,
            'end_line' => 50,
            'token_num' => 10,
            'block_id' => 0,
            'has_warnings' => 1
          },
          {
            'has_warnings' => 1,
            'token_num' => 13,
            'block_id' => 0,
            'indent' => 0,
            'end_line' => 51,
            'start_line' => 51,
            'src' => ' my $big_iv = do { use integer ; $max_uv1 * 16 } ;'
          },
          {
            'block_id' => 1,
            'token_num' => 9,
            'has_warnings' => 1,
            'src' => ' do { use integer ; $max_uv1 * 16 }',
            'start_line' => 51,
            'end_line' => 51,
            'indent' => 0
          },
          {
            'has_warnings' => 0,
            'block_id' => 2,
            'token_num' => 3,
            'end_line' => 51,
            'indent' => 1,
            'src' => ' use integer ;',
            'start_line' => 51
          },
          {
            'block_id' => 0,
            'token_num' => 7,
            'has_warnings' => 1,
            'src' => ' my $max_uv_less3 = $max_uv1 - 3 ;',
            'start_line' => 52,
            'end_line' => 52,
            'indent' => 0
          },
          {
            'end_line' => 54,
            'indent' => 0,
            'src' => ' print "# max_uv1 = $max_uv1, max_uv2 = $max_uv2, big_iv = $big_iv\\n" ;',
            'start_line' => 54,
            'has_warnings' => 0,
            'block_id' => 0,
            'token_num' => 3
          },
          {
            'src' => ' print "# max_uv_less3 = $max_uv_less3\\n" ;',
            'start_line' => 55,
            'end_line' => 55,
            'indent' => 0,
            'block_id' => 0,
            'token_num' => 3,
            'has_warnings' => 0
          },
          {
            'block_id' => 0,
            'token_num' => 42,
            'has_warnings' => 1,
            'src' => ' if ( $max_uv1 ne $max_uv2 or $big_iv > $max_uv1 or $max_uv1 == $max_uv_less3 ) { eval { require Config ; } ; my $message = \'unsigned perl arithmetic is not sane\' ; $message .= " (common in 64-bit platforms)" if $Config::Config { d_quad } ; skip_all ( $message ) ; }',
            'start_line' => 56,
            'end_line' => 61,
            'indent' => 0
          },
          {
            'has_warnings' => 0,
            'block_id' => 3,
            'token_num' => 7,
            'end_line' => 57,
            'indent' => 1,
            'src' => ' eval { require Config ; } ;',
            'start_line' => 57
          },
          {
            'indent' => 1,
            'end_line' => 57,
            'start_line' => 57,
            'src' => ' require Config ;',
            'has_warnings' => 0,
            'token_num' => 3,
            'block_id' => 3
          },
          {
            'indent' => 1,
            'end_line' => 58,
            'start_line' => 58,
            'src' => ' my $message = \'unsigned perl arithmetic is not sane\' ;',
            'has_warnings' => 0,
            'token_num' => 5,
            'block_id' => 3
          },
          {
            'start_line' => 59,
            'src' => ' $message .= " (common in 64-bit platforms)" if $Config::Config { d_quad } ;',
            'indent' => 1,
            'end_line' => 59,
            'token_num' => 9,
            'block_id' => 3,
            'has_warnings' => 1
          },
          {
            'indent' => 1,
            'end_line' => 60,
            'start_line' => 60,
            'src' => ' skip_all ( $message ) ;',
            'has_warnings' => 1,
            'token_num' => 5,
            'block_id' => 3
          },
          {
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 19,
            'end_line' => 64,
            'indent' => 0,
            'src' => ' if ( $max_uv_less3 =~ tr/0-9//c ) { skip_all ( \'this perl stringifies large unsigned integers using E notation\' ) ; }',
            'start_line' => 62
          },
          {
            'has_warnings' => 1,
            'token_num' => 5,
            'block_id' => 4,
            'indent' => 1,
            'end_line' => 63,
            'start_line' => 63,
            'src' => ' skip_all ( \'this perl stringifies large unsigned integers using E notation\' ) ;'
          },
          {
            'src' => ' my $st_t = 4 * 4 ;',
            'start_line' => 66,
            'end_line' => 66,
            'indent' => 0,
            'block_id' => 0,
            'token_num' => 7,
            'has_warnings' => 0
          },
          {
            'indent' => 0,
            'end_line' => 68,
            'start_line' => 68,
            'src' => ' my $num = 0 ;',
            'has_warnings' => 0,
            'token_num' => 5,
            'block_id' => 0
          },
          {
            'end_line' => 69,
            'indent' => 0,
            'src' => ' $num += 10 ** $_ - 4 ** $_ for 1 .. $max_chain ;',
            'start_line' => 69,
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 14
          },
          {
            'block_id' => 0,
            'token_num' => 4,
            'has_warnings' => 1,
            'src' => ' $num *= $st_t ;',
            'start_line' => 70,
            'end_line' => 70,
            'indent' => 0
          },
          {
            'start_line' => 71,
            'src' => ' $num += $: : additional_tests ;',
            'indent' => 0,
            'end_line' => 71,
            'token_num' => 6,
            'block_id' => 0,
            'has_warnings' => 1
          },
          {
            'end_line' => 72,
            'indent' => 0,
            'src' => ' plan ( tests => $num ) ;',
            'start_line' => 72,
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 7
          },
          {
            'has_warnings' => 0,
            'token_num' => 6,
            'block_id' => 0,
            'indent' => 0,
            'end_line' => 74,
            'start_line' => 74,
            'src' => ' my $max_uv = ~ 0 ;'
          },
          {
            'indent' => 0,
            'end_line' => 75,
            'start_line' => 75,
            'src' => ' my $max_iv = int ( $max_uv / 2 ) ;',
            'has_warnings' => 1,
            'token_num' => 10,
            'block_id' => 0
          },
          {
            'has_warnings' => 0,
            'block_id' => 0,
            'token_num' => 5,
            'end_line' => 76,
            'indent' => 0,
            'src' => ' my $zero = 0 ;',
            'start_line' => 76
          },
          {
            'start_line' => 78,
            'src' => ' my $l_uv = length $max_uv ;',
            'indent' => 0,
            'end_line' => 78,
            'token_num' => 6,
            'block_id' => 0,
            'has_warnings' => 1
          },
          {
            'indent' => 0,
            'end_line' => 79,
            'start_line' => 79,
            'src' => ' my $l_iv = length $max_iv ;',
            'has_warnings' => 1,
            'token_num' => 6,
            'block_id' => 0
          },
          {
            'src' => ' my $larger_than_uv = substr 97 x 100 , 0 , $l_uv ;',
            'start_line' => 82,
            'end_line' => 82,
            'indent' => 0,
            'block_id' => 0,
            'token_num' => 12,
            'has_warnings' => 1
          },
          {
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 12,
            'end_line' => 83,
            'indent' => 0,
            'src' => ' my $smaller_than_iv = substr 12 x 100 , 0 , $l_iv ;',
            'start_line' => 83
          },
          {
            'indent' => 0,
            'end_line' => 84,
            'start_line' => 84,
            'src' => ' my $yet_smaller_than_iv = substr 97 x 100 , 0 , ( $l_iv - 1 ) ;',
            'has_warnings' => 1,
            'token_num' => 16,
            'block_id' => 0
          },
          {
            'token_num' => 23,
            'block_id' => 0,
            'has_warnings' => 1,
            'start_line' => 86,
            'src' => ' my @list = ( 1 , $yet_smaller_than_iv , $smaller_than_iv , $max_iv , $max_iv + 1 , $max_uv , $max_uv + 1 ) ;',
            'indent' => 0,
            'end_line' => 87
          },
          {
            'indent' => 0,
            'end_line' => 88,
            'start_line' => 88,
            'src' => ' unshift @list , ( reverse map - $_ , @list ) , 0 ;',
            'has_warnings' => 0,
            'token_num' => 14,
            'block_id' => 0
          },
          {
            'has_warnings' => 0,
            'block_id' => 0,
            'token_num' => 7,
            'end_line' => 89,
            'indent' => 0,
            'src' => ' @list = map "$_" , @list ;',
            'start_line' => 89
          },
          {
            'end_line' => 91,
            'indent' => 0,
            'src' => ' note ( "@list" ) ;',
            'start_line' => 91,
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 5
          },
          {
            'src' => ' my $max_uv_pp = "$max_uv" ;',
            'start_line' => 98,
            'end_line' => 98,
            'indent' => 0,
            'block_id' => 0,
            'token_num' => 5,
            'has_warnings' => 0
          },
          {
            'token_num' => 3,
            'block_id' => 0,
            'has_warnings' => 1,
            'start_line' => 98,
            'src' => ' $max_uv_pp ++ ;',
            'indent' => 0,
            'end_line' => 98
          },
          {
            'src' => ' my $max_uv_p1 = "$max_uv" ;',
            'start_line' => 99,
            'end_line' => 99,
            'indent' => 0,
            'block_id' => 0,
            'token_num' => 5,
            'has_warnings' => 0
          },
          {
            'token_num' => 4,
            'block_id' => 0,
            'has_warnings' => 1,
            'start_line' => 99,
            'src' => ' $max_uv_p1 += 0 ;',
            'indent' => 0,
            'end_line' => 99
          },
          {
            'block_id' => 0,
            'token_num' => 3,
            'has_warnings' => 1,
            'src' => ' $max_uv_p1 ++ ;',
            'start_line' => 99,
            'end_line' => 99,
            'indent' => 0
          },
          {
            'indent' => 0,
            'end_line' => 105,
            'start_line' => 105,
            'src' => ' my $temp = $max_uv_p1 ;',
            'has_warnings' => 1,
            'token_num' => 5,
            'block_id' => 0
          },
          {
            'has_warnings' => 0,
            'block_id' => 0,
            'token_num' => 3,
            'end_line' => 106,
            'indent' => 0,
            'src' => ' my $max_uv_p1_as_iv ;',
            'start_line' => 106
          },
          {
            'end_line' => 107,
            'indent' => 0,
            'src' => ' { use integer ; $max_uv_p1_as_iv = 0 + sprintf "%s" , $temp }',
            'start_line' => 107,
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 13
          },
          {
            'src' => ' use integer ;',
            'start_line' => 107,
            'end_line' => 107,
            'indent' => 1,
            'block_id' => 5,
            'token_num' => 3,
            'has_warnings' => 0
          },
          {
            'end_line' => 108,
            'indent' => 0,
            'src' => ' my $max_uv_p1_as_uv = 0 | sprintf "%s" , $temp ;',
            'start_line' => 108,
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 10
          },
          {
            'token_num' => 10,
            'block_id' => 0,
            'has_warnings' => 0,
            'start_line' => 110,
            'src' => ' my @opnames = split// , "-+UINPuinp" ;',
            'indent' => 0,
            'end_line' => 110
          },
          {
            'block_id' => 0,
            'token_num' => 5,
            'has_warnings' => 0,
            'src' => ' my $test = 1 ;',
            'start_line' => 114,
            'end_line' => 114,
            'indent' => 0
          },
          {
            'end_line' => 115,
            'indent' => 0,
            'src' => ' my $nok ;',
            'start_line' => 115,
            'has_warnings' => 0,
            'block_id' => 0,
            'token_num' => 3
          },
          {
            'end_line' => 251,
            'indent' => 0,
            'src' => ' for my $num_chain ( 1 .. $max_chain ) { my @ops = map [ split// ] , grep/[4-9]/ , map { sprintf "%0${num_chain}d" , $_ } 0 .. 10 ** $num_chain - 1 ; for my $op ( @ops ) { for my $first ( 2 .. 5 ) { for my $last ( 2 .. 5 ) { $nok = 0 ; my @otherops = grep $_ <= 3 , @$op ; my @curops = ( $op , \\ @otherops ) ; for my $num ( @list ) { my $inpt ; my @ans ; for my $short ( 0 , 1 ) { $inpt = $num ; $inpt = "$inpt" ; if ( $first == 2 ) { $inpt = $max_uv & $inpt ; } elsif ( $first == 3 ) { use integer ; $inpt += $zero ; } elsif ( $first == 4 ) { $inpt += $zero ; } else { $inpt = "$inpt" ; } for my $curop ( @{ $curops [ $short ] } ) { if ( $curop < 5 ) { if ( $curop < 3 ) { if ( $curop == 0 ) { -- $inpt ; } elsif ( $curop == 1 ) { ++ $inpt ; } else { $inpt = $max_uv & $inpt ; } } elsif ( $curop == 3 ) { use integer ; $inpt += $zero ; } else { $inpt += $zero ; } } elsif ( $curop < 8 ) { if ( $curop == 5 ) { $inpt = "$inpt" ; } elsif ( $curop == 6 ) { my $dummy = $max_uv & $inpt ; } else { use integer ; my $dummy = $inpt + $zero ; } } elsif ( $curop == 8 ) { my $dummy = $inpt + $zero ; } else { my $dummy = $inpt . "" ; } } if ( $last == 2 ) { $inpt = sprintf "%u" , $inpt ; } elsif ( $last == 3 ) { $inpt = sprintf "%d" , $inpt ; } elsif ( $last == 4 ) { $inpt = sprintf "%g" , $inpt ; } else { $inpt = "$inpt" ; } push @ans , $inpt ; } if ( $ans [ 0 ] ne $ans [ 1 ] ) { my $diag = "\'$ans[0]\' ne \'$ans[1]\',\\t$num\\t=> @opnames[$first,@{$curops[0]},$last] vs @opnames[$first,@{$curops[1]},$last]" ; my $excuse ; if ( ( ( $ans [ 0 ] eq $max_uv_pp ) and ( $ans [ 1 ] eq $max_uv_p1 ) ) or ( ( $ans [ 1 ] eq $max_uv_pp ) and ( $ans [ 0 ] eq $max_uv_p1 ) ) ) { $excuse = "ok, as string ++ of max_uv is \\"$max_uv_pp\\", numeric is $max_uv_p1" ; } elsif ( $opnames [ $last ] eq \'I\' and $ans [ 1 ] eq "-1" and $ans [ 0 ] eq $max_uv_p1_as_iv ) { $excuse = "ok, \\"$max_uv_p1\\" correctly converts to IV \\"$max_uv_p1_as_iv\\"" ; } elsif ( $opnames [ $last ] eq \'U\' and $ans [ 1 ] eq ~ 0 and $ans [ 0 ] eq $max_uv_p1_as_uv ) { $excuse = "ok, \\"$max_uv_p1\\" correctly converts to UV \\"$max_uv_p1_as_uv\\"" ; } elsif ( grep { defined $_ &&/^N$/ } @opnames [ @{ $curops [ 0 ] } ] and $ans [ 0 ] == $ans [ 1 ] and $ans [ 0 ] <= ~ 0 and $ans [ 0 ] !=/^-?\\d+$/ and $ans [ 1 ] !~/^-?\\d+$/ ) { $excuse = "ok, numerically equal - notation changed due to adding zero" ; } else { $nok ++ , diag ( $diag ) ; } if ( $excuse ) { note ( $diag ) ; note ( $excuse ) ; } } } ok ( $nok == 0 ) ; } } } }',
            'start_line' => 116,
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 611
          },
          {
            'start_line' => 117,
            'src' => ' my @ops = map [ split// ] , grep/[4-9]/ , map { sprintf "%0${num_chain}d" , $_ } 0 .. 10 ** $num_chain - 1 ;',
            'indent' => 1,
            'end_line' => 118,
            'token_num' => 31,
            'block_id' => 6,
            'has_warnings' => 1
          },
          {
            'src' => ' for my $op ( @ops ) { for my $first ( 2 .. 5 ) { for my $last ( 2 .. 5 ) { $nok = 0 ; my @otherops = grep $_ <= 3 , @$op ; my @curops = ( $op , \\ @otherops ) ; for my $num ( @list ) { my $inpt ; my @ans ; for my $short ( 0 , 1 ) { $inpt = $num ; $inpt = "$inpt" ; if ( $first == 2 ) { $inpt = $max_uv & $inpt ; } elsif ( $first == 3 ) { use integer ; $inpt += $zero ; } elsif ( $first == 4 ) { $inpt += $zero ; } else { $inpt = "$inpt" ; } for my $curop ( @{ $curops [ $short ] } ) { if ( $curop < 5 ) { if ( $curop < 3 ) { if ( $curop == 0 ) { -- $inpt ; } elsif ( $curop == 1 ) { ++ $inpt ; } else { $inpt = $max_uv & $inpt ; } } elsif ( $curop == 3 ) { use integer ; $inpt += $zero ; } else { $inpt += $zero ; } } elsif ( $curop < 8 ) { if ( $curop == 5 ) { $inpt = "$inpt" ; } elsif ( $curop == 6 ) { my $dummy = $max_uv & $inpt ; } else { use integer ; my $dummy = $inpt + $zero ; } } elsif ( $curop == 8 ) { my $dummy = $inpt + $zero ; } else { my $dummy = $inpt . "" ; } } if ( $last == 2 ) { $inpt = sprintf "%u" , $inpt ; } elsif ( $last == 3 ) { $inpt = sprintf "%d" , $inpt ; } elsif ( $last == 4 ) { $inpt = sprintf "%g" , $inpt ; } else { $inpt = "$inpt" ; } push @ans , $inpt ; } if ( $ans [ 0 ] ne $ans [ 1 ] ) { my $diag = "\'$ans[0]\' ne \'$ans[1]\',\\t$num\\t=> @opnames[$first,@{$curops[0]},$last] vs @opnames[$first,@{$curops[1]},$last]" ; my $excuse ; if ( ( ( $ans [ 0 ] eq $max_uv_pp ) and ( $ans [ 1 ] eq $max_uv_p1 ) ) or ( ( $ans [ 1 ] eq $max_uv_pp ) and ( $ans [ 0 ] eq $max_uv_p1 ) ) ) { $excuse = "ok, as string ++ of max_uv is \\"$max_uv_pp\\", numeric is $max_uv_p1" ; } elsif ( $opnames [ $last ] eq \'I\' and $ans [ 1 ] eq "-1" and $ans [ 0 ] eq $max_uv_p1_as_iv ) { $excuse = "ok, \\"$max_uv_p1\\" correctly converts to IV \\"$max_uv_p1_as_iv\\"" ; } elsif ( $opnames [ $last ] eq \'U\' and $ans [ 1 ] eq ~ 0 and $ans [ 0 ] eq $max_uv_p1_as_uv ) { $excuse = "ok, \\"$max_uv_p1\\" correctly converts to UV \\"$max_uv_p1_as_uv\\"" ; } elsif ( grep { defined $_ &&/^N$/ } @opnames [ @{ $curops [ 0 ] } ] and $ans [ 0 ] == $ans [ 1 ] and $ans [ 0 ] <= ~ 0 and $ans [ 0 ] !=/^-?\\d+$/ and $ans [ 1 ] !~/^-?\\d+$/ ) { $excuse = "ok, numerically equal - notation changed due to adding zero" ; } else { $nok ++ , diag ( $diag ) ; } if ( $excuse ) { note ( $diag ) ; note ( $excuse ) ; } } } ok ( $nok == 0 ) ; } } }',
            'start_line' => 123,
            'end_line' => 250,
            'indent' => 1,
            'block_id' => 6,
            'token_num' => 570,
            'has_warnings' => 1
          },
          {
            'token_num' => 562,
            'block_id' => 7,
            'has_warnings' => 1,
            'start_line' => 124,
            'src' => ' for my $first ( 2 .. 5 ) { for my $last ( 2 .. 5 ) { $nok = 0 ; my @otherops = grep $_ <= 3 , @$op ; my @curops = ( $op , \\ @otherops ) ; for my $num ( @list ) { my $inpt ; my @ans ; for my $short ( 0 , 1 ) { $inpt = $num ; $inpt = "$inpt" ; if ( $first == 2 ) { $inpt = $max_uv & $inpt ; } elsif ( $first == 3 ) { use integer ; $inpt += $zero ; } elsif ( $first == 4 ) { $inpt += $zero ; } else { $inpt = "$inpt" ; } for my $curop ( @{ $curops [ $short ] } ) { if ( $curop < 5 ) { if ( $curop < 3 ) { if ( $curop == 0 ) { -- $inpt ; } elsif ( $curop == 1 ) { ++ $inpt ; } else { $inpt = $max_uv & $inpt ; } } elsif ( $curop == 3 ) { use integer ; $inpt += $zero ; } else { $inpt += $zero ; } } elsif ( $curop < 8 ) { if ( $curop == 5 ) { $inpt = "$inpt" ; } elsif ( $curop == 6 ) { my $dummy = $max_uv & $inpt ; } else { use integer ; my $dummy = $inpt + $zero ; } } elsif ( $curop == 8 ) { my $dummy = $inpt + $zero ; } else { my $dummy = $inpt . "" ; } } if ( $last == 2 ) { $inpt = sprintf "%u" , $inpt ; } elsif ( $last == 3 ) { $inpt = sprintf "%d" , $inpt ; } elsif ( $last == 4 ) { $inpt = sprintf "%g" , $inpt ; } else { $inpt = "$inpt" ; } push @ans , $inpt ; } if ( $ans [ 0 ] ne $ans [ 1 ] ) { my $diag = "\'$ans[0]\' ne \'$ans[1]\',\\t$num\\t=> @opnames[$first,@{$curops[0]},$last] vs @opnames[$first,@{$curops[1]},$last]" ; my $excuse ; if ( ( ( $ans [ 0 ] eq $max_uv_pp ) and ( $ans [ 1 ] eq $max_uv_p1 ) ) or ( ( $ans [ 1 ] eq $max_uv_pp ) and ( $ans [ 0 ] eq $max_uv_p1 ) ) ) { $excuse = "ok, as string ++ of max_uv is \\"$max_uv_pp\\", numeric is $max_uv_p1" ; } elsif ( $opnames [ $last ] eq \'I\' and $ans [ 1 ] eq "-1" and $ans [ 0 ] eq $max_uv_p1_as_iv ) { $excuse = "ok, \\"$max_uv_p1\\" correctly converts to IV \\"$max_uv_p1_as_iv\\"" ; } elsif ( $opnames [ $last ] eq \'U\' and $ans [ 1 ] eq ~ 0 and $ans [ 0 ] eq $max_uv_p1_as_uv ) { $excuse = "ok, \\"$max_uv_p1\\" correctly converts to UV \\"$max_uv_p1_as_uv\\"" ; } elsif ( grep { defined $_ &&/^N$/ } @opnames [ @{ $curops [ 0 ] } ] and $ans [ 0 ] == $ans [ 1 ] and $ans [ 0 ] <= ~ 0 and $ans [ 0 ] !=/^-?\\d+$/ and $ans [ 1 ] !~/^-?\\d+$/ ) { $excuse = "ok, numerically equal - notation changed due to adding zero" ; } else { $nok ++ , diag ( $diag ) ; } if ( $excuse ) { note ( $diag ) ; note ( $excuse ) ; } } } ok ( $nok == 0 ) ; } }',
            'indent' => 2,
            'end_line' => 249
          },
          {
            'token_num' => 552,
            'block_id' => 8,
            'has_warnings' => 1,
            'start_line' => 125,
            'src' => ' for my $last ( 2 .. 5 ) { $nok = 0 ; my @otherops = grep $_ <= 3 , @$op ; my @curops = ( $op , \\ @otherops ) ; for my $num ( @list ) { my $inpt ; my @ans ; for my $short ( 0 , 1 ) { $inpt = $num ; $inpt = "$inpt" ; if ( $first == 2 ) { $inpt = $max_uv & $inpt ; } elsif ( $first == 3 ) { use integer ; $inpt += $zero ; } elsif ( $first == 4 ) { $inpt += $zero ; } else { $inpt = "$inpt" ; } for my $curop ( @{ $curops [ $short ] } ) { if ( $curop < 5 ) { if ( $curop < 3 ) { if ( $curop == 0 ) { -- $inpt ; } elsif ( $curop == 1 ) { ++ $inpt ; } else { $inpt = $max_uv & $inpt ; } } elsif ( $curop == 3 ) { use integer ; $inpt += $zero ; } else { $inpt += $zero ; } } elsif ( $curop < 8 ) { if ( $curop == 5 ) { $inpt = "$inpt" ; } elsif ( $curop == 6 ) { my $dummy = $max_uv & $inpt ; } else { use integer ; my $dummy = $inpt + $zero ; } } elsif ( $curop == 8 ) { my $dummy = $inpt + $zero ; } else { my $dummy = $inpt . "" ; } } if ( $last == 2 ) { $inpt = sprintf "%u" , $inpt ; } elsif ( $last == 3 ) { $inpt = sprintf "%d" , $inpt ; } elsif ( $last == 4 ) { $inpt = sprintf "%g" , $inpt ; } else { $inpt = "$inpt" ; } push @ans , $inpt ; } if ( $ans [ 0 ] ne $ans [ 1 ] ) { my $diag = "\'$ans[0]\' ne \'$ans[1]\',\\t$num\\t=> @opnames[$first,@{$curops[0]},$last] vs @opnames[$first,@{$curops[1]},$last]" ; my $excuse ; if ( ( ( $ans [ 0 ] eq $max_uv_pp ) and ( $ans [ 1 ] eq $max_uv_p1 ) ) or ( ( $ans [ 1 ] eq $max_uv_pp ) and ( $ans [ 0 ] eq $max_uv_p1 ) ) ) { $excuse = "ok, as string ++ of max_uv is \\"$max_uv_pp\\", numeric is $max_uv_p1" ; } elsif ( $opnames [ $last ] eq \'I\' and $ans [ 1 ] eq "-1" and $ans [ 0 ] eq $max_uv_p1_as_iv ) { $excuse = "ok, \\"$max_uv_p1\\" correctly converts to IV \\"$max_uv_p1_as_iv\\"" ; } elsif ( $opnames [ $last ] eq \'U\' and $ans [ 1 ] eq ~ 0 and $ans [ 0 ] eq $max_uv_p1_as_uv ) { $excuse = "ok, \\"$max_uv_p1\\" correctly converts to UV \\"$max_uv_p1_as_uv\\"" ; } elsif ( grep { defined $_ &&/^N$/ } @opnames [ @{ $curops [ 0 ] } ] and $ans [ 0 ] == $ans [ 1 ] and $ans [ 0 ] <= ~ 0 and $ans [ 0 ] !=/^-?\\d+$/ and $ans [ 1 ] !~/^-?\\d+$/ ) { $excuse = "ok, numerically equal - notation changed due to adding zero" ; } else { $nok ++ , diag ( $diag ) ; } if ( $excuse ) { note ( $diag ) ; note ( $excuse ) ; } } } ok ( $nok == 0 ) ; }',
            'indent' => 3,
            'end_line' => 248
          },
          {
            'start_line' => 126,
            'src' => ' $nok = 0 ;',
            'indent' => 4,
            'end_line' => 126,
            'token_num' => 4,
            'block_id' => 9,
            'has_warnings' => 1
          },
          {
            'end_line' => 127,
            'indent' => 4,
            'src' => ' my @otherops = grep $_ <= 3 , @$op ;',
            'start_line' => 127,
            'has_warnings' => 0,
            'block_id' => 9,
            'token_num' => 10
          },
          {
            'src' => ' my @curops = ( $op , \\ @otherops ) ;',
            'start_line' => 128,
            'end_line' => 128,
            'indent' => 4,
            'block_id' => 9,
            'token_num' => 10,
            'has_warnings' => 1
          },
          {
            'token_num' => 511,
            'block_id' => 9,
            'has_warnings' => 1,
            'start_line' => 130,
            'src' => ' for my $num ( @list ) { my $inpt ; my @ans ; for my $short ( 0 , 1 ) { $inpt = $num ; $inpt = "$inpt" ; if ( $first == 2 ) { $inpt = $max_uv & $inpt ; } elsif ( $first == 3 ) { use integer ; $inpt += $zero ; } elsif ( $first == 4 ) { $inpt += $zero ; } else { $inpt = "$inpt" ; } for my $curop ( @{ $curops [ $short ] } ) { if ( $curop < 5 ) { if ( $curop < 3 ) { if ( $curop == 0 ) { -- $inpt ; } elsif ( $curop == 1 ) { ++ $inpt ; } else { $inpt = $max_uv & $inpt ; } } elsif ( $curop == 3 ) { use integer ; $inpt += $zero ; } else { $inpt += $zero ; } } elsif ( $curop < 8 ) { if ( $curop == 5 ) { $inpt = "$inpt" ; } elsif ( $curop == 6 ) { my $dummy = $max_uv & $inpt ; } else { use integer ; my $dummy = $inpt + $zero ; } } elsif ( $curop == 8 ) { my $dummy = $inpt + $zero ; } else { my $dummy = $inpt . "" ; } } if ( $last == 2 ) { $inpt = sprintf "%u" , $inpt ; } elsif ( $last == 3 ) { $inpt = sprintf "%d" , $inpt ; } elsif ( $last == 4 ) { $inpt = sprintf "%g" , $inpt ; } else { $inpt = "$inpt" ; } push @ans , $inpt ; } if ( $ans [ 0 ] ne $ans [ 1 ] ) { my $diag = "\'$ans[0]\' ne \'$ans[1]\',\\t$num\\t=> @opnames[$first,@{$curops[0]},$last] vs @opnames[$first,@{$curops[1]},$last]" ; my $excuse ; if ( ( ( $ans [ 0 ] eq $max_uv_pp ) and ( $ans [ 1 ] eq $max_uv_p1 ) ) or ( ( $ans [ 1 ] eq $max_uv_pp ) and ( $ans [ 0 ] eq $max_uv_p1 ) ) ) { $excuse = "ok, as string ++ of max_uv is \\"$max_uv_pp\\", numeric is $max_uv_p1" ; } elsif ( $opnames [ $last ] eq \'I\' and $ans [ 1 ] eq "-1" and $ans [ 0 ] eq $max_uv_p1_as_iv ) { $excuse = "ok, \\"$max_uv_p1\\" correctly converts to IV \\"$max_uv_p1_as_iv\\"" ; } elsif ( $opnames [ $last ] eq \'U\' and $ans [ 1 ] eq ~ 0 and $ans [ 0 ] eq $max_uv_p1_as_uv ) { $excuse = "ok, \\"$max_uv_p1\\" correctly converts to UV \\"$max_uv_p1_as_uv\\"" ; } elsif ( grep { defined $_ &&/^N$/ } @opnames [ @{ $curops [ 0 ] } ] and $ans [ 0 ] == $ans [ 1 ] and $ans [ 0 ] <= ~ 0 and $ans [ 0 ] !=/^-?\\d+$/ and $ans [ 1 ] !~/^-?\\d+$/ ) { $excuse = "ok, numerically equal - notation changed due to adding zero" ; } else { $nok ++ , diag ( $diag ) ; } if ( $excuse ) { note ( $diag ) ; note ( $excuse ) ; } } }',
            'indent' => 4,
            'end_line' => 246
          },
          {
            'has_warnings' => 0,
            'token_num' => 3,
            'block_id' => 10,
            'indent' => 5,
            'end_line' => 131,
            'start_line' => 131,
            'src' => ' my $inpt ;'
          },
          {
            'src' => ' my @ans ;',
            'start_line' => 132,
            'end_line' => 132,
            'indent' => 5,
            'block_id' => 10,
            'token_num' => 3,
            'has_warnings' => 0
          },
          {
            'indent' => 5,
            'end_line' => 195,
            'start_line' => 134,
            'src' => ' for my $short ( 0 , 1 ) { $inpt = $num ; $inpt = "$inpt" ; if ( $first == 2 ) { $inpt = $max_uv & $inpt ; } elsif ( $first == 3 ) { use integer ; $inpt += $zero ; } elsif ( $first == 4 ) { $inpt += $zero ; } else { $inpt = "$inpt" ; } for my $curop ( @{ $curops [ $short ] } ) { if ( $curop < 5 ) { if ( $curop < 3 ) { if ( $curop == 0 ) { -- $inpt ; } elsif ( $curop == 1 ) { ++ $inpt ; } else { $inpt = $max_uv & $inpt ; } } elsif ( $curop == 3 ) { use integer ; $inpt += $zero ; } else { $inpt += $zero ; } } elsif ( $curop < 8 ) { if ( $curop == 5 ) { $inpt = "$inpt" ; } elsif ( $curop == 6 ) { my $dummy = $max_uv & $inpt ; } else { use integer ; my $dummy = $inpt + $zero ; } } elsif ( $curop == 8 ) { my $dummy = $inpt + $zero ; } else { my $dummy = $inpt . "" ; } } if ( $last == 2 ) { $inpt = sprintf "%u" , $inpt ; } elsif ( $last == 3 ) { $inpt = sprintf "%d" , $inpt ; } elsif ( $last == 4 ) { $inpt = sprintf "%g" , $inpt ; } else { $inpt = "$inpt" ; } push @ans , $inpt ; }',
            'has_warnings' => 1,
            'token_num' => 278,
            'block_id' => 10
          },
          {
            'token_num' => 4,
            'block_id' => 11,
            'has_warnings' => 1,
            'start_line' => 137,
            'src' => ' $inpt = $num ;',
            'indent' => 6,
            'end_line' => 137
          },
          {
            'has_warnings' => 1,
            'block_id' => 11,
            'token_num' => 4,
            'end_line' => 138,
            'indent' => 6,
            'src' => ' $inpt = "$inpt" ;',
            'start_line' => 138
          },
          {
            'end_line' => 141,
            'indent' => 6,
            'src' => ' if ( $first == 2 ) { $inpt = $max_uv & $inpt ; }',
            'start_line' => 139,
            'has_warnings' => 1,
            'block_id' => 11,
            'token_num' => 14
          },
          {
            'block_id' => 12,
            'token_num' => 6,
            'has_warnings' => 1,
            'src' => ' $inpt = $max_uv & $inpt ;',
            'start_line' => 140,
            'end_line' => 140,
            'indent' => 7
          },
          {
            'indent' => 6,
            'end_line' => 143,
            'start_line' => 141,
            'src' => ' elsif ( $first == 3 ) { use integer ; $inpt += $zero ; }',
            'has_warnings' => 1,
            'token_num' => 15,
            'block_id' => 11
          },
          {
            'block_id' => 13,
            'token_num' => 3,
            'has_warnings' => 0,
            'src' => ' use integer ;',
            'start_line' => 142,
            'end_line' => 142,
            'indent' => 7
          },
          {
            'indent' => 7,
            'end_line' => 142,
            'start_line' => 142,
            'src' => ' $inpt += $zero ;',
            'has_warnings' => 1,
            'token_num' => 4,
            'block_id' => 13
          },
          {
            'indent' => 6,
            'end_line' => 145,
            'start_line' => 143,
            'src' => ' elsif ( $first == 4 ) { $inpt += $zero ; }',
            'has_warnings' => 1,
            'token_num' => 12,
            'block_id' => 11
          },
          {
            'end_line' => 144,
            'indent' => 7,
            'src' => ' $inpt += $zero ;',
            'start_line' => 144,
            'has_warnings' => 1,
            'block_id' => 14,
            'token_num' => 4
          },
          {
            'src' => ' else { $inpt = "$inpt" ; }',
            'start_line' => 145,
            'end_line' => 147,
            'indent' => 6,
            'block_id' => 11,
            'token_num' => 7,
            'has_warnings' => 1
          },
          {
            'block_id' => 15,
            'token_num' => 4,
            'has_warnings' => 1,
            'src' => ' $inpt = "$inpt" ;',
            'start_line' => 146,
            'end_line' => 146,
            'indent' => 7
          },
          {
            'start_line' => 155,
            'src' => ' for my $curop ( @{ $curops [ $short ] } ) { if ( $curop < 5 ) { if ( $curop < 3 ) { if ( $curop == 0 ) { -- $inpt ; } elsif ( $curop == 1 ) { ++ $inpt ; } else { $inpt = $max_uv & $inpt ; } } elsif ( $curop == 3 ) { use integer ; $inpt += $zero ; } else { $inpt += $zero ; } } elsif ( $curop < 8 ) { if ( $curop == 5 ) { $inpt = "$inpt" ; } elsif ( $curop == 6 ) { my $dummy = $max_uv & $inpt ; } else { use integer ; my $dummy = $inpt + $zero ; } } elsif ( $curop == 8 ) { my $dummy = $inpt + $zero ; } else { my $dummy = $inpt . "" ; } }',
            'indent' => 6,
            'end_line' => 183,
            'token_num' => 155,
            'block_id' => 11,
            'has_warnings' => 1
          },
          {
            'block_id' => 16,
            'token_num' => 69,
            'has_warnings' => 1,
            'src' => ' if ( $curop < 5 ) { if ( $curop < 3 ) { if ( $curop == 0 ) { -- $inpt ; } elsif ( $curop == 1 ) { ++ $inpt ; } else { $inpt = $max_uv & $inpt ; } } elsif ( $curop == 3 ) { use integer ; $inpt += $zero ; } else { $inpt += $zero ; } }',
            'start_line' => 156,
            'end_line' => 170,
            'indent' => 7
          },
          {
            'src' => ' if ( $curop < 3 ) { if ( $curop == 0 ) { -- $inpt ; } elsif ( $curop == 1 ) { ++ $inpt ; } else { $inpt = $max_uv & $inpt ; } }',
            'start_line' => 157,
            'end_line' => 165,
            'indent' => 8,
            'block_id' => 17,
            'token_num' => 39,
            'has_warnings' => 1
          },
          {
            'block_id' => 18,
            'token_num' => 11,
            'has_warnings' => 1,
            'src' => ' if ( $curop == 0 ) { -- $inpt ; }',
            'start_line' => 158,
            'end_line' => 160,
            'indent' => 9
          },
          {
            'start_line' => 159,
            'src' => ' -- $inpt ;',
            'indent' => 10,
            'end_line' => 159,
            'token_num' => 3,
            'block_id' => 19,
            'has_warnings' => 1
          },
          {
            'has_warnings' => 1,
            'block_id' => 18,
            'token_num' => 11,
            'end_line' => 162,
            'indent' => 9,
            'src' => ' elsif ( $curop == 1 ) { ++ $inpt ; }',
            'start_line' => 160
          },
          {
            'block_id' => 20,
            'token_num' => 3,
            'has_warnings' => 1,
            'src' => ' ++ $inpt ;',
            'start_line' => 161,
            'end_line' => 161,
            'indent' => 10
          },
          {
            'block_id' => 18,
            'token_num' => 9,
            'has_warnings' => 1,
            'src' => ' else { $inpt = $max_uv & $inpt ; }',
            'start_line' => 162,
            'end_line' => 164,
            'indent' => 9
          },
          {
            'end_line' => 163,
            'indent' => 10,
            'src' => ' $inpt = $max_uv & $inpt ;',
            'start_line' => 163,
            'has_warnings' => 1,
            'block_id' => 21,
            'token_num' => 6
          },
          {
            'end_line' => 167,
            'indent' => 8,
            'src' => ' elsif ( $curop == 3 ) { use integer ; $inpt += $zero ; }',
            'start_line' => 165,
            'has_warnings' => 1,
            'block_id' => 17,
            'token_num' => 15
          },
          {
            'block_id' => 22,
            'token_num' => 3,
            'has_warnings' => 0,
            'src' => ' use integer ;',
            'start_line' => 166,
            'end_line' => 166,
            'indent' => 9
          },
          {
            'block_id' => 22,
            'token_num' => 4,
            'has_warnings' => 1,
            'src' => ' $inpt += $zero ;',
            'start_line' => 166,
            'end_line' => 166,
            'indent' => 9
          },
          {
            'token_num' => 7,
            'block_id' => 17,
            'has_warnings' => 1,
            'start_line' => 167,
            'src' => ' else { $inpt += $zero ; }',
            'indent' => 8,
            'end_line' => 169
          },
          {
            'end_line' => 168,
            'indent' => 9,
            'src' => ' $inpt += $zero ;',
            'start_line' => 168,
            'has_warnings' => 1,
            'block_id' => 23,
            'token_num' => 4
          },
          {
            'end_line' => 178,
            'indent' => 7,
            'src' => ' elsif ( $curop < 8 ) { if ( $curop == 5 ) { $inpt = "$inpt" ; } elsif ( $curop == 6 ) { my $dummy = $max_uv & $inpt ; } else { use integer ; my $dummy = $inpt + $zero ; } }',
            'start_line' => 170,
            'has_warnings' => 1,
            'block_id' => 16,
            'token_num' => 48
          },
          {
            'start_line' => 171,
            'src' => ' if ( $curop == 5 ) { $inpt = "$inpt" ; }',
            'indent' => 8,
            'end_line' => 173,
            'token_num' => 12,
            'block_id' => 24,
            'has_warnings' => 1
          },
          {
            'src' => ' $inpt = "$inpt" ;',
            'start_line' => 172,
            'end_line' => 172,
            'indent' => 9,
            'block_id' => 25,
            'token_num' => 4,
            'has_warnings' => 1
          },
          {
            'has_warnings' => 1,
            'block_id' => 24,
            'token_num' => 15,
            'end_line' => 175,
            'indent' => 8,
            'src' => ' elsif ( $curop == 6 ) { my $dummy = $max_uv & $inpt ; }',
            'start_line' => 173
          },
          {
            'has_warnings' => 1,
            'block_id' => 26,
            'token_num' => 7,
            'end_line' => 174,
            'indent' => 9,
            'src' => ' my $dummy = $max_uv & $inpt ;',
            'start_line' => 174
          },
          {
            'start_line' => 175,
            'src' => ' else { use integer ; my $dummy = $inpt + $zero ; }',
            'indent' => 8,
            'end_line' => 177,
            'token_num' => 13,
            'block_id' => 24,
            'has_warnings' => 1
          },
          {
            'end_line' => 176,
            'indent' => 9,
            'src' => ' use integer ;',
            'start_line' => 176,
            'has_warnings' => 0,
            'block_id' => 27,
            'token_num' => 3
          },
          {
            'end_line' => 176,
            'indent' => 9,
            'src' => ' my $dummy = $inpt + $zero ;',
            'start_line' => 176,
            'has_warnings' => 1,
            'block_id' => 27,
            'token_num' => 7
          },
          {
            'src' => ' elsif ( $curop == 8 ) { my $dummy = $inpt + $zero ; }',
            'start_line' => 178,
            'end_line' => 180,
            'indent' => 7,
            'block_id' => 16,
            'token_num' => 15,
            'has_warnings' => 1
          },
          {
            'has_warnings' => 1,
            'block_id' => 28,
            'token_num' => 7,
            'end_line' => 179,
            'indent' => 8,
            'src' => ' my $dummy = $inpt + $zero ;',
            'start_line' => 179
          },
          {
            'has_warnings' => 1,
            'block_id' => 16,
            'token_num' => 10,
            'end_line' => 182,
            'indent' => 7,
            'src' => ' else { my $dummy = $inpt . "" ; }',
            'start_line' => 180
          },
          {
            'src' => ' my $dummy = $inpt . "" ;',
            'start_line' => 181,
            'end_line' => 181,
            'indent' => 8,
            'block_id' => 29,
            'token_num' => 7,
            'has_warnings' => 1
          },
          {
            'end_line' => 187,
            'indent' => 6,
            'src' => ' if ( $last == 2 ) { $inpt = sprintf "%u" , $inpt ; }',
            'start_line' => 185,
            'has_warnings' => 1,
            'block_id' => 11,
            'token_num' => 15
          },
          {
            'block_id' => 30,
            'token_num' => 7,
            'has_warnings' => 1,
            'src' => ' $inpt = sprintf "%u" , $inpt ;',
            'start_line' => 186,
            'end_line' => 186,
            'indent' => 7
          },
          {
            'end_line' => 189,
            'indent' => 6,
            'src' => ' elsif ( $last == 3 ) { $inpt = sprintf "%d" , $inpt ; }',
            'start_line' => 187,
            'has_warnings' => 1,
            'block_id' => 11,
            'token_num' => 15
          },
          {
            'has_warnings' => 1,
            'token_num' => 7,
            'block_id' => 31,
            'indent' => 7,
            'end_line' => 188,
            'start_line' => 188,
            'src' => ' $inpt = sprintf "%d" , $inpt ;'
          },
          {
            'block_id' => 11,
            'token_num' => 15,
            'has_warnings' => 1,
            'src' => ' elsif ( $last == 4 ) { $inpt = sprintf "%g" , $inpt ; }',
            'start_line' => 189,
            'end_line' => 191,
            'indent' => 6
          },
          {
            'has_warnings' => 1,
            'block_id' => 32,
            'token_num' => 7,
            'end_line' => 190,
            'indent' => 7,
            'src' => ' $inpt = sprintf "%g" , $inpt ;',
            'start_line' => 190
          },
          {
            'indent' => 6,
            'end_line' => 193,
            'start_line' => 191,
            'src' => ' else { $inpt = "$inpt" ; }',
            'has_warnings' => 1,
            'token_num' => 7,
            'block_id' => 11
          },
          {
            'has_warnings' => 1,
            'block_id' => 33,
            'token_num' => 4,
            'end_line' => 192,
            'indent' => 7,
            'src' => ' $inpt = "$inpt" ;',
            'start_line' => 192
          },
          {
            'has_warnings' => 1,
            'token_num' => 5,
            'block_id' => 11,
            'indent' => 6,
            'end_line' => 194,
            'start_line' => 194,
            'src' => ' push @ans , $inpt ;'
          },
          {
            'end_line' => 245,
            'indent' => 5,
            'src' => ' if ( $ans [ 0 ] ne $ans [ 1 ] ) { my $diag = "\'$ans[0]\' ne \'$ans[1]\',\\t$num\\t=> @opnames[$first,@{$curops[0]},$last] vs @opnames[$first,@{$curops[1]},$last]" ; my $excuse ; if ( ( ( $ans [ 0 ] eq $max_uv_pp ) and ( $ans [ 1 ] eq $max_uv_p1 ) ) or ( ( $ans [ 1 ] eq $max_uv_pp ) and ( $ans [ 0 ] eq $max_uv_p1 ) ) ) { $excuse = "ok, as string ++ of max_uv is \\"$max_uv_pp\\", numeric is $max_uv_p1" ; } elsif ( $opnames [ $last ] eq \'I\' and $ans [ 1 ] eq "-1" and $ans [ 0 ] eq $max_uv_p1_as_iv ) { $excuse = "ok, \\"$max_uv_p1\\" correctly converts to IV \\"$max_uv_p1_as_iv\\"" ; } elsif ( $opnames [ $last ] eq \'U\' and $ans [ 1 ] eq ~ 0 and $ans [ 0 ] eq $max_uv_p1_as_uv ) { $excuse = "ok, \\"$max_uv_p1\\" correctly converts to UV \\"$max_uv_p1_as_uv\\"" ; } elsif ( grep { defined $_ &&/^N$/ } @opnames [ @{ $curops [ 0 ] } ] and $ans [ 0 ] == $ans [ 1 ] and $ans [ 0 ] <= ~ 0 and $ans [ 0 ] !=/^-?\\d+$/ and $ans [ 1 ] !~/^-?\\d+$/ ) { $excuse = "ok, numerically equal - notation changed due to adding zero" ; } else { $nok ++ , diag ( $diag ) ; } if ( $excuse ) { note ( $diag ) ; note ( $excuse ) ; } }',
            'start_line' => 196,
            'has_warnings' => 1,
            'block_id' => 10,
            'token_num' => 219
          },
          {
            'start_line' => 197,
            'src' => ' my $diag = "\'$ans[0]\' ne \'$ans[1]\',\\t$num\\t=> @opnames[$first,@{$curops[0]},$last] vs @opnames[$first,@{$curops[1]},$last]" ;',
            'indent' => 6,
            'end_line' => 197,
            'token_num' => 5,
            'block_id' => 34,
            'has_warnings' => 0
          },
          {
            'has_warnings' => 0,
            'token_num' => 3,
            'block_id' => 34,
            'indent' => 6,
            'end_line' => 198,
            'start_line' => 198,
            'src' => ' my $excuse ;'
          },
          {
            'block_id' => 34,
            'token_num' => 48,
            'has_warnings' => 1,
            'src' => ' if ( ( ( $ans [ 0 ] eq $max_uv_pp ) and ( $ans [ 1 ] eq $max_uv_p1 ) ) or ( ( $ans [ 1 ] eq $max_uv_pp ) and ( $ans [ 0 ] eq $max_uv_p1 ) ) ) { $excuse = "ok, as string ++ of max_uv is \\"$max_uv_pp\\", numeric is $max_uv_p1" ; }',
            'start_line' => 200,
            'end_line' => 205,
            'indent' => 6
          },
          {
            'has_warnings' => 1,
            'token_num' => 4,
            'block_id' => 35,
            'indent' => 7,
            'end_line' => 204,
            'start_line' => 204,
            'src' => ' $excuse = "ok, as string ++ of max_uv is \\"$max_uv_pp\\", numeric is $max_uv_p1" ;'
          },
          {
            'indent' => 6,
            'end_line' => 219,
            'start_line' => 205,
            'src' => ' elsif ( $opnames [ $last ] eq \'I\' and $ans [ 1 ] eq "-1" and $ans [ 0 ] eq $max_uv_p1_as_iv ) { $excuse = "ok, \\"$max_uv_p1\\" correctly converts to IV \\"$max_uv_p1_as_iv\\"" ; }',
            'has_warnings' => 1,
            'token_num' => 29,
            'block_id' => 34
          },
          {
            'has_warnings' => 1,
            'block_id' => 36,
            'token_num' => 4,
            'end_line' => 218,
            'indent' => 7,
            'src' => ' $excuse = "ok, \\"$max_uv_p1\\" correctly converts to IV \\"$max_uv_p1_as_iv\\"" ;',
            'start_line' => 218
          },
          {
            'end_line' => 223,
            'indent' => 6,
            'src' => ' elsif ( $opnames [ $last ] eq \'U\' and $ans [ 1 ] eq ~ 0 and $ans [ 0 ] eq $max_uv_p1_as_uv ) { $excuse = "ok, \\"$max_uv_p1\\" correctly converts to UV \\"$max_uv_p1_as_uv\\"" ; }',
            'start_line' => 219,
            'has_warnings' => 1,
            'block_id' => 34,
            'token_num' => 30
          },
          {
            'has_warnings' => 1,
            'block_id' => 37,
            'token_num' => 4,
            'end_line' => 222,
            'indent' => 7,
            'src' => ' $excuse = "ok, \\"$max_uv_p1\\" correctly converts to UV \\"$max_uv_p1_as_uv\\"" ;',
            'start_line' => 222
          },
          {
            'src' => ' elsif ( grep { defined $_ &&/^N$/ } @opnames [ @{ $curops [ 0 ] } ] and $ans [ 0 ] == $ans [ 1 ] and $ans [ 0 ] <= ~ 0 and $ans [ 0 ] !=/^-?\\d+$/ and $ans [ 1 ] !~/^-?\\d+$/ ) { $excuse = "ok, numerically equal - notation changed due to adding zero" ; }',
            'start_line' => 223,
            'end_line' => 237,
            'indent' => 6,
            'block_id' => 34,
            'token_num' => 63,
            'has_warnings' => 1
          },
          {
            'src' => ' $excuse = "ok, numerically equal - notation changed due to adding zero" ;',
            'start_line' => 236,
            'end_line' => 236,
            'indent' => 7,
            'block_id' => 38,
            'token_num' => 4,
            'has_warnings' => 1
          },
          {
            'src' => ' else { $nok ++ , diag ( $diag ) ; }',
            'start_line' => 237,
            'end_line' => 240,
            'indent' => 6,
            'block_id' => 34,
            'token_num' => 11,
            'has_warnings' => 1
          },
          {
            'block_id' => 39,
            'token_num' => 8,
            'has_warnings' => 1,
            'src' => ' $nok ++ , diag ( $diag ) ;',
            'start_line' => 238,
            'end_line' => 239,
            'indent' => 7
          },
          {
            'start_line' => 241,
            'src' => ' if ( $excuse ) { note ( $diag ) ; note ( $excuse ) ; }',
            'indent' => 6,
            'end_line' => 244,
            'token_num' => 16,
            'block_id' => 34,
            'has_warnings' => 1
          },
          {
            'token_num' => 5,
            'block_id' => 40,
            'has_warnings' => 1,
            'start_line' => 242,
            'src' => ' note ( $diag ) ;',
            'indent' => 7,
            'end_line' => 242
          },
          {
            'has_warnings' => 1,
            'token_num' => 5,
            'block_id' => 40,
            'indent' => 7,
            'end_line' => 243,
            'start_line' => 243,
            'src' => ' note ( $excuse ) ;'
          },
          {
            'has_warnings' => 1,
            'token_num' => 7,
            'block_id' => 9,
            'indent' => 4,
            'end_line' => 247,
            'start_line' => 247,
            'src' => ' ok ( $nok == 0 ) ;'
          },
          {
            'src' => ' ok ( -0.0 eq "0" , \'negative zero stringifies as 0\' ) ;',
            'start_line' => 256,
            'end_line' => 256,
            'indent' => 0,
            'block_id' => 0,
            'token_num' => 9,
            'has_warnings' => 1
          },
          {
            'has_warnings' => 1,
            'token_num' => 8,
            'block_id' => 0,
            'indent' => 0,
            'end_line' => 257,
            'start_line' => 257,
            'src' => ' ok ( ! -0.0 , "neg zero is boolean false" ) ;'
          },
          {
            'has_warnings' => 0,
            'block_id' => 0,
            'token_num' => 5,
            'end_line' => 258,
            'indent' => 0,
            'src' => ' my $nz = -0.0 ;',
            'start_line' => 258
          },
          {
            'block_id' => 0,
            'token_num' => 7,
            'has_warnings' => 0,
            'src' => ' { my $dummy = "$nz" ; }',
            'start_line' => 259,
            'end_line' => 259,
            'indent' => 0
          },
          {
            'token_num' => 5,
            'block_id' => 42,
            'has_warnings' => 0,
            'start_line' => 259,
            'src' => ' my $dummy = "$nz" ;',
            'indent' => 1,
            'end_line' => 259
          },
          {
            'has_warnings' => 1,
            'token_num' => 8,
            'block_id' => 0,
            'indent' => 0,
            'end_line' => 260,
            'start_line' => 260,
            'src' => ' ok ( ! $nz , \'previously stringified -0.0 is boolean false\' ) ;'
          },
          {
            'end_line' => 261,
            'indent' => 0,
            'src' => ' $nz = -0.0 ;',
            'start_line' => 261,
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 4
          },
          {
            'has_warnings' => 1,
            'token_num' => 21,
            'block_id' => 0,
            'indent' => 0,
            'end_line' => 263,
            'start_line' => 262,
            'src' => ' is sprintf ( "%+.f" , - - $nz ) , sprintf ( "%+.f" , - - $nz ) , "negation does not coerce negative zeroes" ;'
          }
        ]
, 'Compiler::Lexer::get_groups_by_syntax_level');
};

subtest 'get_used_modules' => sub {
    my $modules = Compiler::Lexer->new('')->get_used_modules($script);
    is_deeply($modules, [
          {
            'name' => 'strict',
            'args' => ''
          },
          {
            'args' => '',
            'name' => 'integer'
          },
          {
            'name' => 'integer',
            'args' => ''
          },
          {
            'name' => 'integer',
            'args' => ''
          },
          {
            'name' => 'integer',
            'args' => ''
          },
          {
            'name' => 'integer',
            'args' => ''
          }
        ]
, 'Compiler::Lexer::get_used_modules');
};

done_testing;
