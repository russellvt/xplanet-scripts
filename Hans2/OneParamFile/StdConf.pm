package Hans2::OneParamFile::StdConf;

=head1 NAME

Hans2::OneParamFile::StdConf - shared configuration variable specifications

=head1 COPYRIGHT

Copyright 2003 Hans Ecke hans@ecke.ws under the terms of the GNU Library General Public License

=head1 DESCIRPTION

Some configuration keys for L<Hans2::OneParamFile> are used the same by
many programs. Here their definition is shared for all scripts.

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
                          $ONEPARAMFILE_TMPDIR_OPTS    %ONEPARAMFILE_TMPDIR_OPTS
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

$ONEPARAMFILE_TMPDIR_OPTS='TMPDIR';
%ONEPARAMFILE_TMPDIR_OPTS=(
         'comment'  => [
            'A directory for temporary files.',
            'If the TMP or TEMP environment variables are set, they point to the temporary storage.',
                       ],
         'default'  => $Bin,
         'env'      => ['TMP','TEMP','TMPDIR'],
         'nr'       => $Hans2::OneParamFile::general_nr+6,
         );

END {}

1;
