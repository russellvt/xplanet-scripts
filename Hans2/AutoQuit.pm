package Hans2::AutoQuit;

=head1 NAME

Hans2::AutoQuit - A simple object that will call a function when it expires.

=head1 COPYRIGHT

Copyright 2003 Hans Ecke hans@ecke.ws under the terms of the GNU Library General Public License

=head1 SYNOPSIS

     sub foo() {
         my $quit=Hans2::AutoQuit->new(sub {print "function ends\n";});
         ... do stuff
         if($something) {
            ....
            return;
            }
         ...do other stuff
         return;
      }

=head1 DESCRIPTION

Regardless where you leave the lexical scope it was defined in, the  
given function will be called

Why writing this module: often you initialize data structures when you start 
a function. If you leave the function at many different places you have 
to keep track which datastructures are already initialized and destroy them
in the right order.

Using this module, each time you initialize something, just create an AutoQuit
object that does the destruction and you are set.

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

sub new($&) {
   my ($proto,$func) = @_;
   
   if(!ref($func)) {
      die "Scalar given to AFAutoQuit\n";
      }
   if(ref($func) ne "CODE") {   
      die "Not a code-ref given to AFAutoQuit\n";
      }

   my $class = ref($proto) || $proto;

   my $self  = {
          'func'     =>  $func,
          'active'   =>  1
          };

   bless ($self, $class);
   return $self;
}   

sub delete($) {
   my ($self)=@_;
   return if !$self;
   return if !%$self;
   return if !$self->{'active'};
   $self->{'active'}=0;
   $self->{'func'}->() if $self->{'func'};
}   

sub DESTROY($) {
   my ($self)=@_;
   $self->delete();
}   
   
END {}

1;
