package DateTime::Format::Builder;
# $Id$

=begin comments

Note: there is no API documentation in this file. You want F<Builder.pod> instead.

=cut

use strict;
use 5.005;
use Carp;
use DateTime 0.07;
use Params::Validate qw(
    validate SCALAR ARRAYREF HASHREF SCALARREF CODEREF GLOB GLOBREF UNDEF
);
use vars qw( $VERSION );

$VERSION = '0.64';

# Developer oriented methods

=pod

C<verbose()> sets the logging.

=cut

use vars qw( $LOG_HANDLE );

sub verbose
{
    my $fh = shift;
    return $LOG_HANDLE = undef unless defined $fh;
    return $LOG_HANDLE = $fh if fileno $fh;
    return $LOG_HANDLE = \*STDERR;
}

my $log = sub {
    return unless defined $LOG_HANDLE;
    print $LOG_HANDLE @_, "\n";
};

my $logging = sub { defined $LOG_HANDLE };

my $log_parse = sub {
    my ($text, $p) = @_;
    if ($logging->())
    {
	$log->($text);
	require Data::Dumper;
	$log->(Data::Dumper->Dump( [ $p ], [ 'p' ] ) );
    }
};

=pod

C<import()> merely exists to save typing. class is specified after C<@_>
in order to override it. We really don't want to know about
any class they specify. We'd leave it empty, but C<create_class()>
uses C<caller()> to determine where the code came from.

=cut

sub import
{
    my $class = shift;
    $class->create_class( @_, class => (caller)[0] ) if @_;
}

=pod

Populates C<$class::VERSION>, C<$class::new> and writes any
of the methods.

=cut

sub create_class
{
    my $class = shift;
    my %args = validate( @_, {
	class	=> { type => SCALAR, default => (caller)[0] },
	version => { type => SCALAR, optional => 1 },
	verbose	=> { type => SCALAR|GLOBREF|GLOB, optional => 1 },
	parsers	=> { type => HASHREF },
	constructor => { type => UNDEF|SCALAR|CODEREF, optional => 1 },
    });

    verbose( $args{verbose} ) if exists $args{verbose};

    my $target = $args{class}; # where we're writing our methods and such.

    # Create own lovely new package
    {
	no strict 'refs';


	${"${target}::VERSION"} = $args{version} if exists $args{version};

	$class->create_constructor( $target, exists $args{constructor}, $args{constructor} );

	# Write all our parser methods, creating parsers as we go.
	while (my ($method, $parsers) = each %{ $args{parsers} })
	{
	    # I want to dereference the argument if it was a hash or
	    # array ref. Coderefs? Straight through.
	    my $globname = $target."::$method";
	    croak "Will not override a preexisting new()" if defined &$globname;
	    *$globname = $class->create_parser(
		(ref $parsers eq 'HASH' ) ? %$parsers :
		( ( ref $parsers eq 'ARRAY' ) ? @$parsers : $parsers )
	    );
	}
    }

}

sub create_constructor
{
    my $class = shift;
    my ( $target, $intended, $value ) = @_;

    my $new = $target."::new";
    $value = 1 unless $intended;

    return unless $value;
    return if not $intended and defined &$new;
    croak "Will not override a preexisting new()" if defined &$new;

    no strict 'refs';

    return *$new = $value if ref $value eq 'CODE';
    return *$new = sub {
	my $class = shift;
	croak "${class}->new takes no parameters." if @_;

	my $self = bless {}, ref($class)||$class;
	# If called on an object, clone, but we've nothing to
	# clone

	$self;
    };
}

=pod

This creates the method coderefs. Coderefs die on bad parses, return
C<DateTime> objects on good parse. Used by C<parser()> and
C<create_class()>.

=cut

sub create_parser
{
    my $class = shift;
    if (not ref $_[0])
    {
	# Simple case of single specification as a hash
	return $class->create_method(
	    $class->create_single_parser( @_ )
	);
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
	return $class->create_method(
	    $class->create_multiple_parsers( \%options, @_ )
	);
    }
    else
    {
	# If it wasn't a HASH or CODE, then it was something we
	# don't currently accept.
	croak "create_parser called with bad params.";
    }
}

=pod

C<create_method()> simply takes a parser and returns a coderef suitable
to act as a method.

=cut

sub create_method
{
    my ($class, $parser) = @_;
    return sub {
	my $self = shift;
	$log->("Calling parser on <$_[0]>");
	$self->$parser(@_) || $self->on_fail( $_[0] );
    }
}

=pod

This is the method used when a parse fails. Subclass and override
this if you like.

=cut

sub on_fail
{
    my ($class, $input) = @_;
    croak "Invalid date format: $input";
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
    for ('preprocess') {
	$options{$_} = $class->merge_callbacks( $options{$_} ) if $options{$_};
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
	    $log->("Calling preprocessor on <$date>");
	    $date = $options->{preprocess}->(
		input => $date, parsed => \%p, %param
	    );
	    $log_parse->("Master preprocess results <$date>", \%p );
	}

	# Find length parser
	if (%$lengths)
	{
	    my $length = length $date;
	    my $parser = $lengths->{$length};
	    if ($parser)
	    {
		# Found one, call it with _copy_ of %p
		$log->("Trying length parse (length = $length) <$date>");
		my $dt = $parser->( $self, $date, { %p }, @args );
		return $dt if defined $dt;
	    }
	}
	# Or calls all others, with _copy_ of %p
	for my $parser (@$others)
	{
	    $log->("Trying parse <$date>");
	    my $dt = $parser->( $self, $date, { %p }, @args );
	    return $dt if defined $dt;
	}
	# Failed, return undef.
	$log->("No parse");
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

=pod

Create the single parser. Delegation stops here!

=cut

sub create_single_parser
{
    my $class = shift;
    return $_[0] if ref $_[0] eq 'CODE'; # already code
    @_ = %{ $_[0] } if ref $_[0] eq 'HASH'; # turn hashref into hash
    my @callbacks = qw( on_match on_fail postprocess preprocess );
    # ordinary boring sort
    my %args = validate( @_, {
	    # How to match
	    params	=> {
		type => ARRAYREF, # mapping $1,$2,... to new() args
	    },
	    regex	=> {
		type      => SCALARREF,
		callbacks => {
		    'is a regex' => sub { ref(shift) eq 'Regexp' }
		}
	    },
	    length	=> {
		type      => SCALAR,
		optional  => 1,
		callbacks => {
		    'is an int' => sub { $_[0] !~ /\D/ }
		}
	    },
	    # How to create
	    extra	=> {
		type => HASHREF,
		default => { },
	    },

	    # Stuff used by callbacks
	    label	=> { type => SCALAR,	optional => 1 },
	    ( map { $_ => { type => CODEREF, optional => 1 } } @callbacks ),
	}
    );

    # Determine variables for ease of reference.
    my $callback = (exists $args{on_match}
	    or exists $args{on_fail}) ? 1 : undef;
    my $label = exists $args{label} ? $args{label} : undef;
    for (@callbacks)
    {
	$args{$_} = $class->merge_callbacks( $args{$_} ) if $args{$_};
    }

    # Create our parser
    return sub {
	my ($self, $date, $p, @args) = @_;
	my %p;
	%p = %$p if $p; # Look! A copy!

	my %param = (
	    self => $self,
	    ( defined $label ? ( label => $label ) : ()),
	    (@args ? (args => \@args) : ()),
	);

	# Preprocess - can modify $date and fill %p
	if ($args{preprocess})
	{
	    $log->("Single preprocess <$date>");
	    $date = $args{preprocess}->( input => $date, parsed => \%p, %param );
	    $log_parse->("Preprocess results <$date>", \%p );
	}

	# Do the match!
	my @matches = $date =~ $args{regex};

	# Funky callback thing
	if ($callback)
	{
	    my $type = @matches ? "on_match" : "on_fail";
	    $log->("Calling $type callback <$date>");
	    $args{$type}->( input => $date, %param ) if $args{$type};
	}
	return undef unless @matches;

	# Fill %p from match
	@p{ @{ $args{params} } } = @matches;
	$log_parse->("Match gave us", \%p);

	# Allow post processing. Return undef if regarded as failure
	if ($args{postprocess})
	{
	    my $rv = $args{postprocess}->(
		parsed => \%p,
		input => $date,
		%param,
	    );
	    $log_parse->("Postprocess of <$date> gave us", \%p);
	    return undef unless $rv;
	}

	# A successful match!
	$log->("Good parse");
	return DateTime->new( %p, %{ $args{extra} } );
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

#
# User oriented methods
#

=pod

These methods don't need explaining. They're pretty much
boiler plate stuff.

=cut

sub new
{
    my $class = shift;
    croak "Constructor 'new' takes no parameters" if @_;
    my $self = bless {
	parser => sub { croak "No parser set." }
    }, ref($class)||$class;
    if (ref $class)
    {
	# If called on an object, clone
	$self->set_parser( $class->get_parser );
	# and that's it. we don't store that much info per object
    }
    return $self;
}

sub parser
{
    my $class = shift;
    my $parser = $class->create_parser( @_ );

    # Do we need to instantiate a new object for return,
    # or are we modifying an existing object?
    my $self;
    $self = ref $class ? $class : $class->new();

    $self->set_parser( $parser );

    $self;
}

sub clone
{
    my $self = shift;
    croak "Calling object method as class method!" unless ref $self;
    return $self->new();
}

sub set_parser
{
    my ($self, $parser) = @_;
    croak "set_parser given something other than a coderef" unless $parser
	and ref $parser eq 'CODE';
    $self->{parser} = $parser;
    $self;
}

sub get_parser
{
    my ($self) = @_;
    return $self->{parser};
}

sub parse_datetime
{
    my $self = shift;
    croak "parse_datetime is an object method, not a class method."
        unless ref $self and $self->isa( __PACKAGE__ );
    croak "No date specified." unless @_;
    return $self->{parser}->( $self, @_ );
}

sub format_datetime
{
    croak __PACKAGE__."::format_datetime not implemented.";
}

1;
