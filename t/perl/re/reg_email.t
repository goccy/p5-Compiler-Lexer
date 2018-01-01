use strict;
use warnings;
use Test::More;
BEGIN {
    use_ok('Compiler::Lexer');
}
my $script =<<'__SCRIPT__';
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
no warnings 'experimental::regex_sets';

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
      (?<dtext>           (?&NO_WS_CTL) | (?[ [:ascii:] & [:graph:] & [^][ \\ ] ]))

      (?<atext>           (?&ALPHA) | (?&DIGIT) | [-!#\$%&'*+/=?^_`{|}~])
      (?<atom>            (?&CFWS)? (?&atext)+ (?&CFWS)?)
      (?<dot_atom>        (?&CFWS)? (?&dot_atom_text) (?&CFWS)?)
      (?<dot_atom_text>   (?&atext)+ (?: \. (?&atext)+)*)

      (?<text>            (?[ [:ascii:] & [^ \000 \n \r ] ]))
      (?<quoted_pair>     \\ (?&text))

      (?<qtext>           (?&NO_WS_CTL) | (?[ [:ascii:] & [:graph:] & [^ " \\ ] ]))
      (?<qcontent>        (?&qtext) | (?&quoted_pair))
      (?<quoted_string>   (?&CFWS)? (?&DQUOTE) (?:(?&FWS)? (?&qcontent))*
                           (?&FWS)? (?&DQUOTE) (?&CFWS)?)

      (?<word>            (?&atom) | (?&quoted_string))
      (?<phrase>          (?&word)+)

      # Folding white space
      (?<FWS>             (?: (?&WSP)* (?&CRLF))? (?&WSP)+)
      (?<ctext>           (?&NO_WS_CTL) | (?[ [:ascii:] & [:graph:] & [^ () ] & [^ \\ ] ]))
      (?<ccontent>        (?&ctext) | (?&quoted_pair) | (?&comment))
      (?<comment>         \( (?: (?&FWS)? (?&ccontent))* (?&FWS)? \) )
      (?<CFWS>            (?: (?&FWS)? (?&comment))*
                          (?: (?:(?&FWS)? (?&comment)) | (?&FWS)))

      # No whitespace control
      (?<NO_WS_CTL>       (?[ [:ascii:] & [:cntrl:] & [^ \000 \h \r \n ] ]))

      (?<ALPHA>           [A-Za-z])
      (?<DIGIT>           [0-9])
      (?<CRLF>            \r \n)
      (?<DQUOTE>          ")
      (?<WSP>             [ \t])
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

__SCRIPT__

subtest 'tokenize' => sub {
    my $tokens = Compiler::Lexer->new('')->tokenize($script);
    is_deeply($tokens, [
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_ModWord,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_ModWord,
                   'line' => 6,
                   'data' => 'BEGIN',
                   'name' => 'ModWord'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'line' => 6,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 7,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'BuiltinFunc',
                   'data' => 'chdir'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 7,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'name' => 'RawString',
                   'data' => 't'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'IfStmt',
                   'data' => 'if',
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 7
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-d',
                   'name' => 'Handle',
                   'line' => 7,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'data' => 't',
                   'line' => 7,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 7,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 8,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LibraryDirectories,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '@INC',
                   'name' => 'LibraryDirectories'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 8,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'name' => 'Assign',
                   'data' => '='
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 8,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'data' => '../lib'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 8
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'require',
                   'name' => 'RequireDecl',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RequireDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 9
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => './test.pl',
                   'name' => 'RawString',
                   'line' => 9,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 9
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightBrace',
                   'data' => '}',
                   'line' => 10,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 12,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'UseDecl',
                   'data' => 'use'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'strict',
                   'name' => 'UsedName',
                   'line' => 12,
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 12,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 13,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'BuiltinFunc',
                   'data' => 'no'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'warnings',
                   'name' => 'Key',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 13
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'data' => 'experimental::regex_sets',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'line' => 13
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'line' => 13,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'VarDecl',
                   'data' => 'my',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 15
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$email',
                   'name' => 'LocalVar',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 15
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 15,
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Assign',
                   'data' => '='
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegDecl,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'line' => 15,
                   'name' => 'RegDecl',
                   'data' => 'qr'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'name' => 'RegDelim',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'line' => 15
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 69,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'kind' => Compiler::Lexer::Kind::T_Term,
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
      (?<dtext>           (?&NO_WS_CTL) | (?[ [:ascii:] & [:graph:] & [^][ \\\\ ] ]))

      (?<atext>           (?&ALPHA) | (?&DIGIT) | [-!#\\$%&\'*+/=?^_`{|}~])
      (?<atom>            (?&CFWS)? (?&atext)+ (?&CFWS)?)
      (?<dot_atom>        (?&CFWS)? (?&dot_atom_text) (?&CFWS)?)
      (?<dot_atom_text>   (?&atext)+ (?: \\. (?&atext)+)*)

      (?<text>            (?[ [:ascii:] & [^ \\000 \\n \\r ] ]))
      (?<quoted_pair>     \\\\ (?&text))

      (?<qtext>           (?&NO_WS_CTL) | (?[ [:ascii:] & [:graph:] & [^ " \\\\ ] ]))
      (?<qcontent>        (?&qtext) | (?&quoted_pair))
      (?<quoted_string>   (?&CFWS)? (?&DQUOTE) (?:(?&FWS)? (?&qcontent))*
                           (?&FWS)? (?&DQUOTE) (?&CFWS)?)

      (?<word>            (?&atom) | (?&quoted_string))
      (?<phrase>          (?&word)+)

      # Folding white space
      (?<FWS>             (?: (?&WSP)* (?&CRLF))? (?&WSP)+)
      (?<ctext>           (?&NO_WS_CTL) | (?[ [:ascii:] & [:graph:] & [^ () ] & [^ \\\\ ] ]))
      (?<ccontent>        (?&ctext) | (?&quoted_pair) | (?&comment))
      (?<comment>         \\( (?: (?&FWS)? (?&ccontent))* (?&FWS)? \\) )
      (?<CFWS>            (?: (?&FWS)? (?&comment))*
                          (?: (?:(?&FWS)? (?&comment)) | (?&FWS)))

      # No whitespace control
      (?<NO_WS_CTL>       (?[ [:ascii:] & [:cntrl:] & [^ \\000 \\h \\r \\n ] ]))

      (?<ALPHA>           [A-Za-z])
      (?<DIGIT>           [0-9])
      (?<CRLF>            \\r \\n)
      (?<DQUOTE>          ")
      (?<WSP>             [ \\t])
    )

    (?&address)
'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'name' => 'RegDelim',
                   'line' => 69,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'x',
                   'name' => 'RegOpt',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_RegOpt,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegOpt,
                   'line' => 69
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'line' => 69,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 71,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'run_tests',
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 71,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'name' => 'LeftParenthesis',
                   'data' => '('
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 71
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'unless',
                   'name' => 'UnlessStmt',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'type' => Compiler::Lexer::TokenType::T_UnlessStmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 71
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'caller',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 71
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'line' => 71,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 73,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'name' => 'FunctionDecl',
                   'data' => 'sub'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'run_tests',
                   'name' => 'Function',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 73
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'line' => 73,
                   'name' => 'LeftBrace',
                   'data' => '{'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'seek',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 76,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'type' => Compiler::Lexer::TokenType::T_Mul,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Mul',
                   'data' => '*DATA'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 76,
                   'name' => 'Comma',
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '0',
                   'name' => 'Int',
                   'line' => 76,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 76,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 76,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'name' => 'Int',
                   'data' => '0'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_WhileStmt,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'line' => 77,
                   'data' => 'while',
                   'name' => 'WhileStmt'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 77,
                   'data' => '(',
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_HandleDelim,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 77,
                   'name' => 'HandleDelim',
                   'data' => '<'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 77,
                   'name' => 'Key',
                   'data' => 'DATA'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '>',
                   'name' => 'HandleDelim',
                   'line' => 77,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_HandleDelim
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'line' => 77,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '{',
                   'name' => 'LeftBrace',
                   'line' => 77,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Last,
                   'kind' => Compiler::Lexer::Kind::T_Control,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 77,
                   'data' => 'last',
                   'name' => 'Last'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'line' => 77,
                   'data' => 'if',
                   'name' => 'IfStmt'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 77,
                   'name' => 'RegDelim',
                   'data' => '/'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 77,
                   'data' => '^__DATA__',
                   'name' => 'RegExp'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 77,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '/',
                   'name' => 'RegDelim'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 77,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '}',
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'while',
                   'name' => 'WhileStmt',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'type' => Compiler::Lexer::TokenType::T_WhileStmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 78
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'line' => 78,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 78,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_HandleDelim,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '<',
                   'name' => 'HandleDelim'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'DATA',
                   'name' => 'Key',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 78
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 78,
                   'type' => Compiler::Lexer::TokenType::T_HandleDelim,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'HandleDelim',
                   'data' => '>'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 78
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'line' => 78
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'data' => 'chomp',
                   'line' => 79,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 79
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Next',
                   'data' => 'next',
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Control,
                   'type' => Compiler::Lexer::TokenType::T_Next,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'if',
                   'name' => 'IfStmt',
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 80,
                   'data' => '/',
                   'name' => 'RegDelim'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 80,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegExp',
                   'data' => '^#'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegDelim',
                   'data' => '/',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'like',
                   'name' => 'Key',
                   'line' => 81,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 1,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 81,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'data' => '(',
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 81,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '$_',
                   'name' => 'SpecificValue'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 81,
                   'name' => 'Comma',
                   'data' => ','
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegDecl',
                   'data' => 'qr',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDecl,
                   'line' => 81
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'line' => 81,
                   'data' => '/',
                   'name' => 'RegDelim'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '^$email$',
                   'name' => 'RegExp',
                   'line' => 81,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegDelim',
                   'data' => '/',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'line' => 81
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 81,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ',',
                   'name' => 'Comma'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 81,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'name' => 'SpecificValue',
                   'data' => '$_'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'line' => 81
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'data' => ';',
                   'line' => 81,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '}',
                   'name' => 'RightBrace',
                   'line' => 82,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'data' => 'done_testing',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'line' => 84
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'data' => '(',
                   'line' => 84,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 84,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'name' => 'RightParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 84,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'SemiColon',
                   'data' => ';'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'line' => 85,
                   'data' => '}',
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'line' => 87,
                   'data' => '1',
                   'name' => 'Int'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'name' => 'SemiColon',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'line' => 87
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
            'start_line' => 7,
            'src' => ' chdir \'t\' if -d \'t\' ;',
            'indent' => 1,
            'token_num' => 6,
            'block_id' => 1,
            'has_warnings' => 0,
            'end_line' => 7
          },
          {
            'start_line' => 8,
            'indent' => 1,
            'src' => ' @INC = \'../lib\' ;',
            'end_line' => 8,
            'has_warnings' => 0,
            'block_id' => 1,
            'token_num' => 4
          },
          {
            'block_id' => 1,
            'token_num' => 3,
            'has_warnings' => 0,
            'end_line' => 9,
            'indent' => 1,
            'src' => ' require \'./test.pl\' ;',
            'start_line' => 9
          },
          {
            'start_line' => 12,
            'indent' => 0,
            'src' => ' use strict ;',
            'block_id' => 0,
            'token_num' => 3,
            'has_warnings' => 0,
            'end_line' => 12
          },
          {
            'indent' => 0,
            'src' => ' no warnings \'experimental::regex_sets\' ;',
            'start_line' => 13,
            'token_num' => 4,
            'block_id' => 0,
            'end_line' => 13,
            'has_warnings' => 1
          },
          {
            'block_id' => 0,
            'token_num' => 9,
            'end_line' => 69,
            'has_warnings' => 0,
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
      (?<dtext>           (?&NO_WS_CTL) | (?[ [:ascii:] & [:graph:] & [^][ \\\\ ] ]))

      (?<atext>           (?&ALPHA) | (?&DIGIT) | [-!#\\$%&\'*+/=?^_`{|}~])
      (?<atom>            (?&CFWS)? (?&atext)+ (?&CFWS)?)
      (?<dot_atom>        (?&CFWS)? (?&dot_atom_text) (?&CFWS)?)
      (?<dot_atom_text>   (?&atext)+ (?: \\. (?&atext)+)*)

      (?<text>            (?[ [:ascii:] & [^ \\000 \\n \\r ] ]))
      (?<quoted_pair>     \\\\ (?&text))

      (?<qtext>           (?&NO_WS_CTL) | (?[ [:ascii:] & [:graph:] & [^ " \\\\ ] ]))
      (?<qcontent>        (?&qtext) | (?&quoted_pair))
      (?<quoted_string>   (?&CFWS)? (?&DQUOTE) (?:(?&FWS)? (?&qcontent))*
                           (?&FWS)? (?&DQUOTE) (?&CFWS)?)

      (?<word>            (?&atom) | (?&quoted_string))
      (?<phrase>          (?&word)+)

      # Folding white space
      (?<FWS>             (?: (?&WSP)* (?&CRLF))? (?&WSP)+)
      (?<ctext>           (?&NO_WS_CTL) | (?[ [:ascii:] & [:graph:] & [^ () ] & [^ \\\\ ] ]))
      (?<ccontent>        (?&ctext) | (?&quoted_pair) | (?&comment))
      (?<comment>         \\( (?: (?&FWS)? (?&ccontent))* (?&FWS)? \\) )
      (?<CFWS>            (?: (?&FWS)? (?&comment))*
                          (?: (?:(?&FWS)? (?&comment)) | (?&FWS)))

      # No whitespace control
      (?<NO_WS_CTL>       (?[ [:ascii:] & [:cntrl:] & [^ \\000 \\h \\r \\n ] ]))

      (?<ALPHA>           [A-Za-z])
      (?<DIGIT>           [0-9])
      (?<CRLF>            \\r \\n)
      (?<DQUOTE>          ")
      (?<WSP>             [ \\t])
    )

    (?&address)
}x ;',
            'indent' => 0,
            'start_line' => 15
          },
          {
            'src' => ' run_tests ( ) unless caller ;',
            'indent' => 0,
            'start_line' => 71,
            'end_line' => 71,
            'has_warnings' => 1,
            'block_id' => 0,
            'token_num' => 6
          },
          {
            'block_id' => 0,
            'token_num' => 56,
            'has_warnings' => 1,
            'end_line' => 85,
            'indent' => 0,
            'src' => ' sub run_tests { seek *DATA , 0 , 0 ; while ( < DATA > ) { last if/^__DATA__/ } while ( < DATA > ) { chomp ; next if/^#/ ; like ( $_ , qr/^$email$/ , $_ ) ; } done_testing ( ) ; }',
            'start_line' => 73
          },
          {
            'end_line' => 76,
            'has_warnings' => 0,
            'block_id' => 2,
            'token_num' => 7,
            'start_line' => 76,
            'indent' => 1,
            'src' => ' seek *DATA , 0 , 0 ;'
          },
          {
            'token_num' => 13,
            'block_id' => 2,
            'end_line' => 77,
            'has_warnings' => 1,
            'start_line' => 77,
            'src' => ' while ( < DATA > ) { last if/^__DATA__/ }',
            'indent' => 1
          },
          {
            'end_line' => 82,
            'has_warnings' => 1,
            'block_id' => 2,
            'token_num' => 28,
            'indent' => 1,
            'src' => ' while ( < DATA > ) { chomp ; next if/^#/ ; like ( $_ , qr/^$email$/ , $_ ) ; }',
            'start_line' => 78
          },
          {
            'src' => ' chomp ;',
            'indent' => 2,
            'start_line' => 79,
            'end_line' => 79,
            'has_warnings' => 0,
            'block_id' => 4,
            'token_num' => 2
          },
          {
            'token_num' => 6,
            'block_id' => 4,
            'has_warnings' => 0,
            'end_line' => 80,
            'src' => ' next if/^#/ ;',
            'indent' => 2,
            'start_line' => 80
          },
          {
            'start_line' => 81,
            'src' => ' like ( $_ , qr/^$email$/ , $_ ) ;',
            'indent' => 2,
            'has_warnings' => 1,
            'end_line' => 81,
            'token_num' => 12,
            'block_id' => 4
          },
          {
            'start_line' => 84,
            'indent' => 1,
            'src' => ' done_testing ( ) ;',
            'end_line' => 84,
            'has_warnings' => 1,
            'token_num' => 4,
            'block_id' => 2
          },
          {
            'token_num' => 2,
            'block_id' => 0,
            'end_line' => 87,
            'has_warnings' => 0,
            'start_line' => 87,
            'src' => ' 1 ;',
            'indent' => 0
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
          }
        ]
, 'Compiler::Lexer::get_used_modules');
};

done_testing;
