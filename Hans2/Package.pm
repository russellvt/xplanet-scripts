package Hans2::Package;

=head1 NAME

Hans2::Package - Query and load perl modules

=head1 COPYRIGHT

Copyright 2003 Hans Ecke hans@ecke.ws under the terms of the GNU Library General Public License

=head1 SYNOPSIS

   use Hans2::Package;

   try_to_load("Term::ReadLine::Perl") 
      || warn "Could not load Term::ReadLine::Perl\n";

   import_if_not_already("Term::ReadLine");  # dies if not possible   

   my @list=possible_packages("Term::ReadLine");

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
                           &try_to_load
                           &import_if_not_already
                           &possible_packages
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
use filetest 'access';

# in:  a module name (as a file)
# out: 1 if found under @INC
#      or undef if no success
#
# it searches all of @INC for this module
sub found_in_INC($) {
   my ($fn)=@_;

   # maybe we already know?
   return 1 if $INC{$fn};
   
   # look in @INC   
   foreach(@INC) {
      return 1 if (-f File::Spec->catfile($_,$fn)) && (-r File::Spec->catfile($_,$fn));
      }

   # failure
   return undef;
}   

=head2 C<try_to_load($modname;\@importlist)>

C<$modname>: a module name. either like 'LWP::Simple' or 'LWP/Simple.pm'

C<\@importlist>: For the 'C<import module @list>' syntax, you give the
argument list as an array B<reference> so we can distinguish
between empty lists and no arguments lists at all.

Action: require and import module if not already done so

We could just C<"eval {require }"> the module, which would make this function
useless. But how would we know whether also to C<import()> it?

Return 1 - success - already loaded or success loading
       0 - failure to load or not found

The following are equivalent, except the first column is executed at runtime:

   try_to_load("Term::ReadLine")              use Term::ReadLine
   try_to_load("Term::ReadLine",[])           use Term::ReadLine ()
   try_to_load("Term::ReadLine",['$TTY'])     use Term::ReadLine qw($TTY)

=cut

sub try_to_load($;$) {
   my ($modname,$list)=@_;
   
   # success if its already loaded
   return 1 if $INC{$modname};
   my $fn;
   # make $modname into a honest module name
   $modname =~ s/\.pm$//;
   $modname =~ s/\//::/g;
   return 1 if $INC{$modname};
   # make $fn into a honest filename
   $fn = $modname;
   $fn .= ".pm" if $fn !~ /\.pm$/;
   $fn = File::Spec->catdir(split(/::/,$fn));
   return 1 if $INC{$fn};
   
   # fail if file can't be found
   return 0 if ! found_in_INC($fn);
   
   # fail if it can't be loaded
   eval { require $fn || return 0; 1 } || return 0;
   
   # import
   my $callpkg=caller;
   my $import_stmt="package $callpkg; ";
   if($list && (ref($list)) && (ref($list) eq "ARRAY")) {
      $import_stmt.="import $modname (".join(", ",@$list).");";
      }
   else {
      $import_stmt.="import $modname;";
      }   
   eval $import_stmt;   

   # success
   return 1;
   
}

=head2 C<import_if_not_already($modname;\@importlist)>

same as try_to_load(), but die if it was unsuccessfull

=cut

sub import_if_not_already($;$) {
   my ($mod,$list)=@_;
   if(!try_to_load($mod,$list)) {
      my $msg="";
      if($list) {
         $msg='('.join(", ",@$list).')';
         }
      die "could not load $mod $msg\n";
      }
   return 1;   
}

=head2 C<possible_packages(;$prefix)>

Out: list of all perl packages detected under the $prefix hierarchy

Example: There are the packages
         Geo::Locator::Misc, Geo::Locator::Local, Geo::Locator.pm, Geo::Locator::Foo::bar.
         You call C<possible_packages("Geo::Locator")>.
         This will return C<("Misc","Local")>

=cut

sub possible_packages(;$) {
   my ($prefix)=@_;
   
   $prefix = File::Spec->catdir(split(/::/,$prefix)) if $prefix;

   my %f;
   foreach my $dir (@INC) {
      next if !$dir;
      next if !-d $dir;
      next if !-r $dir;

      my $dir2=$dir;
      $dir2=File::Spec->catdir($dir2,$prefix) if $prefix;
   
      foreach my $file (my_glob($dir2,'*.pm',sub {-f $_ and -r $_})) {
         $file =~ s/\.pm$//;
         $f{$file}=1;
         }
      }
   my @f=sort keys %f;
   return @f;
}



END {}

1;
