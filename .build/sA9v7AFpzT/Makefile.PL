
use strict;
use warnings;

use 5.012_001;

use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "Datamapper written in Perl",
  "AUTHOR" => "Gines Razanov <ginesr\@gmail.com>",
  "BUILD_REQUIRES" => {
    "Cwd" => 0,
    "DBD::Mock" => 0,
    "DBD::SQLite" => 0,
    "DBD::mysql" => 0,
    "DBI" => 0,
    "Driver::Mongo" => 0,
    "Example::Country" => 0,
    "Example::Driver::Mongo" => 0,
    "Example::Driver::SQLite" => 0,
    "Example::Driver::Storable" => 0,
    "Example::Flat" => 0,
    "Example::Person" => 0,
    "Test::Exception" => 0,
    "Test::More" => 0,
    "Try::Tiny" => 0
  },
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "Gideon",
  "EXE_FILES" => [],
  "LICENSE" => "perl",
  "NAME" => "Gideon",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Class::Accessor::Fast" => 0,
    "DBI" => 0,
    "Data::Dumper" => 0,
    "Digest::MD5" => 0,
    "Exporter" => 0,
    "Hash::Merge" => 0,
    "Hash::MultiValue" => 0,
    "MongoDB" => 0,
    "Mouse" => 0,
    "Mouse::Meta::Attribute" => 0,
    "SQL::Abstract" => 0,
    "Set::Array" => 0,
    "Storable" => 0,
    "Try::Tiny" => 0,
    "autodie" => 0,
    "base" => 0,
    "constant" => 0,
    "overload" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "VERSION" => "0.02",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



