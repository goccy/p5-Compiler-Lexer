requires 'XSLoader', '0.02';
requires 'perl', '5.008001';

on 'configure' => sub {
    requires 'Module::Build::XSUtil' => '>=0.02';
};

on 'build' => sub {
    requires 'Devel::PPPort', '3.19';
    requires 'ExtUtils::MakeMaker', '6.59';
    requires 'ExtUtils::ParseXS', '2.21';
    requires 'Test::More';
};

on 'test' => sub {
    requires 'Test::More';
};
