package Hans2::Math;

=head1 NAME

Hans2::Math - some simple math functions

=head1 COPYRIGHT

Copyright 2003 Hans Ecke hans@ecke.ws under the terms of the GNU Library General Public License

=head1 SYNOPSIS

   use Hans2::Math;

   my $radians=deg_2_rad($degrees);
   my $degrees=rad_2_deg($radians);

   my $xx=sqr($x);
   my $angle=acos($length);
   my $circle_surface=PI * sqr($radius);
   my $nearest_int=round("1.4"); # returns 1

   my $adif=angle_difference($lat1,$lat2,$long1,$long2);

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

use Hans2::Algo;

=head2 C<PI()>

perl does not have a builtin pi (3.1428...)

=cut

use constant PI => atan2(1,1)*4;

=head2 C<sgn($number)>

out: -1 if smaller 0, else +1

=cut

sub sgn($) {
   my ($num)=@_;
   return ( ($num<0) ? -1 : 1 );
   }

=head2 C<sgn0($number)>

out: 

   0 if equal 0
   -1 if smaller 0
   +1 if bigger 0

=cut

sub sgn0($) {
   my ($num)=@_;
   return 0 if !$num;
   return ( ($num<0) ? -1 : 1 );
   }

=head2 C<sqr($number)>

out: $number * $number

=cut

sub sqr($) {
   my ($x)=@_;
   return $x * $x;
}   

=head2 C<tan($number)>

out: tangens($number)

=cut

sub tan($) { 
   my ($arc)=@_;
   return sin($arc)/cos($arc);
}

=head2 C<acos($number)>

out: arc-tangens( $number )

(from the camel book)

=cut

sub acos($) { 
   my ($arc)=@_;
   return 0 if ($arc eq 1); # fix for rounding imperfection
   atan2( sqrt(1 - $arc * $arc), $arc ) 
}

=head2 C<asin($number)>

out: arc-sine( $number )

=cut

sub asin { 
   my ($arc)=@_;
   return atan2($arc, sqrt(1 - $arc * $arc)) 
}

=head2 C<atan($number)>

out: arc-tangens( $number )

=cut

sub atan {
   my ($arc)=@_;
   
   return 0 if !$arc;
   return atan2(sqrt(1+sqr($arc)),sqrt(1+1/sqr($arc))) if $arc>0;
   return -atan2(sqrt(1+$_[0]*$_[0]),sqrt(1+1/($_[0]*$_[0])));
}

=head2 C<deg_2_rad($degrees), rad_2_deg($radian)>

conversion between units of angle

=cut

sub deg_2_rad($)   { $_[0] * PI / 180 }
sub rad_2_deg($)   { $_[0] * 180 / PI }

=head2 C<angle_difference ($latitude1,$latitude2,$longitude1,$longitude2)>

finds the shortest distance between two points on a sphere
using the "great circle" method.
not exact but pretty damn good (fine for short distances).

=cut

sub angle_difference($$$$) {
	my ($lat1,$lat2,$long1,$long2) = map { deg_2_rad($_) } @_;
	my $angle = acos( sin($lat1) * sin($lat2) + cos($lat1) * cos($lat2) * cos($long2 - $long1) );
	# to convert to km: $angle * 60 * 1.852
	return rad_2_deg($angle);
}

=head2 C<round($float)>

round number to nearest integer

=cut

sub round($) {
    my($number) = @_;
    return int($number + .5 * ($number <=> 0));
}

=head2 C<floor($float)>

largest integer value less than or equal to the numerical 
argument 

=cut

sub floor {
   my ($num)=@_;
   my $neg   = ($num < 0);
   my $asint = int($num);
   my $exact = ($num == $asint);

   return ($exact ? $asint : ($neg ? $asint - 1 : $asint));
}

=head2 C<$number=average(@data)>

The arithmetic average of a list.

=cut

sub average(@) {
   my (@data)=@_;
   return undef if !@data;
   my $sum=0;
   foreach(@data) {
      $sum+=$_;
      }
   return $sum/scalar(@data);
}      

=head2 C<($absolute,$relative,$coeff)=linear_regression(@x,@y)>

out: linear regression coefficients (absolute, relative) and correlation coefficient

=cut

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


=head2 C<my $corr=correlation(\@x,\@y)>

return ref to the correlation array

=cut

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
   
=head2 C<my $acorr=autocorrelation(\@x)>

return ref to the autocorrelation of @x

=cut

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
   
=head2 C<my $corr=convolution(\@x,\@y)>

return ref to the convolution of @x with @y

=cut

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
   

=head2 C<$bool=is_even($number)>

whether the number is even

=cut

sub is_even($) {
   my ($num)=@_;
   return 1 if int($num/2)*2 == $num;
   return 0;
}   

=head2 C<$num=norm_2_difference(@x,@y)>

square-root of the sum of the squares of the differences between x and y

=cut

sub norm_2_difference(@) {
   return sqrt(sum2(sub {sqr($_[0]-$_[1])}, @_));
}      

=head2 C<$norm=norm2(@x)>

out: 2-norm of that array

=cut

sub norm_2(@) {
   return sqrt(sum( sub {sqr($_)},@_));
}   

=head2 C<$mean=mean(\@array)>

return the mean (average) of an array

=cut

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

=head2 C<$stddev=stddev($mean,\@array)>

return the standard deviation of an array, given its mean

=cut

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


=head2 C<%stat=statistics(\@array)>

return a hash containing 

   'max'    => maximum value
   'min'    => minimum value
   'stddev' => standard deviation
   'mean'   => mean

=cut

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

=head2 C<$diff=difference_2($a,$b)>

return the relative difference between A and B as

      A-B
    -------
   mean(A,B)

=cut

sub difference_2($$) {
   my ($a,$b)=@_;
   return 2*($a-$b)/($a+$b);
}


END {}

1;
