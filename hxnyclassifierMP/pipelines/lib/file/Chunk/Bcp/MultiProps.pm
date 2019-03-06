package file::Chunk::Bcp::MultiProps;
################################################################################
#
#				Required Modules
#
################################################################################

use strict;

use Pod::Usage;

use util::Constants;

use base 'file::Chunk::Bcp';

################################################################################
#
#				 Public Methods
#
################################################################################

sub new {
  my ( $that, $directory, $file_ord, $error_mgr ) = @_;
  my file::Chunk::Bcp::MultiProps $this =
    $that->SUPER::new( $directory, $file_ord, '~,~', '~.~', $error_mgr );

  return $this;
}

################################################################################

1;

__END__

=head1 NAME

MultiProps.pm

=head1 SYNOPSIS

This concrete class provides the mechanism to chunk a file
where the field separator is '~,~' and the line separator is
'~.~'' into smaller chunks for processing and is subclass of
L<file::Chunk::Bcp>.  Each line is an entity if it is not empty or
just whitespace.  The file order names the columns of the
'~,~'-separated line and is used to define the entities generated by the
class.

=head1 METHODS

The following methods are exported from the class.

=head2 B<new file::Chunk::Bcp::MultiProps(directory, file_order, error_mgr)>

This is the constructor of the class and requires the entity_tag that
defines the top-level tag for tab-separated file data.  Also, the
directory is where the chunks will be generated.  The constructor set
the size to 5000 defined rows.  The construct sets the file order
using the reference non-empty array B<file_order>.

=cut
