# vim: ft=perl et
use inc::Module::Install;

&Meta->read;

include_deps( 'Test::More', 5.004 );
include( 'Test::Signature' );

&AutoInstall->run;
&Makefile->write;
