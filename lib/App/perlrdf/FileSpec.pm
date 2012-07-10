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

has response => (
	is         => 'ro',
	isa        => 'HTTP::Response',
	lazy_build => 1,
);

has content => (
	is         => 'ro',
	isa        => 'Str',
	lazy_build => 1,
);

has output_handle => (
	is         => 'ro',
	isa        => 'Any',
	lazy_build => 1,
);

has input_handle => (
	is         => 'ro',
	isa        => 'Any',
	lazy_build => 1,
);

has parser => (
	is         => 'ro',
	isa        => 'Object|Undef',
	lazy_build => 1,
);

has serializer => (
	is         => 'ro',
	isa        => 'Object|Undef',
	lazy_build => 1,
);

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
	my ($class, $spec, $default_format, $default_base, $default_stream) = @_;
	
	my ($optstr, $name) = ($spec =~ m<^ (\{ .*? \}) (.+) $>x)
		? ($1, $2)
		: ('{}', $spec);
	my $opts = $class->_jsonish($optstr);

	$class->new(
		'uri'          => ($name eq '-' ? $default_stream : $name),
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
	
	if ($self->response->content_type)
	{
		return $self->response->content_type;
	}

	return 'RDF::TrineX::Parser::Pretdsl'
		if(($self->response->base // $self->uri) =~ /\.(pret|pretdsl)/i);

	return RDF::Trine::Parser
		-> guess_parser_by_filename($self->response->base // $self->uri);
}

sub _build_response
{
	LWP::UserAgent->new->get( shift->uri );
}

sub _build_content
{
	my $self = shift;
	
	if (lc $self->uri->scheme eq 'file')
	{
		return scalar Path::Class::File
			-> new($self->uri->file)
			-> slurp
	}
	elsif (lc $self->uri->scheme eq 'stdin')
	{
		local $/ = <STDIN>;
		return $/;
	}
	else
	{
		return $self->response->decoded_content;
	}
}

sub _build_input_handle
{
	my $self = shift;
	
	if (lc $self->uri->scheme eq 'file')
	{
		return Path::Class::File
			-> new($self->uri->file)
			-> open
	}
	elsif (lc $self->uri->scheme eq 'stdin')
	{
		return \*STDIN;
	}
	else
	{
		my $data = $self->content;
		open my $fh, '<', \$data;
		return $fh;
	}
}

sub _build_output_handle
{
	my $self = shift;
	
	if (lc $self->uri->scheme eq 'file')
	{
		return Path::Class::File
			-> new($self->uri->file)
			-> openw
	}
	elsif (lc $self->uri->scheme eq 'stdout')
	{
		return \*STDOUT;
	}
	elsif (lc $self->uri->scheme eq 'stderr')
	{
		return \*STDERR;
	}
	else
	{
		die "TODO";
	}
}

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

sub _build_serializer
{
	my $self = shift;
	my $P = 'RDF::Trine::Serializer';
	
	if (blessed $self->format and $self->format->isa($P))
	{
		return $self->format;
	}
	
	if ($self->format =~ m{/})
	{
		my (undef, $s) = $P->negotiate(
			request_headers => HTTP::Headers->new(
				Accept => $self->format,
			),
		);
		return $s;
	}

	if ($self->format =~ m{::})
	{
		return $self->format->new;
	}
	
	return $P->new($self->format);
}

1;