package Hans2::System;

=head1 NAME

Hans2::System - platform dependant functions about executing programs

=head1 COPYRIGHT

Copyright 2003 Hans Ecke hans@ecke.ws under the terms of the GNU Library General Public License

=head1 SYNOPSIS

   my $pager=find_exe_in_path("more");  # returns path and filename of "more" or "more.exe"
   my $is_executable=hyphen_x("script.pl")
   my $dir=find_file("sendmail.cf","/etc","/etc/mail"); 

   my $success=my_system("script.pl",'working_dir'=>'/');
   my $mounts=my_backquote("mount");

   exec_myself();
   my $geom=find_x11_geometry();

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
                         &find_exe_in_path
                         &normalize_path
                         &hyphen_x
                         &find_file
                         &my_system
                         &run_nice_if
                         &my_backquote
                         &exec_myself
                         &find_x11_geometry
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
use filetest 'access';

use Hans2::FindBin;
use Hans2::Cwd;
use Hans2::Units;
use Hans2::Math;
use Hans2::OneParamFile;
use Hans2::OneParamFile::StdConf;
use Hans2::Util;
use Hans2::File;
use Hans2::Debug;
use Hans2::Debug::Indent;
use Hans2::Constants;
use Hans2::ManipulateStdOutErr;
use Hans2::DataConversion;

# the caching needs some kind of tmpdir variable
register_param($ONEPARAMFILE_TMPDIR_OPTS,%ONEPARAMFILE_TMPDIR_OPTS);

$ENV{'PATH'}.=$PATH_CONCAT.$Bin.$PATH_CONCAT.$RealBin.$PATH_CONCAT.getcwd();

my $has_meaningfull_hyphen_x;
{
   my $_have_initialized=0;
   # returns exitvalue, not returned '$exit<<8'
   sub simple_system_quiet($) {
      my ($cmd)=@_;
      my ($stdout,$stderr,$ret)=wrap_filedescs(
         sub {
            wrap_filedescs(
                   sub {system($cmd)},
                   \*STDERR,
                   "STDERR"
                   );
              },
         \*STDOUT,
         "STDOUT"
         );          
      my $exit=$ret >> 8;
      $stdout =~ s/\s+/ /g;
      $stderr =~ s/\s+/ /g;
      writedebug("system($cmd) returned $ret($exit). \$?=$? \$!=$!. stderr=$stderr stdout=$stdout");
      return $exit;
   }
   sub initialize_interpreter_hyphen_x() {
      return if $_have_initialized;
      $_have_initialized=1;
      local $_;
      my $ind=Hans2::Debug::Indent->new("testing -x and interpreter support");
      my $tmpdir=$PARAMS{$ONEPARAMFILE_TMPDIR_OPTS} || $Bin;
      my $fn=File::Spec->catfile($tmpdir,"test.$Scriptbase.$$");
      
      # a random exit value we test against
      # unfortunately, Windows does not return '-1' if it can't execute a file.
      my $test_exit=27;
      
      local *F;
      open(F,"> $fn") || die "could not create $fn\n";
      print F "#!$^X -w\n";
      print F "exit $test_exit;\n";
      close F;
      chmod(0755,$fn);
      
      $has_meaningfull_hyphen_x  = 0;
      
      $has_meaningfull_hyphen_x  = 1 if -x $fn;
      
      die "could not execute $^X $fn\n" if simple_system_quiet(quote_fn($^X)." ".quote_fn($fn))!=$test_exit;
      if(!$DEBUG) {
         unlink($fn) || die "could not delete $fn\n";
         }
      writedebug("has meaningfull -x: $has_meaningfull_hyphen_x");
   }
}

{
# in: an executable file to find
# out: full pathname or false
sub find_exe_in_path_core($) {
   my ($file)=@_;
   return undef if !defined $file;
   return undef if $file eq "";
   # deal with absolute path
   if(File::Spec->file_name_is_absolute($file)) {    
      if((-f $file) && (hyphen_x($file))) {
         writedebug("absolute executable $file exists");
         return $file;
         }
      else {
         writedebug("absolute filename $file is not an executable");
         return undef;
         }   
      }
   # deal with relative path
   foreach my $dir (split($PATH_CONCAT,$ENV{'PATH'})) {   # try all elements of PATH
      next if !$dir;
      next if !-d $dir;
      my @pfiles=(File::Spec->catfile($dir,$file));
      if($file !~ /\.exe$/) {
         push @pfiles,File::Spec->catfile($dir,$file.".exe");
         }
      foreach(@pfiles) {   
         if((-f $_) && (hyphen_x($_))) {
            writedebug("found executable $file in $_");
            return $_;
            }
         }
      }   
   writedebug("did not find executable $file in $ENV{'PATH'}");
   return undef;
}   
my %_find_exe_in_path_cache;
my $_last_path="";

=head2 C<$fullname = find_exe_in_path($basename)>

in:  an executable file to find

out: full pathname or false

This also looks for $basename.exe to account for Windows. This is
not (yet) truly platform-independant.

Additionally, we cache. The cache invalidates if $PATH changes.
Therefore, repeated calls of this function with the same argument is
nearly as cheap as caching it locally.

=cut

sub find_exe_in_path($) {
   my ($file)=@_;
   return if !defined $file;
   return if $file eq '';
   my $this_path=$ENV{'PATH'};
   %_find_exe_in_path_cache=() if $this_path ne $_last_path;
   $_last_path=$this_path;
   return $_find_exe_in_path_cache{$file} if exists $_find_exe_in_path_cache{$file};
   my $path=find_exe_in_path_core($file);
   $_find_exe_in_path_cache{$file}=$path;
   return $path;
}   
}

=head2 C<$path = normalize_path($path;&validator)>

in:  an environment variable like $PATH 
     optional: 

out: the same PATH, but

     * with no double entries
     * the PATH CONCATENATOR (: under Unix, ; under Windows) only between
       elements and not at start or end of the string or double anywhere
     * if a validator function is given, take out all elements where 
       the function does not match

=cut

sub normalize_path($;$) {
   my ($path,$valid)=@_;
   for($path) {
      s/^$PATH_CONCAT+//;
      s/^$PATH_CONCAT+//;
      s/$PATH_CONCAT$PATH_CONCAT+/$PATH_CONCAT/g;
      my $i=1;
      my %p;
      foreach(split(/$PATH_CONCAT/)) {
         $p{$_}=$i++ if !$p{$_};
         }
      my @p=sort { $p{$a} <=> $p{$b} } keys %p;
      if($valid) {
         ref($valid) 
            || die "normalize_path(\"$path\",\"$valid\") called: second argument should be code-ref\n";
         ref($valid) eq 'CODE' 
            || die "normalize_path(\"$path\",\\".ref($valid).") called: second argument should be code-ref\n";
         @p=grep {$valid->()} @p;
         }
      return join($PATH_CONCAT,@p);   
      }
}

$ENV{'PATH'}=normalize_path($ENV{'PATH'});

=head2 C<$path = normalize_path_memoize($path;&validator)>

Like normalize_path(), except that it remembers results.

=cut

{
   my %_n_p_m_cache;
sub normalize_path_memoize($;$) {
   my ($path,$valid)=@_;
   return $_n_p_m_cache{$path,"$valid"} if exists $_n_p_m_cache{$path,"$valid"};
   my $npath=normalize_path($path,$valid);
   $_n_p_m_cache{$path,"$valid"}=$npath;
   return $npath;
}
}

=head2 C<$bool = hyphen_x($filename)>

This is different from the perl "C<-x>" in that it returns
whether this file is B<executable>, even if by an interpreter.

out: 
     Returns '-x $file' if not on windows.
     Returns heuristics of fileextension otherwise.

=cut

sub hyphen_x($) {
   my ($file)=@_;
   initialize_interpreter_hyphen_x();
   if($has_meaningfull_hyphen_x) {
      return (-x $file);
      }
   else {
      return ($file =~ /\.(?:exe|com|pif|sys|bat|pl|dpl)$/);
      }   
}

=head2 C<$dir = find_file($filename,@dirs)>

find readable file inside one of the dirs, return first dir where its found in
or undef if none

=cut

sub find_file($@) {
   my ($file,@dirs)=@_;
   foreach my $d (@dirs) {
      if((-f File::Spec->catfile($d,$file))&&(-r File::Spec->catfile($d,$file))) {
         return $d;
         }
      }
   return undef;
}     

my %known_interpreters=(
   '.exe'  => "",
   '.com'  => "",
   '.bat'  => "",
   '.pl'   => $^X,
   '.dpl'  => $^X,
   );

# in: executable name
# out: possible interpreter
#      ""       - none needed
#      undef    - unknown
#      <string> - interpreter
sub interpreter($) {
   my ($executable)=@_;
   my $ext=file_extension($executable);
   return $known_interpreters{$ext} if exists $known_interpreters{$ext};
   return;
}   

=head2 C<my_system($command,%options)> and C<my_backquote($command,%options)>

options hash:

        'executable'      -> actual file to execute
                             using this option is recommanded, since it enables
                             additional checks and the interpreter handling detailed below
        'working_dir'     -> directory where the command should be executed
        'interpreter'     -> if running in windows, this is the interpreter
                             if running in windows, we will also try to 
                               auto-detect needed interpreters
        'suppress_stdout' -> don't let the program's STDOUT to the TTY
                             if called by my_backquote and this otion is not specifically set to 0
                             it will default to 1
        'suppress_stderr' -> don't let the program's STDERR to the TTY
        'quiet'           -> don't output any warn messages, just return values

my_system(): returns true for success, false otherwise

my_backquote(): returns STDOUT of command, undef if error

All STDOUT and STDERR is also logged using Hans2::Debug.

=cut

# $doit: actual executing function which returns list of
#         * return value - opaque object that we should return
#         * flag whether we were successful
#         * optional error message
#         * optional STDOUT of process
sub my_execute($$;%) {
   my ($cmd,$doit,%opts)=@_;
   
   my $cwd;
   
   my $working_dir     = $opts{'working_dir'};
   my $suppress_stdout = $opts{'suppress_stdout'};
   my $suppress_stderr = $opts{'suppress_stderr'};
   my $quiet           = $opts{'quiet'};
   my $executable      = $opts{'executable'};
   
   my $msg="";
   
   foreach (sort keys %opts) {
      $msg.="$_=$opts{$_}; ";
      }
   $msg=" with opts $msg" if $msg;   
   my $ind=Hans2::Debug::Indent->new("trying to execute $cmd$msg from ".getcwd());

   if($working_dir) {
     die "trying to execute $cmd in non existing directory $working_dir\n" if ! -d $working_dir;
     $cwd=getcwd();
     chdir($working_dir);
     }
     
   if(!$executable) {
      # try heuristics to find executable, but don't force it  
      if($cmd =~ /^(\S+)/) {
         $executable=$1;
         $executable =~ s/"//g;
         $executable=undef if !find_exe_in_path($executable);
         }
      }
   else {   
      # make sure we really can find $executable
      $executable &&= find_exe_in_path($executable) || die "could not find $executable in PATH\n";
      }
   
   initialize_interpreter_hyphen_x();
   if($executable) {
      $opts{'interpreter'} = interpreter($executable) if !exists $opts{'interpreter'};
      my $int=$opts{'interpreter'};
      delete $opts{'interpreter'} if !$int;
      if($int) {
         find_exe_in_path($int) || die "Could not find $int in your path (needed to execute $cmd).\n";
         $cmd=quote_fn($int)." $cmd";
         }
      }
      
   my ($stderr,$ret,$success,$error_message,$stdout)=
       wrap_filedescs(sub {$doit->($cmd)},
                      \*STDERR,
                      "STDERR"
                      );
   
   chdir($cwd) if $working_dir;
   
   if(!$success) {
      my $msg="$cmd returned error";
      $msg.=": $error_message" if $error_message;
      if($quiet) {
         writedebug($msg);
         }
      else {
         warn "$msg\n";
         }   
      }
   else {
      writedebug($error_message) if $error_message;
      writedebug("...returned success");
      }   

   if($stdout) {
      if($suppress_stdout) {
         writedebug("STDOUT:\n".$stdout);
         }
      else {   
         writestdout($stdout);
         }
      }   
   if($stderr) {
      if($suppress_stderr) {
         writedebug("STDERR:\n".$stderr);
         }
      else {   
         writestderr($stderr);
         }
      }   

   return $ret;   
}

sub exit_2_msg($) {
   my ($exit)=@_;

   my $exit_value = $exit >> 8;
   my $signal_num = $exit & 127;
   my $dumped_core= $exit & 128;

   if($exit_value or $signal_num or $dumped_core) {
      my $msg="";
      $msg.="exit:$exit_value; "         if $exit_value;
      $msg.="signal:$signal_num; "       if $signal_num;
      $msg.="dumped_core:$dumped_core; " if $dumped_core;
      $msg =~ s/; $//;
      return $msg;
      }
   return undef;
}   

# in: command
# out: (return value, success-flag, message,stdout)
sub my_system_core($) {
   my ($cmd)=@_;
   
   my ($stdout,$ret,$msg)=
       wrap_filedescs(sub {
                         my $ret=system($cmd);
                         my $msg;
                         if($ret>=0) {
                            $msg=exit_2_msg($?);
                            }
                         else {
                            $msg="could not execute";
                            }   
                         $msg.=": $!" if $msg and $! and "$!";
                         return ($ret,$msg);
                         },
                      \*STDOUT,
                      "STDOUT"
                      );

   my $suc=1;
   $suc=0 if $ret!=0;
   $suc=0 if $msg;
      
   return ($suc,$suc,$msg,$stdout);
}   

# in: command
# out: (return value, success-flag, message,stdout)
sub my_backquote_core($) {
   my ($cmd)=@_;
   my $stdout=`$cmd`;
   my $msg=exit_2_msg($?);
   if($msg) {
      return (undef,0,$msg,$stdout);
      }
   else {   
      return ($stdout,1,"",$stdout);
      }
}   

# see my_execute for meaning of options
sub my_system($;%) {
   my ($cmd,%opts)=@_;
   return my_execute($cmd,\&my_system_core,%opts);
}

# see my_execute for meaning of options
sub my_backquote($;%) {
   my ($cmd,%opts)=@_;
   if(!exists $opts{'suppress_stdout'}) {
      $opts{'suppress_stdout'}=1;
      }
   return my_execute($cmd,\&my_backquote_core,%opts);
}

=head2 C<$success = run_nice_if($command,%options)>

Like my_system(), except that if "nice" is available and
DEBUG mode is not switched on, the command will be executed by nice,
thereby reducing its priority.

=cut

sub run_nice_if($;%) {
   my ($cmd,%opts)=@_;
   if($ENV{'DEBUG'} || !find_exe_in_path("nice")) {
      return my_system($cmd,%opts);
      }
   else {
      return my_system("nice -20 $cmd",%opts,'executable'=>'nice');
      }
   }   

=head2 C<exec_myself(;%options)>

re-execute this script

changes/reads environment: 

  Sets EXECMYSELF_<scriptbase> to the current time().
  If EXECMYSELF_<scriptbase> is set when this function is called, will die, 
     assuming programming error (infinite loop of re-executions?).

options:
  'no_check_env' => if set, don't check the above env var

=cut

sub exec_myself(;%) {
   my (%opts)=@_;
   
   my $self=File::Spec->catfile($Bin,$Script);
   if((!-f $self) or (!hyphen_x($self))) {
      warn "Trying to re-execute myself, but this executable ($self) is not available right now.\n";
      return 0;
      }
   
   my $envv="EXECMYSELF_".$Scriptbase;
   if(!$opts{'no_check_env'}) {
      die "looping exec(".File::Spec->catfile($Bin,$Script).") detected. Bailing. ".
          "Please contact the author at $author_email\n" if $ENV{$envv};
      }    
   $ENV{$envv}=time();
   my @args=($self,@ARGV);
   initialize_interpreter_hyphen_x();
   unshift @args,$^X;
   my $msg=join(" ",@args);
   writedebug("about to exec($msg)");
   my $ret=exec { $args[0] } @args;
   $ret || die "could not execute $msg\n";
   die "exec($msg) returned true????\n";
}   

=head2 C<$string=find_x11_geometry()>

If no X11 window system is available and accessible, returns undef

Otherwise, return geometry as a string (i.e. "1024x768") as told by xdpyinfo.

=cut

sub find_x11_geometry() {
   return if !$ENV{'DISPLAY'};
   return if !find_exe_in_path("xhost");
   return if !find_exe_in_path("xdpyinfo");
   if(!my_system("xhost",
                 'suppress_stdout'=> 1,
                 'suppress_stderr'=> 1,
                 'executable'     => 'xhost',
                 )) {
      writedebug("DISPLAY set to $ENV{'DISPLAY'} but could not connect to it.");
      return;
      }
    my $xdpy=my_backquote("xdpyinfo", 
                 'suppress_stdout'=> 1,
                 'suppress_stderr'=> 1,
                 'executable'     => 'xdpyinfo'
                 );
    my @xdpy= grep {/dimensions:/} split(/\n/,$xdpy);
    if(!@xdpy){
       writedebug("xdpyinfo did not return a \"dimensions:...\" line");
       return;
       }
    $xdpy=$xdpy[0];
    $xdpy =~ s/\s//g;
    if($xdpy !~ s/dimensions:(\d+x\d+)//) {
       writedebug("the \"dimensions:...\" line in xdpyinfos output was not understandable ($xdpy)");
       return;
       }
    my $geometry=$1;   
    writedebug("got geometry $geometry from xdpyinfo");
    return $geometry;
}
   
   
END {}

1;
