# $Id$
use lib 'inc';
use strict;
use blib;

use Test::More tests => 10;

BEGIN {
    my $class = 'DateTime::Format::Builder';
    use_ok $class;
}

# ------------------------------------------------------------------------

{
    eval q[
	package SampleDispatch;
	use DateTime::Format::Builder
	(
	    parsers => {
		parse_datetime => [
		    {
			Dispatch => sub {
			    return 'fnerk';
			}
		    }
		]
	    },
	    groups => {
		fnerk => [
		    {
			regex => qr/^(\d{4})(\d\d)(\d\d)$/,
			params => [qw( year month day )],
		    },
		]
	    }
	);
    ];
    ok( !$@, "No errors when creating the class." );
    if ($@) { diag $@; exit }

    my $parser = SampleDispatch->new();
    isa_ok( $parser => 'SampleDispatch' );

    my $dt = eval { $parser->parse_datetime( "20040506" ) };
    ok( !$@, "No errors when parsing." );
    if ($@) { diag $@; exit }
    isa_ok( $dt => 'DateTime' );

    is( $dt->year	=> 2004, 'Year is 2004' );
    is( $dt->month	=> 5, 'Year is 2004' );
    is( $dt->day	=> 6, 'Year is 2004' );

    eval { $parser->fnerk };
    ok( $@, "There is no fnerk." );

}

# ------------------------------------------------------------------------

pass "All done.";

