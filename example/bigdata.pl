#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use Compiler::Lexer;

my $filename = 'example/lib/BigData.pm';
open my $fh, '<', $filename;
my $script = do { local $/; <$fh> };
Compiler::Lexer->new('-')->tokenize($script);
