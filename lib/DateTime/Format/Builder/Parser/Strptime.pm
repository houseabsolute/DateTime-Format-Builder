package DateTime::Format::Builder::Parser::Strptime;

=head1 SYNOPSIS

   my $parser = DateTime::Format::Builder->create_parser(
	strptime => '%e/%b/%Y:%H:%M:%S %z',
   );

=head1 SPECIFICATION

=over 4

=item *

B<strptime> takes as its argument a strptime string.
See L<DateTime::Format::Strptime> for more information
on valid patterns.

=back

=cut

use strict;
use warnings;
use vars qw( @ISA );
use Params::Validate qw( validate SCALAR HASHREF );

use DateTime::Format::Builder::Parser::generic;
@ISA = qw( DateTime::Format::Builder::Parser::generic );

__PACKAGE__->valid_params(
    strptime => {
        type => SCALAR
            | HASHREF,    # straight pattern or options to DTF::Strptime
    },
);

sub create_parser {
    my ( $self, %args ) = @_;

    # Arguments to DTF::Strptime
    my $pattern = $args{strptime};

    # Create our strptime parser
    require DateTime::Format::Strptime;
    my $strptime = DateTime::Format::Strptime->new(
        ( ref $pattern ? %$pattern : ( pattern => $pattern ) ),
    );
    unless ( ref $self ) {
        $self = $self->new(%args);
    }
    $self->{strptime} = $strptime;

    # Create our parser
    return $self->generic_parser(
        (
            map { exists $args{$_} ? ( $_ => $args{$_} ) : () }
                qw(
                on_match on_fail preprocess postprocess
                )
        ),
        label => $args{label},
    );
}

sub do_match {
    my $self = shift;
    my $date = shift;
    local $^W;    # bizarre bug
                  # Do the match!
    my $dt = eval { $self->{strptime}->parse_datetime($date) };
    return $@ ? undef : $dt;
}

sub post_match {
    return $_[2];
}

1;

# ABSTRACT: strptime based date parsing

__END__

=head1 SUPPORT

See L<DateTime::Format::Builder> for details.

=head1 SEE ALSO

C<datetime@perl.org> mailing list.

http://datetime.perl.org/

L<perl>, L<DateTime>,
L<DateTime::Format::Builder>

=cut


