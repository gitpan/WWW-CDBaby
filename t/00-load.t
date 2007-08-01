#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'WWW::CDBaby' );
}

diag( "Testing WWW::CDBaby $WWW::CDBaby::VERSION, Perl $], $^X" );
