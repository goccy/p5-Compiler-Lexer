use strict;
use warnings;
use Test::More 0.95;

use_ok('Compiler::Lexer');

=pod

Perl v5.14 introduces these new syntax thingys:

In-place substitution modifier
	s/.../.../r

Character set modifiers for regexes
	/d, /l , /u , and /a 

Array and hash operators accept simple references

=cut

done_testing();
