package Xplanet::Constants;

=head1 NAME

Xplanet::Constants - shared constants pertaining to xplanet scripts.

=head1 COPYRIGHT

Copyright 2002 Hans Ecke under the terms of the GNU General Public Licence

=head1 DESCIRPTION

See the module source for specifica.

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

use File::Spec;

use Hans2::UpdateMyself;
use Hans2::Constants;

my $dl_base="http://hans.ecke.ws/xplanet/";
my $current_versions_file="${dl_base}current_versions.lst";

$Hans2::UpdateMyself::dl_base               = $dl_base;
$Hans2::UpdateMyself::current_versions_file = $current_versions_file;

$Hans2::Constants::author_email             = 'hans@ecke.ws';
$Hans2::Constants::author_name              = 'Hans Ecke';
$Hans2::Constants::homepage                 = 'http://hans.ecke.ws/xplanet';



END {}

1;
