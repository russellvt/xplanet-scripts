package Hans2::Ascii::DataIterator;

=head1 NAME

Hans2::Ascii::DataIterator - access Hans2::Ascii::Data objects row-wise

=head1 COPYRIGHT

Copyright 2003 Hans Ecke hans@ecke.ws under the terms of the GNU Library General Public License

=head1 SYNOPSIS

   my $iter=Hans2::Ascii::DataIterator->new(
               Hans2::Ascii::Data->read("file.asc")
            );
   while($iter) {
      process_row(<$iter>);
      }

=head1 DESCRIPTION

=cut

use strict;


BEGIN {
        use Exporter   ();
        use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS @EXP_VAR @NON_EXPORT);

#        $Exporter::Verbose=1;
        # set the version for version checking
        $VERSION     = 1.1;
        # if using RCS/CVS, this may be preferred
#        $VERSION = do { my @r = (q$Revision: 2.21 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };
        # The above must be all one line, for MakeMaker

        @ISA         = qw(Exporter);

# export variables
        @EXP_VAR     = qw(
                           );
# export functions
        @EXPORT      = (qw(
                           &noasciidataiterator
                           ),@EXP_VAR);
# non export variables
        @NON_EXPORT  = qw(
                           );
# optional export variables
        @EXPORT_OK   = qw();
        %EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],
        

        
}        

# exported variables
use vars      @EXP_VAR;
# exportable variables
use vars      @EXPORT_OK;
#non exported package globals
use vars      @NON_EXPORT;

use Hans2::Util;
use Hans2::Units;
use Hans2::StringNum;
use Hans2::Ascii::Data;
use Hans2::Ascii::Param;

use overload 'bool' => \&not_at_end,
             '<>'   => \&next;

sub _that_row($$) {
   my ($self,$pos)=@_;
   my @row;
   
   foreach my $head ($self->{'data'}->headers()) {
      push @row,$self->{'data'}->x($head,$pos);
      }
   
   return @row;
   
}

sub _that($$) {
   my ($self,$pos)=@_;
   my %param;
   my %order;
   my $order_pos=0;
   
   foreach my $head ($self->{'data'}->headers()) {
      my $num = $self->{'data'}->x($head,$pos);
      my $unit= $self->{'data'}->unit($head);
      if(defined $unit) {
         $param{$head}=[$num,$unit];
         }
      else {
         $param{$head}=$num;
         }   
      $order{$head}=$order_pos++;   
      }
   
   my $param=Hans2::Ascii::Param->new_full(\%param,\%order);
   
   return $param;
   
}

=head2 C<bool=noasciidataiterator($unknown_scalar)>

the only non-method in here

return 1 if this is not an iterator

return 0 otherwise

=cut

sub noasciidataiterator($) {
   my ($data)=@_;
   return 1 if ! $data;
   return 1 if ! ref($data);
   return 1 if ! $data->isa("Hans2::Ascii::DataIterator");
   return 0;
}   
   
=head2 C<$iter=Hans2::Ascii::DataIterator-E<gt>new($ascii)>

construct a new iterator from an Hans2::Ascii::Data object

=cut

sub new($$) {
   my ($proto,$asc)=@_;
   
   die "Hans2::Ascii::DataIterator::new was not given a Hans2::Ascii::Data object\n" 
      if noasciidata($asc);
   
   my $class = ref($proto) || $proto;
   my $self  = {
          'data'   => $asc,
          'pos'    => 0,              # points to next element to read
          'length' => $asc->length(),
          };
   bless ($self, $class);
   
   return $self;
}

=head2 C<$iter-E<gt>goto($pos)>

position pointer at $pos (0-counted)

=cut

sub goto($$) {
   my ($self,$pos)=@_;
   
   die "trying to move Ascii::DataIterator to position $pos when end is at ".$self->{'length'}."\n"
      if $pos>=$self->{'length'};
   $self->{'pos'}=$pos;
}

=head2 C<@headers=$iter-E<gt>headers()>

returns the array of headers

=cut

sub headers($) {
   my ($self)=@_;
   return $self->{'data'}->headers();
}

=head2 C<@units=$iter-E<gt>units()>

returns the array of units

=cut

sub units($) {
   my ($self)=@_;
   return $self->{'data'}->units();
}

=head2 C<@row=$iter-E<gt>next_row()>

returns this row as an array of numbers, and then advances one step forward

   foreach my $num ($iter->next_row()) {
      }

=cut

sub next_row($) {
   my ($self)=@_;

   my $pos=$self->{'pos'};
   $self->{'pos'}++;
   
   return $self->_that_row($pos);
   
}

=head2 C<@row=$iter-E<gt>here_row()>

like next_row(), but stays at the current position

=cut

sub here_row($) {
   my ($self)=@_;

   return $self->_that_row($self->{'pos'});
   
}

=head2 C<$row=E<lt>$iterE<gt>> or C<$row=$iter-E<gt>next()>

returns this row as an Ascii::Param object and then advances one row forward

   my $row=<$iter>;
   my $pp=$row->getx('pp','psi');

=cut

sub next($) {
   my ($self)=@_;

   my $pos=$self->{'pos'};
   $self->{'pos'}++;
   
   return $self->_that($pos);
   
}

=head2 C<$row=$iter-E<gt>here()>

like next(), but stays at current position

=cut

sub here($) {
   my ($self)=@_;

   return $self->_that($self->{'pos'});
   
}

=head2 C<while($iter)> or C<bool=$iter-E<gt>not_at_end()>

whether we still have some data left.

=cut

sub not_at_end($) {
   my ($self)=@_;
   return $self->{'pos'} != $self->{'length'};
}   
   
=head2 C<bool=$iter-E<gt>at_end()>

whether we are at the end. 

Calls to next*() will return the empty array after at_end() returns true.

=cut

sub at_end($) {
   my ($self)=@_;
   return $self->{'pos'} == $self->{'length'};
}   
   
END { }

=head1 SEE ALSO

L<Hans2::Ascii::Data>

L<Hans2::Ascii::Param>

=cut

1;

