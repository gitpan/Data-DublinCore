# Copyrights 2009-2010 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 1.06.
use warnings;
use strict;

package Data::DublinCore;
use vars '$VERSION';
$VERSION = '0.03';

use base 'XML::Compile::Cache';
our $VERSION = '0.01';

use Log::Report 'data-dublincore', syntax => 'SHORT';

use XML::Compile::Util  qw/type_of_node unpack_type pack_type SCHEMA2001/;
use XML::LibXML::Simple qw/XMLin/;


use Data::DublinCore::Util;
use XML::Compile::Util  qw/XMLNS/;

# map namespace always to the newest implementation of the protocol
my $newest     = '20080211';
my %ns2version = (&NS_DC_ELEMS11 => $newest);

my %info =
  ( 20020312 => {}
  , 20021212 => {}
  , 20030402 => {}
  , 20060106 => {}
  , 20080211 => {}
  );

# there are no other options yet
my @prefixes =
  ( dc      => NS_DC_ELEMS11
  , dcterms => NS_DC_TERMS
  , dcmi    => NS_DC_DCMITYPE
  , xml     => XMLNS
  );

#----------------


sub new($)
{   my $class = shift;
    $class->SUPER::new(direction => 'RW', @_);
}

sub init($)
{   my ($self, $args) = @_;
    $args->{allow_undeclared} = 1
        unless exists $args->{allow_undeclared};

    my $r = $args->{opts_readers};
    $r = @$r if ref $r eq 'ARRAY';
    $r->{mixed_elements}  = 'XML_NODE';
    $r->{any_type}        = sub { $self->_handle_any_type(@_) };
    $args->{opts_readers} = $r;

    $args->{any_element} ||= 'ATTEMPT';

    $self->SUPER::init($args);

    my $version = $args->{version} || $newest;

    unless(exists $info{$version})
    {   exists $ns2version{$version}
            or error __x"DC version {v} not recognized", v => $version;
        $version = $ns2version{$version};
    }
    $self->{version} = $version;
    my $info = $info{$version};

    $self->prefixes(@prefixes);
    $self->addKeyRewrite('PREFIXED(dc,xml,dcterms)');

    (my $xsd = __FILE__) =~ s!\.pm!/xsd!;
    my @xsds;
    if($version lt 2003)
    {   @xsds = glob "$xsd/dc$version/*";
    }
    else
    {   @xsds = glob "$xsd/dc$version/{dcmitype,dcterms,dc}.xsd";

        # tricky... the application will load the following two,
        # specifying the targetNamespace.  Use with
        #   $self->importDefinitions('qualifieddc', target_namespace => );
        $self->knownNamespace($_ => "$xsd/dc$version/$_.xsd")
            for qw/qualifieddc simpledc/;
    }

    $self->importDefinitions(\@xsds);
    $self->importDefinitions(XMLNS);

    $self;
}

sub _handle_any_type($$$)
{   my ($self, $path, $node, $default_handler) = @_;
    my $r = $default_handler->($path, $node);

    # convert unknown anyType element structure into something
    my $v = ref $r ? XMLin($r) : $r;

    if(ref $node)
    {   if(my $attrn = $node->getAttributeNodeNS(XMLNS, 'lang'))
        {   ref $v eq 'HASH' or $v = { _ => $v };
            $v->{'xml:lang'} = $attrn->value;
        }
    }

    $v;
}


# Business::XPDL shows how to create conversions here... but all
# DC versions are backwards compatible
sub from($@)
{   my ($thing, $source, %args) = @_;

    my $xml  = XML::Compile->dataToXML($source);
    my $top  = type_of_node $xml;
    my ($ns, $topname) = unpack_type $top;
    my $version = $ns2version{$ns}
       or error __x"unknown DC version with namespace {ns}", ns => $ns;

    my $self = ref $thing ? $thing : $thing->new(version => $version);
    my $r    = $self->reader($top, %args)
        or error __x"root node `{top}' not recognized", top => $top;

    ($top, $r->($xml));
}


sub version()   {shift->{version}}
sub namespace() {shift->{namespace}}

1;
