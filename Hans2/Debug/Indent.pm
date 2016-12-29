package Hans2::Debug::Indent;

=head1 NAME

Hans2::Debug::Indent - A simple interface to structure debug/loging output 
by white space indentation using L<Hans2::Debug>.

=head1 COPYRIGHT

Copyright 2003 Hans Ecke hans@ecke.ws under the terms of the GNU Library General Public License

=head1 SYNPOSIS

   sub frobnicate($) {
      my ($baz)=@_;
      my $ind=Hans2::Debug::Indent("now starting to frobnicate the $baz");
      ... do stuff
      if($something) {
         ...
         return;
         }
      ... finish   
      }

=head1 DESCRIPTION

At the start of a block of execution where you wish to indent the loging messages,
create an Hans2::Debug::Indent object with a message. From that point foreward,
debug output will be indented one level more. When the object goes out of scope,
the destructor of the Indent object will reset the indentation level to its original.

Internally, this works by means of L<Hans2::AutoQuit>

=cut

use strict;


BEGIN {
        use Exporter   ();
        use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS @EXP_VAR @NON_EXPORT);
        use Hans2::AutoQuit;

#        $Exporter::Verbose=1;
        # set the version for version checking
        $VERSION     = 1.00;
        # if using RCS/CVS, this may be preferred
#        $VERSION = do { my @r = (q$Revision: 2.21 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };
        # The above must be all one line, for MakeMaker

        @ISA         = qw(Exporter Hans2::AutoQuit);

        @EXP_VAR     = qw(
                         );
        @EXPORT      = (qw(
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

use Hans2::Debug;

sub new($$) {
   my ($proto,$msg) = @_;

   my $class = ref($proto) || $proto;
   
   Hans2::Debug::push_indent($msg);
   
   my $self=$class->SUPER::new( sub {Hans2::Debug::pop_indent();});
   
   bless ($self,$class);

   return $self;
}   
      
END {}

1;
