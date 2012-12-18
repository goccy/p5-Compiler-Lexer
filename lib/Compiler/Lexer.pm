package Compiler::Lexer;

use 5.012004;
use strict;
use warnings;
use Compiler::Lexer::Constants;
### =================== Exporter ======================== ###
require Exporter;
our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = '0.01';
require XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

### ================ Public Methods ===================== ###

1;
__END__

=head1 NAME

Compiler::Lexer - Lexical Analyzer for Perl5

=head1 VERSION

This document describes Compiler::Lexer version 1.0000.

=head1 SYNOPSIS

use Compiler::Lexer;
use Data::Dumper;

sub get_script {

    my ($filename) = @_;
    my $script = "";
    open(FP, "<", $filename) or die("Error");
    $script .= $_ foreach (<FP>);
    close(FP);
    return $script;

}

my $filename = $ARGV[0];

print Dumper Lexer::deparse($filename, get_script($filename));

print Dumper Lexer::get_stmt_codes($filename, get_script($filename));

print Dumper Lexer::get_used_modules($filename, get_script($filename));


=head1 AUTHOR

Masaaki, Goshima (goccy) E<lt>goccy54(at)cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2012, Masaaki, Goshima (goccy). All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
