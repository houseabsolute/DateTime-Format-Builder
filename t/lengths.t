# $Id$
use strict;
use lib 'inc';
use blib;
use Test::More tests => 8;
use vars qw( $class );

BEGIN {
    $class = 'DateTime::Format::Builder';
    use_ok $class;
}

my $which;

my @parsers = (
    {
	length => 10,
	params => [ qw( month year day ) ],
	regex  => qr/^(\d\d)-(\d\d\d\d)-(\d\d)$/,
	postprocess => sub { $which = 1 },
    },
    {
	length => 10,
	params => [ qw( year month day ) ],
	regex  => qr/^(\d\d\d\d)-(\d\d)-(\d\d)$/,
	postprocess => sub { $which = 2 },
    },
    {
	length => 10,
	params => [ qw( day month year ) ],
	regex  => qr/^(\d\d)-(\d\d)-(\d\d\d\d)$/,
	postprocess => sub { $which = 3 },
    },
);

my %data = (
    1 => "05-2003-10",
    2 => "2003-04-07",
    3 => "13-12-2006",
);

{
    my $parser = $class->parser( @parsers );
    isa_ok( $parser => $class );

    for my $length (sort keys %data)
    {
	my $date = $data{$length};
	my $dt = $parser->parse_datetime( $date );
	isa_ok $dt => 'DateTime';
	is( $which, $length, "Used length parser $length" );
    }
}
