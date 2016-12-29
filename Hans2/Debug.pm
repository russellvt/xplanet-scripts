package Hans2::Debug;

=head1 NAME

Hans2::Debug - a light-weight loging framework.

=head1 COPYRIGHT

Copyright 2003 Hans Ecke hans@ecke.ws under the terms of the GNU Library General Public License

=head1 SYNOPSIS

   use Hans2::Debug;

   # output informational message to STDERR if DEBUG is set
   writedebug("we are now starting to feed the buzzy");

   # make sure output to STDOUT also goes to the logfile
   writestdout("Your lucky numbers are: 1,2,3,4");

   # make sure output to STDERR also goes to the logfile
   writestderr("Error executing application.");

   # warn() and die() also write to the logfile

=head1 DESCRIPTION

A light-weight loging framework. Does not get into the way and can easily 
be wrapped - if the need arrises - by more powerfull frameworks like
log4perl.

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
                         $DEBUG
                         );
        @EXPORT      = (qw(
                         &writedebug
                         &writestdout
                         &writestderr
                         ),@EXP_VAR);
        @NON_EXPORT  = qw(
                          $off
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

use POSIX qw(locale_h strtod);
use File::Basename;
use File::Spec;
use Config;

use Hans2::FindBin;

select STDERR; $| = 1;      # make unbuffered
select STDOUT; $| = 1;      # make unbuffered

$off       = 0;

=head2 C<$DEBUG>

Whether we are in debug/log mode or not. At program start, is set depending
on the DEBUG environment variable or any switches on the command line
that look like C</^-+d/>. If such switches are found, they are removed from
C<@ARGV>.

=cut

# before anything else, look if we should run in DEBUG mode
$DEBUG=0;
if(@ARGV) {
   my @argv_new;
   foreach(@ARGV) {
      if(/^-+d/) {
         $ENV{'DEBUG'}=1;
         $DEBUG=1;
         }
      else {   
         push @argv_new,$_;
         }
      }
   @ARGV=@argv_new;
   }   

my $prefix_tty=" " x (length($Scriptbase) + 2);
my $prefix_log;
{
   my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) 
       = localtime(time());
   $mon++;
   $year+=1900;    
   foreach($mon,$mday,$hour,$min,$sec) {   
      $_ ="0$_"  if $_<10;   
      }
   my $txt="$Scriptbase($$) $mday/$mon $hour:$min:$sec ";
   $prefix_log=" " x length($txt);
}   

=head2 C<push_indent($message) and pop_indent()>

These B<unexported> functions change the level of white-space indentation
in loging output. A better interface is in L<Hans2::Debug::Indent>.

push_indent($message) outputs the message and then increases the level of indentation by 1

pop_indent() decreases the level by one.

The level of indentation is 0 at program start. So if these functions are never called
you will not even notice their existence.

=cut

my $indent_num=0;
my $indent_length=4;
sub push_indent($) {
   my ($msg)=@_;
   writedebug($msg) if $msg;
   $indent_num++;
   }
sub pop_indent() {
   $indent_num-- if $indent_num>0;
   }

sub writelogline($) {
   my ($msg)=@_;
   return if !$ENV{'LOGFILE'};
   $msg =~ s/\n/\n$prefix_log/g;
   my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) 
       = localtime(time());
   $mon++;
   $year+=1900;    
   foreach($mon,$mday,$hour,$min,$sec) {   
      $_ ="0$_"  if $_<10;   
      }
   local *LOG;
   if(!open(LOG, ">>".$ENV{'LOGFILE'})) {
      my $lf=$ENV{'LOGFILE'};
      delete $ENV{'LOGFILE'}; # make sure we don't go to a endless loop
      die "could not write to logfile $lf\n";
      };
   print LOG "$Scriptbase($$) $mday/$mon $hour:$min:$sec $msg\n";
   close LOG;
}   

sub writettyline($) {
   my ($msg)=@_;
   $msg =~ s/\n/\n$prefix_tty/g;
   print STDERR "$msg\n";
}

# INTERFACE

=head2 C<writedebug($message)>

Write the message string to STDERR if $DEBUG is set

Write the message string to a logfile specified in the LOGFILE environment
variable, if that variable is set and the file it points to is writable.

=cut

# write out debug message if DEBUG is set
sub writedebug($) {
   my ($msg)=@_;
   return if $off;
   $msg =~ s/[\s\n\r]+$//;
   my $pref=" " x ($indent_num*$indent_length);
   $msg=$pref . $msg;
   $msg =~ s/\n/\n$pref/g;
   writelogline($msg);
   writettyline("$Scriptbase: $msg") if $ENV{'DEBUG'};
}  

=head2 C<$SIG{__WARN__} and $SIG{__DIE__}>

These signal handlers have been overridden to also output their message to the logfile.

=cut

sub writewarn($) {
   my ($msg)=@_;
   return if $off;
   $msg =~ s/[\s\n\r]+$//;
   writelogline("!warning: ".$msg);
   print STDERR $msg."\n";
}

sub writedie($) {
   my ($msg)=@_;    
   return if $off;
   $msg =~ s/[\s\n\r]+$//;
   writelogline("!fatal: ".$msg);
#   print STDERR $msg."\n";
}

=head2 C<writestdout($message)>

This function behaves identical to 

   chomp $message;
   print $message."\n";

except that it also outputs $message into the logfile.

This might be done better with changing STDOUT to a tie'd filehandle?

=cut

sub writestdout($) {
   my ($msg)=@_;    
   return if $off;
   $msg =~ s/[\s\n\r]+$//;
   writelogline($msg);
   print STDOUT $msg."\n";
}

=head2 C<writestderr($message)>

This function behaves identical to 

   chomp $message;
   print STDERR $message."\n";

except that it also outputs $message into the logfile.

This might be done better with changing STDERR to a tie'd filehandle?

=cut

sub writestderr($) {
   my ($msg)=@_;    
   return if $off;
   $msg =~ s/[\s\n\r]+$//;
   writelogline($msg);
   print STDERR $msg."\n";
}

$SIG{__WARN__}=\&writewarn;
$SIG{__DIE__} =\&writedie;

writedebug("-------------------");
writedebug("initialized logging");
writedebug("$^X is version ".sprintf("%vd",$^V));
writedebug("OS: $^O");
{ my $h=$ENV{'HOME'} || "<undefined>";
  writedebug("users home: $h");   
}  
writedebug("users id: effective: $>; real: $<");   
if(@ARGV) {
   writedebug("command line args: \'".join("\', \'",@ARGV)."\'");
   }
else {   
   writedebug("command line args: <none>");
   }
   
END {}

1;
