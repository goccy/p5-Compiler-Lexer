use strict;
use warnings;
use Test::More;
BEGIN {
    use_ok('Compiler::Lexer');
}
my $script =<<'SCRIPT';
#!./perl -w
#
# Tests to make sure the regexp engine doesn't run into limits too soon.
#

BEGIN {
    chdir 't' if -d 't';
    @INC = '../lib';
    require './test.pl';
}

use strict;

my $email = qr {
    (?(DEFINE)
      (?<address>         (?&mailbox) | (?&group))
      (?<mailbox>         (?&name_addr) | (?&addr_spec))
      (?<name_addr>       (?&display_name)? (?&angle_addr))
      (?<angle_addr>      (?&CFWS)? < (?&addr_spec) > (?&CFWS)?)
      (?<group>           (?&display_name) : (?:(?&mailbox_list) | (?&CFWS))? ;
                                             (?&CFWS)?)
      (?<display_name>    (?&phrase))
      (?<mailbox_list>    (?&mailbox) (?: , (?&mailbox))*)

      (?<addr_spec>       (?&local_part) \@ (?&domain))
      (?<local_part>      (?&dot_atom) | (?&quoted_string))
      (?<domain>          (?&dot_atom) | (?&domain_literal))
      (?<domain_literal>  (?&CFWS)? \[ (?: (?&FWS)? (?&dcontent))* (?&FWS)?
                                    \] (?&CFWS)?)
      (?<dcontent>        (?&dtext) | (?&quoted_pair))
      (?<dtext>           (?&NO_WS_CTL) | [\x21-\x5a\x5e-\x7e])

      (?<atext>           (?&ALPHA) | (?&DIGIT) | [-!#\$%&'*+/=?^_`{|}~])
      (?<atom>            (?&CFWS)? (?&atext)+ (?&CFWS)?)
      (?<dot_atom>        (?&CFWS)? (?&dot_atom_text) (?&CFWS)?)
      (?<dot_atom_text>   (?&atext)+ (?: \. (?&atext)+)*)

      (?<text>            [\x01-\x09\x0b\x0c\x0e-\x7f])
      (?<quoted_pair>     \\ (?&text))

      (?<qtext>           (?&NO_WS_CTL) | [\x21\x23-\x5b\x5d-\x7e])
      (?<qcontent>        (?&qtext) | (?&quoted_pair))
      (?<quoted_string>   (?&CFWS)? (?&DQUOTE) (?:(?&FWS)? (?&qcontent))*
                           (?&FWS)? (?&DQUOTE) (?&CFWS)?)

      (?<word>            (?&atom) | (?&quoted_string))
      (?<phrase>          (?&word)+)

      # Folding white space
      (?<FWS>             (?: (?&WSP)* (?&CRLF))? (?&WSP)+)
      (?<ctext>           (?&NO_WS_CTL) | [\x21-\x27\x2a-\x5b\x5d-\x7e])
      (?<ccontent>        (?&ctext) | (?&quoted_pair) | (?&comment))
      (?<comment>         \( (?: (?&FWS)? (?&ccontent))* (?&FWS)? \) )
      (?<CFWS>            (?: (?&FWS)? (?&comment))*
                          (?: (?:(?&FWS)? (?&comment)) | (?&FWS)))

      # No whitespace control
      (?<NO_WS_CTL>       [\x01-\x08\x0b\x0c\x0e-\x1f\x7f])

      (?<ALPHA>           [A-Za-z])
      (?<DIGIT>           [0-9])
      (?<CRLF>            \x0d \x0a)
      (?<DQUOTE>          ")
      (?<WSP>             [\x20\x09])
    )

    (?&address)
}x;

run_tests() unless caller;

sub run_tests {
    # rewinding DATA is necessary with PERLIO=stdio when this
    # test is run from another thread
    seek *DATA, 0, 0;
    while (<DATA>) { last if /^__DATA__/ }
    while (<DATA>) {
	chomp;
	next if /^#/;
	like($_, qr/^$email$/, $_);
    }

    done_testing();
}

1; # Because reg_email_thr.t will (indirectly) require this script.

#
# Acme::MetaSyntactic ++
#
__DATA__
Jeff_Tracy@thunderbirds.org
"Lady Penelope"@thunderbirds.org
"The\ Hood"@thunderbirds.org
fred @ flintstones.net
barney (rubble) @ flintstones.org
bammbamm (bam! bam! (bam! bam! (bam!)) bam!) @ flintstones.org
Michelangelo@[127.0.0.1]
Donatello @ [127.0.0.1]
Raphael (He as well) @ [127.0.0.1]
"Leonardo" @ [127.0.0.1]
Barbapapa <barbapapa @ barbapapa.net>
"Barba Mama" <barbamama @ [127.0.0.1]>
Barbalala (lalalalalalalala) <barbalala (Yes, her!) @ (barba) barbapapa.net>

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
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 6
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'chdir',
                   'type' => 64,
                   'line' => 7
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 't',
                   'type' => 164,
                   'line' => 7
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'IfStmt',
                   'data' => 'if',
                   'type' => 89,
                   'line' => 7
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 13,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Handle',
                   'data' => '-d',
                   'type' => 83,
                   'line' => 7
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => 't',
                   'type' => 164,
                   'line' => 7
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 7
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LibraryDirectories',
                   'data' => '@INC',
                   'type' => 132,
                   'line' => 8
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 8
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => '../lib',
                   'type' => 164,
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
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RequireDecl',
                   'data' => 'require',
                   'type' => 65,
                   'line' => 9
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RawString',
                   'data' => './test.pl',
                   'type' => 164,
                   'line' => 9
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 9
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 10
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
                   'data' => 'strict',
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
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'type' => 57,
                   'line' => 14
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LocalVar',
                   'data' => '$email',
                   'type' => 176,
                   'line' => 14
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 2,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Assign',
                   'data' => '=',
                   'type' => 60,
                   'line' => 14
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDecl',
                   'data' => 'qr',
                   'type' => 141,
                   'line' => 14
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '{',
                   'type' => 143,
                   'line' => 14
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => '
    (?(DEFINE)
      (?<address>         (?&mailbox) | (?&group))
      (?<mailbox>         (?&name_addr) | (?&addr_spec))
      (?<name_addr>       (?&display_name)? (?&angle_addr))
      (?<angle_addr>      (?&CFWS)? < (?&addr_spec) > (?&CFWS)?)
      (?<group>           (?&display_name) : (?:(?&mailbox_list) | (?&CFWS))? ;
                                             (?&CFWS)?)
      (?<display_name>    (?&phrase))
      (?<mailbox_list>    (?&mailbox) (?: , (?&mailbox))*)

      (?<addr_spec>       (?&local_part) \\@ (?&domain))
      (?<local_part>      (?&dot_atom) | (?&quoted_string))
      (?<domain>          (?&dot_atom) | (?&domain_literal))
      (?<domain_literal>  (?&CFWS)? \\[ (?: (?&FWS)? (?&dcontent))* (?&FWS)?
                                    \\] (?&CFWS)?)
      (?<dcontent>        (?&dtext) | (?&quoted_pair))
      (?<dtext>           (?&NO_WS_CTL) | [\\x21-\\x5a\\x5e-\\x7e])

      (?<atext>           (?&ALPHA) | (?&DIGIT) | [-!#\\$%&\'*+/=?^_`{|}~])
      (?<atom>            (?&CFWS)? (?&atext)+ (?&CFWS)?)
      (?<dot_atom>        (?&CFWS)? (?&dot_atom_text) (?&CFWS)?)
      (?<dot_atom_text>   (?&atext)+ (?: \\. (?&atext)+)*)

      (?<text>            [\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])
      (?<quoted_pair>     \\\\ (?&text))

      (?<qtext>           (?&NO_WS_CTL) | [\\x21\\x23-\\x5b\\x5d-\\x7e])
      (?<qcontent>        (?&qtext) | (?&quoted_pair))
      (?<quoted_string>   (?&CFWS)? (?&DQUOTE) (?:(?&FWS)? (?&qcontent))*
                           (?&FWS)? (?&DQUOTE) (?&CFWS)?)

      (?<word>            (?&atom) | (?&quoted_string))
      (?<phrase>          (?&word)+)

      # Folding white space
      (?<FWS>             (?: (?&WSP)* (?&CRLF))? (?&WSP)+)
      (?<ctext>           (?&NO_WS_CTL) | [\\x21-\\x27\\x2a-\\x5b\\x5d-\\x7e])
      (?<ccontent>        (?&ctext) | (?&quoted_pair) | (?&comment))
      (?<comment>         \\( (?: (?&FWS)? (?&ccontent))* (?&FWS)? \\) )
      (?<CFWS>            (?: (?&FWS)? (?&comment))*
                          (?: (?:(?&FWS)? (?&comment)) | (?&FWS)))

      # No whitespace control
      (?<NO_WS_CTL>       [\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x7f])

      (?<ALPHA>           [A-Za-z])
      (?<DIGIT>           [0-9])
      (?<CRLF>            \\x0d \\x0a)
      (?<DQUOTE>          ")
      (?<WSP>             [\\x20\\x09])
    )

    (?&address)
',
                   'type' => 172,
                   'line' => 68
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '}',
                   'type' => 143,
                   'line' => 68
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegOpt',
                   'data' => 'x',
                   'type' => 136,
                   'line' => 68
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 68
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'run_tests',
                   'type' => 114,
                   'line' => 70
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 70
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 70
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'UnlessStmt',
                   'data' => 'unless',
                   'type' => 92,
                   'line' => 70
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'caller',
                   'type' => 64,
                   'line' => 70
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 70
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'FunctionDecl',
                   'data' => 'sub',
                   'type' => 58,
                   'line' => 72
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 3,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Function',
                   'data' => 'run_tests',
                   'type' => 188,
                   'line' => 72
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 72
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'seek',
                   'type' => 64,
                   'line' => 75
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Mul',
                   'data' => '*',
                   'type' => 3,
                   'line' => 75
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'DATA',
                   'type' => 114,
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
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Int',
                   'data' => '0',
                   'type' => 161,
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
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Int',
                   'data' => '0',
                   'type' => 161,
                   'line' => 75
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 75
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'WhileStmt',
                   'data' => 'while',
                   'type' => 124,
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Less',
                   'data' => '<',
                   'type' => 8,
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'DATA',
                   'type' => 114,
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Greater',
                   'data' => '>',
                   'type' => 7,
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 76
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
                   'kind' => 16,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Last',
                   'data' => 'last',
                   'type' => 78,
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'IfStmt',
                   'data' => 'if',
                   'type' => 89,
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => '^__DATA__',
                   'type' => 172,
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
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
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'WhileStmt',
                   'data' => 'while',
                   'type' => 124,
                   'line' => 77
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 77
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Less',
                   'data' => '<',
                   'type' => 8,
                   'line' => 77
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'DATA',
                   'type' => 114,
                   'line' => 77
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 1,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Greater',
                   'data' => '>',
                   'type' => 7,
                   'line' => 77
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 77
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => 102,
                   'line' => 77
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 4,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'BuiltinFunc',
                   'data' => 'chomp',
                   'type' => 64,
                   'line' => 78
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 78
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 15,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Next',
                   'data' => 'next',
                   'type' => 77,
                   'line' => 79
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 22,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'IfStmt',
                   'data' => 'if',
                   'type' => 89,
                   'line' => 79
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 79
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => '^#',
                   'type' => 172,
                   'line' => 79
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 79
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 79
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'like',
                   'type' => 114,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SpecificValue',
                   'data' => '$_',
                   'type' => 129,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDecl',
                   'data' => 'qr',
                   'type' => 141,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegExp',
                   'data' => '^$email$',
                   'type' => 172,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RegDelim',
                   'data' => '/',
                   'type' => 143,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 24,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Comma',
                   'data' => ',',
                   'type' => 97,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SpecificValue',
                   'data' => '$_',
                   'type' => 129,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 81
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 1,
                   'stype' => 0,
                   'name' => 'Key',
                   'data' => 'done_testing',
                   'type' => 114,
                   'line' => 83
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'type' => 100,
                   'line' => 83
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'type' => 101,
                   'line' => 83
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 83
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 27,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'RightBrace',
                   'data' => '}',
                   'type' => 103,
                   'line' => 84
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 21,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'Int',
                   'data' => '1',
                   'type' => 161,
                   'line' => 86
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => 26,
                   'has_warnings' => 0,
                   'stype' => 0,
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => 99,
                   'line' => 86
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
            'token_num' => 6,
            'has_warnings' => 0,
            'end_line' => 7,
            'src' => ' chdir \'t\' if -d \'t\' ;',
            'start_line' => 7,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 4,
            'has_warnings' => 0,
            'end_line' => 8,
            'src' => ' @INC = \'../lib\' ;',
            'start_line' => 8,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 3,
            'has_warnings' => 0,
            'end_line' => 9,
            'src' => ' require \'./test.pl\' ;',
            'start_line' => 9,
            'indent' => 1,
            'block_id' => 1
          },
          {
            'token_num' => 3,
            'has_warnings' => 0,
            'end_line' => 12,
            'src' => ' use strict ;',
            'start_line' => 12,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 9,
            'has_warnings' => 0,
            'end_line' => 68,
            'src' => ' my $email = qr{
    (?(DEFINE)
      (?<address>         (?&mailbox) | (?&group))
      (?<mailbox>         (?&name_addr) | (?&addr_spec))
      (?<name_addr>       (?&display_name)? (?&angle_addr))
      (?<angle_addr>      (?&CFWS)? < (?&addr_spec) > (?&CFWS)?)
      (?<group>           (?&display_name) : (?:(?&mailbox_list) | (?&CFWS))? ;
                                             (?&CFWS)?)
      (?<display_name>    (?&phrase))
      (?<mailbox_list>    (?&mailbox) (?: , (?&mailbox))*)

      (?<addr_spec>       (?&local_part) \\@ (?&domain))
      (?<local_part>      (?&dot_atom) | (?&quoted_string))
      (?<domain>          (?&dot_atom) | (?&domain_literal))
      (?<domain_literal>  (?&CFWS)? \\[ (?: (?&FWS)? (?&dcontent))* (?&FWS)?
                                    \\] (?&CFWS)?)
      (?<dcontent>        (?&dtext) | (?&quoted_pair))
      (?<dtext>           (?&NO_WS_CTL) | [\\x21-\\x5a\\x5e-\\x7e])

      (?<atext>           (?&ALPHA) | (?&DIGIT) | [-!#\\$%&\'*+/=?^_`{|}~])
      (?<atom>            (?&CFWS)? (?&atext)+ (?&CFWS)?)
      (?<dot_atom>        (?&CFWS)? (?&dot_atom_text) (?&CFWS)?)
      (?<dot_atom_text>   (?&atext)+ (?: \\. (?&atext)+)*)

      (?<text>            [\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])
      (?<quoted_pair>     \\\\ (?&text))

      (?<qtext>           (?&NO_WS_CTL) | [\\x21\\x23-\\x5b\\x5d-\\x7e])
      (?<qcontent>        (?&qtext) | (?&quoted_pair))
      (?<quoted_string>   (?&CFWS)? (?&DQUOTE) (?:(?&FWS)? (?&qcontent))*
                           (?&FWS)? (?&DQUOTE) (?&CFWS)?)

      (?<word>            (?&atom) | (?&quoted_string))
      (?<phrase>          (?&word)+)

      # Folding white space
      (?<FWS>             (?: (?&WSP)* (?&CRLF))? (?&WSP)+)
      (?<ctext>           (?&NO_WS_CTL) | [\\x21-\\x27\\x2a-\\x5b\\x5d-\\x7e])
      (?<ccontent>        (?&ctext) | (?&quoted_pair) | (?&comment))
      (?<comment>         \\( (?: (?&FWS)? (?&ccontent))* (?&FWS)? \\) )
      (?<CFWS>            (?: (?&FWS)? (?&comment))*
                          (?: (?:(?&FWS)? (?&comment)) | (?&FWS)))

      # No whitespace control
      (?<NO_WS_CTL>       [\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x7f])

      (?<ALPHA>           [A-Za-z])
      (?<DIGIT>           [0-9])
      (?<CRLF>            \\x0d \\x0a)
      (?<DQUOTE>          ")
      (?<WSP>             [\\x20\\x09])
    )

    (?&address)
}x ;',
            'start_line' => 14,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 6,
            'has_warnings' => 1,
            'end_line' => 70,
            'src' => ' run_tests ( ) unless caller ;',
            'start_line' => 70,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 57,
            'has_warnings' => 1,
            'end_line' => 84,
            'src' => ' sub run_tests { seek * DATA , 0 , 0 ; while ( < DATA > ) { last if/^__DATA__/ } while ( < DATA > ) { chomp ; next if/^#/ ; like ( $_ , qr/^$email$/ , $_ ) ; } done_testing ( ) ; }',
            'start_line' => 72,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'token_num' => 8,
            'has_warnings' => 1,
            'end_line' => 75,
            'src' => ' seek * DATA , 0 , 0 ;',
            'start_line' => 75,
            'indent' => 1,
            'block_id' => 2
          },
          {
            'token_num' => 13,
            'has_warnings' => 1,
            'end_line' => 76,
            'src' => ' while ( < DATA > ) { last if/^__DATA__/ }',
            'start_line' => 76,
            'indent' => 1,
            'block_id' => 2
          },
          {
            'token_num' => 28,
            'has_warnings' => 1,
            'end_line' => 81,
            'src' => ' while ( < DATA > ) { chomp ; next if/^#/ ; like ( $_ , qr/^$email$/ , $_ ) ; }',
            'start_line' => 77,
            'indent' => 1,
            'block_id' => 2
          },
          {
            'token_num' => 2,
            'has_warnings' => 0,
            'end_line' => 78,
            'src' => ' chomp ;',
            'start_line' => 78,
            'indent' => 2,
            'block_id' => 4
          },
          {
            'token_num' => 6,
            'has_warnings' => 0,
            'end_line' => 79,
            'src' => ' next if/^#/ ;',
            'start_line' => 79,
            'indent' => 2,
            'block_id' => 4
          },
          {
            'token_num' => 12,
            'has_warnings' => 1,
            'end_line' => 80,
            'src' => ' like ( $_ , qr/^$email$/ , $_ ) ;',
            'start_line' => 80,
            'indent' => 2,
            'block_id' => 4
          },
          {
            'token_num' => 4,
            'has_warnings' => 1,
            'end_line' => 83,
            'src' => ' done_testing ( ) ;',
            'start_line' => 83,
            'indent' => 1,
            'block_id' => 2
          },
          {
            'token_num' => 2,
            'has_warnings' => 0,
            'end_line' => 86,
            'src' => ' 1 ;',
            'start_line' => 86,
            'indent' => 0,
            'block_id' => 0
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
          }
        ]
, 'Compiler::Lexer::get_used_modules');
};

done_testing;
