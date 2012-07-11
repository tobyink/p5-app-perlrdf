package App::perlrdf::Command::StoreTruncate;

use 5.010;
use strict;
use warnings;
use utf8;

BEGIN {
	$App::perlrdf::Command::StoreTruncate::AUTHORITY = 'cpan:TOBYINK';
	$App::perlrdf::Command::StoreTruncate::VERSION   = '0.001';
}

use App::perlrdf -command;
use namespace::clean;

use constant abstract      => q (Delete RDF data from an RDF::Trine::Store.);
use constant command_names => qw( store_truncate truncate );
use constant description   => <<'INTRO' . __PACKAGE__->store_help . <<'DESCRIPTION';
Delete data from an RDF::Trine::Store.
INTRO
DESCRIPTION

use constant opt_spec => (
	__PACKAGE__->store_opt_spec,
	[]=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>,
	[ 'graph|g=s@',        'Graph(s) to delete (default: all graphs)' ],
	[ 'yes',               'Answer "yes" to prompts' ],
	[ 'nuke',              'Delete the entire store' ],
);

sub execute
{
	require RDF::Trine;
	require App::perlrdf::FileSpec::OutputRDF;
	
	my ($self, $opt, $arg) = @_;

	my $store = $self->get_store($opt);
	my $model = RDF::Trine::Model->new($store);

	if ($opt->{graph})
	{
		for (@{ $opt->{graph} })
		{
			printf STDERR "Truncating graph %s\n", $_;
			my $graph = RDF::Trine::Node::Resource->new($_);
			$model->remove_statements((undef)x3, $graph);
		}
		
		printf STDERR "'nuke' ignored when 'graph' specified\n"
			if $opt->{nuke};
	}
	
	else
	{
		if ($opt->{yes} or prompt_yn("Really delete all data from this store?"))
		{
			$model->remove_statements((undef)x4);
		}
		
		if ($opt->{yes} or prompt_yn("Really nuke this store?"))
		{
			$store->nuke;
		}
	}
}

1;