package Hans2::Util;

=head1 NAME

Hans2::Util - miscellaneous functions and variables

=head1 COPYRIGHT

Copyright 2003 Hans Ecke hans@ecke.ws under the terms of the GNU Library General Public License

=head1 SYNOPSIS

   $I_am_interactive
   $in_windows
   $in_cygwin
   my @dirs = split($PATH_CONCAT,$ENV{'PATH'});
   print "please quit input with an $EOF_CHAR_WRITTEN\n";  # "^Z" on Windows, "^D" on Unix

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
                         $I_am_interactive
                         $in_windows
                         $in_cygwin
                         $PATH_CONCAT
                         $EOF_CHAR_WRITTEN
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

use POSIX qw(locale_h strtod);
use File::Basename;
use File::Spec;
use Config;
use filetest 'access';

use Hans2::FindBin;
use Hans2::Cwd;
use Hans2::Debug;

=head2 exported variables

C<$in_windows> : Whether we are running under Windows

C<$in_cygwin>  : Whether we are running under CygWin

C<$PATH_CONCAT>: The character between individual directories in variables like C<$ENV{'PATH'}>

C<$EOF_CHAR_WRITTEN> : A written representation of the EOF character. Usefull for talking to the user.

C<$I_am_interactive> : Whether STDIN and STDOUT are terminals. I believe this definition is best, since it allows tools like L<Expect> to work.

=cut

$in_windows= ( $^O =~ /win/i    ? 1 : 0);
$in_cygwin = ( $^O =~ /cygwin/i ? 1 : 0);

$PATH_CONCAT=$Config{'path_sep'};

$EOF_CHAR_WRITTEN="^D";
$EOF_CHAR_WRITTEN="^Z" if $in_windows;


writedebug(File::Spec->catfile($Bin,$Script)." called from ".getcwd());
if($in_windows) {
   writedebug("Windows environment detected");
   }
else {
   writedebug("Non-windows environment detected");
   }
if($in_cygwin) {
   writedebug("Cygwin environment detected");
   }
else {
   writedebug("Non-cygwin environment detected");
   }

# from perl recipes
#
# returns true if we read from a file or redirection or are called by cron
sub I_am_interactive() {
   return -t STDIN && -t STDOUT;
}
$I_am_interactive=I_am_interactive();

END {}

1;
