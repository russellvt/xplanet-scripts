package Hans2::Ascii::Data;

=head1 NAME

Hans2::Ascii::Apply - Apply functions to each row of an Hans2::Ascii::Data object

=head1 COPYRIGHT

Copyright 2003 Hans Ecke hans@ecke.ws under the terms of the GNU Library General Public License

=head1 SYNOPSIS

   use Hans2::Ascii::Data;
   use Hans2::Ascii::Apply;
   my $data=Hans2::Ascii::Data->read("file.asc");
   my $data->apply(&func);
   my $new_data=$data->applied(&func2);

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

use Hans2::Ascii::Data;
use Hans2::Ascii::DataIterator;

=head2 C<$data-E<gt>apply(&func)>

Applies the function to each row of the table.

The function receives each row as a Hans2::Data::Param object
and modifies it however it likes.

=cut

sub apply($$) {
   my ($self,$func)=@_;
   $new=$self->applied($func);
   $self=undef;
   $_[0]=undef;   
   $_[0]=$new;   
}   

=head2 C<$newdata=$data-E<gt>applied(&func)>

Returns a new table as a transformation with &func.

The function receives each row as a Hans2::Data::Param object
and modifies it however it likes.

=cut

sub applied($$) {
   my ($self,$func)=@_;
   ref($func)        || die;
   ref($func)='CODE' || die;
   my $iter=Hans2::Ascii::DataIterator->new($self);
   my @newrows;
   while($iter) {
      my $row=<$iter>;
      $func->($row);
      push @newrows,$row;
      }
   return Hans2::Ascii::Data->from_params(@newrows);   
}   
   
   
END { }

=head1 SEE ALSO

L<Hans2::Ascii::Data>

L<Hans2::Ascii::Param>

=cut

1;

