package Hans2::Cwd;

=head1 NAME

Hans2::Cwd - portabler wrapper around L<Cwd>::getcwd()

=head1 COPYRIGHT

Copyright 2003 Hans Ecke hans@ecke.ws under the terms of the GNU Library General Public License

=head1 SYNPOSIS

   use Hans2::Cwd;
   my $cwd=getcwd();

=head1 DESCRIPTION

The standard L<Cwd> module exports a C<getcwd()> function that resturns the current
working directory. Unfortunately, under platforms other than Unix,
the path returned may contain slashes (/) instead of i.e. backslashes (\).

This module exports an identically-behaving C<getcwd()>, but its output has first
been sanitized by C<< File::Spec->canonpath() >>. It is so much more suitable for
programs that need to be portable.

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
                           &getcwd
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

BEGIN {
require Cwd;
}
use File::Spec;

sub getcwd() {
   return File::Spec->canonpath(Cwd::getcwd());
}   

END {}

1;
