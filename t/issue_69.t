use strict;
use warnings;
use Compiler::Lexer;
use Test::More;

my $tokens = Compiler::Lexer->new->recursive_tokenize('{}');
is_deeply($tokens,
          {
            'main' => [
                        bless( {
                                 'kind' => 22,
                                 'has_warnings' => 0,
                                 'stype' => 0,
                                 'name' => 'LeftBrace',
                                 'data' => '{',
                                 'type' => 109,
                                 'line' => 1
                               }, 'Compiler::Lexer::Token' ),
                        bless( {
                                 'kind' => 22,
                                 'has_warnings' => 0,
                                 'stype' => 0,
                                 'name' => 'RightBrace',
                                 'data' => '}',
                                 'type' => 110,
                                 'line' => 1
                               }, 'Compiler::Lexer::Token' )
                      ]
          });

done_testing;
