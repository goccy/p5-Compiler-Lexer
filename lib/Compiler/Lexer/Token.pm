package Compiler::Lexer::Token;
use strict;
use warnings;

my $FIELDS = [qw/
    stype
    type
    kind
    line
    name
    data
    has_warnings
/];

{
    no strict 'refs';
    foreach my $field (@$FIELDS) {
        *{__PACKAGE__ . '::' . $field} = sub {
            my ($self, $value) = @_;
            return $self->{$field} unless defined $value;
            $self->{$field} = $value;
        };
    }
}

1;
__END__

=encoding utf-8

=for stopwords stype

=head1 NAME

Compiler::Lexer::Token

=head1 SYNOPSIS

Compiler::Lexer::Token includes the following members.

=over

=item stype

constant of Compiler::Lexer::SyntaxType

=item type

constant of Compiler::Lexer::TokenType

=item kind

constant of Compiler::Lexer::Kind

=item name

name of Compiler::Lexer::TokenType

=item data

raw data

=item has_warnings

flag of whether unknown keyword or not

=back

=head1 METHODS

support simple get/set accessors like Class::Accessor::Fast

example:

  my $type = $token->type;                            # get accessor
  $token->type(Compiler::Lexer::TokenType::T_RegExp); # set accessor

=head1 AUTHOR

Masaaki Goshima (goccy) E<lt>goccy(at)cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2013, Masaaki Goshima (goccy). All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
