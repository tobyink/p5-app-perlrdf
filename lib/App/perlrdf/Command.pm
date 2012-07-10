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
	my ($self, $class, $name, $opt) = @_;
	
	my @specs = map {
		$class->new_from_filespec(
			$_,
			$opt->{$name.'_format'},
			$opt->{$name.'_base'},
		)
	} do {
		if (ref $opt->{$name.'_spec'} eq 'ARRAY')
			{ @{$opt->{$name.'_spec'}} }
		elsif (defined $opt->{$name.'_spec'})
			{ ($opt->{$name.'_spec'}) }
		else
			{ qw() }
	};
	
	if (defined $opt->{$name} and length $opt->{$name})
	{
		push @specs, $class->new_from_filespec(
			'{}'.$opt->{$name},
			$opt->{$name.'_format'},
			$opt->{$name.'_base'},
		)
	}
	
	return @specs;
}

1;