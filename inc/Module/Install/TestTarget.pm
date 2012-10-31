#line 1
package Module::Install::TestTarget;
use 5.006_002;
use strict;
#use warnings; # XXX: warnings.pm produces a lot of 'redefine' warnings!
our $VERSION = '0.15';

use base qw(Module::Install::Base);
use Config;
use Carp qw(croak);

our($ORIG_TEST_VIA_HARNESS);

our $TEST_DYNAMIC = {
    env                => '',
    includes           => '',
    load_modules       => '',
    insert_on_prepare  => '',
    insert_on_finalize => '',
    run_on_prepare     => '',
    run_on_finalize    => '',
};

# override the default `make test`
sub default_test_target {
    my ($self, %args) = @_;
    my %test = _build_command_parts(%args);
    $TEST_DYNAMIC = \%test;
}

# create a new test target
sub test_target {
    my ($self, $target, %args) = @_;
    croak 'target must be spesiced at test_target()' unless $target;
    my $alias = "\n";

    if($args{alias}) {
        $alias .= qq{$args{alias} :: $target\n\n};
    }
    if($Module::Install::AUTHOR && $args{alias_for_author}) {
        $alias .= qq{$args{alias_for_author} :: $target\n\n};
    }

    my $test = _assemble(_build_command_parts(%args));

    $self->postamble(
          $alias
        . qq{$target :: pure_all\n}
        . qq{\t} . $test
    );
}

sub _build_command_parts {
    my %args = @_;

    #XXX: _build_command_parts() will be called first, so we put it here
    unless(defined $ORIG_TEST_VIA_HARNESS) {
        $ORIG_TEST_VIA_HARNESS = MY->can('test_via_harness');
        no warnings 'redefine';
        *MY::test_via_harness = \&_test_via_harness;
    }

    for my $key (qw/includes load_modules run_on_prepare run_on_finalize insert_on_prepare insert_on_finalize tests/) {
        $args{$key} ||= [];
        $args{$key} = [$args{$key}] unless ref $args{$key} eq 'ARRAY';
    }
    $args{env} ||= {};

    my %test;
    $test{includes} = @{$args{includes}} ? join '', map { qq|"-I$_" | } @{$args{includes}} : '';
    $test{load_modules}  = @{$args{load_modules}}  ? join '', map { qq|"-M$_" | } @{$args{load_modules}}  : '';

    $test{tests} =  @{$args{tests}}
        ? join '', map { qq|"$_" | } @{$args{tests}}
        : '$(TEST_FILES)';

    for my $key (qw/run_on_prepare run_on_finalize/) {
        $test{$key} = @{$args{$key}} ? join '', map { qq|do { local \$@; do '$_'; die \$@ if \$@ }; | } @{$args{$key}} : '';
        $test{$key} = _quote($test{$key});
    }
    for my $key (qw/insert_on_prepare insert_on_finalize/) {
        my $codes = join '', map { _build_funcall($_) } @{$args{$key}};
        $test{$key} = _quote($codes);
    }
    $test{env} = %{$args{env}} ? _quote(join '', map {
        my $key = _env_quote($_);
        my $val = _env_quote($args{env}->{$_});
        sprintf "\$ENV{q{%s}} = q{%s}; ", $key, $val
    } keys %{$args{env}}) : '';

    return %test;
}

my $bd;
sub _build_funcall {
    my($code) = @_;
    if(ref $code eq 'CODE') {
        $bd ||= do { require B::Deparse; B::Deparse->new() };
        $code = $bd->coderef2text($code);
    }
    return qq|sub { $code }->(); |;
}

sub _quote {
    my $code = shift;
    $code =~ s/\$/\\\$\$/g;
    $code =~ s/"/\\"/g;
    $code =~ s/\n/ /g;
    if ($^O eq 'MSWin32') {
        $code =~ s/\\\$\$/\$\$/g;
        if ($Config{make} eq 'dmake') {
            $code =~ s/{/{{/g;
            $code =~ s/}/}}/g;
        }
    }
    return $code;
}

sub _env_quote {
    my $val = shift;
    $val =~ s/}/\\}/g;
    return $val;
}

sub _assemble {
    my %args = @_;
    my $command = MY->$ORIG_TEST_VIA_HARNESS($args{perl} || '$(FULLPERLRUN)', $args{tests});

    # inject includes and modules before the first switch
    $command =~ s/("- \S+? ")/$args{includes}$args{load_modules}$1/xms;

    # inject snipetts in the one-liner
    $command =~ s{
        ( "-e" \s+ ")          # start the one liner
        ( (?: [^"] | \\ . )+ ) # body of the one liner
        ( " )                  # end the one liner
     }{
        join '', $1,
            $args{env},
            $args{run_on_prepare},
            $args{insert_on_prepare},
            "$2; ",
            $args{run_on_finalize},
            $args{insert_on_finalize},
            $3,
    }xmse;
    return $command;
}

sub _test_via_harness {
    my($self, $perl, $tests) = @_;

    $TEST_DYNAMIC->{perl} = $perl;
    $TEST_DYNAMIC->{tests} ||= $tests;
    return _assemble(%$TEST_DYNAMIC);
}

1;
__END__

#line 393
