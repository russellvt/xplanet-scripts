package Hans2::Screensize;

=head1 NAME

Hans2::Screensize - determine the screensize

=head1 COPYRIGHT

Copyright 2003 Hans Ecke hans@ecke.ws under the terms of the GNU Library General Public License

=head1 SYNOPSIS

   use Hans2::Screensize;

   my $string=geometry();  # something like "1024x768"

=head1 DESCRIPTION

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
                         &geometry
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

use filetest 'access';

use Hans2::System;
use Hans2::OneParamFile;

my $ONEPARAMFILE_GEOMETRY_OPTS='GEOMETRY';
my %ONEPARAMFILE_GEOMETRY_OPTS=(
         'comment'  => [
            'The size of your screen, something like 1280x1024',
            '',
            'For Unix: If an X-Display is set via the DISPLAY variable, we will try',
            'to determine its screen size and use it instead of the value of this option.',
            'If you do not like this autodetection, make sure the DISPLAY environment',
            'variable is not set when the script is being run.',
            ],
         'default'  => '1280x1024',
         'nr'       => $Hans2::OneParamFile::general_nr + 7,
         );

register_param($ONEPARAMFILE_GEOMETRY_OPTS,%ONEPARAMFILE_GEOMETRY_OPTS);

=head2 C<geometry()>

Returns a geometry string C<NNNxNNN> like C<1024x768> or undefined

If in a Unix-X11 environment, the geometry is determined from the active
display which is in the DISPLAY environment variable and needs to be accessible
for this process.

If no X11 is available, the geometry is taken from the configuration file, if available.

=cut

sub geometry() {
   return find_x11_geometry() || $PARAMS{$ONEPARAMFILE_GEOMETRY_OPTS};
   }

END {}

1;
