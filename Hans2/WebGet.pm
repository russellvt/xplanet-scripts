package Hans2::WebGet;

=head1 NAME

Hans2::WebGet - simple document retreival and caching

=head1 COPYRIGHT

Copyright 2003 Hans Ecke hans@ecke.ws under the terms of the GNU Library General Public License

=head1 SYNOPSIS

   my $text=get_webpage("http://www.weather.com");  

   my $text=get_webpage("http://www.weather.com",
                          'file'             => 'weather',
                          'cache_expiration' => 0
                          );

=head1 DESCRIPTION

Proxy handling is automatic from environment variables in the usual LWP manner.

Cookie file handling is automatic using a L<Hans2::OneParamFile> config file
or the COOKIE_FILE environment variable. The cookie file
must be Netscape- or Mozilla style.

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
                           $HAVE_COOKIES
                           );
        @EXPORT      = (qw(
                          &URL_2_filename
                          &get_webpage
                           ),@EXP_VAR);
        @NON_EXPORT  = qw(
                          $cache_expiration
                          $ua
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

BEGIN {
#   use Hans2::FindBin;
#   use File::Spec;
#   my $cook=File::Spec->catfile(File::Spec->catdir($Bin,'HTTP'),'Cookies.pm');
#   unlink($cook) if -f $cook;
   }

use File::Spec;
use LWP::UserAgent;       
use LWP::Simple;
use File::Basename;
use HTTP::Cookies;
use URI;
use filetest 'access';

use Hans2::FindBin;
use Hans2::Util;
use Hans2::OneParamFile;
use Hans2::File;
use Hans2::Debug;
use Hans2::Debug::Indent;
use Hans2::OneParamFile::StdConf;
use Hans2::DataConversion;
use Hans2::Constants;

=head2 C<$filename=URL_2_filename($url)>

Take URL like "http://www.weather.com/weather/print/80202" and return the 
"file" part, in this case "80202".

=cut

sub URL_2_filename($) {
   my ($url)=@_;
   my @a=URI->new($url)->path_segments();
   return $a[$#a];
}   

# default: always renew cache (never trust it)
$cache_expiration=0;

$ua = LWP::UserAgent->new() ;
$ua->env_proxy();

$HAVE_COOKIES=0;

my $ONEPARAMFILE_COOKIE_OPTS='COOKIES_FILE';
my %ONEPARAMFILE_COOKIE_OPTS=(
         'comment'  => [
            'Which Netscape- or Mozilla-style cookie file to use',
            '',
            'This option is only required for weather.pl but might be usefull for any of the scripts.',
            '',
            '1.) For Windows:',
            '    THIS DOES NOT WORK WITH COOKIE FILES FROM INTERNET EXPLORER!',
            '',
            '    Install Mozilla (or Netscape 6.x or 7.x) and then look around your harddrive',
            '    for its cookies.txt file. Often it can be found in',
            '    C:\WINDOWS\Application Data\Mozilla\Profiles\default\***.slt\cookies.txt',
            '    C:\Documents and Settings\<name>\Application Data\Mozilla\Profiles\default\***.slt\cookies.txt',
            '    C:\WINNT\Profiles\<name>\Application Data\Mozilla\Profiles\default\***.slt\cookies.txt ',
            '',
            '2.) For Unix/Linux:',
            '',
            '    Netscape 3.x or 4.x:',
            '    -> $HOME/.netscape/cookies',
            '',
            '    Galeon:',
            '    -> $HOME/.galeon/mozilla/galeon/cookies.txt',
            '',
            '    Mozilla:',
            '    -> $HOME/.mozilla/$USER/???/cookies.txt',
            '',
            '3.) Local cookie file',
            "    -> ".File::Spec->catfile($Bin,"cookies"),
            "",
            "Please note that if you change your cookie file here you might want to delete",
            "all files in the subdirectory \"cache\" of the temporary storage below (TMPDIR).",
            "They might contain content gathered using the old cookie file.",
            "",
            "If the COOKIE_FILE environment variable is set, its value",
            "overrides anything you put here."
                       ],
         'default'  => '',
         'env'      => ['WEATHERPL_COOKIES','XPLANET_COOKIES','COOKIE_FILE'],
         'nr'       => $Hans2::OneParamFile::general_nr+5,
         );

# the caching needs some kind of tmpdir variable
register_param($ONEPARAMFILE_TMPDIR_OPTS,%ONEPARAMFILE_TMPDIR_OPTS);

# cookies are usefull for many things...
register_param($ONEPARAMFILE_COOKIE_OPTS,%ONEPARAMFILE_COOKIE_OPTS);

# initialization code. called the first time get_webpage() is executed
#
# * cookies
#   if $PARAMS{$ONEPARAMFILE_COOKIE_OPTS} || $ENV{'XPLANET_COOKIES'} || $ENV{'WEATHERPL_COOKIES'} 
#   then initialize LWP with that netscape style cookie file
# * agent
#   set agent string to a in-style browser, with special code to denote we are 
#   coming from WebGet.pm, including script name and -version
# * set $cache_expiration to $main::cache_expiration, if defined
{
sub set_cookie_jar($) {
   my ($cookie_file)=@_;
   $cookie_file                || ($in_windows ?
                                  die("Please set the COOKIE_FILE environment variable to your cookies.txt file from Netscape or Mozilla (NOT Internet Explorer!)\n") 
                                : die("Please set the COOKIE_FILE environment variable to your Netscape-style cookie file\n"));
   -d $cookie_file             && ($cookie_file=File::Spec->catfile($cookie_file,"cookies.txt"));
   -f $cookie_file             || die("Could not find cookie file $cookie_file\n");
   -r $cookie_file             || die("Could not read cookie file $cookie_file\n");
   (-s $cookie_file > 50)      || die("Cookie file $cookie_file does not seem to contain any information. Please use a valid Netscape-style cookie file.\n");
   
   my $cookie_jar = HTTP::Cookies::Netscape->new('File' => $cookie_file);
   if(!($cookie_jar                 && 
        $cookie_jar->{'COOKIES'}    &&
        %{$cookie_jar->{'COOKIES'}})) {
      warn("Could not understand cookie file $cookie_file. If this is a mozilla cookie file, ".
           "please contact the author at $author_email\n");
      return;
      }
   
   $ua->cookie_jar($cookie_jar);
   $HAVE_COOKIES=1;
   
   writedebug("cookie file: $cookie_file");   
}
   
sub try_set_cookie_jar() {
   writedebug("first time in try_set_cookie_jar()");
   my $jar=$PARAMS{$ONEPARAMFILE_COOKIE_OPTS} || 
           $ENV{'COOKIE_FILE'} || 
           $ENV{'XPLANET_COOKIES'} || 
           $ENV{'WEATHERPL_COOKIES'};
   if(!$jar) {
      writedebug("no cookie file given in parameter file or COOKIE_FILE");
      return;
      }
   writedebug("trying file $jar");
   set_cookie_jar($jar);
}   

my $have_webget_init=0;
sub webget_init() {
   return if $have_webget_init;
   $have_webget_init=1;
   defined($main::VERSION) || die "main::VERSION not defined?\n";
   $ua->agent("Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; HE $Scriptbase $main::VERSION)"); # Use on-fashion browser
   try_set_cookie_jar();
   if((defined ${"main::cache_expiration"}) and (defined $main::cache_expiration)) {
      $cache_expiration=$main::cache_expiration;
      }
}
}


########################################################################
#
#
#	get_webpage, caching
#
#
########################################################################

# in: text of HTML file
# out: a redirection URL if one is found
sub check_redirect($) {
   local ($_)=@_;
   $_                            or return;
   s/.*<head>//i;
   s/<\/head>.*//i;
   s/\s+/ /g;
   /http-equiv="refresh"(.*?)>/i or return;
   $_=$1;
   /URL=(.*?)"$/i                or return;
   return $1;
}

# return 1 or undef
sub get_webpage_direct_file($$;%) {
   my ($req,$URL,%opts)=@_;
   make_directory(dirname($opts{'file'}));
   my $res = $ua->request($req,$opts{'file'});
   if(!$res->is_success()) {
      writedebug("could not download $URL: ".$res->code()." ".$res->message());
      return undef;
      }
   writedebug("got $URL");
   return 1;
}
# return content or undef
sub get_webpage_direct_content($$;%) {
   my ($req,$URL,%opts)=@_;
   my $res = $ua->request($req);
   if(!$res->is_success()) {
      writedebug("could not download $URL: ".$res->code()." ".$res->message());
      return undef;
      }
   writedebug("got $URL");
   my $cont=$res->content();
   if(!$cont) {
      writedebug("$URL returned empty document");
      return undef;
      }
   return $cont;
}
# in: URL, options hash
# out: $opts{'file'} : whether we wrote into that file successfully
#      else          : text of that web/ftp page
sub get_webpage($;%);
sub get_webpage_direct($;%);
sub get_webpage_direct($;%) {
   my ($URL,%opts)=@_;
   my $req = HTTP::Request->new(GET => $URL);
   my $ret;
   if($opts{'file'}) {
      return get_webpage_direct_file($req,$URL,%opts);
      }
   else {   
      $ret=get_webpage_direct_content($req,$URL,%opts);
      return $ret if !$ret;   
      return $ret if !$opts{'check_redirect'};
      my $new_url=check_redirect($ret);
      writedebug("checking whether we need to redirect...");
      return $ret if !$new_url;
      writedebug("It seems we need to redirect to $new_url");
      return get_webpage_direct($new_url,%opts);
      }   
}

# get cache file corresponding to an internet address
sub URL_2_file($%) {
   my ($URL,%opts)=@_;
   my $tmpdir=$PARAMS{$ONEPARAMFILE_TMPDIR_OPTS} || $Bin;
   my $dir=$opts{'cache_dir'} || File::Spec->catdir($tmpdir,"cache");
   return File::Spec->catfile($dir,anytext_2_filename($URL));
}   

sub hour_str($) {
   my ($sec)=@_;
   return sprintf("%.2f",$sec/60/60);
}

# checks whether cache file is younger than $expiration
#
# in: cache file, options hash
# out: 1 - younger (use cache)
#      undef - older, renew cache
sub check_cache($%) {
   my ($cache,%opts)=@_;
   if(-f $cache) {
      my $expiration=$opts{'cache_expiration'};
      $expiration=$cache_expiration if !defined $expiration;
      return 1 if $expiration < 0;
      my $file_time=mtime($cache);
      my $time=time();
      writedebug(basename($cache).": age=".hour_str($time-$file_time)." hours. expiration time=".hour_str($expiration)." hours");
      return 1 if ($time-$file_time) < $expiration;
      }
   return undef;   
}

=head2 C<get_webpage($URL;%options)>

optional option hash with keys:

          cache_expiration - in seconds
                             -1 : always use cache
                             0  : always renew cache
                             >0 : depending on cache age
          cache            - cache file, 'none' or '' if no cache
          cache_dir        - cache directory
          file             - file where to put the webpage
                             otherwise, webpage is returned as string by function

Out if webpage content requested (no 'file' option):

          text of that web/ftp page if success
          false otherwise

Out if download into file requested:

          1     - success
          false - error
          
If the URL given is undefined or empty, this just initializes           

has _very_ crude caching

=cut

sub get_webpage($;%) {
   my ($URL,%opts)=@_;

   my $msg=join(", ",map {$_."=>".$opts{$_}} sort keys %opts);
   $msg = " with opts $msg" if $msg;
   if(defined $URL and $URL ne '') {
      $msg="$URL$msg";
      }
   else {   
      $msg = "Hans2::WebGet initialization";
      }
   my $ind=Hans2::Debug::Indent->new("requested $msg");
   
   webget_init();
   
   return if !defined $URL;
   return if $URL eq '';

   my $cache=1;                                    # whether we are doing caching
   $cache=0 if defined $opts{'cache'} and (!$opts{'cache'} or $opts{'cache'} eq 'none');

   my $cfile=$opts{'file'}||$opts{'cache'};        # where on disc we are caching
   $cfile=URL_2_file($URL,%opts) if !defined $cfile;
   
   if(($cache) && (check_cache($cfile,%opts))) {
      if($opts{'file'}) {
         writedebug("is fresh in file");
         return 1;
         }
      my $txt=readfile($cfile);
      if(defined $txt) {
         writedebug("got from cache");
         return $txt;
         }
      writedebug("did not get anything from $cfile, removing it");
      unlink($cfile);
      }
   
   my $txt=get_webpage_direct($URL,%opts);
   return if !$txt;
   if($cache and !$opts{'file'}) {
      my $had_dir=0;
      $had_dir=1 if -d dirname($cfile);
      writefile($cfile,$txt);
      if($> == 0) {
         # make sure the cache is read-writable by anybody.
         # This looks like a _tiny_ security risk, but it helps when running the 
         # scripts by different users.
         chmod(0666,$cfile);
         chmod(0777,dirname($cfile)) if !$had_dir; 
         }
      }
   return $txt;
}


END {}

1;
