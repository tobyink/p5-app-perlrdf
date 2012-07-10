package App::perlrdf::FileSpec::InputRDF;

use 5.010;
use autodie;
use strict;
use warnings;
use utf8;

BEGIN {
	$App::perlrdf::FileSpec::InputRDF::AUTHORITY = 'cpan:TOBYINK';
	$App::perlrdf::FileSpec::InputRDF::VERSION   = '0.001';
}

use Any::Moose;
use namespace::clean;

extends 'App::perlrdf::FileSpec::InputFile';

has parser => (
	is         => 'ro',
	isa        => 'Object|Undef',
	lazy_build => 1,
);

sub _build_parser
{
	my $self = shift;
	my $P = 'RDF::Trine::Parser';
	
	if (blessed $self->format and $self->format->isa($P))
	{
		return $self->format;
	}
	
	if ($self->format =~ m{/})
	{
		return $P->parser_by_media_type($self->format)->new;
	}

	if ($self->format =~ m{::})
	{
		return $self->format->new;
	}

	if ($self->format =~ m{(pret|pretdsl)}i)
	{
		return RDF::TrineX::Parser::Pretdsl->new;
	}

	return $P->new($self->format);
}

1;
