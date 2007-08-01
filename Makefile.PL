use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'WWW::CDBaby',
    AUTHOR              => 'Grant Grueninger <grantg@cpan.org>',
    VERSION_FROM        => 'lib/WWW/CDBaby.pm',
    ABSTRACT_FROM       => 'lib/WWW/CDBaby.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'WWW::Sitebase::Navigator' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'WWW-CDBaby-*' },
);
