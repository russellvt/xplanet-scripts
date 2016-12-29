package Hans2::Ascii::Param;

=head1 NAME

Hans2::Ascii::Param - access key=value parameter files

=head1 COPYRIGHT

Copyright 2003 Hans Ecke hans@ecke.ws under the terms of the GNU Library General Public License

=head1 SYNOPSIS

my $param=Hans2::Ascii::Param->read("file.param");

=head1 DESCRIPTION

The parameter keys are very simply ordered: they will be written out in the same order
as they were read in. Newly added keys go to the end.

=cut

use strict;


BEGIN {
        use Exporter   ();
        use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS @EXP_VAR @NON_EXPORT);

#        $Exporter::Verbose=1;
        # set the version for version checking
        $VERSION     = 1.1;
        # if using RCS/CVS, this may be preferred
#        $VERSION = do { my @r = (q$Revision: 2.21 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };
        # The above must be all one line, for MakeMaker

        @ISA         = qw(Exporter);

# export variables
        @EXP_VAR     = qw(
                           );
# export functions
        @EXPORT      = (qw(
                           &noasciiparam
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

use Hans2::Util;
use Hans2::Units;
use Hans2::Math;
use Hans2::Algo;
use Hans2::StringNum;

my $extension='.param';

=head2 C<bool=noasciidata($unknown_scalar)>

An exported non-method!

return 1 if this is not a Hans2::Ascii::Param object

return 0 otherwise

=cut

sub noasciiparam($) {
   my ($data)=@_;
   return 1 if ! $data;
   return 1 if ! ref($data);
   return 1 if ! $data->isa("Hans2::Ascii::Param");
   return 0;
}   
   
=head2 C<$ext=extension()>

An unexported non-method!

return the default extension for Ascii::Param files

=cut

sub extension() {
   $extension
}   
   
# how an input line of text is split into constituents
sub datasplit($) {
   my ($txt)=@_;
   if(/^(.+?)\s*=\s*(.+)$/) {
      return ($1,$2);
      }
   return;   
   }

# how to print a row of datapoints   
sub datajoin($$;$) {
   my ($key,$val,$unit)=@_;
   if($unit) {
      $val = "$val $unit";
      }
   die "dasciiparam: key not defined\n" if !defined $key;   
   die "dasciiparam: value not defined for $key\n" if !defined $val;   
   return "$key = $val";
}      

# in: filename, options
# out: (\%parameter,\%order)
sub readparamfile_simple($%) {
   my ($fn,%opts)=@_;
   local *P;
   if(! -f $fn) {
      my @try=("$fn$extension");
      my $f=$fn;
      $f =~ s/\Q$extension\E$//;
      push @try,"$f$extension";
      foreach(@try) {
         if(-f $_) {
            $fn=$_;
            last;
            }
         }
      }
   
   open(P,$fn) || die "could not open parameterfile $fn for reading: $!\n";
   my %param;
   my %order;
   my $pos=0;
   while(<P>) {
      s/#.*//;
      s/^\s+//;
      s/\s+$//;
      next if !$_;
      my ($key,$val)=datasplit($_);
      if(defined($key) and defined($val)) {
         $key=lc($key);
         $param{$key}=$val;
         $order{$key}=$pos++;
         }
      }
   close P;
   return (\%param,\%order);
   }

###############################################################
#    CONSTRUCTORS
###############################################################

# storage:
#
# 'all'   => hash of
#
#      either    key  => [number, unit]
#      or        key  => value
#
# 'order' => hash of
#      'key' => order


=head2 C<$param=Hans2::Ascii::Param-E<gt>new(head=>value,...)>

Make new AsciiParam object from key-value pairs

   value is either
      * a scalar
      * an array-ref of [number, unit]

Keys are case-insensitive      

Ordering of input data will be retained

=cut

sub new($@) {
   my ($proto,@param)=@_;

   is_even(scalar(@param)) || die "Ascii::Param::new(): odd number of arguments (not a valid hash)\n";
   
   my %param;
   my %order;
   my $pos=0;
   while(@param) {
      my $head=lc(shift @param);
      my $val=shift @param;
      $order{$head}=$pos++;
      $param{$head}=$val;
      }

   my $class = ref($proto) || $proto;
   my $self  = {
      'all'   => \%param,
      'order' => \%order,
      };
   bless ($self, $class);
   return $self;
}

=head2 C<$param=Hans2::Ascii::Param-E<gt>new_full(\%param,\%order)>

like new(), except

   * you give a hash reference \%param instead of %param
   * the second argument, \%order gives an ordering 'key' => position

=cut

sub new_full($$$) {
   my ($proto,$param,$order)=@_;
   
   my $class = ref($proto) || $proto;
   my $i=0;
   my $self  = {
      'all'   => $param,
      'order' => $order,
      };
   bless ($self, $class);
   return $self;
}

# in: value string
# out: (number,unit) if parseable as such
sub try_interpret_as_sci($) {
   my ($val)=@_;
   my $re_num= '[\d\.]+';
   my $re_unit='[\w\/\^]+';
   $val =~ s/\s//g;
   # 12.5"
   if(   $val =~ /^($re_num)(\")$/o) {
      return ($1,'in');
      }
   # 43%   
   elsif($val =~ /^($re_num)(\%)$/o) {
      return($1/100,'');
      }
   # 100.3
   elsif($val =~ /^($re_num)$/o) {
      return ($val,'');
      }
   # 100.3 g/cc   
   elsif($val =~ /^($re_num)($re_unit)$/o) {   
      return ($1,$2);
      }
   return;   
}

=head2 C<$param=Hans2::Ascii::Param-E<gt>read($filename;%opts)>

read in data file $filename and return Hans2::Ascii::Param object

options:
   'mode'  => 'sci' : all values must be of form <number>[<unit>]
              'txt' : values are arbitrary text
              'mix' : try interpreting values as scientific. If not 
                      possible, interpret as text.

Format of parameter file:
   # starts a comment and is ignored
   empty lines are ignored
   Each line is one key-value pair
   $key=$val

=cut

sub read($$;%) {
   my ($proto,$fn,%opts)=@_;
   
   my ($param,$order)=readparamfile_simple($fn,%opts);
   
   # can be 
   #   'sci'   - strict
   #   'mix'   - try sci, don't enforce
   #   'txt'   - plain text
   my $mode=$opts{'mode'} || "mix";
   
   my %self;

   if($mode eq 'txt') {
      %self  = ( 
         'all'   => $param,
         'order' => $order
          );
      }
   else {      
      my %combined;
      foreach my $key (keys %$param) {
         my $val=$param->{$key};
         my ($num,$unit)=try_interpret_as_sci($val);
         if(defined $unit and is_numeric($num)) {
            $combined{$key}=[$num,$unit];
            }
         else {
            die "parameter \"$key = $val\" not scientific(?)\n" if $mode eq 'sci';
            if(defined $unit) {
               $combined{$key}=[$num,$unit];
               }
            else {   
               $combined{$key}=$val;
               }
            }
         }
      %self  = ( 
         'all'   => \%combined,
         'order' => $order 
         );
      }   

   my $class = ref($proto) || $proto;
   my $self  = \%self;
   bless ($self, $class);
   return $self;
}

###############################################################
#    PRIMITIVE PRIVATE ACCESSORS
###############################################################

# returns string form of entry $key
sub get_all($$) {
   my ($self,$key)=@_;
   my $val=$self->{'all'}->{$key};
   return if !defined $val;
   if(ref($val)) {
      if($val->[1]) {
         return $val->[0]." ".$val->[1];
         }
      else {   
         return $val->[0];
         }
      }
   else {
      return $val;
      }
}   
      
# returns (data,unit) if available, else dies
sub get_sci($$) {
   my ($self,$key)=@_;
   my $val=$self->{'all'}->{$key};
   return if !defined $val;
   if(ref($val)) {
      return @$val;
      }
   else {
      die "Ascii::Param::get_sci($key) called but no unit available\n"
      }
}   
      
sub set_sci($$$$) {
   my ($self,$key,$num,$unit)=@_;
   $self->{'all'}->{$key}=[$num,$unit];
   if(!defined $self->{'order'}->{$key}) {
      $self->{'order'}->{$key}=scalar(keys %{$self->{'all'}})-1;
      }
}

sub set_all($$$) {
   my ($self,$key,$val)=@_;   
   $self->{'all'}->{$key}=$val;
   if(!defined $self->{'order'}->{$key}) {
      $self->{'order'}->{$key}=scalar(keys %{$self->{'all'}})-1;
      }
}   
 
sub has($$) {
   my ($self,$key)=@_;
   $key=lc($key);
   return exists $self->{'all'}->{$key};
}

###############################################################
#    GENERIC, PUBLIC ACCESSORS
###############################################################

=head2 C<$param-E<gt>get($key)>

Return empty if no value for $key available.

If list required, return (data, unit). Die if not possible.

Else return whole value as string.

=cut

=head2 C<$num=$param-E<gt>get($key,$unit)>

Return empty if no value for $key available.

Return numerical value in that unit. Die if not numeric.

=cut

sub get($$;$) {
   my ($self,$key,$target_unit)=@_;
   $key=lc($key);
   if(defined $target_unit) {
      my ($num,$unit)=$self->get_sci($key);
      defined $num and defined $unit or return;
      return convert_units($num,$unit,$target_unit);
      }
   else {   
      if(wantarray()) {
         return $self->get_sci($key);
         }
      else {   
         return $self->get_all($key);
         }
      }   
}

=head2 C<$param-E<gt>getx($key;$unit)>

like get() above, but dies if asked for non-existing key

=cut

sub getx($$;$) {
   my ($self,$key,$target_unit)=@_;
   $key=lc($key);
   die "did not find parameter $key\n" if !$self->has($key);
   if(defined $target_unit) {
      my ($num,$unit)=$self->get_sci($key);
      defined $num and defined $unit or die "did not find scientific parameter $key\n";
      return convert_units($num,$unit,$target_unit);
      }
   else {   
      return $self->get($key);
      }
}
   
=head2 C<$param-E<gt>set($key,$val;$unit)>

set $key to $val. If $unit given, set $key's unit to it.

=cut

sub set($$$;$) {
   my ($self,$key,$val,$unit)=@_;
   $key=lc($key);
   if(defined($unit)) {
      $self->set_sci($key,$val,$unit);
      }
   else {
      $self->set_all($key,$val);
      }
}   

=head2 C<$unit=$param-E<gt>unit($key)>

Return unit of $key or die.

=cut

sub unit($$) {
   my ($self,$key)=@_;
   $key=lc($key);
   my $val=$self->{'all'}->{$key};
   ref($val) || die "unit of non-numeric parameter $key requested\n";
   return $val->[1];
}   

=head2 C<$num=$param-E<gt>num($key)>

Return number (quantity) of $key or die.

=cut

sub num($$) {
   my ($self,$key)=@_;
   $key=lc($key);
   my $val=$self->{'all'}->{$key};
   ref($val) || die "number of non-numeric parameter $key requested\n";
   return $val->[0];
}   

=head2 C<$param-E<gt>write($filename)>

Write parameters to $filename in the same format that is read.

=cut

sub write($$) {
   my ($self,$fn)=@_;
   
   $fn =~ s/\Q$extension\E$//;
   $fn.=$extension;

   local *P;
   open(P,">$fn") || die "could not open $fn for writing: $!\n";
   for my $key ($self->keys()) {
      my $val=$self->{'all'}->{$key};
      print P datajoin($key,$self->get_all($key))."\n";
      }
   close P;
}      

=head2 C<@keys=$param-E<gt>keys()>

return all keys in order

=cut

sub keys($) {
   my ($self)=@_;
   return sort {
      $self->{'order'}->{$a} <=> $self->{'order'}->{$b}
      ||
      $a cmp $b
               } keys %{$self->{'all'}};
}

=head2 C<$param-E<gt>add($param2)>

add all elements of Hans2::Ascii::Param object $param2

=cut

sub add($$) {
   my ($self,$p2)=@_;
   noasciiparam($p2) && die "Ascii::Param::add(): argument is no correct object\n";
   my $max_order=max_simple(values %{$self->{'order'}});
   my @k2=$p2->keys();
   my $o=$max_order+1;
   foreach my $k2 (@k2) {
      $self->{'all'}->{$k2}=$p2->{'all'}->{$k2};
      if(!defined $self->{'order'}->{$k2}) {
         $self->{'order'}->{$k2}=$o++;
         }
      }
}

END { }


1;
