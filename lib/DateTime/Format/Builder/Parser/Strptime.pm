package DateTime::Format::Builder::Parser::Strptime;
use strict;
use vars qw( $VERSION @ISA );
use Params::Validate qw( validate SCALAR HASHREF );

$VERSION = '0.13';
@ISA = qw( DateTime::Format::Builder::Parser );

__PACKAGE__->valid_params(
    strptime	=> {
	type	=> SCALAR|HASHREF, # straight pattern or options to DTF::Strptime
    },
);

sub create_parser
{
    my ($self, %args) = @_;

    # Arguments to DTF::Strptime
    my $pattern = $args{strptime};

    # Create our strptime parser
    require DateTime::Format::Strptime;
    my $strptime = DateTime::Format::Strptime->new(
	( ref $pattern ? %$pattern : ( pattern => $pattern ) ),
    );

    # Create our parser
    return $self->generic_parser(
	( map { exists $args{$_} ? ( $_ => $args{$_} ) : () } qw(
	    on_match on_fail preprocess postprocess
	    ) ),
	do_match => sub {
	    my $date = shift;
	    # Do the match!
	    my $dt = eval { $strptime->parse_datetime( $date ) };
	    return $@ ? undef : $dt;
	},
	post_match => sub {
	    return $_[1],
	},
	label => $args{label},
    );
}


1;
