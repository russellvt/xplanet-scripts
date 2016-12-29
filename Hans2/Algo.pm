package Hans2::Algo;

=head1 NAME

Hans2::Algo - algorithms

=head1 COPYRIGHT

Copyright 2003 Hans Ecke hans@ecke.ws under the terms of the GNU Library General Public License

=head1 SYNOPSIS

fill this in...

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
                       &split_half
                       &sum
                       &sum_simple
                       &sum2
                       &max
                       &max_simple
                       &min  
                       &min_simple  
                       &firstgood
                       &allgood
                       &random_array_elem
                       &samearray
                       &uniq
                       &uniq_simple
                       &uniq_global
                       &fisher_yates_shuffle
                       &fisher_yates_shuffled
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

=head2 C<($aref1,$aref2)=split_half(@list)>

in: array/list consisting of two arrays, one after the other

out: refs to the two lists

ex: ([1,2,3,4],[5,6,7,8])=split_half(1,2,3,4,5,6,7,8)

=cut

sub split_half(@) {
   my (@args)=@_;
   my $num=scalar(@args);
   die "split_half(): given array of size ".$num." is not even\n" if int($num/2)*2 != $num;
   my @x=@args[0      .. $num/2-1];
   my @y=@args[$num/2 .. $num-1];
   return (\@x,\@y);
}   

=head2 C<$sum=sum(\&evaluate,@list)>

out: sum of each element of the array with the function applied to it

=cut

sub sum($@) {
   my ($fun,@ar)=@_;
   die "sum(): first arg no fun-ref\n" if !ref($fun);
   die "sum(): first arg no fun-ref\n" if ref($fun) ne 'CODE';
   my $sum=0;

   foreach(@ar) {
      $sum+=$fun->($_);
      }

   return $sum;   
}

=head2 C<$sum=sum_simple(@list)>

out: sum of each element of the array

=cut

sub sum_simple(@) {
   my (@ar)=@_;
   my $sum=0;

   foreach(@ar) {
      $sum+=$_;
      }

   return $sum;   
}

=head2 C<$sum=sum2(\&evaluate,@list1,@list2)>

out: Sum of the elements of both arrays. We loop through both arrays
simultaneously, calling the function for each one with $list[i] and $list2[i]
as arguments.

=cut

sub sum2($@) {
   my ($fun,@ar)=@_;
   my ($x,$y)=split_half(@ar);
   my $sum=0;
   for(my $i=0;$i<scalar(@$x);$i++) {
      $sum+=$fun->($x->[$i],$y->[$i]);
      }
   return $sum;
}         
   
=head2 C<$biggest_element=max(\&objective,@list)>

The biggest of a list of entries after some measure &objective

The first argument is a func-ref, it serves to impose a measure on
the input list. Something like

   $manager_to_give_raise_to = max( \&performance, @managers );

=cut

sub max($@) {
   my ($func,@args)=@_;
   return undef if !@args;
   die "max(): first arg is no fun-ref" if !ref($func);
   die "max(): first arg is no fun-ref" if ref($func) ne 'CODE';
   my $extr=shift @args;
   my $extrfunc;
   for($extr) {
      $extrfunc=$func->($_);
      }
   foreach(@args){
      my $this=$func->($_);
      if($this>$extrfunc) {
         $extr=$_;
         $extrfunc=$this;
         }
      }
   return $extr;   
}

=head2 C<$biggest_number=max_simple(@list)>

The biggest number or string out of a list

=cut

sub max_simple(@) {
   my (@args)=@_;
   return undef if !@args;
   my $extr=shift @args;
   foreach(@args){
      $extr=$_ if $_>$extr;
      }
   return $extr;   
}


=head2 C<$smallest_element=min(\&objective,@list)>

The smallest of a list of entries after some measure &objective

The first argument is a func-ref, it serves to impose a measure on
the input list. Something like

   $manager_to_fire = min( \&performance, @managers );

=cut

sub min($@) {
   my ($func,@args)=@_;
   return undef if !@args;
   die "min(): first arg is no fun-ref" if !ref($func);
   die "min(): first arg is no fun-ref" if ref($func) ne 'CODE';
   my $extr=shift @args;
   my $extrfunc;
   for($extr) {
      $extrfunc=$func->($_);
      }
   foreach(@args){
      my $this=$func->($_);
      if($this<$extrfunc) {
         $extr=$_;
         $extrfunc=$this;
         }
      }
   return $extr;   
}

=head2 C<$smallest_number=min_simple(@list)>

The smallest number or string out of a list

=cut

sub min_simple(@) {
   my (@args)=@_;
   return undef if !@args;
   my $extr=shift @args;
   foreach(@args){
      $extr=$_ if $_<$extr;
      }
   return $extr;   
}

=head2 C<$elem=firstgood(\&validator,@list)>

in: func-ref and list of scalars

out: first of the scalars where the function returns true or undef

=cut

sub firstgood(&@) {
   my ($validator,@tries)=@_;
   die "firstgood(): first arg is no fun-ref" if !ref($validator);
   die "firstgood(): first arg is no fun-ref" if ref($validator) ne 'CODE';
   foreach(@tries) {
      return $_ if $validator->($_);
      }
   return undef;
}      

=head2 C<$elem=random_array_elem(@list)>

returns a random element from the array

=cut

sub random_array_elem(@) {
   $_[int(rand(scalar(@_)))];
}   

=head2 C<$bool=samearray(\@list1,\@list2)>

whether the two array refs point to arrays of the same size and same elements

=cut

sub samearray($$) {
   my ($a1,$a2)=@_;
   die "samearray(): first arg no array-ref\n" if !ref($a1);
   die "samearray(): first arg no array-ref\n" if ref($a1) ne 'ARRAY';
   die "samearray(): second arg no array-ref\n" if !ref($a2);
   die "samearray(): second arg no array-ref\n" if ref($a2) ne 'ARRAY';
   return 0 if scalar(@$a1) != scalar(@$a2);
   my $same=1;
   for(my $i=0;$i < scalar(@$a1);$i++) {
      return 0 if $a1->[$i] ne $a2->[$i];
      }
   return 1;
}      

=head2 C<@uniq=uniq(\&is_equal,@list)>

out: The array, with B<consecutive> equal values taken out.
     The first argument, a function-reference, is returns
     whether 2 values are equal.

Example: 

     @uniq_website_visits = uniq(\&visitors_host_is_equal,@hits)

=cut

sub uniq($@) {
   my ($is_eq,@ar)=@_;
   return () if !@ar;
   die "uniq(): first arg is no fun-ref" if !ref($is_eq);
   die "uniq(): first arg is no fun-ref" if ref($is_eq) ne 'CODE';
   
   my $last=shift @ar;
   my @ret=($last);
   foreach(@_) {
      if(!$is_eq->($_,$last)) {
         $last=$_;
         push @ret,$_;
         }
      }
  return @ret;
}         
      
=head2 C<@uniq=uniq_simple(@list)>

out: the numeric array, with consecutve equal values taken out

Example:

     (1,3,5,1,4,6,3)= uniq_simple(1,3,5,1,4,6,3)
     (1,3,5,4,6,3) = uniq_simple(1,3,3,5,4,4,4,4,6,3,3,3,3,3)

=cut

sub uniq_simple(@) {
   my (@ar)=@_;
   return () if !@ar;
   
   my $last=shift @ar;
   my @ret=($last);
   foreach(@_) {
      if($_ != $last) {
         $last=$_;
         push @ret,$_;
         }
      }
  return @ret;
}         

=head2 C<@uniq=uniq_global(@list)>
      
out: The array, with repeated values taken out.
     Equality is defined by the stringification of each element.

Example:     

     (1,3,5,4,6)=uniq_global(1,3,5,1,4,6,3)

=cut

sub uniq_global(@) {
   return () if !@_;
   my %seen;
   return grep { ! $seen{$_}++ } @_;
}         

=head2 C<fisher_yates_shuffle(@array)> and C<@shuffled=fisher_yates_shuffled(@array)>

The first shuffles the array in-place while the second returns a shuffled copy of the array

=cut
      
sub fisher_yates_shuffle(\@) {
   my ($array)=@_;
   my $i;
   for ($i = scalar(@$array); --$i; ) {
      my $j = int rand ($i+1);
      next if $i == $j;
      @$array[$i,$j] = @$array[$j,$i];
      }
}

sub fisher_yates_shuffled(@) {
   my (@array)=@_;
   my $i;
   for ($i = scalar(@array); --$i; ) {
      my $j = int rand ($i+1);
      next if $i == $j;
      @array[$i,$j] = @array[$j,$i];
      }
   return @array;   
}

  

END { }

1;
