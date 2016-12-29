package Hans2::Ascii::Data;

=head1 NAME

Hans2::Ascii::Data - access column data

=head1 COPYRIGHT

Copyright 2003 Hans Ecke hans@ecke.ws under the terms of the GNU Library General Public License

=head1 SYNOPSIS

my $ascii=Hans2::Ascii::Data->read("file.asc");

=head1 DESCRIPTION

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
                           &noasciidata
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
use Hans2::StringNum;
use Hans2::Ascii::Param;
use Hans2::Algo;
use Hans2::Math;

# storage structure
#
# 'has_headers'  => bool
#         whether we have known headers
# 'has_units'    => bool
#         whether we have units
# 'data'         => { key  => @data,...}
#         the actual data
# 'units'        => { key  => $unit,...}
#         the units
# 'length'       => number
#         the number of rows
# 'headers'      => \@headers
#         the list and ordering of columns

my $extension='.asc';

=head2 C<bool=noasciidata($unknown_scalar)>

An exported non-method!

return 1 if this is not a Hans2::Ascii::Data object

return 0 otherwise

=cut

sub noasciidata($) {
   my ($data)=@_;
   return 1 if ! $data;
   return 1 if ! ref($data);
   return 1 if ! $data->isa("Hans2::Ascii::Data");
   return 0;
}   
   
=head2 C<$ext=extension()>

An unexported non-method!

return the default extension for Ascii::Data files

=cut

sub extension() {
   $extension
}   
   
# how an input line of text is split into constituents
sub datasplit($) {
   my ($txt)=@_;
   return split(/\s+/,$txt);
   }

# how to print a row of datapoints   
sub datajoin(@) {
   my (@data)=@_;
   return join("\t ",@data);
}      

=head2 C<$ascii=Hans2::Ascii::Data-E<gt>from_params(@rows)>

construct a new object from an array of Ascii::Param objects

The input objects must be scientific (i.e. numeric and contain unit) and
all parameter objects must have the same 

=cut

sub from_params($@) {
   my ($proto,@rows)=@_;
   
   my @headers;
   my $length=undef;
   my %data;
   my %units;
   my $has_units;
   
   my $first=$rows[0];
   die "Ascii::Data::from_params(): no Ascii::Param object given\n" if noasciiparam($first);

   @headers=$first->keys();
   $length=scalar(@rows);
   foreach my $head (@headers) {
      $units{$head}=$first->unit($head);
      $data{$head}=[];
      }
   
   foreach my $row (@rows) {
      my @this_heads=$row->keys();
      die "Ascii::Data::from_params(): inconsistent arguments\n" 
         if !samearray(\@headers,\@this_heads);
      foreach my $head (@headers) {
         push @{$data{$head}},$row->getx($head,$units{$head});
         }
      }

   my $class = ref($proto) || $proto;
   my $self  = {
          'has_headers' => 1,
          'has_units'   => 1,
          'data'        => \%data,
          'units'       => \%units,
          'length'      => $length,
          'headers'     => \@headers,
          };
   bless ($self, $class);
   
   return $self;
}

=head2 C<$ascii=Hans2::Ascii::Data-E<gt>new(columname => {data},...)>

construct a new object from auxilliary information

{data} is a hash
        'data' => \@data array reference
        'unit' => $unit name (optional)

=cut

sub new($@) {
   my ($proto,@in)=@_;
   
   my @headers;
   my $length=undef;
   my %data;
   my %units;
   my $has_units;
   
   is_even(scalar(@in)) || die "Ascii::Data::new(): odd number of arguments (not a valid hash)\n";
   
   while(@in) {
      my $h=shift @in;
      my $d=shift @in;
      push @headers,$h;
      my %d=%$d;
      my $unit=$d{'unit'};
      my $data=$d{'data'};
      
      if(defined $length) {
         die "Ascii::Data::new() given columns of different lengths\n" 
            if $length != scalar(@$data);
         }
      else {
         $length=scalar(@$data);
         }   
      
      $data{$h}=$data;
      
      $units{$h}=$unit if $unit;
      }
      
   my @all_units=values %units;
   if(!@all_units) {
      $has_units=0;
      }
   elsif(scalar(@all_units) != scalar(@headers)) {
      die "Ascii::Data::new given some columns with, some without units\n";
      }      

   my $class = ref($proto) || $proto;
   my $self  = {
          'has_headers' => 1,
          'has_units'   => $has_units,
          'data'        => \%data,
          'units'       => \%units,
          'length'      => $length,
          'headers'     => \@headers,
          };
   bless ($self, $class);
   
   return $self;
}


=head2 C<$ascii=Hans2::Ascii::Data-E<gt>read($filename,%opts)>

construct a new object from a data file

options: required_headers : headers required, dies otherwise
         required_units   : units required, dies otherwise
         validator        : if string 'num' -> needs to be a number
                            if ref to func  -> function that takes 
                            datum and current colum name
         eval             : evaluate each value
                            if string 'perl' -> use perl eval
                            if ref to func   -> put each value into 
                            that func, replace with return value
         assert_units     : hash with header-unit mapping
                            all columns are rectified wrt that

=cut

sub read($$;%) {
   my ($proto,$fn,%opts)=@_;
   
   my $length=0;
   my $has_headers=0;
   my $has_units=0;
   my @headers;
   my %units;
   my %data;

   my @comments;
   my @data;
   {
      local *D;
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
      open(D,$fn) || die "could not open ASCII data file $fn for reading: $!\n";
      my @txt=<D>;
      close D;
      @txt=grep {defined $_ and $_ ne ""} map {s/^\s+//;s/\s+$//;$_} @txt;
      foreach(@txt) {
         if(/^\s*#\s*(.*)/) {
            push @comments,$1;
            }
         else {
            push @data,$_;
            }
         }   
   }
   if(@comments) {
      $has_headers=1;
      my $head=shift @comments;
      @headers=map {lc($_)} datasplit($head);
      foreach my $h (@headers) {
         $data{$h}=[];
         }
      if(@comments) {
         $has_units=1;   
         my $units=shift @comments;
         my @units=datasplit($units);
         die "given ".scalar(@units)." units and ".scalar(@headers)." headers. Those should be equal\n" 
            if scalar(@units) != scalar(@headers);
         for(my $i=0;$i<scalar(@headers);$i++) {
            $units{$headers[$i]}=$units[$i];
            }
         }      
      else {
         die "could not find units in ASCII data file $fn\n" if $opts{'required_units'};
         }   
      }
   else{
      die "could not find headers in ASCII data file $fn\n" if $opts{'required_headers'};
      $has_headers=0;
      my $head=$data[0];
      @headers=datasplit($head);
      my $n=scalar(@headers);
      @headers=(1 .. $n);
      }   
      
   if($opts{'eval'}) {
      if(!ref($opts{'eval'})) {
         $opts{'eval'}=sub {
            my $val=eval($_);
            die "evaluating expression $_ in ASCII data file $fn gives error: $@\n" if $@;
            return $val
            };
         }
      }   
   if($opts{'validator'}) {
      if(!ref($opts{'validator'})) {
         $opts{'validator'}=sub {is_numeric($_)};
         }
      }   

   foreach(@data) {
      my @dat=datasplit($_);
      if($opts{'eval'}) {
         my $i=0;
         foreach(@dat) {
            my $ori=$_;
            $_=$opts{'eval'}->($_,$headers[$i]);
            $i++;
            }
         }   
      if($opts{'validator'}) {
         my $i=0;
         foreach(@dat) {
            die "datum $_ did not fit the bill in ASCII file $fn\n" 
               if !$opts{'validator'}->($_,$headers[$i]);
            $i++;
            }
         }   
      die "line \"$_\": wrong number of fields\n" if scalar(@dat) != scalar(@headers); 
      my $i=0;
      foreach my $d (@dat) {
         push @{$data{$headers[$i]}},$d;
         $i++;
         }
      }
   $length=scalar(@data);   
   
   my $class = ref($proto) || $proto;
   my $self  = {
          'has_headers' => $has_headers,
          'has_units'   => $has_units,
          'data'        => \%data,
          'units'       => \%units,
          'length'      => $length,
          'headers'     => \@headers,
          };
   bless ($self, $class);
   
   if($opts{'assert_units'}) {
      my $new_units=$opts{'assert_units'};
      $self->change_units(%$new_units);
      }
   
   return $self;
}

=head2 C<$ascii-E<gt>change_units($header=E<gt>$new_unit,...)>

in: hash describing which columns should be changed to which units

    example: $data->change_units('Pc'=>'Pa')
    changes column 'Pc' to unit 'Pa'

this will only change columns if they are not already in that unit

=cut

sub change_units($%) {
   my ($self,%new_units)=@_;
   die "trying to change units in header-less dataset\n" if !$self->{'has_headers'};
   die "trying to change units in unit-less dataset\n" if !$self->{'has_units'};
   my $data=$self->{'data'};
   my $old_units=$self->{'units'};
   foreach my $head (keys %new_units) {
      # get variables and check that it applies      
      my $new_unit=$new_units{$head};
      die "asked to change column $head to <none> unit?!\n" if !$new_unit;
      $head=lc($head);
      next if !$self->has($head);
      my $old_unit=$old_units->{$head};
      die "asked to change header $head to $new_unit from <none>?!\n" if !$old_unit;
      next if $new_unit eq $old_unit;
      
      # do the conversion
      my $factor=convert_units_factor($old_unit,$new_unit);
      my @data= map {$_ * $factor} @{$data->{$head}};

      # writeback
      $data->{$head}=\@data;
      $old_units->{$head}=$new_unit;
      }
}   

=head2 C<$unit=$ascii-E<gt>unit($header)>

return unit of column $header

=cut

sub unit($$) {
   my ($self,$head)=@_;
   $head=lc($head);
   return undef if !$self->{'has_units'};
   return $self->{'units'}->{$head};
}

=head2 C<@units=$ascii-E<gt>units()>

return all units

=cut

sub units($) {
   my ($self)=@_;
   return if !$self->{'has_units'};
   my @u;
   foreach my $head (@{$self->{'headers'}}) {
      push @u,$self->{'units'}->{$head};
      }
   return @u;   
}

=head2 C<@column=$ascii-E<gt>column($header)>

return the whole column.

column name is checked

=cut

sub column($$) {
   my ($self,$head)=@_;
   $head=lc($head);
   die "trying to access non-existing header $head\n" if !$self->{'data'}->{$head};
   die "trying to access empty header $head\n"        if !@{$self->{'data'}->{$head}};
   return @{$self->{'data'}->{$head}};
}      

=head2 C<$column=$ascii-E<gt>column_ref($header)>

return the whole column, changable

column name is checked

=cut

sub column_ref($$) {
   my ($self,$head)=@_;
   $head=lc($head);
   die "trying to access non-existing header $head\n" if !$self->{'data'}->{$head};
   die "trying to access empty header $head\n"        if !@{$self->{'data'}->{$head}};
   return $self->{'data'}->{$head};
}      

=head2 C<$dat=$ascii-E<gt>x($header,$row_n)>

return the data point at row number $row_n (0-counted)

index and column name are checked

=cut

sub x($$$) {
   my ($self,$head,$i)=@_;
   $head=lc($head);
   die "trying to access non-existing header $head\n" 
      if !$self->{'data'}->{$head};
   die "trying to access empty header $head\n" 
      if !@{$self->{'data'}->{$head}};
   die "trying to access too big index $i (max is ".$self->{'length'}.")\n" 
      if $i >= $self->{'length'};
   die "trying to access non-existing index $i for header $head\n"          
      if !defined $self->{'data'}->{$head}->[$i];
   return $self->{'data'}->{$head}->[$i];
}      

=head2 C<$rown_n=$ascii-E<gt>length()>

how many rows we have

=cut

sub length($) {
   my ($self)=@_;
   return $self->{'length'};
}

=head2 C<bool=$ascii-E<gt>has($head)>

whether the column "$head" is known

=cut

sub has($$) {
   my ($self,$head)=@_;
   $head=lc($head);
   return 1 if exists $self->{'data'}->{$head};
   return undef;
   }
   
=head2 C<$ascii-E<gt>set($head,@data)>

replace column $head without touching the unit

=cut

sub set($$@) {
   my ($self,$head,@data)=@_;
   $head=lc($head);
   die "trying to replace non existing column $head\n" 
      if !$self->has($head);
   die "changing header $head: not of size ".$self->{length}."\n" 
      if scalar(@data) != $self->{'length'};
   $self->{'data'}->{$head}=\@data;
}   

=head2 C<$ascii-E<gt>set1($head,$i,$data)>

set element #$i in column $head to $data

=cut

sub set1($$$$) {
   my ($self,$head,$i,$data)=@_;
   $head=lc($head);
   die "trying to replace element in non existing column $head\n" 
      if !$self->has($head);
   die "changing element $i of header $head: $i is bigger than  ".$self->{length}."\n" 
      if $i >= $self->{'length'};
   die "changing element $i of header $head: $i is negative\n" 
      if $i < 0;
   $self->{'data'}->{$head}->[$i]=$data;
}   

=head2 C<$ascii-E<gt>add($head,\@data,$unit)>

add a column to our data

   $head - column name
   @data - data array ref
   $unit - unit of data (if available)

=cut

sub add($$$;$) {
   my ($self,$head,$data,$unit)=@_;
   $head=lc($head);
   die "adding header $head: not of size ".$self->{length}."\n" if scalar(@$data) != $self->{'length'};
   push @{$self->{'headers'}},$head;
   if($self->{'has_units'}) {
      die "trying to add column $head without units to a dataset with units (first elem is ".$data->[0]." )\n" 
         if !defined $unit;
      $self->{'units'}->{$head}=$unit;
      }
   else {
      die "trying to add column $head with unit $unit to dataset without units\n"
         if defined $unit;
      }   
   $self->{'data'}->{$head}=$data;
}   

=head2 C<@heads=$ascii-E<gt>headers()>

returns headers array

=cut

sub headers($) {
   my ($self)=@_;
   return @{$self->{'headers'}};
   }
 
=head2 C<$ascii-E<gt>sort_columns($header=E<gt>$order,...)>

sorting headers after new order given

  example:
  $data->sort_headers('ts1' => 100)    put ts1 at the end (if we have less than 100 columns)
  $data->sort_headers('file' => -100)  put file at the start

=cut

sub sort_columns($%) {
   my ($self,%new_order)=@_;
   my @old_headers=@{$self->{'headers'}};
   my %old_order;
   # default order is the same as before
   for(my $i=0;$i<scalar(@old_headers);$i++) {
      $old_order{$old_headers[$i]}=$i;
      }
   # override with the given new order   
   foreach my $head (keys %new_order) {
      $head=lc($head);
      if(defined $old_order{$head}) {
         $old_order{$head}=$new_order{$head};
         }
      else {
#         warn "header $head not found and can therefore not be re-ordered\n";
         }      
      }
   # get new headers: sort by number and if even, by column name   
   my @new_headers=sort {$old_order{$a} <=> $old_order{$b} || $a cmp $b } keys %old_order;      
   $self->{'headers'}=\@new_headers;
}   

=head2 C<$ascii-E<gt>write($filename)>

write table to file

=cut

sub write($$) {
   my ($self,$fn)=@_;
   my $headers=$self->{'headers'};
   my $data=$self->{'data'};
   my $length=$self->{'length'};
   my $units=$self->{'units'};

   $fn =~ s/\Q$extension\E$//;
   $fn.=$extension;

   local *D;
   open(D,">$fn") || die "could not open $fn for writing: $!\n";
   if($self->{'has_headers'}) {
      print D "# ".datajoin(@$headers)."\n";
      if($self->{'has_units'}) {
         my @units;
         foreach(@$headers) {
            push @units,$units->{$_};
            }
         print D "# ".datajoin(@units)."\n";
         }
      print D "\n";   
      }
  for(my $row=0;$row < $length;$row++) {
     my @v;
     foreach my $h (@$headers) {
        push @v,$data->{$h}->[$row];
        }
     print D datajoin(@v)."\n";   
     }
  close D;
}      

=head2 C<%stat=$ascii-E<gt>colstat($column)>

Return a hash containing
   'max'    => maximum value
   'min'    => minimum value
   'stddev' => standard deviation
   'mean'   => mean
   
=cut

sub colstat($$) {
   my ($self,$head)=@_;
   $head=lc($head);
   die "trying to get statistics of non existing column $head\n" if !$self->has($head);
   my ($min,$max,$mean,$stddev);
   return statistics($self->{'data'}->{$head});
}

=head2 C<$stat=$ascii-E<gt>colstatparam($column)>

Like colstat(), except it returns a Hans2::Ascii::Param object with the correct units

Also, all keys are prefixed with "${column}_", so you can better add those parameters up

=cut

sub colstatparam($$) {
   my ($self,$head)=@_;
   $head=lc($head);
   die "trying to get statistics of non existing column $head\n" if !$self->has($head);
   my ($min,$max,$mean,$stddev);
   my %stat=statistics($self->{'data'}->{$head});
   my $unit=$self->unit($head);
   return Hans2::Ascii::Param->new(
      $head."_min"    => [ $stat{'min'}, $unit ],
      $head."_max"    => [ $stat{'max'}, $unit ],
      $head."_mean"   => [ $stat{'mean'}, $unit ],
      $head."_stddev" => [ $stat{'stddev'}, $unit ],
      );
}

=head1 SEE ALSO

Hans2::Ascii::Param

=cut

END { }


1;
