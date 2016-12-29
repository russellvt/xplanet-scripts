package Geo::Locator::Local;

#################### PURPOSE AND USAGE ################################
#
# Interface to local zone.tab (timezone) files and xplanet-style
# markerfiles for geo_locator.pl http://hans.ecke.ws/xplanet
#
# xplanet information at http://xplanet.sourceforge.net
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
use File::Spec;

use Hans2::FindBin;
use Hans2::Util;
use Hans2::Math;
use Hans2::File;
use Hans2::Debug;
use Hans2::Debug::Indent;

use Xplanet::StringNum;

# $self accepts those fields in its constructor
#   'zone.tab' => zone.tab filename
#   'markers'  => ref to array of marker files
#   'cache'    => cache filename if configured
#
# $self has those datafields:
#   'cities'   => array of information hashes

#sub AUTOLOAD {
#   our $AUTOLOAD;
#   my $function=$AUTOLOAD;
#   return undef;
#}   

# capabilities of this data source
# might have $self argument
sub capabilities(;$) {
   return {'exact'       => 1,
           'multi'       => 1,
           'nearest'     => 1,
           'near'        => 1,
           'dump'        => 1,
           'local'       => 1,
           'detail'      => 1,
           'description' => 'Contains information from the local system\'s zone.tab file as well as local xplanet-style marker files',
           };
}

sub new($%) {
   my ($proto,%arg) = @_;
   
   my $class = ref($proto) || $proto;

   my $self  = \%arg;

   bless ($self, $class);
   
   $self->init();
   
   return $self;
}  

# in: city name, latitude, longitude, details
# action: adds them to the database
sub add_record($$$$$) {
   my ($self,$match,$lat,$long,$detail)=@_;
   
# the below code is too slow to be used.
#
#   my @details=grep {$_} map {s/^\s+//;s/\s+$//;$_} split(",",$detail);
#   foreach(@details) {
#      if(/^(.+?):(.*)/) {
#         my ($key,$val)=($1,$2);
#         foreach($key,$val) {
#            s/^\s+//;
#            s/\s+$//;
#            }
#         $info{$key}=$val;  
#         }
#      else{
#         $info{$_}="";
#         }    
#      }
   
   push @{$self->{'cities'}}, {
               'match'   => lc($match),
               'lat'     => $lat,
               'long'    => $long,
               'detail'  => $detail,
               };
}

#
# get longitudes/latitudes from the zone.tab file
sub init_zonetab($) {
   my ($self)=@_;
   my $zone_tab=$self->{'zone.tab'};
   
   local *ZONE_FILE;
   open( ZONE_FILE, "< $zone_tab" ) || die("Couldn't open file $zone_tab: $!");
   writedebug("parsing $zone_tab");
   
   my ($countrycode, $isocoord, $name, $comment);
   
   while (<ZONE_FILE>) {
      s/#.*$//;
      s/^\s+//;
      next if !$_;
      ($countrycode, $isocoord, $name, $comment) = split(' ', $_, 4);
      
      next if (!( ($isocoord =~ /((?:\+|-)\d{4})((?:\+|-)\d{5})/)
   	           || 
                  ($isocoord =~ /((?:\+|-)\d{6})((?:\+|-)\d{7})/)
              ));
   
      my $isolatitude  = $1;
      my $isolongitude = $2;
   
      my $latitude  = 0;
      my $longitude = 0;
   
      # Seconds?
      if ( length( $isolatitude ) > 5 )
      {
        $latitude  += substr( $isolatitude, -2, 2, '' ) / 3600;
        $longitude += substr( $isolongitude, -2, 2, '' ) / 3600;
      }
      
      # Minutes
      $latitude  += substr( $isolatitude,  -2, 2, '' ) / 60;
      $longitude += substr( $isolongitude, -2, 2, '' ) / 60;
      
      # Degrees
      $latitude  += substr( $isolatitude,  1, 2 );
      $longitude += substr( $isolongitude, 1, 3 );
      
      # Sign
      $latitude  *= -1 if ( substr( $isolatitude,  0, 1 ) eq '-' );
      $longitude *= -1 if ( substr( $isolongitude, 0, 1 ) eq '-' );
      
      # convert 'America/Denver' to 'Denver'
      $name =~ s/(.*)\///;
      
      my $desc="timezone";
      $desc .= ", $1" if $1;

      # this comment is sometimes irrelevant, timezone info
      chomp($desc = "$desc, $comment") if $comment;
      $desc =~ tr/|/ /;  # the cache uses | as delimiters
      
      $self->add_record($name,$latitude,$longitude,$desc);
      
      
      }
   close ZONE_FILE;   
}   

#
# get longitudes/latitudes from the "earth" markers files
sub init_markers($) {
   my ($self)=@_;
   
   my @earth_m_fn=@{$self->{'markers'}};
   # get rid of duplicates but retain order
   {
   my %e;
   my @e;
   foreach(@earth_m_fn) {
      next if $e{$_};
      $e{$_}++;
      push @e,$_;
      }
   @earth_m_fn=@e;
   @{$self->{'markers'}}=@earth_m_fn;
   }
   
   foreach my $earth_m (@earth_m_fn) {
      local *EARTH;
      if(!open(EARTH,$earth_m)) {
         warn("Could not open earth markers file $earth_m: $!\n");
         next;
         }
      my $ind=Hans2::Debug::Indent->new("reading $earth_m");
      my $desc_m="marker:".basename($earth_m);
      while(<EARTH>) {
         s/^\s+//;
         s/\s+$//;
         next if !$_;
         #          39.74          -104.98         "Denver"                         # US
         if( /^#?\s*(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)\s+\"(.+?)\"(.*)$/ ) {
            my $desc=$desc_m;
            my ($lat,$long,$city,$desc2)=($1,$2,$3,$4);
            my $tz="";
            if($desc2) {
               if($desc2 =~ /timezone=([\w\/]+)/) {
                  $tz=$1;
                  }
               $desc2 =~ s/.*#//;
               $desc2 =~ s/\([\d\s]+\)\s*$//;
               $desc2 =~ s/\s+$//;
               $desc2 =~ s/^\s+//;
               }
            $city =~ s/%.*//;  
            $city =~ s/\s+$//;
            $desc.=", $desc2" if $desc2;   
            $desc.=", timezone:$tz" if $tz;   
            $desc =~ tr/|/ /;  # the cache uses | as delimiters
            $self->add_record($city,$lat,$long,$desc);
            if($city =~ /^(.+)\/(.+)/) {
               my ($city1,$city2)=($1,$2);
               $self->add_record($city1,$lat,$long,$desc);
               $self->add_record($city2,$lat,$long,$desc);
               }
               
            }
         else {
            writedebug("$desc_m: did not understand $_");
            }   
         }   
      close EARTH;
      }
}      

# dump the database to disc in a preparsed format
sub write_cache($) {
   my ($self)=@_;
   my $fn=$self->{'cache'};
   writedebug("Writing cache $fn");
   local *CACHE;
   open(CACHE, "> $fn") || die "Could not open cache file $fn for writing\n";
   foreach my $city (@{$self->{'cities'}}) {
      print CACHE "$city->{'match'}|$city->{'lat'}|$city->{'long'}|$city->{'detail'}\n" or die "writing to $fn failed: $!\n";
      }
   close CACHE;
   writedebug("done....");
}

# read in the cache file
# the method below is faster than having the cache in perl-code format and
# running "do $cache"!
sub read_cache($) {
   my ($self)=@_;
   return if $self->{'read'};
   writedebug("Reading cache $self->{'cache'}");
   local *CACHE;
   open CACHE, $self->{'cache'} || die "Could not open cache file $self->{'cache'} for reading\n";
   while(<CACHE>) {
      chomp;
      $self->add_record(split(/\|/,$_,4));
      }
   close CACHE;
   writedebug("done....");
   $self->{'read'}=1;
}

# read local location information from zone.tab and markers
sub read_sources($) {
   my ($self)=@_;
   return if $self->{'read'};
   $self->init_zonetab();
   $self->init_markers();
   $self->{'read'}=1;
}

# main object initialisation
sub init($) {
   my ($self)=@_;
   
   return if $self->{'init'};
   
   $self->{'cities'}=[];
   
   if($self->{'cache'}) {
   
      if(!$self->{'cache_is_absolute'}) {
         $self->{'cache'} =~ s/\.$Script$//;
         $self->{'cache'} =~ s/\.$Scriptbase$//;
         $self->{'cache'} .= ".$Scriptbase";
         }
   
      # see if the cache is younger than all source files
      my $redo_cache=0;
      my $cache_mtime=mtime($self->{'cache'});
      $cache_mtime=0 if ! -s $self->{'cache'};
      if($cache_mtime) {
         # compare mtimes with the zone.tab file
         #                     the marker files
         #                     the script file itself
         foreach my $source ($self->{'zone.tab'},
                             @{$self->{'markers'}}, 
                             File::Spec->catfile($Bin,$Script)) {
            my $mt=mtime($source);
            next if !$mt;
            if($mt > $cache_mtime) {
               $redo_cache=1;
               writedebug("source file $source is newer than cache $self->{'cache'}: will renew cache");
               last;
               }
            }   
         }
      else {
         writedebug("no cache found: will renew cache");
         $redo_cache=1;  # no cache found
         }   
      if($redo_cache) {
         # read info and write cache
         $self->read_sources();
         $self->write_cache();
         }
      else {
         # cache recent: read it in
         $self->read_cache();
         }   
      }
   else {
      # if no cache configured, parse stuff in the hard way
      writedebug("No cache configured: parsing marker files");
      $self->read_sources();
      }         
   
   $self->{'init'}=1;
   
}

# return database
sub dump($){
   my ($self)=@_;
   return @{$self->{'cities'}};
}   

# in: city name
#
# out: hash of information, if found
#      or empty list if not
sub match_exact($$) {
   my ($self,$city)=@_;
   $city=lc($city);
   
   foreach my $this_city (@{$self->{'cities'}}) {
      next if $this_city->{'match'} ne $city;
      next if $self->{'detail'} && ($this_city->{'detail'} !~ /$self->{'detail'}/i);
      return %$this_city ;
      }
      
   return ();   
   
}

# in: city name
#
# out: array of ref to hash of matches
sub match_multi($$) {
   my ($self,$city)=@_;
   
   my @hits;
   
   foreach my $this_city (@{$self->{'cities'}}) {
      next if $self->{'detail'} && ($this_city->{'detail'} !~ /\Q$self->{'detail'}\E/i);
      if($this_city->{'match'} =~ /\b\Q$city\E/i) {
         my %hit=%$this_city;
         push @hits,\%hit;
	 }
      }
      
   return @hits;      
   
}

# in: (latitude, longitude) asked
#
# out: information hash, including
#           'qlat', 'qlong', 'match' and 'dist'
sub nearest($$$) {
   my ($self,$qlat,$qlong)=@_;
   
   my $near_dist = 10000;    # starting point
   
   my $hit;                  # return variable
   my $this_lat;
   my $this_long;
   my $this_dist;
   
   foreach my $this_city (@{$self->{'cities'}}) {
      next if $self->{'detail'} && ($this_city->{'detail'} !~ /$self->{'detail'}/i);
      $this_lat = $this_city->{'lat'};
      $this_long= $this_city->{'long'};
      $this_dist = angle_difference($this_lat,$qlat,$this_long,$qlong);
      if($this_dist < $near_dist) {
         $near_dist = $this_dist;
         $hit = $this_city;
         writedebug( "closer match: [".print_coord($this_lat)." ".print_coord($this_long)
                    ."] (distance ".print_coord($this_dist).") ".print_name($this_city->{'match'}) );
         }
      }
      
   my %hit=%$hit;
   $hit{'dist'} =$this_dist;
   $hit{'qlat'} =$qlat;
   $hit{'qlong'}=$qlong;
      
   return %hit;
   
}
   
# in: (latitude, longitude, max distance)
#
# out: array of matches
sub near($$$$) {
   my ($self,$qlat,$qlong,$angle)=@_;
   
   my @hits;   
   foreach my $this_city (@{$self->{'cities'}}) {
      next if $self->{'detail'} && ($this_city->{'detail'} !~ /$self->{'detail'}/i);
      my $this_lat = $this_city->{'lat'};
      my $this_long= $this_city->{'long'};
      my $this_dist = angle_difference($this_lat,$qlat,$this_long,$qlong);
      if($this_dist <= $angle) {
         my %hit = %$this_city;
         $hit{'dist'} =$this_dist;
         $hit{'qlat'} =$qlat;
         $hit{'qlong'}=$qlong;
         push @hits, \%hit;
         }
      }
   return @hits;   
   
}
   
END {}

1;
