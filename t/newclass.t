# $Id$
use lib 'inc';
use blib;
use strict;
use Test::More tests => 9;
use vars qw( $class );
BEGIN {
    $class = 'DateTime::Format::Builder';
    use_ok $class;
}

# Does create_class() work properly?
{
    my %args = (
	params => [ qw( year month day hour minute second ) ],
	regex  => qr/^(\d\d\d\d)(\d\d)(\d\d)T(\d\d)(\d\d)(\d\d)$/,
    );
    my $sample = "20030716T163245";
    my $newclass = "DateTime::Format::ICal15";

    $class->create_class(
	class => $newclass,
	version => 4.00,
	parsers => {
	    parse_datetime => [ \%args ],
	},
    );

    my $parser = $newclass->new();
    cmp_ok ( $newclass->VERSION, '==', '4.00', "Version matches");

    {
	my $dt = $parser->parse_datetime( $sample );
	isa_ok( $dt => "DateTime" );
	my %methods = qw(
	    hour 16 minute 32 second 45
	    year 2003 month 7 day 16
	);
	while (my ($method, $expected) = each %methods)
	{
	    is( $dt->$method() => $expected,
		"\$dt->$method() == $expected" );
	}
    }

}
