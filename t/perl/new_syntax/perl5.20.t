use strict;
use warnings;
use Test::More 0.95;

use_ok('Compiler::Lexer');

=pod

Perl v5.20 introduces these new syntax thingys:

Postfix dereference (see also t/perl/op/postderef.t)
	$array->@*

Chunk slices
	%hash{@keys}
	%array[@indices]

Subroutine signatures
	sub ...

=cut


done_testing();
