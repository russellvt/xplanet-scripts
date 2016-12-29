package Hans2::Ascii::Bulk;

=head1 NAME

Hans2::Ascii::Bulk - read many Ascii::Data and Ascii::Param objects at once

=head1 COPYRIGHT

Copyright 2003 Hans Ecke hans@ecke.ws under the terms of the GNU Library General Public License

=head1 SYNOPSIS

FIXME

=head1 DESCRIPTION

=cut

use strict;

require 5.006;

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

# export variables
        @EXP_VAR     = qw(
                           );
# export functions
        @EXPORT      = (qw(
                         &read_ascii_dir
                           ),@EXP_VAR);
# non export variables
        @NON_EXPORT  = qw(
                           );
# optional export variables
        @EXPORT_OK   = qw();
        %EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],
        

        
}        

# exported variables
use vars      @EXP_VAR;
# exportable variables
use vars      @EXPORT_OK;
#non exported package globals
use vars      @NON_EXPORT;

use File::Basename;
use Hans2::Ascii::Data;
use Hans2::Ascii::Param;

=head2 C<($data,$param)=read_ascii_dir($directory;%opts)>

Will read all .param and .asc files in a directory

    %opts: options hash
          'paramfiles_filter' : ref to func
                                given paramfilename in $_, 
                                returns whether process it or not
          'datafiles_filter'  : ref to func
                                given datafilename in $_, returns 
                                whether process it or not
          'asciiopts'         : ref to options hash for 
                                AsciiData::read()
          'paramopts'         : ref to options hash for 
                                AsciiParam::read()

    $data: ref to hash
           <datafilename>      -> Ascii::Data object
 
    $param: ref to hash
           <parameterfilename> -> Ascii::Param object
 
=cut

sub read_ascii_dir($;%) {
   my ($dir,%opts)=@_;
   
   my $data_ext=Hans2::Ascii::Data::extension();
   my $param_ext=Hans2::Ascii::Param::extension();
   
   my @paramfiles=glob("$dir/*$param_ext");
   if($opts{'paramfiles_filter'}) {
      @paramfiles=grep {$opts{'paramfiles_filter'}->($_)} @paramfiles;
      }
   my @datafiles =glob("$dir/*$data_ext");
   if($opts{'datafiles_filter'}) {
      @datafiles =grep {$opts{'datafiles_filter'}->($_)} @datafiles;
      }

   my %aopts=();
   if($opts{'asciiopts'}) {
      %aopts=%{ $opts{'asciiopts'} };
      }
   my %popts=();
   if($opts{'paramopts'}) {
      %popts=%{ $opts{'paramopts'} };
      }
   
   my %data;
   foreach my $dfn (@datafiles) {
      my $base=basename($dfn);
      $base =~ s/\Q$data_ext\E$//o;
      $data{$base}=Hans2::Ascii::Data->read($dfn,%aopts);
      }
      
   my %param;   
   foreach my $pfn (@paramfiles) {
      my $base=basename($pfn);
      $base =~ s/\Q$param_ext\E$//o;
      $param{$base}=Hans2::Ascii::Param->read($pfn,%popts);
      }
   
   return (\%data,\%param);
}         

=head1 SEE ALSO

L<Hans2::Ascii::Data>

L<Hans2::Ascii::Param>

=cut


END { }

1;
