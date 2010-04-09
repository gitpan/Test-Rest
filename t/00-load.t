#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Test::Rest' );
}

diag( "Testing Test::Rest $Test::Rest::VERSION, Perl $], $^X" );
