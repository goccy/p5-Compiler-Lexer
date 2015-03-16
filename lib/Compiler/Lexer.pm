package Compiler::Lexer;
use strict;
use warnings;
use 5.008_001;
use File::Find;
use Compiler::Lexer::Token;
use Compiler::Lexer::Constants;

require Exporter;
our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = '0.22';
require XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

my $inc;

sub new {
    my ($class, $args) = @_;
    my $options = +{};
    if (ref $args eq 'HASH') {
        $options = $args;
    } elsif (ref $args eq 'SCALAR') {
        $options->{filename} = $args;
    }
    $options->{filename} ||= '-';
    $options->{verbose}  ||= 0;
    return $class->_new($options);
}

sub set_library_path {
    my ($self, $_inc) = @_;
    $inc = $_inc;
}

sub load_module {
    my ($self, $name) = @_;
    $name =~ s|::|/|g;
    my @include_path = ($inc) ? @$inc : @INC;
    my $module_path = '';
    foreach my $path (@include_path) {
        next unless -e $path;
        find(sub {
            return if ($module_path);
            my $absolute_path = $File::Find::name;
            if ($absolute_path =~ "$name.pm") {
                $module_path = $absolute_path;
            }
        }, $path);
        last if ($module_path);
    }
    return undef unless $module_path;
    open my $fh, '<', $module_path;
    return do { local $/; <$fh> };
}

sub recursive_tokenize {
    my ($self, $script) = @_;
    my %results;
    $self->__recursive_tokenize(\%results, $script);
    $results{main} = $self->tokenize($script);
    return \%results;
}

sub __recursive_tokenize {
    my ($self, $results, $script) = @_;
    my $modules = $self->get_used_modules($script);
    foreach my $module (@$modules) {
        my $name = $module->{name};
        next if (defined $results->{$name});
        $results->{$name} ||= [];
        my $code = $self->load_module($name);
        next unless ($code);
        $results->{$name} = $self->tokenize($code);
        $self->__recursive_tokenize($results, $code);
    }
}

1;
__END__

=encoding utf-8

=head1 NAME

Compiler::Lexer - Lexical Analyzer for Perl5

=head1 SYNOPSIS

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

=head1 METHODS

=over 4

=item my $lexer = Compiler::Lexer->new($options);

create new instance.
You can create object from $options in hash reference.

B<options list>

=over 4

=item filename

=item verbose : includes token of Pod, Comment and WhiteSpace

=back

=item $lexer->tokenize($script);

get token objects includes parameter of 'name' or 'type' or 'line' and so on.
This method requires perl source code in string.

=item $lexer->set_library_path(['path1', 'path2' ...])

set libraries path for reading recursively. Default paths are @INC.

=item $lexer->recursive_tokenize($script)

get hash reference like { 'module_nameA' => [], 'module_nameB' => [] ... }.
This method requires per source code in string.

=item $lexer->get_used_modules($script);

get names of used module.
This method requires perl source code in string.

=back

=head1 AUTHOR

Masaaki Goshima (goccy) E<lt>goccy(at)cpan.orgE<gt>

=head1 CONTRIBUTORS

tokuhirom: Tokuhiro Matsuno

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2013, Masaaki Goshima (goccy). All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
