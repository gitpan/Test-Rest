package Test::Rest;
use warnings;
use strict;
use Carp;
use XML::LibXML;
use Test::Rest::Commands;
use Test::Rest::Context;
use URI;
use Test::More;

our $VERSION = '0.01';

=head1 NAME

Test::Rest - Declarative test framework for RESTful web services

=head1 SYNOPSIS

This module is very experimental/alpha and will likely change.  It's not super usable at the moment, but I'm open to feedback and suggestions on how to move forward, and feature requests are OK too.

    use Test::Rest;

    # Scan the directory './tests' for test declaration files 
    # and run them against the server http://webservice.example.com/
    # e.g.
    # ./tests/01-authentication.xml
    # ./tests/02-create-a-foobar.xml
    # ./tests/03-delete-a-foobar.xml
    my $tests = Test::Rest->new(dir => 'tests', base_url => 'http://webservice.example.com/');
    $tests->run;

=head1 DESCRIPTION

The idea here is to write tests against REST services in a data-driven, declarative way.

Here is an example test description file:

    <tests>
      <get>api/login</get>
      <submit_form>
        <with_fields>
          <name>admin</name>
          <pass>admin</pass>
        </with_fields>
      </submit_form>
      <is the="[% response.code %]">200</is> 
      <set name="random">[% c.random %]</set>
      <set name="mail">test+[% random %]@example.com</set>
      <set name="pass">[% random %]</set>
      <post url="rest/user">
        <Content>
          <user>
            <firstname>Testy</firstname>
            <lastname>McTester</lastname>
            <mail>[% mail %]</mail>
            <pass>[% pass %]</pass>
          </user>
        </Content>
      </post>
      <is the="[% response.code %]">200</is> 
      <set name="uid" xpath="id"/>
      <diag>Created a user with ID [% uid %]</diag>
    </tests>

=over

Things to note:

=item * 

Each child of the top-level element represents a command or test, and they are executed sequentially by Test::Rest.

=item * 

Methods like 'get', 'post', and 'submit_form' map to the equivalent methods of L<WWW::Mechanize> or L<LWP::UserAgent> - they result in a request being made to the server.

=item * 

The default user agent is L<WWW::Mechanize>.  Cookies/sessions are stored between requests.

=item * 

The web service URLs given are relative paths and are automatically prefixed by the 'base_url' parameter given to new().

=item * 

Template::Toolkit is used to expand template variables.  The template stash (variable hash) persists until the end of the test file.  The 'set' command can be used to add variables to the stash.

=item * 

The most recent L<HTTP::Response> is stored in the stash via the key 'response'.  If the response type is an XML document, the response document is automatically parsed and available to future tests/commands via XPath, and via the stash key 'document'.  The whole history of responses and documents are available via the stash keys 'responses' and 'documents' respectively.

=back

=head1 COMMANDS

=over

=item get

GETs a URL

Attributes:

=over

=item * 

url - the URL to get.  Relative URLs are automatically prefixed with 'base_url'

=back

=item post

POSTs to a URL

Attributes:

=over

=item url

The URL

=back

Children:

All of the children of the 'post' element are converted to a hash and fed to L<WWW::Mechanize>::post().

The 'Content' element gets special treatment - its first child element is encoded back to XML, and that XML is sent as the content of the post.

TODO: support other content types, including URL-encoded forms.

=over

=item Content

The content to post.  Content-type may be supplied via the 'type' attribute.  Default content type is application/xml.

=back

=item set

Sets a variable in the stash

Attributes:

=over

=item name

Name of the variable

=item xpath

If set, the value of the variable is the first result of the XPath expression given, and the text content of the 'set' element is ignored.

=back

Children:

The text content of the 'set' element is the value of the variable (unless the xpath attribute is set).

=item submit_form

Submits a form (see WWW::Mechanize::submit_form())

Children:

All the child nodes of the submit_form element are converted to a hash and fed to L<WWW::Mechanize>::submit_form()

=head1 FUNCTIONS

=head2 my $tests = Test::Rest->new(%params)

Create a new Test::Rest object

Parameters:

=over

=item * dir - directory to scan for test files

=item * base_url - the base URL of the web service - should end in / 

=back

=cut

sub new {
  my $proto = shift;
  my $class = ref $proto || $proto;
  my %opts = @_;
  return bless \%opts, $class;
}

=head2 $tests->run

Scan directory for test description files and run them.

=cut

sub run {
  my $self = shift;
  croak 'Parameter "base_url" required' unless defined $self->{base_url};
  $self->{base_url} = URI->new($self->{base_url});
  my $dir = $self->{dir};
  croak 'Parameter "dir" required' unless defined $dir;
  croak 'Directory "dir" not found' unless -d $dir;
  opendir(my $dh, $dir) || croak "can't opendir $dir: $!";
  while (my $t = readdir($dh)) {
    next if $t =~ /^\./ or !-f "$dir/$t";
    $self->run_test_file("$dir/$t");
  }
  closedir $dh;
  done_testing();
}

=head2 $tests->run_test_file($filename)

Run a single test description file.

=cut

sub run_test_file {
  my $self = shift;
  my $filename = shift;
  my $doc = XML::LibXML->load_xml(location => $filename);
  my $commands = Test::Rest::Commands->new;
  my $context = Test::Rest::Context->new(tests => $doc, base_url => $self->{base_url});
  foreach my $child ($doc->documentElement->childNodes) {
    next unless $child->nodeType == XML_ELEMENT_NODE;
    my $cmd = $child->localname;
    croak "Unsupported command '$cmd' in $filename" unless $commands->can($cmd);
    $context->test($child);
    $commands->$cmd($context);
  }
}

=head1 AUTHOR

Keith Grennan, C<< <kgrennan at cpan.org> >>

=head1 TODO

=over

=item * 

This initial implementation is very XML/XPath-centric, but there's certainly room to incorporate other formats (YAML, JSON, etc)

=item  *

Figure out how to make friendly with Test::Harness and whatnot

=item *

Allow extensions to supply custom commands, tests, formats

=back

=head1 SEE ALSO

L<LWP::UserAgent>, L<WWW::Mechanize>, L<Template>

=head1 BUGS

Please report any bugs or feature requests to C<bug-test-rest at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-Rest>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::Rest


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Test-Rest>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Test-Rest>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Test-Rest>

=item * Search CPAN

L<http://search.cpan.org/dist/Test-Rest/>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2010 Keith Grennan, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of Test::Rest
