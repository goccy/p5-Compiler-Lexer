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
                   'kind' => Compiler::Lexer::Kind::T_ModWord,
                   'data' => 'BEGIN',
                   'type' => Compiler::Lexer::TokenType::T_ModWord,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 6,
                   'name' => 'ModWord'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'line' => 6,
                   'name' => 'LeftBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'line' => 7,
                   'data' => 'chdir',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 't',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RawString',
                   'line' => 7
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'IfStmt',
                   'line' => 7,
                   'data' => 'if',
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '-d',
                   'kind' => Compiler::Lexer::Kind::T_Handle,
                   'type' => Compiler::Lexer::TokenType::T_Handle,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Handle',
                   'line' => 7
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 't',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RawString',
                   'line' => 7
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 7,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '@INC',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_LibraryDirectories,
                   'line' => 8,
                   'name' => 'LibraryDirectories'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 8,
                   'name' => 'Assign',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=',
                   'type' => Compiler::Lexer::TokenType::T_Assign,
                   'kind' => Compiler::Lexer::Kind::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'line' => 8,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '../lib',
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 8,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'require',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'type' => Compiler::Lexer::TokenType::T_RequireDecl,
                   'name' => 'RequireDecl',
                   'line' => 9
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 9,
                   'name' => 'RawString',
                   'data' => './test.pl',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'line' => 9
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'data' => '}',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightBrace',
                   'line' => 10
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_UseDecl,
                   'data' => 'use',
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 12,
                   'name' => 'UseDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_UsedName,
                   'data' => 'strict',
                   'kind' => Compiler::Lexer::Kind::T_Module,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'UsedName',
                   'line' => 12
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'line' => 12
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'line' => 13,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'no',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'warnings',
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'line' => 13
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RawString',
                   'line' => 13,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'experimental::regex_sets',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RawString
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'line' => 13,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'data' => 'my',
                   'type' => Compiler::Lexer::TokenType::T_VarDecl,
                   'line' => 15,
                   'name' => 'VarDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '$email',
                   'type' => Compiler::Lexer::TokenType::T_LocalVar,
                   'line' => 15,
                   'name' => 'LocalVar'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Assign',
                   'line' => 15,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '=',
                   'kind' => Compiler::Lexer::Kind::T_Assign,
                   'type' => Compiler::Lexer::TokenType::T_Assign
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'RegDecl',
                   'line' => 15,
                   'data' => 'qr',
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'type' => Compiler::Lexer::TokenType::T_RegDecl,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'name' => 'RegDelim',
                   'line' => 15
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 69,
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
',
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 69,
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'data' => '}',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'x',
                   'kind' => Compiler::Lexer::Kind::T_RegOpt,
                   'type' => Compiler::Lexer::TokenType::T_RegOpt,
                   'line' => 69,
                   'name' => 'RegOpt'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 69,
                   'name' => 'SemiColon'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'run_tests',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 1,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 71,
                   'name' => 'Key'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'line' => 71,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RightParenthesis',
                   'line' => 71
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'UnlessStmt',
                   'line' => 71,
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'data' => 'unless',
                   'type' => Compiler::Lexer::TokenType::T_UnlessStmt,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'line' => 71,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => 'caller',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'line' => 71,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'sub',
                   'type' => Compiler::Lexer::TokenType::T_FunctionDecl,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 73,
                   'name' => 'FunctionDecl'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'run_tests',
                   'type' => Compiler::Lexer::TokenType::T_Function,
                   'kind' => Compiler::Lexer::Kind::T_Decl,
                   'line' => 73,
                   'name' => 'Function'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 73,
                   'name' => 'LeftBrace',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '{',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'data' => 'seek',
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc,
                   'name' => 'BuiltinFunc',
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '*DATA',
                   'type' => Compiler::Lexer::TokenType::T_Mul,
                   'kind' => Compiler::Lexer::Kind::T_Operator,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'Mul',
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ',',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'Comma',
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'line' => 76,
                   'data' => '0',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'name' => 'Comma',
                   'line' => 76
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'line' => 76,
                   'data' => '0',
                   'type' => Compiler::Lexer::TokenType::T_Int,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'line' => 76,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'while',
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'type' => Compiler::Lexer::TokenType::T_WhileStmt,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 77,
                   'name' => 'WhileStmt'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'line' => 77,
                   'name' => 'LeftParenthesis'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '<',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_HandleDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 77,
                   'name' => 'HandleDelim'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Key',
                   'line' => 77,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'data' => 'DATA',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 1,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 77,
                   'name' => 'HandleDelim',
                   'data' => '>',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_HandleDelim,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 77,
                   'name' => 'RightParenthesis',
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftBrace',
                   'line' => 77,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '{',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'last',
                   'type' => Compiler::Lexer::TokenType::T_Last,
                   'kind' => Compiler::Lexer::Kind::T_Control,
                   'line' => 77,
                   'name' => 'Last'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'if',
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 77,
                   'name' => 'IfStmt'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'data' => '/',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 77,
                   'name' => 'RegDelim'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '^__DATA__',
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 77,
                   'name' => 'RegExp'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'data' => '/',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'name' => 'RegDelim',
                   'line' => 77
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '}',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'name' => 'RightBrace',
                   'line' => 77
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => 'while',
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'type' => Compiler::Lexer::TokenType::T_WhileStmt,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'WhileStmt',
                   'line' => 78
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 78,
                   'name' => 'LeftParenthesis',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '(',
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'kind' => Compiler::Lexer::Kind::T_Symbol
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '<',
                   'type' => Compiler::Lexer::TokenType::T_HandleDelim,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'HandleDelim',
                   'line' => 78
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 78,
                   'name' => 'Key',
                   'has_warnings' => 1,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => 'DATA',
                   'type' => Compiler::Lexer::TokenType::T_Key
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'HandleDelim',
                   'line' => 78,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '>',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_HandleDelim
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 78,
                   'name' => 'RightParenthesis',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 78,
                   'name' => 'LeftBrace',
                   'data' => '{',
                   'type' => Compiler::Lexer::TokenType::T_LeftBrace,
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'BuiltinFunc',
                   'line' => 79,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => 'chomp',
                   'kind' => Compiler::Lexer::Kind::T_Function,
                   'type' => Compiler::Lexer::TokenType::T_BuiltinFunc
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'name' => 'SemiColon',
                   'line' => 79
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Next',
                   'line' => 80,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_Control,
                   'data' => 'next',
                   'type' => Compiler::Lexer::TokenType::T_Next
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'type' => Compiler::Lexer::TokenType::T_IfStmt,
                   'data' => 'if',
                   'kind' => Compiler::Lexer::Kind::T_Stmt,
                   'line' => 80,
                   'name' => 'IfStmt'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '/',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'RegDelim',
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 80,
                   'name' => 'RegExp',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => '^#',
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'kind' => Compiler::Lexer::Kind::T_Term
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'data' => '/',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'RegDelim',
                   'line' => 80
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SemiColon',
                   'line' => 80,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 1,
                   'data' => 'like',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'name' => 'Key',
                   'line' => 81
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'LeftParenthesis',
                   'line' => 81,
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'SpecificValue',
                   'line' => 81,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '$_',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'line' => 81,
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'data' => ',',
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'type' => Compiler::Lexer::TokenType::T_RegDecl,
                   'data' => 'qr',
                   'kind' => Compiler::Lexer::Kind::T_RegPrefix,
                   'name' => 'RegDecl',
                   'line' => 81
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 81,
                   'name' => 'RegDelim',
                   'type' => Compiler::Lexer::TokenType::T_RegDelim,
                   'data' => '/',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 81,
                   'name' => 'RegExp',
                   'data' => '^$email$',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegExp,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 81,
                   'name' => 'RegDelim',
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '/',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_RegDelim
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Comma',
                   'line' => 81,
                   'kind' => Compiler::Lexer::Kind::T_Comma,
                   'data' => ',',
                   'type' => Compiler::Lexer::TokenType::T_Comma,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '$_',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_SpecificValue,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'line' => 81,
                   'name' => 'SpecificValue'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 81,
                   'name' => 'RightParenthesis',
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 81,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'data' => '}',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'line' => 82,
                   'name' => 'RightBrace'
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 84,
                   'name' => 'Key',
                   'data' => 'done_testing',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Key,
                   'has_warnings' => 1,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => '(',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_LeftParenthesis,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'name' => 'LeftParenthesis',
                   'line' => 84
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 84,
                   'name' => 'RightParenthesis',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ')',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'type' => Compiler::Lexer::TokenType::T_RightParenthesis
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'data' => ';',
                   'type' => Compiler::Lexer::TokenType::T_SemiColon,
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'name' => 'SemiColon',
                   'line' => 84
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 85,
                   'name' => 'RightBrace',
                   'type' => Compiler::Lexer::TokenType::T_RightBrace,
                   'data' => '}',
                   'kind' => Compiler::Lexer::Kind::T_Symbol,
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'name' => 'Int',
                   'line' => 87,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'has_warnings' => 0,
                   'data' => '1',
                   'kind' => Compiler::Lexer::Kind::T_Term,
                   'type' => Compiler::Lexer::TokenType::T_Int
                 }, 'Compiler::Lexer::Token' ),
          bless( {
                   'line' => 87,
                   'name' => 'SemiColon',
                   'has_warnings' => 0,
                   'stype' => Compiler::Lexer::SyntaxType::T_Value,
                   'data' => ';',
                   'kind' => Compiler::Lexer::Kind::T_StmtEnd,
                   'type' => Compiler::Lexer::TokenType::T_SemiColon
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
            'src' => ' chdir \'t\' if -d \'t\' ;',
            'token_num' => 6,
            'block_id' => 1,
            'start_line' => 7,
            'indent' => 1,
            'has_warnings' => 0,
            'end_line' => 7
          },
          {
            'block_id' => 1,
            'start_line' => 8,
            'indent' => 1,
            'token_num' => 4,
            'src' => ' @INC = \'../lib\' ;',
            'end_line' => 8,
            'has_warnings' => 0
          },
          {
            'has_warnings' => 0,
            'end_line' => 9,
            'token_num' => 3,
            'src' => ' require \'./test.pl\' ;',
            'start_line' => 9,
            'block_id' => 1,
            'indent' => 1
          },
          {
            'block_id' => 0,
            'start_line' => 12,
            'indent' => 0,
            'token_num' => 3,
            'src' => ' use strict ;',
            'end_line' => 12,
            'has_warnings' => 0
          },
          {
            'end_line' => 13,
            'has_warnings' => 1,
            'start_line' => 13,
            'indent' => 0,
            'block_id' => 0,
            'token_num' => 4,
            'src' => ' no warnings \'experimental::regex_sets\' ;'
          },
          {
            'end_line' => 69,
            'has_warnings' => 0,
            'indent' => 0,
            'start_line' => 15,
            'block_id' => 0,
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
            'token_num' => 9
          },
          {
            'has_warnings' => 1,
            'end_line' => 71,
            'src' => ' run_tests ( ) unless caller ;',
            'token_num' => 6,
            'start_line' => 71,
            'indent' => 0,
            'block_id' => 0
          },
          {
            'src' => ' sub run_tests { seek *DATA , 0 , 0 ; while ( < DATA > ) { last if/^__DATA__/ } while ( < DATA > ) { chomp ; next if/^#/ ; like ( $_ , qr/^$email$/ , $_ ) ; } done_testing ( ) ; }',
            'token_num' => 56,
            'start_line' => 73,
            'block_id' => 0,
            'indent' => 0,
            'has_warnings' => 1,
            'end_line' => 85
          },
          {
            'block_id' => 2,
            'start_line' => 76,
            'indent' => 1,
            'token_num' => 7,
            'src' => ' seek *DATA , 0 , 0 ;',
            'end_line' => 76,
            'has_warnings' => 0
          },
          {
            'block_id' => 2,
            'start_line' => 77,
            'indent' => 1,
            'token_num' => 13,
            'src' => ' while ( < DATA > ) { last if/^__DATA__/ }',
            'end_line' => 77,
            'has_warnings' => 1
          },
          {
            'end_line' => 82,
            'has_warnings' => 1,
            'start_line' => 78,
            'block_id' => 2,
            'indent' => 1,
            'src' => ' while ( < DATA > ) { chomp ; next if/^#/ ; like ( $_ , qr/^$email$/ , $_ ) ; }',
            'token_num' => 28
          },
          {
            'end_line' => 79,
            'has_warnings' => 0,
            'start_line' => 79,
            'indent' => 2,
            'block_id' => 4,
            'token_num' => 2,
            'src' => ' chomp ;'
          },
          {
            'has_warnings' => 0,
            'end_line' => 80,
            'src' => ' next if/^#/ ;',
            'token_num' => 6,
            'start_line' => 80,
            'block_id' => 4,
            'indent' => 2
          },
          {
            'has_warnings' => 1,
            'end_line' => 81,
            'src' => ' like ( $_ , qr/^$email$/ , $_ ) ;',
            'token_num' => 12,
            'block_id' => 4,
            'start_line' => 81,
            'indent' => 2
          },
          {
            'has_warnings' => 1,
            'end_line' => 84,
            'src' => ' done_testing ( ) ;',
            'token_num' => 4,
            'start_line' => 84,
            'block_id' => 2,
            'indent' => 1
          },
          {
            'has_warnings' => 0,
            'end_line' => 87,
            'token_num' => 2,
            'src' => ' 1 ;',
            'start_line' => 87,
            'block_id' => 0,
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
