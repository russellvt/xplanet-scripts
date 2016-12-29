package Hans2::WeekDay;

=head1 NAME

Hans2::WeekDay - map day-in-week to weekday-names

=head1 COPYRIGHT

Copyright 2003 Hans Ecke hans@ecke.ws under the terms of the GNU Library General Public License

=head1 SYNPOSIS

   use Hans2::WeekDay;
   
   # 'Sun'
   my $month_str=Hans2::WeekDay::SHORT[0];
   # 'Wednesday'
   my $month_str=Hans2::WeekDay::LONG[3];
   # 5
   my $month_num=Hans2::WeekDay::STR_2_NUM{'Friday'};

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
   'Sun',
   'Mon',
   'Tue',
   'Wed',
   'Thu',
   'Fri',
   'Sat',
   );
   
@LONG=(
   'Sunday',
   'Monday',
   'Tuesday',
   'Wednesday',
   'Thursday',
   'Friday',
   'Saturday',
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
