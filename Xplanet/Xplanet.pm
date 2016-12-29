package Xplanet::Xplanet;

=head1 NAME

Xplanet::Xplanet - xplanet specific functions

=head1 COPYRIGHT

Copyright 2002 Hans Ecke under the terms of the GNU General Public Licence

=head1 SYNOPSIS

   $success=execute_xplanet_script("weather","");
   $text=execute_xplanet_script("geo_locator","denver",'catch_output'=>1);
   $success=execute_xplanet('output'=>'test.jpg');

   ($cmd,%opts)=xplanetcmd_2_opts("-image earth.jpg -output test.jpg frobnicate");
   # now %opts is 'output' => 'test.jpg'
   #              'image'  => 'earth.jpg'
   # and $cmd is "frobnicate"
   $command=opts_2_xplanetcmd($cmd,%opts);
   # $command is '-image earth.jpg -output test.jpg frobnicate'

   $fullpath=xplanet_script_2_file("weather");

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
                         &execute_xplanet_script
                         &xplanetcmd_2_opts
                         &opts_2_xplanetcmd
                         &execute_xplanet
                         &xplanet_script_2_file
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

use Hans2::Cwd;
use Hans2::FindBin;
use Hans2::Units;
use Hans2::Math;
use Hans2::OneParamFile;
use Hans2::System;
use Hans2::Util;
use Hans2::Debug;
use Hans2::File;
use Hans2::Constants;
use Hans2::DataConversion;

use Xplanet::StdConf;

# the caching needs some kind of tmpdir variable
register_param($ONEPARAMFILE_DIR_OPTS,%ONEPARAMFILE_DIR_OPTS);

my $ONEPARAMFILE_XPLANET_OPTS='XPLANET_EXECUTABLE';
my %ONEPARAMFILE_XPLANET_OPTS=(
         'comment'  => [
            'The name and path of the xplanet executable.',
                       ],
         'default'  => "xplanet",
         'env'      => 'XPLANET',
         'nr'       => 5,
         );

register_param($ONEPARAMFILE_XPLANET_OPTS,%ONEPARAMFILE_XPLANET_OPTS);

sub add_xplanet_path() {
   my $dir=$PARAMS{$ONEPARAMFILE_DIR_OPTS};
   if($dir) {
      if($ENV{'PATH'} !~ /\Q$dir\E/) {
         $ENV{'PATH'}.=$PATH_CONCAT.$dir;
         $ENV{'PATH'}=normalize_path($ENV{'PATH'});
         }
      }
}      

my $_have_checked_xplanet_version=0;
sub check_xplanet_version() {
   return if $_have_checked_xplanet_version;
   $_have_checked_xplanet_version=1;
   %PARAMS || die "check_xplanet_version() called before config file is parsed\n";
   my $xplanet_executable=  find_exe_in_path($PARAMS{$ONEPARAMFILE_XPLANET_OPTS}) 
                         || find_exe_in_path("xplanet") 
                         || die "Could not find xplanet executable in path $ENV{'PATH'}. Try setting XPLANET_EXECUTABLE in the xplanet.conf configuration file to the absolute path.\n";
   my $xplanet_v=my_backquote("$xplanet_executable -version",'suppress_stderr' => 1);
   if(!$xplanet_v) {
      die "could not find the xplanet executable and execute \"xplanet -version\"\n";
      }
   elsif($xplanet_v =~ /(\d+(?:\.\d+)+)/) {
      my $v=$1;
      if($v =~ /^0/) {
         writedebug("xplanet $v detected.");
         }
      else {
         die "xplanet version $v not supported. Sorry\n";
         }   
      }
   else {
      die "could not understand the\"xplanet -version\" output. ".
          "Maybe you are running a non-supported version? ".
          "Please write the author $author_name at $author_email and ".
          "include the output of \"xplanet -version\". Thanks.\n";
      }   
}      


=head2 C<$fullpath=xplanet_script_2_file("weather")>

find filename corresponding to a script, i.e. for 'weather' it might return 

     'weather.pl'
     'weather.exe'
     '/usr/local/share/xplanet/weather.dpl'

whichever is available

=cut

{
my %_xs2f;
sub xplanet_script_2_file($) {
   my ($script)=@_;

   check_xplanet_version();

   return $_xs2f{$script} if exists $_xs2f{$script};
   my $xplanet_dir=$PARAMS{$ONEPARAMFILE_DIR_OPTS} || $Bin;
   my $cwd=getcwd();
   # try to find out what file corresponds to the script name we were given
   my $s;
   foreach my $ext ("",".pl",".exe",".dpl") {
      foreach my $dir ("",$Bin,$xplanet_dir,$cwd) {
         $s=$script;
         $s=File::Spec->catdir($dir,$s) if $dir;
         $s="$s$ext" if $ext;
         next if !-f $s;
         next if !-r $s;
         next if !hyphen_x($s);
         writedebug("script $script is $s");
         $_xs2f{$script}=$s;
         return $s;
         }
      }
   writedebug("no script $script found");   
   $_xs2f{$script}=undef;
   return undef;
}
}

=head2 C<$success=execute_xplanet_script($script,$command;%options)>

Execute an xplanet $script with command line $command.
Will execute the script inside $xplanet_dir with interpreter perl

%options:

  'catch_output'  => 1      : run it in backquotes, return the output
                     0/undef: run it in my_system()

See my_system()/my_backquote() in L<Hans2::System> for more meanings of the options hash.

=cut

sub execute_xplanet_script($$;%) {
   my ($script,$command,%opts)=@_;
   
   check_xplanet_version();
   
   my $xplanet_dir=$PARAMS{$ONEPARAMFILE_DIR_OPTS} || $Bin;
   add_xplanet_path();

   my $script_abs=xplanet_script_2_file($script);
   if(!$script_abs) {
      warn "could not find script $script\n";
      return undef;
      }
            
   $opts{'executable'} = $script_abs;
   my $cmd=quote_fn($script_abs);
   $cmd.=" $command" if $command;
   $opts{'working_dir'}= $xplanet_dir;
   if($opts{'catch_output'}) {
      return my_backquote($cmd,%opts);
      }
   else {
      return my_system(   $cmd,%opts);
      }
   }

=head2 C<xplanetcmd_2_opts> and C<opts_2_xplanetcmd>

C<($cmd,%opts)=xplanetcmd_2_opts($cmd)> takes an xplanet-style command line
and returns the unparsable components and an options-hash

C<$cmd=opts_2_xplanetcmd($cmd,%opts)> takes a command line and a options
hash and returns the whole command line

=cut

# in: command line
# out: options we treat specifically
sub xplanetcmd_2_opts($) {
   my ($cmd)=@_;
   my %opts;

   check_xplanet_version();

   $cmd =~ s/-image (\S+)//       and $opts{'image'}=$1;
   $cmd =~ s/-night_image (\S+)// and $opts{'night_image'}=$1;
   $cmd =~ s/-font (\S+)//        and $opts{'font'}=$1;
   $cmd =~ s/-output (\S+)//      and $opts{'output'}=$1;
   $cmd =~ s/-mapdir (\S+)//      and $opts{'mapdir'}=$1;
   $cmd =~ s/-fontdir (\S+)//     and $opts{'fontdir'}=$1;
   
   # get rid of " at start/end of options
   foreach my $key (keys %opts) {
      my $val=$opts{$key};
      if(($val =~ /^\"/) and ($val =~ /"$/)) {
         $val =~ s/^"//;
         $val =~ s/"$//;
         $opts{$key}=$val;
         }
      }   
   
   return ($cmd,%opts);
}   

# in: command line; options hash
# out: complete command line, ready for execution
#
# if a value is empty: if its
#   undefined         : not considered
#   "" (empty string) : option does not have value, only key
sub opts_2_xplanetcmd($%) {
   my ($cmd,%opts)=@_;

   check_xplanet_version();

   foreach my $key (sort keys %opts) {
      my $val=$opts{$key};
      next if !defined $val;
      if($val eq "") {
         $cmd.=" -$key";
         }
      else {
         $cmd.=" -$key ".quote_fn($val);
         }   
      }
   return $cmd;
}   

=head2 C<$success=execute_xplanet($command,%options)>

Run xplanet with the specified options inside $xplanet_dir.
If not in windows and DEBUG is not set, run under 'nice -15'

necessary options: 'output'
                   'image'
optional options:  'night_image'
                   'font'

=cut

sub execute_xplanet($%) {
   my ($cmd,%opts)=@_;

   check_xplanet_version();

   my $xplanet_dir=$PARAMS{$ONEPARAMFILE_DIR_OPTS} || $Bin;
   add_xplanet_path();

   my $xplanet_executable=  find_exe_in_path($PARAMS{$ONEPARAMFILE_XPLANET_OPTS}) 
                         || find_exe_in_path("xplanet") 
                         || die "Could not find xplanet executable in path $ENV{'PATH'}. Try setting XPLANET_EXECUTABLE in the xplanet.conf configuration file to the absolute path.\n";

   # check validity of $cmd 
   {
   my ($cmd,%opts2)=xplanetcmd_2_opts($cmd);
   %opts2 && die "options ".join(", ",sort keys %opts2)." given directly to execute_xplanet()\n";
   }
   
   # unpack mandatory and optional parameters
   my $out        = $opts{'output'}      || die "no output specified for xplanet command\n";
   my $day_image  = $opts{'image'}       || die "no day image specified for xplanet command\n";
   my $night_image= $opts{'night_image'};
   my $font       = $opts{'font'};

   # -mapdir, -fontdir
   my $xpl_im=File::Spec->catdir($xplanet_dir,"images");  
   my $xpl_fn=File::Spec->catdir($xplanet_dir,"fonts");  
   $opts{'mapdir'}=$xpl_im;
   $opts{'fontdir'}=$xpl_fn;
   
   # -output
   my $test_out=$out;
   my $ext=file_extension($test_out);
   $test_out =~ s/\Q$ext\E$//;
   $test_out.="_test".$ext;
   if(-f $test_out) {
      unlink($test_out) || die "could not delete $test_out\n";
      }
   die "could not delete $test_out\n" if -e $test_out;   
   if(-f $out) {
      unlink($out) || die "could not delete $out\n";
      }
   die "could not delete $out\n" if -e $out;   
   $opts{'output'}=$test_out;
   
   # -image
   my $day_image_full=$day_image;
   $day_image_full=File::Spec->catfile($xpl_im,$day_image) 
      if !File::Spec->file_name_is_absolute($day_image);
   if(!test_file_really_accessible($day_image_full)) {
      warn "day image $day_image given, but not accessible\n"; 
      return 0;
      }

   # -night_image
   if($night_image) {
      my $night_image_full=$night_image;
      $night_image_full=File::Spec->catfile($xpl_im,$night_image) 
         if !File::Spec->file_name_is_absolute($night_image);
      if(!test_file_really_accessible($night_image_full)) {
         warn "night image $night_image given, but not accessible\n";
         return 0;
         }
      }
      
   # -font   
   if($font) {
      die "-font $font given, but that font file is not accessible to me\n" 
         if !test_file_really_accessible(File::Spec->catfile($xpl_fn,$font));
      }          

   $cmd=opts_2_xplanetcmd($cmd,%opts);

   my $ret=run_nice_if(quote_fn($xplanet_executable)." $cmd",
                      'working_dir' => $xplanet_dir,
                      'executable'  => $xplanet_executable,
                      );

   return $ret if !$ret;
   
   return undef if !test_file_really_accessible($test_out);
   rename($test_out,$out) || die "could not rename $test_out to $out\n";   
   chmod(0644,$out)       || die "could not chmod(644,$out)\n";  

   return $ret;          
}
   
END {}

1;
