use strict;
use warnings;
use inc::Module::Install;
use Module::Install::XSUtil; # for co-developpers
use constant DEBUG => 0;

use_ppport 3.19;
#name 'Compiler::Lexer';
#author 'Masaaki Goshima <goccy54@gmail.com>';
all_from 'lib/Compiler/Lexer.pm';
requires_cplusplus;
cc_warnings;
cc_src_paths qw(src);
cc_include_paths qw(include);
cc_define qw();
makemaker_args->{CC} = 'g++';
makemaker_args->{LD} = 'g++';
my @ignore_warnings_options = qw(missing-field-initializers unused-variable);
makemaker_args->{CCFLAGS} .= join('', map { ' -Wno-' . $_ } @ignore_warnings_options);
if (DEBUG) {
    makemaker_args->{OPTIMIZE} = '-O0';
    makemaker_args->{CCFLAGS} = '-g3 ' . makemaker_args->{CCFLAGS};
}

#test_requires 'Test::More';

WriteAll(check_nmake => 0);
