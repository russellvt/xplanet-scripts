package Hans2::Astro::Julian;

=head1 NAME

Hans2::Astro::Julian - some simple math functions

=head1 COPYRIGHT

Copyright 2003 Hans Ecke hans@ecke.ws under the terms of the GNU Library General Public License

=head1 SYNOPSIS

   use Hans2::Astro::Julian;

   FIXME: fill me in

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
                         &GMTdate_2_julian
                         &time_2_julian
                         &julian_2_yearmonthday
                         &julian_2_hms
                         &julian_2_time
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

use Hans2::Math;
use Time::Local;

=head2 C<$julian=GMTdate_2_julian($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst)>

convert internal GMT date and time to Julian day and fraction

=cut

sub GMTdate_2_julian(@) {
	use integer;
	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = @_;
	my ($c, $m, $y);

	$y = $year + 1900;
	$m = $mon + 1;
	if ($m > 2) {
		$m = $m - 3;
	}
	else {
		$m = $m + 9;
		$y--;
	}
	$c = $y / 100;		# compute century
	$y -= 100 * $c;
	return ($mday + ($c * 146097) / 4 + ($y * 1461) / 4 + ($m * 153 + 2) / 5 + 1721119);
}

=head2 C<$julian=time_2_julian(time())>

convert internal date and time to astronomical Julian
time (i.e. Julian date plus day fraction)

=cut

sub time_2_julian($) {
	my ($t)=@_;

	my @dt = localtime($t);

	return (( GMTdate_2_julian(@dt) - 0.5 ) + ( $dt[0] + 60 * ( $dt[1] + 60 * $dt[2] ) ) / 86400.0 );
}

=head2 C<($year,$month,$day)=julian_2_yearmonthday($jdate)>

convert Julian date to year, month, day, 

=cut

sub julian_2_yearmonthday($) {
	my ($td) = @_;
        
	my ($j, $d, $y, $m);

	$td += 0.5;				# astronomical to civil
	$j = floor($td);
	$j = $j - 1721119.0;
	$y = floor(((4 * $j) - 1) / 146097.0);
	$j = ($j * 4.0) - (1.0 + (146097.0 * $y));
	$d = floor($j / 4.0);
	$j = floor(((4.0 * $d) + 3.0) / 1461.0);
	$d = ((4.0 * $d) + 3.0) - (1461.0 * $j);
	$d = floor(($d + 4.0) / 4.0);
	$m = floor(((5.0 * $d) - 3) / 153.0);
	$d = (5.0 * $d) - (3.0 + (153.0 * $m));
	$d = floor(($d + 5.0) / 5.0);
	$y = (100.0 * $y) + $j;
	if ($m < 10.0) {
	   $m = $m + 3;
	   }
	else {
           $m = $m - 9;
           $y = $y + 1;
           }
        return (int($y),int($m),int($d));
}

=head2 C<($hour,$minute,$sec)=julian_2_hms($jtime)>

convert Julian time to hour, minutes, and seconds

=cut

sub julian_2_hms($) {
	my ($j)=@_;
	my ($ij, $h, $m, $s);
	
	$j += 0.5;				# astronomical to civil
	$ij = int (($j - floor($j)) * 86400.0);

	$h = int ($ij / 3600);
	$m = int (($ij / 60) % 60);
	$s = int ($ij % 60);

	return ($h, $m, $s);
}

=head2 C<$time=julian_2_time($julian)>

 convert Julian time to a time returned by time() function

=cut

sub julian_2_time($) {
	my ($jday)=@_;
	my ($hour,$min,$sec) = julian_2_hms($jday);
	my ($y,$m,$d)=julian_2_yearmonthday($jday);
	return ( timegm($sec, $min, $hour, $d, --$m, $y) );
}

END {}

1;
