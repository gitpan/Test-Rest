package Test::Rest::Context;
use strict;
use warnings;
use base qw(Class::Accessor);
use Carp;
use WWW::Mechanize;
use Template;
use XML::LibXML;
use String::Random;
__PACKAGE__->mk_accessors( qw(test tests stash ua tt base_url) );

sub new {
  my $proto = shift;
  my $class = ref $proto || $proto;
  my %opts = @_;
  $opts{stash} ||= {};
  $opts{ua} ||= WWW::Mechanize->new;
  $opts{tt} ||= Template->new(INCLUDE_PATH => '.')  || die $Template::ERROR, "\n";
  return bless \%opts, $class;
}

sub add_response {
  my $self = shift;
  my $response = shift;
  my $document;
  if ($response->header('Content-Type') =~ /\bxml\b/) {
    $document = XML::LibXML->load_xml(string => $response->content);
  }
  else {
    $document = XML::LibXML::Document->new;
  }
  $self->stash->{documents} ||= [];
  $self->stash->{responses} ||= [];
  push @{$self->stash->{documents}}, $document;
  push @{$self->stash->{responses}}, $response;
  $self->stash->{response} = $response;
  $self->stash->{document} = $document;
}

sub expand_string {
  my $self = shift;
  my $string = shift;
  my $output;
  $self->stash->{c} = $self;
  $self->tt->process(\$string, $self->stash, \$output) || die $self->tt->error(), "\n";
  delete $self->stash->{c};
  return $output;
}

sub expand_url {
  my $self = shift;
  my $string = shift;
  my $url = $self->base_url->clone;
  $url->path_query($string);
  return $self->expand_string($url->as_string);
}

sub random {
  my $self = shift;
  my $n = shift || 8; 
  my $random = new String::Random;
  return $random->randregex('[A-Za-z]{'.$n.'}');
}

1;
