# $Id$
use strict;
use lib 'inc';
use blib;
use Test::More tests => 18;
use vars qw( $class );

BEGIN {
    $class = 'DateTime::Format::Builder';
    use_ok $class;
}

# ------------------------------------------------------------------------

sub do_check
{
    my ($parser, $date, $values) = @_;
    my $parsed = $class->$parser( $date );
    isa_ok( $parsed => 'DateTime' );
    is( $parsed->year()  => $values->[0], "Year is right" );
    is( $parsed->month() => $values->[1], "Month is right" );
    is( $parsed->day()   => $values->[2], "Day is right" );
}


{
    my $parser = $class->create_parser(
	{
	    #YYYY-DDD 1985-102
	    regex => qr/^ (\d{4}) -?? (\d{3}) $/x,
	    params => [ qw( year day_of_year ) ],
	    constructor => [ 'DateTime', 'from_day_of_year' ],
	},
	{
	    regex => qr/^ (\d{4}) foo (\d{3}) $/x,
	    params => [ qw( year day_of_year ) ],
	    constructor => sub {
		my $self = shift;
		DateTime->from_day_of_year(@_);
	    },
	}
    );

    my %dates = (
	'1985-102' => [ 1985, 4, 12 ],
	'2004-102' => [ 2004, 4, 11 ], # leap year
    );

    for my $date (sort keys %dates)
    {
	my $values = $dates{$date};
	do_check( $parser, $date, $values );
	$date =~ s/-/foo/;
	do_check( $parser, $date, $values );
    }
}



pass 'All done';
