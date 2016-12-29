package Hans2::UpdateMyself;

=head1 NAME

Hans2::UpdateMyself - auto updating from the 'net

=head1 COPYRIGHT

Copyright 2003 Hans Ecke hans@ecke.ws under the terms of the GNU Library General Public License

=head1 SYNOPSIS

   updatemyself();

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
                           &updatemyself
                           ),@EXP_VAR);
        @NON_EXPORT  = qw(
                           $dl_base
                           $current_versions_file
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

my $versions_file_cache_expiration=60*60*24;

use File::Spec;
use filetest 'access';

use Hans2::FindBin;
use Hans2::Util;
use Hans2::WebGet;
use Hans2::File;
use Hans2::System;
use Hans2::OneParamFile;
use Hans2::Debug;
use Hans2::Constants;
use Hans2::DataConversion;
use Hans2::ParseVersionList;

my $ONEPARAMFILE_UPDATE_OPTS='AUTO_UPDATE';
my %ONEPARAMFILE_UPDATE_OPTS=(
         'comment'  => [
            'Apply bugfixes and feature improvements automatically?',
            '',
            'If AUTO_UPDATE is set to 1, each time a script is run, it will look',
            'at the website whether a newer version of itself is available. If',
            'yes, it will download that newer version.',
            '',
            'This has nothing to do with marker files or automatic execution of scripts,',
            'only updating the scripts themselves.',
            '',
            '   0 - no automatic upgrading',
            '   1 - automatic upgrading',
                       ],
         'default'  => 1,
         'nr'       => 20,
         );

register_param($ONEPARAMFILE_UPDATE_OPTS,%ONEPARAMFILE_UPDATE_OPTS);

# like get_webpage, except file is first downloaded in temp location for safety
sub my_getwebpage($$) {
   my ($url,$file)=@_;
   my $tmp_file=$file.".new";
   return 0 if !get_webpage($url,'file' => $tmp_file,'cache_expiration'=>0);
   return 0 if ! -f $tmp_file;
   return 0 if ! -s $tmp_file;
   if(-f $file) {
      return 0 if !chmod(file_perms($file),$tmp_file);
      }
   return 0 if ! rename($tmp_file,$file);
   return 1;
}   

=head2 C<updatemyself()>

Retreives the list of current versions

If it turns out a newer version of this script is available, update and re-execute,
or at least warn.

Out:

     undef - if error
     0     - outdated version running, not updating
     1     - current version running (or auto-updating disabled)

=cut

sub updatemyself() {
   my $autoupdate=$PARAMS{$ONEPARAMFILE_UPDATE_OPTS};
   $autoupdate=1 if !defined $autoupdate;
   return 1 if !$autoupdate;
   
   die "updatemyself: don\'t know where to download version info\n" if !$dl_base or !$current_versions_file;

   my $ret=get_webpage($current_versions_file,
                       'cache_expiration'=>$versions_file_cache_expiration
                      );
   if(!$ret) {
      writedebug("$current_versions_file is empty or non-existant");
      return undef;
      }
      
   my %data=parse_version_list($ret);   
      
   if(!$data{$Scriptbase}) {
      writedebug("could not find a record corresponding to $Scriptbase in $current_versions_file");
      return undef;           
      }
   %data=%{$data{$Scriptbase}};   
   my $updatenotice=$data{'update_notice'};

   my $my_version=$main::VERSION || die "$Script: no \$VERSION defined\n";
   return 1 if $my_version !~ /^[\d\.]+$/;
   my $v_my_version     =versionstring_2_vstring($my_version);

   my $current_version  =$data{'effective_version'};
   my $v_current_version=$data{'v_effective_version'};
   if(! ($v_my_version lt $v_current_version)) {
      writedebug("no need to upgrade: $my_version >= $current_version");
      return 1;
      }
   {my $msg="need to upgrade: ";
    $msg.=$updatenotice." " if $updatenotice;
    $msg.="$my_version < $current_version";
    writedebug($msg);
    }
   
   if(exists $data{'silent'}) {
      return 0;
      }
      
   if(exists $data{'only_warn'}) {
      my $msg="At $dl_base, version $current_version of $Script is available. ";
      $msg.="Changes to your version: ".$updatenotice.". " if $updatenotice;
      $msg.="You are running $my_version. Updating is recommanded. ".
           "Unfortunately, I can\'t update your installation automatically. Sorry.";
      warn $msg."\n";     
      return 0;
      }
      
   my @to_download=$Script;
   if($data{'others'}) {
      my @others=map {s/^\s+//;s/\s+$//;$_} split(",",$data{'others'});
      push @to_download,@others;
      }
   {  my $msg="At $dl_base, version $current_version of $Script is available. ";
      $msg.="Changes to your version: ".$updatenotice.". " if $updatenotice;
      $msg.="You are running $my_version. Will try updating automatically.";
      warn $msg."\n";       
      }     
   foreach(@to_download) {
      my $file=File::Spec->catfile($Bin,$_);
      my $url=$dl_base.$_;
      if(!my_getwebpage($url,$file)) {
         warn "could not download ${dl_base}$_, can\'t update myself\n";
         return undef;
         }
      else {   
         warn "    $url -> $file\n";
         }
      }
   warn "Hold on tight...\n";   
   exec_myself();
}

END {}

1;
