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

use Hans2::Util;
use Hans2::Package;
use Hans2::Math;
use Hans2::Debug;
use Hans2::Debug::Indent;
use Hans2::File;

use Xplanet::StringNum;

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
