package Hans2::StringNum;

=head1 NAME

Hans2::StringNum - dealing with converting strings and numbers

=head1 COPYRIGHT

Copyright 2003 Hans Ecke hans@ecke.ws under the terms of the GNU Library General Public License

=head1 SYNOPSIS

..fill me

=head1 DESCRIPTION

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
                       &sprintf_num_locale
                       &getnum 
                       &makenum
                       &is_numeric 
                       &not_numeric
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

use POSIX qw(locale_h strtod);

=head2 C<$string=sprintf_num_locale($format,$number;$locale)>

print a number as if we were in a different number locale

target locale $locale defaults to 'C'

out: number printed as a string

note: if you print the number in a special locale, perl might not be able to
      transform it back into a number without first switching back to that locale.

=cut

sub sprintf_num_locale($$;$) {
   my ($format,$num,$locale)=@_;
   $locale ||= 'C';

   my $old_locale=setlocale(LC_NUMERIC);
   if($old_locale ne $locale) {
      # only bother changing locales if it would really change anything
      setlocale(LC_NUMERIC, $locale);
      my $ret=sprintf($format,$num);
      setlocale(LC_NUMERIC, $old_locale); 
      return $ret;
      }
   else {
      return sprintf($format,$num);
      }   
}      

# try to interpret the string as a number. return undef if no success
sub getnum_simple($) {
   my ($str)=@_;

   return undef if !defined $str;
   $str =~ s/^\s+//;
   $str =~ s/\s+$//;
   return undef if $str eq "";

   $! = 0;

   my($num, $unparsed) = strtod($str);

   if (($str eq '') || ($unparsed != 0) || $!) {
      return undef;
      }
   else {
      return $num;
      } 
} 

=head2 C<$num=getnum($string)>

try to interpret the string as a number

try really hard: try both with the current locale and the standard "C" locale

return undef if $string can't be interpreted as a number.

=cut

sub getnum($) {
   my ($str)=@_;
   
   my $ret;
   
   $ret=getnum_simple($str);
   return $ret if defined $ret;
   
   my $old_locale=setlocale(LC_NUMERIC);
   if($old_locale ne 'C') {
      # only bother changing locales if it would really change anything
      setlocale(LC_NUMERIC, 'C');
      $ret=getnum_simple($str);
      setlocale(LC_NUMERIC, $old_locale); 
      }
   
   return $ret;
}

=head2 C<$num=makenum($string,1)>

converts argument to number or undef if not a number

if not a number and second argument is set, dies with error message

=cut

sub makenum($$) {
   my ($ori,$hard)=@_;
   my $num=getnum($ori);
   die "$ori is not a number\n" if ($hard) && (!defined $num);
   return $num;
}

=head2 C<$bool=is_numeric($string)> and C<$bool=not_numeric($string)>

Return true or false depending on what C<getnum($string)> says.

=cut

sub is_numeric($) { defined getnum($_[0]) }   
sub not_numeric($) { ! defined getnum($_[0]) }   


END {

}

1;
