# $Id$
use strict;
use Test::More tests => 4;
use vars qw( $class );

BEGIN {
    $class = 'DateTime::Format::Builder';
    use_ok $class;
}

{
    $class->create_class(
	class	 => 'DateTime::Format::Builder::Test',
	parsers    => {
	    parse_datetime => [    
	    [
		preprocess => sub {
		    my %p=(@_);
		    my $self = $p{'self'};
		    $p{'parsed'}->{'time_zone'} = $self->{'global'}
			if $self->{'global'};
		    return $p{'input'};
		},
	    ],
	    {
		params => [ qw( year month day hour minute second ) ],
		regex  => qr/^(\d\d\d\d)(\d\d)(\d\d)T(\d\d)(\d\d)(\d\d)$/,
		preprocess =>  sub {
		    my %p=(@_);
		    my $self = $p{'self'};
		    $p{'parsed'}->{'time_zone'} = $self->{'pre'}
			if $self->{'pre'}; 
		    return $p{'input'};
		},
		postprocess => sub {
		    my %p=(@_);
		    my $self = $p{'self'};
		    $p{'parsed'}->{'time_zone'} = $self->{'post'}
			if $self->{'post'}; 
		    return 1;
		},
	    },
	    ],
	}
    );

    @DateTime::Format::Builder::Test::ISA = ($class);

    my ($dt,$parser);

    $parser = DateTime::Format::Builder::Test->new();
    $parser->{'global'} = 'Africa/Cairo';
    $dt = $parser->parse_datetime( "20030716T163245" );
    is( $dt->time_zone->name, 'Africa/Cairo' );

    $parser = DateTime::Format::Builder::Test->new();
    $parser->{'pre'} = 'Europe/London';
    $dt = $parser->parse_datetime( "20030716T163245");
    is( $dt->time_zone->name, 'Europe/London' );

    $parser = DateTime::Format::Builder::Test->new();
    $parser->{'post'} = 'Australia/Sydney';
    $dt = $parser->parse_datetime( "20030716T163245" );
    is( $dt->time_zone->name, 'Australia/Sydney' );
}
