package Hans2::File;

=head1 NAME

Hans2::File - A collection of file-oriented functions that are platform independant

=head1 COPYRIGHT

Copyright 2003 Hans Ecke hans@ecke.ws under the terms of the GNU Library General Public License

=head1 SYNPOSIS

   use Hans2::File;

   test_file_really_accessible($filename) || die "could not access file $filename\n"

   my $ext=file_extension($filename);

   make_link($src,$dest) || die "could not link $src to $dest. Even tried plain copy.\n";
   copy_file($src,$dest) || die "could not copy $src to $dest\n";

   my $file_modification_time=mtime($filename);
   my $file_perms=file_perms($filename);

   writefile($filename,$content) || die "could not create/overwrite $filename\n";
   my $content=readfile($filename); 
   defined $content || die "could not read $filename\n";

   make_directory($dirname) || die "could not create directory $dirname\n"

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
                         &test_file_really_accessible
                         &file_extension
                         &make_link
                         &copy_file
                         &mtime
                         &file_perms
                         &writefile
                         &readfile
                         &make_directory
                         &perlre_glob
                         &my_glob
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

use Hans2::FindBin;

use POSIX qw(locale_h strtod);
use File::Basename;
use File::Spec;
use File::Copy;
use Fcntl;
use filetest 'access';

use Hans2::Cwd;
use Hans2::Util;
use Hans2::Debug;
use Hans2::DataConversion;

my $filetest_ops_work_correctly=0;

=head2 C<test_file_really_accessible($filename)>

Test that a file is accessible: test -f, -r and -w
Also test by opening the file for reading and appending (non-destructive).

This is necessary since the -f, -r, -w don't always work correctly under Windows

=cut

sub test_file_really_accessible($) {
   my ($fn)=@_;
   (-f $fn) || return 0;
   (-r $fn) || return 0;
   (-w $fn) || return 0;
   (-s $fn) || return 0;
   return 1 if $filetest_ops_work_correctly;
   local *F;
   open(F,'< '.$fn) || return 0;
   close(F) || return 0;
   local *F2;
   open(F2,'>> '.$fn) || return 0;
   close(F2) || return 0;
   return 1;
}   

=head2 C<file_extension($filename)>

file extension B<with> leading . (dot)

This is a wrapper around File::Basename::fileparse(), but
it hardcodes a reasonable extension-pattern.

=cut

sub file_extension($) {
   my ($fn)=@_;
   return (fileparse($fn,qr/\.\w{2,4}/))[2];
}   

=head2 C<copy_file($src,$dest)>

Copy $src to $dest, preserving permissions.

Is a wrapper around File::Copy::syscopy() with more error checking.

=cut

sub copy_file($$) {
   my ($src,$dest)=@_;
   my $perm=file_perms($src);
   unlink($dest) if -e $dest or -l $dest;
   die "could not delete $dest\n" if -e $dest or -l $dest;
   my $ret=File::Copy::syscopy($src,$dest);
   warn "could not copy $src to $dest: $!\n" if !$ret;
   $ret &&= chmod($perm,$dest);
   return $ret;
}      

=head2 C<make_link($src,$dest)>

Make a link from $src to $dest B<if> symlinks are available. Otherwise just copy
$src to $dest. Unfortunately hard links as a alternative to symlinks are much
less portable than simple copying.

=cut


$Hans2::Debug::off=1;
my $symlink_exists = (eval { symlink("",""); 1 }) || 0;
$Hans2::Debug::off=0;
writedebug("symlink exists: $symlink_exists");
sub make_link($$) {
   my ($src,$dest)=@_;
   writedebug("trying to link $src to $dest");
   my $ret=1;
   my $dir=getcwd();
   $ret &&= chdir(dirname($dest));
   $ret &&= unlink($dest) if -e $dest or -l $dest;
   die "could not delete $dest\n" if -e $dest or -l $dest;
   if($symlink_exists) {
      $ret &&= symlink($src,$dest);
      if(!$ret) {
         writedebug("could not link $src to $dest, trying copy");
         $ret &&= copy_file($src,$dest);
         }
      }
   else {      
      $ret &&= copy_file($src,$dest);
      }
   $ret &&= chdir($dir);
   return $ret;   
}   

=head2 C<mtime($filename)>

Gives back the modification time of the file

=cut

sub mtime($) {
   my ($fn)=@_;
#     ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
#     $atime,$mtime,$ctime,$blksize,$blocks)
   my $time=(stat($fn))[9];
   return undef if !-e $fn;
   return $time;
}       

=head2 C<file_perms($filename)>

Gives back the file permissions.
I<This is an octal number!> To convert 420 to "644", do something like

   $mode_string=sprintf("%04o",$mode)

=cut

sub file_perms($) {
   my ($fn)=@_;
#     ($dev,$ino,$moade,$nlink,$uid,$gid,$rdev,$size,
#     $atime,$mtime,$ctime,$blksize,$blocks)
   my $mode = (stat($fn))[2];
   if(!-e $fn) {
      writedebug("could not get the perms of $fn because its not existing");
      return undef;
      }
   if(!defined $mode) {   
      writedebug("could not stat $fn");
      return undef;
      }   
   $mode=Fcntl::S_IMODE($mode);   
   return $mode;
}       

=head2 C<make_directory($dirname)>

mkdir, but also creates parent directories

out: 1 - success or already there
     0 - could not create

=cut

sub make_directory($) {
   my ($target)=@_;

   -f $target && return undef;
   -d $target && return 1;
   
   my ($volume,$directories,$file) = File::Spec->splitpath($target,1);
   my @dirs = File::Spec->splitdir( $directories );

   my @these_dirs=();
   foreach(@dirs) {
      push @these_dirs,$_;
      my $dir = File::Spec->catpath( $volume, File::Spec->catdir( @these_dirs), "");
      if(!-d $dir) {
         writedebug("mkdir $dir");
         mkdir($dir) || return undef; 
         }
      }

   return 1;
}   

=head2 C<readfile($filename)>

reads file into memory and returns contents

out: if array wanted : array of lines, without \n
                       empty array if problem
     if scalar wanted: content of file as scalar
                       undef if problem

=cut

sub readfile($) {
   my ($fn)=@_;
   local *F;
   if(!open(F,$fn)) {
      writedebug("could not open $fn: $!");
      return wantarray() ? () : undef;
      }
   writedebug("reading $fn");
   my $txt;
   my @txt;
   if(wantarray()) {
      while(<F>) {
         chomp;
         push @txt,$_;
         }
      }
   else {      
      while(<F>) {
         $txt.=$_;
         }
      }
   close F;   
   return wantarray() ? @txt : $txt;
}      

=head2 C<writefile($filename,$content)>

writes file, creates directory if necessary

out: undef - error
     1     - success

=cut

sub writefile($$) {
   my ($fn,$txt)=@_;
   local *F;
   my $dir=dirname($fn);
   if(!-d $dir) {
      if(!make_directory($dir)) {
         writedebug("could not create $dir");
         return undef;
         }
      }   
   if(!open(F,'>',$fn)) {
      writedebug("could not write to $fn: $!");
      return undef;
      }
   writedebug("writing $fn");   
   print F $txt;
   close F;
   return 1;
}         

=head2 C<@list=perlre_glob($dir,$pattern;$validator)>

Returns all files inside $dir that match $pattern in a perl-regex style.

As an example, here is a translation between old-style glob() and this perlre_glob:

   Old-Style     Perlre
   *.pl          .*\.pl$
   w*            ^w
   *             .

$validator is an optional func-ref that specifies a condition each file needs to pass
in order to be returned. Something like C<sub {-f $_ and -r $_}> returns only
readable files.

=cut

sub perlre_glob($$;$) {
   my ($dir,$pattern,$validator)=@_;
   
   return if !defined $pattern;
   return if $pattern eq '';
   
   my @files;
   
   local *DIR;
   opendir(DIR,$dir) || die "can not opendir $dir: $!\n";
   @files = readdir(DIR);
   closedir DIR;
   
   $pattern=qr/$pattern/;
   
   @files=grep {($_ ne ".") and ($_ ne "..")} @files;
   @files=grep {/$pattern/} @files;
   @files=map  {File::Spec->catfile($dir,$_)} @files;
   
   @files=grep {$validator->($_)} @files if (defined $validator) and 
                                            (ref($validator)) and 
                                            (ref($validator) eq 'CODE');
   
   return @files;
}   
   
=head2 C<@list=my_glob($dir,$pattern;$validator)>

Like perlre_glob, except that it accepts conventional globbing patterns 
like C<*.pl> or C<m*.exe>

Why should you use this instead of the builtin glob() function? Core glob()
is not portable at all. It happens to work for most Unix systems, but
will not work for Windows much of the time.

=cut

sub my_glob($$;$) {
   my ($dir,$pattern,$validator)=@_;
   
   return perlre_glob($dir,fileglob_2_perlre($pattern),$validator);
   
}

END {}

1;
