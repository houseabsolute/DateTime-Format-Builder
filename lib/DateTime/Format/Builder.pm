package DateTime::Format::Builder;
# $Id$

use strict;
use 5.005;
use Carp;
use DateTime 0.07;
use Params::Validate qw( validate SCALAR ARRAYREF HASHREF SCALARREF CODEREF );
use vars qw( $VERSION );

$VERSION = '0.24';

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

sub create_class
{
    my $class = shift;
    my %args = validate( @_, {
	class	=> { type => SCALAR, default => (caller)[0] },
	version => { type => SCALAR, optional => 1 },
	parsers	=> { type => HASHREF },
    });

    my $target = $args{class};

    # Create own lovely new package
    {
	no strict 'refs';

	${"${target}::VERSION"} = $args{version} if (exists $args{version});

	*{"${target}::new"} = sub {
	    my $class = shift;
	    croak "${class}->new takes no parameters." if @_;

	    my $self = bless {}, ref($class)||$class;
	    # If called on an object, clone, but we've nothing to
	    # clone

	    $self;
	};

	while (my ($method, $parsers) = each %{ $args{parsers} })
	{
	    *{"${target}::$method"} = $class->create_parser(
		(ref $parsers eq 'HASH' ) ? %$parsers : @$parsers
	    );
	}
    }

}

sub create_parser
{
    my $class = shift;
    if (not ref $_[0])
    {
	# Simple case
	my $parser = $class->create_single_parser( @_ );
	return sub {
	    $parser->(@_) || croak "Invalid date format: $_[1]";
	};
    } #

    my %options;
    if (ref $_[0] eq 'ARRAY')
    {
	my $options = shift;
	%options = @$options;
    }

    if (ref $_[0] eq 'HASH' or ref $_[0] eq 'CODE')
    {
	# Series of parser specs
	my @specs = @_;

	my %lengths;
	my @others;

	for my $spec (@specs)
	{
	    if (ref $spec eq 'CODE')
	    {
		push @others, $spec;
	    }
	    elsif (ref $spec eq 'HASH')
	    {
		if (exists $spec->{length})
		{
		    $lengths{$spec->{length}} =
			$class->create_single_parser( %$spec );
		}
		else
		{
		    push @others, $class->create_single_parser( %$spec );
		}
	    }
	    else
	    {
		croak "Invalid specification in list.";
	    }
	}

	return sub {
	    my ($self, $date) = @_;

	    my %p;
	    if ($options{preprocess})
	    {
		$date = $options{preprocess}->( input => $date, parsed => \%p );
	    }

	    # Find length parser
	    if (%lengths)
	    {
		my $length = length $date;
		my $parser = $lengths{$length};
		my $dt = eval { $parser->( $self, $date, \%p ) };
		return $dt if defined $dt and not $@;
	    }
	    # Or find parser parser
	    for my $parser (@others)
	    {
		my $dt = eval { $parser->( $self, $date, \%p ) };
		return $dt if defined $dt and not $@;
	    }
	    croak "Invalid date format: $date\n";
	};
    }
    else
    {
	# Only called in event of weirdness (e.g. bad params).
	# Shoving it off to csp() should result in appropriate
	# errors.
	my $parser = $class->create_single_parser( @_ );
	return sub {
	    $parser->(@_) || croak "Invalid date format: $_[1]";
	};
    }

    #
}

sub create_single_parser
{
    my $class = shift;
    return $class->create_single_parser( %{ $_[0] } ) if ref $_[0] eq 'HASH';
    return $_[0] if ref $_[0] eq 'CODE';
    # ordinary boring sort
    my %args = validate( @_, {
	    # How to match
	    params	=> {
		type => ARRAYREF
	    },
	    regex	=> {
		type      => SCALARREF,
		callbacks => { 'is a regex' => sub { ref(shift) eq 'Regexp' } }
	    },
	    length	=> {
		type      => SCALAR,
		optional  => 1,
		callbacks => { 'is an int' => sub { $_[0] !~ /\D/ } }
	    },
	    # How to create
	    extra	=> {
		type => HASHREF,
		default => { },
	    },

	    # Stuff used by callbacks
	    on_match	=> { type => CODEREF,	optional => 1 },
	    on_fail	=> { type => CODEREF,	optional => 1 },
	    postprocess => { type => CODEREF,	optional => 1 },
	    preprocess => { type => CODEREF,	optional => 1 },
	    label	=> { type => SCALAR,	optional => 1 },
	}
    );
    my $callback = (exists $args{on_match} or exists $args{on_fail}) ? 1 : undef;
    my $label = exists $args{label} ? $args{label} : undef;

    return sub {
	my ($self, $date, $p) = @_;
	my %p;
	%p = %$p if $p;

	if ($args{preprocess})
	{
	    $date = $args{preprocess}->( input => $date, parsed => \%p );
	}

	my @matches = $date =~ $args{regex};

	# Funky callback thing
	if ($callback)
	{
	    my $type = @matches ? "on_match" : "on_fail";
	    if ($args{$type}) {
		$args{$type}->(
		    input => $date,
		    ( defined $label ? ( label => $label ) : ())
		);
	    }
	}
	return undef unless @matches;

	@p{ @{ $args{params} } } = @matches;

	# Allow post processing
	return if $args{postprocess} and not $args{postprocess}->(
	    parsed => \%p,
	    input => $date,
	);

	return DateTime->new( %p, %{ $args{default} } );
    };
}

sub set_parser
{
    my ($self, $parser) = @_;
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
    croak "No date specified." unless @_;
    return $self->{parser}->( $self, @_ );
}

sub format_datetime
{
    croak __PACKAGE__."::format_datetime not implemented.";
}

1;
