use strict;
use warnings;
use Compiler::Lexer;
use Test::More;
use Data::Dumper;

my $lexer  = Compiler::Lexer->new({ verbose => 1 });
my $tokens = $lexer->tokenize(<<'SCRIPT');
# comment line
my $var;
=pod

=head1

=head2

=cut
my  $foo = <<"        --";
            print "Hello";
            print "Goodbye";
        --
SCRIPT
subtest 'tokenize' => sub {
    is_deeply($tokens, [
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Verbose,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'Comment',
            'data' => '# comment line',
            'type' => Compiler::Lexer::TokenType::T_Comment,
            'line' => 1
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Verbose,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'WhiteSpace',
            'data' => '
',
            'type' => Compiler::Lexer::TokenType::T_WhiteSpace,
            'line' => 1
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Decl,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'VarDecl',
            'data' => 'my',
            'type' => Compiler::Lexer::TokenType::T_VarDecl,
            'line' => 2
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Verbose,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'WhiteSpace',
            'data' => ' ',
            'type' => Compiler::Lexer::TokenType::T_WhiteSpace,
            'line' => 2
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Term,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'LocalVar',
            'data' => '$var',
            'type' => Compiler::Lexer::TokenType::T_LocalVar,
            'line' => 2
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_StmtEnd,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'SemiColon',
            'data' => ';',
            'type' => Compiler::Lexer::TokenType::T_SemiColon,
            'line' => 2
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Verbose,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'WhiteSpace',
            'data' => '
',
            'type' => Compiler::Lexer::TokenType::T_WhiteSpace,
            'line' => 2
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Verbose,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'Pod',
            'data' => '=pod

=head1

=head2

',
            'type' => Compiler::Lexer::TokenType::T_Pod,
            'line' => 9
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Verbose,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'WhiteSpace',
            'data' => '
',
            'type' => Compiler::Lexer::TokenType::T_WhiteSpace,
            'line' => 9
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Decl,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'VarDecl',
            'data' => 'my',
            'type' => Compiler::Lexer::TokenType::T_VarDecl,
            'line' => 10
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Verbose,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'WhiteSpace',
            'data' => '  ',
            'type' => Compiler::Lexer::TokenType::T_WhiteSpace,
            'line' => 10
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Term,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'LocalVar',
            'data' => '$foo',
            'type' => Compiler::Lexer::TokenType::T_LocalVar,
            'line' => 10
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Verbose,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'WhiteSpace',
            'data' => ' ',
            'type' => Compiler::Lexer::TokenType::T_WhiteSpace,
            'line' => 10
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Assign,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'Assign',
            'data' => '=',
            'type' => Compiler::Lexer::TokenType::T_Assign,
            'line' => 10
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Verbose,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'WhiteSpace',
            'data' => ' ',
            'type' => Compiler::Lexer::TokenType::T_WhiteSpace,
            'line' => 10
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Operator,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'LeftShift',
            'data' => '<<',
            'type' => Compiler::Lexer::TokenType::T_LeftShift,
            'line' => 10
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Term,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'HereDocumentTag',
            'data' => '        --',
            'type' => Compiler::Lexer::TokenType::T_HereDocumentTag,
            'line' => 10
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_StmtEnd,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'SemiColon',
            'data' => ';',
            'type' => Compiler::Lexer::TokenType::T_SemiColon,
            'line' => 10
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Verbose,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'WhiteSpace',
            'data' => '
',
            'type' => Compiler::Lexer::TokenType::T_WhiteSpace,
            'line' => 10
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Term,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'HereDocument',
            'data' => '            print "Hello";
            print "Goodbye";
',
            'type' => Compiler::Lexer::TokenType::T_HereDocument,
            'line' => 13
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Term,
            'has_warnings' => 0,
            'stype' => Compiler::Lexer::SyntaxType::T_Value,
            'name' => 'HereDocumentEnd',
            'data' => '        --',
            'type' => Compiler::Lexer::TokenType::T_HereDocumentEnd,
            'line' => 13
        }, 'Compiler::Lexer::Token' ),
        bless( {
            'kind' => Compiler::Lexer::Kind::T_Verbose,
            'has_warnings' => 0,
            'stype' => 0,
            'name' => 'WhiteSpace',
            'data' => '
',
            'type' => Compiler::Lexer::TokenType::T_WhiteSpace,
            'line' => 13
        }, 'Compiler::Lexer::Token' ),
    ]);
};

done_testing;
