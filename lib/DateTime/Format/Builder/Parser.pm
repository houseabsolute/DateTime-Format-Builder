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

sub create_single_parser
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

=pod

Creates the multi-spec parsers.

=cut

sub create_multiple_parsers
{
    my $class = shift;
    my ($options, @specs) = @_;

    # Organise the specs, and transform them into parsers.
    my ($lengths, $others) = $class->sort_parsers( $options, \@specs );
    for ( 'preprocess' ) {
	$options->{$_} = $class->merge_callbacks( $options->{$_} ) if $options->{$_};
    }

    # These are the innards of a multi-parser.
    return sub {
	my ($self, $date, @args) = @_;

	my %param = (
	    self => $self,
	    ( @args ? (args => \@args) : () ),
	);

	my %p;
	# Preprocess and potentially fill %p
	if ($options->{preprocess})
	{
	    $date = $options->{preprocess}->(
		input => $date, parsed => \%p, %param
	    );
	}

	# Find length parser
	if (%$lengths)
	{
	    my $length = length $date;
	    my $parser = $lengths->{$length};
	    if ($parser)
	    {
		# Found one, call it with _copy_ of %p
		my $dt = $parser->( $self, $date, { %p }, @args );
		return $dt if defined $dt;
	    }
	}
	# Or calls all others, with _copy_ of %p
	for my $parser (@$others)
	{
	    my $dt = $parser->( $self, $date, { %p }, @args );
	    return $dt if defined $dt;
	}
	# Failed, return undef.
	return undef;
    };
}

=pod

Organise and create parsers from specs.

=cut

sub sort_parsers
{
    my $class = shift;
    my ($options, $specs) = @_;
    my (%lengths, @others);

    for my $spec (@$specs)
    {
	# Put coderefs straight into the 'other' heap.
	if (ref $spec eq 'CODE')
	{
	    push @others, $spec;
	}
	# Specifications...
	elsif (ref $spec eq 'HASH')
	{
	    if (exists $spec->{length})
	    {
		croak "Cannot specify the same length twice"
		if exists $lengths{$spec->{length}};

		$lengths{$spec->{length}} =
		    $class->create_single_parser( %$spec );
	    }
	    else
	    {
		push @others, $class->create_single_parser( %$spec );
	    }
	}
	# Something else
	else
	{
	    croak "Invalid specification in list.";
	}
    }

    return ( \%lengths, \@others );
}

sub create_parser
{
    my $class = shift;
    if (not ref $_[0])
    {
	# Simple case of single specification as a hash
	return $class->create_single_parser( @_ )
    }

    # Let's see if we were given an options block
    my %options;
    if (ref $_[0] eq 'ARRAY')
    {
	my $options = shift;
	%options = @$options;
    }

    # Now, can we create a multi-parser out of the remaining arguments?
    if (ref $_[0] eq 'HASH' or ref $_[0] eq 'CODE')
    {
	return $class->create_multiple_parsers( \%options, @_ );
    }
    else
    {
	# If it wasn't a HASH or CODE, then it was something we
	# don't currently accept.
	croak "create_parser called with bad params.";
    }
}

# Find all our workers
{
    use File::Find ();
    use File::Spec ();
    use File::Basename qw( basename );
    my @dirs = grep -d, map { File::Spec->catfile( $_, qw( DateTime Format Builder Parser ) ) } @INC;
    my $count = 0;
    my %loaded;
    File::Find::find({
	    no_chdir => 1,
	    wanted => sub {
		if ( /\.pm\z/ )
		{
		    next if $loaded{basename($_)}++;
		    require $_;
		    $count++;
		}
	    },
	},
	@dirs
    );
    croak "No parser modules found: this is bad! Check directory permissions.\n" unless $count;
}

1;
