#!/usr/bin/perl -w

# This uses the Weekly Volcanic Activity Report of the Smithsonian and xplanet to show
# active volcanoes on your desktop
#
# INSTALL: Put this script in your xplanet directory
#          Run it once
#          It should create or update the xplanet.conf configuration file
#          Adjust any variables inside that file, if needed (you likely don't have to)
#
# homepage/newest version: http://hans.ecke.ws/xplanet
#
# Usage: * call the script.  It will write a markerfile 'volcano' to xplanet/marker/
#        * put '-markerfile volcano' in your xplanet commandline
#
# Copyright 2002 Hans Ecke <hans@ecke.ws>
#
# Licence: Gnu Public License. In short: This comes without any warranty. Redistribution
#          of the original or changed versions must leave this Copyright statement intact -AND-
#          provide the sourcecode for free.
#
# Written and tested on Linux and Windows 98. Especially the behavior on
# Windows is poorly tested
#
# Comment, suggestions, bugreports are very much appreciated!
#
# Needs:   Perl      version 5.6 or later     http://www.perl.com (Unix)
#                                             http://www.activestate.com/Products/ActivePerl/ (Windows)
#          xplanet   version 0.91 or later    http://xplanet.sourceforge.net
#
# ChangeLog: Version
#          2.1.3:
#          2.1.2: windows fixes
#          2.1.1:
#            2.1: auto-updating; improved config file handling
#            2.0: source code cleanup: share between all xplanet perl scripts
#                 new unified configuration system using the xplanet.conf file
#                 changed license to GPL
#            1.0: this really isn't beta anymore, so I bump the version number.
#                 no feature or bug updates, just change of status to stable software
#          0.9.6: updated caching
#          0.9.5: caching get_webpage()
#                 windows and non-US compatibility fixes, thanks Stefan P. Wolf
#                 fixed month and year in writedebug() thanks Stefan P. Wolf
#                 deal with unknown summit elevation
#                 better parsing
#          0.9.4: new address to get the info from
#          0.9.3: -d command line switch
#          0.9.2: no parse errors if the webpage uses faulty HTML:
#                 no &deg; but the actual <degree> sign
#          0.9.1: one more line of debug output
#                 take changed format of source webpage into account
#            0.9: initial release
#                 thanks Felix & Bernhard for additional volcano icons!


require 5.006;

use FindBin;
use lib $FindBin::Bin;
use LWP::UserAgent;
use LWP::Simple;
use Time::Local;
use File::Basename;
use File::Spec;

# the file we try to download
my $URL = "http://www.volcano.si.edu/gvp/reports/usgs/index.cfm";

# if downloaded copy found, when will it be considered too old?
# -1 means: consider any content of cache fresh
# in seconds (one hour = 60*60 = 3600)
our $cache_expiration=60*60*2.5;

# the configuration file
my $conffile=$ENV{'XPLANET_SCRIPTS_CONF'} || 'xplanet.conf';

our $VERSION="2.1.5";

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
Hans2::OneParamFile->import();
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

writedebug("version: $VERSION");

my $conf_offset=soundex_number($Scriptbase)*100;

my %cfg=check_param(
   'file'   => $conffile,
   'check'  => {
      $ONEPARAMFILE_DIR_OPTS => \%ONEPARAMFILE_DIR_OPTS,
      'VOLCANO_TEMPLATE' => {
         'comment'  => [
            'How each marker file looks like. Can understand those symbols:',
            '   $lat        - latitude',
            '   $long       - longitude',
            '   $name       - mountain name',
            '   $elev       - summit elevation in meters',
            '   <CR>        - inset a linebreak. This makes it possible to have multiple',
            '                 markerlines per volcano',
            ],
         'default'  => '$lat $long "$name" image=volcano.png color=red transparent={255,255,255} # summit: $elev',
         'nr'       => $conf_offset,
         },
      },

);

updatemyself();

my $xplanet_dir           = $cfg{$ONEPARAMFILE_DIR_OPTS};
-d $xplanet_dir           || die("Could not find xplanet installation directory $xplanet_dir\n") ;
-r $xplanet_dir           || die("Could not read xplanet installation directory $xplanet_dir\n") ;

my $xplanet_markers_dir   = File::Spec->catdir($xplanet_dir,"markers");
-d $xplanet_markers_dir   || die("Could not find xplanet markers directory $xplanet_markers_dir\n") ;
-r $xplanet_markers_dir   || die("Could not read xplanet markers directory $xplanet_markers_dir\n") ;
-w $xplanet_markers_dir   || die("Could not write xplanet markers directory $xplanet_markers_dir\n") ;

my $volcano_marker_file   = File::Spec->catfile($xplanet_markers_dir,"volcano");

my $template              = $cfg{'VOLCANO_TEMPLATE'};
$template =~ s/\<CR\>/\n/g;

# in: -
# out: prints help text, exits
sub help {
	   print <<EOM ;

  $Script: download and create a marker file of currently active volcanoes
  to be used with xplanet.

  The only command line option this script understands is "-d". This
  option turns on debuging mode, in which it will output additional
  information. This is usefull for tracking down errors.

  To set $Script up, set the XPLANET_DIR variable to your xplanet
  directory and run it. Afterwards you should be able to find a
  \"volcano\" marker file inside xplanet's marker directory.

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

########################################################################
#
#
#	Main Program
#
#
########################################################################

# in: latitude, longitude, mountain name, summit elevation
# out: the template, expanded
sub expand_template($$$$) {
   my ($lat,$long,$name,$elev)=@_;

   my $text=$template;

   # try to format the marker file nicely by keeping columns the same width
   my $lat_str  = sprintf_num_locale("% 7.2f",$lat);
   my $long_str = sprintf_num_locale("% 7.2f",$long);

   my $name1 = sprintf("%-15s",$name);
   my $name2 = sprintf("%-17s",'"'.$name.'"');

   $elev='???' if !$elev;

   $text =~ s/\$lat/$lat_str/g;
   $text =~ s/\$long/$long_str/g;
   $text =~ s/"\$name"/$name2/g;
   $text =~ s/\$name/$name1/g;
   $text =~ s/\$elev/$elev/g;

   $text =~ s/\s+$//;

   return $text;
}

my @data;  # contains info hashes

{ # get and parse the volcano file
my $volcanoes=get_webpage($URL);
die "could not download $URL\n" if !$volcanoes;
foreach(split("\n",$volcanoes)) {
   chomp;
    #<span class="WeeklyVolcano">LAMINGTON</span>  New Guinea, Papua New Guinea 8.95&deg;S, 148.15&deg;E; summit elev. 1,680 m; All times are local (= UTC + 10 hours)
   if( /\<span class="WeeklyVolcano"\>(.+?)\<\/span\>(.+)/ ) {
      my ($name,$detail)=($1,$2);
      ($name,$detail)=map {s/^\s+//;s/\s+$//;$_} ($name,$detail);
      next if !$detail;
      my ($lat,$long,$elev);
      if($detail =~ /(\d+\.\d+)(?:&deg;|°)\s*([NS])/i) {
         my $sign;
         ($lat,$sign)=($1,$2);
         is_numeric($lat) || die "latitude $lat is not numeric\n";
         if($sign =~ /s/i) {
            $lat *= -1;
            }
         }
      else {
         warn("no latitude to $name found. bailing out.\n");
         next;
         }
      if($detail =~ /(\d+\.\d+)(?:&deg;|°)\s*([EW])/i) {
         my $sign;
         ($long,$sign)=($1,$2);
         is_numeric($long) || die "longitude $long is not numeric\n";
         if($sign =~ /w/i) {
            $long *= -1;
            }
         }
      else {
         warn("no longitude to $name found. bailing out.\n");
         next;
         }
      if($detail =~ /summit elev\..*?([\d,]+)/) {
         $elev=$1;
         $elev =~ s/\D//;
         $elev =getnum($elev);
         }
      else {
         writedebug("no elevation to $name found.");
         }
      $name =~ s/\&(.).*?\;/lc($1)/eg;
      $name = lc($name);
      $name =~ s/\b(\w)/uc($1)/eg;
      push @data, {
         'lat'    => $lat,
         'long'   => $long,
         'name'   => $name,
         'elev'   => $elev,
         };
      }
   }
}

# output
local *VOL;
open(VOL,">$volcano_marker_file") || die("Could not open volcano markers $volcano_marker_file for writing: $!\n");;
print VOL "# Volcano marker file created by $Script version $VERSION\n";
print VOL "# For more information read the top of the $Script script or go to\n";
print VOL "# $homepage\n";
print VOL "\n";
foreach my $volcano (@data) {
   my $txt=expand_template($volcano->{'lat'},$volcano->{'long'},$volcano->{'name'},$volcano->{'elev'});
   writedebug($txt);
   print VOL "$txt\n";
   }
close VOL;


