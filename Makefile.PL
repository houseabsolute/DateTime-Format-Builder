use ExtUtils::MakeMaker;
WriteMakefile(
    NAME		=> 'DateTime::Format::Builder',
    VERSION_FROM	=> 'lib/DateTime/Format/Builder.pm',
    PREREQ_PM => {
		'DateTime' => 0.09,
		'Params::Validate' => 0.58,
		'Test::More' => 0.47,
	    },
    ($] >= 5.005 ?
      (ABSTRACT_FROM => 'lib/DateTime/Format/Builder.pod',
      AUTHOR     => 'Iain Truskett <spoon@cpan.org>') : ()),
    ( eval($ExtUtils::MakeMaker::VERSION) >= 6.10 ?
	( NO_META => 1, ) : ()),
);


