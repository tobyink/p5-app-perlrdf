package App::perlrdf::FileSpec;

use 5.010;
use autodie;
use strict;
use warnings;
use utf8;

BEGIN {
	$App::perlrdf::FileSpec::AUTHORITY = 'cpan:TOBYINK';
	$App::perlrdf::FileSpec::VERSION   = '0.001';
}

use Any::Moose;
use Any::Moose '::Util::TypeConstraints';
use IO::Scalar;
use LWP::UserAgent;
use Path::Class;
use PerlX::Maybe;
use RDF::Trine;
use RDF::TriN3;
use RDF::TrineX::Parser::Pretdsl;
use URI;
use URI::file;

use namespace::clean;

class_type 'AbsoluteUri',
	{ class => 'URI' };

class_type 'PathClassFile',
	{ class => 'Path::Class::File' };

coerce 'AbsoluteUri',
	from 'Str', via {
		if    (/^std(in|out):$/i) { URI->new(lc $_) }
		elsif (/^\w+:/i)          { URI->new($_) }
		else                      { URI::file->new_abs($_) }
	};

coerce 'AbsoluteUri',
	from 'PathClassFile', via { URI::file->new_abs("$_") };

has uri => (
	is         => 'ro',
	isa        => 'AbsoluteUri',
	required   => 1,
	coerce     => 1,
);

has base => (
	is         => 'ro',
	isa        => 'AbsoluteUri',
	lazy_build => 1,
	coerce     => 1,
);

has 'format' => (
	is         => 'ro',
	isa        => 'Str',
	lazy_build => 1,
);

sub DEFAULT_STREAM { confess "DEFAULT_STREAM is undefined" };

sub _jsonish
{
	my ($self, $str) = @_;
	$str =~ s/(^\{)|(\}$)//g; # strip curlies
	
	my $opts = {};
	while ($str =~ m{ \s* (\w+|"[^"]+"|'[^']+') \s* [:] (\w+|"[^"]+"|'[^']+') \s* ([;,]|$) }xg)
	{
		my $key = $1;
		my $val = $2;
		$val = $1 if $val =~ /^["'](.+).$/;
		$opts->{$key} = $val;
	}
	
	return $opts;
}

sub new_from_filespec
{
	my ($class, $spec, $default_format, $default_base) = @_;
	
	my ($optstr, $name) = ($spec =~ m<^ (\{ .*? \}) (.+) $>x)
		? ($1, $2)
		: ('{}', $spec);
	my $opts = $class->_jsonish($optstr);

	$class->new(
		'uri'          => ($name eq '-' ? $class->DEFAULT_STREAM : $name),
		maybe('format' => ($opts->{format} // $default_format)),
		maybe('base'   => ($opts->{base}   // $default_base)),
	);
}

sub _build_base
{
	shift->uri;
}

sub _build_format
{
	my $self = shift;
	
	if (lc $self->uri->scheme eq 'file')
	{
		return 'RDF::TrineX::Parser::Pretdsl'
			if $self->uri->file =~ /\.(pret|pretdsl)/i;
		
		return RDF::Trine::Parser
			-> guess_parser_by_filename($self->uri->file);
	}
	
	if ($self->can('response'))
	{
		return $self->response->content_type
			if $self->response->content_type;
		
		return 'RDF::TrineX::Parser::Pretdsl'
			if (($self->response->base // $self->uri) =~ /\.(pret|pretdsl)/i);
			
		return RDF::Trine::Parser->guess_parser_by_filename(
			$self->response->base // $self->uri,
		);
	}

	return 'RDF::TrineX::Parser::Pretdsl'
		if $self->uri =~ /\.(pret|pretdsl)/i;

	return RDF::Trine::Parser->guess_parser_by_filename($self->uri);
}

1;