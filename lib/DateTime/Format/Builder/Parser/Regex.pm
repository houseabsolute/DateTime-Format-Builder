package DateTime::Format::Builder::Parser::Regex;
use strict;
use vars qw( $VERSION @ISA );
use Params::Validate qw( validate ARRAYREF SCALARREF HASHREF );

$VERSION = '0.16';
@ISA = qw( DateTime::Format::Builder::Parser );

__PACKAGE__->valid_params(
# How to match
    params	=> {
	type	=> ARRAYREF, # mapping $1,$2,... to new() args
    },
    regex	=> {
	type      => SCALARREF,
	callbacks => {
	    'is a regex' => sub { ref(shift) eq 'Regexp' }
	}
    },
# How to create
    extra	=> {
	type => HASHREF,
	optional => 1,
    },
);

sub create_parser
{
    my ($self, %args) = @_;
    $args{extra} ||= {};

    # Create our parser
    return $self->generic_parser(
	( map { exists $args{$_} ? ( $_ => $args{$_} ) : () } qw(
	    on_match on_fail preprocess postprocess
	    ) ),
	do_match => sub {
	    my $date = shift;
	    # Do the match!
	    my @matches = $date =~ $args{regex};
	    return @matches ? \@matches : undef;
	},

	post_match => sub {
	    my ( $date, $matches, $p ) = @_;
	    # Fill %p from match
	    @{$p}{ @{ $args{params} } } = @$matches;
	    return;
	},
	label => $args{label},
	make => sub {
	    my ( $date, $dt, $p ) = @_;
	    DateTime->new( %$p, %{ $args{extra} } );
	}
    );
}


1;
