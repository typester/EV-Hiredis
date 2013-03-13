use strict;
use warnings;

use Config;
use EV::MakeMaker '$installsitearch';

use Module::Build::Pluggable (
    'XSUtil' => {
        cc_warnings => 1,
        ppport      => 'src/ppport.h',
    },
);

my $build = Module::Build::Pluggable->new(
    module_name    => 'EV::Hiredis',
    license        => 'perl',
    create_license => 1,
    requires => {
        'EV' => '4.11',
    },
    configure_requires => {
        'EV::MakeMaker' => 0,
    },
    build_requires => {
        'Test::More'        => '0.98',
        'Test::RedisServer' => '0.12',
        'Test::TCP'         => '1.18',
        'Test::Deep'        => 0,
    },
    include_dirs       => ['src', 'deps/hiredis', "${installsitearch}/EV", $installsitearch],
    xs_files           => { 'src/EV__Hiredis.xs' => 'lib/EV/Hiredis.xs' },
    extra_linker_flags => ["deps/hiredis/libhiredis$Config{lib_ext}"],

    test_files           => (-d '.git' || $ENV{RELEASE_TESTING}) ? 't/ xt/' : 't/',
    recursive_test_files => 1,

    no_index => { 'directory' => [ 'deps' ] },
);

$build->do_system($Config{make}, '-C', 'deps/hiredis', 'static');

$build->create_build_script;
