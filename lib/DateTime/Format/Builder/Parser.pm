package DateTime::Format::Builder::Parser;
use strict;
use vars qw( $VERSION );
use Carp;
use Params::Validate qw(
    validate SCALAR ARRAYREF HASHREF SCALARREF CODEREF GLOB GLOBREF UNDEF
);

$VERSION = '0.14';

my @callbacks = qw( on_match on_fail postprocess preprocess );

{
    my %params = (
	common => {
	    length	=> {
		type      => SCALAR,
		optional  => 1,
		callbacks => {
		    'is an int' => sub { $_[0] !~ /\D/ }
		}
	    },

	    # Stuff used by callbacks
	    label	=> { type => SCALAR,	optional => 1 },
	    ( map { $_ => { type => CODEREF, optional => 1 } } @callbacks ),
	},
    );

    sub params
    {
	my $self = shift;
	my $caller = ref $self || $self;
	return { map { %$_ } @params{ $caller, 'common' } }
    }

    my $all_params;
    sub params_all
    {
	return $all_params if defined $all_params;
	my %all_params = map { %$_ } values %params;
	$_ = { %$_, optional => 1 } for values %all_params;
	$all_params = \%all_params;
    }

    my %inverse;
    sub valid_params
    {
	my $self = shift;
	my $from = (caller)[0];
	my %args = @_;
	$params{ $from } = \%args;
	$inverse{$_} = $from for keys %args;
	undef $all_params;
	1;
    }

    sub whose_params
    {
	my $param = shift;
	return $inverse{$param};
    }
}

sub create_parser
{
    my $class = shift;
    return $_[0] if ref $_[0] eq 'CODE'; # already code
    @_ = %{ $_[0] } if ref $_[0] eq 'HASH'; # turn hashref into hash
    # ordinary boring sort
    my %args = validate( @_, params_all() );

    # Determine variables for ease of reference.
    for (@callbacks)
    {
	$args{$_} = $class->merge_callbacks( $args{$_} ) if $args{$_};
    }

    my $from;
    for ( keys %args )
    {
	$from = whose_params( $_ );
	last unless $from eq 'common';
    }
    if ( $from )
    {
	eval " require $from ";
	croak $@ if $@;
	my $method = $from->can( "create_parser" )
	    or croak "Can't create  a $_ parser (no such method)";
	my @args = %args;
	my %args = validate( @args, $from->params() );
	return $class->$method( %args );
    }

    croak "Could not identify a parsing module to use.";
}

sub generic_parser {
    my $class = shift;
    my %args = validate( @_, {
	    ( map { $_ => { type => CODEREF, optional => 1 } } qw(
	      do_match post_match on_match on_fail make
	      preprocess postprocess
	    ) ),
	    label => { type => SCALAR|UNDEF, optional => 1 },
	});
    my $label = $args{label};

    my $callback = (exists $args{on_match} or exists $args{on_fail}) ? 1 : undef;

    return sub
    {
	my ($self, $date, $p, @args) = @_;
	my %p;
	%p = %$p if $p; # Look! A Copy!

	my %param = (
	    self => $self,
	    ( defined $label ? ( label => $label ) : ()),
	    (@args ? (args => \@args) : ()),
	);

	# Preprocess - can modify $date and fill %p
	if ($args{preprocess})
	{
	    $date = $args{preprocess}->( input => $date, parsed => \%p, %param );
	}

	my $rv = $args{do_match}->( $date, @args ) if exists $args{do_match};

	# Funky callback thing
	if ($callback)
	{
	    my $type = defined $rv ? "on_match" : "on_fail";
	    $args{$type}->( input => $date, %param ) if $args{$type};
	}
	return undef unless defined $rv;

	my $dt;
	$dt = $args{post_match}->( $date, $rv, \%p ) if exists $args{post_match};

	# Allow post processing. Return undef if regarded as failure
	if ($args{postprocess})
	{
	    my $rv = $args{postprocess}->(
		parsed => \%p,
		input => $date,
		post => $dt,
		%param,
	    );
	    return undef unless $rv;
	}

	# A successful match!
	$dt = $args{make}->( $date, $dt, \%p ) if exists $args{make};
	return $dt;
    };
}

=pod

Produce either undef or a single coderef from either undef,
an empty array, a single coderef or an array of coderefs

=cut

sub merge_callbacks
{
    my $self = shift;

    return undef unless @_; # No arguments
    return undef unless $_[0]; # Irrelevant argument
    my @callbacks = @_;
    if (@_ == 1)
    {
	return $_[0] if ref $_[0] eq 'CODE';
	@callbacks = @{ $_[0] } if ref $_[0] eq 'ARRAY';
    }
    return undef unless @callbacks;

    for (@callbacks)
    {
	croak "All callbacks must be coderefs!" unless ref $_ eq 'CODE';
    }

    return sub {
	my $rv;
	my %args = @_;
	for my $cb (@callbacks)
	{
	    $rv = $cb->( %args );
	    return $rv unless $rv;
	    # Ugh. Symbiotic. All but postprocessor return the date.
	    $args{input} = $rv unless $args{parsed};
	}
	$rv;
    };
}

{
    use File::Find;
    use File::Spec;
    my @dirs = map { File::Spec->catfile( $_, qw( DateTime Format Builder Parser ) ) } @INC;
    find({
	    no_chdir => 1,
	    wanted => sub {
		require $_ if /\.pm\z/;
	    },
	},
	@dirs);
}

1;
