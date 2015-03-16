use strict;
use warnings;
use Test::More 0.95;

use_ok('Compiler::Lexer');

=pod

Perl v5.10 introduces these new syntax thingys:

state keyword
	state $foo 

Defined-or
	//

say{}

stacked filetests

UNITCHECK

_ prototype

Smart matching
	~~ operator
	given-when
	
=cut

done_testing();
