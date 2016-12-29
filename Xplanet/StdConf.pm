package Xplanet::StdConf;

=head1 NAME

Xplanet::StdConf - shared configuration variable specifications

=head1 COPYRIGHT

Copyright 2002 Hans Ecke under the terms of the GNU General Public Licence

=head1 DESCIRPTION

Some configuration keys for L<Hans2::OneParamFile> are used the same by
many programs. Here their definition is shared for all xplanet scripts.

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
                          $ONEPARAMFILE_DIR_OPTS       %ONEPARAMFILE_DIR_OPTS
                          $ONEPARAMFILE_METRIC_OPTS    %ONEPARAMFILE_METRIC_OPTS
                          $ONEPARAMFILE_US_OPTS        %ONEPARAMFILE_US_OPTS
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

use Hans2::FindBin;
use Hans2::OneParamFile;

$ONEPARAMFILE_DIR_OPTS='XPLANET_DIR';
%ONEPARAMFILE_DIR_OPTS=(
         'comment'  => [
            'The main xplanet installation directory, with the markers/ subdirectory for',
            'marker files, the images/ subdirectory for map images etc.',
            "",
            "If the environment variable XPLANET_DIR is set, its value overrides what you write down here.",
                       ],
         'default'  => $Bin,
         'env'      => 'XPLANET_DIR',
         'nr'       => $Hans2::OneParamFile::general_nr,
         );

$ONEPARAMFILE_METRIC_OPTS='METRIC';
%ONEPARAMFILE_METRIC_OPTS=(
         'comment'  => [
            'Whether we use metric units',
            '   1 -> use metric (SI) units, i.e. km and Celsius',
            '   0 -> use imperial (standard) units, i.e. miles and Fahrenheit',
                       ],
         'default'  => 0,
         'env'      => 'XPLANET_METRIC',
         'nr'       => $Hans2::OneParamFile::general_nr+1,
         );

$ONEPARAMFILE_US_OPTS='US';
%ONEPARAMFILE_US_OPTS=(
         'comment'  => [
            'Whether we are located inside the United States',
            '   1 -> we are inside the US',
            '   0 -> we are not inside the US',
                       ],
         'default'  => 1,
         'env'      => 'XPLANET_US',
         'nr'       => $Hans2::OneParamFile::general_nr+2,
         );

END {}

1;
