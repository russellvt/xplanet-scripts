package Hans2::Units;

=head1 NAME

Hans2::Units - convert between physical units

=head1 COPYRIGHT

Copyright 2003 Hans Ecke hans@ecke.ws under the terms of the GNU Library General Public License

=head1 SYNOPSIS

   my $celsius=convert_units('32','F','C');  # returns 0

   my $mile2km=convert_units_factor('mile','km');
   my @kilometers=map {$_ * $mile2km} @miles;

=head1 DESCRIPTION

Hans2::Units makes use of the excellent Math::Units module B<if that exists>. If 
it is not found, we fall back to our own small set of pre-defined conversion rules.

=cut

require 5.006;

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

use Hans2::Package;

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

=head2 C<$number=convert_units($number,$old_unit,$new_unit)>

Convert $number (which is in $old_unit) to $new_unit.

=cut

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

=head2 C<$factor=convert_units_factor($old_unit,$new_unit)>

Assuming $old_unit is directly proportional to $new_unit, return that
factor.

If $old_unit and $new_unit are at least linearly related, returns
how much a B<difference> 1 $old_unit is in $new_unit.

Everything else, it will return non-sensical values.

Example: 

* mile to km returns 1.6 since the 2 are directly proportional

* Celsius to Fahrenheit are not proportional but linear. It returns
  9/5, which is how much a B<difference> of 1 Celsius is in Fahrenheit

=cut

sub convert_units_factor($$) {
   my ($old_unit,$new_unit)=@_;
   return convert_units(1,$old_unit,$new_unit)-convert_units(0,$old_unit,$new_unit);
}   

=head2 C<$old_rule=Hans2::Units::add_rule($old_unit,$new_unit,$new_rule)>

Adds a pre-defined conversion rule from $old_unit to $new_unit.

$new_rule can be on of

   * simple number - conversion factor
   * fun-ref: it takes the value in $_ and returns the converted value.

=cut

sub add_rule($$$) {
   my ($old_unit,$new_unit,$rule)=@_;
   my $old=$predef_conv{$old_unit}->{$new_unit};
   $predef_conv{$old_unit}->{$new_unit}=$rule;
   return $old;
   }

END {

}

1;
