use strict;
use warnings;
use Test::More 0.95;

use_ok('Compiler::Lexer');

my @scripts = (
	{
	test  => 'scalar',
	code  => '$scalar->$*',	
	names => [ qw( GlobalVar Pointer PostDeref PostDerefStar ) ],	
	},
	{
	test  => 'array',
	code  => '$array->@*',	
	names => [ qw( GlobalVar Pointer PostDeref PostDerefStar ) ],	
	},
	{
	test  => 'array index',
	code  => '$array->$#*',	
	names => [ qw( GlobalVar Pointer PostDeref PostDerefStar ) ],	
	},
	{
	test  => 'array single element',
	code  => '$array->@[0]',	
	names => [ qw( GlobalVar Pointer PostDeref LeftBracket Int RightBracket ) ],	
	},
	{
	test  => 'array slice',
	code  => '$array->@[0,1]',	
	names => [ qw( GlobalVar Pointer PostDeref LeftBracket Int Comma Int RightBracket ) ],	
	},
	{
	test  => 'hash',
	code  => '$hash->%*',	
	names => [ qw( GlobalVar Pointer PostDeref PostDerefStar ) ],	
	},
	{
	test  => 'hash single element',
	code  => '$hash->%{"key"}',	
	names => [ qw( GlobalVar Pointer PostDeref LeftBrace String RightBrace ) ],	
	},
	{
	test  => 'hash slice',
	code  => '$hash->%{ @keys }',	
	names => [ qw( GlobalVar Pointer PostDeref LeftBrace GlobalArrayVar RightBrace ) ],	
	},
	{
	test  => 'code',
	code  => '$code->&*',	
	names => [ qw( GlobalVar Pointer PostDeref PostDerefStar ) ],	
	},
	{
	test  => 'code with args',
	code  => '$code->&( @args )',	
	names => [ qw( GlobalVar Pointer PostDeref LeftParenthesis GlobalArrayVar RightParenthesis ) ],	
	},
	{
	test  => 'typeglob',
	code  => '$typeglob->**',	
	names => [ qw( GlobalVar Pointer PostDeref PostDerefStar ) ],	
	},
	{
	test  => 'typeglob with key',
	code  => '$typeglob->*{SCALAR}',	
	names => [ qw( GlobalVar Pointer PostDeref LeftBrace Key RightBrace ) ],	
	},
	);



foreach my $hash ( @scripts ) {
	subtest $hash->{test} => sub {
    	my $tokens = Compiler::Lexer->new('')->tokenize($hash->{code});
		my @names = map { $_->name } @$tokens;
		is_deeply( \@names, $hash->{names},  $hash->{code} );
		};
	}

done_testing();
