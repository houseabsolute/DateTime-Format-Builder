use ExtUtils::MakeMaker;
WriteMakefile(
    NAME		=> 'DateTime::Format::Builder',
    VERSION_FROM	=> 'lib/DateTime/Format/Builder.pm',
    PREREQ_PM => {
		'File::Find' => 0,
		'DateTime' => 0.10,
		'Params::Validate' => 0.58,
		'File::Spec' => 0.6,
		'DateTime::Format::Strptime' => 1.00.01,
		'File::Basename' => 2.4,
		'Test::More' => 0.47,
	    },
    ($] >= 5.005 ?
      (ABSTRACT_FROM => 'lib/DateTime/Format/Builder.pod',
      AUTHOR     => 'Iain Truskett <spoon@cpan.org>') : ()),
    ( eval($ExtUtils::MakeMaker::VERSION) >= 6.10 ?
	( NO_META => 1, ) : ()),
);


