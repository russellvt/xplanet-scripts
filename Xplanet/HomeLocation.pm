package Xplanet::HomeLocation;

=head1 NAME

Xplanet::HomeLocation - Functions to deal with and determine (latitude,longitude) coordinates

=head1 COPYRIGHT

Copyright 2002-2003 Hans Ecke hans@ecke.ws under the terms of the GNU General Public Licence

=head1 SYNOPSIS

   use Xplanet::HomeLocation;

   my ($latitude,$longitude)=determine_location();

   my $string=latlong_2_tzcoordpl($latitude,$longitude);
   my ($latitude,$longitude)=tzcoordpl_2_latlong($string);

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

use Hans2::Math;
use Hans2::Util;
use Hans2::Debug;
use Hans2::OneParamFile;
use Hans2::StringNum;
use Hans2::Constants;

use Geo::SingleLocator;

use Xplanet::Xplanet;
use Xplanet::Constants;
use Xplanet::StringNum;

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

=head2 C<latlong_2_tzcoordpl($latitude,$longitude)>

Out: string as tzcoord.pl would output it

=cut

sub latlong_2_tzcoordpl($$) {
   my ($lat,$long)=@_;
   return "-lat ".print_coord($lat).
          " -lon ".print_coord($long);
}      

=head2 C<tzcoordpl_2_latlong($string)>

in: string as tzcoord.pl would output it

out: latitude, longitude

=cut

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

=head2 C<determine_location()>

out: (latitude,longitude) of your home location or undef

=cut

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
