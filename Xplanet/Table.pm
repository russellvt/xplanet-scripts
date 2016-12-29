package Xplanet::Table;

=head1 NAME

Xplanet::Table - printing a table of text and images.

=head1 COPYRIGHT

Copyright 2003 Hans Ecke under the terms of the GNU General Public Licence

=head1 DESCIRPTION

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
                           table_2_markerfile
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

use Hans2::Algo;
use Hans2::Debug;

my $default_avg_x_size=6.7;
my $default_avg_y_size=20;

sub txt_cell_draw($$%) {
   my ($x,$y,%cell)=@_;
   my $str=$cell{'txt'};
   return "" if !$str;
   my $width =$cell{'width'};
   my $height=$cell{'height'};
   my $avg_x_size=$cell{'avg_x_size'};
   $x+=$avg_x_size/2;
#   $x+=$width/2;
#   $y+=$height/2;
   my ($xx,$yy)=(int($x),int($y));
   my $txt="$yy $xx \"$str\" image=none position=pixel align=right";
   my %understand=(
      'color'  => 1,
      );
   foreach my $key (keys %cell) {
      if($understand{$key}) {
         $txt.=" $key=".$cell{$key};
         }
      }
   writedebug($txt);
   return $txt;
}   

sub icn_cell_draw($$%) {
   my ($x,$y,%cell)=@_;
   my $file=$cell{'icon'};
   return "" if !$file;
   my $width =$cell{'width'};
   my $height=$cell{'height'};
   $x+=$width/2;
#   $y+=$height/2;
   my ($xx,$yy)=(int($x),int($y));
   my $txt="$yy $xx \"\" image=$file position=pixel";
   my %understand=(
      'transparent' => 1,
      );
   foreach my $key (keys %cell) {
      if($understand{$key}) {
         $txt.=" $key=".$cell{$key};
         }
      }
   writedebug($txt);
   return $txt;
}   

sub cell_draw($$%) {
   my ($x,$y,%cell)=@_;
   if($cell{'txt'}) {
      return txt_cell_draw($x,$y,%cell);
      }
   else {
      return icn_cell_draw($x,$y,%cell);
      }   
}   

sub txt_cell_size(%) {
   my (%cell)=@_;
   my $str=$cell{'txt'};
   return (0,0) if !$str;
   my $width =$cell{'avg_x_size'}*(length($str)+1);
   my $height=$cell{'avg_y_size'};
   return ($width,$height);
}

sub icn_cell_size(%) {
   my (%cell)=@_;
   my $fn=$cell{'icon'};
   return (0,0) if !$fn;
   my $width =$cell{'width'}  || die "icon $fn: no width given\n";   
   my $height=$cell{'height'} || die "icon $fn: no height given\n";   
   return ($width,$height);
}   

sub cell_size(%) {
   my (%cell)=@_;
   if($cell{'txt'}) {
      return txt_cell_size(%cell);
      }
   elsif(exists $cell{'icon'}) {
      return icn_cell_size(%cell);
      }
   else {
      die "bad cell\n";
      }
}            

=head2 C<print MARKERFILE, table_2_markefile(%table)>

%table is a hash with elements:

  'x_start'    => how far from left
                  how far from right if negative
  'y_start'    => how far from top
                  how far from bottom if negative
  'avg_x_size' => character width
  'avg_y_size' => character height
  'd'          => array of rows, 
                  each of which is an array of cell-hashes
                  with elements
                     'txt'   => some text
                     'color' => text color (optional)
                      or
                     'icon'  => iconname
                     'width' => pixels..     
                     'height'=> pixels...

out: markerfile-string that displays the table in an xplanet map

=cut

sub table_2_markerfile(%) {
   my (%tbl)=@_;
   my $x_start   = $tbl{'x_start'};
   my $y_start   = $tbl{'y_start'};
   my $avg_x_size= $tbl{'avg_x_size'} || $default_avg_x_size;
   my $avg_y_size= $tbl{'avg_y_size'} || $default_avg_y_size;
   my $d=$tbl{'d'};
   my @d=@$d;

   my @c_w;  # column-width
   my @r_h;  # row-height
   
   my $row_num;
   my $col_num;
   
   
   my $rn=0;
   foreach my $row (@d) {
      $r_h[$rn]=0;
      my $cn=0;
      foreach my $cell (@$row) {
         $c_w[$cn]||=0;
         my %cell=%$cell;
         my $colspan=$cell{'colspan'} || 1;
         
         my ($width,$height)=cell_size(%cell,
                               'avg_x_size' => $avg_x_size,
                               'avg_y_size' => $avg_y_size,
                               );
         $height+=1;   
         $width +=1;   
         $r_h[$rn]=max_simple($r_h[$rn],$height);

         if($colspan==1) {
            $c_w[$cn]=max_simple($c_w[$cn],$width);
            }
            
         $cn+=$colspan;
         $col_num=$cn;
         }
      $rn++;
      $row_num=$rn;
      }
      
   my $tbl_height=0;   
   foreach(@r_h) {
      $tbl_height+=$_;
      }
   my $tbl_width=0;
   foreach(@c_w) {
      $tbl_width+=$_;
      }
   
   $y_start-=$tbl_height if $y_start<0;
   $x_start-=$tbl_width  if $x_start<0;
   $y_start+=$r_h[$row_num-1]/2;
   
   my $y=$y_start;
   my $txt="";
   $rn=0;
   foreach my $row (@d) {
      my $x=$x_start;
      my $height=$r_h[$rn];
      my $cn=0;
      foreach my $cell (@$row) {
         my $width=$c_w[$cn];
         my %cell=%$cell;
         my $colspan=$cell{'colspan'} || 1;
         $txt.=cell_draw($x,$y,%cell,
                               'x_start'    => $x_start,
                               'width'      => $width,
                               'height'     => $height,
                               'avg_x_size' => $avg_x_size,
                               'avg_y_size' => $avg_y_size,
                               );
         $txt.="\n"; 
         $x += $width;
         $cn+= $colspan; 
         }
      $rn++;
      $y+=$height;
      $txt.="\n";
      writedebug("");
      }
   
   return $txt;
   
}

END {}

1;
