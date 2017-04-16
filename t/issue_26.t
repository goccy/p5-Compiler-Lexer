use strict;
use warnings;
use Compiler::Lexer;
use Test::More;
use Data::Dumper;
my $tokens = Compiler::Lexer->new->tokenize('my @chars = split //, $what;');
print Dumper($tokens);
is_deeply($tokens, [
    bless( {
             'has_warnings' => 0,
             'line' => 1,
             'type' => 62,
             'stype' => 0,
             'data' => 'my',
             'kind' => 3,
             'name' => 'VarDecl'
           }, 'Compiler::Lexer::Token' ),
    bless( {
             'kind' => 24,
             'data' => '@chars',
             'name' => 'LocalArrayVar',
             'stype' => 0,
             'type' => 192,
             'line' => 1,
             'has_warnings' => 0
           }, 'Compiler::Lexer::Token' ),
    bless( {
             'has_warnings' => 0,
             'type' => 65,
             'line' => 1,
             'data' => '=',
             'kind' => 2,
             'name' => 'Assign',
             'stype' => 0
           }, 'Compiler::Lexer::Token' ),
    bless( {
             'has_warnings' => 0,
             'line' => 1,
             'type' => 70,
             'stype' => 0,
             'data' => 'split',
             'name' => 'BuiltinFunc',
             'kind' => 4
           }, 'Compiler::Lexer::Token' ),
    bless( {
             'line' => 1,
             'type' => 187,
             'has_warnings' => 0,
             'stype' => 0,
             'name' => 'RegExp',
             'data' => '//',
             'kind' => 24
           }, 'Compiler::Lexer::Token' ),
    bless( {
             'has_warnings' => 0,
             'line' => 1,
             'type' => 104,
             'stype' => 0,
             'name' => 'Comma',
             'data' => ',',
             'kind' => 19
           }, 'Compiler::Lexer::Token' ),
    bless( {
             'line' => 1,
             'type' => 194,
             'has_warnings' => 0,
             'stype' => 0,
             'data' => '$what',
             'name' => 'GlobalVar',
             'kind' => 24
           }, 'Compiler::Lexer::Token' ),
    bless( {
             'line' => 1,
             'type' => 106,
             'has_warnings' => 0,
             'stype' => 0,
             'name' => 'SemiColon',
             'data' => ';',
             'kind' => 21
           }, 'Compiler::Lexer::Token'
    )
]);

done_testing;
