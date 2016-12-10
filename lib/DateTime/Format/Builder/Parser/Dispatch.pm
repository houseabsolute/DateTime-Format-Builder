package DateTime::Format::Builder::Parser::Dispatch;

use strict;
use warnings;

our $VERSION = '0.82';

use vars qw( %dispatch_data );
use Params::Validate qw( CODEREF validate );
use DateTime::Format::Builder::Parser;

=head1 SYNOPSIS

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

=head1 DESCRIPTION

C<Dispatch> adds another parser type to C<Builder> permitting
dispatch of parsing according to group names.

=head1 SPECIFICATION

C<Dispatch> has just one key: C<Dispatch>. The value should be a
reference to a subroutine that returns one of:

=over 4

=item *

C<undef>, meaning no groups could be found.

=item *

An empty list, meaning no groups could be found.

=item *

A single string, meaning: use this group

=item *

A list of strings, meaning: use these groups in this order.

=back

Groups are specified much like the example in the L<SYNOPSIS>.
They follow the same format as when you specify them for methods.

=head1 SIDEEFFECTS

Your group parser can also be a Dispatch parser. Thus you could
potentially end up with an infinitely recursive parser.

=cut


{
    no strict 'refs';
    *dispatch_data = *DateTime::Format::Builder::dispatch_data;
    *params        = *DateTime::Format::Builder::Parser::params;
}

DateTime::Format::Builder::Parser->valid_params(
    Dispatch => {
        type => CODEREF,
    }
);

sub create_parser {
    my ( $self, %args ) = @_;
    my $coderef = $args{Dispatch};

    return sub {
        my ( $self, $date, $p, @args ) = @_;
        return unless defined $date;
        my $class = ref($self) || $self;

        my @results = $coderef->($date);
        return unless @results;
        return unless defined $results[0];

        for my $group (@results) {
            my $parser = $dispatch_data{$class}{$group};
            die "Unknown parsing group: $class\n" unless defined $parser;
            my $rv = eval { $parser->parse( $self, $date, $p, @args ) };
            return $rv unless $@ or not defined $rv;
        }
        return;
    };
}

1;

# ABSTRACT: Dispatch parsers by group

__END__

=head1 SUPPORT

See L<DateTime::Format::Builder> for details.

=head1 SEE ALSO

C<datetime@perl.org> mailing list.

http://datetime.perl.org/

L<perl>, L<DateTime>,
L<DateTime::Format::Builder>

=cut


