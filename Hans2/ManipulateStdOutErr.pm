package Hans2::ManipulateStdOutErr;

=head1 NAME

Hans2::ManipulateStdOutErr - manipulate STDOUT and STDERR

=head1 COPYRIGHT

Copyright 2003 Hans Ecke hans@ecke.ws under the terms of the GNU Library General Public License

=head1 SYNOPSIS

   # simulate backticks
   ($stdout,$exitvalue)=wrap_filedescs(sub {system("cat /etc/passwd")},\*STDOUT,"STDOUT")

   # catch STDERR 
   ($stderr,$stdout)=wrap_filedescs(sub {`cat /etc/passwd`},\*STDERR,"STDERR")

   # attach external program 
   add_output_filter("/bin/pr")

   # attach internal filter function
   add_output_filter(sub {while(<STDIN>){s/foo/bar/;print}})

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
                         &wrap_filedescs
                         &add_output_filter
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
use filetest 'access';

use Hans2::FindBin;
use Hans2::OneParamFile;
use Hans2::OneParamFile::StdConf;

=head2 C<($output,@return)=wrap_filedescs(\&execute,$filehandle,$filehandlename)>

&execute is the function that should be executed while $filehandle is under 
examination.

$filehandle and $filehandle name must
    * be a regular old perl file handle, like \*FILE or \*STDOUT
    * correspond to the same object, i.e. be \*STDOUT and "STDOUT"

out: Text that was printed to that filehandle while function was active.
     Return values of &execute.

=cut

sub wrap_filedescs($$$) {
   my ($func,$fh,$fhn)=@_;
   
   local $_;
   
   my $tmpdir=$PARAMS{$ONEPARAMFILE_TMPDIR_OPTS} || $Bin;
   my $fileno=fileno($fh) || int(rand(100));
   my $logf=File::Spec->catfile($tmpdir,"log.$Scriptbase.$fileno.$$");

   local *OLDERR;
   open(OLDERR,">&$fhn") or die "Can't dup $fhn: $!";
   close($fh);
   open($fh,">> $logf") || die "could not open $logf for writing\n";
   
   my @ret=$func->();
   
   close($fh);
   open($fh,">&OLDERR") or die "Can't dup OLDERR: $!";
   
   my $txt;
   local *LOG;
   open(LOG,$logf) || die "could not open $logf for reading\n";
   while(<LOG>) {
      $txt.=$_;
      }
   close(LOG);
   unlink($logf);
   
   my $log_short=$txt || "";
   $log_short =~ s/[\s\r\n]+//g;
   $txt="" if !$log_short;
   if($txt) {
      chomp $txt;
      $txt.="\n";
      }
   
   return ($txt,@ret);
}    

=head2 C<add_output_filter("program"> or C<add_output_filter(\&filter)>

in: a function reference or the name of an external program

action: attach this function (or program) to our stdout

function will get its input from STDIN and should write to its STDOUT

example: 

   # call out to external filter program:
   add_output_filter("/usr/bin/pr")

   # filter output stream inside perl: only output the first 20 lines
   add_output_filter( sub {
                      my $lines = 20;
                      while (<STDIN>) {   print;  last unless --$lines; }
                      }
                    )

=cut

sub add_output_filter($) {
   my ($func)=@_;
   if(!ref($func)) {
      my $program=$func;
      $func = sub { exec($program);};
      }
   die "Please give a function to add_output_filter, not $func (".ref($func).")\n" if !isfunction($func);
   my $pid;
   return if $pid = open(STDOUT, "|-");
   die "cannot fork: $!" if ! defined $pid;
   $func->();
   exit;   # if $func does not do it by itself....
}

   
END {}

1;
