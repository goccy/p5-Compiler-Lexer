# NAME

Compiler::Lexer - Lexical Analyzer for Perl5

# SYNOPSIS

    use Compiler::Lexer;
    use Data::Dumper;

    my $filename = $ARGV[0];
    open my $fh, '<', $filename;
    my $script = do { local $/; <$fh> };

    my $lexer = Compiler::Lexer->new($filename);
    my $tokens = $lexer->tokenize($script);
    print Dumper $tokens;

    my $modules = $lexer->get_used_modules($script);
    print Dumper $modules;

# METHODS

Compiler::Lexer provides three methods

- my $lexer = Compiler::Lexer->new($filename);

    create new instance.
    You can create object from \`$filename\` in string.

- $lexer->tokenize($script);

    get token objects includes parameter of 'name' or 'type' or 'line' and so on.
    This method requires perl source code in string.

- $lexer->get\_used\_modules($script);

    get names of used module.
    This method requires perl source code in string.

# AUTHOR

Masaaki Goshima (goccy) <goccy(at)cpan.org>

# CONTRIBUTORS

tokuhirom: Tokuhiro Matsuno

# LICENSE AND COPYRIGHT

Copyright (c) 2013, Masaaki Goshima (goccy). All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
