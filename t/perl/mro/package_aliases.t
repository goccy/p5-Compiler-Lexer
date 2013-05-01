use strict;
use warnings;
use Test::More;
BEGIN {
    use_ok('Compiler::Lexer');
}
my $script =<<'SCRIPT';
#!./perl

BEGIN {
    unless (-d 'blib') {
        chdir 't' if -d 't';
        @INC = '../lib';
    }
    require q(./test.pl);
}

use strict;
use warnings;
plan(tests => 52);

{
    package New;
    use strict;
    use warnings;

    package Old;
    use strict;
    use warnings;

    {
      no strict 'refs';
      *{'Old::'} = *{'New::'};
    }
}

ok (Old->isa (New::), 'Old inherits from New');
ok (New->isa (Old::), 'New inherits from Old');

object_ok (bless ({}, Old::), New::, 'Old object');
object_ok (bless ({}, New::), Old::, 'New object');


# Test that replacing a package by assigning to an existing glob
# invalidates the isa caches
for(
 {
   name => 'assigning a glob to a glob',
   code => '$life_raft = $::{"Left::"}; *Left:: = $::{"Right::"}',
 },
 {
   name => 'assigning a string to a glob',
   code => '$life_raft = $::{"Left::"}; *Left:: = "Right::"',
 },
 {
   name => 'assigning a stashref to a glob',
   code => '$life_raft = \%Left::; *Left:: = \%Right::',
 },
) {
 fresh_perl_is
   q~
     @Subclass::ISA = "Left";
     @Left::ISA = "TopLeft";

     sub TopLeft::speak { "Woof!" }
     sub TopRight::speak { "Bow-wow!" }

     my $thing = bless [], "Subclass";

     # mro_package_moved needs to know to skip non-globs
     $Right::{"gleck::"} = 3;

     @Right::ISA = 'TopRight';
     my $life_raft;
    __code__;

     print $thing->speak, "\n";

     undef $life_raft;
     print $thing->speak, "\n";
   ~ =~ s\__code__\$$_{code}\r,
  "Bow-wow!\nBow-wow!\n",
   {},
  "replacing packages by $$_{name} updates isa caches";
}

# Similar test, but with nested packages
#
#  TopLeft (Woof)    TopRight (Bow-wow)
#      |                 |
#  Left::Side   <-   Right::Side
#      |
#   Subclass
#
# This test assigns Right:: to Left::, indirectly making Left::Side an
# alias to Right::Side (following the arrow in the diagram).
for(
 {
   name => 'assigning a glob to a glob',
   code => '$life_raft = $::{"Left::"}; *Left:: = $::{"Right::"}',
 },
 {
   name => 'assigning a string to a glob',
   code => '$life_raft = $::{"Left::"}; *Left:: = "Right::"',
 },
 {
   name => 'assigning a stashref to a glob',
   code => '$life_raft = \%Left::; *Left:: = \%Right::',
 },
) {
 fresh_perl_is
   q~
     @Subclass::ISA = "Left::Side";
     @Left::Side::ISA = "TopLeft";

     sub TopLeft::speak { "Woof!" }
     sub TopRight::speak { "Bow-wow!" }

     my $thing = bless [], "Subclass";

     @Right::Side::ISA = 'TopRight';
     my $life_raft;
    __code__;

     print $thing->speak, "\n";

     undef $life_raft;
     print $thing->speak, "\n";
   ~ =~ s\__code__\$$_{code}\r,
  "Bow-wow!\nBow-wow!\n",
   {},
  "replacing nested packages by $$_{name} updates isa caches";
}

# Another nested package test, in which the isa cache needs to be reset on
# the subclass of a package that does not exist.
#
# Parenthesized packages do not exist.
#
#  outer::inner    ( clone::inner )
#       |                 |
#     left              right
#
#        outer  ->  clone
#
# This test assigns outer:: to clone::, making clone::inner an alias to
# outer::inner.
#
# Then we also run the test again, but without outer::inner
for(
 {
   name => 'assigning a glob to a glob',
   code => '*clone:: = *outer::',
 },
 {
   name => 'assigning a string to a glob',
   code => '*clone:: = "outer::"',
 },
 {
   name => 'assigning a stashref to a glob',
   code => '*clone:: = \%outer::',
 },
) {
 for my $tail ('inner', 'inner::', 'inner:::', 'inner::::') {
  fresh_perl_is
    q~
      my $tail = shift;
      @left::ISA = "outer::$tail";
      @right::ISA = "clone::$tail";
      bless [], "outer::$tail"; # autovivify the stash

     __code__;

      print "ok 1", "\n" if left->isa("clone::$tail");
      print "ok 2", "\n" if right->isa("outer::$tail");
      print "ok 3", "\n" if right->isa("clone::$tail");
      print "ok 4", "\n" if left->isa("outer::$tail");
    ~ =~ s\__code__\$$_{code}\r,
   "ok 1\nok 2\nok 3\nok 4\n",
    { args => [$tail] },
   "replacing nonexistent nested packages by $$_{name} updates isa caches"
     ." ($tail)";

  # Same test but with the subpackage autovivified after the assignment
  fresh_perl_is
    q~
      my $tail = shift;
      @left::ISA = "outer::$tail";
      @right::ISA = "clone::$tail";

     __code__;

      bless [], "outer::$tail";

      print "ok 1", "\n" if left->isa("clone::$tail");
      print "ok 2", "\n" if right->isa("outer::$tail");
      print "ok 3", "\n" if right->isa("clone::$tail");
      print "ok 4", "\n" if left->isa("outer::$tail");
    ~ =~ s\__code__\$$_{code}\r,
   "ok 1\nok 2\nok 3\nok 4\n",
    { args => [$tail] },
   "Giving nonexistent packages multiple effective names by $$_{name}"
     . " ($tail)";
 }
}

no warnings; # temporary; there seems to be a scoping bug, as this does not
             # work when placed in the blocks below

# Test that deleting stash elements containing
# subpackages also invalidates the isa cache.
# Maybe this does not belong in package_aliases.t, but it is closely
# related to the tests immediately preceding.
{
 @Pet::ISA = ("Cur", "Hound");
 @Cur::ISA = "Hylactete";

 sub Hylactete::speak { "Arff!" }
 sub Hound::speak { "Woof!" }

 my $pet = bless [], "Pet";

 my $life_raft = delete $::{'Cur::'};

 is $pet->speak, 'Woof!',
  'deleting a stash from its parent stash invalidates the isa caches';

 undef $life_raft;
 is $pet->speak, 'Woof!',
  'the deleted stash is gone completely when freed';
}
# Same thing, but with nested packages
{
 @Pett::ISA = ("Curr::Curr::Curr", "Hownd");
 @Curr::Curr::Curr::ISA = "Latrator";

 sub Latrator::speak { "Arff!" }
 sub Hownd::speak { "Woof!" }

 my $pet = bless [], "Pett";

 my $life_raft = delete $::{'Curr::'};

 is $pet->speak, 'Woof!',
  'deleting a stash from its parent stash resets caches of substashes';

 undef $life_raft;
 is $pet->speak, 'Woof!',
  'the deleted substash is gone completely when freed';
}

# [perl #77358]
fresh_perl_is
   q~#!perl -w
     @Pet::ISA = "Tike";
     @Tike::ISA = "Barker";
     
     sub Barker::speak { print "Woof!\n" }
     sub Latrator::speak { print "Bow-wow!\n" }
     
     my $pet = bless [], "Pet";
     
     $pet->speak;
     
     sub Dog::speak { print "Hello.\n" } # strange dog!
     @Dog::ISA = 'Latrator';
     *Tike:: = delete $::{'Dog::'};
     
     $pet->speak;
   ~,
  "Woof!\nHello.\n",
   { stderr => 1 },
  "Assigning a nameless package over one w/subclasses updates isa caches";

# mro_package_moved needs to make a distinction between replaced and
# assigned stashes when keeping track of what it has seen so far.
no warnings; {
    no strict 'refs';

    sub bar::blonk::blonk::phoo { "bbb" }
    sub veclum::phoo { "lasrevinu" }
    @feedlebomp::ISA = qw 'phoo::blonk::blonk veclum';
    *phoo::baz:: = *bar::blonk::;   # now bar::blonk:: is on both sides
    *phoo:: = *bar::;         # here bar::blonk:: is both deleted and added
    *bar:: = *boo::;          # now it is only known as phoo::blonk::

    # At this point, before the bug was fixed, %phoo::blonk::blonk:: ended
    # up with no effective name, allowing it to be deleted without updating
    # its subclasses’ caches.

    my $accum = '';

    $accum .= 'feedlebomp'->phoo;          # bbb
    delete ${"phoo::blonk::"}{"blonk::"};
    $accum .= 'feedlebomp'->phoo;          # bbb (Oops!)
    @feedlebomp::ISA = @feedlebomp::ISA;
    $accum .= 'feedlebomp'->phoo;          # lasrevinu

    is $accum, 'bbblasrevinulasrevinu',
      'nested classes deleted & added simultaneously';
}
use warnings;

# mro_package_moved needs to check for self-referential packages.
# This broke Text::Template [perl #78362].
watchdog 3;
*foo:: = \%::;
*Acme::META::Acme:: = \*Acme::; # indirect self-reference
pass("mro_package_moved and self-referential packages");

# Deleting a glob whose name does not indicate its location in the symbol
# table but which nonetheless *is* in the symbol table.
{
    no strict refs=>;
    no warnings;
    @one::more::ISA = "four";
    sub four::womp { "aoeaa" }
    *two:: = *one::;
    delete $::{"one::"};
    @Childclass::ISA = 'two::more';
    my $accum = 'Childclass'->womp . '-';
    my $life_raft = delete ${"two::"}{"more::"};
    $accum .= eval { 'Childclass'->womp } // '<undef>';
    is $accum, 'aoeaa-<undef>',
     'Deleting globs whose loc in the symtab differs from gv_fullname'
}

# Pathological test for undeffing a stash that has an alias.
*Ghelp:: = *Neen::;
@Subclass::ISA = 'Ghelp';
undef %Ghelp::;
sub Frelp::womp { "clumpren" }
eval '
  $Neen::whatever++;
  @Neen::ISA = "Frelp";
';
is eval { 'Subclass'->womp }, 'clumpren',
 'Changes to @ISA after undef via original name';
undef %Ghelp::;
eval '
  $Ghelp::whatever++;
  @Ghelp::ISA = "Frelp";
';
is eval { 'Subclass'->womp }, 'clumpren',
 'Changes to @ISA after undef via alias';


# Packages whose containing stashes have aliases must lose all names cor-
# responding to that container when detached.
{
 {package smare::baz} # autovivify
 *phring:: = *smare::;  # smare::baz now also named phring::baz
 *bonk:: = delete $smare::{"baz::"};
 # In 5.13.7, it has now lost its smare::baz name (reverting to phring::baz
 # as the effective name), and gained bonk as an alias.
 # In 5.13.8, both smare::baz *and* phring::baz names are deleted.

 # Make some methods
 no strict 'refs';
 *{"phring::baz::frump"} = sub { "hello" };
 sub frumper::frump { "good bye" };

 @brumkin::ISA = qw "bonk frumper"; # now wrongly inherits from phring::baz

 is frump brumkin, "good bye",
  'detached stashes lose all names corresponding to the containing stash';
}

# Crazy edge cases involving packages ending with a single :
@Colon::ISA = 'Organ:'; # pun intended!
bless [], "Organ:"; # autovivify the stash
ok "Colon"->isa("Organ:"), 'class isa "class:"';
{ no strict 'refs'; *{"Organ:::"} = *Organ:: }
ok "Colon"->isa("Organ"),
 'isa(foo) when inheriting from "class:" which is an alias for foo';
{
 no warnings;
 # The next line of code is *not* normative. If the structure changes,
 # this line needs to change, too.
 my $foo = delete $Organ::{":"};
 ok !Colon->isa("Organ"),
  'class that isa "class:" no longer isa foo if "class:" has been deleted';
}
@Colon::ISA = ':';
bless [], ":";
ok "Colon"->isa(":"), 'class isa ":"';
{ no strict 'refs'; *{":::"} = *Punctuation:: }
ok "Colon"->isa("Punctuation"),
 'isa(foo) when inheriting from ":" which is an alias for foo';
@Colon::ISA = 'Organ:';
bless [], "Organ:";
{
 no strict 'refs';
 my $life_raft = \%{"Organ:::"};
 *{"Organ:::"} = \%Organ::;
 ok "Colon"->isa("Organ"),
  'isa(foo) when inheriting from "class:" after hash-to-glob assignment';
}
@Colon::ISA = 'O:';
bless [], "O:";
{
 no strict 'refs';
 my $life_raft = \%{"O:::"};
 *{"O:::"} = "Organ::";
 ok "Colon"->isa("Organ"),
  'isa(foo) when inheriting from "class:" after string-to-glob assignment';
}



SCRIPT

subtest 'tokenize' => sub {
    my $tokens = Compiler::Lexer->new('')->tokenize($script);
    is_deeply($$tokens, [
          bless( {
                   'kind' => 9,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'ModWord',
                   'data' => 'BEGIN',
                   'type' => 69,
                   'line' => 3
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 3
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UnlessStmt',
                   'data' => 'unless',
                   'type' => 92,
                   'line' => 4
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 4
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 13,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Handle',
                   'data' => '-d',
                   'type' => 83,
                   'line' => 4
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'blib',
                   'type' => 164,
                   'line' => 4
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 4
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 4
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'chdir',
                   'type' => 64,
                   'line' => 5
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 't',
                   'type' => 164,
                   'line' => 5
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'IfStmt',
                   'data' => 'if',
                   'type' => 89,
                   'line' => 5
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 13,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Handle',
                   'data' => '-d',
                   'type' => 83,
                   'line' => 5
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 't',
                   'type' => 164,
                   'line' => 5
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 5
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LibraryDirectories',
                   'data' => '@INC',
                   'type' => 132,
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '../lib',
                   'type' => 164,
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 7
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RequireDecl',
                   'data' => 'require',
                   'type' => 65,
                   'line' => 8
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegQuote',
                   'data' => 'q',
                   'type' => 137,
                   'line' => 8
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '(',
                   'type' => 143,
                   'line' => 8
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => './test.pl',
                   'type' => 172,
                   'line' => 8
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => ')',
                   'type' => 143,
                   'line' => 8
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 8
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 9
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 11
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'strict',
                   'type' => 88,
                   'line' => 11
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 11
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 12
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'warnings',
                   'type' => 88,
                   'line' => 12
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 12
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'plan',
                   'type' => 114,
                   'line' => 13
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 13
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'tests',
                   'type' => 114,
                   'line' => 13
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'type' => 116,
                   'line' => 13
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Int',
                   'data' => '52',
                   'type' => 161,
                   'line' => 13
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 13
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 13
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 15
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Package',
                   'data' => 'package',
                   'type' => 120,
                   'line' => 16
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Class',
                   'data' => 'New',
                   'type' => 121,
                   'line' => 16
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 16
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 17
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'strict',
                   'type' => 88,
                   'line' => 17
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 17
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 18
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'warnings',
                   'type' => 88,
                   'line' => 18
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 18
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Package',
                   'data' => 'package',
                   'type' => 120,
                   'line' => 20
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Class',
                   'data' => 'Old',
                   'type' => 121,
                   'line' => 20
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 20
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 21
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'strict',
                   'type' => 88,
                   'line' => 21
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 21
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 22
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'warnings',
                   'type' => 88,
                   'line' => 22
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 22
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 24
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'no',
                   'type' => 64,
                   'line' => 25
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'strict',
                   'type' => 114,
                   'line' => 25
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'refs',
                   'type' => 164,
                   'line' => 25
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 25
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Mul',
                   'data' => '*',
                   'type' => 3,
                   'line' => 26
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 26
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'Old::',
                   'type' => 164,
                   'line' => 26
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 26
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 26
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Mul',
                   'data' => '*',
                   'type' => 3,
                   'line' => 26
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 26
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'New::',
                   'type' => 164,
                   'line' => 26
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 26
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 26
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 27
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 28
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'ok',
                   'type' => 114,
                   'line' => 30
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 30
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Class',
                   'data' => 'Old',
                   'type' => 121,
                   'line' => 30
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Pointer',
                   'data' => '->',
                   'type' => 117,
                   'line' => 30
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Method',
                   'data' => 'isa',
                   'type' => 59,
                   'line' => 30
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 30
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'New',
                   'type' => 119,
                   'line' => 30
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 30
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => ')',
                   'type' => 119,
                   'line' => 30
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 30
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'Old inherits from New',
                   'type' => 164,
                   'line' => 30
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 30
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 30
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'ok',
                   'type' => 114,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Class',
                   'data' => 'New',
                   'type' => 121,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Pointer',
                   'data' => '->',
                   'type' => 117,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Method',
                   'data' => 'isa',
                   'type' => 59,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'Old',
                   'type' => 119,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => ')',
                   'type' => 119,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'New inherits from Old',
                   'type' => 164,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 31
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'object_ok',
                   'type' => 114,
                   'line' => 33
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 33
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'bless',
                   'type' => 64,
                   'line' => 33
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 33
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 33
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 33
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 33
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'Old',
                   'type' => 119,
                   'line' => 33
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 33
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => ')',
                   'type' => 119,
                   'line' => 33
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 33
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'New',
                   'type' => 119,
                   'line' => 33
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 33
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => ',',
                   'type' => 119,
                   'line' => 33
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'Old object',
                   'type' => 164,
                   'line' => 33
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 33
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 33
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'object_ok',
                   'type' => 114,
                   'line' => 34
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 34
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'bless',
                   'type' => 64,
                   'line' => 34
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 34
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 34
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 34
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 34
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'New',
                   'type' => 119,
                   'line' => 34
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 34
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => ')',
                   'type' => 119,
                   'line' => 34
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 34
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'Old',
                   'type' => 119,
                   'line' => 34
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 34
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => ',',
                   'type' => 119,
                   'line' => 34
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'New object',
                   'type' => 164,
                   'line' => 34
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 34
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 34
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'ForStmt',
                   'data' => 'for',
                   'type' => 125,
                   'line' => 39
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 39
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 40
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'name',
                   'type' => 114,
                   'line' => 41
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'type' => 116,
                   'line' => 41
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'assigning a glob to a glob',
                   'type' => 164,
                   'line' => 41
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 41
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'code',
                   'type' => 114,
                   'line' => 42
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'type' => 116,
                   'line' => 42
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '$life_raft = $::{"Left::"}; *Left:: = $::{"Right::"}',
                   'type' => 164,
                   'line' => 42
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 42
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 43
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 43
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 44
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'name',
                   'type' => 114,
                   'line' => 45
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'type' => 116,
                   'line' => 45
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'assigning a string to a glob',
                   'type' => 164,
                   'line' => 45
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 45
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'code',
                   'type' => 114,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'type' => 116,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '$life_raft = $::{"Left::"}; *Left:: = "Right::"',
                   'type' => 164,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 46
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 47
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 47
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 48
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'name',
                   'type' => 114,
                   'line' => 49
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'type' => 116,
                   'line' => 49
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'assigning a stashref to a glob',
                   'type' => 164,
                   'line' => 49
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 49
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'code',
                   'type' => 114,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'type' => 116,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '$life_raft = \\%Left::; *Left:: = \\%Right::',
                   'type' => 164,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 50
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 51
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 51
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 52
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 52
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'fresh_perl_is',
                   'type' => 114,
                   'line' => 54
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegQuote',
                   'data' => 'q',
                   'type' => 137,
                   'line' => 54
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '~',
                   'type' => 143,
                   'line' => 54
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => '
     @Subclass::ISA = "Left";
     @Left::ISA = "TopLeft";

     sub TopLeft::speak { "Woof!" }
     sub TopRight::speak { "Bow-wow!" }

     my $thing = bless [], "Subclass";

     # mro_package_moved needs to know to skip non-globs
     $Right::{"gleck::"} = 3;

     @Right::ISA = \'TopRight\';
     my $life_raft;
    __code__;

     print $thing->speak, "\\n";

     undef $life_raft;
     print $thing->speak, "\\n";
   ',
                   'type' => 172,
                   'line' => 74
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '~',
                   'type' => 143,
                   'line' => 74
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegOK',
                   'data' => '=~',
                   'type' => 31,
                   'line' => 74
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Ref',
                   'data' => '\\',
                   'type' => 10,
                   'line' => 74
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 's__code__',
                   'type' => 114,
                   'line' => 74
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 28,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'ShortScalarDereference',
                   'data' => '$$',
                   'type' => 109,
                   'line' => 74
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => '_',
                   'type' => 114,
                   'line' => 74
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 74
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'code',
                   'type' => 114,
                   'line' => 74
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 74
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'r',
                   'type' => 114,
                   'line' => 74
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 74
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Bow-wow!\\nBow-wow!\\n',
                   'type' => 163,
                   'line' => 75
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 75
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'replacing packages by $$_{name} updates isa caches',
                   'type' => 163,
                   'line' => 77
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 77
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 78
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'ForStmt',
                   'data' => 'for',
                   'type' => 125,
                   'line' => 90
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 90
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 91
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'name',
                   'type' => 114,
                   'line' => 92
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'type' => 116,
                   'line' => 92
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'assigning a glob to a glob',
                   'type' => 164,
                   'line' => 92
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 92
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'code',
                   'type' => 114,
                   'line' => 93
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'type' => 116,
                   'line' => 93
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '$life_raft = $::{"Left::"}; *Left:: = $::{"Right::"}',
                   'type' => 164,
                   'line' => 93
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 93
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 94
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 94
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 95
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'name',
                   'type' => 114,
                   'line' => 96
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'type' => 116,
                   'line' => 96
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'assigning a string to a glob',
                   'type' => 164,
                   'line' => 96
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 96
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'code',
                   'type' => 114,
                   'line' => 97
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'type' => 116,
                   'line' => 97
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '$life_raft = $::{"Left::"}; *Left:: = "Right::"',
                   'type' => 164,
                   'line' => 97
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 97
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 98
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 98
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 99
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'name',
                   'type' => 114,
                   'line' => 100
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'type' => 116,
                   'line' => 100
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'assigning a stashref to a glob',
                   'type' => 164,
                   'line' => 100
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 100
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'code',
                   'type' => 114,
                   'line' => 101
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'type' => 116,
                   'line' => 101
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '$life_raft = \\%Left::; *Left:: = \\%Right::',
                   'type' => 164,
                   'line' => 101
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 101
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 102
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 102
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 103
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 103
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'fresh_perl_is',
                   'type' => 114,
                   'line' => 105
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegQuote',
                   'data' => 'q',
                   'type' => 137,
                   'line' => 105
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '~',
                   'type' => 143,
                   'line' => 105
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => '
     @Subclass::ISA = "Left::Side";
     @Left::Side::ISA = "TopLeft";

     sub TopLeft::speak { "Woof!" }
     sub TopRight::speak { "Bow-wow!" }

     my $thing = bless [], "Subclass";

     @Right::Side::ISA = \'TopRight\';
     my $life_raft;
    __code__;

     print $thing->speak, "\\n";

     undef $life_raft;
     print $thing->speak, "\\n";
   ',
                   'type' => 172,
                   'line' => 122
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '~',
                   'type' => 143,
                   'line' => 122
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegOK',
                   'data' => '=~',
                   'type' => 31,
                   'line' => 122
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Ref',
                   'data' => '\\',
                   'type' => 10,
                   'line' => 122
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 's__code__',
                   'type' => 114,
                   'line' => 122
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 28,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'ShortScalarDereference',
                   'data' => '$$',
                   'type' => 109,
                   'line' => 122
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => '_',
                   'type' => 114,
                   'line' => 122
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 122
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'code',
                   'type' => 114,
                   'line' => 122
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 122
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'r',
                   'type' => 114,
                   'line' => 122
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 122
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Bow-wow!\\nBow-wow!\\n',
                   'type' => 163,
                   'line' => 123
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 123
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 124
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 124
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 124
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'replacing nested packages by $$_{name} updates isa caches',
                   'type' => 163,
                   'line' => 125
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 125
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 126
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'ForStmt',
                   'data' => 'for',
                   'type' => 125,
                   'line' => 143
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 143
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 144
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'name',
                   'type' => 114,
                   'line' => 145
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'type' => 116,
                   'line' => 145
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'assigning a glob to a glob',
                   'type' => 164,
                   'line' => 145
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 145
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'code',
                   'type' => 114,
                   'line' => 146
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'type' => 116,
                   'line' => 146
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '*clone:: = *outer::',
                   'type' => 164,
                   'line' => 146
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 146
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 147
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 147
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 148
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'name',
                   'type' => 114,
                   'line' => 149
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'type' => 116,
                   'line' => 149
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'assigning a string to a glob',
                   'type' => 164,
                   'line' => 149
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 149
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'code',
                   'type' => 114,
                   'line' => 150
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'type' => 116,
                   'line' => 150
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '*clone:: = "outer::"',
                   'type' => 164,
                   'line' => 150
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 150
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 151
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 151
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 152
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'name',
                   'type' => 114,
                   'line' => 153
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'type' => 116,
                   'line' => 153
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'assigning a stashref to a glob',
                   'type' => 164,
                   'line' => 153
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 153
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'code',
                   'type' => 114,
                   'line' => 154
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'type' => 116,
                   'line' => 154
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '*clone:: = \\%outer::',
                   'type' => 164,
                   'line' => 154
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 154
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 155
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 155
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 156
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 156
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'ForStmt',
                   'data' => 'for',
                   'type' => 125,
                   'line' => 157
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 157
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$tail',
                   'type' => 176,
                   'line' => 157
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 157
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'inner',
                   'type' => 164,
                   'line' => 157
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 157
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'inner::',
                   'type' => 164,
                   'line' => 157
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 157
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'inner:::',
                   'type' => 164,
                   'line' => 157
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 157
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'inner::::',
                   'type' => 164,
                   'line' => 157
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 157
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 157
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'fresh_perl_is',
                   'type' => 114,
                   'line' => 159
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegQuote',
                   'data' => 'q',
                   'type' => 137,
                   'line' => 159
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '~',
                   'type' => 143,
                   'line' => 159
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => '
      my $tail = shift;
      @left::ISA = "outer::$tail";
      @right::ISA = "clone::$tail";
      bless [], "outer::$tail"; # autovivify the stash

     __code__;

      print "ok 1", "\\n" if left->isa("clone::$tail");
      print "ok 2", "\\n" if right->isa("outer::$tail");
      print "ok 3", "\\n" if right->isa("clone::$tail");
      print "ok 4", "\\n" if left->isa("outer::$tail");
    ',
                   'type' => 172,
                   'line' => 171
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '~',
                   'type' => 143,
                   'line' => 171
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegOK',
                   'data' => '=~',
                   'type' => 31,
                   'line' => 171
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Ref',
                   'data' => '\\',
                   'type' => 10,
                   'line' => 171
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 's__code__',
                   'type' => 114,
                   'line' => 171
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 28,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'ShortScalarDereference',
                   'data' => '$$',
                   'type' => 109,
                   'line' => 171
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => '_',
                   'type' => 114,
                   'line' => 171
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 171
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'code',
                   'type' => 114,
                   'line' => 171
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 171
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'r',
                   'type' => 114,
                   'line' => 171
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 171
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'ok 1\\nok 2\\nok 3\\nok 4\\n',
                   'type' => 163,
                   'line' => 172
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 172
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 173
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'args',
                   'type' => 114,
                   'line' => 173
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'type' => 116,
                   'line' => 173
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'type' => 104,
                   'line' => 173
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$tail',
                   'type' => 157,
                   'line' => 173
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBracket',
                   'data' => ']',
                   'type' => 105,
                   'line' => 173
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 173
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 173
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'replacing nonexistent nested packages by $$_{name} updates isa caches',
                   'type' => 163,
                   'line' => 174
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringAdd',
                   'data' => '.',
                   'type' => 9,
                   'line' => 175
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => ' ($tail)',
                   'type' => 163,
                   'line' => 175
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 175
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'fresh_perl_is',
                   'type' => 114,
                   'line' => 179
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegQuote',
                   'data' => 'q',
                   'type' => 137,
                   'line' => 179
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '~',
                   'type' => 143,
                   'line' => 179
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => '
      my $tail = shift;
      @left::ISA = "outer::$tail";
      @right::ISA = "clone::$tail";

     __code__;

      bless [], "outer::$tail";

      print "ok 1", "\\n" if left->isa("clone::$tail");
      print "ok 2", "\\n" if right->isa("outer::$tail");
      print "ok 3", "\\n" if right->isa("clone::$tail");
      print "ok 4", "\\n" if left->isa("outer::$tail");
    ',
                   'type' => 172,
                   'line' => 192
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '~',
                   'type' => 143,
                   'line' => 192
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegOK',
                   'data' => '=~',
                   'type' => 31,
                   'line' => 192
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Ref',
                   'data' => '\\',
                   'type' => 10,
                   'line' => 192
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 's__code__',
                   'type' => 114,
                   'line' => 192
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 28,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'ShortScalarDereference',
                   'data' => '$$',
                   'type' => 109,
                   'line' => 192
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => '_',
                   'type' => 114,
                   'line' => 192
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 192
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'code',
                   'type' => 114,
                   'line' => 192
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 192
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'r',
                   'type' => 114,
                   'line' => 192
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 192
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'ok 1\\nok 2\\nok 3\\nok 4\\n',
                   'type' => 163,
                   'line' => 193
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 193
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 194
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'args',
                   'type' => 114,
                   'line' => 194
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'type' => 116,
                   'line' => 194
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'type' => 104,
                   'line' => 194
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$tail',
                   'type' => 157,
                   'line' => 194
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBracket',
                   'data' => ']',
                   'type' => 105,
                   'line' => 194
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 194
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 194
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Giving nonexistent packages multiple effective names by $$_{name}',
                   'type' => 163,
                   'line' => 195
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringAdd',
                   'data' => '.',
                   'type' => 9,
                   'line' => 196
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => ' ($tail)',
                   'type' => 163,
                   'line' => 196
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 196
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 197
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 198
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'no',
                   'type' => 64,
                   'line' => 200
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'warnings',
                   'type' => 114,
                   'line' => 200
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 200
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 207
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '@Pet',
                   'type' => 119,
                   'line' => 208
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 208
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'ISA',
                   'type' => 119,
                   'line' => 208
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 208
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 208
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Cur',
                   'type' => 163,
                   'line' => 208
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 208
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Hound',
                   'type' => 163,
                   'line' => 208
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 208
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 208
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '@Cur',
                   'type' => 119,
                   'line' => 209
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 209
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'ISA',
                   'type' => 119,
                   'line' => 209
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 209
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Hylactete',
                   'type' => 163,
                   'line' => 209
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 209
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'FunctionDecl',
                   'data' => 'sub',
                   'type' => 58,
                   'line' => 211
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'Hylactete',
                   'type' => 119,
                   'line' => 211
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 211
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'speak',
                   'type' => 119,
                   'line' => 211
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 211
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Arff!',
                   'type' => 163,
                   'line' => 211
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 211
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'FunctionDecl',
                   'data' => 'sub',
                   'type' => 58,
                   'line' => 212
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'Hound',
                   'type' => 119,
                   'line' => 212
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 212
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'speak',
                   'type' => 119,
                   'line' => 212
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 212
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Woof!',
                   'type' => 163,
                   'line' => 212
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 212
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 214
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$pet',
                   'type' => 176,
                   'line' => 214
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 214
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'bless',
                   'type' => 64,
                   'line' => 214
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'type' => 104,
                   'line' => 214
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBracket',
                   'data' => ']',
                   'type' => 105,
                   'line' => 214
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 214
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Pet',
                   'type' => 163,
                   'line' => 214
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 214
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 216
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$life_raft',
                   'type' => 176,
                   'line' => 216
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 216
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'delete',
                   'type' => 64,
                   'line' => 216
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SpecificValue',
                   'data' => '$:',
                   'type' => 129,
                   'line' => 216
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 25,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Colon',
                   'data' => ':',
                   'type' => 98,
                   'line' => 216
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 216
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'Cur::',
                   'type' => 164,
                   'line' => 216
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 216
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 216
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'is',
                   'type' => 114,
                   'line' => 218
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$pet',
                   'type' => 157,
                   'line' => 218
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Pointer',
                   'data' => '->',
                   'type' => 117,
                   'line' => 218
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Method',
                   'data' => 'speak',
                   'type' => 59,
                   'line' => 218
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 218
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'Woof!',
                   'type' => 164,
                   'line' => 218
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 218
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'deleting a stash from its parent stash invalidates the isa caches',
                   'type' => 164,
                   'line' => 219
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 219
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Default',
                   'data' => 'undef',
                   'type' => 192,
                   'line' => 221
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$life_raft',
                   'type' => 157,
                   'line' => 221
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 221
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'is',
                   'type' => 114,
                   'line' => 222
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$pet',
                   'type' => 157,
                   'line' => 222
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Pointer',
                   'data' => '->',
                   'type' => 117,
                   'line' => 222
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Method',
                   'data' => 'speak',
                   'type' => 59,
                   'line' => 222
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 222
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'Woof!',
                   'type' => 164,
                   'line' => 222
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 222
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'the deleted stash is gone completely when freed',
                   'type' => 164,
                   'line' => 223
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 223
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 224
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 226
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '@Pett',
                   'type' => 119,
                   'line' => 227
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 227
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'ISA',
                   'type' => 119,
                   'line' => 227
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 227
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 227
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Curr::Curr::Curr',
                   'type' => 163,
                   'line' => 227
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 227
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Hownd',
                   'type' => 163,
                   'line' => 227
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 227
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 227
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '@Curr',
                   'type' => 119,
                   'line' => 228
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 228
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'Curr',
                   'type' => 119,
                   'line' => 228
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 228
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'Curr',
                   'type' => 119,
                   'line' => 228
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 228
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'ISA',
                   'type' => 119,
                   'line' => 228
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 228
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Latrator',
                   'type' => 163,
                   'line' => 228
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 228
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'FunctionDecl',
                   'data' => 'sub',
                   'type' => 58,
                   'line' => 230
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'Latrator',
                   'type' => 119,
                   'line' => 230
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 230
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'speak',
                   'type' => 119,
                   'line' => 230
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 230
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Arff!',
                   'type' => 163,
                   'line' => 230
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 230
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'FunctionDecl',
                   'data' => 'sub',
                   'type' => 58,
                   'line' => 231
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'Hownd',
                   'type' => 119,
                   'line' => 231
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 231
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'speak',
                   'type' => 119,
                   'line' => 231
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 231
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Woof!',
                   'type' => 163,
                   'line' => 231
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 231
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 233
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$pet',
                   'type' => 176,
                   'line' => 233
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 233
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'bless',
                   'type' => 64,
                   'line' => 233
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'type' => 104,
                   'line' => 233
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBracket',
                   'data' => ']',
                   'type' => 105,
                   'line' => 233
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 233
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Pett',
                   'type' => 163,
                   'line' => 233
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 233
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 235
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$life_raft',
                   'type' => 176,
                   'line' => 235
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 235
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'delete',
                   'type' => 64,
                   'line' => 235
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SpecificValue',
                   'data' => '$:',
                   'type' => 129,
                   'line' => 235
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 25,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Colon',
                   'data' => ':',
                   'type' => 98,
                   'line' => 235
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 235
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'Curr::',
                   'type' => 164,
                   'line' => 235
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 235
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 235
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'is',
                   'type' => 114,
                   'line' => 237
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$pet',
                   'type' => 157,
                   'line' => 237
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Pointer',
                   'data' => '->',
                   'type' => 117,
                   'line' => 237
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Method',
                   'data' => 'speak',
                   'type' => 59,
                   'line' => 237
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 237
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'Woof!',
                   'type' => 164,
                   'line' => 237
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 237
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'deleting a stash from its parent stash resets caches of substashes',
                   'type' => 164,
                   'line' => 238
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 238
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Default',
                   'data' => 'undef',
                   'type' => 192,
                   'line' => 240
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$life_raft',
                   'type' => 157,
                   'line' => 240
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 240
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'is',
                   'type' => 114,
                   'line' => 241
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$pet',
                   'type' => 157,
                   'line' => 241
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Pointer',
                   'data' => '->',
                   'type' => 117,
                   'line' => 241
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Method',
                   'data' => 'speak',
                   'type' => 59,
                   'line' => 241
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 241
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'Woof!',
                   'type' => 164,
                   'line' => 241
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 241
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'the deleted substash is gone completely when freed',
                   'type' => 164,
                   'line' => 242
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 242
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 243
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'fresh_perl_is',
                   'type' => 114,
                   'line' => 247
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegQuote',
                   'data' => 'q',
                   'type' => 137,
                   'line' => 247
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '~',
                   'type' => 143,
                   'line' => 247
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => '#!perl -w
     @Pet::ISA = "Tike";
     @Tike::ISA = "Barker";
     
     sub Barker::speak { print "Woof!\\n" }
     sub Latrator::speak { print "Bow-wow!\\n" }
     
     my $pet = bless [], "Pet";
     
     $pet->speak;
     
     sub Dog::speak { print "Hello.\\n" } # strange dog!
     @Dog::ISA = \'Latrator\';
     *Tike:: = delete $::{\'Dog::\'};
     
     $pet->speak;
   ',
                   'type' => 172,
                   'line' => 263
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '~',
                   'type' => 143,
                   'line' => 263
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 263
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Woof!\\nHello.\\n',
                   'type' => 163,
                   'line' => 264
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 264
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 265
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'stderr',
                   'type' => 114,
                   'line' => 265
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'type' => 116,
                   'line' => 265
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Int',
                   'data' => '1',
                   'type' => 161,
                   'line' => 265
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 265
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 265
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Assigning a nameless package over one w/subclasses updates isa caches',
                   'type' => 163,
                   'line' => 266
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 266
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'no',
                   'type' => 64,
                   'line' => 270
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'warnings',
                   'type' => 114,
                   'line' => 270
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 270
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 270
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'no',
                   'type' => 64,
                   'line' => 271
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'strict',
                   'type' => 114,
                   'line' => 271
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'refs',
                   'type' => 164,
                   'line' => 271
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 271
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'FunctionDecl',
                   'data' => 'sub',
                   'type' => 58,
                   'line' => 273
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'bar',
                   'type' => 119,
                   'line' => 273
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 273
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'blonk',
                   'type' => 119,
                   'line' => 273
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 273
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'blonk',
                   'type' => 119,
                   'line' => 273
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 273
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'phoo',
                   'type' => 119,
                   'line' => 273
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 273
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'bbb',
                   'type' => 163,
                   'line' => 273
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 273
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'FunctionDecl',
                   'data' => 'sub',
                   'type' => 58,
                   'line' => 274
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'veclum',
                   'type' => 119,
                   'line' => 274
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 274
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'phoo',
                   'type' => 119,
                   'line' => 274
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 274
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'lasrevinu',
                   'type' => 163,
                   'line' => 274
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 274
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '@feedlebomp',
                   'type' => 119,
                   'line' => 275
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 275
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'ISA',
                   'type' => 119,
                   'line' => 275
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 275
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegList',
                   'data' => 'qw',
                   'type' => 139,
                   'line' => 275
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'phoo::blonk::blonk veclum',
                   'type' => 164,
                   'line' => 275
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 275
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Mul',
                   'data' => '*',
                   'type' => 3,
                   'line' => 276
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'phoo',
                   'type' => 119,
                   'line' => 276
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 276
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'baz',
                   'type' => 119,
                   'line' => 276
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 276
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '=',
                   'type' => 119,
                   'line' => 276
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Mul',
                   'data' => '*',
                   'type' => 3,
                   'line' => 276
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'bar',
                   'type' => 119,
                   'line' => 276
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 276
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'blonk',
                   'type' => 119,
                   'line' => 276
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 276
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => ';',
                   'type' => 119,
                   'line' => 276
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Mul',
                   'data' => '*',
                   'type' => 3,
                   'line' => 277
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'phoo',
                   'type' => 119,
                   'line' => 277
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 277
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '=',
                   'type' => 119,
                   'line' => 277
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Mul',
                   'data' => '*',
                   'type' => 3,
                   'line' => 277
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'bar',
                   'type' => 119,
                   'line' => 277
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 277
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => ';',
                   'type' => 119,
                   'line' => 277
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Mul',
                   'data' => '*',
                   'type' => 3,
                   'line' => 278
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'bar',
                   'type' => 119,
                   'line' => 278
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 278
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '=',
                   'type' => 119,
                   'line' => 278
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Mul',
                   'data' => '*',
                   'type' => 3,
                   'line' => 278
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'boo',
                   'type' => 119,
                   'line' => 278
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 278
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => ';',
                   'type' => 119,
                   'line' => 278
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 284
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$accum',
                   'type' => 176,
                   'line' => 284
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 284
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '',
                   'type' => 164,
                   'line' => 284
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 284
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$accum',
                   'type' => 157,
                   'line' => 286
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringAdd',
                   'data' => '.=',
                   'type' => 9,
                   'line' => 286
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'feedlebomp',
                   'type' => 164,
                   'line' => 286
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Pointer',
                   'data' => '->',
                   'type' => 117,
                   'line' => 286
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Method',
                   'data' => 'phoo',
                   'type' => 59,
                   'line' => 286
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 286
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'delete',
                   'type' => 64,
                   'line' => 287
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 28,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'ScalarDereference',
                   'data' => '${',
                   'type' => 108,
                   'line' => 287
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'phoo::blonk::',
                   'type' => 163,
                   'line' => 287
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 287
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 287
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'blonk::',
                   'type' => 163,
                   'line' => 287
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 287
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 287
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$accum',
                   'type' => 157,
                   'line' => 288
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringAdd',
                   'data' => '.=',
                   'type' => 9,
                   'line' => 288
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'feedlebomp',
                   'type' => 164,
                   'line' => 288
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Pointer',
                   'data' => '->',
                   'type' => 117,
                   'line' => 288
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Method',
                   'data' => 'phoo',
                   'type' => 59,
                   'line' => 288
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 288
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '@feedlebomp',
                   'type' => 119,
                   'line' => 289
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 289
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'ISA',
                   'type' => 119,
                   'line' => 289
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 289
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '@feedlebomp',
                   'type' => 119,
                   'line' => 289
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 289
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'ISA',
                   'type' => 119,
                   'line' => 289
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 289
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$accum',
                   'type' => 157,
                   'line' => 290
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringAdd',
                   'data' => '.=',
                   'type' => 9,
                   'line' => 290
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'feedlebomp',
                   'type' => 164,
                   'line' => 290
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Pointer',
                   'data' => '->',
                   'type' => 117,
                   'line' => 290
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Method',
                   'data' => 'phoo',
                   'type' => 59,
                   'line' => 290
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 290
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'is',
                   'type' => 114,
                   'line' => 292
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$accum',
                   'type' => 157,
                   'line' => 292
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 292
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'bbblasrevinulasrevinu',
                   'type' => 164,
                   'line' => 292
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 292
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'nested classes deleted & added simultaneously',
                   'type' => 164,
                   'line' => 293
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 293
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 294
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UseDecl',
                   'data' => 'use',
                   'type' => 87,
                   'line' => 295
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UsedName',
                   'data' => 'warnings',
                   'type' => 88,
                   'line' => 295
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 295
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'watchdog',
                   'type' => 114,
                   'line' => 299
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Int',
                   'data' => '3',
                   'type' => 161,
                   'line' => 299
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 299
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Mul',
                   'data' => '*',
                   'type' => 3,
                   'line' => 300
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'foo',
                   'type' => 119,
                   'line' => 300
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 300
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '=',
                   'type' => 119,
                   'line' => 300
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Ref',
                   'data' => '\\',
                   'type' => 10,
                   'line' => 300
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '%',
                   'type' => 119,
                   'line' => 300
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 300
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => ';',
                   'type' => 119,
                   'line' => 300
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Mul',
                   'data' => '*',
                   'type' => 3,
                   'line' => 301
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'Acme',
                   'type' => 119,
                   'line' => 301
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 301
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'META',
                   'type' => 119,
                   'line' => 301
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 301
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'Acme',
                   'type' => 119,
                   'line' => 301
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 301
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '=',
                   'type' => 119,
                   'line' => 301
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Mul',
                   'data' => '*',
                   'type' => 3,
                   'line' => 301
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'Acme',
                   'type' => 119,
                   'line' => 301
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 301
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => ';',
                   'type' => 119,
                   'line' => 301
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'pass',
                   'type' => 114,
                   'line' => 302
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 302
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'mro_package_moved and self-referential packages',
                   'type' => 163,
                   'line' => 302
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 302
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 302
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 306
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'no',
                   'type' => 64,
                   'line' => 307
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'strict',
                   'type' => 114,
                   'line' => 307
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'refs',
                   'type' => 114,
                   'line' => 307
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Arrow',
                   'data' => '=>',
                   'type' => 116,
                   'line' => 307
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 307
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'no',
                   'type' => 64,
                   'line' => 308
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'warnings',
                   'type' => 114,
                   'line' => 308
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 308
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '@one',
                   'type' => 119,
                   'line' => 309
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 309
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'more',
                   'type' => 119,
                   'line' => 309
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 309
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'ISA',
                   'type' => 119,
                   'line' => 309
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 309
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'four',
                   'type' => 163,
                   'line' => 309
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 309
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'FunctionDecl',
                   'data' => 'sub',
                   'type' => 58,
                   'line' => 310
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'four',
                   'type' => 119,
                   'line' => 310
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 310
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'womp',
                   'type' => 119,
                   'line' => 310
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 310
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'aoeaa',
                   'type' => 163,
                   'line' => 310
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 310
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Mul',
                   'data' => '*',
                   'type' => 3,
                   'line' => 311
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'two',
                   'type' => 119,
                   'line' => 311
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 311
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '=',
                   'type' => 119,
                   'line' => 311
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Mul',
                   'data' => '*',
                   'type' => 3,
                   'line' => 311
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'one',
                   'type' => 119,
                   'line' => 311
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 311
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => ';',
                   'type' => 119,
                   'line' => 311
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'delete',
                   'type' => 64,
                   'line' => 312
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SpecificValue',
                   'data' => '$:',
                   'type' => 129,
                   'line' => 312
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 25,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Colon',
                   'data' => ':',
                   'type' => 98,
                   'line' => 312
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 312
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'one::',
                   'type' => 163,
                   'line' => 312
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 312
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 312
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '@Childclass',
                   'type' => 119,
                   'line' => 313
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 313
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'ISA',
                   'type' => 119,
                   'line' => 313
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 313
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'two::more',
                   'type' => 164,
                   'line' => 313
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 313
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 314
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$accum',
                   'type' => 176,
                   'line' => 314
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 314
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'Childclass',
                   'type' => 164,
                   'line' => 314
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Pointer',
                   'data' => '->',
                   'type' => 117,
                   'line' => 314
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Method',
                   'data' => 'womp',
                   'type' => 59,
                   'line' => 314
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringAdd',
                   'data' => '.',
                   'type' => 9,
                   'line' => 314
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '-',
                   'type' => 164,
                   'line' => 314
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 314
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 315
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$life_raft',
                   'type' => 176,
                   'line' => 315
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 315
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'delete',
                   'type' => 64,
                   'line' => 315
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 28,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'ScalarDereference',
                   'data' => '${',
                   'type' => 108,
                   'line' => 315
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'two::',
                   'type' => 163,
                   'line' => 315
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 315
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 315
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'more::',
                   'type' => 163,
                   'line' => 315
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 315
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 315
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$accum',
                   'type' => 157,
                   'line' => 316
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'StringAdd',
                   'data' => '.=',
                   'type' => 9,
                   'line' => 316
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'eval',
                   'type' => 64,
                   'line' => 316
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 316
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'Childclass',
                   'type' => 164,
                   'line' => 316
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Pointer',
                   'data' => '->',
                   'type' => 117,
                   'line' => 316
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Method',
                   'data' => 'womp',
                   'type' => 59,
                   'line' => 316
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 316
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'DefaultOperator',
                   'data' => '//',
                   'type' => 55,
                   'line' => 316
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '<undef>',
                   'type' => 164,
                   'line' => 316
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 316
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'is',
                   'type' => 114,
                   'line' => 317
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Var',
                   'data' => '$accum',
                   'type' => 157,
                   'line' => 317
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 317
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'aoeaa-<undef>',
                   'type' => 164,
                   'line' => 317
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 317
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'Deleting globs whose loc in the symtab differs from gv_fullname',
                   'type' => 164,
                   'line' => 318
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 319
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Mul',
                   'data' => '*',
                   'type' => 3,
                   'line' => 322
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'Ghelp',
                   'type' => 119,
                   'line' => 322
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 322
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '=',
                   'type' => 119,
                   'line' => 322
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Mul',
                   'data' => '*',
                   'type' => 3,
                   'line' => 322
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'Neen',
                   'type' => 119,
                   'line' => 322
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 322
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => ';',
                   'type' => 119,
                   'line' => 322
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '@Subclass',
                   'type' => 119,
                   'line' => 323
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 323
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'ISA',
                   'type' => 119,
                   'line' => 323
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 323
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'Ghelp',
                   'type' => 164,
                   'line' => 323
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 323
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Default',
                   'data' => 'undef',
                   'type' => 192,
                   'line' => 324
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '%Ghelp',
                   'type' => 119,
                   'line' => 324
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 324
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => ';',
                   'type' => 119,
                   'line' => 324
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'FunctionDecl',
                   'data' => 'sub',
                   'type' => 58,
                   'line' => 325
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'Frelp',
                   'type' => 119,
                   'line' => 325
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 325
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'womp',
                   'type' => 119,
                   'line' => 325
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 325
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'clumpren',
                   'type' => 163,
                   'line' => 325
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 325
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'eval',
                   'type' => 64,
                   'line' => 326
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '
  $Neen::whatever++;
  @Neen::ISA = "Frelp";
',
                   'type' => 164,
                   'line' => 329
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 329
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'is',
                   'type' => 114,
                   'line' => 330
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'eval',
                   'type' => 64,
                   'line' => 330
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 330
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'Subclass',
                   'type' => 164,
                   'line' => 330
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Pointer',
                   'data' => '->',
                   'type' => 117,
                   'line' => 330
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Method',
                   'data' => 'womp',
                   'type' => 59,
                   'line' => 330
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 330
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 330
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'clumpren',
                   'type' => 164,
                   'line' => 330
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 330
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'Changes to @ISA after undef via original name',
                   'type' => 164,
                   'line' => 331
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 331
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Default',
                   'data' => 'undef',
                   'type' => 192,
                   'line' => 332
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '%Ghelp',
                   'type' => 119,
                   'line' => 332
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 332
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => ';',
                   'type' => 119,
                   'line' => 332
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'eval',
                   'type' => 64,
                   'line' => 333
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '
  $Ghelp::whatever++;
  @Ghelp::ISA = "Frelp";
',
                   'type' => 164,
                   'line' => 336
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 336
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'is',
                   'type' => 114,
                   'line' => 337
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'eval',
                   'type' => 64,
                   'line' => 337
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 337
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'Subclass',
                   'type' => 164,
                   'line' => 337
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Pointer',
                   'data' => '->',
                   'type' => 117,
                   'line' => 337
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Method',
                   'data' => 'womp',
                   'type' => 59,
                   'line' => 337
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 337
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 337
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'clumpren',
                   'type' => 164,
                   'line' => 337
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 337
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'Changes to @ISA after undef via alias',
                   'type' => 164,
                   'line' => 338
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 338
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 343
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 344
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Package',
                   'data' => 'package',
                   'type' => 120,
                   'line' => 344
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'smare',
                   'type' => 119,
                   'line' => 344
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 344
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'baz',
                   'type' => 119,
                   'line' => 344
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 344
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Mul',
                   'data' => '*',
                   'type' => 3,
                   'line' => 345
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'phring',
                   'type' => 119,
                   'line' => 345
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 345
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '=',
                   'type' => 119,
                   'line' => 345
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Mul',
                   'data' => '*',
                   'type' => 3,
                   'line' => 345
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'smare',
                   'type' => 119,
                   'line' => 345
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 345
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => ';',
                   'type' => 119,
                   'line' => 345
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Mul',
                   'data' => '*',
                   'type' => 3,
                   'line' => 346
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'bonk',
                   'type' => 119,
                   'line' => 346
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 346
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '=',
                   'type' => 119,
                   'line' => 346
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'delete',
                   'type' => 64,
                   'line' => 346
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '$smare',
                   'type' => 119,
                   'line' => 346
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 346
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '{',
                   'type' => 119,
                   'line' => 346
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'baz::',
                   'type' => 163,
                   'line' => 346
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 346
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 346
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'no',
                   'type' => 64,
                   'line' => 352
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'strict',
                   'type' => 114,
                   'line' => 352
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'refs',
                   'type' => 164,
                   'line' => 352
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 352
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Mul',
                   'data' => '*',
                   'type' => 3,
                   'line' => 353
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 353
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'phring::baz::frump',
                   'type' => 163,
                   'line' => 353
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 353
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 353
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'FunctionDecl',
                   'data' => 'sub',
                   'type' => 58,
                   'line' => 353
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 353
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'hello',
                   'type' => 163,
                   'line' => 353
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 353
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 353
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'FunctionDecl',
                   'data' => 'sub',
                   'type' => 58,
                   'line' => 354
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'frumper',
                   'type' => 119,
                   'line' => 354
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 354
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'frump',
                   'type' => 119,
                   'line' => 354
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 354
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'good bye',
                   'type' => 163,
                   'line' => 354
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 354
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 354
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '@brumkin',
                   'type' => 119,
                   'line' => 356
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 356
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'ISA',
                   'type' => 119,
                   'line' => 356
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 356
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegList',
                   'data' => 'qw',
                   'type' => 139,
                   'line' => 356
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'bonk frumper',
                   'type' => 163,
                   'line' => 356
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 356
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'is',
                   'type' => 114,
                   'line' => 358
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'frump',
                   'type' => 114,
                   'line' => 358
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'brumkin',
                   'type' => 114,
                   'line' => 358
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 358
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'good bye',
                   'type' => 163,
                   'line' => 358
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 358
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'detached stashes lose all names corresponding to the containing stash',
                   'type' => 164,
                   'line' => 359
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 359
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 360
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '@Colon',
                   'type' => 119,
                   'line' => 363
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 363
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'ISA',
                   'type' => 119,
                   'line' => 363
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 363
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'Organ:',
                   'type' => 164,
                   'line' => 363
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 363
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'bless',
                   'type' => 64,
                   'line' => 364
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'type' => 104,
                   'line' => 364
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBracket',
                   'data' => ']',
                   'type' => 105,
                   'line' => 364
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 364
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Organ:',
                   'type' => 163,
                   'line' => 364
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 364
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'ok',
                   'type' => 114,
                   'line' => 365
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Colon',
                   'type' => 163,
                   'line' => 365
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Pointer',
                   'data' => '->',
                   'type' => 117,
                   'line' => 365
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Method',
                   'data' => 'isa',
                   'type' => 59,
                   'line' => 365
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 365
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Organ:',
                   'type' => 163,
                   'line' => 365
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 365
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 365
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'class isa "class:"',
                   'type' => 164,
                   'line' => 365
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 365
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 366
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'no',
                   'type' => 64,
                   'line' => 366
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'strict',
                   'type' => 114,
                   'line' => 366
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'refs',
                   'type' => 164,
                   'line' => 366
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 366
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Mul',
                   'data' => '*',
                   'type' => 3,
                   'line' => 366
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 366
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Organ:::',
                   'type' => 163,
                   'line' => 366
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 366
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 366
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Mul',
                   'data' => '*',
                   'type' => 3,
                   'line' => 366
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'Organ',
                   'type' => 119,
                   'line' => 366
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 366
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '}',
                   'type' => 119,
                   'line' => 366
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'ok',
                   'type' => 114,
                   'line' => 367
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Colon',
                   'type' => 163,
                   'line' => 367
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Pointer',
                   'data' => '->',
                   'type' => 117,
                   'line' => 367
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Method',
                   'data' => 'isa',
                   'type' => 59,
                   'line' => 367
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 367
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Organ',
                   'type' => 163,
                   'line' => 367
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 367
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 367
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'isa(foo) when inheriting from "class:" which is an alias for foo',
                   'type' => 164,
                   'line' => 368
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 368
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 369
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'no',
                   'type' => 64,
                   'line' => 370
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'warnings',
                   'type' => 114,
                   'line' => 370
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 370
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 373
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$foo',
                   'type' => 176,
                   'line' => 373
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 373
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'delete',
                   'type' => 64,
                   'line' => 373
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '$Organ',
                   'type' => 119,
                   'line' => 373
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 373
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '{',
                   'type' => 119,
                   'line' => 373
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => ':',
                   'type' => 163,
                   'line' => 373
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 373
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 373
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'ok',
                   'type' => 114,
                   'line' => 374
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 5,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'IsNot',
                   'data' => '!',
                   'type' => 62,
                   'line' => 374
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'Colon',
                   'type' => 114,
                   'line' => 374
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Pointer',
                   'data' => '->',
                   'type' => 117,
                   'line' => 374
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Method',
                   'data' => 'isa',
                   'type' => 59,
                   'line' => 374
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 374
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Organ',
                   'type' => 163,
                   'line' => 374
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 374
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 374
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'class that isa "class:" no longer isa foo if "class:" has been deleted',
                   'type' => 164,
                   'line' => 375
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 375
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 376
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '@Colon',
                   'type' => 119,
                   'line' => 377
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 377
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'ISA',
                   'type' => 119,
                   'line' => 377
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 377
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => ':',
                   'type' => 164,
                   'line' => 377
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 377
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'bless',
                   'type' => 64,
                   'line' => 378
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'type' => 104,
                   'line' => 378
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBracket',
                   'data' => ']',
                   'type' => 105,
                   'line' => 378
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 378
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => ':',
                   'type' => 163,
                   'line' => 378
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 378
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'ok',
                   'type' => 114,
                   'line' => 379
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Colon',
                   'type' => 163,
                   'line' => 379
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Pointer',
                   'data' => '->',
                   'type' => 117,
                   'line' => 379
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Method',
                   'data' => 'isa',
                   'type' => 59,
                   'line' => 379
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 379
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => ':',
                   'type' => 163,
                   'line' => 379
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 379
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 379
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'class isa ":"',
                   'type' => 164,
                   'line' => 379
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 379
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 380
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'no',
                   'type' => 64,
                   'line' => 380
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'strict',
                   'type' => 114,
                   'line' => 380
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'refs',
                   'type' => 164,
                   'line' => 380
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 380
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Mul',
                   'data' => '*',
                   'type' => 3,
                   'line' => 380
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 380
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => ':::',
                   'type' => 163,
                   'line' => 380
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 380
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 380
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Mul',
                   'data' => '*',
                   'type' => 3,
                   'line' => 380
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'Punctuation',
                   'type' => 119,
                   'line' => 380
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 380
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '}',
                   'type' => 119,
                   'line' => 380
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'ok',
                   'type' => 114,
                   'line' => 381
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Colon',
                   'type' => 163,
                   'line' => 381
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Pointer',
                   'data' => '->',
                   'type' => 117,
                   'line' => 381
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Method',
                   'data' => 'isa',
                   'type' => 59,
                   'line' => 381
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 381
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Punctuation',
                   'type' => 163,
                   'line' => 381
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 381
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 381
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'isa(foo) when inheriting from ":" which is an alias for foo',
                   'type' => 164,
                   'line' => 382
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 382
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '@Colon',
                   'type' => 119,
                   'line' => 383
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 383
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'ISA',
                   'type' => 119,
                   'line' => 383
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 383
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'Organ:',
                   'type' => 164,
                   'line' => 383
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 383
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'bless',
                   'type' => 64,
                   'line' => 384
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'type' => 104,
                   'line' => 384
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBracket',
                   'data' => ']',
                   'type' => 105,
                   'line' => 384
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 384
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Organ:',
                   'type' => 163,
                   'line' => 384
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 384
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 385
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'no',
                   'type' => 64,
                   'line' => 386
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'strict',
                   'type' => 114,
                   'line' => 386
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'refs',
                   'type' => 164,
                   'line' => 386
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 386
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 387
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$life_raft',
                   'type' => 176,
                   'line' => 387
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 387
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Ref',
                   'data' => '\\',
                   'type' => 10,
                   'line' => 387
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 28,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'HashDereference',
                   'data' => '%{',
                   'type' => 107,
                   'line' => 387
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Organ:::',
                   'type' => 163,
                   'line' => 387
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 387
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 387
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Mul',
                   'data' => '*',
                   'type' => 3,
                   'line' => 388
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 388
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Organ:::',
                   'type' => 163,
                   'line' => 388
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 388
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 388
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Ref',
                   'data' => '\\',
                   'type' => 10,
                   'line' => 388
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '%Organ',
                   'type' => 119,
                   'line' => 388
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 388
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => ';',
                   'type' => 119,
                   'line' => 388
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'ok',
                   'type' => 114,
                   'line' => 389
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Colon',
                   'type' => 163,
                   'line' => 389
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Pointer',
                   'data' => '->',
                   'type' => 117,
                   'line' => 389
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Method',
                   'data' => 'isa',
                   'type' => 59,
                   'line' => 389
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 389
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Organ',
                   'type' => 163,
                   'line' => 389
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 389
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 389
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'isa(foo) when inheriting from "class:" after hash-to-glob assignment',
                   'type' => 164,
                   'line' => 390
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 390
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 391
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => '@Colon',
                   'type' => 119,
                   'line' => 392
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'NamespaceResolver',
                   'data' => '::',
                   'type' => 118,
                   'line' => 392
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 29,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Namespace',
                   'data' => 'ISA',
                   'type' => 119,
                   'line' => 392
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 392
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'O:',
                   'type' => 164,
                   'line' => 392
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 392
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'bless',
                   'type' => 64,
                   'line' => 393
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBracket',
                   'data' => '[',
                   'type' => 104,
                   'line' => 393
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBracket',
                   'data' => ']',
                   'type' => 105,
                   'line' => 393
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 393
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'O:',
                   'type' => 163,
                   'line' => 393
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 393
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 394
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'no',
                   'type' => 64,
                   'line' => 395
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'strict',
                   'type' => 114,
                   'line' => 395
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'refs',
                   'type' => 164,
                   'line' => 395
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 395
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 396
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$life_raft',
                   'type' => 176,
                   'line' => 396
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 396
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Ref',
                   'data' => '\\',
                   'type' => 10,
                   'line' => 396
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 28,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'HashDereference',
                   'data' => '%{',
                   'type' => 107,
                   'line' => 396
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'O:::',
                   'type' => 163,
                   'line' => 396
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 396
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 396
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Mul',
                   'data' => '*',
                   'type' => 3,
                   'line' => 397
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 397
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'O:::',
                   'type' => 163,
                   'line' => 397
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 397
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 397
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Organ::',
                   'type' => 163,
                   'line' => 397
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 397
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'ok',
                   'type' => 114,
                   'line' => 398
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Colon',
                   'type' => 163,
                   'line' => 398
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Pointer',
                   'data' => '->',
                   'type' => 117,
                   'line' => 398
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Method',
                   'data' => 'isa',
                   'type' => 59,
                   'line' => 398
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 398
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'String',
                   'data' => 'Organ',
                   'type' => 163,
                   'line' => 398
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 398
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 398
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 'isa(foo) when inheriting from "class:" after string-to-glob assignment',
                   'type' => 164,
                   'line' => 399
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 399
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 400
                 }, 'Compiler::Lexer::Token' )
        ]
, 'Compiler::Lexer::tokenize');
};

subtest 'get_groups_by_syntax_level' => sub {
    my $lexer = Compiler::Lexer->new('');
    my $tokens = $lexer->tokenize($script);
    my $stmts = $lexer->get_groups_by_syntax_level($$tokens, Compiler::Lexer::SyntaxType::T_Stmt);
    is_deeply($$stmts, [
          {
            'token_num' => 17,
            'has_warnings' => 0,
            'end_line' => 7,
            'src' => ' unless ( -d \'blib\' ) { chdir \'t\' if -d \'t\' ; @INC = \'../lib\' ; }',
            'start_line' => 4,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 6,
            'has_warnings' => 0,
            'end_line' => 5,
            'src' => ' chdir \'t\' if -d \'t\' ;',
            'start_line' => 5,
            'indent' => 2,
            'block_id' => 2
          },
          {
            'token_num' => 4,
            'has_warnings' => 0,
            'end_line' => 6,
            'src' => ' @INC = \'../lib\' ;',
            'start_line' => 6,
            'indent' => 2,
            'block_id' => 2
          },
          {
            'token_num' => 6,
            'has_warnings' => 0,
            'end_line' => 8,
            'src' => ' require q(./test.pl) ;',
            'start_line' => 8,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 3,
            'has_warnings' => 0,
            'end_line' => 11,
            'src' => ' use strict ;',
            'start_line' => 11,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 3,
            'has_warnings' => 0,
            'end_line' => 12,
            'src' => ' use warnings ;',
            'start_line' => 12,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 7,
            'has_warnings' => 1,
            'end_line' => 13,
            'src' => ' plan ( tests => 52 ) ;',
            'start_line' => 13,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 918,
            'has_warnings' => 1,
            'end_line' => 400,
            'src' => ' { package New ; use strict ; use warnings ; package Old ; use strict ; use warnings ; { no strict \'refs\' ; * { \'Old::\' } = * { \'New::\' } ; } } ok ( Old-> isa ( New::) , \'Old inherits from New\' ) ; ok ( New-> isa ( Old::) , \'New inherits from Old\' ) ; object_ok ( bless ( { } , Old::) , New::, \'Old object\' ) ; object_ok ( bless ( { } , New::) , Old::, \'New object\' ) ; for ( { name => \'assigning a glob to a glob\' , code => \'$life_raft = $::{"Left::"}; *Left:: = $::{"Right::"}\' , } , { name => \'assigning a string to a glob\' , code => \'$life_raft = $::{"Left::"}; *Left:: = "Right::"\' , } , { name => \'assigning a stashref to a glob\' , code => \'$life_raft = \\%Left::; *Left:: = \\%Right::\' , } , ) { fresh_perl_is q~
     @Subclass::ISA = "Left";
     @Left::ISA = "TopLeft";

     sub TopLeft::speak { "Woof!" }
     sub TopRight::speak { "Bow-wow!" }

     my $thing = bless [], "Subclass";

     # mro_package_moved needs to know to skip non-globs
     $Right::{"gleck::"} = 3;

     @Right::ISA = \'TopRight\';
     my $life_raft;
    __code__;

     print $thing->speak, "\\n";

     undef $life_raft;
     print $thing->speak, "\\n";
   ~ =~ \\ s__code__ $$_ { code } r , "Bow-wow!\\nBow-wow!\\n" , { } , "replacing packages by $$_{name} updates isa caches" ; } for ( { name => \'assigning a glob to a glob\' , code => \'$life_raft = $::{"Left::"}; *Left:: = $::{"Right::"}\' , } , { name => \'assigning a string to a glob\' , code => \'$life_raft = $::{"Left::"}; *Left:: = "Right::"\' , } , { name => \'assigning a stashref to a glob\' , code => \'$life_raft = \\%Left::; *Left:: = \\%Right::\' , } , ) { fresh_perl_is q~
     @Subclass::ISA = "Left::Side";
     @Left::Side::ISA = "TopLeft";

     sub TopLeft::speak { "Woof!" }
     sub TopRight::speak { "Bow-wow!" }

     my $thing = bless [], "Subclass";

     @Right::Side::ISA = \'TopRight\';
     my $life_raft;
    __code__;

     print $thing->speak, "\\n";

     undef $life_raft;
     print $thing->speak, "\\n";
   ~ =~ \\ s__code__ $$_ { code } r , "Bow-wow!\\nBow-wow!\\n" , { } , "replacing nested packages by $$_{name} updates isa caches" ; } for ( { name => \'assigning a glob to a glob\' , code => \'*clone:: = *outer::\' , } , { name => \'assigning a string to a glob\' , code => \'*clone:: = "outer::"\' , } , { name => \'assigning a stashref to a glob\' , code => \'*clone:: = \\%outer::\' , } , ) { for my $tail ( \'inner\' , \'inner::\' , \'inner:::\' , \'inner::::\' ) { fresh_perl_is q~
      my $tail = shift;
      @left::ISA = "outer::$tail";
      @right::ISA = "clone::$tail";
      bless [], "outer::$tail"; # autovivify the stash

     __code__;

      print "ok 1", "\\n" if left->isa("clone::$tail");
      print "ok 2", "\\n" if right->isa("outer::$tail");
      print "ok 3", "\\n" if right->isa("clone::$tail");
      print "ok 4", "\\n" if left->isa("outer::$tail");
    ~ =~ \\ s__code__ $$_ { code } r , "ok 1\\nok 2\\nok 3\\nok 4\\n" , { args => [ $tail ] } , "replacing nonexistent nested packages by $$_{name} updates isa caches" . " ($tail)" ; fresh_perl_is q~
      my $tail = shift;
      @left::ISA = "outer::$tail";
      @right::ISA = "clone::$tail";

     __code__;

      bless [], "outer::$tail";

      print "ok 1", "\\n" if left->isa("clone::$tail");
      print "ok 2", "\\n" if right->isa("outer::$tail");
      print "ok 3", "\\n" if right->isa("clone::$tail");
      print "ok 4", "\\n" if left->isa("outer::$tail");
    ~ =~ \\ s__code__ $$_ { code } r , "ok 1\\nok 2\\nok 3\\nok 4\\n" , { args => [ $tail ] } , "Giving nonexistent packages multiple effective names by $$_{name}" . " ($tail)" ; } } no warnings ; { @Pet::ISA = ( "Cur" , "Hound" ) ; @Cur::ISA = "Hylactete" ; sub Hylactete::speak { "Arff!" } sub Hound::speak { "Woof!" } my $pet = bless [ ] , "Pet" ; my $life_raft = delete $: : { \'Cur::\' } ; is $pet-> speak , \'Woof!\' , \'deleting a stash from its parent stash invalidates the isa caches\' ; undef $life_raft ; is $pet-> speak , \'Woof!\' , \'the deleted stash is gone completely when freed\' ; } { @Pett::ISA = ( "Curr::Curr::Curr" , "Hownd" ) ; @Curr::Curr::Curr::ISA = "Latrator" ; sub Latrator::speak { "Arff!" } sub Hownd::speak { "Woof!" } my $pet = bless [ ] , "Pett" ; my $life_raft = delete $: : { \'Curr::\' } ; is $pet-> speak , \'Woof!\' , \'deleting a stash from its parent stash resets caches of substashes\' ; undef $life_raft ; is $pet-> speak , \'Woof!\' , \'the deleted substash is gone completely when freed\' ; } fresh_perl_is q~#!perl -w
     @Pet::ISA = "Tike";
     @Tike::ISA = "Barker";
     
     sub Barker::speak { print "Woof!\\n" }
     sub Latrator::speak { print "Bow-wow!\\n" }
     
     my $pet = bless [], "Pet";
     
     $pet->speak;
     
     sub Dog::speak { print "Hello.\\n" } # strange dog!
     @Dog::ISA = \'Latrator\';
     *Tike:: = delete $::{\'Dog::\'};
     
     $pet->speak;
   ~ , "Woof!\\nHello.\\n" , { stderr => 1 } , "Assigning a nameless package over one w/subclasses updates isa caches" ; no warnings ; { no strict \'refs\' ; sub bar::blonk::blonk::phoo { "bbb" } sub veclum::phoo { "lasrevinu" } @feedlebomp::ISA = qw \'phoo::blonk::blonk veclum\' ; * phoo::baz::= * bar::blonk::; * phoo::= * bar::; * bar::= * boo::; my $accum = \'\' ; $accum .= \'feedlebomp\'-> phoo ; delete ${ "phoo::blonk::" } { "blonk::" } ; $accum .= \'feedlebomp\'-> phoo ; @feedlebomp::ISA = @feedlebomp::ISA ; $accum .= \'feedlebomp\'-> phoo ; is $accum , \'bbblasrevinulasrevinu\' , \'nested classes deleted & added simultaneously\' ; } use warnings ; watchdog 3 ; * foo::= \\ %::; * Acme::META::Acme::= * Acme::; pass ( "mro_package_moved and self-referential packages" ) ; { no strict refs => ; no warnings ; @one::more::ISA = "four" ; sub four::womp { "aoeaa" } * two::= * one::; delete $: : { "one::" } ; @Childclass::ISA = \'two::more\' ; my $accum = \'Childclass\'-> womp . \'-\' ; my $life_raft = delete ${ "two::" } { "more::" } ; $accum .= eval { \'Childclass\'-> womp } // \'<undef>\' ; is $accum , \'aoeaa-<undef>\' , \'Deleting globs whose loc in the symtab differs from gv_fullname\' } * Ghelp::= * Neen::; @Subclass::ISA = \'Ghelp\' ; undef %Ghelp::; sub Frelp::womp { "clumpren" } eval \'
  $Neen::whatever++;
  @Neen::ISA = "Frelp";
\' ; is eval { \'Subclass\'-> womp } , \'clumpren\' , \'Changes to @ISA after undef via original name\' ; undef %Ghelp::; eval \'
  $Ghelp::whatever++;
  @Ghelp::ISA = "Frelp";
\' ; is eval { \'Subclass\'-> womp } , \'clumpren\' , \'Changes to @ISA after undef via alias\' ; { { package smare::baz } * phring::= * smare::; * bonk::= delete $smare::{ "baz::" } ; no strict \'refs\' ; * { "phring::baz::frump" } = sub { "hello" } ; sub frumper::frump { "good bye" } ; @brumkin::ISA = qw "bonk frumper" ; is frump brumkin , "good bye" , \'detached stashes lose all names corresponding to the containing stash\' ; } @Colon::ISA = \'Organ:\' ; bless [ ] , "Organ:" ; ok "Colon"-> isa ( "Organ:" ) , \'class isa "class:"\' ; { no strict \'refs\' ; * { "Organ:::" } = * Organ::} ok "Colon"-> isa ( "Organ" ) , \'isa(foo) when inheriting from "class:" which is an alias for foo\' ; { no warnings ; my $foo = delete $Organ::{ ":" } ; ok ! Colon-> isa ( "Organ" ) , \'class that isa "class:" no longer isa foo if "class:" has been deleted\' ; } @Colon::ISA = \':\' ; bless [ ] , ":" ; ok "Colon"-> isa ( ":" ) , \'class isa ":"\' ; { no strict \'refs\' ; * { ":::" } = * Punctuation::} ok "Colon"-> isa ( "Punctuation" ) , \'isa(foo) when inheriting from ":" which is an alias for foo\' ; @Colon::ISA = \'Organ:\' ; bless [ ] , "Organ:" ; { no strict \'refs\' ; my $life_raft = \\ %{ "Organ:::" } ; * { "Organ:::" } = \\ %Organ::; ok "Colon"-> isa ( "Organ" ) , \'isa(foo) when inheriting from "class:" after hash-to-glob assignment\' ; } @Colon::ISA = \'O:\' ; bless [ ] , "O:" ; { no strict \'refs\' ; my $life_raft = \\ %{ "O:::" } ; * { "O:::" } = "Organ::" ; ok "Colon"-> isa ( "Organ" ) , \'isa(foo) when inheriting from "class:" after string-to-glob assignment\' ; } } ; } ; } ;',
            'start_line' => 15,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 3,
            'has_warnings' => 1,
            'end_line' => 16,
            'src' => ' package New ;',
            'start_line' => 16,
            'indent' => 1,
            'block_id' => 3
          },
          {
            'token_num' => 3,
            'has_warnings' => 0,
            'end_line' => 17,
            'src' => ' use strict ;',
            'start_line' => 17,
            'indent' => 1,
            'block_id' => 3
          },
          {
            'token_num' => 3,
            'has_warnings' => 0,
            'end_line' => 18,
            'src' => ' use warnings ;',
            'start_line' => 18,
            'indent' => 1,
            'block_id' => 3
          },
          {
            'token_num' => 3,
            'has_warnings' => 1,
            'end_line' => 20,
            'src' => ' package Old ;',
            'start_line' => 20,
            'indent' => 1,
            'block_id' => 3
          },
          {
            'token_num' => 3,
            'has_warnings' => 0,
            'end_line' => 21,
            'src' => ' use strict ;',
            'start_line' => 21,
            'indent' => 1,
            'block_id' => 3
          },
          {
            'token_num' => 3,
            'has_warnings' => 0,
            'end_line' => 22,
            'src' => ' use warnings ;',
            'start_line' => 22,
            'indent' => 1,
            'block_id' => 3
          },
          {
            'token_num' => 16,
            'has_warnings' => 1,
            'end_line' => 27,
            'src' => ' { no strict \'refs\' ; * { \'Old::\' } = * { \'New::\' } ; }',
            'start_line' => 24,
            'indent' => 1,
            'block_id' => 3
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 25,
            'src' => ' no strict \'refs\' ;',
            'start_line' => 25,
            'indent' => 2,
            'block_id' => 4
          },
          {
            'token_num' => 10,
            'has_warnings' => 0,
            'end_line' => 26,
            'src' => ' * { \'Old::\' } = * { \'New::\' } ;',
            'start_line' => 26,
            'indent' => 2,
            'block_id' => 4
          },
          {
            'token_num' => 878,
            'has_warnings' => 1,
            'end_line' => 400,
            'src' => ' Old-> isa ( New::) , \'Old inherits from New\' ) ; ok ( New-> isa ( Old::) , \'New inherits from Old\' ) ; object_ok ( bless ( { } , Old::) , New::, \'Old object\' ) ; object_ok ( bless ( { } , New::) , Old::, \'New object\' ) ; for ( { name => \'assigning a glob to a glob\' , code => \'$life_raft = $::{"Left::"}; *Left:: = $::{"Right::"}\' , } , { name => \'assigning a string to a glob\' , code => \'$life_raft = $::{"Left::"}; *Left:: = "Right::"\' , } , { name => \'assigning a stashref to a glob\' , code => \'$life_raft = \\%Left::; *Left:: = \\%Right::\' , } , ) { fresh_perl_is q~
     @Subclass::ISA = "Left";
     @Left::ISA = "TopLeft";

     sub TopLeft::speak { "Woof!" }
     sub TopRight::speak { "Bow-wow!" }

     my $thing = bless [], "Subclass";

     # mro_package_moved needs to know to skip non-globs
     $Right::{"gleck::"} = 3;

     @Right::ISA = \'TopRight\';
     my $life_raft;
    __code__;

     print $thing->speak, "\\n";

     undef $life_raft;
     print $thing->speak, "\\n";
   ~ =~ \\ s__code__ $$_ { code } r , "Bow-wow!\\nBow-wow!\\n" , { } , "replacing packages by $$_{name} updates isa caches" ; } for ( { name => \'assigning a glob to a glob\' , code => \'$life_raft = $::{"Left::"}; *Left:: = $::{"Right::"}\' , } , { name => \'assigning a string to a glob\' , code => \'$life_raft = $::{"Left::"}; *Left:: = "Right::"\' , } , { name => \'assigning a stashref to a glob\' , code => \'$life_raft = \\%Left::; *Left:: = \\%Right::\' , } , ) { fresh_perl_is q~
     @Subclass::ISA = "Left::Side";
     @Left::Side::ISA = "TopLeft";

     sub TopLeft::speak { "Woof!" }
     sub TopRight::speak { "Bow-wow!" }

     my $thing = bless [], "Subclass";

     @Right::Side::ISA = \'TopRight\';
     my $life_raft;
    __code__;

     print $thing->speak, "\\n";

     undef $life_raft;
     print $thing->speak, "\\n";
   ~ =~ \\ s__code__ $$_ { code } r , "Bow-wow!\\nBow-wow!\\n" , { } , "replacing nested packages by $$_{name} updates isa caches" ; } for ( { name => \'assigning a glob to a glob\' , code => \'*clone:: = *outer::\' , } , { name => \'assigning a string to a glob\' , code => \'*clone:: = "outer::"\' , } , { name => \'assigning a stashref to a glob\' , code => \'*clone:: = \\%outer::\' , } , ) { for my $tail ( \'inner\' , \'inner::\' , \'inner:::\' , \'inner::::\' ) { fresh_perl_is q~
      my $tail = shift;
      @left::ISA = "outer::$tail";
      @right::ISA = "clone::$tail";
      bless [], "outer::$tail"; # autovivify the stash

     __code__;

      print "ok 1", "\\n" if left->isa("clone::$tail");
      print "ok 2", "\\n" if right->isa("outer::$tail");
      print "ok 3", "\\n" if right->isa("clone::$tail");
      print "ok 4", "\\n" if left->isa("outer::$tail");
    ~ =~ \\ s__code__ $$_ { code } r , "ok 1\\nok 2\\nok 3\\nok 4\\n" , { args => [ $tail ] } , "replacing nonexistent nested packages by $$_{name} updates isa caches" . " ($tail)" ; fresh_perl_is q~
      my $tail = shift;
      @left::ISA = "outer::$tail";
      @right::ISA = "clone::$tail";

     __code__;

      bless [], "outer::$tail";

      print "ok 1", "\\n" if left->isa("clone::$tail");
      print "ok 2", "\\n" if right->isa("outer::$tail");
      print "ok 3", "\\n" if right->isa("clone::$tail");
      print "ok 4", "\\n" if left->isa("outer::$tail");
    ~ =~ \\ s__code__ $$_ { code } r , "ok 1\\nok 2\\nok 3\\nok 4\\n" , { args => [ $tail ] } , "Giving nonexistent packages multiple effective names by $$_{name}" . " ($tail)" ; } } no warnings ; { @Pet::ISA = ( "Cur" , "Hound" ) ; @Cur::ISA = "Hylactete" ; sub Hylactete::speak { "Arff!" } sub Hound::speak { "Woof!" } my $pet = bless [ ] , "Pet" ; my $life_raft = delete $: : { \'Cur::\' } ; is $pet-> speak , \'Woof!\' , \'deleting a stash from its parent stash invalidates the isa caches\' ; undef $life_raft ; is $pet-> speak , \'Woof!\' , \'the deleted stash is gone completely when freed\' ; } { @Pett::ISA = ( "Curr::Curr::Curr" , "Hownd" ) ; @Curr::Curr::Curr::ISA = "Latrator" ; sub Latrator::speak { "Arff!" } sub Hownd::speak { "Woof!" } my $pet = bless [ ] , "Pett" ; my $life_raft = delete $: : { \'Curr::\' } ; is $pet-> speak , \'Woof!\' , \'deleting a stash from its parent stash resets caches of substashes\' ; undef $life_raft ; is $pet-> speak , \'Woof!\' , \'the deleted substash is gone completely when freed\' ; } fresh_perl_is q~#!perl -w
     @Pet::ISA = "Tike";
     @Tike::ISA = "Barker";
     
     sub Barker::speak { print "Woof!\\n" }
     sub Latrator::speak { print "Bow-wow!\\n" }
     
     my $pet = bless [], "Pet";
     
     $pet->speak;
     
     sub Dog::speak { print "Hello.\\n" } # strange dog!
     @Dog::ISA = \'Latrator\';
     *Tike:: = delete $::{\'Dog::\'};
     
     $pet->speak;
   ~ , "Woof!\\nHello.\\n" , { stderr => 1 } , "Assigning a nameless package over one w/subclasses updates isa caches" ; no warnings ; { no strict \'refs\' ; sub bar::blonk::blonk::phoo { "bbb" } sub veclum::phoo { "lasrevinu" } @feedlebomp::ISA = qw \'phoo::blonk::blonk veclum\' ; * phoo::baz::= * bar::blonk::; * phoo::= * bar::; * bar::= * boo::; my $accum = \'\' ; $accum .= \'feedlebomp\'-> phoo ; delete ${ "phoo::blonk::" } { "blonk::" } ; $accum .= \'feedlebomp\'-> phoo ; @feedlebomp::ISA = @feedlebomp::ISA ; $accum .= \'feedlebomp\'-> phoo ; is $accum , \'bbblasrevinulasrevinu\' , \'nested classes deleted & added simultaneously\' ; } use warnings ; watchdog 3 ; * foo::= \\ %::; * Acme::META::Acme::= * Acme::; pass ( "mro_package_moved and self-referential packages" ) ; { no strict refs => ; no warnings ; @one::more::ISA = "four" ; sub four::womp { "aoeaa" } * two::= * one::; delete $: : { "one::" } ; @Childclass::ISA = \'two::more\' ; my $accum = \'Childclass\'-> womp . \'-\' ; my $life_raft = delete ${ "two::" } { "more::" } ; $accum .= eval { \'Childclass\'-> womp } // \'<undef>\' ; is $accum , \'aoeaa-<undef>\' , \'Deleting globs whose loc in the symtab differs from gv_fullname\' } * Ghelp::= * Neen::; @Subclass::ISA = \'Ghelp\' ; undef %Ghelp::; sub Frelp::womp { "clumpren" } eval \'
  $Neen::whatever++;
  @Neen::ISA = "Frelp";
\' ; is eval { \'Subclass\'-> womp } , \'clumpren\' , \'Changes to @ISA after undef via original name\' ; undef %Ghelp::; eval \'
  $Ghelp::whatever++;
  @Ghelp::ISA = "Frelp";
\' ; is eval { \'Subclass\'-> womp } , \'clumpren\' , \'Changes to @ISA after undef via alias\' ; { { package smare::baz } * phring::= * smare::; * bonk::= delete $smare::{ "baz::" } ; no strict \'refs\' ; * { "phring::baz::frump" } = sub { "hello" } ; sub frumper::frump { "good bye" } ; @brumkin::ISA = qw "bonk frumper" ; is frump brumkin , "good bye" , \'detached stashes lose all names corresponding to the containing stash\' ; } @Colon::ISA = \'Organ:\' ; bless [ ] , "Organ:" ; ok "Colon"-> isa ( "Organ:" ) , \'class isa "class:"\' ; { no strict \'refs\' ; * { "Organ:::" } = * Organ::} ok "Colon"-> isa ( "Organ" ) , \'isa(foo) when inheriting from "class:" which is an alias for foo\' ; { no warnings ; my $foo = delete $Organ::{ ":" } ; ok ! Colon-> isa ( "Organ" ) , \'class that isa "class:" no longer isa foo if "class:" has been deleted\' ; } @Colon::ISA = \':\' ; bless [ ] , ":" ; ok "Colon"-> isa ( ":" ) , \'class isa ":"\' ; { no strict \'refs\' ; * { ":::" } = * Punctuation::} ok "Colon"-> isa ( "Punctuation" ) , \'isa(foo) when inheriting from ":" which is an alias for foo\' ; @Colon::ISA = \'Organ:\' ; bless [ ] , "Organ:" ; { no strict \'refs\' ; my $life_raft = \\ %{ "Organ:::" } ; * { "Organ:::" } = \\ %Organ::; ok "Colon"-> isa ( "Organ" ) , \'isa(foo) when inheriting from "class:" after hash-to-glob assignment\' ; } @Colon::ISA = \'O:\' ; bless [ ] , "O:" ; { no strict \'refs\' ; my $life_raft = \\ %{ "O:::" } ; * { "O:::" } = "Organ::" ; ok "Colon"-> isa ( "Organ" ) , \'isa(foo) when inheriting from "class:" after string-to-glob assignment\' ; } } ; } ;',
            'start_line' => 30,
            'indent' => 0,
            'block_id' => 4
          },
          {
            'token_num' => 9,
            'has_warnings' => 1,
            'end_line' => 30,
            'src' => ' Old-> isa ( New::) , \'Old inherits from New\' ) ;',
            'start_line' => 30,
            'indent' => 0,
            'block_id' => 4
          },
          {
            'token_num' => 865,
            'has_warnings' => 1,
            'end_line' => 400,
            'src' => ' New-> isa ( Old::) , \'New inherits from Old\' ) ; object_ok ( bless ( { } , Old::) , New::, \'Old object\' ) ; object_ok ( bless ( { } , New::) , Old::, \'New object\' ) ; for ( { name => \'assigning a glob to a glob\' , code => \'$life_raft = $::{"Left::"}; *Left:: = $::{"Right::"}\' , } , { name => \'assigning a string to a glob\' , code => \'$life_raft = $::{"Left::"}; *Left:: = "Right::"\' , } , { name => \'assigning a stashref to a glob\' , code => \'$life_raft = \\%Left::; *Left:: = \\%Right::\' , } , ) { fresh_perl_is q~
     @Subclass::ISA = "Left";
     @Left::ISA = "TopLeft";

     sub TopLeft::speak { "Woof!" }
     sub TopRight::speak { "Bow-wow!" }

     my $thing = bless [], "Subclass";

     # mro_package_moved needs to know to skip non-globs
     $Right::{"gleck::"} = 3;

     @Right::ISA = \'TopRight\';
     my $life_raft;
    __code__;

     print $thing->speak, "\\n";

     undef $life_raft;
     print $thing->speak, "\\n";
   ~ =~ \\ s__code__ $$_ { code } r , "Bow-wow!\\nBow-wow!\\n" , { } , "replacing packages by $$_{name} updates isa caches" ; } for ( { name => \'assigning a glob to a glob\' , code => \'$life_raft = $::{"Left::"}; *Left:: = $::{"Right::"}\' , } , { name => \'assigning a string to a glob\' , code => \'$life_raft = $::{"Left::"}; *Left:: = "Right::"\' , } , { name => \'assigning a stashref to a glob\' , code => \'$life_raft = \\%Left::; *Left:: = \\%Right::\' , } , ) { fresh_perl_is q~
     @Subclass::ISA = "Left::Side";
     @Left::Side::ISA = "TopLeft";

     sub TopLeft::speak { "Woof!" }
     sub TopRight::speak { "Bow-wow!" }

     my $thing = bless [], "Subclass";

     @Right::Side::ISA = \'TopRight\';
     my $life_raft;
    __code__;

     print $thing->speak, "\\n";

     undef $life_raft;
     print $thing->speak, "\\n";
   ~ =~ \\ s__code__ $$_ { code } r , "Bow-wow!\\nBow-wow!\\n" , { } , "replacing nested packages by $$_{name} updates isa caches" ; } for ( { name => \'assigning a glob to a glob\' , code => \'*clone:: = *outer::\' , } , { name => \'assigning a string to a glob\' , code => \'*clone:: = "outer::"\' , } , { name => \'assigning a stashref to a glob\' , code => \'*clone:: = \\%outer::\' , } , ) { for my $tail ( \'inner\' , \'inner::\' , \'inner:::\' , \'inner::::\' ) { fresh_perl_is q~
      my $tail = shift;
      @left::ISA = "outer::$tail";
      @right::ISA = "clone::$tail";
      bless [], "outer::$tail"; # autovivify the stash

     __code__;

      print "ok 1", "\\n" if left->isa("clone::$tail");
      print "ok 2", "\\n" if right->isa("outer::$tail");
      print "ok 3", "\\n" if right->isa("clone::$tail");
      print "ok 4", "\\n" if left->isa("outer::$tail");
    ~ =~ \\ s__code__ $$_ { code } r , "ok 1\\nok 2\\nok 3\\nok 4\\n" , { args => [ $tail ] } , "replacing nonexistent nested packages by $$_{name} updates isa caches" . " ($tail)" ; fresh_perl_is q~
      my $tail = shift;
      @left::ISA = "outer::$tail";
      @right::ISA = "clone::$tail";

     __code__;

      bless [], "outer::$tail";

      print "ok 1", "\\n" if left->isa("clone::$tail");
      print "ok 2", "\\n" if right->isa("outer::$tail");
      print "ok 3", "\\n" if right->isa("clone::$tail");
      print "ok 4", "\\n" if left->isa("outer::$tail");
    ~ =~ \\ s__code__ $$_ { code } r , "ok 1\\nok 2\\nok 3\\nok 4\\n" , { args => [ $tail ] } , "Giving nonexistent packages multiple effective names by $$_{name}" . " ($tail)" ; } } no warnings ; { @Pet::ISA = ( "Cur" , "Hound" ) ; @Cur::ISA = "Hylactete" ; sub Hylactete::speak { "Arff!" } sub Hound::speak { "Woof!" } my $pet = bless [ ] , "Pet" ; my $life_raft = delete $: : { \'Cur::\' } ; is $pet-> speak , \'Woof!\' , \'deleting a stash from its parent stash invalidates the isa caches\' ; undef $life_raft ; is $pet-> speak , \'Woof!\' , \'the deleted stash is gone completely when freed\' ; } { @Pett::ISA = ( "Curr::Curr::Curr" , "Hownd" ) ; @Curr::Curr::Curr::ISA = "Latrator" ; sub Latrator::speak { "Arff!" } sub Hownd::speak { "Woof!" } my $pet = bless [ ] , "Pett" ; my $life_raft = delete $: : { \'Curr::\' } ; is $pet-> speak , \'Woof!\' , \'deleting a stash from its parent stash resets caches of substashes\' ; undef $life_raft ; is $pet-> speak , \'Woof!\' , \'the deleted substash is gone completely when freed\' ; } fresh_perl_is q~#!perl -w
     @Pet::ISA = "Tike";
     @Tike::ISA = "Barker";
     
     sub Barker::speak { print "Woof!\\n" }
     sub Latrator::speak { print "Bow-wow!\\n" }
     
     my $pet = bless [], "Pet";
     
     $pet->speak;
     
     sub Dog::speak { print "Hello.\\n" } # strange dog!
     @Dog::ISA = \'Latrator\';
     *Tike:: = delete $::{\'Dog::\'};
     
     $pet->speak;
   ~ , "Woof!\\nHello.\\n" , { stderr => 1 } , "Assigning a nameless package over one w/subclasses updates isa caches" ; no warnings ; { no strict \'refs\' ; sub bar::blonk::blonk::phoo { "bbb" } sub veclum::phoo { "lasrevinu" } @feedlebomp::ISA = qw \'phoo::blonk::blonk veclum\' ; * phoo::baz::= * bar::blonk::; * phoo::= * bar::; * bar::= * boo::; my $accum = \'\' ; $accum .= \'feedlebomp\'-> phoo ; delete ${ "phoo::blonk::" } { "blonk::" } ; $accum .= \'feedlebomp\'-> phoo ; @feedlebomp::ISA = @feedlebomp::ISA ; $accum .= \'feedlebomp\'-> phoo ; is $accum , \'bbblasrevinulasrevinu\' , \'nested classes deleted & added simultaneously\' ; } use warnings ; watchdog 3 ; * foo::= \\ %::; * Acme::META::Acme::= * Acme::; pass ( "mro_package_moved and self-referential packages" ) ; { no strict refs => ; no warnings ; @one::more::ISA = "four" ; sub four::womp { "aoeaa" } * two::= * one::; delete $: : { "one::" } ; @Childclass::ISA = \'two::more\' ; my $accum = \'Childclass\'-> womp . \'-\' ; my $life_raft = delete ${ "two::" } { "more::" } ; $accum .= eval { \'Childclass\'-> womp } // \'<undef>\' ; is $accum , \'aoeaa-<undef>\' , \'Deleting globs whose loc in the symtab differs from gv_fullname\' } * Ghelp::= * Neen::; @Subclass::ISA = \'Ghelp\' ; undef %Ghelp::; sub Frelp::womp { "clumpren" } eval \'
  $Neen::whatever++;
  @Neen::ISA = "Frelp";
\' ; is eval { \'Subclass\'-> womp } , \'clumpren\' , \'Changes to @ISA after undef via original name\' ; undef %Ghelp::; eval \'
  $Ghelp::whatever++;
  @Ghelp::ISA = "Frelp";
\' ; is eval { \'Subclass\'-> womp } , \'clumpren\' , \'Changes to @ISA after undef via alias\' ; { { package smare::baz } * phring::= * smare::; * bonk::= delete $smare::{ "baz::" } ; no strict \'refs\' ; * { "phring::baz::frump" } = sub { "hello" } ; sub frumper::frump { "good bye" } ; @brumkin::ISA = qw "bonk frumper" ; is frump brumkin , "good bye" , \'detached stashes lose all names corresponding to the containing stash\' ; } @Colon::ISA = \'Organ:\' ; bless [ ] , "Organ:" ; ok "Colon"-> isa ( "Organ:" ) , \'class isa "class:"\' ; { no strict \'refs\' ; * { "Organ:::" } = * Organ::} ok "Colon"-> isa ( "Organ" ) , \'isa(foo) when inheriting from "class:" which is an alias for foo\' ; { no warnings ; my $foo = delete $Organ::{ ":" } ; ok ! Colon-> isa ( "Organ" ) , \'class that isa "class:" no longer isa foo if "class:" has been deleted\' ; } @Colon::ISA = \':\' ; bless [ ] , ":" ; ok "Colon"-> isa ( ":" ) , \'class isa ":"\' ; { no strict \'refs\' ; * { ":::" } = * Punctuation::} ok "Colon"-> isa ( "Punctuation" ) , \'isa(foo) when inheriting from ":" which is an alias for foo\' ; @Colon::ISA = \'Organ:\' ; bless [ ] , "Organ:" ; { no strict \'refs\' ; my $life_raft = \\ %{ "Organ:::" } ; * { "Organ:::" } = \\ %Organ::; ok "Colon"-> isa ( "Organ" ) , \'isa(foo) when inheriting from "class:" after hash-to-glob assignment\' ; } @Colon::ISA = \'O:\' ; bless [ ] , "O:" ; { no strict \'refs\' ; my $life_raft = \\ %{ "O:::" } ; * { "O:::" } = "Organ::" ; ok "Colon"-> isa ( "Organ" ) , \'isa(foo) when inheriting from "class:" after string-to-glob assignment\' ; } } ;',
            'start_line' => 31,
            'indent' => 0,
            'block_id' => 4
          },
          {
            'token_num' => 9,
            'has_warnings' => 1,
            'end_line' => 31,
            'src' => ' New-> isa ( Old::) , \'New inherits from Old\' ) ;',
            'start_line' => 31,
            'indent' => 0,
            'block_id' => 4
          },
          {
            'token_num' => 11,
            'has_warnings' => 1,
            'end_line' => 33,
            'src' => ' bless ( { } , Old::) , New::, \'Old object\' ) ;',
            'start_line' => 33,
            'indent' => 0,
            'block_id' => 4
          },
          {
            'token_num' => 655,
            'has_warnings' => 1,
            'end_line' => 363,
            'src' => ' object_ok ( bless ( { } , New::) , Old::, \'New object\' ) ; for ( { name => \'assigning a glob to a glob\' , code => \'$life_raft = $::{"Left::"}; *Left:: = $::{"Right::"}\' , } , { name => \'assigning a string to a glob\' , code => \'$life_raft = $::{"Left::"}; *Left:: = "Right::"\' , } , { name => \'assigning a stashref to a glob\' , code => \'$life_raft = \\%Left::; *Left:: = \\%Right::\' , } , ) { fresh_perl_is q~
     @Subclass::ISA = "Left";
     @Left::ISA = "TopLeft";

     sub TopLeft::speak { "Woof!" }
     sub TopRight::speak { "Bow-wow!" }

     my $thing = bless [], "Subclass";

     # mro_package_moved needs to know to skip non-globs
     $Right::{"gleck::"} = 3;

     @Right::ISA = \'TopRight\';
     my $life_raft;
    __code__;

     print $thing->speak, "\\n";

     undef $life_raft;
     print $thing->speak, "\\n";
   ~ =~ \\ s__code__ $$_ { code } r , "Bow-wow!\\nBow-wow!\\n" , { } , "replacing packages by $$_{name} updates isa caches" ; } for ( { name => \'assigning a glob to a glob\' , code => \'$life_raft = $::{"Left::"}; *Left:: = $::{"Right::"}\' , } , { name => \'assigning a string to a glob\' , code => \'$life_raft = $::{"Left::"}; *Left:: = "Right::"\' , } , { name => \'assigning a stashref to a glob\' , code => \'$life_raft = \\%Left::; *Left:: = \\%Right::\' , } , ) { fresh_perl_is q~
     @Subclass::ISA = "Left::Side";
     @Left::Side::ISA = "TopLeft";

     sub TopLeft::speak { "Woof!" }
     sub TopRight::speak { "Bow-wow!" }

     my $thing = bless [], "Subclass";

     @Right::Side::ISA = \'TopRight\';
     my $life_raft;
    __code__;

     print $thing->speak, "\\n";

     undef $life_raft;
     print $thing->speak, "\\n";
   ~ =~ \\ s__code__ $$_ { code } r , "Bow-wow!\\nBow-wow!\\n" , { } , "replacing nested packages by $$_{name} updates isa caches" ; } for ( { name => \'assigning a glob to a glob\' , code => \'*clone:: = *outer::\' , } , { name => \'assigning a string to a glob\' , code => \'*clone:: = "outer::"\' , } , { name => \'assigning a stashref to a glob\' , code => \'*clone:: = \\%outer::\' , } , ) { for my $tail ( \'inner\' , \'inner::\' , \'inner:::\' , \'inner::::\' ) { fresh_perl_is q~
      my $tail = shift;
      @left::ISA = "outer::$tail";
      @right::ISA = "clone::$tail";
      bless [], "outer::$tail"; # autovivify the stash

     __code__;

      print "ok 1", "\\n" if left->isa("clone::$tail");
      print "ok 2", "\\n" if right->isa("outer::$tail");
      print "ok 3", "\\n" if right->isa("clone::$tail");
      print "ok 4", "\\n" if left->isa("outer::$tail");
    ~ =~ \\ s__code__ $$_ { code } r , "ok 1\\nok 2\\nok 3\\nok 4\\n" , { args => [ $tail ] } , "replacing nonexistent nested packages by $$_{name} updates isa caches" . " ($tail)" ; fresh_perl_is q~
      my $tail = shift;
      @left::ISA = "outer::$tail";
      @right::ISA = "clone::$tail";

     __code__;

      bless [], "outer::$tail";

      print "ok 1", "\\n" if left->isa("clone::$tail");
      print "ok 2", "\\n" if right->isa("outer::$tail");
      print "ok 3", "\\n" if right->isa("clone::$tail");
      print "ok 4", "\\n" if left->isa("outer::$tail");
    ~ =~ \\ s__code__ $$_ { code } r , "ok 1\\nok 2\\nok 3\\nok 4\\n" , { args => [ $tail ] } , "Giving nonexistent packages multiple effective names by $$_{name}" . " ($tail)" ; } } no warnings ; { @Pet::ISA = ( "Cur" , "Hound" ) ; @Cur::ISA = "Hylactete" ; sub Hylactete::speak { "Arff!" } sub Hound::speak { "Woof!" } my $pet = bless [ ] , "Pet" ; my $life_raft = delete $: : { \'Cur::\' } ; is $pet-> speak , \'Woof!\' , \'deleting a stash from its parent stash invalidates the isa caches\' ; undef $life_raft ; is $pet-> speak , \'Woof!\' , \'the deleted stash is gone completely when freed\' ; } { @Pett::ISA = ( "Curr::Curr::Curr" , "Hownd" ) ; @Curr::Curr::Curr::ISA = "Latrator" ; sub Latrator::speak { "Arff!" } sub Hownd::speak { "Woof!" } my $pet = bless [ ] , "Pett" ; my $life_raft = delete $: : { \'Curr::\' } ; is $pet-> speak , \'Woof!\' , \'deleting a stash from its parent stash resets caches of substashes\' ; undef $life_raft ; is $pet-> speak , \'Woof!\' , \'the deleted substash is gone completely when freed\' ; } fresh_perl_is q~#!perl -w
     @Pet::ISA = "Tike";
     @Tike::ISA = "Barker";
     
     sub Barker::speak { print "Woof!\\n" }
     sub Latrator::speak { print "Bow-wow!\\n" }
     
     my $pet = bless [], "Pet";
     
     $pet->speak;
     
     sub Dog::speak { print "Hello.\\n" } # strange dog!
     @Dog::ISA = \'Latrator\';
     *Tike:: = delete $::{\'Dog::\'};
     
     $pet->speak;
   ~ , "Woof!\\nHello.\\n" , { stderr => 1 } , "Assigning a nameless package over one w/subclasses updates isa caches" ; no warnings ; { no strict \'refs\' ; sub bar::blonk::blonk::phoo { "bbb" } sub veclum::phoo { "lasrevinu" } @feedlebomp::ISA = qw \'phoo::blonk::blonk veclum\' ; * phoo::baz::= * bar::blonk::; * phoo::= * bar::; * bar::= * boo::; my $accum = \'\' ; $accum .= \'feedlebomp\'-> phoo ; delete ${ "phoo::blonk::" } { "blonk::" } ; $accum .= \'feedlebomp\'-> phoo ; @feedlebomp::ISA = @feedlebomp::ISA ; $accum .= \'feedlebomp\'-> phoo ; is $accum , \'bbblasrevinulasrevinu\' , \'nested classes deleted & added simultaneously\' ; } use warnings ; watchdog 3 ; * foo::= \\ %::; * Acme::META::Acme::= * Acme::; pass ( "mro_package_moved and self-referential packages" ) ; { no strict refs => ; no warnings ; @one::more::ISA = "four" ; sub four::womp { "aoeaa" } * two::= * one::; delete $: : { "one::" } ; @Childclass::ISA = \'two::more\' ; my $accum = \'Childclass\'-> womp . \'-\' ; my $life_raft = delete ${ "two::" } { "more::" } ; $accum .= eval { \'Childclass\'-> womp } // \'<undef>\' ; is $accum , \'aoeaa-<undef>\' , \'Deleting globs whose loc in the symtab differs from gv_fullname\' } * Ghelp::= * Neen::; @Subclass::ISA = \'Ghelp\' ; undef %Ghelp::; sub Frelp::womp { "clumpren" } eval \'
  $Neen::whatever++;
  @Neen::ISA = "Frelp";
\' ; is eval { \'Subclass\'-> womp } , \'clumpren\' , \'Changes to @ISA after undef via original name\' ; undef %Ghelp::; eval \'
  $Ghelp::whatever++;
  @Ghelp::ISA = "Frelp";
\' ; is eval { \'Subclass\'-> womp } , \'clumpren\' , \'Changes to @ISA after undef via alias\' ; { { package smare::baz } * phring::= * smare::; * bonk::= delete $smare::{ "baz::" } ; no strict \'refs\' ; * { "phring::baz::frump" } = sub { "hello" } ; sub frumper::frump { "good bye" } ; @brumkin::ISA = qw "bonk frumper" ; is frump brumkin , "good bye" , \'detached stashes lose all names corresponding to the containing stash\' ; } @Colon::ISA = \'Organ:\' ;',
            'start_line' => 34,
            'indent' => 0,
            'block_id' => 4
          },
          {
            'token_num' => 11,
            'has_warnings' => 1,
            'end_line' => 34,
            'src' => ' bless ( { } , New::) , Old::, \'New object\' ) ;',
            'start_line' => 34,
            'indent' => 0,
            'block_id' => 5
          },
          {
            'token_num' => 59,
            'has_warnings' => 1,
            'end_line' => 78,
            'src' => ' for ( { name => \'assigning a glob to a glob\' , code => \'$life_raft = $::{"Left::"}; *Left:: = $::{"Right::"}\' , } , { name => \'assigning a string to a glob\' , code => \'$life_raft = $::{"Left::"}; *Left:: = "Right::"\' , } , { name => \'assigning a stashref to a glob\' , code => \'$life_raft = \\%Left::; *Left:: = \\%Right::\' , } , ) { fresh_perl_is q~
     @Subclass::ISA = "Left";
     @Left::ISA = "TopLeft";

     sub TopLeft::speak { "Woof!" }
     sub TopRight::speak { "Bow-wow!" }

     my $thing = bless [], "Subclass";

     # mro_package_moved needs to know to skip non-globs
     $Right::{"gleck::"} = 3;

     @Right::ISA = \'TopRight\';
     my $life_raft;
    __code__;

     print $thing->speak, "\\n";

     undef $life_raft;
     print $thing->speak, "\\n";
   ~ =~ \\ s__code__ $$_ { code } r , "Bow-wow!\\nBow-wow!\\n" , { } , "replacing packages by $$_{name} updates isa caches" ; }',
            'start_line' => 39,
            'indent' => 0,
            'block_id' => 5
          },
          {
            'token_num' => 3,
            'has_warnings' => 0,
            'end_line' => 77,
            'src' => ' , "replacing packages by $$_{name} updates isa caches" ;',
            'start_line' => 76,
            'indent' => 1,
            'block_id' => 7
          },
          {
            'token_num' => 59,
            'has_warnings' => 1,
            'end_line' => 126,
            'src' => ' for ( { name => \'assigning a glob to a glob\' , code => \'$life_raft = $::{"Left::"}; *Left:: = $::{"Right::"}\' , } , { name => \'assigning a string to a glob\' , code => \'$life_raft = $::{"Left::"}; *Left:: = "Right::"\' , } , { name => \'assigning a stashref to a glob\' , code => \'$life_raft = \\%Left::; *Left:: = \\%Right::\' , } , ) { fresh_perl_is q~
     @Subclass::ISA = "Left::Side";
     @Left::Side::ISA = "TopLeft";

     sub TopLeft::speak { "Woof!" }
     sub TopRight::speak { "Bow-wow!" }

     my $thing = bless [], "Subclass";

     @Right::Side::ISA = \'TopRight\';
     my $life_raft;
    __code__;

     print $thing->speak, "\\n";

     undef $life_raft;
     print $thing->speak, "\\n";
   ~ =~ \\ s__code__ $$_ { code } r , "Bow-wow!\\nBow-wow!\\n" , { } , "replacing nested packages by $$_{name} updates isa caches" ; }',
            'start_line' => 90,
            'indent' => 0,
            'block_id' => 5
          },
          {
            'token_num' => 3,
            'has_warnings' => 0,
            'end_line' => 125,
            'src' => ' , "replacing nested packages by $$_{name} updates isa caches" ;',
            'start_line' => 124,
            'indent' => 1,
            'block_id' => 10
          },
          {
            'token_num' => 108,
            'has_warnings' => 1,
            'end_line' => 198,
            'src' => ' for ( { name => \'assigning a glob to a glob\' , code => \'*clone:: = *outer::\' , } , { name => \'assigning a string to a glob\' , code => \'*clone:: = "outer::"\' , } , { name => \'assigning a stashref to a glob\' , code => \'*clone:: = \\%outer::\' , } , ) { for my $tail ( \'inner\' , \'inner::\' , \'inner:::\' , \'inner::::\' ) { fresh_perl_is q~
      my $tail = shift;
      @left::ISA = "outer::$tail";
      @right::ISA = "clone::$tail";
      bless [], "outer::$tail"; # autovivify the stash

     __code__;

      print "ok 1", "\\n" if left->isa("clone::$tail");
      print "ok 2", "\\n" if right->isa("outer::$tail");
      print "ok 3", "\\n" if right->isa("clone::$tail");
      print "ok 4", "\\n" if left->isa("outer::$tail");
    ~ =~ \\ s__code__ $$_ { code } r , "ok 1\\nok 2\\nok 3\\nok 4\\n" , { args => [ $tail ] } , "replacing nonexistent nested packages by $$_{name} updates isa caches" . " ($tail)" ; fresh_perl_is q~
      my $tail = shift;
      @left::ISA = "outer::$tail";
      @right::ISA = "clone::$tail";

     __code__;

      bless [], "outer::$tail";

      print "ok 1", "\\n" if left->isa("clone::$tail");
      print "ok 2", "\\n" if right->isa("outer::$tail");
      print "ok 3", "\\n" if right->isa("clone::$tail");
      print "ok 4", "\\n" if left->isa("outer::$tail");
    ~ =~ \\ s__code__ $$_ { code } r , "ok 1\\nok 2\\nok 3\\nok 4\\n" , { args => [ $tail ] } , "Giving nonexistent packages multiple effective names by $$_{name}" . " ($tail)" ; } }',
            'start_line' => 143,
            'indent' => 0,
            'block_id' => 5
          },
          {
            'token_num' => 70,
            'has_warnings' => 1,
            'end_line' => 197,
            'src' => ' for my $tail ( \'inner\' , \'inner::\' , \'inner:::\' , \'inner::::\' ) { fresh_perl_is q~
      my $tail = shift;
      @left::ISA = "outer::$tail";
      @right::ISA = "clone::$tail";
      bless [], "outer::$tail"; # autovivify the stash

     __code__;

      print "ok 1", "\\n" if left->isa("clone::$tail");
      print "ok 2", "\\n" if right->isa("outer::$tail");
      print "ok 3", "\\n" if right->isa("clone::$tail");
      print "ok 4", "\\n" if left->isa("outer::$tail");
    ~ =~ \\ s__code__ $$_ { code } r , "ok 1\\nok 2\\nok 3\\nok 4\\n" , { args => [ $tail ] } , "replacing nonexistent nested packages by $$_{name} updates isa caches" . " ($tail)" ; fresh_perl_is q~
      my $tail = shift;
      @left::ISA = "outer::$tail";
      @right::ISA = "clone::$tail";

     __code__;

      bless [], "outer::$tail";

      print "ok 1", "\\n" if left->isa("clone::$tail");
      print "ok 2", "\\n" if right->isa("outer::$tail");
      print "ok 3", "\\n" if right->isa("clone::$tail");
      print "ok 4", "\\n" if left->isa("outer::$tail");
    ~ =~ \\ s__code__ $$_ { code } r , "ok 1\\nok 2\\nok 3\\nok 4\\n" , { args => [ $tail ] } , "Giving nonexistent packages multiple effective names by $$_{name}" . " ($tail)" ; }',
            'start_line' => 157,
            'indent' => 1,
            'block_id' => 13
          },
          {
            'token_num' => 16,
            'has_warnings' => 1,
            'end_line' => 175,
            'src' => ' r , "ok 1\\nok 2\\nok 3\\nok 4\\n" , { args => [ $tail ] } , "replacing nonexistent nested packages by $$_{name} updates isa caches" . " ($tail)" ;',
            'start_line' => 171,
            'indent' => 2,
            'block_id' => 14
          },
          {
            'token_num' => 16,
            'has_warnings' => 1,
            'end_line' => 196,
            'src' => ' r , "ok 1\\nok 2\\nok 3\\nok 4\\n" , { args => [ $tail ] } , "Giving nonexistent packages multiple effective names by $$_{name}" . " ($tail)" ;',
            'start_line' => 192,
            'indent' => 2,
            'block_id' => 14
          },
          {
            'token_num' => 3,
            'has_warnings' => 1,
            'end_line' => 200,
            'src' => ' no warnings ;',
            'start_line' => 200,
            'indent' => 0,
            'block_id' => 5
          },
          {
            'token_num' => 64,
            'has_warnings' => 1,
            'end_line' => 224,
            'src' => ' { @Pet::ISA = ( "Cur" , "Hound" ) ; @Cur::ISA = "Hylactete" ; sub Hylactete::speak { "Arff!" } sub Hound::speak { "Woof!" } my $pet = bless [ ] , "Pet" ; my $life_raft = delete $: : { \'Cur::\' } ; is $pet-> speak , \'Woof!\' , \'deleting a stash from its parent stash invalidates the isa caches\' ; undef $life_raft ; is $pet-> speak , \'Woof!\' , \'the deleted stash is gone completely when freed\' ; }',
            'start_line' => 207,
            'indent' => 0,
            'block_id' => 5
          },
          {
            'token_num' => 8,
            'has_warnings' => 1,
            'end_line' => 208,
            'src' => ' @Pet::ISA = ( "Cur" , "Hound" ) ;',
            'start_line' => 208,
            'indent' => 1,
            'block_id' => 17
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 209,
            'src' => ' @Cur::ISA = "Hylactete" ;',
            'start_line' => 209,
            'indent' => 1,
            'block_id' => 17
          },
          {
            'token_num' => 9,
            'has_warnings' => 0,
            'end_line' => 214,
            'src' => ' my $pet = bless [ ] , "Pet" ;',
            'start_line' => 214,
            'indent' => 1,
            'block_id' => 17
          },
          {
            'token_num' => 10,
            'has_warnings' => 0,
            'end_line' => 216,
            'src' => ' my $life_raft = delete $: : { \'Cur::\' } ;',
            'start_line' => 216,
            'indent' => 1,
            'block_id' => 17
          },
          {
            'token_num' => 9,
            'has_warnings' => 1,
            'end_line' => 219,
            'src' => ' is $pet-> speak , \'Woof!\' , \'deleting a stash from its parent stash invalidates the isa caches\' ;',
            'start_line' => 218,
            'indent' => 1,
            'block_id' => 17
          },
          {
            'token_num' => 3,
            'has_warnings' => 1,
            'end_line' => 221,
            'src' => ' undef $life_raft ;',
            'start_line' => 221,
            'indent' => 1,
            'block_id' => 17
          },
          {
            'token_num' => 9,
            'has_warnings' => 1,
            'end_line' => 223,
            'src' => ' is $pet-> speak , \'Woof!\' , \'the deleted stash is gone completely when freed\' ;',
            'start_line' => 222,
            'indent' => 1,
            'block_id' => 17
          },
          {
            'token_num' => 64,
            'has_warnings' => 1,
            'end_line' => 243,
            'src' => ' { @Pett::ISA = ( "Curr::Curr::Curr" , "Hownd" ) ; @Curr::Curr::Curr::ISA = "Latrator" ; sub Latrator::speak { "Arff!" } sub Hownd::speak { "Woof!" } my $pet = bless [ ] , "Pett" ; my $life_raft = delete $: : { \'Curr::\' } ; is $pet-> speak , \'Woof!\' , \'deleting a stash from its parent stash resets caches of substashes\' ; undef $life_raft ; is $pet-> speak , \'Woof!\' , \'the deleted substash is gone completely when freed\' ; }',
            'start_line' => 226,
            'indent' => 0,
            'block_id' => 5
          },
          {
            'token_num' => 8,
            'has_warnings' => 1,
            'end_line' => 227,
            'src' => ' @Pett::ISA = ( "Curr::Curr::Curr" , "Hownd" ) ;',
            'start_line' => 227,
            'indent' => 1,
            'block_id' => 21
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 228,
            'src' => ' @Curr::Curr::Curr::ISA = "Latrator" ;',
            'start_line' => 228,
            'indent' => 1,
            'block_id' => 21
          },
          {
            'token_num' => 9,
            'has_warnings' => 0,
            'end_line' => 233,
            'src' => ' my $pet = bless [ ] , "Pett" ;',
            'start_line' => 233,
            'indent' => 1,
            'block_id' => 21
          },
          {
            'token_num' => 10,
            'has_warnings' => 0,
            'end_line' => 235,
            'src' => ' my $life_raft = delete $: : { \'Curr::\' } ;',
            'start_line' => 235,
            'indent' => 1,
            'block_id' => 21
          },
          {
            'token_num' => 9,
            'has_warnings' => 1,
            'end_line' => 238,
            'src' => ' is $pet-> speak , \'Woof!\' , \'deleting a stash from its parent stash resets caches of substashes\' ;',
            'start_line' => 237,
            'indent' => 1,
            'block_id' => 21
          },
          {
            'token_num' => 3,
            'has_warnings' => 1,
            'end_line' => 240,
            'src' => ' undef $life_raft ;',
            'start_line' => 240,
            'indent' => 1,
            'block_id' => 21
          },
          {
            'token_num' => 9,
            'has_warnings' => 1,
            'end_line' => 242,
            'src' => ' is $pet-> speak , \'Woof!\' , \'the deleted substash is gone completely when freed\' ;',
            'start_line' => 241,
            'indent' => 1,
            'block_id' => 21
          },
          {
            'token_num' => 16,
            'has_warnings' => 1,
            'end_line' => 266,
            'src' => ' fresh_perl_is q~#!perl -w
     @Pet::ISA = "Tike";
     @Tike::ISA = "Barker";
     
     sub Barker::speak { print "Woof!\\n" }
     sub Latrator::speak { print "Bow-wow!\\n" }
     
     my $pet = bless [], "Pet";
     
     $pet->speak;
     
     sub Dog::speak { print "Hello.\\n" } # strange dog!
     @Dog::ISA = \'Latrator\';
     *Tike:: = delete $::{\'Dog::\'};
     
     $pet->speak;
   ~ , "Woof!\\nHello.\\n" , { stderr => 1 } , "Assigning a nameless package over one w/subclasses updates isa caches" ;',
            'start_line' => 247,
            'indent' => 0,
            'block_id' => 5
          },
          {
            'token_num' => 3,
            'has_warnings' => 1,
            'end_line' => 270,
            'src' => ' no warnings ;',
            'start_line' => 270,
            'indent' => 0,
            'block_id' => 5
          },
          {
            'token_num' => 75,
            'has_warnings' => 1,
            'end_line' => 294,
            'src' => ' { no strict \'refs\' ; sub bar::blonk::blonk::phoo { "bbb" } sub veclum::phoo { "lasrevinu" } @feedlebomp::ISA = qw \'phoo::blonk::blonk veclum\' ; * phoo::baz::= * bar::blonk::; * phoo::= * bar::; * bar::= * boo::; my $accum = \'\' ; $accum .= \'feedlebomp\'-> phoo ; delete ${ "phoo::blonk::" } { "blonk::" } ; $accum .= \'feedlebomp\'-> phoo ; @feedlebomp::ISA = @feedlebomp::ISA ; $accum .= \'feedlebomp\'-> phoo ; is $accum , \'bbblasrevinulasrevinu\' , \'nested classes deleted & added simultaneously\' ; }',
            'start_line' => 270,
            'indent' => 0,
            'block_id' => 5
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 271,
            'src' => ' no strict \'refs\' ;',
            'start_line' => 271,
            'indent' => 1,
            'block_id' => 25
          },
          {
            'token_num' => 5,
            'has_warnings' => 1,
            'end_line' => 275,
            'src' => ' @feedlebomp::ISA = qw \'phoo::blonk::blonk veclum\' ;',
            'start_line' => 275,
            'indent' => 1,
            'block_id' => 25
          },
          {
            'token_num' => 17,
            'has_warnings' => 1,
            'end_line' => 284,
            'src' => ' * phoo::baz::= * bar::blonk::; * phoo::= * bar::; * bar::= * boo::; my $accum = \'\' ;',
            'start_line' => 276,
            'indent' => 1,
            'block_id' => 25
          },
          {
            'token_num' => 6,
            'has_warnings' => 1,
            'end_line' => 286,
            'src' => ' $accum .= \'feedlebomp\'-> phoo ;',
            'start_line' => 286,
            'indent' => 1,
            'block_id' => 25
          },
          {
            'token_num' => 8,
            'has_warnings' => 0,
            'end_line' => 287,
            'src' => ' delete ${ "phoo::blonk::" } { "blonk::" } ;',
            'start_line' => 287,
            'indent' => 1,
            'block_id' => 25
          },
          {
            'token_num' => 6,
            'has_warnings' => 1,
            'end_line' => 288,
            'src' => ' $accum .= \'feedlebomp\'-> phoo ;',
            'start_line' => 288,
            'indent' => 1,
            'block_id' => 25
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 289,
            'src' => ' @feedlebomp::ISA = @feedlebomp::ISA ;',
            'start_line' => 289,
            'indent' => 1,
            'block_id' => 25
          },
          {
            'token_num' => 6,
            'has_warnings' => 1,
            'end_line' => 290,
            'src' => ' $accum .= \'feedlebomp\'-> phoo ;',
            'start_line' => 290,
            'indent' => 1,
            'block_id' => 25
          },
          {
            'token_num' => 7,
            'has_warnings' => 1,
            'end_line' => 293,
            'src' => ' is $accum , \'bbblasrevinulasrevinu\' , \'nested classes deleted & added simultaneously\' ;',
            'start_line' => 292,
            'indent' => 1,
            'block_id' => 25
          },
          {
            'token_num' => 3,
            'has_warnings' => 0,
            'end_line' => 295,
            'src' => ' use warnings ;',
            'start_line' => 295,
            'indent' => 0,
            'block_id' => 5
          },
          {
            'token_num' => 3,
            'has_warnings' => 1,
            'end_line' => 299,
            'src' => ' watchdog 3 ;',
            'start_line' => 299,
            'indent' => 0,
            'block_id' => 5
          },
          {
            'token_num' => 13,
            'has_warnings' => 1,
            'end_line' => 302,
            'src' => ' * foo::= \\ %::; * Acme::META::Acme::= * Acme::; pass ( "mro_package_moved and self-referential packages" ) ;',
            'start_line' => 300,
            'indent' => 0,
            'block_id' => 5
          },
          {
            'token_num' => 71,
            'has_warnings' => 1,
            'end_line' => 319,
            'src' => ' { no strict refs => ; no warnings ; @one::more::ISA = "four" ; sub four::womp { "aoeaa" } * two::= * one::; delete $: : { "one::" } ; @Childclass::ISA = \'two::more\' ; my $accum = \'Childclass\'-> womp . \'-\' ; my $life_raft = delete ${ "two::" } { "more::" } ; $accum .= eval { \'Childclass\'-> womp } // \'<undef>\' ; is $accum , \'aoeaa-<undef>\' , \'Deleting globs whose loc in the symtab differs from gv_fullname\' }',
            'start_line' => 306,
            'indent' => 0,
            'block_id' => 5
          },
          {
            'token_num' => 5,
            'has_warnings' => 1,
            'end_line' => 307,
            'src' => ' no strict refs => ;',
            'start_line' => 307,
            'indent' => 1,
            'block_id' => 28
          },
          {
            'token_num' => 3,
            'has_warnings' => 1,
            'end_line' => 308,
            'src' => ' no warnings ;',
            'start_line' => 308,
            'indent' => 1,
            'block_id' => 28
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 309,
            'src' => ' @one::more::ISA = "four" ;',
            'start_line' => 309,
            'indent' => 1,
            'block_id' => 28
          },
          {
            'token_num' => 11,
            'has_warnings' => 1,
            'end_line' => 312,
            'src' => ' * two::= * one::; delete $: : { "one::" } ;',
            'start_line' => 311,
            'indent' => 1,
            'block_id' => 28
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 313,
            'src' => ' @Childclass::ISA = \'two::more\' ;',
            'start_line' => 313,
            'indent' => 1,
            'block_id' => 28
          },
          {
            'token_num' => 9,
            'has_warnings' => 0,
            'end_line' => 314,
            'src' => ' my $accum = \'Childclass\'-> womp . \'-\' ;',
            'start_line' => 314,
            'indent' => 1,
            'block_id' => 28
          },
          {
            'token_num' => 11,
            'has_warnings' => 0,
            'end_line' => 315,
            'src' => ' my $life_raft = delete ${ "two::" } { "more::" } ;',
            'start_line' => 315,
            'indent' => 1,
            'block_id' => 28
          },
          {
            'token_num' => 11,
            'has_warnings' => 1,
            'end_line' => 316,
            'src' => ' $accum .= eval { \'Childclass\'-> womp } // \'<undef>\' ;',
            'start_line' => 316,
            'indent' => 1,
            'block_id' => 28
          },
          {
            'token_num' => 8,
            'has_warnings' => 1,
            'end_line' => 323,
            'src' => ' * Ghelp::= * Neen::; @Subclass::ISA = \'Ghelp\' ;',
            'start_line' => 322,
            'indent' => 0,
            'block_id' => 5
          },
          {
            'token_num' => 3,
            'has_warnings' => 0,
            'end_line' => 329,
            'src' => ' eval \'
  $Neen::whatever++;
  @Neen::ISA = "Frelp";
\' ;',
            'start_line' => 326,
            'indent' => 0,
            'block_id' => 5
          },
          {
            'token_num' => 12,
            'has_warnings' => 1,
            'end_line' => 331,
            'src' => ' is eval { \'Subclass\'-> womp } , \'clumpren\' , \'Changes to @ISA after undef via original name\' ;',
            'start_line' => 330,
            'indent' => 0,
            'block_id' => 5
          },
          {
            'token_num' => 5,
            'has_warnings' => 1,
            'end_line' => 336,
            'src' => ' undef %Ghelp::; eval \'
  $Ghelp::whatever++;
  @Ghelp::ISA = "Frelp";
\' ;',
            'start_line' => 332,
            'indent' => 0,
            'block_id' => 5
          },
          {
            'token_num' => 12,
            'has_warnings' => 1,
            'end_line' => 338,
            'src' => ' is eval { \'Subclass\'-> womp } , \'clumpren\' , \'Changes to @ISA after undef via alias\' ;',
            'start_line' => 337,
            'indent' => 0,
            'block_id' => 5
          },
          {
            'token_num' => 16,
            'has_warnings' => 1,
            'end_line' => 346,
            'src' => ' { { package smare::baz } * phring::= * smare::; * bonk::= delete $smare::{ "baz::" } ;',
            'start_line' => 343,
            'indent' => 0,
            'block_id' => 5
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 352,
            'src' => ' no strict \'refs\' ;',
            'start_line' => 352,
            'indent' => 0,
            'block_id' => 5
          },
          {
            'token_num' => 10,
            'has_warnings' => 0,
            'end_line' => 353,
            'src' => ' * { "phring::baz::frump" } = sub { "hello" } ;',
            'start_line' => 353,
            'indent' => 0,
            'block_id' => 5
          },
          {
            'token_num' => 6,
            'has_warnings' => 1,
            'end_line' => 354,
            'src' => ' sub frumper::frump { "good bye" } ;',
            'start_line' => 354,
            'indent' => 0,
            'block_id' => 5
          },
          {
            'token_num' => 5,
            'has_warnings' => 1,
            'end_line' => 356,
            'src' => ' @brumkin::ISA = qw "bonk frumper" ;',
            'start_line' => 356,
            'indent' => 0,
            'block_id' => 5
          },
          {
            'token_num' => 8,
            'has_warnings' => 1,
            'end_line' => 359,
            'src' => ' is frump brumkin , "good bye" , \'detached stashes lose all names corresponding to the containing stash\' ;',
            'start_line' => 358,
            'indent' => 0,
            'block_id' => 5
          },
          {
            'token_num' => 6,
            'has_warnings' => 0,
            'end_line' => 364,
            'src' => ' bless [ ] , "Organ:" ;',
            'start_line' => 364,
            'indent' => 0,
            'block_id' => 4
          },
          {
            'token_num' => 10,
            'has_warnings' => 1,
            'end_line' => 365,
            'src' => ' ok "Colon"-> isa ( "Organ:" ) , \'class isa "class:"\' ;',
            'start_line' => 365,
            'indent' => 0,
            'block_id' => 4
          },
          {
            'token_num' => 46,
            'has_warnings' => 1,
            'end_line' => 376,
            'src' => ' { no strict \'refs\' ; * { "Organ:::" } = * Organ::} ok "Colon"-> isa ( "Organ" ) , \'isa(foo) when inheriting from "class:" which is an alias for foo\' ; { no warnings ; my $foo = delete $Organ::{ ":" } ; ok ! Colon-> isa ( "Organ" ) , \'class that isa "class:" no longer isa foo if "class:" has been deleted\' ; }',
            'start_line' => 366,
            'indent' => 0,
            'block_id' => 4
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 366,
            'src' => ' no strict \'refs\' ;',
            'start_line' => 366,
            'indent' => 1,
            'block_id' => 36
          },
          {
            'token_num' => 17,
            'has_warnings' => 1,
            'end_line' => 368,
            'src' => ' * { "Organ:::" } = * Organ::} ok "Colon"-> isa ( "Organ" ) , \'isa(foo) when inheriting from "class:" which is an alias for foo\' ;',
            'start_line' => 366,
            'indent' => 1,
            'block_id' => 36
          },
          {
            'token_num' => 12,
            'has_warnings' => 1,
            'end_line' => 373,
            'src' => ' { no warnings ; my $foo = delete $Organ::{ ":" } ;',
            'start_line' => 369,
            'indent' => 1,
            'block_id' => 36
          },
          {
            'token_num' => 3,
            'has_warnings' => 1,
            'end_line' => 370,
            'src' => ' no warnings ;',
            'start_line' => 370,
            'indent' => 2,
            'block_id' => 37
          },
          {
            'token_num' => 11,
            'has_warnings' => 1,
            'end_line' => 375,
            'src' => ' ok ! Colon-> isa ( "Organ" ) , \'class that isa "class:" no longer isa foo if "class:" has been deleted\' ;',
            'start_line' => 374,
            'indent' => 1,
            'block_id' => 36
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 377,
            'src' => ' @Colon::ISA = \':\' ;',
            'start_line' => 377,
            'indent' => 0,
            'block_id' => 4
          },
          {
            'token_num' => 6,
            'has_warnings' => 0,
            'end_line' => 378,
            'src' => ' bless [ ] , ":" ;',
            'start_line' => 378,
            'indent' => 0,
            'block_id' => 4
          },
          {
            'token_num' => 10,
            'has_warnings' => 1,
            'end_line' => 379,
            'src' => ' ok "Colon"-> isa ( ":" ) , \'class isa ":"\' ;',
            'start_line' => 379,
            'indent' => 0,
            'block_id' => 4
          },
          {
            'token_num' => 104,
            'has_warnings' => 1,
            'end_line' => 400,
            'src' => ' { no strict \'refs\' ; * { ":::" } = * Punctuation::} ok "Colon"-> isa ( "Punctuation" ) , \'isa(foo) when inheriting from ":" which is an alias for foo\' ; @Colon::ISA = \'Organ:\' ; bless [ ] , "Organ:" ; { no strict \'refs\' ; my $life_raft = \\ %{ "Organ:::" } ; * { "Organ:::" } = \\ %Organ::; ok "Colon"-> isa ( "Organ" ) , \'isa(foo) when inheriting from "class:" after hash-to-glob assignment\' ; } @Colon::ISA = \'O:\' ; bless [ ] , "O:" ; { no strict \'refs\' ; my $life_raft = \\ %{ "O:::" } ; * { "O:::" } = "Organ::" ; ok "Colon"-> isa ( "Organ" ) , \'isa(foo) when inheriting from "class:" after string-to-glob assignment\' ; }',
            'start_line' => 380,
            'indent' => 0,
            'block_id' => 4
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 380,
            'src' => ' no strict \'refs\' ;',
            'start_line' => 380,
            'indent' => 1,
            'block_id' => 38
          },
          {
            'token_num' => 17,
            'has_warnings' => 1,
            'end_line' => 382,
            'src' => ' * { ":::" } = * Punctuation::} ok "Colon"-> isa ( "Punctuation" ) , \'isa(foo) when inheriting from ":" which is an alias for foo\' ;',
            'start_line' => 380,
            'indent' => 1,
            'block_id' => 38
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 383,
            'src' => ' @Colon::ISA = \'Organ:\' ;',
            'start_line' => 383,
            'indent' => 1,
            'block_id' => 38
          },
          {
            'token_num' => 6,
            'has_warnings' => 0,
            'end_line' => 384,
            'src' => ' bless [ ] , "Organ:" ;',
            'start_line' => 384,
            'indent' => 1,
            'block_id' => 38
          },
          {
            'token_num' => 31,
            'has_warnings' => 1,
            'end_line' => 391,
            'src' => ' { no strict \'refs\' ; my $life_raft = \\ %{ "Organ:::" } ; * { "Organ:::" } = \\ %Organ::; ok "Colon"-> isa ( "Organ" ) , \'isa(foo) when inheriting from "class:" after hash-to-glob assignment\' ; }',
            'start_line' => 385,
            'indent' => 1,
            'block_id' => 38
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 386,
            'src' => ' no strict \'refs\' ;',
            'start_line' => 386,
            'indent' => 2,
            'block_id' => 39
          },
          {
            'token_num' => 8,
            'has_warnings' => 0,
            'end_line' => 387,
            'src' => ' my $life_raft = \\ %{ "Organ:::" } ;',
            'start_line' => 387,
            'indent' => 2,
            'block_id' => 39
          },
          {
            'token_num' => 17,
            'has_warnings' => 1,
            'end_line' => 390,
            'src' => ' * { "Organ:::" } = \\ %Organ::; ok "Colon"-> isa ( "Organ" ) , \'isa(foo) when inheriting from "class:" after hash-to-glob assignment\' ;',
            'start_line' => 388,
            'indent' => 2,
            'block_id' => 39
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 392,
            'src' => ' @Colon::ISA = \'O:\' ;',
            'start_line' => 392,
            'indent' => 1,
            'block_id' => 38
          },
          {
            'token_num' => 6,
            'has_warnings' => 0,
            'end_line' => 393,
            'src' => ' bless [ ] , "O:" ;',
            'start_line' => 393,
            'indent' => 1,
            'block_id' => 38
          },
          {
            'token_num' => 31,
            'has_warnings' => 1,
            'end_line' => 400,
            'src' => ' { no strict \'refs\' ; my $life_raft = \\ %{ "O:::" } ; * { "O:::" } = "Organ::" ; ok "Colon"-> isa ( "Organ" ) , \'isa(foo) when inheriting from "class:" after string-to-glob assignment\' ; }',
            'start_line' => 394,
            'indent' => 1,
            'block_id' => 38
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 395,
            'src' => ' no strict \'refs\' ;',
            'start_line' => 395,
            'indent' => 2,
            'block_id' => 40
          },
          {
            'token_num' => 8,
            'has_warnings' => 0,
            'end_line' => 396,
            'src' => ' my $life_raft = \\ %{ "O:::" } ;',
            'start_line' => 396,
            'indent' => 2,
            'block_id' => 40
          },
          {
            'token_num' => 7,
            'has_warnings' => 0,
            'end_line' => 397,
            'src' => ' * { "O:::" } = "Organ::" ;',
            'start_line' => 397,
            'indent' => 2,
            'block_id' => 40
          },
          {
            'token_num' => 10,
            'has_warnings' => 1,
            'end_line' => 399,
            'src' => ' ok "Colon"-> isa ( "Organ" ) , \'isa(foo) when inheriting from "class:" after string-to-glob assignment\' ;',
            'start_line' => 398,
            'indent' => 2,
            'block_id' => 40
          }
        ]
, 'Compiler::Lexer::get_groups_by_syntax_level');
};

subtest 'get_used_modules' => sub {
    my $modules = Compiler::Lexer->new('')->get_used_modules($script);
    is_deeply($modules, [
          {
            'args' => '',
            'name' => 'strict'
          },
          {
            'args' => '',
            'name' => 'warnings'
          },
          {
            'args' => '',
            'name' => 'strict'
          },
          {
            'args' => '',
            'name' => 'warnings'
          },
          {
            'args' => '',
            'name' => 'strict'
          },
          {
            'args' => '',
            'name' => 'warnings'
          },
          {
            'args' => '',
            'name' => 'warnings'
          }
        ]
, 'Compiler::Lexer::get_used_modules');
};

done_testing;
