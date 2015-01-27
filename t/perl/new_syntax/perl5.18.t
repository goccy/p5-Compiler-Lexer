use strict;
use warnings;
use Test::More 0.95;

use_ok('Compiler::Lexer');

=pod

Perl v5.18 introduces these new syntax thingys:

Last filehandle
	${^LAST_FH}

Named lexical subroutines
	my sub foo { ... }
	our sub foo { ... }
	state sub foo { ... }

=cut

done_testing();
