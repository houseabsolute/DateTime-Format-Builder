#!/usr/bin/perl -w
use lib 'inc';
use strict;
use blib;

BEGIN {
for (qw( HTTP Mail IBeat ))
{
    my $mod = "DateTime::Format::$_";
    eval "require $mod";
    if ($@) {
	print "1..1\nok 1 # skip Fallthrough tests: $mod not installed.\n";
	exit;
    }
}
}

use Test::More tests => 4;
BEGIN { use_ok 'DateTime::Format::Builder' }

package DTFB::Quick;

use DateTime::Format::Builder (
parsers => { parse_datetime => [
    { Quick => 'DateTime::Format::HTTP' },
    { Quick => 'DateTime::Format::Mail' },
    { Quick => 'DateTime::Format::IBeat' },
]});

package main;

my $get = sub { eval {
        DTFB::Quick->parse_datetime($_[0])->datetime
    } };


for ( '@d19.07.03 @704', '20030719T155345' )
{
    my $dt = $get->( $_ );
    is $dt, "2003-07-19T15:53:45", "Can parse [$_]";
}

for ( 'gibberish' )
{
    my $dt = $get->( $_ );
    ok( !defined $dt, "Shouldn't parse [$_]" )
}
