requires 'EV', '4.11';
requires 'XSLoader', '0.02';

on configure => sub {
    requires 'EV::MakeMaker';
    requires 'ExtUtils::ParseXS', '2.21';
    requires 'Module::Build::Pluggable::ReadmeMarkdownFromPod', '0.04';
    requires 'Module::Build::Pluggable::XSUtil', '1.02';
};

on build => sub {
    requires 'Devel::Refcount';
    requires 'ExtUtils::CBuilder';
    requires 'Module::Build::Pluggable::ReadmeMarkdownFromPod', '0.04';
    requires 'Module::Build::Pluggable::XSUtil', '1.02';
    requires 'Pod::Markdown';
    requires 'Test::Deep';
    requires 'Test::More', '0.98';
    requires 'Test::RedisServer', '0.12';
    requires 'Test::TCP', '1.18';
};
