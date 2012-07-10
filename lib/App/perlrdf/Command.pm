package App::perlrdf::Command;

use 5.010;
use strict;
use warnings;
use utf8;

BEGIN {
	$App::perlrdf::Command::AUTHORITY = 'cpan:TOBYINK';
	$App::perlrdf::Command::VERSION   = '0.001';
}

use App::Cmd::Setup -command;

sub get_filespecs
{
	require App::perlrdf::FileSpec;
	my ($self, $name, $opt) = @_;
	
	my @specs = map {
		App::perlrdf::FileSpec->new_from_filespec(
			$_,
			$opt->{"$name\-format"},
			$opt->{"$name\-base"},
		)
	} @{ $opt->{"$name\-spec"} || [] };
	
	if (defined $opt->{$name} and length $opt->{$name})
	{
		push @specs, App::perlrdf::FileSpec->new_from_filespec(
			'{}'.$opt->{$name},
			$opt->{"$name\-format"},
			$opt->{"$name\-base"},
		)
	}
	
	return @specs;
}

1;