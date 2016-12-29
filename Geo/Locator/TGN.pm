package Geo::Locator::TGN;

#################### PURPOSE AND USAGE ################################
#
# Interface to the Getty Thesaurus of Geographic Names
#         http://www.getty.edu/research/tools/vocabulary/tgn/
#
# for geo_locator.pl http://hans.ecke.ws/xplanet
#
#################### COPYRIGHT ##########################################
#
# Copyright 2002-2003 Hans Ecke and Felix Andrews under the terms of the GNU General Public License.
#

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

use File::Basename;

use Hans2::FindBin;
use Hans2::Util;
use Hans2::Package;
use Hans2::Debug;
use Hans2::DataConversion;

use Xplanet::StringNum;

#sub AUTOLOAD {
#   our $AUTOLOAD;
#   my $function=$AUTOLOAD;
#   return;
#}   

# capabilities of this data source
# might have $self argument
sub capabilities(;$) {
   return {'exact'       => 1,
           'multi'       => 1,
           'loctype'     => 1,
           'detail'      => 1,
           'net'         => 1,
           'description' => 'Looks up information in the "Getty Thesaurus of Geographic Names" on the web',
           };
}

# $self accepts those fields in its constructor:
#   'loctype' => location type if requested
#
# no other datafields

sub new($%) {
   my ($proto,%arg) = @_;
   
   my $class = ref($proto) || $proto;

   my $self  = \%arg;

   bless ($self, $class);
   
   $self->init();
   
   return $self;
}   

# the main lookup URL
my $tgn_url = 'http://vocab.pub.getty.edu/cgi-bin/tgn_browser/tgn.spl';

# database: 
#    serial number -> {
#         'name'     => name
#         'type'     => place type
#                       "inhabited place", "county", "river", etc.
#                       can be comma separated collectyion
#         'loc_desc' => location_description
#         'lat'      => latitude
#         'long'     => longitude
#         'match'    => name
#         }
# it is unnecessary to make this 
my %DB;

# if downloaded copy found, when will it be considered too old?
# -1 means: consider any content of cache fresh
#
# in seconds
my $cache_expiration=60*60*2.5;   # one day=60*60*24

use Hans2::WebGet;
$Hans2::WebGet::cache_expiration=$cache_expiration;

########################################################################
#
#
#   API for the Thesaurus of Geographic Names
#
#
########################################################################

# list of get_tgn_hits() we have already done
#  city -> array of searials 
my %_get_tgn_hits=();
# in: location query string (usually city name)
#
# out: list of serials to query
sub get_tgn_hits($$) {
   my ($self,$city) = @_;
   
   if($_get_tgn_hits{$city}) {
      writedebug("cached get_tgn_hits($city)");
      return @{$_get_tgn_hits{$city}};
      }
      
   my $URL = $tgn_url . "?searchtype=keyword&keywords=" . CGI::escape($city);
   my $hits_page=get_webpage($URL);
   return if !$hits_page;
   my %hits = ();
   foreach my $record (split "<input", $hits_page) {
      my ($serial,$name,$name2,$type,$loc_desc);

      next if $record !~ /type="checkbox"/;
      
      next if $record !~ /name="key" value="(\d+)">/s;
      $serial=$1;
      if($DB{$serial}) {
         writedebug("TGN: cached $serial $DB{$serial}->{'name'}");
         $hits{$serial}=1;
         next;
         }
      
      next if $record !~ /<b>(.*?)<\/b><\/a>/s;
      $name=$1;
      
      next if $record !~ /<b>\((.*?)\)<\/b><\/font>/s;
      $type=$1;

      # preferred name is usually the vernacular form. may also show english.
      $name2 = $1  if $record =~ /\s<b>(.*?)<\/b>/s;
      $name2 ||= '';

      my $compare_city = lc($city);
      $compare_city =~ s/\"//g; # search string may be quoted

      $name = $name2 if ($compare_city ne lc($name)) and ($compare_city eq lc($name2));

      # (N & C Am., USA, California, San Diego)
      $loc_desc = $1 if $record =~ /\s<font size=-1>\((.*?)\)/s;
      $loc_desc =~ s/.*?, //; # drop first entry (continent)
      
      $DB{$serial}->{'name'}    = lc($name);
      $DB{$serial}->{'type'}    = $type;
      $DB{$serial}->{'loc_desc'}= $loc_desc;
      $DB{$serial}->{'TGN'}     = $serial;
      
      $hits{$serial}=1;
      
      writedebug("TGN search result: [$serial] ($type) $name ($loc_desc)");
   }
   my @hits=keys %hits;
   $_get_tgn_hits{$city}=\@hits;
   return @hits;
}

# in: city, list of serial_numbers
#
# out: list of serial numbers that were hits
sub get_tgn_records($$@) {
   my ($self,$city,@search_list) = @_;
   
   return if !@search_list;
   my @hits;

   my $URL = $tgn_url . "?searchtype=record";
   foreach my $serial (@search_list) { 
      # check if we already have info to that serial number.
#      if(0) {
      if(exists $DB{$serial}->{'lat'}) {
         next if $self->{'detail'} && ($DB{$serial}->{'detail'} !~ /$self->{'detail'}/i);
         # but we still need to filter for loctype
         if ($self->{'loctype'}) {
            if($DB{$serial}->{'type'}) {
               grep {$DB{$serial}->{'type'} =~ /$_/i} split(",", $self->{'loctype'}) or next;
               }
            }   
         push @hits,$serial;
         writedebug("TGN: cached $serial $DB{$serial}->{'name'}");
         next;
         }
      $URL .= "&key=$serial"; 
      }
   return @hits if $URL=~/searchtype=record$/;
      
   my $hits_page=get_webpage($URL);   
   return if !$hits_page;

   foreach my $place (split '<hr>', $hits_page) {

      my ($serial)      = ($place =~ m|<font size=-1><b>\[(\d+?)\]|s);
      my ($lat)         = ($place =~ m|Lat: <b>(-?\d+\.\d+)</b>|s)          or next;
      my ($long)        = ($place =~ m|Long: <b>(-?\d+\.\d+)</b>|s)         or next;
      my ($names_block) = ($place =~ m|Names:\s*?<pre><b>(.*?)</b></pre>|s) or next;
      my ($types)       = ($place =~ m|Place Types:<pre>(.+?)</pre>|s)      or next;
      # from http://www.getty.edu/research/tools/vocabulary/tgn/about.html:
      # Each name is followed by two capital letters, or "flags", in parentheses. 
      # These flags indicate the following: C for current name; H for historical name; 
      # V for vernacular name; and O for a variant name in a language other than the vernacular.

      my $name;
      foreach (split /\s\s+/, $names_block) {
         /^(.*?) \(/ or next;
         my $this_name = $1;
         $name ||= $this_name;
         last if lc($name) eq lc($city);
         if (lc($this_name) eq lc($city)) { 
            $name = $this_name; 
            last; 
            }
      }
      
      $DB{$serial}->{'lat'}     = $lat;
      $DB{$serial}->{'long'}    = $long;
      $DB{$serial}->{'match'}   = lc($name);
      $DB{$serial}->{'name'}    = lc($name);
      
      {
      my @types;
      $types =~ s/^\s+//s;
      $types =~ s/\s+$//s;
      @types = split(/\n/,$types);
      @types = grep {/<\/?b>/} @types;  # only lines with a <b> or </b> 
      @types = grep {/[\d\w\s]+\s+\([\w\s\,]+\)/} @types;
      @types = map {s/\(.*//;s/<\/?b>//g;s/^\s+//;s/\s+$//;$_} @types;
      @types = grep {$_} @types;        # take out empty lines   
      my %types=map {$_ => 1} @types;
      
      $types=join(", ",sort keys %types);
      }
      $DB{$serial}->{'type'}    = $types;
      
      $DB{$serial}->{'detail'}  = "TGN:$serial, $DB{$serial}->{'type'}, $DB{$serial}->{'loc_desc'}";

      next if $self->{'detail'} && ($DB{$serial}->{'detail'} !~ /$self->{'detail'}/i);
      # search for loctype happens here because one location might have more
      # than one loctype, in which case we don't find that with get_tgn_hits()
      if ($self->{'loctype'}) {
         grep {$types =~ /$_/i} split(",", $self->{'loctype'}) or next;
         }
      
      push @hits,$serial;

      writedebug("TGN record: #$serial [ ".print_coord($lat)." ".print_coord($long)." ] $name");
   }

   if (!@hits) {
      my @chunks = split '<hr>', $hits_page;
      my $chunks = scalar @chunks;
      writedebug("Failed to read information from detail page. There were $chunks chunks." );
   }

   return @hits;
}

sub init($) {
   my ($self)=@_;
   
   return if $self->{'init'};
   
   import_if_not_already("LWP::Simple");
   import_if_not_already("LWP::UserAgent");
   import_if_not_already("CGI");
   
   $self->{'init'}=1;

}

# in: city name
#
# out: hash of information, if found
#      or empty list if not
sub match_exact($$) {
   my ($self,$city)=@_;
   
   $city = lc($city);

   # look for exact hits from TGN
   # pass the engine an exact search string, quoting with ""
   my @tgn_hits = $self->get_tgn_hits(dquote($city));
   return if !@tgn_hits;
   my @tgn_get;
   foreach my $serial (@tgn_hits) {
      # [serial_number, name, place_type, location_description]
      if($city eq lc($DB{$serial}->{'name'})) {
         # exact match
         push @tgn_get,$serial;
         last;
         }
      }
   
   return if !@tgn_get;
   
   my @tgn_recs = $self->get_tgn_records($city,@tgn_get);
   foreach my $serial (@tgn_recs) {
      return %{$DB{$serial}} if $city eq lc($DB{$serial}->{'match'}); # exact match
      }
      
   return;   
}

# in: city name
#
# out: array of ref to hash of matches
sub match_multi($$) {
   my ($self,$city)=@_;
   
   my @tgn_recs = $self->get_tgn_records($city,$self->get_tgn_hits($city));
   return if !@tgn_recs;

   return @DB{@tgn_recs};
}

END {}

1;
