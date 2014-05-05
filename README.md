[![Build Status](https://travis-ci.org/goccy/p5-Compiler-Lexer.png?branch=master)](https://travis-ci.org/goccy/p5-Compiler-Lexer) [![Coverage Status](https://coveralls.io/repos/goccy/p5-Compiler-Lexer/badge.png?branch=master)](https://coveralls.io/r/goccy/p5-Compiler-Lexer?branch=master)

# NAME

Compiler::Lexer - Lexical Analyzer for Perl5

# SYNOPSIS

    use Compiler::Lexer;
    use Data::Dumper;

    my $filename = $ARGV[0];
    open my $fh, '<', $filename or die "Cannot open $filename: $!";
    my $script = do { local $/; <$fh> };

    my $lexer = Compiler::Lexer->new($filename);
    my $tokens = $lexer->tokenize($script);
    print Dumper $tokens;

    my $modules = $lexer->get_used_modules($script);
    print Dumper $modules;

# METHODS

- my $lexer = Compiler::Lexer->new($options);

    create new instance.
    You can create object from $options in hash reference.

    __options list__

    - filename
    - verbose : includes token of Pod, Comment and WhiteSpace

- $lexer->tokenize($script);

    get token objects includes parameter of 'name' or 'type' or 'line' and so on.
    This method requires perl source code in string.

- $lexer->set\_library\_path(\['path1', 'path2' ...\])

    set libraries path for reading recursively. Default paths are @INC.

- $lexer->recursive\_tokenize($script)

    get hash reference like { 'module\_nameA' => \[\], 'module\_nameB' => \[\] ... }.
    This method requires per source code in string.

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
