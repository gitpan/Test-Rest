package Test::Rest::Commands;
use strict;
use warnings;
use Test::More ();
use XML::LibXML;
use Data::Dumper;

sub new {
  my $proto = shift;
  my $class = ref $proto || $proto;
  my %opts = @_;
  return bless \%opts, $class;
}

sub get {
  my $self = shift;
  my $c = shift;
  $c->add_response($c->ua->get($c->expand_url($c->test->textContent)));
}

sub post {
  my $self = shift;
  my $c = shift;
  my $url = $c->expand_url($c->test->getAttribute('to'));
  my %hash;
  _children_to_hash($c->test, \%hash);
  my @node = $c->test->findnodes('Content');
  if (@node and _has_child_elements($node[0])) {
    $hash{Content} = $c->expand_string(_first_child_element($node[0])->toString);
  }
  $hash{'Content-Type'} ||= $node[0]->getAttribute('type') || 'application/xml';
  $c->add_response($c->ua->post($url, %hash));
}

sub is {
  my $self = shift;
  my $c = shift;
  my $value = '';
  if ($c->test->hasAttribute('xpath')) {
    $value = $self->_xpath($c, $c->test->getAttribute('xpath'));
  }
  elsif ($c->test->hasAttribute('the')) {
    $value = $c->expand_string($c->test->getAttribute('the'));
  }
  Test::More::is($value, $c->test->textContent);
}

sub submit_form {
  my $self = shift;
  my $c = shift;
  my %hash;
  _children_to_hash($c->test, \%hash);
  $c->add_response($c->ua->submit_form(%hash));
}

sub set {
  my $self = shift;
  my $c = shift;
  my $value = '';
  if ($c->test->hasAttribute('xpath')) {
    $value = $self->_xpath($c, $c->test->getAttribute('xpath'));
  }
  else {
    $value = $c->expand_string($c->test->textContent);
  }
  $c->stash->{$c->test->getAttribute('name')} = $value;
}

sub diag {
  my $self = shift;
  my $c = shift;
  Test::More::diag($c->expand_string($c->test->textContent));
}

sub _xpath {
  my $self = shift;
  my $c = shift;
  my $xpath = shift;
  my @node = defined($c->stash->{document}->documentElement) ?
    $c->stash->{document}->documentElement->findnodes($xpath) : ();
  if (@node) {
    return $node[0]->nodeType == XML_ELEMENT_NODE ? $node[0]->textContent : $node[0]->nodeValue;
  }
  else {
    return '';
  }
}

sub _children_to_hash {
  my $node = shift;
  my $hash = shift;
  foreach my $child ($node->childNodes) {
    next unless $child->nodeType == XML_ELEMENT_NODE;
    if (_has_child_elements($child)) {
      $hash->{$child->localname} = {};
      _children_to_hash($child, $hash->{$child->localname});
    }
    else {
      $hash->{$child->localname} = $child->textContent;
    }
  }
}

sub _has_child_elements {
  my $e = shift;
  return $e->childNodes && grep($_->nodeType == XML_ELEMENT_NODE, $e->childNodes);
}

sub _first_child_element {
  my $e = shift;
  my @children = grep($_->nodeType == XML_ELEMENT_NODE, $e->childNodes);
  return $children[0];
}

1;
