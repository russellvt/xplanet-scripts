package Hans2::Constants;

=head1 NAME

Hans2::Constants - constants

=head1 COPYRIGHT

Copyright 2003 Hans Ecke hans@ecke.ws under the terms of the GNU Library General Public License

=head1 SYNPOSIS

   use Hans2::Constants;
   print "Im made by $author_mail\n";

=head1 DESCRIPTION

Some constants shared by all programs. This is the one place to set those constants.
See source for details.

=cut

use strict;

BEGIN {
        use Exporter   ();
        use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS @EXP_VAR @NON_EXPORT);

#        $Exporter::Verbose=1;
        # set the version for version checking
        $VERSION     = 1.00;
        # if using RCS/CVS, this may be preferred
#        $VERSION = do { my @r = (q$Revision: 2.21 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };
        # The above must be all one line, for MakeMaker

        @ISA         = qw(Exporter);

        @EXP_VAR     = qw(
                           $author_email
                           $author_name
                           $homepage
                           );
        @EXPORT      = (qw(
                           ),@EXP_VAR);
        @NON_EXPORT  = qw(
                           );
        @EXPORT_OK   = qw();
        %EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],
        
}        

# exported variables
use vars      @EXP_VAR;
# exportable variables
use vars      @EXPORT_OK;
#non exported package globals
use vars      @NON_EXPORT;

END {}

1;
