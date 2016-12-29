package Xplanet::StringNum;

=head1 NAME

Xplanet::StringNum - convert entities to / from strings

=head1 COPYRIGHT

Copyright 2002 Hans Ecke under the terms of the GNU General Public Licence

=head1 DESCIRPTION

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

use Hans2::StringNum;
use Hans2::Math;
use Hans2::Units;

=head2 C<$string=print_coord($latitude)>

in: coordinate as a number

out: a string with only two numbers after the decimal point

=cut

sub print_coord($) {
   my ($c)=@_;
   use locale;
   return sprintf_num_locale("% 7.2f",$c);
}

=head2 C<$string=print_angle($angle)>

in: angle difference as a number

out: a string with only two numbers after the decimal point

=cut

sub print_angle($) {
   my ($c)=@_;
   use locale;
   return sprintf_num_locale("%5.2f",$c);
}

=head2 C<$string=print_name($name>

converts lowercase to word caps

=cut

sub print_name($) {
   my ($name)=@_;
   $name =~ s/(\b.)/uc($1)/eg;
   return $name;
}

=head2 C<$angle=distspec2deg($string)>

   <number>      : returns it
   <number>km    : interpreted as km (kilometers = 1000 meters) - returns corresponding angle
   <number>miles : interpreted as US-miles - returns corresponding angle
   else returns undef

=cut

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
