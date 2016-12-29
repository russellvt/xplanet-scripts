package Hans2::ParseVersionList;

=head1 NAME

Hans2::ParseVersionList - parse a version file

=head1 COPYRIGHT

Copyright 2003 Hans Ecke hans@ecke.ws under the terms of the GNU Library General Public License

=head1 SYNOPSIS

   %data=parse_version_list($text)

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
                           &parse_version_list
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

use Hans2::DataConversion;
use Hans2::Constants;
use Hans2::MonthNames;
use Hans2::Debug;

=head2 C<%data=parse_version_list($text)>

in: the text of a version file

out: 

   the hash of
   component-name  => component information
   
   where component information is a hash with possible keys
      version                  version as a string
      v_version                version as a v-string
      effective_version        effective version
      v_effective_version      effectibe version a s av-string
      last_change_short        last change date as a short string
      last_change_long         ... and as a long string
     ... whatever was in the version file

=cut

sub parse_version_list($) {

   my ($txt)=@_;

   return if !$txt;
   
   my @ret=grep {$_} map {s/#.*//;s/^\s+//;s/\s+$//;$_} split("\n",$txt);
   my %ret;
   foreach(@ret) {
      /^([\w\-]+)\s+(\S+)\s*(.*)/ || 
         die "did not understand line $_ in versions file. Please notify ".
             "the author at $author_email\n";
      $ret{$1}=[$2,$3];
      }
   # now %ret contains
   #  component -> [ version, other info ]   
   
   my %data;
   
   foreach my $comp_name (keys %ret) {
   
      my $comp=$ret{$comp_name};
      
      my $version=$comp->[0];

      $comp=$comp->[1];
      my %comp=anglebracketoptions_decode($comp);
      
      # process last_change_short and last_change_long
      if($comp{'last_change_short'}) {
         $comp{'last_change_short'} =~ /^(\d\d) (\w+) (\d\d\d\d)$/ 
            or die "could not understand last_change_short for $comp_name\n";
         my ($day,$mon_short,$year)=($1,$2,$3);
         my $mn=$Hans2::MonthNames::STR_2_NUM{$mon_short};
         my $mon_long=$Hans2::MonthNames::LONG[$mn];
         $comp{'last_change_long'}="$day $mon_long $year";
         }   
      
      #process version   
      $comp{'version'}=$version;
      $comp{'v_version'}=versionstring_2_vstring($version);
      if($comp{'effective_version'}) {
         $comp{'v_effective_version'}=versionstring_2_vstring($comp{'effective_version'});
         }
      else {
         $comp{'effective_version'}  =$comp{'version'};
         $comp{'v_effective_version'}=$comp{'v_version'};
         }   
      
      $data{$comp_name}=\%comp;
      }
      
   return %data;
}      


END {}

1;
