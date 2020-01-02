package builder::MyBuilder;
use strict;
use warnings FATAL => 'all';
use 5.008005;
use base 'Module::Build::XSUtil';
use constant DEBUG => 0;

sub new {
    my ( $class, %args ) = @_;
    my @ignore_warnings_options = map { "-Wno-$_" } qw(missing-field-initializers);
    my $self = $class->SUPER::new(
        %args,
        generate_ppport_h    => 'include/ppport.h',
        needs_compiler_cpp   => 1,
        c_source => [qw/src/],
        xs_files => { 'src/Compiler-Lexer.xs' => 'lib/Compiler/Lexer.xs' },
        cc_warnings => 0, # TODO
        extra_compiler_flags => ['-std=c++14', '-Iinclude', @ignore_warnings_options, '-g3'],
        add_to_cleanup => [
            'lib/Compiler/Lexer/*.o', 'lib/Compiler/Lexer/*.c',
            'lib/Compiler/Lexer/*.xs',
        ],
    );
    $self->{config}->set('optimize' => '-O0') if (DEBUG);
    return $self;
}

1;
