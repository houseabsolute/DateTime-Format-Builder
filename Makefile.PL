use ExtUtils::MakeMaker;
WriteMakefile(
    NAME		=> 'DateTime::Format::Builder',
    VERSION_FROM	=> 'lib/DateTime/Format/Builder.pm',
    PREREQ_PM => {
		'DateTime' => 0.08,
		'Params::Validate' => 0.57,
		'Carp' => 1.01,
		'Test::More' => 0.47,
		'Test' => 1.23,
	    },
    ($] >= 5.005 ?
      (ABSTRACT_FROM => 'lib/DateTime/Format/Builder.pod',
      AUTHOR     => 'Iain Truskett <spoon@cpan.org>') : ()),
);


