# NAME

Compiler::Lexer - Lexical Analyzer for Perl5

# SYNOPSIS

    use Compiler::Lexer;
    use Data::Dumper;

    my $filename = $ARGV[0];
    open(my $fh, "<", $filename) or die("$filename could not find.");
    my $script = do { local $/; <$fh> };
    my $lexer = Compiler::Lexer->new($filename);
    my $tokens = $lexer->tokenize($script);
    print Dumper $tokens;
    print Dumper $lexer->get_used_modules($script);

# DESCRIPTION

Compiler::Lexer is lexical analyzer for perl5.

# METHODS

- my $lexer = Compiler::Lexer->new($filename);

    Create new instance. You can create object from `$filename` in string.

- $lexer->tokenize($script);

    Get token objects includes parameter of 'name' or 'type' or 'line' and so on.
    This method requires perl source code in string.

- $lexer->get_used_modules($script);

    Get names of used module. This method requires perl source code in string.

# LICENSE

Copyright (C) Masaaki Goshima (goccy).

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Masaaki Goshima (goccy) <goccy@cpan.org>

# SEE ALSO

[Compiler::Parser](http://search.cpan.org/perldoc?Compiler::Parser)
