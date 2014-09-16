requires 'EV', '4.11';
requires 'XSLoader', '0.02';

on configure => sub {
    requires 'EV::MakeMaker';
    requires 'ExtUtils::ParseXS', '2.21';
    requires 'Module::Build::XSUtil' => '>=0.02';
    requires 'File::Which';
};

on build => sub {
    requires 'Devel::Refcount';
    requires 'ExtUtils::CBuilder';
    requires 'Pod::Markdown';
    requires 'Test::Deep';
    requires 'Test::More', '0.98';
    requires 'Test::RedisServer', '0.12';
    requires 'Test::TCP', '1.18';
};
