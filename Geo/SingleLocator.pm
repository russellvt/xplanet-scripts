package Geo::SingleLocator;

=head1 NAME

Geo::SingleLocator - a Geo::Locator singleton object

=head1 COPYRIGHT

Copyright 2003 Hans Ecke hans@ecke.ws under the terms of the GNU General Public License

=head1 SYNPOSIS

   use Geo::SingleLocator;
   Geo::Locator::init('markers'=>'australia weather_markers earth');
   @info=$LOCATOR->lookup_forward($city,$mode);

=head1 DESCRIPTION

Provides a shared Geo::Locator object called $LOCATOR

C<%info=$LOCATOR->nearest(qlat,qlong)>

C<@info=$LOCATOR->near(qlat,qlong,angle)>

C<%info=$LOCATOR->get_exact(city)>

C<@info=$LOCATOR->get_multi(city)>

C<@info=$LOCATOR->get_trusted(city)>

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

use Hans2::Algo;
use Hans2::OneParamFile;
use Hans2::OneParamFile::StdConf;
use Hans2::FindBin;

use Geo::Locator;

use Xplanet::StdConf;

register_param($ONEPARAMFILE_TMPDIR_OPTS,%ONEPARAMFILE_TMPDIR_OPTS);
register_param($ONEPARAMFILE_DIR_OPTS,%ONEPARAMFILE_DIR_OPTS);

=head2 C<Geo::SingleLocator::init(%init)>

The initialization for $LOCATOR. Whoever calls this last gets to initialize
$LOCATOR

in: options hash %init with optional entries

    'zone.tab'             => timezone file
    'markers'              => ref to array of full filenames
                              or string with basenames of markerfiles in markers/ subdirectory
                              defaults to weather_markers earth capitals nations ed_u.com bcca.org
    'cache'                => full filename of cache file
                              defaults to TMPDIR/local_location.cache
    'net_modules'          => ref to array of net modules to load             
                              defaults to nothing (empty)
    'min_angle_difference' => difference in degrees under which 2 locations are considered equal
                              defaults to 2 

=cut

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

=head2 C<Geo::SingleLocator::single_init(%init)>

Like Geo::SingleLocator::init(), except that it will not be executed if there was 
a previous call to init()

=cut

sub single_init(;%) {
   my (%opts)=@_;
   return if $init_nr;
   Geo::SingleLocator::init(%opts);
}   



END {}

1;
