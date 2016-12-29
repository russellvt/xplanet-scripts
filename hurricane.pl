#!/usr/bin/perl -w

# This uses the Hurricane Alert of hawaii.edu and xplanet to show 
# active hurricanes on your desktop
#
# INSTALL: Put this script in your xplanet directory
#          Run it once
#          It should create or update the xplanet.conf configuration file
#          Adjust any variables inside that file, if needed (you likely don't have to)
#
# homepage/newest version: http://hans.ecke.ws/xplanet
#
# Usage: * call the script.  It will write a markerfile 'hurricane' to xplanet/marker/
#          and a great-arc file 'hurricane' to xplanet/arcs/
#        * put '-markerfile hurricane -greatarcfile hurricane' in your xplanet commandline
#
# Copyright 2002 Hans Ecke <hans@ecke.ws>
#
# Licence: Gnu Public License. In short: This comes without any warranty. Redistribution
#          of the original or changed versions must leave this Copyright statement intact -AND-
#          provide the sourcecode for free.
#
# Thank you Michael Knight for ideas and creating the inset library.
# Imagery courtesy of NASA 
#        http://www.nasa.gov
#        http://visibleearth.nasa.gov
#        http://earthobservatory.nasa.gov
#
# Written and tested on Linux and Windows 98. Especially the behavior on
# Windows is poorly tested
#
# Comment, suggestions, bugreports are very much appreciated!
#
# Needs: Perl      version 5.6 or later     http://www.perl.com (Unix)
#                                           http://www.activestate.com/Products/ActivePerl/ (Windows)
#        xplanet   version 0.91 or later    http://xplanet.sourceforge.net
#
# ChangeLog: Version 
#        2.2.3: fix in inset name calculation - faster
#        2.2.2: minor stability fixes
#               fixed computation of needed inset for locales that write 1/2 as '0,5' instead '0.5'
#        2.2.1: minor stability fixes
#          2.2: faster: we don't call out to geo_locator anymore but instead 
#                  use the Geo::Locator API directly
#               finally added date/time parsing. Much of this was developed or inspired by 
#                  Stefan P. Wolf. Thanks and sorry for the delay!
#               added time labels at start and end of paths
#               some cleanup of the atrociously complex code
#               faster: computation of which inset we need to draw does not read the .INF
#                  collection anymore, unless the computation fails
#                  algorithm is thanks to Stefan P. Wolf
#        2.1.2: windows fixes
#        2.1.1:
#          2.1: auto-updating; improved config file handling
#        2.0.1: fixed bug that affected the windows version
#          2.0: source cleanup: share source between all xplanet perl scripts
#               better detection which inset to choose for a given location, thanks Stefan P. Wolf
#               new unified configuration system using the xplanet.conf file
#               changed license to GPL
#        1.9.9: better detection of errors in xplanet's inset generation
#        1.9.8: we do a chdir(XPLANET_DIR) before calling xplanet. this should
#                  help with the problem that xplanet does not find the rgb.txt file
#               choose_inset='none' option added. thanks Phil Hyde for suggestion
#        1.9.7: updated caching
#        1.9.6: changed font handling so it works better under linux. 
#               included verdana.ttf in hurricane_data archive.
#        1.9.x: support for hurricane insets
#               thanks Michael Knight for ideas and the inset library
#               thanks Stefan P. Wolf for numerous ideas and bugreports
#        0.9.7: support for cyclones
#               thanks Michael Knight for below definitions
#        0.9.6: extended template syntax: added $stype, $ltype, $mspeed, $kspeed
#               thanks Chris Harper & Michael Knight for suggestions
#               better getnum() that tries harder with non-US formated numbers
#               changed default colors of label & icons to green/blue to better work
#                   together with other scripts
#        0.9.5: added -d command line option
#        0.9.4: extended template syntax: added $type
#               multiple icon sets
#               thanks Fly Paper ('Zac') for explanations and icons
#        0.9.3: non-US formated numbers (i.e. 14,1 instead of 14.1)
#               thanks Matz Johansson for the error report!
#        0.9.2: take case of no hurricanes into account
#        0.9.1: arc between last known and first forecast location
#          0.9: initial release
#               thanks Michael Knight for the suggestion
#                          
#
# Todo:  more than 1 inset: 2, 3, for all storms
#          -> use forecast/moonphase positioning code
#        get a cyclone icon
#        add a legend for the colors of the storm path?
#        don't do anything if main page didn't change - using cache subsystem?
#
# National Hurricane Center definitions:
#       
#        Tropical Disturbance:
#            A discrete tropical weather system of apparently organized
#            convection -- generally 100 to 300 nmi in diameter --
#            originating in the tropics or subtropics, having a nonfrontal
#            migratory character, and maintaining its identity for 24
#            hours or more. It may or may not be associated with a
#            detectable perturbation of the wind field.
#       
#        Tropical Depression:
#            A tropical cyclone in which the maximum sustained surface
#            wind speed (using the U.S. 1-minute average) is 33 kt (38 mph
#            or 62 km/hr) or less.
#       
#        Tropical Storm:
#            A tropical cyclone in which the maximum sustained surface
#            wind speed (using the U.S. 1-minute average) ranges from 34
#            kt (39 mph or 63 km/hr) to 63 kt (73 mph or 118 km/hr).
#       
#        Hurricane / Typhoon:
#            A tropical cyclone in which the maximum sustained surface
#            wind (using the U.S. 1-minute average) is 64 kt (74 mph or
#            119 km/hr) or more. The term hurricane is used for Northern
#            Hemisphere tropical cyclones east of the International
#            Dateline to the Greenwich Meridian. The term typhoon is used
#            for Pacific tropical cyclones north of the Equator west of
#            the International Dateline.
#       
#        Tropical Cyclone:
#            A warm-core non-frontal synoptic-scale cyclone, originating
#            over tropical or subtropical waters, with organized deep
#            convection and a closed surface wind circulation about a
#            well-defined center. Once formed, a tropical cyclone is
#            maintained by the extraction of heat energy from the ocean at
#            high temperature and heat export at the low temperatures of
#            the upper troposphere. In this they differ from extratropical
#            cyclones, which derive their energy from horizontal
#            temperature contrasts in the atmosphere (baroclinic effects).
#       
#        Subtropical Cyclone:
#            A non-frontal low pressure system that has characteristics of
#            both tropical and extratropical cyclones.
#       
#        Subtropical Depression:
#            A subtropical cyclone in which the maximum sustained surface
#            wind speed (using the U.S. 1-minute average) is 33 kt (38 mph
#            or 62 km/hr) or less.
#       
#        Subtropical Storm:
#            A subtropical cyclone in which the maximum sustained surface
#            wind speed (using the U.S. 1-minute average) is 34 kt (39 mph
#            or 63 km/hr) or more.
#


require 5.006;

use FindBin;
use lib $FindBin::Bin;
use Time::Local;
use File::Basename;
use File::Spec;
use filetest 'access';

# how we name the hurricane.pl - generated image
my $compiled_inset_image = "hurricane_inset.jpg";
-f $compiled_inset_image && unlink($compiled_inset_image);

# how short type strings look like
my %type_2_stype=(
     'DEP'  => 'T.D.',
     'STO'  => 'T.S.',
     'HUR'  => 'Hur.',
     'TYP'  => 'Typ.',
     'CYC'  => 'Cyc.',
     );

# how long type strings look like
my %type_2_ltype=(
     'DEP'  => 'Depression',
     'STO'  => 'Storm',
     'HUR'  => 'Hurricane',
     'TYP'  => 'Typhoon',
     'CYC'  => 'Cyclone',
     );

# the color a storm trace is painted
my %type_2_color=(
     'DEP'  => 'blue',
     'STO'  => 'green',
     'HUR'  => 'red', 
     'TYP'  => 'red', 
     'CYC'  => 'red', 
     );
     
# if the type of the storm is not known, try to determine the color from the speed
sub wind_2_color($) {
   my ($kn) = @_;
   
   return $type_2_color{'DEP'}    if !$kn;
   return $type_2_color{'DEP'}    if $kn < 38;
   return $type_2_color{'STO'}    if $kn < 74;
   return $type_2_color{'HUR'};
}   

# the file we try to download
my $URL = "http://www.solar.ifa.hawaii.edu/Tropical/";

# where we download missing image files from
my $inset_lib_URL="http://acoustics.mines.edu/~hans/xplanet/images/insets/";

# how the dots on the hurricane paths are spaced
#
# the hurricane greatarc file used for the whole-earth images
# forecast and actual
#
# increase the number after $spacing_global_for if you see a 
# solid line for predicted storms paths -- decrease it if 
# you think the dot distance is too wide
#
my $spacing_global_for="0.2";
my $spacing_global_act="0.05";
#
# the hurricane greatarc file used for high-magnification inset images
# forecast and actual
my $spacing_inset_for ="0.05";
my $spacing_inset_act ="0.005";

# required inset image size
my $inset_x_size = 300;
my $inset_y_size = 300;

# if downloaded copy found, when will it be considered too old?
# -1 means: consider any content of cache fresh
# in seconds (one hour = 60*60 = 3600)
our $cache_expiration=60*60*2.5;

# the configuration file
my $conffile=$ENV{'XPLANET_SCRIPTS_CONF'} || 'xplanet.conf';

our $VERSION="2.2.3";

BEGIN { 
### Start of inlined library Hans2::FindBin.
$INC{'Hans2/FindBin.pm'} = './Hans2/FindBin.pm';
{
package Hans2::FindBin;




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

};
### End of inlined library Hans2::FindBin.
Hans2::FindBin->import();
}
BEGIN { 
### Start of inlined library Hans2::Util.
$INC{'Hans2/Util.pm'} = './Hans2/Util.pm';
{
package Hans2::Util;




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

BEGIN { 
Hans2::FindBin->import();
}
BEGIN { 
### Start of inlined library Hans2::Cwd.
$INC{'Hans2/Cwd.pm'} = './Hans2/Cwd.pm';
{
package Hans2::Cwd;



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
                           &getcwd
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

BEGIN {
require Cwd;
}
use File::Spec;

sub getcwd() {
   return File::Spec->canonpath(Cwd::getcwd());
}   

END {}

1;

};
### End of inlined library Hans2::Cwd.
Hans2::Cwd->import();
}
BEGIN { 
### Start of inlined library Hans2::Debug.
$INC{'Hans2/Debug.pm'} = './Hans2/Debug.pm';
{
package Hans2::Debug;




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
                         $DEBUG
                         );
        @EXPORT      = (qw(
                         &writedebug
                         &writestdout
                         &writestderr
                         ),@EXP_VAR);
        @NON_EXPORT  = qw(
                          $off
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

BEGIN { 
Hans2::FindBin->import();
}

select STDERR; $| = 1;      # make unbuffered
select STDOUT; $| = 1;      # make unbuffered

$off       = 0;


# before anything else, look if we should run in DEBUG mode
$DEBUG=0;
if(@ARGV) {
   my @argv_new;
   foreach(@ARGV) {
      if(/^-+d/) {
         $ENV{'DEBUG'}=1;
         $DEBUG=1;
         }
      else {   
         push @argv_new,$_;
         }
      }
   @ARGV=@argv_new;
   }   

my $prefix_tty=" " x (length($Scriptbase) + 2);
my $prefix_log;
{
   my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) 
       = localtime(time());
   $mon++;
   $year+=1900;    
   foreach($mon,$mday,$hour,$min,$sec) {   
      $_ ="0$_"  if $_<10;   
      }
   my $txt="$Scriptbase($$) $mday/$mon $hour:$min:$sec ";
   $prefix_log=" " x length($txt);
}   


my $indent_num=0;
my $indent_length=4;
sub push_indent($) {
   my ($msg)=@_;
   writedebug($msg) if $msg;
   $indent_num++;
   }
sub pop_indent() {
   $indent_num-- if $indent_num>0;
   }

sub writelogline($) {
   my ($msg)=@_;
   return if !$ENV{'LOGFILE'};
   $msg =~ s/\n/\n$prefix_log/g;
   my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) 
       = localtime(time());
   $mon++;
   $year+=1900;    
   foreach($mon,$mday,$hour,$min,$sec) {   
      $_ ="0$_"  if $_<10;   
      }
   local *LOG;
   if(!open(LOG, ">>".$ENV{'LOGFILE'})) {
      my $lf=$ENV{'LOGFILE'};
      delete $ENV{'LOGFILE'}; # make sure we don't go to a endless loop
      die "could not write to logfile $lf\n";
      };
   print LOG "$Scriptbase($$) $mday/$mon $hour:$min:$sec $msg\n";
   close LOG;
}   

sub writettyline($) {
   my ($msg)=@_;
   $msg =~ s/\n/\n$prefix_tty/g;
   print STDERR "$msg\n";
}

# INTERFACE


# write out debug message if DEBUG is set
sub writedebug($) {
   my ($msg)=@_;
   return if $off;
   $msg =~ s/[\s\n\r]+$//;
   my $pref=" " x ($indent_num*$indent_length);
   $msg=$pref . $msg;
   $msg =~ s/\n/\n$pref/g;
   writelogline($msg);
   writettyline("$Scriptbase: $msg") if $ENV{'DEBUG'};
}  


sub writewarn($) {
   my ($msg)=@_;
   return if $off;
   $msg =~ s/[\s\n\r]+$//;
   writelogline("!warning: ".$msg);
   print STDERR $msg."\n";
}

sub writedie($) {
   my ($msg)=@_;    
   return if $off;
   $msg =~ s/[\s\n\r]+$//;
   writelogline("!fatal: ".$msg);
#   print STDERR $msg."\n";
}


sub writestdout($) {
   my ($msg)=@_;    
   return if $off;
   $msg =~ s/[\s\n\r]+$//;
   writelogline($msg);
   print STDOUT $msg."\n";
}


sub writestderr($) {
   my ($msg)=@_;    
   return if $off;
   $msg =~ s/[\s\n\r]+$//;
   writelogline($msg);
   print STDERR $msg."\n";
}

$SIG{__WARN__}=\&writewarn;
$SIG{__DIE__} =\&writedie;

writedebug("-------------------");
writedebug("initialized logging");
writedebug("$^X is version ".sprintf("%vd",$^V));
writedebug("OS: $^O");
{ my $h=$ENV{'HOME'} || "<undefined>";
  writedebug("users home: $h");   
}  
writedebug("users id: effective: $>; real: $<");   
if(@ARGV) {
   writedebug("command line args: \'".join("\', \'",@ARGV)."\'");
   }
else {   
   writedebug("command line args: <none>");
   }
   
END {}

1;

};
### End of inlined library Hans2::Debug.
Hans2::Debug->import();
}


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

};
### End of inlined library Hans2::Util.
Hans2::Util->import();
}
BEGIN { 
### Start of inlined library Hans2::WebGet.
$INC{'Hans2/WebGet.pm'} = './Hans2/WebGet.pm';
{
package Hans2::WebGet;




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
BEGIN { 
### Start of inlined library HTTP::Cookies.
$INC{'HTTP/Cookies.pm'} = './HTTP/Cookies.pm';
{
package HTTP::Cookies;

use HTTP::Date qw(str2time time2str);
use HTTP::Headers::Util qw(split_header_words join_header_words);
use LWP::Debug ();

use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.25 $ =~ /(\d+)\.(\d+)/);

my $EPOCH_OFFSET = 0;  # difference from Unix epoch
if ($^O eq "MacOS") {
    require Time::Local;
    $EPOCH_OFFSET = Time::Local::timelocal(0,0,0,1,0,70);
}

sub new
{
    my $class = shift;
    my $self = bless {
	COOKIES => {},
    }, $class;
    my %cnf = @_;
    for (keys %cnf) {
	$self->{lc($_)} = $cnf{$_};
    }
    $self->load;
    $self;
}

sub add_cookie_header
{
    my $self = shift;
    my $request = shift || return;
    my $url = $request->url;
    my $domain = _host($request, $url);
    $domain = "$domain.local" unless $domain =~ /\./;
    my $secure_request = ($url->scheme eq "https");
    my $req_path = _url_path($url);
    my $req_port = $url->port;
    my $now = time();
    _normalize_path($req_path) if $req_path =~ /%/;

    my @cval;    # cookie values for the "Cookie" header
    my $set_ver;
    my $netscape_only = 0; # An exact domain match applies to any cookie

    while ($domain =~ /\./) {

        LWP::Debug::debug("Checking $domain for cookies");
	my $cookies = $self->{COOKIES}{$domain};
	next unless $cookies;

	# Want to add cookies corresponding to the most specific paths
	# first (i.e. longest path first)
	my $path;
	for $path (sort {length($b) <=> length($a) } keys %$cookies) {
            LWP::Debug::debug("- checking cookie path=$path");
	    if (index($req_path, $path) != 0) {
	        LWP::Debug::debug("  path $path:$req_path does not fit");
		next;
	    }

	    my($key,$array);
	    while (($key,$array) = each %{$cookies->{$path}}) {
		my($version,$val,$port,$path_spec,$secure,$expires) = @$array;
	        LWP::Debug::debug(" - checking cookie $key=$val");
		if ($secure && !$secure_request) {
		    LWP::Debug::debug("   not a secure requests");
		    next;
		}
		if ($expires && $expires < $now) {
		    LWP::Debug::debug("   expired");
		    next;
		}
		if ($port) {
		    my $found;
		    if ($port =~ s/^_//) {
			# The correponding Set-Cookie attribute was empty
			$found++ if $port eq $req_port;
			$port = "";
		    } else {
			my $p;
			for $p (split(/,/, $port)) {
			    $found++, last if $p eq $req_port;
			}
		    }
		    unless ($found) {
		        LWP::Debug::debug("   port $port:$req_port does not fit");
			next;
		    }
		}
		if ($version > 0 && $netscape_only) {
		    LWP::Debug::debug("   domain $domain applies to " .
				      "Netscape-style cookies only");
		    next;
		}

	        LWP::Debug::debug("   it's a match");

		# set version number of cookie header.
	        # XXX: What should it be if multiple matching
                #      Set-Cookie headers have different versions themselves
		if (!$set_ver++) {
		    if ($version >= 1) {
			push(@cval, "\$Version=$version");
		    } elsif (!$self->{hide_cookie2}) {
			$request->header(Cookie2 => '$Version="1"');
		    }
		}

		# do we need to quote the value
		if ($val =~ /\W/ && $version) {
		    $val =~ s/([\\\"])/\\$1/g;
		    $val = qq("$val");
		}

		# and finally remember this cookie
		push(@cval, "$key=$val");
		if ($version >= 1) {
		    push(@cval, qq(\$Path="$path"))     if $path_spec;
		    push(@cval, qq(\$Domain="$domain")) if $domain =~ /^\./;
		    if (defined $port) {
			my $p = '$Port';
			$p .= qq(="$port") if length $port;
			push(@cval, $p);
		    }
		}

	    }
        }

    } continue {
	# Try with a more general domain, alternately stripping
	# leading name components and leading dots.  When this
	# results in a domain with no leading dot, it is for
	# Netscape cookie compatibility only:
	#
	# a.b.c.net	Any cookie
	# .b.c.net	Any cookie
	# b.c.net	Netscape cookie only
	# .c.net	Any cookie

	if ($domain =~ s/^\.+//) {
	    $netscape_only = 1;
	} else {
	    $domain =~ s/[^.]*//;
	    $netscape_only = 0;
	}
    }

    $request->header(Cookie => join("; ", @cval)) if @cval;

    $request;
}

sub extract_cookies
{
    my $self = shift;
    my $response = shift || return;

    my @set = split_header_words($response->_header("Set-Cookie2"));
    my @ns_set = $response->_header("Set-Cookie");

    return $response unless @set || @ns_set;  # quick exit

    my $request = $response->request;
    my $url = $request->url;
    my $req_host = _host($request, $url);
    $req_host = "$req_host.local" unless $req_host =~ /\./;
    my $req_port = $url->port;
    my $req_path = _url_path($url);
    _normalize_path($req_path) if $req_path =~ /%/;

    if (@ns_set) {
	# The old Netscape cookie format for Set-Cookie
        # http://www.netscape.com/newsref/std/cookie_spec.html
	# can for instance contain an unquoted "," in the expires
	# field, so we have to use this ad-hoc parser.
	my $now = time();

	# Build a hash of cookies that was present in Set-Cookie2
	# headers.  We need to skip them if we also find them in a
	# Set-Cookie header.
	my %in_set2;
	for (@set) {
	    $in_set2{$_->[0]}++;
	}

	my $set;
	for $set (@ns_set) {
	    my @cur;
	    my $param;
	    my $expires;
	    for $param (split(/;\s*/, $set)) {
		my($k,$v) = split(/\s*=\s*/, $param, 2);
		$v =~ s/\s+$//;
		#print "$k => $v\n";
		my $lc = lc($k);
		if ($lc eq "expires") {
		    my $etime = str2time($v);
		    if ($etime) {
			push(@cur, "Max-Age" => str2time($v) - $now);
			$expires++;
		    }
		} else {
		    push(@cur, $k => $v);
		}
	    }
	    next if $in_set2{$cur[0]};

#	    push(@cur, "Port" => $req_port);
	    push(@cur, "Discard" => undef) unless $expires;
	    push(@cur, "Version" => 0);
	    push(@cur, "ns-cookie" => 1);
	    push(@set, \@cur);
	}
    }

  SET_COOKIE:
    for my $set (@set) {
	next unless @$set >= 2;

	my $key = shift @$set;
	my $val = shift @$set;

        LWP::Debug::debug("Set cookie $key => $val");

	my %hash;
	while (@$set) {
	    my $k = shift @$set;
	    my $v = shift @$set;
	    my $lc = lc($k);
	    # don't loose case distinction for unknown fields
	    $k = $lc if $lc =~ /^(?:discard|domain|max-age|
                                    path|port|secure|version)$/x;
	    if ($k eq "discard" || $k eq "secure") {
		$v = 1 unless defined $v;
	    }
	    next if exists $hash{$k};  # only first value is signigicant
	    $hash{$k} = $v;
	};

	my %orig_hash = %hash;
	my $version   = delete $hash{version};
	$version = 1 unless defined($version);
	my $discard   = delete $hash{discard};
	my $secure    = delete $hash{secure};
	my $maxage    = delete $hash{'max-age'};
	my $ns_cookie = delete $hash{'ns-cookie'};

	# Check domain
	my $domain  = delete $hash{domain};
	if (defined($domain)
	    && $domain ne $req_host && $domain ne ".$req_host") {
	    if ($domain !~ /\./ && $domain ne "local") {
	        LWP::Debug::debug("Domain $domain contains no dot");
		next SET_COOKIE;
	    }
	    $domain = ".$domain" unless $domain =~ /^\./;
	    if ($domain =~ /\.\d+$/) {
	        LWP::Debug::debug("IP-address $domain illeagal as domain");
		next SET_COOKIE;
	    }
	    my $len = length($domain);
	    unless (substr($req_host, -$len) eq $domain) {
	        LWP::Debug::debug("Domain $domain does not match host $req_host");
		next SET_COOKIE;
	    }
	    my $hostpre = substr($req_host, 0, length($req_host) - $len);
	    if ($hostpre =~ /\./ && !$ns_cookie) {
	        LWP::Debug::debug("Host prefix contain a dot: $hostpre => $domain");
		next SET_COOKIE;
	    }
	} else {
	    $domain = $req_host;
	}

	my $path = delete $hash{path};
	my $path_spec;
	if (defined $path && $path ne '') {
	    $path_spec++;
	    _normalize_path($path) if $path =~ /%/;
	    if (!$ns_cookie &&
                substr($req_path, 0, length($path)) ne $path) {
	        LWP::Debug::debug("Path $path is not a prefix of $req_path");
		next SET_COOKIE;
	    }
	} else {
	    $path = $req_path;
	    $path =~ s,/[^/]*$,,;
	    $path = "/" unless length($path);
	}

	my $port;
	if (exists $hash{port}) {
	    $port = delete $hash{port};
	    if (defined $port) {
		$port =~ s/\s+//g;
		my $found;
		for my $p (split(/,/, $port)) {
		    unless ($p =~ /^\d+$/) {
		      LWP::Debug::debug("Bad port $port (not numeric)");
			next SET_COOKIE;
		    }
		    $found++ if $p eq $req_port;
		}
		unless ($found) {
		    LWP::Debug::debug("Request port ($req_port) not found in $port");
		    next SET_COOKIE;
		}
	    } else {
		$port = "_$req_port";
	    }
	}
	$self->set_cookie($version,$key,$val,$path,$domain,$port,$path_spec,$secure,$maxage,$discard, \%hash)
	    if $self->set_cookie_ok(\%orig_hash);
    }

    $response;
}

sub set_cookie_ok { 1 };

sub set_cookie
{
    my $self = shift;
    my($version,
       $key, $val, $path, $domain, $port,
       $path_spec, $secure, $maxage, $discard, $rest) = @_;

    # path and key can not be empty (key can't start with '$')
    return $self if !defined($path) || $path !~ m,^/, ||
	            !defined($key)  || $key  !~ m,[^\$],;

    # ensure legal port
    if (defined $port) {
	return $self unless $port =~ /^_?\d+(?:,\d+)*$/;
    }

    my $expires;
    if (defined $maxage) {
	if ($maxage <= 0) {
	    delete $self->{COOKIES}{$domain}{$path}{$key};
	    return $self;
	}
	$expires = time() + $maxage;
    }
    $version = 0 unless defined $version;

    my @array = ($version, $val,$port,
		 $path_spec,
		 $secure, $expires, $discard);
    push(@array, {%$rest}) if defined($rest) && %$rest;
    # trim off undefined values at end
    pop(@array) while !defined $array[-1];

    $self->{COOKIES}{$domain}{$path}{$key} = \@array;
    $self;
}

sub save
{
    my $self = shift;
    my $file = shift || $self->{'file'} || return;
    local(*FILE);
    open(FILE, ">$file") or die "Can't open $file: $!";
    print FILE "#LWP-Cookies-1.0\n";
    print FILE $self->as_string(!$self->{ignore_discard});
    close(FILE);
    1;
}

sub load
{
    my $self = shift;
    my $file = shift || $self->{'file'} || return;
    local(*FILE, $_);
    local $/ = "\n";  # make sure we got standard record separator
    open(FILE, $file) or return;
    my $magic = <FILE>;
    unless ($magic =~ /^\#LWP-Cookies-(\d+\.\d+)/) {
	warn "$file does not seem to contain cookies";
	return;
    }
    while (<FILE>) {
	next unless s/^Set-Cookie3:\s*//;
	chomp;
	my $cookie;
	for $cookie (split_header_words($_)) {
	    my($key,$val) = splice(@$cookie, 0, 2);
	    my %hash;
	    while (@$cookie) {
		my $k = shift @$cookie;
		my $v = shift @$cookie;
		$hash{$k} = $v;
	    }
	    my $version   = delete $hash{version};
	    my $path      = delete $hash{path};
	    my $domain    = delete $hash{domain};
	    my $port      = delete $hash{port};
	    my $expires   = str2time(delete $hash{expires});

	    my $path_spec = exists $hash{path_spec}; delete $hash{path_spec};
	    my $secure    = exists $hash{secure};    delete $hash{secure};
	    my $discard   = exists $hash{discard};   delete $hash{discard};

	    my @array =	($version,$val,$port,
			 $path_spec,$secure,$expires,$discard);
	    push(@array, \%hash) if %hash;
	    $self->{COOKIES}{$domain}{$path}{$key} = \@array;
	}
    }
    close(FILE);
    1;
}

sub revert
{
    my $self = shift;
    $self->clear->load;
    $self;
}

sub clear
{
    my $self = shift;
    if (@_ == 0) {
	$self->{COOKIES} = {};
    } elsif (@_ == 1) {
	delete $self->{COOKIES}{$_[0]};
    } elsif (@_ == 2) {
	delete $self->{COOKIES}{$_[0]}{$_[1]};
    } elsif (@_ == 3) {
	delete $self->{COOKIES}{$_[0]}{$_[1]}{$_[2]};
    } else {
	require Carp;
        Carp::carp('Usage: $c->clear([domain [,path [,key]]])');
    }
    $self;
}

sub clear_temporary_cookies
{
    my($self) = @_;

    $self->scan(sub {
        if($_[9] or        # "Discard" flag set
           not $_[8]) {    # No expire field?
            $_[8] = -1;            # Set the expire/max_age field
            $self->set_cookie(@_); # Clear the cookie
        }
      });
}

sub DESTROY
{
    my $self = shift;
    $self->save if $self->{'autosave'};
}


sub scan
{
    my($self, $cb) = @_;
    my($domain,$path,$key);
    for $domain (sort keys %{$self->{COOKIES}}) {
	for $path (sort keys %{$self->{COOKIES}{$domain}}) {
	    for $key (sort keys %{$self->{COOKIES}{$domain}{$path}}) {
		my($version,$val,$port,$path_spec,
		   $secure,$expires,$discard,$rest) =
		       @{$self->{COOKIES}{$domain}{$path}{$key}};
		$rest = {} unless defined($rest);
		&$cb($version,$key,$val,$path,$domain,$port,
		     $path_spec,$secure,$expires,$discard,$rest);
	    }
	}
    }
}

sub as_string
{
    my($self, $skip_discard) = @_;
    my @res;
    $self->scan(sub {
	my($version,$key,$val,$path,$domain,$port,
	   $path_spec,$secure,$expires,$discard,$rest) = @_;
	return if $discard && $skip_discard;
	my @h = ($key, $val);
	push(@h, "path", $path);
	push(@h, "domain" => $domain);
	push(@h, "port" => $port) if defined $port;
	push(@h, "path_spec" => undef) if $path_spec;
	push(@h, "secure" => undef) if $secure;
	push(@h, "expires" => HTTP::Date::time2isoz($expires)) if $expires;
	push(@h, "discard" => undef) if $discard;
	my $k;
	for $k (sort keys %$rest) {
	    push(@h, $k, $rest->{$k});
	}
	push(@h, "version" => $version);
	push(@res, "Set-Cookie3: " . join_header_words(\@h));
    });
    join("\n", @res, "");
}

sub _host
{
    my($request, $url) = @_;
    if (my $h = $request->header("Host")) {
	$h =~ s/:\d+$//;  # might have a port as well
	return $h;
    }
    return $url->host;
}

sub _url_path
{
    my $url = shift;
    my $path;
    if($url->can('epath')) {
       $path = $url->epath;    # URI::URL method
    } else {
       $path = $url->path;           # URI::_generic method
    }
    $path = "/" unless length $path;
    $path;
}

sub _normalize_path  # so that plain string compare can be used
{
    my $x;
    $_[0] =~ s/%([0-9a-fA-F][0-9a-fA-F])/
	         $x = uc($1);
                 $x eq "2F" || $x eq "25" ? "%$x" :
                                            pack("C", hex($x));
              /eg;
    $_[0] =~ s/([\0-\x20\x7f-\xff])/sprintf("%%%02X",ord($1))/eg;
}



package HTTP::Cookies::Netscape;

use vars qw(@ISA);
@ISA=qw(HTTP::Cookies);

sub load
{
    my($self, $file) = @_;
    $file ||= $self->{'file'} || return;
    local(*FILE, $_);
    local $/ = "\n";  # make sure we got standard record separator
    my @cookies;
    open(FILE, $file) || return;
    my $magic = <FILE>;
    unless ($magic =~ /^\# (?:Netscape )?HTTP Cookie File/) {
	warn "$file does not look like a netscape cookies file" if $^W;
	close(FILE);
	return;
    }
    my $now = time() - $EPOCH_OFFSET;
    while (<FILE>) {
	next if /^\s*\#/;
	next if /^\s*$/;
	tr/\n\r//d;
	my($domain,$bool1,$path,$secure, $expires,$key,$val) = split(/\t/, $_);
	$secure = ($secure eq "TRUE");
	$self->set_cookie(undef,$key,$val,$path,$domain,undef,
			  0,$secure,$expires-$now, 0);
    }
    close(FILE);
    1;
}

sub save
{
    my($self, $file) = @_;
    $file ||= $self->{'file'} || return;
    local(*FILE, $_);
    open(FILE, ">$file") || return;

    print FILE <<EOT;
# Netscape HTTP Cookie File
# http://www.netscape.com/newsref/std/cookie_spec.html
# This is a generated file!  Do not edit.

EOT

    my $now = time - $EPOCH_OFFSET;
    $self->scan(sub {
	my($version,$key,$val,$path,$domain,$port,
	   $path_spec,$secure,$expires,$discard,$rest) = @_;
	return if $discard && !$self->{ignore_discard};
	$expires = $expires ? $expires - $EPOCH_OFFSET : 0;
	return if $now > $expires;
	$secure = $secure ? "TRUE" : "FALSE";
	my $bool = $domain =~ /^\./ ? "TRUE" : "FALSE";
	print FILE join("\t", $domain, $bool, $path, $secure, $expires, $key, $val), "\n";
    });
    close(FILE);
    1;
}

1;


};
### End of inlined library HTTP::Cookies.
HTTP::Cookies->import();
}
use URI;
use filetest 'access';

BEGIN { 
Hans2::FindBin->import();
}
BEGIN { 
Hans2::Util->import();
}
BEGIN { 
### Start of inlined library Hans2::OneParamFile.
$INC{'Hans2/OneParamFile.pm'} = './Hans2/OneParamFile.pm';
{
package Hans2::OneParamFile;




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
                          %PARAMS
                           );
        @EXPORT      = (qw(
                          &register_param
                          &register_remove_param
                          &check_param
                           ),@EXP_VAR);
        @NON_EXPORT  = qw(
                          $general_nr
                          $local_off
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

BEGIN { 
Hans2::Cwd->import();
}
BEGIN { 
Hans2::FindBin->import();
}
BEGIN { 
Hans2::Util->import();
}
BEGIN { 
### Start of inlined library Hans2::File.
$INC{'Hans2/File.pm'} = './Hans2/File.pm';
{
package Hans2::File;




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

BEGIN { 
Hans2::FindBin->import();
}

use POSIX qw(locale_h strtod);
use File::Basename;
use File::Spec;
use File::Copy;
use Fcntl;
use filetest 'access';

BEGIN { 
Hans2::Cwd->import();
}
BEGIN { 
Hans2::Util->import();
}
BEGIN { 
Hans2::Debug->import();
}
BEGIN { 
### Start of inlined library Hans2::DataConversion.
$INC{'Hans2/DataConversion.pm'} = './Hans2/DataConversion.pm';
{
package Hans2::DataConversion;



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
                         &anglebracketoptions_decode
                         &anglebracketoptions_encode
                         &xml_quote
                         &xml_unquote
                         &quote_fn
                         &dquote
                         &versionstring_2_vstring
                         &vstring_2_versionstring
                         &soundex
                         &soundex_number
                         &anytext_2_filename
                         &anytext_2_printable
                         &quoted_printable
                         &parse_eq_cl
                         &fileglob_2_perlre
                         &interpret_as_perl_string
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


{

# the format of anglebracketdata is one-line: linebreaks have to be encoded as well.
my $abo_quote=sub {
   my ($txt)=@_;
   $txt=xml_quote($txt);
   $txt =~ s/\n/&HENL;/g;
   return $txt;
   };
my $abo_unquote=sub {
   my ($txt)=@_;
   $txt =~ s/&HENL;/\n/g;
   $txt=xml_unquote($txt);
   return $txt;
   };

sub anglebracketoptions_decode($) {
   my ($string)=@_;
   my @data=($string =~ /\<.*?\>/g);
   foreach(@data){  s/^\<\s*//;s/\s*\>$//; };
   @data=map {$abo_unquote->($_)} grep {$_} @data;
   my %data;
   foreach(@data) {
      /(\w+)[=:]?(.*)/ || die "did not understand record $_ in anglebrackets $string\n";
      my ($key,$val)=($1,$2);
      ($key,$val)=map {s/^\s+//;s/\s+$//;$_} ($key,$val);
      $data{$key}=$val;
      }
   return %data;
}      
   
sub anglebracketoptions_encode(%) {
   my (%data)=@_;
   my @data;
   foreach my $key (sort keys %data) {
      my $val=$data{$key};
      my $str="$key";
      $str.=":$val" if defined $val and $val ne "";
      push @data,$abo_quote->($str);
      }
   return "<".join("> <",@data).">";
}      

}

# I don't really know what UTF-8 characters are.
# I don't really understand how you write UTF-8 characters in XML, either.
# But thats what this function does, obviously.
sub XmlUtf8Encode($) {
# borrowed from XML::DOM
    my ($n) = @_;
    if ($n < 0x80) {
        return chr ($n);
        } 
    elsif ($n < 0x800) {
        return pack ("CC", (($n >> 6) | 0xc0), (($n & 0x3f) | 0x80));
        } 
    elsif ($n < 0x10000) {
        return pack ("CCC", (($n >> 12) | 0xe0), ((($n >> 6) & 0x3f) | 0x80),
                     (($n & 0x3f) | 0x80));
        } 
    elsif ($n < 0x110000) {
        return pack ("CCCC", (($n >> 18) | 0xf0), ((($n >> 12) & 0x3f) | 0x80),
                     ((($n >> 6) & 0x3f) | 0x80), (($n & 0x3f) | 0x80));
        }
    return $n;
}

# quotes a scalar to be used as XML - text. 
sub xml_quote($) {
   my ($string)=@_;
   for ($string) {
      s/\&/\&amp;/ig;
      s/\</\&lt;/ig;
      s/\>/\&gt;/ig;
      s/\"/\&quot;/ig;
      s/([\x80-\xFF])/&XmlUtf8Encode(ord($1))/ge;
   }
   return $string;
}   

# un-escape XML base entities
sub xml_unquote($) {
    my ($string)=@_;
    for($string) {
       s/&lt;/</ig;
       s/&gt;/>/ig;
       s/&apos;/'/ig;
       s/&quot;/"/ig;
       s/&amp;/&/ig;
       }
    return $string;
}


use File::Spec;
my $filesep;
{   my $d=File::Spec->catfile("a","b");
   $filesep=$1 if $d =~ /^a(.)b$/;
}
sub quote_fn($) {
   my ($name)=@_;
   $name =~ s/"/\\"/g;
   my $allowed_chars='\w\-\_\.';
   $allowed_chars.=quotemeta($filesep) if defined $filesep;
   $name='"'.$name.'"' if $name =~ /[^$allowed_chars]/o;
   return $name;
}


sub dquote($) {
   my ($name)=@_;
   $name =~ s/"/\\"/g;
   $name='"'.$name.'"';
   return $name;
}


sub versionstring_2_vstring($) {
   my ($str)=@_;
   return undef if $str !~ /^[\d\.]+$/;
   return eval "v$str";
}   

sub vstring_2_versionstring($) {
   my ($v)=@_;
   return sprintf("%vd",$v);
}  
 

sub soundex($) {
   my ($string)=@_;
   return if !defined $string;
   return if $string eq "";
   for($string) {
      $_=uc($_);
      tr/A-Z//cd;
      my ($f) = /^(.)/;
      tr/AEHIOUWYBFPVCGJKQSXZDTLMNR/00000000111122222222334556/;
      my ($fc) = /^(.)/;
      s/^$fc+//;
      tr///cs;
      tr/0//d;
      $_ = $f . $_ . '000';
      s/^(.{4}).*/$1/;
      }
   return $string;   
}

sub soundex_number($) {
   my ($string)=@_;
   return if !defined $string;
   return if $string eq "";
   $string=soundex($string);
   $string =~/^(.)(.)(.)(.)$/ || die "bad string $_\n";
   my ($n1,$n2,$n3,$n4)=($1,$2,$3,$4);
   return $n4+6*$n3+6*6*$n2+6*6*6*(ord($1)-ord("A"));
}


sub anytext_2_filename($) {
   my ($txt)=@_;
   for($txt) {
      s/([^\w\-\_\.])/sprintf("=%02X", ord($1))/eg; 
      }
   return $txt;
}


use Text::Tabs;
sub anytext_2_printable($) {
   my ($txt)=expand(@_);
   $txt =~ s/\n\r/\n/g;
   $txt =~ s/\r\n/\n/g;
   $txt =~ s/(\s)/($1 eq "\n") ? ("\n") : (" ")/eg;
   $txt =~ s/([^ \n\w\~\!\@\#\$\%\^\&\*\(\)\_\+\`\-\=\[\]\{\}\|\;\'\:\"\,\.\/\<\>\?])/sprintf("=%02X", ord($1))/eg;  # rule #2,#3
   return $txt;
}


sub quoted_printable($) {
   my ($txt)=@_;
   $txt =~ s/([^ \t\n!-<>-~])/sprintf("=%02X", ord($1))/eg;  # rule #2,#3
   $txt =~ s/([ \t]+)$/join('', map { sprintf("=%02X", ord($_)) } split('', $1))/egm;                        # rule #3 (encode whitespace at eol)
   return $txt;
}


sub parse_eq_cl($) {
   my ($cl)=@_;
   return if !$cl;
   $cl =~ s/^\s+//;
   $cl =~ s/\s+$//;
   my %args=();
   my $arg;
   my $val;

   ($cl =~ /(\w+)=/g) && ($arg=$1);
   while ($cl =~ /\G(.*?)\s+(\w+)=/gc) {
      $val=$1;
      $args{lc($arg)}=$val;
      $arg=$2;
      }
   ($cl =~ /\G(.*)/g) && ($val=$1);
   $args{lc($arg)}=$val;

   return %args;   
   
}   


sub fileglob_2_perlre($) {
   my ($glob)=@_;
   return undef if !defined $glob;
   return ""    if $glob eq '';
   $glob='^\Q'.$glob.'\E$';
   $glob =~ s/\*/\\E.*\\Q/g;
   $glob =~ s/\?/\\E.\\Q/g;
   $glob =~ s/\\Q\\E//g;
   $glob =~ s/\\E\\Q//g;
   $glob =~ s/\\Q\\E//g;
   $glob =~ s/\\E\\Q//g;
   $glob =~ s/\\Q(.*?)\\E/quotemeta($1)/eg;
   return $glob;
}


sub interpret_as_perl_string($) {
   my ($in)=@_;
   my $out;
   eval '$out="'.$in.'"';
   return $out;
}   


END {}

1;

};
### End of inlined library Hans2::DataConversion.
Hans2::DataConversion->import();
}

my $filetest_ops_work_correctly=0;


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


sub file_extension($) {
   my ($fn)=@_;
   return (fileparse($fn,qr/\.\w{2,4}/))[2];
}   


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


sub mtime($) {
   my ($fn)=@_;
#     ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
#     $atime,$mtime,$ctime,$blksize,$blocks)
   my $time=(stat($fn))[9];
   return undef if !-e $fn;
   return $time;
}       


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
   

sub my_glob($$;$) {
   my ($dir,$pattern,$validator)=@_;
   
   return perlre_glob($dir,fileglob_2_perlre($pattern),$validator);
   
}

END {}

1;

};
### End of inlined library Hans2::File.
Hans2::File->import();
}
BEGIN { 
Hans2::Debug->import();
}
BEGIN { 
### Start of inlined library Hans2::Debug::Indent.
$INC{'Hans2/Debug/Indent.pm'} = './Hans2/Debug/Indent.pm';
{
package Hans2::Debug::Indent;




BEGIN {
        use Exporter   ();
        use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS @EXP_VAR @NON_EXPORT);
BEGIN { 
### Start of inlined library Hans2::AutoQuit.
$INC{'Hans2/AutoQuit.pm'} = './Hans2/AutoQuit.pm';
{
package Hans2::AutoQuit;




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

sub new($&) {
   my ($proto,$func) = @_;
   
   if(!ref($func)) {
      die "Scalar given to AFAutoQuit\n";
      }
   if(ref($func) ne "CODE") {   
      die "Not a code-ref given to AFAutoQuit\n";
      }

   my $class = ref($proto) || $proto;

   my $self  = {
          'func'     =>  $func,
          'active'   =>  1
          };

   bless ($self, $class);
   return $self;
}   

sub delete($) {
   my ($self)=@_;
   return if !$self;
   return if !%$self;
   return if !$self->{'active'};
   $self->{'active'}=0;
   $self->{'func'}->() if $self->{'func'};
}   

sub DESTROY($) {
   my ($self)=@_;
   $self->delete();
}   
   
END {}

1;

};
### End of inlined library Hans2::AutoQuit.
Hans2::AutoQuit->import();
}

#        $Exporter::Verbose=1;
        # set the version for version checking
        $VERSION     = 1.00;
        # if using RCS/CVS, this may be preferred
#        $VERSION = do { my @r = (q$Revision: 2.21 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };
        # The above must be all one line, for MakeMaker

        @ISA         = qw(Exporter Hans2::AutoQuit);

        @EXP_VAR     = qw(
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

BEGIN { 
Hans2::Debug->import();
}

sub new($$) {
   my ($proto,$msg) = @_;

   my $class = ref($proto) || $proto;
   
   Hans2::Debug::push_indent($msg);
   
   my $self=$class->SUPER::new( sub {Hans2::Debug::pop_indent();});
   
   bless ($self,$class);

   return $self;
}   
      
END {}

1;

};
### End of inlined library Hans2::Debug::Indent.
Hans2::Debug::Indent->import();
}
BEGIN { 
### Start of inlined library Hans2::Constants.
$INC{'Hans2/Constants.pm'} = './Hans2/Constants.pm';
{
package Hans2::Constants;



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
                           $author_email
                           $author_name
                           $homepage
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

END {}

1;

};
### End of inlined library Hans2::Constants.
Hans2::Constants->import();
}
BEGIN { 
Hans2::DataConversion->import();
}

$general_nr=-100;
$local_off=0;

my $comment='#';

my %registered_params=();
my %registered_remove_params=();

my @initial_comment;

sub make_initial_comment() {
   @initial_comment=(
   'In this configuration file, you can customize all the perl scripts by',
   "$author_name <$author_email>.",
   '',
   'Please ONLY edit the values of each item. The comment sections as well as',
   'those "<nr:6> <lastdefval:skfdjdsj>" lines at the top of each comment section',
   'are used by the programs. Any changes by you will either be deleted by the next',
   'time a script is run or in the worst case, make the configuration file unusable.',
   );
   unshift @initial_comment,'';
   push    @initial_comment,'';
   foreach(@initial_comment) {
      s/\s+$//;
      $_=sprintf("%-82s",$_);
      $_.='#';
      }
   unshift @initial_comment, ('#' x 83 );
   push    @initial_comment, ('#' x 83 );
   };


sub register_param($%) {
   my ($key,%opts)=@_;
   $registered_params{$key}=\%opts;
}   

sub register_remove_param($) {
   my ($key)=@_;
   $registered_remove_params{$key}=1;
}   

# in: filename
# out: original file contents
#      hash of
#      <var name> => ref of config hash
sub read_cfg($) {
   my ($file)=@_;
   my $txt=readfile($file) || die "could not read configuration file $file\n";
   my @txt=split(/\n/,$txt);
   my @comment=();
   my %cfg;
   my $nr=0;
   if($txt[0] =~ /^#+$/) {
      while($_=shift @txt) {
         last if !$_;
         last if /^[^#]/;
         }
      }   
   foreach (@txt) {
      s/^\s+//;
      s/\s+$//;
      next if !$_;
      if(/^${comment}(.*)/) {
         my $c=$1;
         $c=~ s/^\s//;
         push @comment,$c;
         }
      elsif(/^(\w+)\s*\=\s*(.*)$/) {
         my ($key,$val)=($1,$2);
         my @c=@comment;
         my $first_line=shift @c;
         while(!$c[0]) {
            shift @c;
            };
         while(!$c[$#c]) {
            pop @c;
            };
         my %first_params=anglebracketoptions_decode($first_line);
         if(!defined $first_params{'nr'}) {
            my $msg=<<EOT;
Config file $file, key $key: did not understand first line. 
Possible reasons:

Reason:   You edited that config file inappropriately
Solution: You might _not_ edit the comments section of the config file.
          Only adjust the value of each config key, nothing else.
          Delete the file and let the scripts re-create the default 
          config file for you.
          
Reason:   A programming error in the perl scripts
Solution: Contact the author via e-mail at $author_email and send him
          $file
             
EOT
            die $msg;
            }   
         $cfg{$key}={'read'      => $val,
                     'comment'   => \@c,
                     %first_params,
                     };
         @comment=();            
         $nr++;
         }
      else {
         die "did not understand line <$_> in configuration file $file\n";
         }
      }
   return ($txt,%cfg);      
}

# sort 2 parameter hashes by key name
sub sort_param($$%) {
   my ($a,$b,%cfg)=@_;
   if(defined $cfg{$a}->{'nr'} and defined $cfg{$b}->{'nr'}) {
      my $r=$cfg{$a}->{'nr'} <=> $cfg{$b}->{'nr'};
      return $r if $r;
      }
   return $a cmp $b;
}   

# in: filename and config hash
# out: write config file
sub write_cfg($$%) {
   my ($file,$ori_txt,%cfg)=@_;
   my $txt="";

   make_initial_comment();

   foreach(@initial_comment) {
      if(/^#+$/) {
         $txt.="##$_\n";
         }
      else {
         $txt.="# $_\n";
         }
      }
   $txt.="\n";   
   foreach my $key (sort { sort_param($a,$b,%cfg)} keys %cfg) {
      my $param=$cfg{$key};
      my @comment=@{$param->{'comment'}};
      my $val=$param->{'write'};
      $val=$param->{'read'} if !defined $param->{'write'};
      my %firstparam=('nr'=> $param->{'nr'});
      $firstparam{'lastdefval'}=$param->{'lastdefval'} if defined $param->{'lastdefval'};
      $firstparam{'lastdefval'}=$param->{'default'} if defined $param->{'default'};
      $txt.="# ".anglebracketoptions_encode(%firstparam)."\n";
      $txt.="#\n";
      foreach(@comment) {
         s/\s+$//;
         $txt.="# $_\n";
         }
      $txt.="\n";
      $txt.=sprintf("%-30s",$key)." = $val\n";
      $txt.="\n";
      }
   if($txt eq $ori_txt) {
      writedebug("not updating config file $file since it would be unchanged");
      return;
      }   
   writefile($file,$txt) || die "could not write to configuration file $file\n";
}      


sub check_param(%) {
   my (%opts)=@_;
   
   my $file_base=$opts{'file'};
   
   my $ind=Hans2::Debug::Indent->new("Processing $file_base config file");
   
   my $cwd=getcwd();


   #
   # add default remove parameters from register_remove_param()
   #
   my @remove;
   if($opts{'remove'} or %registered_remove_params) {
      my %rem=%registered_remove_params;
      foreach (@{ $opts{'remove'}}) {
         $rem{$_}=1;
         }
      @remove=keys %rem;
      }   
      

   #
   # add default parameters from register_param() and validate
   #
   # default it with the registered parameters
   my %check=%registered_params;
   # now add/override the given parameters
   { my %check_p=%{ $opts{'check'} };
   foreach my $key (keys %check_p) {
      $check{$key}=$check_p{$key};
      }
   }   
   
   #
   foreach my $key (keys %check) {
      foreach my $what ("nr","default","comment") {
         exists $check{$key}->{$what} || die "invalid parameter $key does not include $what\n";
         }
      }
   
   #
   # determine whether we already have a config file; reading of the file
   #
   
   my @file_tries=($file_base,
                   File::Spec->catfile($cwd,$file_base),
                   File::Spec->catfile($Bin,$file_base)
                   );
   my $file;
   foreach (@file_tries) {
      if(-f $_ and -r $_) {
         $file=$_;
         last;
         }
      }   
   my ($ori_cfg,%cfg);
   if(!$file) {
      $file=File::Spec->catfile($Bin,$file_base);
      warn "making new config file $file\n";
      %cfg=();
      $ori_cfg="";
      }
   else {   
      ($ori_cfg,%cfg)=read_cfg($file);
      }

   foreach my $rem_key (@remove) {
      if(exists $cfg{$rem_key}) {
         warn "deleting obsolete variable $rem_key\n";
         delete $cfg{$rem_key};
         }
      }
      
   # %check : parameter to this func, has keys
   #          comment               - comment block
   #          default               - default value 
   #          env        (optional) - env vars to find it in
   #          nr                    - pos in conf file
   #          
   # %cfg   : from config file, has keys
   #          comment               - old comment block, discard
   #          read                  - current val from config file
   #          nr                    - pos in conf file
   #          lastdefval (optional) - default value from last run
   #
   # %cfg gets updated, keys are added:
   #          cur                   - current, effective value
   #          write                 - value to write back into file

   foreach my $chk_key (sort {sort_param($a,$b,%check)} keys %check) {
   
      my $from_prog=$check{$chk_key};
      my $from_file=$cfg{$chk_key};
      
      $from_prog->{'write'}=$from_prog->{'default'};
      $from_prog->{'lastdefval'}=$from_prog->{'default'};
      if($from_file) {
         # if the key was already in the config file, take its value IF its not the previous default
         if(!$from_file->{'lastdefval'} or $from_file->{'lastdefval'} ne $from_file->{'read'}) {
            $from_prog->{'write'}=$from_file->{'read'};
            }
         }
      # otherwise, take what was given to this func, but make sure there is a 'nr' parameter   
      else {
         warn "Adding variable ".sprintf("%-30s",$chk_key)."=".$from_prog->{'default'}." to config file $file\n";
         }
      %{$cfg{$chk_key}}=%{$from_prog};
      $from_file=$cfg{$chk_key};
      # now everything is in %cfg and we evaluate the record   

      my $env=$from_file->{'env'};
      my @env;
      my $env_val=undef;
      # generate the list of env vars to check
      if($env) {
         if(ref($env)) {
            @env=@$env;
            }
         else {
            @env=($env);
            }
         }   
      # check all the environment variables 
      foreach $env (@env) {
         next if !defined $ENV{$env};
         $env_val=$ENV{$env};
         writedebug("found envval $env=$env_val for $chk_key");
         last;
         }

      # the correct value is the environment value, if found, otherwise the value from the config file
      $env_val=$from_file->{'write'} if !defined $env_val;   
      # now $env_val contains the value we are looking for, set 'cur' to it
      $from_file->{'cur'}=$env_val;
      # set the environment variables to the value, if we are calling other programs that depend on it
      foreach $env (@env) {
         $ENV{$env}=$env_val;
         }
      writedebug(sprintf("%-30s",$chk_key)."= $env_val (".$from_file->{'nr'}.")");
      }         
   
   write_cfg($file,$ori_cfg,%cfg);
   
   %PARAMS=();
   foreach my $key (keys %cfg) {
      $PARAMS{$key}=$cfg{$key}->{'cur'};
      }
   
  return %PARAMS;
}   
         
END {}

1;

};
### End of inlined library Hans2::OneParamFile.
Hans2::OneParamFile->import();
}
BEGIN { 
Hans2::File->import();
}
BEGIN { 
Hans2::Debug->import();
}
BEGIN { 
Hans2::Debug::Indent->import();
}
BEGIN { 
### Start of inlined library Hans2::OneParamFile::StdConf.
$INC{'Hans2/OneParamFile/StdConf.pm'} = './Hans2/OneParamFile/StdConf.pm';
{
package Hans2::OneParamFile::StdConf;




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

BEGIN { 
Hans2::FindBin->import();
}
BEGIN { 
Hans2::OneParamFile->import();
}

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

};
### End of inlined library Hans2::OneParamFile::StdConf.
Hans2::OneParamFile::StdConf->import();
}
BEGIN { 
Hans2::DataConversion->import();
}
BEGIN { 
Hans2::Constants->import();
}


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

};
### End of inlined library Hans2::WebGet.
Hans2::WebGet->import();
}
BEGIN { 
### Start of inlined library Hans2::Units.
$INC{'Hans2/Units.pm'} = './Hans2/Units.pm';
{
package Hans2::Units;


require 5.006;


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
                        &convert_units
                        &convert_units_factor
                       ),@EXP_VAR);
        %EXPORT_TAGS = ();     # eg: TAG => [ qw!name1 name2! ],

        # your exported package globals go here,
        # as well as any optionally exported functions
#        @EXPORT_OK     = qw($MY_STDOUT $MY_STDERR $MY_STDIN $PROGRAM $PROGRAM_UC); 
        @EXPORT_OK   = qw();
        @NON_EXPORT  = qw(
                         ); 
        
}        

use vars      @EXP_VAR;
use vars      @EXPORT_OK;
use vars      @NON_EXPORT;

BEGIN { 
### Start of inlined library Hans2::Package.
$INC{'Hans2/Package.pm'} = './Hans2/Package.pm';
{
package Hans2::Package;




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
                           &try_to_load
                           &import_if_not_already
                           &possible_packages
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

# in:  a module name (as a file)
# out: 1 if found under @INC
#      or undef if no success
#
# it searches all of @INC for this module
sub found_in_INC($) {
   my ($fn)=@_;

   # maybe we already know?
   return 1 if $INC{$fn};
   
   # look in @INC   
   foreach(@INC) {
      return 1 if (-f File::Spec->catfile($_,$fn)) && (-r File::Spec->catfile($_,$fn));
      }

   # failure
   return undef;
}   


sub try_to_load($;$) {
   my ($modname,$list)=@_;
   
   # success if its already loaded
   return 1 if $INC{$modname};
   my $fn;
   # make $modname into a honest module name
   $modname =~ s/\.pm$//;
   $modname =~ s/\//::/g;
   return 1 if $INC{$modname};
   # make $fn into a honest filename
   $fn = $modname;
   $fn .= ".pm" if $fn !~ /\.pm$/;
   $fn = File::Spec->catdir(split(/::/,$fn));
   return 1 if $INC{$fn};
   
   # fail if file can't be found
   return 0 if ! found_in_INC($fn);
   
   # fail if it can't be loaded
   eval { require $fn || return 0; 1 } || return 0;
   
   # import
   my $callpkg=caller;
   my $import_stmt="package $callpkg; ";
   if($list && (ref($list)) && (ref($list) eq "ARRAY")) {
      $import_stmt.="import $modname (".join(", ",@$list).");";
      }
   else {
      $import_stmt.="import $modname;";
      }   
   eval $import_stmt;   

   # success
   return 1;
   
}


sub import_if_not_already($;$) {
   my ($mod,$list)=@_;
   if(!try_to_load($mod,$list)) {
      my $msg="";
      if($list) {
         $msg='('.join(", ",@$list).')';
         }
      die "could not load $mod $msg\n";
      }
   return 1;   
}


sub possible_packages(;$) {
   my ($prefix)=@_;
   
   $prefix = File::Spec->catdir(split(/::/,$prefix)) if $prefix;

   my %f;
   foreach my $dir (@INC) {
      next if !$dir;
      next if !-d $dir;
      next if !-r $dir;

      my $dir2=$dir;
      $dir2=File::Spec->catdir($dir2,$prefix) if $prefix;
   
      foreach my $file (my_glob($dir2,'*.pm',sub {-f $_ and -r $_})) {
         $file =~ s/\.pm$//;
         $f{$file}=1;
         }
      }
   my @f=sort keys %f;
   return @f;
}



END {}

1;

};
### End of inlined library Hans2::Package.
Hans2::Package->import();
}

my $GIGA=1e9;
my $MICRO=1e-6;

my $have_many_units=try_to_load('Math::Units');

my %predef_conv=(
   'deg'   => { 'km'    => 60 * 1.852 ,
              },
   'mile'  => { 'km'    => 1.609344 ,
              },
   'knots' => { 'mp/h'  => 1.1507771555,
                'km/h'  => 1.852,
              },
   'inch'  => { 'cm'    => 2.54,
                'm'     => 2.54 / 100,
              },
   'g/cc'  => { 'kg/m3' => 1000,
              },
   'F'     => { 'C'     => sub { ($_ - 32)*5/9;},
              },            
   'C'     => { 'F'     => sub { $_*9/5 + 32;},
              },         
   'rad'   => { 'deg'   => 180/(atan2(1,1)*4),
              },
   'GPa'   => { 'Pa'    => $GIGA,
              },
   'kg'    => { 'g'     => 1000,
              },
   'µsec'  => { 'sec'   => $MICRO,
              },
         );   

my %normalize_unit=(
   '"'          => 'inch', 
   'inches'     => 'inch',
   'in'         => 'inch',
   'gcc'        => 'g/cc',
   'kgm3'       => 'kg/m3',
   'kmh'        => 'km/h',
   'mph'        => 'mp/h',
   'usec'       => 'µsec',
   ); 


sub convert_units($$$) {
   my ($num,$old_unit,$new_unit)=@_;
   die "asked to convert unit on non defined value\n" if !defined $num;
   die "asked to convert value $num from <none> unit?!\n" if !$old_unit;
   die "asked to convert value $num from $old_unit unit to <none>?!\n" if !$new_unit;
   $old_unit=$normalize_unit{$old_unit} if exists $normalize_unit{$old_unit};
   $new_unit=$normalize_unit{$new_unit} if exists $normalize_unit{$new_unit};
   return $num if $new_unit eq $old_unit;
   # first try if forward conversion exists
   if(exists $predef_conv{$old_unit} and exists $predef_conv{$old_unit}->{$new_unit}) {
      my $conv=$predef_conv{$old_unit}->{$new_unit};
      if(ref($conv)) {
         for($num) {
            return $conv->();
            }
         }
      else {
         return $num * $conv;
         }      
      }
   # if reverse conversion exists as a constant, apply that one     
   if(exists $predef_conv{$new_unit} and exists $predef_conv{$new_unit}->{$old_unit}) {
      my $conv=$predef_conv{$new_unit}->{$old_unit};
      if(!ref($conv)) {
         return $num / $conv;
         }      
      }
   # still not found? Try Math::Units if available   
   if($have_many_units) {
      return Math::Units::convert($num,$old_unit,$new_unit);
      }
   # give up   
   die "could not convert $num from $old_unit to $new_unit\n";
}   


sub convert_units_factor($$) {
   my ($old_unit,$new_unit)=@_;
   return convert_units(1,$old_unit,$new_unit)-convert_units(0,$old_unit,$new_unit);
}   


sub add_rule($$$) {
   my ($old_unit,$new_unit,$rule)=@_;
   my $old=$predef_conv{$old_unit}->{$new_unit};
   $predef_conv{$old_unit}->{$new_unit}=$rule;
   return $old;
   }

END {

}

1;

};
### End of inlined library Hans2::Units.
Hans2::Units->import();
}
BEGIN { 
### Start of inlined library Hans2::Math.
$INC{'Hans2/Math.pm'} = './Hans2/Math.pm';
{
package Hans2::Math;




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
                         &sgn
                         &sgn0
                         &deg_2_rad
                         &rad_2_deg
                         &sqr
                         &tan
                         &acos
                         &asin
                         &atan
                         &angle_difference
                         &PI
                         &round
                         &floor
                         &linear_regression
                         &correlation
                         &autocorrelation
                         &convolution
                         &is_even
                         &norm_2_difference
                         &norm_2
                         &mean
                         &stddev
                         &statistics
                         &difference_2
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

BEGIN { 
### Start of inlined library Hans2::Algo.
$INC{'Hans2/Algo.pm'} = './Hans2/Algo.pm';
{
package Hans2::Algo;



require 5.006;

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

# export variables
        @EXP_VAR     = qw(
                           );
# export functions
        @EXPORT      = (qw(
                       &split_half
                       &sum
                       &sum_simple
                       &sum2
                       &max
                       &max_simple
                       &min  
                       &min_simple  
                       &firstgood
                       &allgood
                       &random_array_elem
                       &samearray
                       &uniq
                       &uniq_simple
                       &uniq_global
                       &fisher_yates_shuffle
                       &fisher_yates_shuffled
                           ),@EXP_VAR);
# non export variables
        @NON_EXPORT  = qw(
                           );
# optional export variables
        @EXPORT_OK   = qw();
        %EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],
        

        
}        

# exported variables
use vars      @EXP_VAR;
# exportable variables
use vars      @EXPORT_OK;
#non exported package globals
use vars      @NON_EXPORT;


sub split_half(@) {
   my (@args)=@_;
   my $num=scalar(@args);
   die "split_half(): given array of size ".$num." is not even\n" if int($num/2)*2 != $num;
   my @x=@args[0      .. $num/2-1];
   my @y=@args[$num/2 .. $num-1];
   return (\@x,\@y);
}   


sub sum($@) {
   my ($fun,@ar)=@_;
   die "sum(): first arg no fun-ref\n" if !ref($fun);
   die "sum(): first arg no fun-ref\n" if ref($fun) ne 'CODE';
   my $sum=0;

   foreach(@ar) {
      $sum+=$fun->($_);
      }

   return $sum;   
}


sub sum_simple(@) {
   my (@ar)=@_;
   my $sum=0;

   foreach(@ar) {
      $sum+=$_;
      }

   return $sum;   
}


sub sum2($@) {
   my ($fun,@ar)=@_;
   my ($x,$y)=split_half(@ar);
   my $sum=0;
   for(my $i=0;$i<scalar(@$x);$i++) {
      $sum+=$fun->($x->[$i],$y->[$i]);
      }
   return $sum;
}         
   

sub max($@) {
   my ($func,@args)=@_;
   return undef if !@args;
   die "max(): first arg is no fun-ref" if !ref($func);
   die "max(): first arg is no fun-ref" if ref($func) ne 'CODE';
   my $extr=shift @args;
   my $extrfunc;
   for($extr) {
      $extrfunc=$func->($_);
      }
   foreach(@args){
      my $this=$func->($_);
      if($this>$extrfunc) {
         $extr=$_;
         $extrfunc=$this;
         }
      }
   return $extr;   
}


sub max_simple(@) {
   my (@args)=@_;
   return undef if !@args;
   my $extr=shift @args;
   foreach(@args){
      $extr=$_ if $_>$extr;
      }
   return $extr;   
}



sub min($@) {
   my ($func,@args)=@_;
   return undef if !@args;
   die "min(): first arg is no fun-ref" if !ref($func);
   die "min(): first arg is no fun-ref" if ref($func) ne 'CODE';
   my $extr=shift @args;
   my $extrfunc;
   for($extr) {
      $extrfunc=$func->($_);
      }
   foreach(@args){
      my $this=$func->($_);
      if($this<$extrfunc) {
         $extr=$_;
         $extrfunc=$this;
         }
      }
   return $extr;   
}


sub min_simple(@) {
   my (@args)=@_;
   return undef if !@args;
   my $extr=shift @args;
   foreach(@args){
      $extr=$_ if $_<$extr;
      }
   return $extr;   
}


sub firstgood(&@) {
   my ($validator,@tries)=@_;
   die "firstgood(): first arg is no fun-ref" if !ref($validator);
   die "firstgood(): first arg is no fun-ref" if ref($validator) ne 'CODE';
   foreach(@tries) {
      return $_ if $validator->($_);
      }
   return undef;
}      


sub random_array_elem(@) {
   $_[int(rand(scalar(@_)))];
}   


sub samearray($$) {
   my ($a1,$a2)=@_;
   die "samearray(): first arg no array-ref\n" if !ref($a1);
   die "samearray(): first arg no array-ref\n" if ref($a1) ne 'ARRAY';
   die "samearray(): second arg no array-ref\n" if !ref($a2);
   die "samearray(): second arg no array-ref\n" if ref($a2) ne 'ARRAY';
   return 0 if scalar(@$a1) != scalar(@$a2);
   my $same=1;
   for(my $i=0;$i < scalar(@$a1);$i++) {
      return 0 if $a1->[$i] ne $a2->[$i];
      }
   return 1;
}      


sub uniq($@) {
   my ($is_eq,@ar)=@_;
   return () if !@ar;
   die "uniq(): first arg is no fun-ref" if !ref($is_eq);
   die "uniq(): first arg is no fun-ref" if ref($is_eq) ne 'CODE';
   
   my $last=shift @ar;
   my @ret=($last);
   foreach(@_) {
      if(!$is_eq->($_,$last)) {
         $last=$_;
         push @ret,$_;
         }
      }
  return @ret;
}         
      

sub uniq_simple(@) {
   my (@ar)=@_;
   return () if !@ar;
   
   my $last=shift @ar;
   my @ret=($last);
   foreach(@_) {
      if($_ != $last) {
         $last=$_;
         push @ret,$_;
         }
      }
  return @ret;
}         


sub uniq_global(@) {
   return () if !@_;
   my %seen;
   return grep { ! $seen{$_}++ } @_;
}         

      
sub fisher_yates_shuffle(\@) {
   my ($array)=@_;
   my $i;
   for ($i = scalar(@$array); --$i; ) {
      my $j = int rand ($i+1);
      next if $i == $j;
      @$array[$i,$j] = @$array[$j,$i];
      }
}

sub fisher_yates_shuffled(@) {
   my (@array)=@_;
   my $i;
   for ($i = scalar(@array); --$i; ) {
      my $j = int rand ($i+1);
      next if $i == $j;
      @array[$i,$j] = @array[$j,$i];
      }
   return @array;   
}

  

END { }

1;

};
### End of inlined library Hans2::Algo.
Hans2::Algo->import();
}


use constant PI => atan2(1,1)*4;


sub sgn($) {
   my ($num)=@_;
   return ( ($num<0) ? -1 : 1 );
   }


sub sgn0($) {
   my ($num)=@_;
   return 0 if !$num;
   return ( ($num<0) ? -1 : 1 );
   }


sub sqr($) {
   my ($x)=@_;
   return $x * $x;
}   


sub tan($) { 
   my ($arc)=@_;
   return sin($arc)/cos($arc);
}


sub acos($) { 
   my ($arc)=@_;
   return 0 if ($arc eq 1); # fix for rounding imperfection
   atan2( sqrt(1 - $arc * $arc), $arc ) 
}


sub asin { 
   my ($arc)=@_;
   return atan2($arc, sqrt(1 - $arc * $arc)) 
}


sub atan {
   my ($arc)=@_;
   
   return 0 if !$arc;
   return atan2(sqrt(1+sqr($arc)),sqrt(1+1/sqr($arc))) if $arc>0;
   return -atan2(sqrt(1+$_[0]*$_[0]),sqrt(1+1/($_[0]*$_[0])));
}


sub deg_2_rad($)   { $_[0] * PI / 180 }
sub rad_2_deg($)   { $_[0] * 180 / PI }


sub angle_difference($$$$) {
	my ($lat1,$lat2,$long1,$long2) = map { deg_2_rad($_) } @_;
	my $angle = acos( sin($lat1) * sin($lat2) + cos($lat1) * cos($lat2) * cos($long2 - $long1) );
	# to convert to km: $angle * 60 * 1.852
	return rad_2_deg($angle);
}


sub round($) {
    my($number) = @_;
    return int($number + .5 * ($number <=> 0));
}


sub floor {
   my ($num)=@_;
   my $neg   = ($num < 0);
   my $asint = int($num);
   my $exact = ($num == $asint);

   return ($exact ? $asint : ($neg ? $asint - 1 : $asint));
}


sub average(@) {
   my (@data)=@_;
   return undef if !@data;
   my $sum=0;
   foreach(@data) {
      $sum+=$_;
      }
   return $sum/scalar(@data);
}      


sub linear_regression(@) {
   my ($x,$y)=split_half(@_);
   my @x=@$x;
   my @y=@$y;
   my $x_avg=sum_simple(@x)/scalar(@x);
   my $y_avg=sum_simple(@y)/scalar(@y);
   my $SS_xx=sum( sub {sqr($_-$x_avg);},        @x);
   my $SS_yy=sum( sub {sqr($_-$y_avg);},        @y);
   my $SS_xy=sum2(sub {($_[0]-$x_avg)*($_[1]-$y_avg)},@x,@y);
   my $rel=$SS_xy/$SS_xx;
   my $abs=$y_avg-$rel*$x_avg;
   my $r=$SS_xy/sqrt($SS_xx * $SS_yy);
   
   return ($abs,$rel,$r);   
} 



sub correlation($$) {
   my ($x,$y)=@_;
   my @z;
   my $length_x=scalar(@$x);
   my $length_y=scalar(@$y);
   my $length_z=scalar(@$x)+scalar(@$y)-1;
   $#z=$length_z-1;
   for(my $i=0;$i<$length_z;$i++) {
#      print sprintf("%-2s",$i).": ";
      for(my $yi=0;$yi<$length_y;$yi++) {
         my $xxi=$i+$yi-$length_y+1;
         next if $xxi<0;
         next if $xxi>=$length_x;
         my $yyi=$yi;
         next if $yyi<0;
         next if $yyi>=$length_y;
#         print ("($xxi,$yyi) ");
         $z[$i]+=$x->[$xxi]*$y->[$yyi];
         }
#      print "\n";   
      }
   return \@z;   
}      
   

sub autocorrelation($) {
   my ($x)=@_;
   my @z;
   my $l=scalar(@$x);
   $#z=$l;
   for(my $i=0;$i<$l;$i++) {
      for(my $j=0;$j<$l-$i;$j++) {
         $z[$i]+=$x->[$j]*$x->[$i+$j];
         }
      }
   return \@z;   
}      
   

sub convolution($$) {
   my ($x,$y)=@_;
   my @y=reverse @$y;
   return correlation($x,\@y);
}      
   
#
#           ifx+lx-1
#    z[i] =   sum    x[j]*y[i-j]  ;  i = ifz,...,ifz+lz-1
#            j=ifx
#******************************************************************************
#Input:
#lx		length of x array
#ifx		sample index of first x
#x		array[lx] to be convolved with y
#ly		length of y array
#ify		sample index of first y
#y		array[ly] with which x is to be convolved
#lz		length of z array
#ifz		sample index of first z
#
#Output:
#z		array[lz] containing x convolved with y
#void conv (int lx, int ifx, float *x,
#	   int ly, int ify, float *y,
#	   int lz, int ifz, float *z)
#	int ilx=ifx+lx-1,ily=ify+ly-1,ilz=ifz+lz-1,i,j,jlow,jhigh;
#	float sum;
#	
#	x -= ifx;  y -= ify;  z -= ifz;
#	for (i=ifz; i<=ilz; ++i) {
#		jlow = i-ily;  if (jlow<ifx) jlow = ifx;
#		jhigh = i-ify;  if (jhigh>ilx) jhigh = ilx;
#		for (j=jlow,sum=0.0; j<=jhigh; ++j)
#			sum += x[j]*y[i-j];
#		z[i] = sum;
#	}
   


sub is_even($) {
   my ($num)=@_;
   return 1 if int($num/2)*2 == $num;
   return 0;
}   


sub norm_2_difference(@) {
   return sqrt(sum2(sub {sqr($_[0]-$_[1])}, @_));
}      


sub norm_2(@) {
   return sqrt(sum( sub {sqr($_)},@_));
}   


sub mean($) {
   my ($ar)=@_;
   ref($ar)            || die "mean(): no array ref given\n";
   ref($ar) eq 'ARRAY' || die "mean(): no array ref given\n";
   my $sum=0;
   foreach(@$ar) {
      $sum+=$_;
      }
   return $sum/scalar(@$ar);   
}


sub stddev($$) {
   my ($mean,$ar)=@_;
   ref($ar)            || die "stddev(): no array ref given\n";
   ref($ar) eq 'ARRAY' || die "stddev(): no array ref given\n";
   my $sum=0;
   foreach(@$ar) {
     $sum+=sqr($_-$mean);
     }
  $sum/=scalar(@$ar)-1;
  return sqrt($sum);   
}



sub statistics($) {
   my ($ar)=@_;
   ref($ar)            || die "statistics(): no array ref given\n";
   ref($ar) eq 'ARRAY' || die "statistics(): no array ref given\n";
   my ($min,$max);
   $min=$max=$ar->[0];
   my $sum=0;
   foreach(@$ar){
      $min=$_ if $_<$min;
      $max=$_ if $_>$max;
      $sum+=$_;
      }
   my $mean=$sum/scalar(@$ar);
   my $stddev=stddev($mean,$ar);   
   
   return (
      'max'    => $max,
      'min'    => $min,
      'mean'   => $mean,
      'stddev' => $stddev,
      );
}


sub difference_2($$) {
   my ($a,$b)=@_;
   return 2*($a-$b)/($a+$b);
}


END {}

1;

};
### End of inlined library Hans2::Math.
Hans2::Math->import();
}
BEGIN { 
Hans2::OneParamFile->import();
}
BEGIN { 
Hans2::File->import();
}
BEGIN { 
### Start of inlined library Hans2::System.
$INC{'Hans2/System.pm'} = './Hans2/System.pm';
{
package Hans2::System;




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

BEGIN { 
Hans2::FindBin->import();
}
BEGIN { 
Hans2::Cwd->import();
}
BEGIN { 
Hans2::Units->import();
}
BEGIN { 
Hans2::Math->import();
}
BEGIN { 
Hans2::OneParamFile->import();
}
BEGIN { 
Hans2::OneParamFile::StdConf->import();
}
BEGIN { 
Hans2::Util->import();
}
BEGIN { 
Hans2::File->import();
}
BEGIN { 
Hans2::Debug->import();
}
BEGIN { 
Hans2::Debug::Indent->import();
}
BEGIN { 
Hans2::Constants->import();
}
BEGIN { 
### Start of inlined library Hans2::ManipulateStdOutErr.
$INC{'Hans2/ManipulateStdOutErr.pm'} = './Hans2/ManipulateStdOutErr.pm';
{
package Hans2::ManipulateStdOutErr;




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

BEGIN { 
Hans2::FindBin->import();
}
BEGIN { 
Hans2::OneParamFile->import();
}
BEGIN { 
Hans2::OneParamFile::StdConf->import();
}


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

};
### End of inlined library Hans2::ManipulateStdOutErr.
Hans2::ManipulateStdOutErr->import();
}
BEGIN { 
Hans2::DataConversion->import();
}

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


sub run_nice_if($;%) {
   my ($cmd,%opts)=@_;
   if($ENV{'DEBUG'} || !find_exe_in_path("nice")) {
      return my_system($cmd,%opts);
      }
   else {
      return my_system("nice -20 $cmd",%opts,'executable'=>'nice');
      }
   }   


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

};
### End of inlined library Hans2::System.
Hans2::System->import();
}
BEGIN { 
### Start of inlined library Hans2::UpdateMyself.
$INC{'Hans2/UpdateMyself.pm'} = './Hans2/UpdateMyself.pm';
{
package Hans2::UpdateMyself;




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

BEGIN { 
Hans2::FindBin->import();
}
BEGIN { 
Hans2::Util->import();
}
BEGIN { 
Hans2::WebGet->import();
}
BEGIN { 
Hans2::File->import();
}
BEGIN { 
Hans2::System->import();
}
BEGIN { 
Hans2::OneParamFile->import();
}
BEGIN { 
Hans2::Debug->import();
}
BEGIN { 
Hans2::Constants->import();
}
BEGIN { 
Hans2::DataConversion->import();
}
BEGIN { 
### Start of inlined library Hans2::ParseVersionList.
$INC{'Hans2/ParseVersionList.pm'} = './Hans2/ParseVersionList.pm';
{
package Hans2::ParseVersionList;




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
                           &parse_version_list
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

BEGIN { 
Hans2::DataConversion->import();
}
BEGIN { 
Hans2::Constants->import();
}
BEGIN { 
### Start of inlined library Hans2::MonthNames.
$INC{'Hans2/MonthNames.pm'} = './Hans2/MonthNames.pm';
{
package Hans2::MonthNames;



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
                           ),@EXP_VAR);
        @NON_EXPORT  = qw(
                           @SHORT
                           @LONG
                           %STR_2_NUM
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

@SHORT=(
   '',
   'Jan',
   'Feb',
   'Mar',
   'Apr',
   'May',
   'Jun',
   'Jul',
   'Aug',
   'Sep',
   'Oct',
   'Nov',
   'Dec',
   );
   
@LONG=(
   '',
   'January',
   'February',
   'March',
   'April',
   'May',
   'June',
   'July',
   'August',
   'September',
   'October',
   'November',
   'December',
   );
   
my $i=0;
foreach my $mn (@SHORT) {
   $STR_2_NUM{$mn}=$i;
   $i++;
   }   
   
$i=0;   
foreach my $mn (@LONG) {
   $STR_2_NUM{$mn}=$i;
   $i++;
   }   
   

END {}

1;

};
### End of inlined library Hans2::MonthNames.
Hans2::MonthNames->import();
}
BEGIN { 
Hans2::Debug->import();
}


sub parse_version_list($) {

   my ($txt)=@_;

   return if !$txt;
   
   my @ret=grep {$_} map {s/#.*//;s/^\s+//;s/\s+$//;$_} split("\n",$txt);
   my %ret;
   foreach(@ret) {
      /^([\w\-]+)\s+(\S+)\s*(.*)/ || 
         die "did not understand line $_ in versions file. Please notify ".
             "the author at $author_email\n";
      $ret{$1}=[$2,$3];
      }
   # now %ret contains
   #  component -> [ version, other info ]   
   
   my %data;
   
   foreach my $comp_name (keys %ret) {
   
      my $comp=$ret{$comp_name};
      
      my $version=$comp->[0];

      $comp=$comp->[1];
      my %comp=anglebracketoptions_decode($comp);
      
      # process last_change_short and last_change_long
      if($comp{'last_change_short'}) {
         $comp{'last_change_short'} =~ /^(\d\d) (\w+) (\d\d\d\d)$/ 
            or die "could not understand last_change_short for $comp_name\n";
         my ($day,$mon_short,$year)=($1,$2,$3);
         my $mn=$Hans2::MonthNames::STR_2_NUM{$mon_short};
         my $mon_long=$Hans2::MonthNames::LONG[$mn];
         $comp{'last_change_long'}="$day $mon_long $year";
         }   
      
      #process version   
      $comp{'version'}=$version;
      $comp{'v_version'}=versionstring_2_vstring($version);
      if($comp{'effective_version'}) {
         $comp{'v_effective_version'}=versionstring_2_vstring($comp{'effective_version'});
         }
      else {
         $comp{'effective_version'}  =$comp{'version'};
         $comp{'v_effective_version'}=$comp{'v_version'};
         }   
      
      $data{$comp_name}=\%comp;
      }
      
   return %data;
}      


END {}

1;

};
### End of inlined library Hans2::ParseVersionList.
Hans2::ParseVersionList->import();
}

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

};
### End of inlined library Hans2::UpdateMyself.
Hans2::UpdateMyself->import();
}
BEGIN { 
Hans2::Debug->import();
}
BEGIN { 
Hans2::Constants->import();
}
BEGIN { 
Hans2::DataConversion->import();
}
BEGIN { 
### Start of inlined library Hans2::StringNum.
$INC{'Hans2/StringNum.pm'} = './Hans2/StringNum.pm';
{
package Hans2::StringNum;


require 5.006;


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
                       &sprintf_num_locale
                       &getnum 
                       &makenum
                       &is_numeric 
                       &not_numeric
                       ),@EXP_VAR);
        %EXPORT_TAGS = ();     # eg: TAG => [ qw!name1 name2! ],

        # your exported package globals go here,
        # as well as any optionally exported functions
#        @EXPORT_OK     = qw($MY_STDOUT $MY_STDERR $MY_STDIN $PROGRAM $PROGRAM_UC); 
        @EXPORT_OK   = qw();
        @NON_EXPORT  = qw(
                         ); 
        
        
}        

use vars      @EXP_VAR;
use vars      @EXPORT_OK;
use vars      @NON_EXPORT;

use POSIX qw(locale_h strtod);


sub sprintf_num_locale($$;$) {
   my ($format,$num,$locale)=@_;
   $locale ||= 'C';

   my $old_locale=setlocale(LC_NUMERIC);
   if($old_locale ne $locale) {
      # only bother changing locales if it would really change anything
      setlocale(LC_NUMERIC, $locale);
      my $ret=sprintf($format,$num);
      setlocale(LC_NUMERIC, $old_locale); 
      return $ret;
      }
   else {
      return sprintf($format,$num);
      }   
}      

# try to interpret the string as a number. return undef if no success
sub getnum_simple($) {
   my ($str)=@_;

   return undef if !defined $str;
   $str =~ s/^\s+//;
   $str =~ s/\s+$//;
   return undef if $str eq "";

   $! = 0;

   my($num, $unparsed) = strtod($str);

   if (($str eq '') || ($unparsed != 0) || $!) {
      return undef;
      }
   else {
      return $num;
      } 
} 


sub getnum($) {
   my ($str)=@_;
   
   my $ret;
   
   $ret=getnum_simple($str);
   return $ret if defined $ret;
   
   my $old_locale=setlocale(LC_NUMERIC);
   if($old_locale ne 'C') {
      # only bother changing locales if it would really change anything
      setlocale(LC_NUMERIC, 'C');
      $ret=getnum_simple($str);
      setlocale(LC_NUMERIC, $old_locale); 
      }
   
   return $ret;
}


sub makenum($$) {
   my ($ori,$hard)=@_;
   my $num=getnum($ori);
   die "$ori is not a number\n" if ($hard) && (!defined $num);
   return $num;
}


sub is_numeric($) { defined getnum($_[0]) }   
sub not_numeric($) { ! defined getnum($_[0]) }   


END {

}

1;

};
### End of inlined library Hans2::StringNum.
Hans2::StringNum->import();
}
BEGIN { 
Hans2::Units->import();
}
BEGIN { 
Hans2::Algo->import();
}
BEGIN { 
Hans2::MonthNames->import();
}
BEGIN { 
### Start of inlined library Hans2::WeekDay.
$INC{'Hans2/WeekDay.pm'} = './Hans2/WeekDay.pm';
{
package Hans2::WeekDay;



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
                           ),@EXP_VAR);
        @NON_EXPORT  = qw(
                           @SHORT
                           @LONG
                           %STR_2_NUM
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

@SHORT=(
   'Sun',
   'Mon',
   'Tue',
   'Wed',
   'Thu',
   'Fri',
   'Sat',
   );
   
@LONG=(
   'Sunday',
   'Monday',
   'Tuesday',
   'Wednesday',
   'Thursday',
   'Friday',
   'Saturday',
   );
   
my $i=0;
foreach my $mn (@SHORT) {
   $STR_2_NUM{$mn}=$i;
   $i++;
   }   

$i=0;   
foreach my $mn (@LONG) {
   $STR_2_NUM{$mn}=$i;
   $i++;
   }   
   

END {}

1;

};
### End of inlined library Hans2::WeekDay.
Hans2::WeekDay->import();
}

BEGIN { 
### Start of inlined library Xplanet::HomeLocation.
$INC{'Xplanet/HomeLocation.pm'} = './Xplanet/HomeLocation.pm';
{
package Xplanet::HomeLocation;




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
                         &determine_location
                         &latlong_2_tzcoordpl
                         &tzcoordpl_2_latlong
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

use filetest 'access';

BEGIN { 
Hans2::Math->import();
}
BEGIN { 
Hans2::Util->import();
}
BEGIN { 
Hans2::Debug->import();
}
BEGIN { 
Hans2::OneParamFile->import();
}
BEGIN { 
Hans2::StringNum->import();
}
BEGIN { 
Hans2::Constants->import();
}

BEGIN { 
### Start of inlined library Geo::SingleLocator.
$INC{'Geo/SingleLocator.pm'} = './Geo/SingleLocator.pm';
{
package Geo::SingleLocator;



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
                           $LOCATOR
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

BEGIN { 
Hans2::Algo->import();
}
BEGIN { 
Hans2::OneParamFile->import();
}
BEGIN { 
Hans2::OneParamFile::StdConf->import();
}
BEGIN { 
Hans2::FindBin->import();
}

BEGIN { 
### Start of inlined library Geo::Locator.
$INC{'Geo/Locator.pm'} = './Geo/Locator.pm';
{
package Geo::Locator;

#################### PURPOSE AND USAGE ################################
#
# A locator object. this way we could put different front-ends on this
#
# xplanet information at http://xplanet.sourceforge.net
#
#################### COPYRIGHT ##########################################
#
# Copyright 2002-2003 Hans Ecke and Felix Andrews under the terms of the GNU General Public License.
#



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
                           &markerlist_2_array
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

use filetest 'access';

BEGIN { 
Hans2::Util->import();
}
BEGIN { 
Hans2::Package->import();
}
BEGIN { 
Hans2::Math->import();
}
BEGIN { 
Hans2::Debug->import();
}
BEGIN { 
Hans2::Debug::Indent->import();
}
BEGIN { 
Hans2::File->import();
}

BEGIN { 
### Start of inlined library Xplanet::StringNum.
$INC{'Xplanet/StringNum.pm'} = './Xplanet/StringNum.pm';
{
package Xplanet::StringNum;




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
                         &print_coord
                         &print_angle
                         &print_name
                         &distspec2deg
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

BEGIN { 
Hans2::StringNum->import();
}
BEGIN { 
Hans2::Math->import();
}
BEGIN { 
Hans2::Units->import();
}


sub print_coord($) {
   my ($c)=@_;
   use locale;
   return sprintf_num_locale("% 7.2f",$c);
}


sub print_angle($) {
   my ($c)=@_;
   use locale;
   return sprintf_num_locale("%5.2f",$c);
}


sub print_name($) {
   my ($name)=@_;
   $name =~ s/(\b.)/uc($1)/eg;
   return $name;
}


sub distspec2deg($) {
   my ($dist)=@_;
   
   return undef if !defined $dist;
   return undef if $dist eq '';

   if($dist =~ /(.+)miles$/i) {
      my $miles=getnum($1);
      return undef if !defined($miles);
      return convert_units(convert_units($miles,'mile','km'),'km','deg');
      }
   elsif($dist =~ /(.+)km$/i) {
      my $km=getnum($1);
      return undef if !defined($km);
      return convert_units($km,'km','deg');
      }
   elsif(is_numeric($dist)) {
      return getnum($dist);
      }   
   else {
      return undef;
      }   
}

END {}

1;

};
### End of inlined library Xplanet::StringNum.
Xplanet::StringNum->import();
}

sub markerlist_2_array($$) {
   my ($xplanet_markers_dir,$str)=@_;
   my $ind=Hans2::Debug::Indent->new("configured marker files: $str");
   my @earth_m_fn            = split(/\s+/,$str);
   @earth_m_fn               = map {my_glob($xplanet_markers_dir,$_)} @earth_m_fn; 
   writedebug("configured marker filenames: ".join(", ",@earth_m_fn));
   {  my @emf;
      foreach(@earth_m_fn) {
         next if !-f $_;
         next if !-r $_;
         writedebug("found marker file $_");
         push @emf,$_;
         }
      @earth_m_fn=@emf;   
   }
}         
   

# object fields:
#
#  private:
#     modules   : hash module name => data source object reference or '1' if not yet initialized
#     sources   : array of source objects
#
#  public:
#     mode      : 's' -> forward search
#                 'r' -> reverse search using 'qlat', 'qlong', 'reverse_angle'
#     qlat, qlong, reverse_angle: for reverse lookup
#     city      : for forward lookup
#     angle_diff: minimal angle difference
#     smode     : search mdoe '1' 't' 'm'
#     loctype   : filter for location types (comma separated)
#     detail    : simple substring filter for the 'detail' field of each location
#
# Usage:
#
# Init via new(%args)
#     %args can have those fields:
#
#     * values for all public fields above, and
#
#     'modules'              => array of module names to pre-load
#     'cache'                => local cache file to use
#     'zone.tab'             => zone.tab timezone file to use
#     'markers'              => array of xplanet-style marker files to use
#     'cache_is_absolute'    => usually the cache file specified above has 
#                               the name of the executing script attached.
#                               If this is set, don't do that.
#
# Lookup on several levels of abstraction:
#
# lookup() takes the search mode stored and returns an array of information hashes
#
#     * lookup_reverse(qlat,qlong,angle) returns an array of information hashes
#       qlat, qlong and angle are optional. If not specified, the values stored inside the
#       object are taken
#       If angle=0  -> this array has only one element, the nearest neighbor to (qlat,qlong)
#       If angle!=0 -> all elements inside that circle around (qlat,qlong)
#
#         * nearest(qlat,qlong) returns an information hash
#           qlat and qlong are optional. If not specified, the values stored in the object are taken
#           returns the nearest location to (qlat,qlong)
#
#         * near(qlat,qlong,angle) returns an array of information hashes
#           qlat, qlong and angle are optional. If not specified, the values stored in the object are taken
#           returns all elements in the circle of radius <angle> around (qlat,qlong)
#
#     * lookup_forward(city, search mode) returns an array of information hashes
#       city and smode are optional. If not specified, values stored inside the object are taken
#       If smode='1' returns the first exact match found
#       If smode='t' returns the first exact match found. If no exact match is found, returns
#          all inexact matches
#       If smode='m' returns all inexact matches
#
#         * get_exact(city) returns an information hash
#           city is optional. If not specified, the value stored inside the object is taken
#           Returns the first exact match found, if any found. Nothing otherwise
#
#         * get_multi(city) returns an array of information hashes
#           city is optional. If not specified, the value stored inside the object is taken
#           Returns all substring matches found
#
#         * get_trusted(city) returns an array of information hashes
#           city is optional. If not specified, the value stored inside the object is taken
#           Has only the exact match as its element, if it is found. 
#           If not, returns all substring matches
#
# add a required data source with $self->add_module(module, module, ...) : returns number added
# delete a data source with $self->delete_module(module)
# list all data sources with $self->list_modules()
# get a hash of all data sources and their self-descriptions with $self->list_modules_descriptions()
#
# get/set mode with $self->mode() = 's' or 'r' (forward/reverse search)
#
# get/set search mode with $self->smode() = '1' or 't' or 'm'
#
# set search object with $self->city() or give directly to functions
#
# get/set minimal angle difference with $self->angle_diff()
#
# get/set reverse search parameters with $self->qlat(), $self->qlong(), $self->reverse_angle()
#
# get/set location type filter with $self->loctype()
#
# $self->package_prefix() gives the prefix under which loadable modules live, something like "Geo::Locator"
#
# get/set detail filter with $self->detail()

#
# Programming Information: 
#
# the "information hash" datatype we use has the following keys:
#     * lat          latitude
#     * long         longitude
#     * match        matched name
#     * detail       some more info we found
#     * qlat, qlong, dist (for reverse lookup)
#
# Modules must have this interface:
#
#   * net modules have all-uppercase names. I.e. 'USGS' not 'Usgs'
#
#   * a capabilities() method/function that returns a ref to a read-only hash whose
#     keys with non-false values denote what this data source can do:
#           'exact'       => exact search
#           'multi'       => multi search
#           'nearest'     => reverse lookup for nearest location
#           'near'        => reverse lookup for list of near locations
#           'dump'        => dump all locations
#           'loctype'     => search for specific location type is possible
#           'detail'      => search for detail is possible
#           'local'       => this datasource takes local information
#           'net'         => this datasource takes information from the Internet
#           'description' => a string describing this module and what it can do
#
#   * exact search: $self->match_exact($city) returns information hash or ()
#
#   * multi search: $self->match_multi($city) returns array of ref to hash of matches
#
#   * reverse lookup: 
#
#           $self->nearest($qlat,$qlong) returns nearest location from ($qlat,$qlong) 
#
#           $self->near($qlat,$qlong,$angle) returns array of locations in circle of 
#               $angle distance around ($qlat, $qlong)
#
#   * dump: $self->dump() returns array of information hashes
#
#   * location type: is the constructor option 'loctype'
#

my $package_prefix="Geo::Locator";

# for now, allow read/write access via pseudo-methods
our $AUTOLOAD;
# public fields we can just change in $self
my %permitted=( 'city'          => 1,
                'mode'          => 1,
                'smode'         => 1,
                'angle_diff'    => 1,
                'qlat'          => 1,
                'qlong'         => 1,
                'reverse_angle' => 1,
                );
# public fields we change in $self AND that have to be changed in all datasources that
# support it
my %hand_thru=( 'loctype'       => 1,
                'detail'        => 1,
                );                
# fields that are read-only to the public
my %ro_fields=( 'package_prefix'       => 1,
                );          
# fields we hand-thru to module initialization
my %init_fields=( 'cache'             => 1,
                  'zone.tab'          => 1,
                  'markers'           => 1,
                  'cache_is_absolute' => 1,
    );                      
sub AUTOLOAD {
   my ($self,$arg) = @_;
   my $type = ref($self) || die("$self is not an object\n");

   my $name = $AUTOLOAD;
   $name =~ s/.*://;   # strip fully-qualified portion
   
   # deal with hand-thru public fields
   if($hand_thru{$name}) {
      if(defined $arg) {
         $self->{$name}=$arg;
         foreach my $src (@{$self->{'sources'}}) {
            next if !$src->capabilities()->{$name};
            $src->{$name}=$arg;
            }
         }
      return $self->{$name}      
      }
   # deal with simple public fields
   if($permitted{$name}) {    
      $self->{$name} = $arg if defined $arg;
      return $self->{$name};
      }
   # deal with read-only fields
   if($ro_fields{$name}) {    
      die "You are not permitted to change the $name field in objects of type $type\n" if defined $arg;
      return $self->{$name};
      }
   # everything left over is not public
   die "You are not allowed to access the \"$name\" field in objects of type $type\n";

}

sub DESTROY {}  # need to declare, so its not taken by the above AUTOLOAD

############################################################################
#
# Utility
#
############################################################################

# in: array of information hashes
#
# action: removes duplicate entries (within $min_angle_difference)
#         this should also do relevance ranking (but doesn't, yet)
#
# out: array of only the 'unique' entries
sub resolve_dups($@) {
   my ($self,@hits) = @_;
   return () if !@hits;
   return @hits if !$self->{'angle_diff'};
   my @uniq = ();
   push @uniq, shift @hits;   # shift, not pop!
   # these are both arrays of information hashes
   HIT: 
   foreach my $hit (@hits) { # do not use reverse to keep trust priority!
      foreach my $uniq_hit (@uniq) {
         my $dist=angle_difference($hit->{'lat'},$uniq_hit->{'lat'},$hit->{'long'},$uniq_hit->{'long'});
         if ( $dist < $self->{'angle_diff'} ) {
             # which of $hit and $uniq_hit should we choose?     
             my $new_c=$hit->{'match'};
             my $old_c=$uniq_hit->{'match'};
             # if the new string is shorter, use that record
             if(length($new_c) < length($old_c)) {
                ($uniq_hit,$hit)=($hit,$uniq_hit);   
                }
             writedebug("omitting $hit->{'match'} [ $hit->{'lat'} $hit->{'long'} ]");
             writedebug("        :conflict with $uniq_hit->{'match'} [ $uniq_hit->{'lat'} $uniq_hit->{'long'} ] which is ".sprintf("%3.4f",$dist)." degrees away");
             next HIT;
         }
      }
      push @uniq, $hit;
   }
   my $trim = @hits - @uniq + 1; # we shifted one from @hits
   writedebug("resolved $trim duplicates with a threshold of $self->{'angle_diff'} degrees.");
   return @uniq;
}

# in: * data source name that corresponds to a perl module inside
#       the Geo::Locator:: hierarchy
#     * optional argument hash to constructor
#
# out: created object or undef if error
sub create_source($$;%) {
   my($self,$src,%args)=@_;
   
   my $module=$self->{'package_prefix'}."::".$src;
   
   if(!try_to_load($module)) {
      writedebug("trying to load $module module failed");
      return undef;
      }
   
   my $obj;
   
   eval {$obj=$module->new(%args);};   # if no new() method exists its likely not a 
                                       # module. Silently return undef in that case
                                       
   if($@) {
      writedebug("trying to create $src plugin: $@");
      return undef;
      }
   
   writedebug("Created a $module object");
   
   return $obj;
}

# instantiate all required modules that we don't yet have
# we see that in fields of %modules that do NOT have a reference (i.e. object) as value
#
# return number of sources added
sub check_modules($) {
   my ($self)=@_;
   
   my $ret=0;
   
   my %modules=%{$self->{'modules'}};
   
   # default constructor arguments
   my %arg;
   foreach(keys %init_fields) {
      $arg{$_}=$self->{$_};
      }
   # make sure all hand-through fields get propagated         
   foreach my $field (keys %hand_thru) {
      next if !exists $self->{$field};
      $arg{$field}=$self->{$field};
      }            
   
   foreach my $mod (keys %modules) {
      my $src1=$modules{$mod};
      if((!$src1)||(!ref($src1))){  # all sources that are not there yet
         my $ind=Hans2::Debug::Indent->new("Trying to create a $mod plugin");
         my $src=$self->create_source($mod,%arg);
         
         next if !$src;  # if we did not succeed, i.e. not found or is not an object
         
         # now we should do some sanity checking on the newly created module
         # right now we just test that capabilities() and capabilities(){'description'} are there
         my $cap;
         eval {$cap=$src->capabilities();};
         if($@) {
            writedebug("calling capabilities() on plugin $mod: $@");
            next;
            }
         if(!$cap) {
            writedebug($mod."->capabilities() returned nothing");
            next;
            }   
         if(!%$cap) {
            writedebug($mod."->capabilities() returned empty hash");
            next;
            }   
         if(!$cap->{'description'}) {
            writedebug($mod."->capabilities() returned a hash that does not contain a \"description\" field");
            next;
            }   
         
         writedebug("Succeeded in creating a $mod plugin");
         $ret++;
         
         # and register it in our data structures
         $self->{'modules'}->{$mod}=$src;
         push @{$self->{'sources'}},$src;
         }
      }
   foreach my $mod (keys %modules) {
      my $src1=$self->{'modules'}->{$mod};
      # we could not create those guys in the last run
      # so lets not try again in the future
      if((!$src1) || (!ref($src1))) {
         delete $self->{'modules'}->{$mod};
         writedebug("Give up on creating a $mod plugin");
         }
      }
      
   return $ret;   
}         

# initializing
sub init($) {
   my ($self)=@_;
   
   $self->check_modules();
   
}   

############################################################################
#
# Most specific lookups
#
############################################################################

# in: city name
#
# out: information hash
#
# action: looks the coordinates of the city up : exact search
sub get_exact($;$) {
   my ($self,$city)=@_;
   
   $city ||= $self->{'city'};
   
   foreach my $src (@{$self->{'sources'}}){
      next if ! $src->capabilities()->{'exact'};
      my %match = $src->match_exact($city);
      if(%match) {
         $match{'match'} ||= $city;
         my ($lat,$long)=@match{'lat','long'};
         writedebug("Looking exact for ".sprintf("%-18s",'"'.$city.'"').": (".print_coord($lat).",".print_coord($long).")");
         return %match;
         }
      }

   writedebug("Looking exact for \"$city\": not found");
   return ();
}

# in: city name
#
# action: look the coordinate up, return _all_ matches
#
# out: array of refs to information hash, including 'match'  => matching name
#
# return () if no results at all
sub get_multi($;$) {
   my ($self,$city)=@_;
   
   $city ||= $self->{'city'};

   # only [uppercase letter][lowercase letter][upper and lowercase letters or spaces]
   # are cities
   if($city !~ /^(?:[a-z][a-z][a-z ]*|\d+)$/i) {
      writedebug("Looking multi for \"$city\": bad name");
      return ();
      }

   my @hits;
   
   foreach my $src (@{$self->{'sources'}}) {
      next if ! $src->capabilities()->{'multi'};
      push @hits,$src->match_multi($city);
      }

   @hits=$self->resolve_dups(@hits);
   writedebug("Looking multi for \"$city\": ".scalar(@hits)." matches");
   return @hits;
}

# in: city name
#
# action: looks the coordinates of the city up, try to return trusted matches
#
# out: array of information hashes
#
# return () if no results at all
sub get_trusted($;$) {
   my ($self,$city)=@_;

   $city ||= $self->{'city'};

   # first hope we get exact matches

   my %exact=$self->get_exact($city);
   if(%exact) {
      writedebug("Looking trusted for \"$city\": one match");
      return (\%exact);
      }

   # There are no exact hits.
   
   my @hits=$self->get_multi($city);
   if(!@hits) {
      writedebug("Looking trusted for \"$city\": no matches");
      return ();
      }
   
   # At this stage we could try to see if a majority of matches 
   # point to a specific area (i.e. aliasing of names) and assume that
   # particular area is the best to choose.
   #
   # But this is decidedly non-trivial. Coordinates even for the same city
   # are often off by up to 1/2 degree between different location sources.
   #
   # If we accept that we have many different matches (after all, maybe there
   # _are_ different locations of the same name in the world), we might still
   # want to weed out matches that are too close to each other so the resulting
   # map has readable location labels.

   # NOTE: resolving of duplicates is done in the 'processing' functions

   return $self->resolve_dups(@hits);
}

# in: (latitude, longitude) asked
#
# out: information hash
sub nearest($;$$) {
   my ($self,$qlat,$qlong) = @_;
   
   $qlat  = $self->{'qlat'}  if !defined $qlat;
   $qlong = $self->{'qlong'} if !defined $qlong;
   
   writedebug("Looking for nearest to [$qlat, $qlong]");

   my @hits;
   
   # get the nearest for each source
   foreach my $src (@{$self->{'sources'}}){
      next if ! $src->capabilities()->{'nearest'};
      my %match = $src->nearest($qlat,$qlong);
      die "Source ".ref($src)." failed to return a nearest neighbor to ($qlat,$qlong)\n" if !%match;
      push @hits,\%match; 
      }
      
   return () if !@hits;   
      
   # and look for the nearest among them   
   my $nearest=shift @hits;   
   foreach my $hit (@hits) {
      $nearest=$hit if $hit->{'dist'} < $nearest->{'dist'};
      }

   return %$nearest;
}   

# in: (latitude, longitude, angle) asked
#
# out: array of information hashes
sub near($;$$$) {
   my ($self,$qlat,$qlong,$angle) = @_;
   
   $qlat  = $self->{'qlat'}          if !defined $qlat;
   $qlong = $self->{'qlong'}         if !defined $qlong;
   $angle = $self->{'reverse_angle'} if !defined $angle;

   writedebug("Looking for near ($angle) to [$qlat, $qlong]");

   my @hits;
   
   foreach my $src (@{$self->{'sources'}}){
      next if ! $src->capabilities()->{'near'};
      my @match = $src->near($qlat,$qlong,$angle);
      push @hits, @match if @match;
      }

   return @hits;
}   

############################################################################
#
# forward/reverse lookup
#
############################################################################

# in: city, search mode
#
# out: array of hashes
sub lookup_forward($;$$) {
   my ($self,$city,$smode)=@_;
   
   $city  ||= $self->{'city'};
   $smode ||= $self->{'smode'};
   
   my @hits;
   
   if($smode eq '1') {
      my %match=$self->get_exact($city);
      @hits=(\%match) if %match;
      }
   elsif($smode eq 't') {
      @hits=$self->get_trusted($city);
      }
   elsif($smode eq 'm') {
      @hits=$self->get_multi($city);
      }
   else {
      die "Unknown search mode $smode\n";
      }   
   
   return @hits;
   
}

# in: qlat, qlong, reverse angle
#
# out: array of info hashes
sub lookup_reverse($;$$$) {
   my ($self,$qlat,$qlong,$revang)=@_;
   
   $qlat  = $self->{'qlat'}          if !defined $qlat;
   $qlong = $self->{'qlong'}         if !defined $qlong;
   $revang= $self->{'reverse_angle'} if !defined $revang;
   
   my @hits;
   
   if($revang) {
      @hits=$self->near($qlat,$qlong,$revang);
      }
   else {
      my %match=$self->nearest($qlat,$qlong);
      @hits=(\%match) if %match;
      }   
      
   return @hits;
   
}

############################################################################
#
# generic lookup
#
############################################################################

# in: nothing (use search params that are stored in $self)
#
# out: array of hashes
sub lookup($) {
   my ($self)=@_;
   
   if($self->{'mode'} eq 'r') {
      return $self->lookup_reverse();
      }
   elsif($self->{'mode'} eq 's') {
      return $self->lookup_forward();
      }
   else {
      die "Unknown lookup mode $self->{'mode'}\n";
      }   

}

############################################################################
#
# other interface functions
#
############################################################################

# in: nothing
#
# out: array of information hashes
sub dump_locations($) {

   my ($self)=@_;

   my @cities;
   
   foreach my $src (@{$self->{'sources'}}) {
      next if ! $src->capabilities()->{'dump'};
      push @cities, $src->dump();
      }

   return @cities;   # success   
}

# constructor
sub new($%) {
   my ($proto,%arg) = @_;
   
   my $class = ref($proto) || $proto;

   my $self  = \%arg;

   bless ($self, $class);
   
   my $ind=Hans2::Debug::Indent->new("Constructing a Geo::Locator object");

   # default values
   $self->{'mode'}         ||= 's';
   $self->{'smode'}        ||= '1';
   $self->{'angle_diff'}     = 2  if !defined $self->{'angle_diff'};
   $self->{'reverse_angle'}  = 0  if !defined $self->{'reverse_angle'};
   $self->{'qlat'}           = 90 if !defined $self->{'qlat'};  
   $self->{'qlong'}          = 0  if !defined $self->{'qlong'};  
   $self->{'city'}         ||= 'london';
   
   $self->{'package_prefix'}=$package_prefix;
   
   # get the list of modules to preload
   my %modules;
   my $mods=$self->{'modules'};
   if($mods) {
      if(ref($mods)) {
         if(ref($mods) eq 'ARRAY') {
            %modules=map {$_ => 1} @$mods;
            }
         else {
            die "argument \"modules\" to constructor Geo::Locator::new() must be array reference, not of type ".ref($mods)."\n";
            }   
         }
      else {
         die "argument \"modules\" to constructor Geo::Locator::new() must be array reference, not scalar $mods\n";
         }      
      }
   $self->{'modules'}=\%modules;   
   $self->{'sources'}=[];   
   
   $self->init();
   
   writedebug("Done constructing a Geo::Locator object");
   
   return $self;
}   

# add some data sources
#
# return number added
sub add_module($@) {
   my ($self,@modules)=@_;
   
   writedebug("Requested to add ".join(", ",@modules)." plugins");

   foreach my $mod (@modules) {
      $self->{'modules'}->{$mod} ||= 1; # make sure not to overwrite already existing modules
      }
      
   return $self->check_modules();   
   
}

# delete module $mod
sub delete_module($$) {
   my ($self,$mod)=@_;
   
   writedebug("Requested to delete a $mod plugin");

   return if !$self->{'modules'}->{$mod};
   return if !ref($self->{'modules'}->{$mod});
   
   my $src=$self->{'modules'}->{$mod};
   delete $self->{'modules'}->{$mod};
   
   my @new_sources;
   
   foreach my $this_src (@{$self->{'sources'}}) {
      if(!($this_src eq $src)) {
         push @new_sources,$this_src;
         }
      }
   $self->{'sources'}=\@new_sources;   
   
}

# list of all loaded data sources
#
# this is somewhat complicated since we want to sort it by order
sub list_modules($) {
   my ($self)=@_;
   my %modules=%{$self->{'modules'}};
   my @sources=@{$self->{'sources'}};
   
   my @list;
   
   foreach my $src (@sources) {
      # search for its name in %modules
      foreach my $mod (keys %modules) {
         if($src and $modules{$mod} and ref($modules{$mod}) and ($src eq $modules{$mod})) {
            push @list,$mod;
            last;
            }
         }
      }
   return @list;
   
}

# hash of all loaded data sources -> their descriptions
sub list_modules_descriptions($) {
   my ($self)=@_;
   
   my %modules;
   
   foreach my $mod (keys %{$self->{'modules'}}) {
      my $src=$self->{'modules'}->{$mod};
      next if !$src;
      next if !ref($src);
      $modules{$mod}=$src->capabilities()->{'description'};
      }
      
   return %modules;   
   
}

END {}

1;

};
### End of inlined library Geo::Locator.
Geo::Locator->import();
}

BEGIN { 
### Start of inlined library Xplanet::StdConf.
$INC{'Xplanet/StdConf.pm'} = './Xplanet/StdConf.pm';
{
package Xplanet::StdConf;




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

BEGIN { 
Hans2::FindBin->import();
}
BEGIN { 
Hans2::OneParamFile->import();
}

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

};
### End of inlined library Xplanet::StdConf.
Xplanet::StdConf->import();
}

register_param($ONEPARAMFILE_TMPDIR_OPTS,%ONEPARAMFILE_TMPDIR_OPTS);
register_param($ONEPARAMFILE_DIR_OPTS,%ONEPARAMFILE_DIR_OPTS);


my $init_nr=0;
sub init(;%) {
   my (%opts)=@_;
   $init_nr++;
   
   my $xplanet_dir           = $PARAMS{$ONEPARAMFILE_DIR_OPTS};
   my $xplanet_markers_dir   = File::Spec->catdir($xplanet_dir,"markers");

   # the default zone.tab file
   my $zone_tab = firstgood(sub {$_ and (-f $_) and (-r $_)}, 
                            $opts{'zone.tab'},
                            '/usr/share/zoneinfo/zone.tab',
                            File::Spec->catfile($Bin,"zone.tab")
                            );
   die "Could not find timezone information file\n" if ! $zone_tab;
   
   my @earth_m_fn;
   if($opts{'markers'}) {
      if(ref($opts{'markers'})) {
         @earth_m_fn=@{$opts{'markers'}};
         }
      else {   
         @earth_m_fn=markerlist_2_array($xplanet_markers_dir,$opts{'markers'});
         }
      }
   else {   
      @earth_m_fn=markerlist_2_array($xplanet_markers_dir,'weather_markers earth capitals nations ed_u.com bcca.org')
      }
   
   my $local_cache=$opts{'cache'};
   if(!$local_cache) {
      my $tmpdir = $PARAMS{$ONEPARAMFILE_TMPDIR_OPTS} || $Bin;
      $local_cache = File::Spec->catfile($tmpdir,"local_location.cache.generic");
      }
      
   my @net_modules=@{$opts{'net_modules'}} if $opts{'net_modules'};
   
   my $min_angle_difference=$opts{'min_angle_difference'};
   $min_angle_difference=2 if !defined $min_angle_difference;
   
   my $cache_is_absolute=(%opts ? 0 : 1);
   
   $LOCATOR=Geo::Locator->new(
                            'zone.tab'          => $zone_tab,
                            'markers'           => \@earth_m_fn,
                            'cache'             => $local_cache,
                            'modules'           => [ 'Local', @net_modules],
                            'angle_diff'        => $min_angle_difference,
                            'cache_is_absolute' => $cache_is_absolute,
                            );
}


sub single_init(;%) {
   my (%opts)=@_;
   return if $init_nr;
   Geo::SingleLocator::init(%opts);
}   



END {}

1;

};
### End of inlined library Geo::SingleLocator.
Geo::SingleLocator->import();
}

BEGIN { 
### Start of inlined library Xplanet::Xplanet.
$INC{'Xplanet/Xplanet.pm'} = './Xplanet/Xplanet.pm';
{
package Xplanet::Xplanet;




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

BEGIN { 
Hans2::Cwd->import();
}
BEGIN { 
Hans2::FindBin->import();
}
BEGIN { 
Hans2::Units->import();
}
BEGIN { 
Hans2::Math->import();
}
BEGIN { 
Hans2::OneParamFile->import();
}
BEGIN { 
Hans2::System->import();
}
BEGIN { 
Hans2::Util->import();
}
BEGIN { 
Hans2::Debug->import();
}
BEGIN { 
Hans2::File->import();
}
BEGIN { 
Hans2::Constants->import();
}
BEGIN { 
Hans2::DataConversion->import();
}

BEGIN { 
Xplanet::StdConf->import();
}

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

};
### End of inlined library Xplanet::Xplanet.
Xplanet::Xplanet->import();
}
BEGIN { 
### Start of inlined library Xplanet::Constants.
$INC{'Xplanet/Constants.pm'} = './Xplanet/Constants.pm';
{
package Xplanet::Constants;




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

BEGIN { 
Hans2::UpdateMyself->import();
}
BEGIN { 
Hans2::Constants->import();
}

my $dl_base="http://hans.ecke.ws/xplanet/";
my $current_versions_file="${dl_base}current_versions.lst";

$Hans2::UpdateMyself::dl_base               = $dl_base;
$Hans2::UpdateMyself::current_versions_file = $current_versions_file;

$Hans2::Constants::author_email             = 'hans@ecke.ws';
$Hans2::Constants::author_name              = 'Hans Ecke';
$Hans2::Constants::homepage                 = 'http://hans.ecke.ws/xplanet';



END {}

1;

};
### End of inlined library Xplanet::Constants.
Xplanet::Constants->import();
}
BEGIN { 
Xplanet::StringNum->import();
}

my $ONEPARAMFILE_LOCATION_OPTS='LOCATION';
my %ONEPARAMFILE_LOCATION_OPTS=(
         'comment'  => [
            'Your home location, i.e. your home town. Something geo_locator with default options',
            'will understand',
            '',
            'If you leave this empty, we will fallback to the below LATITUDE',
            'and LONGITUDE. You can determine those with geo_locator using netmodules, i.e.',
            '   geo_locator.pl -n TGN -s m vu ',
            ],
         'default'  => 'Golden',
         'nr'       => $Hans2::OneParamFile::local_off + 1,
         );

my $ONEPARAMFILE_LAT_OPTS='LATITUDE';
my %ONEPARAMFILE_LAT_OPTS=(
         'comment'  => [
            'If the LOCATOR program above can not determine the coordinates for your home,',
            '(the LOCATION above that) you need to specify it directly.',
            '',
            'Latitude of our home location',
            'Latitude is north or south. A southern latitude is negative.',
                    ],
         'default'  => 39.75,
         'nr'       => $Hans2::OneParamFile::local_off+3,
         );

my $ONEPARAMFILE_LONG_OPTS='LONGITUDE';
my %ONEPARAMFILE_LONG_OPTS=(
         'comment'  => [
            'If the LOCATOR program above can not determine the coordinates for your home,',
            '(the LOCATION above that) you need to specify it directly.',
            '',
            'Longitude of our home location',
            'Longitude is west or east. A western longitude is negative.',
                       ],
         'default'  => -105.22,
         'nr'       => $Hans2::OneParamFile::local_off+4,
         );

register_param($ONEPARAMFILE_LAT_OPTS,     %ONEPARAMFILE_LAT_OPTS);
register_param($ONEPARAMFILE_LONG_OPTS,    %ONEPARAMFILE_LONG_OPTS);
register_param($ONEPARAMFILE_LOCATION_OPTS,%ONEPARAMFILE_LOCATION_OPTS);

register_remove_param('LOCATOR');


sub latlong_2_tzcoordpl($$) {
   my ($lat,$long)=@_;
   return "-lat ".print_coord($lat).
          " -lon ".print_coord($long);
}      


sub tzcoordpl_2_latlong($) {
   my ($str)=@_;
   my ($lat,$long);
   for($str) {
      s/^\s+//;
      s/\s+$//;
      return if !$_;
      
      return if !/-lat\s+(-?\d+\.\d+)/;
      $lat=$1;

      return if !/-lon\s+(-?\d+\.\d+)/;
      $long=$1;

      return if !is_numeric($lat);
      return if !is_numeric($long);
      }
   return ($lat,$long);
}      

sub determine_location_locator() {
   Geo::SingleLocator::single_init();
   my $location              = $PARAMS{$ONEPARAMFILE_LOCATION_OPTS} || return;
   my @info=$LOCATOR->get_trusted($location);
   return if !@info;
   return if scalar(@info)!=1;
   my %info=%{$info[0]};
   my ($lat,$long)=@info{'lat','long'};
   writedebug("coords of $location is ($lat,$long)");
   return ($lat,$long);
}
   
sub determine_location_latlong() {
   my $lat =$PARAMS{$ONEPARAMFILE_LAT_OPTS}  || return;
   my $long=$PARAMS{$ONEPARAMFILE_LONG_OPTS} || return;
   return if !is_numeric($lat);
   return if !is_numeric($long);
   return ($lat,$long);
}   


sub determine_location() {
   my ($lat,$long);
   
   ($lat,$long)=determine_location_locator();
   return ($lat,$long) if (defined $lat) and (defined $long) and (is_numeric($lat)) and (is_numeric($long));

   ($lat,$long)=determine_location_latlong();
   return ($lat,$long) if (defined $lat) and (defined $long) and (is_numeric($lat)) and (is_numeric($long));
   
   return;
}   

END {}

1;

};
### End of inlined library Xplanet::HomeLocation.
Xplanet::HomeLocation->import();
}
BEGIN { 
Xplanet::Xplanet->import();
}
BEGIN { 
Xplanet::StdConf->import();
}
BEGIN { 
### Start of inlined library Xplanet::Table.
$INC{'Xplanet/Table.pm'} = './Xplanet/Table.pm';
{
package Xplanet::Table;




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
                           table_2_markerfile
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

BEGIN { 
Hans2::Algo->import();
}
BEGIN { 
Hans2::Debug->import();
}

my $default_avg_x_size=6.7;
my $default_avg_y_size=20;

sub txt_cell_draw($$%) {
   my ($x,$y,%cell)=@_;
   my $str=$cell{'txt'};
   return "" if !$str;
   my $width =$cell{'width'};
   my $height=$cell{'height'};
   my $avg_x_size=$cell{'avg_x_size'};
   $x+=$avg_x_size/2;
#   $x+=$width/2;
#   $y+=$height/2;
   my ($xx,$yy)=(int($x),int($y));
   my $txt="$yy $xx \"$str\" image=none position=pixel align=right";
   my %understand=(
      'color'  => 1,
      );
   foreach my $key (keys %cell) {
      if($understand{$key}) {
         $txt.=" $key=".$cell{$key};
         }
      }
   writedebug($txt);
   return $txt;
}   

sub icn_cell_draw($$%) {
   my ($x,$y,%cell)=@_;
   my $file=$cell{'icon'};
   return "" if !$file;
   my $width =$cell{'width'};
   my $height=$cell{'height'};
   $x+=$width/2;
#   $y+=$height/2;
   my ($xx,$yy)=(int($x),int($y));
   my $txt="$yy $xx \"\" image=$file position=pixel";
   my %understand=(
      'transparent' => 1,
      );
   foreach my $key (keys %cell) {
      if($understand{$key}) {
         $txt.=" $key=".$cell{$key};
         }
      }
   writedebug($txt);
   return $txt;
}   

sub cell_draw($$%) {
   my ($x,$y,%cell)=@_;
   if($cell{'txt'}) {
      return txt_cell_draw($x,$y,%cell);
      }
   else {
      return icn_cell_draw($x,$y,%cell);
      }   
}   

sub txt_cell_size(%) {
   my (%cell)=@_;
   my $str=$cell{'txt'};
   return (0,0) if !$str;
   my $width =$cell{'avg_x_size'}*(length($str)+1);
   my $height=$cell{'avg_y_size'};
   return ($width,$height);
}

sub icn_cell_size(%) {
   my (%cell)=@_;
   my $fn=$cell{'icon'};
   return (0,0) if !$fn;
   my $width =$cell{'width'}  || die "icon $fn: no width given\n";   
   my $height=$cell{'height'} || die "icon $fn: no height given\n";   
   return ($width,$height);
}   

sub cell_size(%) {
   my (%cell)=@_;
   if($cell{'txt'}) {
      return txt_cell_size(%cell);
      }
   elsif(exists $cell{'icon'}) {
      return icn_cell_size(%cell);
      }
   else {
      die "bad cell\n";
      }
}            


sub table_2_markerfile(%) {
   my (%tbl)=@_;
   my $x_start   = $tbl{'x_start'};
   my $y_start   = $tbl{'y_start'};
   my $avg_x_size= $tbl{'avg_x_size'} || $default_avg_x_size;
   my $avg_y_size= $tbl{'avg_y_size'} || $default_avg_y_size;
   my $d=$tbl{'d'};
   my @d=@$d;

   my @c_w;  # column-width
   my @r_h;  # row-height
   
   my $row_num;
   my $col_num;
   
   
   my $rn=0;
   foreach my $row (@d) {
      $r_h[$rn]=0;
      my $cn=0;
      foreach my $cell (@$row) {
         $c_w[$cn]||=0;
         my %cell=%$cell;
         my $colspan=$cell{'colspan'} || 1;
         
         my ($width,$height)=cell_size(%cell,
                               'avg_x_size' => $avg_x_size,
                               'avg_y_size' => $avg_y_size,
                               );
         $height+=1;   
         $width +=1;   
         $r_h[$rn]=max_simple($r_h[$rn],$height);

         if($colspan==1) {
            $c_w[$cn]=max_simple($c_w[$cn],$width);
            }
            
         $cn+=$colspan;
         $col_num=$cn;
         }
      $rn++;
      $row_num=$rn;
      }
      
   my $tbl_height=0;   
   foreach(@r_h) {
      $tbl_height+=$_;
      }
   my $tbl_width=0;
   foreach(@c_w) {
      $tbl_width+=$_;
      }
   
   $y_start-=$tbl_height if $y_start<0;
   $x_start-=$tbl_width  if $x_start<0;
   $y_start+=$r_h[$row_num-1]/2;
   
   my $y=$y_start;
   my $txt="";
   $rn=0;
   foreach my $row (@d) {
      my $x=$x_start;
      my $height=$r_h[$rn];
      my $cn=0;
      foreach my $cell (@$row) {
         my $width=$c_w[$cn];
         my %cell=%$cell;
         my $colspan=$cell{'colspan'} || 1;
         $txt.=cell_draw($x,$y,%cell,
                               'x_start'    => $x_start,
                               'width'      => $width,
                               'height'     => $height,
                               'avg_x_size' => $avg_x_size,
                               'avg_y_size' => $avg_y_size,
                               );
         $txt.="\n"; 
         $x += $width;
         $cn+= $colspan; 
         }
      $rn++;
      $y+=$height;
      $txt.="\n";
      writedebug("");
      }
   
   return $txt;
   
}

END {}

1;

};
### End of inlined library Xplanet::Table.
Xplanet::Table->import();
}
BEGIN { 
Xplanet::Constants->import();
}

writedebug("version: $VERSION");

my $conf_offset=soundex_number($Scriptbase)*100;

my %cfg=check_param(
   'file'   => $conffile,
   'remove' => ['HURRICANE_INSET_MARKER_LINE','HURRICANE_TIME_MARKER_LINE'],
   'check'  => {
      $ONEPARAMFILE_DIR_OPTS      => \%ONEPARAMFILE_DIR_OPTS,
      $ONEPARAMFILE_METRIC_OPTS   => \%ONEPARAMFILE_METRIC_OPTS,
      'HURRICANE_INSET_SIZE' => {
         'comment'  => [
            'Size of the generated inset, something like 300x300'
            ],
         'default'  => '300x300',
         'nr'       => $conf_offset,
         },
      'HURRICANE_ALWAYS_INSET' => {
         'comment'  => [
            'Should we paint an inset, even if no storm is in it?',
            '',
            '   0 : don\'t paint an inset if not necessary',
            '   1 : always paint an inset',
            ],
         'default'  => 0,
         'nr'       => $conf_offset + 1,
         },
      'HURRICANE_CHOOSE_INSET' => {
         'comment'  => [
            'Which inset are we trying to show?',
            '',
            '   \'none\'             : no inset shown',
            '   \'home\'             : use inset showing home',
            '   \'nearest storm\'    : use inset showing storm nearest to home',
            '                          (this will still show your home area if no ',
            '                          storms could be found but the $always_inset ',
            '                          variable above is \'1\')',
            ],
         'default'  => 'nearest storm',
         'nr'       => $conf_offset + 2,
         },
      'HURRICANE_MARKERFILES' => {
         'comment'  => [
            'Which markerfiles should be included in the inset',
            ],
         'default'  => 'earth.hans quake volcano US-capitals-plus',
         'nr'       => $conf_offset + 3,
         },
      'HURRICANE_GREATARCFILES' => {
         'comment'  => [
            'Which greatarcfiles should be included in the inset',
            '',
            'Example: Do not include the coast lines arc file, which will speed ',
            '         this script up greatly',
            '         states_i_dg.tight boundaries_i_dg.tight',
            '',
            'Example: Include the coast lines arc file, which will make the insets',
            '         this much prettier',
            '         states_i_dg.tight coast_i_dg.tight boundaries_i_dg.tight',
            ],
         'default'  => 'states_i_dg.tight coast_i_dg.tight boundaries_i_dg.tight',
         'nr'       => $conf_offset + 4,
         },
      'HURRICANE_MARKER_TEMPLATE' => {
         'comment'  => [
            'How each marker file looks like. Can understand those symbols:',
            '   $lat        - latitude',
            '   $long       - longitude',
            '   $name       - hurricane name',
            '   $wind       - wind speed in your favorite unit: ',
            '                 if you have choosen METRIC=1 above, its km/h',
            '                 if you have choosen METRIC=0 above, its miles/h',
            '   $unitwind   - the unit from above',
            '   $knwind     - wind speed in knots',
            '   $miwind     - wind speed in miles/hour',
            '   $kmwind     - wind speed in km/hour',
            '   $file       - URL to more information',
            '   $type       - type - DEP, STO, HUR, TYP, CYC',
            '                 DEP = depression, windspeed < 38 mph',
            '                 STO = storm, 38 mph < windspeed < 73 mph',
            '                 HUR = hurricane, windspeed > 74 mph, formed in eastern pacific or atlantic',
            '                 TYP = typhoon, windspeed > 74 mph, formed in western pacific',
            '                 CYC = cyclone, organized rotating storm, like a tornado',
            '   $stype      - above type, in a shorter, nicer writing',
            '                 T.D.',
            '                 T.S.',
            '                 Hur.',
            '                 Typ.',
            '                 Cyc.',
            '   $ltype      - above type, in a longer, nicer writing',
            '                 Depression',
            '                 Storm',
            '                 Hurricane',
            '                 Typhoon',
            '                 Cyclone',
            '   <CR>        - a linebreak, to make for markers that go over multiple lines', 
            ],
         'default'  => '$lat $long "$stype $name [$wind $unitwind]" image=hurricane_$type.png color=green transparent={255,255,255} # $file',
         'nr'       => $conf_offset + 5,
         },    
      'HURRICANE_XPLANET_CMD' => {
         'comment'  => [
            'The command to generate the inset with storm. Understands those variables:',
            '   $lat1, $long1, $lat2, $long2 : mapbounds of source inset',
            '   $markerfiles                 : xplanet options to include above markerfiles',
            '   $greatarcfiles               : xplanet options to include above markerfiles',
            '   $image                       : source inset',
            '   $output_inset_size           : above output geometry',
            '',
            'Example: Default',
            '         -truetype -font verdana.ttf -shade 100 -quality 100 -mapbounds $lat1,$long1,$lat2,$long2 $markerfiles $greatarcfiles -image $image -geometry $output_inset_size',
            ],
         'default'  => '-truetype -font verdana.ttf -shade 100 -quality 100 -mapbounds $lat1,$long1,$lat2,$long2 $markerfiles $greatarcfiles -image $image -geometry $output_inset_size',
         'nr'       => $conf_offset + 6,
         },
      'HURRICANE_INSET_POSITION' => {
         'comment'  => [
            'The position of the insets, in the form "XxY"',
            '',
            'X: How far from the left/right corner we should position the inset',
            '   Negative numbers denote distance from the right',
            'Y: How far from the top we should position the inset',
            '   Negative numbers denote distance from the bottom',
            '',
            'Example: left,top',
            '         1x1',
            '',
            'Example: right,bottom',
            '         -1x-1',
            '',
            'Example: right,200 pixels from bottom',
            '         -1x-200',
            ],
         'default'  => '1x1',
         'nr'       => $conf_offset + 7,
         },
      'HURRICANE_NO_INSET_MARKER_LINE' => {
         'comment'  => [
          'Markerline to output if no inset could be found or no inset could be generated.',
          'Leave empty if you don\'t want that error message',
          '',
          'Example: No error message',
          '         <leave the option empty>',
          '',
          'Example: Standard text message',
          '         20 20 "NO HURRICANE INSET FOUND" image=none position=pixel align=right',
          '',
          'Example: Error image',
          '         150 150 "" image=hurricane_no_inset.jpg position=pixel',
            ],
         'default'  => ' 20 20 "NO HURRICANE INSET FOUND" image=none position=pixel align=right',
         'nr'       => $conf_offset + 8,
         },
      'HURRICANE_INSET_TIMETEXT' => {
         'comment'  => [
            'Output timestamps (local time!) next to the inset for',
            '  a) inset creation time',
            '  b) timestamp of the latest storm data on the website',
            '',
            'Leave empty if you don\'t want a timestamp message at all',
            '',
            'The template understands these tokens for inset creation time: ',
            '        $rdow (3-letter weekday),',
            '        $rday (day of month), ',
            '        $rmonth (month), ',
            '        $rmon_name (name of month)',
            '        $ryear, ',
            '        $rhour, ',
            '        $rmin, ',
            '        $rsec',
            '',
            'And these tokens for storm data timestamp:',
            '        $sdow, $sday, $smonth, $smon_name, $syear,',
            '        $shour, $smin, $ssec',
            '',
            'And these tokens for webpage update timestamp:',
            '        $wdow, $wday, $wmonth, $wmon_name, $wyear,',
            '        $whour, $wmin, $wsec',
            '',
            '<CR> is linefeed',
            '',
            'The text will be positioned at the top of the inset',
            ],
         'default'  => 'rendered  : $rdow $rday $rmon_name $rhour:$rmin<CR>storm data: $sdow $sday $smon_name $shour:$smin',
         'nr'       => $conf_offset + 9,
         },
      'HURRICANE_PATHTIME_TEMPLATE' => {
         'comment'  => [
            'A template for the markers we put at the start and end of each storm path',
            '',
            'Understands:',
            '   $lat, $long  - position',
            '   $color       - color of storm track at this point',
            '   $dow         - 3-letter weekday,',
            '   $day         - day of month, ',
            '   $month       - month, ',
            '   $mon_name    - name of month',
            '   $year, ',
            '   $hour, ',
            '   $min, ',
            '   $sec',
            '',
            'Leave empty to disable',
            ],
         'default'  => '$lat $long "$day $mon_name $hour:$min" color=$color',
         'nr'       => $conf_offset + 10,
         },
      }
   );

updatemyself();

my $xplanet_dir           = $cfg{$ONEPARAMFILE_DIR_OPTS}  ;
-d $xplanet_dir           || die("Could not find xplanet installation directory $xplanet_dir\n");
-r $xplanet_dir           || die("Could not read xplanet installation directory $xplanet_dir\n");
-f File::Spec->catfile($xplanet_dir,"rgb.txt")
                          || die("Could not find color definition file $xplanet_dir/rgb.txt\n");
-r File::Spec->catfile($xplanet_dir,"rgb.txt")
                          || die("Could not read color definition file $xplanet_dir/rgb.txt\n");

# where the xplanet marker files are
my $xplanet_markers_dir   = File::Spec->catdir($xplanet_dir,"markers");
-d $xplanet_markers_dir   || die("Could not find xplanet markers directory $xplanet_markers_dir\n");
-r $xplanet_markers_dir   || die("Could not read xplanet markers directory $xplanet_markers_dir\n");
-w $xplanet_markers_dir   || die("Could not write xplanet markers directory $xplanet_markers_dir\n");

# where the xplanet image files are
my $xplanet_images_dir    = File::Spec->catdir($xplanet_dir,"images");
-d $xplanet_images_dir    || die("Could not find xplanet images directory $xplanet_images_dir\n");
-r $xplanet_images_dir    || die("Could not read xplanet images directory $xplanet_images_dir\n");
-w $xplanet_images_dir    || die("Could not write xplanet images directory $xplanet_images_dir\n");
$compiled_inset_image     = abs2rel($compiled_inset_image,$xplanet_images_dir);

# where the inset image files are
my $xplanet_insets_dir    = File::Spec->catdir($xplanet_images_dir,"insets");
-d $xplanet_insets_dir    || die("Could not find xplanet insets directory $xplanet_insets_dir\n");
-r $xplanet_insets_dir    || die("Could not read xplanet insets directory $xplanet_insets_dir\n");

# where the xplanet greatarc files are
my $xplanet_arcs_dir      = File::Spec->catdir($xplanet_dir,"arcs");
-d $xplanet_arcs_dir      || die("Could not find xplanet arcs directory $xplanet_arcs_dir\n");
-r $xplanet_arcs_dir      || die("Could not read xplanet arcs directory $xplanet_arcs_dir\n");
-w $xplanet_arcs_dir      || die("Could not write xplanet arcs directory $xplanet_arcs_dir\n");

my $output_inset_size     = $cfg{'HURRICANE_INSET_SIZE'};
$output_inset_size =~ /^(\d+)x(\d+)$/ or die "Output inset size should be something like 300x300, not $output_inset_size\n";
my ($output_x_size,$output_y_size)=($1,$2);

# where the hurricane marker will be written to
my $hurricane_marker_file = File::Spec->catfile($xplanet_markers_dir,"hurricane");

# where the hurricane arc files will be written to
#
# the arc file for the big (global, whole-earth) view
my $hurricane_arc_file_global= File::Spec->catfile($xplanet_arcs_dir,"hurricane");
# the arc file for the inset
my $hurricane_arc_file_tight = File::Spec->catfile($xplanet_arcs_dir,"hurricane.tight");

my ($home_lat,$home_long) = determine_location();
die "could not determine your home location\n" if ! (defined $home_lat and defined $home_long);

my $always_inset          = $cfg{'HURRICANE_ALWAYS_INSET'};

my $choose_inset          = $cfg{'HURRICANE_CHOOSE_INSET'};

my $markerfiles           = $cfg{'HURRICANE_MARKERFILES'};
my @markerfiles           = grep {-f $_}                                    # existing file
                            map { -f $_ or $_=File::Spec->catfile($xplanet_markers_dir,$_);$_} # make absolute filename
                            grep {$_}                                       # non-empty string
                            map {s/^\s+//;s/\s+$//;$_}                      # make sure to take off all space
                            split(/\s+/,$markerfiles);                      # split at whitespace
push @markerfiles,$hurricane_marker_file;
@markerfiles              = map {abs2rel($_,$xplanet_markers_dir)}
                            @markerfiles;                                   # filename relative to marker dir
writedebug("markerfiles found: ".join(", ",@markerfiles));
                    

my $greatarcfiles         = $cfg{'HURRICANE_GREATARCFILES'};
my @greatarcfiles         = grep {-f $_}                                    # existing file
                            map { -f $_ or $_=File::Spec->catfile($xplanet_arcs_dir,$_);$_}    # make absolute filename
                            grep {$_}                                       # non-empty string
                            map {s/^\s+//;s/\s+$//;$_}                      # make sure to take off all space
                            split(/\s+/,$greatarcfiles);                    # split at whitespace
push @greatarcfiles,$hurricane_arc_file_tight;
@greatarcfiles              = map {abs2rel($_,$xplanet_arcs_dir)}
                            @greatarcfiles;                                 # filename relative to marker dir
writedebug("greatarcfiles found: ".join(", ",@greatarcfiles));

my $template_marker       = $cfg{'HURRICANE_MARKER_TEMPLATE'};

my $xplanet_command       = $cfg{'HURRICANE_XPLANET_CMD'};

my $inset_position        = $cfg{'HURRICANE_INSET_POSITION'};
$inset_position =~ /^(-?\d+)x(-?\d+)$/ or die "HURRICANE_INSET_POSITION is not of the form XxY\n";
my ($inset_position_x,$inset_position_y)=($1,$2);
my ($insettext_position_x,$insettext_position_y)=($inset_position_x,$inset_position_y);
$inset_position_x+=int($output_x_size/2*sgn($inset_position_x));
$inset_position_y+=int($output_y_size/2*sgn($inset_position_y));

my $error_marker_line     = $cfg{'HURRICANE_NO_INSET_MARKER_LINE'};

writedebug("inset: around ($home_lat,$home_long) of size ($inset_x_size,$inset_y_size)");

my $inset_timetext        = $cfg{'HURRICANE_INSET_TIMETEXT'};
$inset_timetext =~ s/\n//g;
$inset_timetext =~ s/<CR>/\n/g;

my $pathtime_template     = $cfg{'HURRICANE_PATHTIME_TEMPLATE'};

# in: -
# out: prints help text, exits
sub help {
	   print <<EOM ;

  $Script: download and create a marker file of currently active hurricanes
  to be used with xplanet.
  
  The only command line option this script understands is "-d". This 
  option turns on debuging mode, in which it will output additional
  information. This is usefull for tracking down errors.
  
  To set $Script up, set the XPLANET_DIR variable to your xplanet 
  directory and run it. Afterwards you should be able to find a 
  \"hurricane\" marker file inside xplanet's marker directory and a 
  \"hurricane\" greatarc file inside xplanet's arcs directory.

  You can customize the script further by editing some variables in the
  xplanet.conf configuration file.
  Don't worry, its really easy.

  Version: $VERSION
  Home: $homepage
   
  Installation: 
     Place this script into your xplanet directory
     Set XPLANET_DIR to xplanet's installation directory
     Run the script
  
EOM
   	exit 1;
}

help() if @ARGV;

delete $ENV{'DISPLAY'} if exists $ENV{'DISPLAY'};

########################################################################
#
#
#	Utility functions
#
#
########################################################################

# in: base URL, link
# out: link absolute URL
#
# this is only a 80% solution
sub relative_adress($$) {
   my ($base,$link)=@_;
   # non-local link
   if($link =~ /^http:\/\//) {
      return $link;
      }
   # absolute local link
   if($link =~ /^\//) {
      my $host=$base;
      $host =~ s/^(http:\/\/[^\/]).*/$1/;
      return $host.$link;
      }
   # relative local link
   my $dir = $base;
   $dir =~ s/\/[^\/]*$//;
   return $dir."/".$link;
}   

# in: either an inset hash ref or
#     (long1,long2)
# out: whether the inset is on the dateline
sub inset_on_dateline($;$) {
   my ($long1,$long2)=@_;
   if(!defined $long2) {
      my $inset=$long1;
      ($long1,$long2)=($inset->{'LONG1'},$inset->{'LONG2'});
      }
   return $long1 > $long2;
}   

sub lat_contained($$$) {
   my ($lat,$lat1,$lat2)=@_;
   return (($lat1 >= $lat) and ($lat2 <= $lat));
}   

sub long_contained($$$) {
   my ($long,$long1,$long2)=@_;
   if(!inset_on_dateline($long1,$long2)) {     
      # standard situation
      return (($long1 <= $long) and ($long <= $long2))
      }
   else {
      # special situation, inset contains date border so ins-L is pos while ins-R is neg.
      return (($long1 <= $long) or ($long <= $long2))
      }
}   

# in: coordinates, inset
# out: whether the point falls into the inset
sub inset_contains($$%) {
   my ($lat,$long,%inset)=@_;
   
   return (lat_contained($lat,$inset{'LAT1'},$inset{'LAT2'}) and
          long_contained($long,$inset{'LONG1'},$inset{'LONG2'}));
}

sub sqrt_sqr_difference($$$$) {
   my ($x1,$x2,$y1,$y2)=@_;
   return sqrt(sqr($x1-$x2)+sqr($y1-$y2));
}   

# in: coordinates, inset
# out: angle difference from center of inset to coordinates
sub inset_point_angle_difference($$%) {
   my ($lat,$long,%inset)=@_;
 
   my $center_lat= ($inset{'LAT1'} +$inset{'LAT2'})/2;
   my $center_long=($inset{'LONG1'}+$inset{'LONG2'})/2;
   my $adiff;
   if(inset_on_dateline(\%inset)) {
     $adiff=angle_difference($lat,$center_lat,$long,$center_long);
     }
  else {   
     $adiff=sqrt_sqr_difference($lat,$center_lat,$long,$center_long);
     }
   
   writedebug("considering diff $adiff ($inset{LAT1},$inset{LAT2}),($inset{LONG1},$inset{LONG2})");

   return $adiff;
}   

########################################################################
#
#
#	Main functions
#
#
########################################################################

sub time_2_vals($) {
   my ($time)=@_;
   my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)
      = localtime($time);
   $mon += 1;
   $year += 1900;

   foreach($mon,$mday,$hour,$min,$sec) {
      $_ ="0$_"  if $_<10;
      }
      
   return (
      'sec'      => $sec,
      'min'      => $min,
      'hour'     => $hour,
      'day'      => $mday,
      'month'    => $mon,
      'year'     => $year,
      'yday'     => $yday,
      'dow'      => $Hans2::WeekDay::SHORT[$wday],
      'mon_name' => $Hans2::MonthNames::SHORT[$mon],
      );   
}

# SPW
# in: n/a (the time marker template is global)
# out: the time marker line template, expanded
sub expand_time_marker($$) {

   my ($storm,$webpage)=@_;

   my %render=time_2_vals(time());
   my %webpage=time_2_vals($webpage);
   my %storm=time_2_vals($storm);

   my $text=$inset_timetext;
   
   foreach my $replace (keys %render) {
      $text =~ s/\$r$replace/$render{$replace}/g;
      $text =~ s/\$w$replace/$webpage{$replace}/g;
      $text =~ s/\$s$replace/$storm{$replace}/g;
      }
   
   my @table;
   foreach (split"\n",$text) {
      my @row;
      my %cell=( 'txt' => $_  );
      push @row,\%cell;
      push @table,\@row;
      }
   
   $text=table_2_markerfile(
      'x_start'  => $insettext_position_x,
      'y_start'  => $insettext_position_y,
      'd'        => \@table,
      );
   
   writedebug($text);

   return $text;
}

# SPW end


# hurricane info hash
#  lat, long - position
#  name      - name
#  wind      - current wind speed in knots
#  file      - url of more information
#  type      - cyclone, hurricane etc

# inset info hash
#  LAT1, LAT2, LONG1, LONG2 - position
#  REGION                   - region name, like eastern_n_america
#  IMAGE                    - image name, like inset_90.0N_95.0E-85.0N_100.0E.jpg
#  XSIZE, YSIZE

# in: hurricane info hash
# out: the markerfile template, expanded
sub expand_template_marker(%) {
   my (%hur)=@_;

   my $text=$template_marker;
   
   my ($lat,$long,$name,$wind,$file,$type)=@hur{'lat','long','name','wind','file','type'};
   
   # try to format the marker file nicely by keeping columns the same width
   my $lat_str  = sprintf_num_locale("% 7.2f",$lat);
   my $long_str = sprintf_num_locale("% 7.2f",$long);

   $name=uc($name);
   $name =~ s/\b([A-Z])([A-Z]+)/$1.lc($2)/eg;
   my $name1 = sprintf("%s",$name);
   my $name2 = sprintf("%-17s",'"'.$name.'"');
   
   my $stype=$type_2_stype{$type} || '<?>';
   my $ltype=$type_2_ltype{$type} || '<unknown>';
   
   my $mph=round(convert_units($wind,'knots','mph')) || '???';
   my $kmh=round(convert_units($wind,'knots','kmh')) || '???';
   $wind ||= '???';
   
   my $METRIC=$PARAMS{$ONEPARAMFILE_METRIC_OPTS};
   my $ourunit;
   my $ourwind;
   if($METRIC) {
      $ourunit="km/h";
      $ourwind=$kmh;
      }
   else {
      $ourunit="mph";
      $ourwind=$mph;
      }
   
   $text =~ s/\$lat/$lat_str/g;
   $text =~ s/\$long/$long_str/g;
   $text =~ s/"\$name"/$name2/g;
   $text =~ s/\$name/$name1/g;
   $text =~ s/\$knwind/$wind/g;
   $text =~ s/\$miwind/$mph/g;
   $text =~ s/\$kmwind/$kmh/g;
   $text =~ s/\$wind/$ourwind/g;
   $text =~ s/\$unitwind/$ourunit/g;
   $text =~ s/\$file/$file/g;
   $text =~ s/\$type/$type/g;
   $text =~ s/\$stype/$stype/g;
   $text =~ s/\$ltype/$ltype/g;
   
   $text =~ s/\s+$//;
   
   return $text;
}

# in: hurricane info hash
# out: the template, expanded
sub expand_template_arc($$$$$$$$) {
   my ($lat1,$long1,$lat2,$long2,$color,$spacing,$name,$wind)=@_;
   
   my @coords = map {sprintf_num_locale("%.2f",$_)} ($lat1,$long1,$lat2,$long2);
   $wind||='???';

   return join(" ",@coords)." color=$color spacing=$spacing # $name at $wind";
}

# in: inset information
# out: list of 
#         command
#         options hash
sub expand_xplanet_cmd(%) {
   my (%inset)=@_;
   my($lat1,$long1,$lat2,$long2,$region,$image)=
      @inset{'LAT1','LONG1','LAT2','LONG2','REGION','IMAGEFILE'};
   
   my $markerfiles_cmd="-markerfile ".join(" -markerfile ",@markerfiles);
   my $greatarcfiles_cmd="-greatarcfile ".join(" -greatarcfile ",@greatarcfiles);
   
   my $rel_image=File::Spec->catfile(
                    File::Spec->catdir($xplanet_insets_dir,$region),
                    $image
                    );
   $rel_image = abs2rel($rel_image,$xplanet_images_dir);
   
   my $out=File::Spec->catfile($xplanet_images_dir,$compiled_inset_image);
   
   my $text=$xplanet_command;
   $text =~ s/-output \S+//;
   
   $text =~ s/\$lat1/$lat1/g;
   $text =~ s/\$lat2/$lat2/g;
   $text =~ s/\$long1/$long1/g;
   $text =~ s/\$long2/$long2/g;
   $text =~ s/\$image/$rel_image/g;
   $text =~ s/\$output_inset_size/$output_inset_size/g;
   $text =~ s/\$markerfiles/$markerfiles_cmd/g;
   $text =~ s/\$greatarcfiles/$greatarcfiles_cmd/g;
   
   return (xplanetcmd_2_opts($text));
}

# in: filename of .inf file
# out: array of information hashes
sub inf_readfile($) {
   my ($fn)=@_;
   writedebug("    starting to parse INF $fn");
   my @txt=readfile($fn);
   @txt || die "could not open $fn: $!\n";
   my %inf;
   my @ret;
LINE:
   foreach(@txt) {
      s/#.*//;       # take off everything after #
      s/^\s+//;      # take off begining spaces
      s/\s+$//;      # take off finishing spaces
      next LINE if !$_;   # don't use if empty or only comment
      if(/^-+$/) {
         my %inf_copy=%inf;
         %inf=();
         push @ret,\%inf_copy if %inf_copy;
         }
      elsif(/^(\w+)\s*=\s*(.*)$/) {   # match
         my ($key,$val)=($1,$2);
         $key=uc($key);
         $inf{$key}=$val;
         }
      else {
         die ".inf file $fn: line \"$_\" not understood.\n";
         }
      }
   push @ret,\%inf if %inf;
   writedebug("    done parsing INF $fn");
   return @ret;   
}   

# SPW start
# SPW
# in: "yyyy-mm-dd hh:mm UT"
# out: (in) converted to local time and expressed as epoch time
#
# parses update date/time of the first storm from the website (which
# is given in GMT), converts to the local timezone and to epoch time
#
sub parse_mainstorm_datetime($) {
   my ($year,$mon,$mday,$hour,$min) = (0,1,1,0,0);
   foreach(@_) {
      if(/^(\d+)-(\d+)-(\d+) (\d+):(\d+) \w+/) {
         ($year,$mon,$mday,$hour,$min)=($1,$2,$3,$4,$5);
         }
      }
   my $time = timegm(0, $min, $hour, $mday, $mon-1, $year-1900);
   return ($time);
}

# returns hashref,array 
# where hashref is
#    'webpage_timestamp'  => newest storm on page
# and array contains hashes
#     'name' => 
#     'type' =>
#     'file' => URL of info
#     'time' => 
#     'lat','long','name','speed', 'wind' etc
sub parse_main_webpage() {
   
   my @txt;  # contains text to parse
   
   #
   # get and parse the main hurricane file
   #
   
   # keep only important lines
   my $mainpage=get_webpage($URL) || die "could not download $URL\n";
   my @hurr=grep {$_} map {s/^\s+//;s/\s+$//;s/\s+/ /g;$_} split("\n",$mainpage);
   # take off section above data
   while(shift(@hurr) !~ /^<H2>Current Storms:<\/H2>$/) {};
   shift @hurr;shift @hurr;
   while($hurr[0] !~ /^<\/PRE>$/) {
      push @txt,shift @hurr;
      if(!@hurr) {
         writedebug("Could not find </PRE> pattern in $URL");
         exit;
         }
      };
   
   # array of hashes, will be returned
   my @data; 
   my $latest_time=0;
   
   # parse each line
   foreach(@txt) {

#      writedebug("processing line $_");
#      if(/^(\w+) <A HREF="([\w\d\_\-\.\/]+\.html)">(\w+)<\/A> [\d\-]+ \d+:\d+ \w+ ([\d\.]+[SN]) ([\d\.]+[WE]) ([\d\?]+) kts/) {
#         my ($type,$file,$name,$lat,$long,$wind)=($1,$2,$3,$4,$5,$6);

      #    CYC <A HREF="Data/ERROL-02.html   ">ERROL</A>  2002-05-12 18:00 UT 07.4S  094.4E  040 kts  <A HREF="GifArchive/ERROL-02.gif">ERROL</A> <A HREF="/Tropical/Gif/sin.latest.gif">S Indian</A>  
# SPW start
      if(/^(\w+) <A HREF="([\w\d\_\-\.\/]+\.html)">(\w+)<\/A> ([\d\-]+ \d+:\d+ \w+) ([\d\.]+[SN]) ([\d\.]+[WE]) ([\d\?]+) kts/) {
         my ($type,$file,$name,$datetime,$lat,$long,$wind)=($1,$2,$3,$4,$5,$6,$7);
# SPW end

         my $sign;
         
         $lat =~ s/^0+//;
         $lat =~ /(\d+\.\d+)([SN])$/;
         ($lat,$sign)=($1,$2);
         $lat=makenum($lat,1);
         $lat *= -1 if $sign =~ /s/i;
   
         $long =~ s/^0+//;
         $long =~ /(\d+\.\d+)([WE])$/;
         ($long,$sign)=($1,$2);
         $long=makenum($long,1);
         $long *= -1 if $sign =~ /w/i;
         
         $wind =~ s/^0+//;
         $wind=0 if $wind eq '???';
         $wind=makenum($wind,1);
         
         $file=relative_adress($URL,$file);
         
         $type=uc($type);

         writedebug("found storm $name: type=$type, file=$file, pos=($lat,$long), wind speed=$wind");
   
         $datetime    = parse_mainstorm_datetime($datetime);
         $latest_time = max_simple($latest_time,$datetime);

         push @data, {
            'type'   => $type,
            'file'   => $file,
            'name'   => $name,
            'lat'    => $lat,
            'long'   => $long,
            'wind'   => $wind,
            'time'   => $datetime,   # SPW: the latest timestamp up to this storm
           };
         }
      }
      
   return ({'webpage_timestamp'=>$latest_time},@data);
}      

# in: URL for hurricane specific information
# out: two array refs : actual and forecast path
#      earliest time for 
#
# each element in the arrays is a hash of
#         'act'    => whether its actual (or forecast)
#         'course' => direction (degrees)
#         'gusts'  => speed,
#         'lat','long' => position
#         'name'   => hurricane name,
#         'pres'   => pressure
#         'speed'  => speed of the hurricane center
#         'time'   => seconds in UTC
#         'type'   => type of hurricane
#         'wind'   => wind speed
#         'wmo'    => ID
#   
sub parse_one_hurricane($$) {
   my ($file,$h_name)=@_;
   writedebug("processing hurricane $h_name");
   my @hur_path_act;
   my @hur_path_for;
   my $hur_page=get_webpage($file);
   my $earliest_time=time();
   my $latest_time=0;
   my %earliest_point;
   my %latest_point;
   if(!$hur_page) {
      warn "could not download $file\n";
      next;
      }
   foreach (split(/<TR>/,$hur_page)) {
      next if ! /<TD ALIGN=CENTER>\d+<\/TD>/;
      s/<\/TR>.*//s;
      s/^\s+//;
      s/\s+$//;
      s/\s+/ /g;
#      
      my @a=grep {defined $_ and "$_" ne ""} map {s/<\/TD>\s*$//;$_} split(/<TD ALIGN=CENTER>/);
      my ($name,$date,$time,$lat,$long,$course,$speed,$pres,$wind,$gusts,$type,$act,$wmo)=@a;
      my $sign;
      
#      writedebug("got record name=$name, date=$date, time=$time, lat=$lat, long=$long ,act=$act");
      
      $lat =~ s/^0+//;
      $lat =~ /(\d+\.\d+)([SN])$/ || die "did not understand latitude $lat\n";
      ($lat,$sign)=($1,$2);
      $lat=makenum($lat,1);
      $lat *= -1 if $sign =~ /s/i;

      $long =~ s/^0+//;
      $long =~ /(\d+\.\d+)([WE])$/ || die "did not understand longitude $long\n";
      ($long,$sign)=($1,$2);
      $long=makenum($long,1);
      $long *= -1 if $sign =~ /w/i;
      
      $course=makenum($course,0);
      $speed=makenum($speed,0);
      $pres=makenum($pres,0);
      $wind=0 if $wind eq '???';
      $wind=makenum($wind,0);
      $gusts=makenum($gusts,0);
      
      $type=uc($type);
      $type=undef if $type =~ /\?\?\?/;

      $act eq 'ACT' or $act eq 'FOR' or 
           die "did not understand $act: is this an actual position or a forecast?\n";
      $act = ($act eq 'ACT' ? 1 : 0);
      
      $date =~ /^(\d\d\d\d)-(\d\d)-(\d\d)$/ || die "did not understand date $date\n";
      my ($year,$month,$day)=($1,$2,$3);
      $time =~ /^(\d\d):(\d\d)$/ || die "did not understand time $time\n";
      my ($hour,$min)=($1,$2);
      $time=timegm(0,$min,$hour,$day,$month-1,$year);
      
      
#      writedebug("               =$name, date=$date, time=$time, lat=$lat, long=$long, act=$act");

      my %info=(
         'act'    => $act,
         'course' => $course,
         'gusts'  => $gusts,
         'lat'    => $lat,
         'long'   => $long,
         'name'   => $h_name,
         'pres'   => $pres,
         'speed'  => $speed,
         'time'   => $time,
         'type'   => $type,
         'wind'   => $wind,
         'wmo'    => $wmo,
         );
         
      $earliest_time=min_simple($earliest_time,$time);
      %earliest_point=%info if $earliest_time==$time;
      $latest_time  =max_simple($latest_time,$time);
      %latest_point  =%info if $latest_time==$time;

      if($act) {
         push @hur_path_act,\%info;
         }
      else {   
         push @hur_path_for,\%info;
         }
      
      }
    
   return (\@hur_path_act,\@hur_path_for,\%earliest_point,\%latest_point);   

}

# in: INF filename
#     region name
#     information hash
# out: information hash, cleared up
sub understand_inset($$) {
   my ($inf_file,$inf)=@_;
   
   # check that location info is included
   foreach my $req_key ('REGION','IMAGEFILE') {
      defined($inf->{$req_key}) || die ".inf file $inf_file: could not find required key $req_key\n";
      }
   my $image=$inf->{'IMAGEFILE'};   

   # adjust sizes
   my $xs=$inf->{'XSIZE'};
   my $ys=$inf->{'YSIZE'};
   my $ss=$inf->{'SIZE'};
   $xs ||= $ss;
   $ys ||= $ss;
   $ss   = $xs if !$ss and $xs and $ys and $xs==$ys;
   $inf->{'XSIZE'}=$xs;
   $inf->{'YSIZE'}=$ys;
   $inf->{'SIZE'} =$ss;
   
   # parse latitudes
   foreach my $lat ('LAT1','LAT2') {
      my $l=$inf->{$lat};
      defined $l || die "$inf_file, image $image: latitude $lat not specified";
      $l =~ /(\d+(?:\.\d+)?)([NS])/ || die "$lat $l in $inf_file:$image not understood.";
      my $sign;
      ($l,$sign)=($1,$2);
      $l=makenum($l,0);
      $l*=(-1) if $sign eq 'S';
      $inf->{$lat}=$l;
      }   
      
   # parse longitudes
   foreach my $long ('LONG1','LONG2') {
      my $l=$inf->{$long};
      defined $l || die "$inf_file, image $image: longitude $long not specified";
      $l =~ /(\d+(?:\.\d+)?)([WE])/ || die "$long $l in $inf_file:$image not understood.";
      my $sign;
      ($l,$sign)=($1,$2);
      $l=makenum($l,0);
      $l*=(-1) if $sign eq 'W';
      $inf->{$long}=$l;
      }   
      
   return $inf;
}   

# in: INF file name
# out: array of information hashes
sub parse_inf_file($) {
   my ($inf_file)=@_;
   writedebug("processing $inf_file");
   
   my $inf_base=basename($inf_file);
   $inf_base =~ s/\.inf$//;

   # get the options
   my @inf=inf_readfile($inf_file);

   foreach (@inf) {
      $_->{'REGION'}=$inf_base;
      understand_inset($inf_file,$_);
      }

   return @inf;
}      

# returns array of information hashes
sub parse_inset_db() {
   my @inset_db;
   foreach(my_glob($xplanet_insets_dir,'*.inf',sub {-f $_ and -r $_})) {
      push @inset_db,parse_inf_file($_);
      }
   writedebug("inset database contains ".scalar(@inset_db)." entries");
   return @inset_db;
}

# return whether we could find an inset image
#
# in: inset information hash
# out: 1 - its there
#      false - its not there and can't be acquired
sub find_inset_image($) {
   my ($inset)=@_;
   my $img=$inset->{'IMAGEFILE'};
   my $region=$inset->{'REGION'};
   die "can't find image because filename not known\n" if !$img;
   die "can't find image because region not known\n"   if !$region;
   my $file=File::Spec->catfile(
                File::Spec->catdir($xplanet_insets_dir,$region),
                $img);
   if(-f $file) {
      writedebug("$file already existing");
      return 1;
      }
   return get_webpage($inset_lib_URL.$region."/".$img,
                      'file'             => $file,
                      'cache_expiration' => -1
                      );
}   

# output marker file
sub write_marker_file(@) {
   my (@storms)=@_;
   local *HUR_M;
   writedebug("writing $hurricane_marker_file");
   open(HUR_M,">$hurricane_marker_file") || die("Could not open hurricane markers $hurricane_marker_file for writing: $!\n");;
   print HUR_M "# Hurricane marker file created by $Script version $VERSION\n";
   print HUR_M "# For more information read the top of the $Script script or go to\n";
   print HUR_M "# $homepage\n";
   print HUR_M "\n";
   foreach my $hurricane (@storms) {
      my $txt=expand_template_marker(%$hurricane);
      writedebug($txt);
      print HUR_M "$txt\n";
      }
   close HUR_M;   
}

sub write_pathtime_one(%) {
   my (%p)=@_;
   my $lat=$p{'lat'};
   my $long=$p{'long'};
   my %time=time_2_vals($p{'time'});
   
   my $type   = $p{'type'};
   my $wind;
   my $wind1=$p{'wind'};
   my $wind2=$p{'wind'};
   if(!$wind1 and $wind2) {
      $wind=$wind2;
      }
   elsif(!$wind2 and $wind1) {
      $wind=$wind1;
      }
   elsif($wind1 and $wind2) {      
      $wind=($wind1 + $wind2) / 2;
      }
   else {
      $wind='';
      }   

   my $color=$type_2_color{$type} if $type;
   $color ||= wind_2_color($wind);
   
   my $txt=$pathtime_template;
   
   foreach my $repl (keys %time) {
      $txt =~ s/\$$repl/$time{$repl}/g;
      }
   $txt =~ s/\$lat/$lat/g;   
   $txt =~ s/\$long/$long/g;   
   $txt =~ s/\$color/$color/g;   
   
   return $txt;
   
}

sub write_pathtime(@) {
   my (@storms)=@_;
   return if !$pathtime_template;
   local *HUR_M;
   writedebug("writing $hurricane_marker_file");
   open(HUR_M,">>$hurricane_marker_file") || die("Could not open hurricane markers $hurricane_marker_file for writing: $!\n");;
   foreach my $hurricane (@storms) {
      my $earl=$hurricane->{'earliest'};
      my $late=$hurricane->{'latest'};
      
      my $txt=write_pathtime_one(%$earl);
      writedebug($txt);
      print HUR_M $txt."\n";
      
      $txt=write_pathtime_one(%$late);
      writedebug($txt);
      print HUR_M $txt."\n";
   
      }
   close HUR_M;   
}   


# write one arc segment:
#    $p1,$p2      - the 2 points (as hasherefs)
#    $is_global   - intended for inset or global map?
sub write_arc_file_one($$$) {
   my ($p1,$p2,$is_global)=@_;
   my $lat1   = $p1->{'lat'};
   my $long1  = $p1->{'long'};
   my $lat2   = $p2->{'lat'};
   my $long2  = $p2->{'long'};
   
   my $h_name = $p2->{'name'};
   
   my $act    = $p2->{'act'};

   my $type   = $p2->{'type'};
   
   my $spacing;
   
   $spacing = $is_global ? 
              ($act ? $spacing_global_act : $spacing_global_for) : 
              ($act ? $spacing_inset_act  : $spacing_inset_for);
   
   my $wind;
   my $wind1=$p1->{'wind'};
   my $wind2=$p2->{'wind'};
   if(!$wind1 and $wind2) {
      $wind=$wind2;
      }
   elsif(!$wind2 and $wind1) {
      $wind=$wind1;
      }
   elsif($wind1 and $wind2) {      
      $wind=($wind1 + $wind2) / 2;
      }
   else {
      $wind='';
      }   
   
   my $color=$type_2_color{$type} if $type;
   $color ||= wind_2_color($wind);
   
   return expand_template_arc($lat1,$long1,$lat2,$long2,$color,$spacing,$h_name,$wind);
   }
   
# output greatarc file
sub write_arc_file($$$$) {
   my ($fn,$is_global,$paths_act,$paths_for)=@_;
   writedebug("writing $fn");
   local *HUR_A;
   open(HUR_A,">$fn") || die("Could not open hurricane greatarc file $fn for writing: $!\n");;
   print HUR_A "# Hurricane greatarc file created by $Script version $VERSION\n";
   print HUR_A "# For more information read the top of the $Script script or go to\n";
   print HUR_A "# $homepage\n";
   # actual data
   my %last_known_location;
   foreach my $h_name (keys %$paths_act) {
      print HUR_A "\n";
      print HUR_A "# actual data for hurricane $h_name\n";
      my $path=$paths_act->{$h_name};
      my @path=@$path;
      my $last = shift @path;
      my $wrote_one=0;
      foreach my $pos (@path) {
         my $txt=write_arc_file_one($last,$pos,$is_global);
         writedebug($txt) if !$wrote_one;
         print HUR_A "$txt\n";
         $wrote_one=1;
         $last=$pos;
         }
      $last_known_location{$h_name}=$last;   
      }
   #forecast data
   foreach my $h_name (keys %$paths_for) {
      print HUR_A "\n";
      print HUR_A "# forecast data for hurricane $h_name\n";
      my $path=$paths_for->{$h_name};
      my @path=@$path;
      my $last=$last_known_location{$h_name};
      my $wrote_one=0;
      foreach my $pos (@path) {
         my $txt=write_arc_file_one($last,$pos,$is_global);
         writedebug($txt) if !$wrote_one;
         print HUR_A "$txt\n";
         $wrote_one=1;
         $last=$pos;
         }
      }
   close HUR_A;   
}

sub position_2_inset_inf($$) {
   my ($lat,$long)=@_;
   my @inset_db=parse_inset_db();
   my @containing_insets = grep { inset_contains($lat,$long,%$_)} @inset_db;
   die "could not find insets containing ($lat,$long)\n" if !@containing_insets;               
   writedebug("found ".scalar(@containing_insets)." insets containing ($lat,$long)");
   @containing_insets = grep {
                  $_->{'XSIZE'}==$inset_x_size and
                  $_->{'YSIZE'}==$inset_y_size
                  } @containing_insets;
   die "could not find insets of size ($inset_x_size,$inset_y_size)\n" if !@containing_insets;               
   writedebug("found ".scalar(@containing_insets)." containing insets of correct size");
   
   my $home_inset=min(sub {return inset_point_angle_difference($lat,$long,%$_)}, @containing_insets);
   writedebug("source inset:".
             " (" .$home_inset->{'LAT1'}.
             ",".$home_inset->{'LAT2'}.
             "), (" .$home_inset->{'LONG1'}.
             ",".$home_inset->{'LONG2'}.
             ")"
             );
   return $home_inset;
}

sub best_lat($) {
   my ($lat) = @_;
   my $blat = int(abs($lat*10)/25) * 2.5 * sgn($lat);

   if (abs($lat-$blat) > 1.25) {
      $blat += (2.5 * sgn($lat));
      }
   if ($blat ==  90.0) {$blat =  87.5;};
   if ($blat == -90.0) {$blat = -87.5;};

   return $blat;
   }

sub best_long($) {
   my ($long) = @_;
   my $blong = int(abs($long*10)/25) * 2.5 * sgn($long);

   if (abs($long-$blong) > 1.25) {
      $blong += (2.5 * sgn($long));
      }
   if ($blong == -180.0) {$blong =  180.0;};

   return $blong;
   }

sub position_2_infname($) {
   my ($pos)=@_;
   return "0" if !$pos;
   return sprintf_num_locale("%.1f",$pos);
}   

sub position_2_inset_math($$) {
   my ($lat,$long)=@_;
   my $center_lat=best_lat($lat);
   my $center_long=best_long($long);
   my %inset=(
      'LAT1'  => $center_lat+2.5,
      'LAT2'  => $center_lat-2.5,
      'LONG1' => $center_long-2.5,
      'LONG2' => $center_long+2.5,
      );
   my $lat1=$inset{'LAT1'};
   if($lat1<1) {
      $lat1*=-1;
      $lat1=position_2_infname($lat1)."S";
      }
   else {
      $lat1=position_2_infname($lat1)."N";
      }
   my $lat2=$inset{'LAT2'};
   if($lat2<1) {
      $lat2*=-1;
      $lat2=position_2_infname($lat2)."S";
      }
   else {
      $lat2=position_2_infname($lat2)."N";
      }
   my $long1=$inset{'LONG1'};
   if($long1<1) {
      $long1*=-1;
      $long1=position_2_infname($long1)."W";
      }
   else {
      $long1=position_2_infname($long1)."E";
      }
   my $long2=$inset{'LONG2'};
   if($long2<1) {
      $long2*=-1;
      $long2=position_2_infname($long2)."W";
      }
   else {
      $long2=position_2_infname($long2)."E";
      }
   $inset{'IMAGEFILE'}="inset_${lat1}_${long1}-${lat2}_${long2}.jpg";
   $inset{'REGION'}='all';
   return \%inset;
}

# find the home inset
sub position_2_inset($$) {
   my ($lat,$long)=@_;
   my @finders;
   push @finders,\&position_2_inset_math;
   push @finders,\&position_2_inset_inf;
   
   foreach my $finder (@finders) {
      my $inset=$finder->($lat,$long);
      next if !$inset;
      if(!find_inset_image($inset)) {
         writedebug("but can not find that inset anywhere");
         next;
         } 
      return $inset;   
      }
   return;   
}

########################################################################
#
#
#	Main program
#
#
########################################################################

my ($global_data,@storms)=parse_main_webpage();
my $webpage_timestamp=$global_data->{'webpage_timestamp'};

my %paths_act;  # actual
my %paths_for;  # forcast
foreach my $hurricane (@storms) {
   my $h_name= $hurricane->{'name'};
   my $file  = $hurricane->{'file'};
   my ($act,$for,$earliest,$latest)=parse_one_hurricane($file,$h_name);
   $paths_act{$h_name}=$act;
   $paths_for{$h_name}=$for;
   $hurricane->{'earliest'}=$earliest;
   $hurricane->{'latest'}  =$latest;
   }   

# now @storms contains hashes as returned by parse_main_webpage()
# as well as 'earliest' => point hash for the earliest time
#            'latest'   => point hash for latest time

# %paths_act and %paths_for are
#   'name' => array of point hashes
   
write_marker_file(@storms);
write_pathtime(@storms);
write_arc_file($hurricane_arc_file_global,1,\%paths_act,\%paths_for);
write_arc_file($hurricane_arc_file_tight,0,\%paths_act,\%paths_for);

exit 0 if $choose_inset eq 'none';

exit 0 if !@storms and !$always_inset;

$choose_inset = 'home' if !@storms and $choose_inset eq 'nearest storm';

# coordinates we are looking for
my $inset_lat;
my $inset_long;

if($choose_inset eq 'nearest storm') {
   my $nearest_storm = min(sub {
                       return angle_difference($home_lat,$_->{'lat'},$home_long,$_->{'long'});
                       },@storms);
   $inset_lat=$nearest_storm->{'lat'};
   $inset_long=$nearest_storm->{'long'};
   writedebug("inset near storm ".$nearest_storm->{'name'}." at ($inset_lat,$inset_long) requested");
   }
else {
   $inset_lat = $home_lat;
   $inset_long= $home_long;
   }   

my $home_inset=position_2_inset($inset_lat,$inset_long);      
   
my @storms_in_home_inset = grep { inset_contains($_->{'lat'},$_->{'long'},%$home_inset) } @storms;

# decide if we show an inset          
if(($choose_inset eq 'home') and (!$always_inset) ){

   # find storms inside the home inset
   if(!@storms_in_home_inset) {
      writedebug("no storms found in the home inset and no inset painting required. bailing out.");
      exit 0;
      }
   else {
      writedebug("found ".scalar(@storms_in_home_inset)." storms in the inset, continuing");
      }   
   }
   
# now we wrote $hurricane_marker_file and $hurricane_arc_file
#
# next, we need to generate the inset with the storms
# our home inset is $home_inset

if($home_inset) {

   my ($cmd,%opts)=expand_xplanet_cmd(%$home_inset);
   if(execute_xplanet($cmd,
                      %opts,
                      'output' => File::Spec->catfile($xplanet_images_dir,$compiled_inset_image),
                      )) {

      my $latest_storm_time;
      if(@storms_in_home_inset) {
         $latest_storm_time=max_simple map {$_->{'time'}} @storms_in_home_inset;
         }
      else {
         $latest_storm_time=$webpage_timestamp;
         }   
                      
      # now we need to extend the hurricane marker file with the info about that inset
      local *HUR_M;
      open(HUR_M,">>$hurricane_marker_file") || die("Could not open hurricane markers $hurricane_marker_file for appending: $!\n");;
      my $inset_marker_line="$inset_position_y $inset_position_x \"\" image=$compiled_inset_image position=pixel";      writedebug($inset_marker_line);
      print HUR_M "$inset_marker_line\n";
      print HUR_M expand_time_marker($latest_storm_time,$webpage_timestamp)."\n" if $inset_timetext;
      close HUR_M;   
      }
   elsif($error_marker_line) {   
      local *HUR_M;
      open(HUR_M,">>$hurricane_marker_file") || die("Could not open hurricane markers $hurricane_marker_file for appending: $!\n");;
      writedebug($error_marker_line);
      print HUR_M "$error_marker_line\n";
      close HUR_M;
      }
      
}
   
