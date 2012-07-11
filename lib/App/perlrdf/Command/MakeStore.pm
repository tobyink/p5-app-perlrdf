package App::perlrdf::Command::MakeStore;

use 5.010;
use strict;
use warnings;
use utf8;

BEGIN {
	$App::perlrdf::Command::MakeStore::AUTHORITY = 'cpan:TOBYINK';
	$App::perlrdf::Command::MakeStore::VERSION   = '0.001';
}

use App::perlrdf -command;
use namespace::clean;

use constant abstract      => q (Initialise an RDF::Trine::Store.);
use constant command_names => qw( make_store mkstore );
use constant description   => <<'DESCRIPTION' . __PACKAGE__->store_help;
Creates an empty RDF::Trine store.
DESCRIPTION
use constant opt_spec => ( __PACKAGE__->store_opt_spec );

sub execute
{
	my ($self, $opt, $arg) = @_;
	$self->get_store($opt)->init;
	say "done";
}

1;
