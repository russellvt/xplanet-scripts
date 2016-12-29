package Hans2::FindBin;

=head1 NAME

Hans2::FindBin - Cross-platform support for The standard L<FindBin> module and L<File::Basename>::abs2rel()

=head1 COPYRIGHT

Copyright 2003 Hans Ecke hans@ecke.ws under the terms of the GNU Library General Public License

=head1 SYNOPSIS

   use Hans2::FindBin;

   print "We are script $Script, located in $Bin (which really is $RealBin)\n";
   print "Without extension, scriptname is $Scriptbase\n";

   # prints "images\insets\west_north\f.jpg"
   print abs2rel("C:\xplanet\images\insets\west_north\f.jpg","C:\xplanet")."\n";  

=head1 DESCRIPTION

=head2 C<$Bin, $RealBin, $Script>

The standard L<FindBin> module is very usefull to create relocatable scripts.

Unfortunately the variables $FindBin::Bin, $FindBin::Script and $FindBin::RealBin 
are 100% correct only on Unix: on other platforms they are slightly misformed,
for instance under Windows, paths might contain slashes / instead of
backslashes.

Here they are identical to the versions in L<FindBin>, except that
they have been sanitized by File::Spec->canonpath() and are B<exported by default>.

=head2 C<abs2rel($path,$base)>

This is a version of File::Basename::abs2rel() that works also under Windows.

=head2 C<$Scriptbase>

This is a variable identical to $Script with the file extension stripped off.

This is usefull for cross-plattform development: Under Unix, your script 
might be called just "script". Under Windows, it might be "script.pl". Compiled
with some sort of perlcompiler, it might be "script.exe". Never assume your script 
will have a particular extension!

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
                          $Bin
                          $RealBin
                          $Script
                          $Scriptbase
                           );
        @EXPORT      = (qw(
                           &abs2rel
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

use FindBin;
use File::Spec;
use File::Basename;

$Bin = File::Spec->canonpath($FindBin::Bin);
$RealBin = File::Spec->canonpath($FindBin::RealBin);
$Script = $FindBin::Script;
$Scriptbase = $Script;
$Scriptbase = (fileparse($Script,qr/\.\w{2,4}/))[0];

sub abs2rel($$) {
   my ($path,$base)=@_;
   return $path if !File::Spec->file_name_is_absolute($path);
   $path=File::Spec->abs2rel($path,$base);
   my ($volume,$directories,$file) = File::Spec->splitpath($path);
   return $file if !$directories;
   return File::Spec->catfile($directories,$file);
}   

END {}

1;
