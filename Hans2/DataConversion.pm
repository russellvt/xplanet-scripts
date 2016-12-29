package Hans2::DataConversion;

=head1 NAME

Hans2::DataConversion - convert between strings and different data formats

=head1 COPYRIGHT

Copyright 2003 Hans Ecke hans@ecke.ws under the terms of the GNU Library General Public License

=head1 SYNPOSIS

... fill me in

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
                         &anglebracketoptions_decode
                         &anglebracketoptions_encode
                         &xml_quote
                         &xml_unquote
                         &quote_fn
                         &dquote
                         &versionstring_2_vstring
                         &vstring_2_versionstring
                         &soundex
                         &soundex_number
                         &anytext_2_filename
                         &anytext_2_printable
                         &quoted_printable
                         &parse_eq_cl
                         &fileglob_2_perlre
                         &interpret_as_perl_string
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

=head2 C<anglebracketoptions_decode($string)> and C<anglebracketoptions_encode(%data)>

Those 2 functions encode a simple hash into an XML-like format that is suitable
for small data volumes.

   my %data=anglebracketoptions_decode("<nr=12> <formula=x&gt;y>");
   # now data is 
   #   'nr'       => 12,
   #   'formula'  => 'x>y',
   my $string=anglebracketoptions_encode(%data);
   # now $string is "<nr=12> <formula=x&gt;y>"

=cut

{

# the format of anglebracketdata is one-line: linebreaks have to be encoded as well.
my $abo_quote=sub {
   my ($txt)=@_;
   $txt=xml_quote($txt);
   $txt =~ s/\n/&HENL;/g;
   return $txt;
   };
my $abo_unquote=sub {
   my ($txt)=@_;
   $txt =~ s/&HENL;/\n/g;
   $txt=xml_unquote($txt);
   return $txt;
   };

sub anglebracketoptions_decode($) {
   my ($string)=@_;
   my @data=($string =~ /\<.*?\>/g);
   foreach(@data){  s/^\<\s*//;s/\s*\>$//; };
   @data=map {$abo_unquote->($_)} grep {$_} @data;
   my %data;
   foreach(@data) {
      /(\w+)[=:]?(.*)/ || die "did not understand record $_ in anglebrackets $string\n";
      my ($key,$val)=($1,$2);
      ($key,$val)=map {s/^\s+//;s/\s+$//;$_} ($key,$val);
      $data{$key}=$val;
      }
   return %data;
}      
   
sub anglebracketoptions_encode(%) {
   my (%data)=@_;
   my @data;
   foreach my $key (sort keys %data) {
      my $val=$data{$key};
      my $str="$key";
      $str.=":$val" if defined $val and $val ne "";
      push @data,$abo_quote->($str);
      }
   return "<".join("> <",@data).">";
}      

}
=head2 C<$xml=xml_quote($string)> and C<$string=xml_unquote($xml)>

Convert to and from XML.

=cut

# I don't really know what UTF-8 characters are.
# I don't really understand how you write UTF-8 characters in XML, either.
# But thats what this function does, obviously.
sub XmlUtf8Encode($) {
# borrowed from XML::DOM
    my ($n) = @_;
    if ($n < 0x80) {
        return chr ($n);
        } 
    elsif ($n < 0x800) {
        return pack ("CC", (($n >> 6) | 0xc0), (($n & 0x3f) | 0x80));
        } 
    elsif ($n < 0x10000) {
        return pack ("CCC", (($n >> 12) | 0xe0), ((($n >> 6) & 0x3f) | 0x80),
                     (($n & 0x3f) | 0x80));
        } 
    elsif ($n < 0x110000) {
        return pack ("CCCC", (($n >> 18) | 0xf0), ((($n >> 12) & 0x3f) | 0x80),
                     ((($n >> 6) & 0x3f) | 0x80), (($n & 0x3f) | 0x80));
        }
    return $n;
}

# quotes a scalar to be used as XML - text. 
sub xml_quote($) {
   my ($string)=@_;
   for ($string) {
      s/\&/\&amp;/ig;
      s/\</\&lt;/ig;
      s/\>/\&gt;/ig;
      s/\"/\&quot;/ig;
      s/([\x80-\xFF])/&XmlUtf8Encode(ord($1))/ge;
   }
   return $string;
}   

# un-escape XML base entities
sub xml_unquote($) {
    my ($string)=@_;
    for($string) {
       s/&lt;/</ig;
       s/&gt;/>/ig;
       s/&apos;/'/ig;
       s/&quot;/"/ig;
       s/&amp;/&/ig;
       }
    return $string;
}

=head2 C<$fn_quoted=quote_fn($filename)>

transform it into a form that can be used in the command line:

   if it contains spaces, put double quotes before and after
   quote any double quote inside with a backspace

=cut

use File::Spec;
my $filesep;
{   my $d=File::Spec->catfile("a","b");
   $filesep=$1 if $d =~ /^a(.)b$/;
}
sub quote_fn($) {
   my ($name)=@_;
   $name =~ s/"/\\"/g;
   my $allowed_chars='\w\-\_\.';
   $allowed_chars.=quotemeta($filesep) if defined $filesep;
   $name='"'.$name.'"' if $name =~ /[^$allowed_chars]/o;
   return $name;
}

=head2 C<$string=dquote($string)>

put quotes around string and quote any quotes inside

=cut

sub dquote($) {
   my ($name)=@_;
   $name =~ s/"/\\"/g;
   $name='"'.$name.'"';
   return $name;
}

=head2 C<versionstring_2_vstring> and C<vstring_2_versionstring>

convert between versions as V-Strings and versions as regular strings:

Example: 

   my $v=versionstring_2_vstring("5.6.0");
   # $v is now v5.6.0
   my $s=versionstring_2_vstring($v);
   # $s is now "5.6.0"

=cut

sub versionstring_2_vstring($) {
   my ($str)=@_;
   return undef if $str !~ /^[\d\.]+$/;
   return eval "v$str";
}   

sub vstring_2_versionstring($) {
   my ($v)=@_;
   return sprintf("%vd",$v);
}  
 
=head2 C<soundex($string)> and C<soundex_number($string)>

soundex() eturns the soundex value of a string

soundex_number() returns that value, but as a number

=cut 

sub soundex($) {
   my ($string)=@_;
   return if !defined $string;
   return if $string eq "";
   for($string) {
      $_=uc($_);
      tr/A-Z//cd;
      my ($f) = /^(.)/;
      tr/AEHIOUWYBFPVCGJKQSXZDTLMNR/00000000111122222222334556/;
      my ($fc) = /^(.)/;
      s/^$fc+//;
      tr///cs;
      tr/0//d;
      $_ = $f . $_ . '000';
      s/^(.{4}).*/$1/;
      }
   return $string;   
}

sub soundex_number($) {
   my ($string)=@_;
   return if !defined $string;
   return if $string eq "";
   $string=soundex($string);
   $string =~/^(.)(.)(.)(.)$/ || die "bad string $_\n";
   my ($n1,$n2,$n3,$n4)=($1,$2,$3,$4);
   return $n4+6*$n3+6*6*$n2+6*6*6*(ord($1)-ord("A"));
}

=head2 C<$filename=anytext_2_filename($txt)>

returns its argument converted to a string that is suitable to be a filename

the returned string is in a format similar to Quoted-Printable.

=cut

sub anytext_2_filename($) {
   my ($txt)=@_;
   for($txt) {
      s/([^\w\-\_\.])/sprintf("=%02X", ord($1))/eg; 
      }
   return $txt;
}

=head2 C<$quoted=anytext_2_printable($txt)>

returns its argument converted to a printable format similar to Quoted-Printable.

Differences:
    Leaves long lines alone (the standard says QP lines must not be longer than 76 chars)
    Does not quote many printable chars, including the '=' quoting character
    Therefore it is a one-way transformation, because the original can't be recovered
    Expands Tabs to Spaces
    Converts all 'spaces' (\s except \n) to Spaces (' ') 

=cut

use Text::Tabs;
sub anytext_2_printable($) {
   my ($txt)=expand(@_);
   $txt =~ s/\n\r/\n/g;
   $txt =~ s/\r\n/\n/g;
   $txt =~ s/(\s)/($1 eq "\n") ? ("\n") : (" ")/eg;
   $txt =~ s/([^ \n\w\~\!\@\#\$\%\^\&\*\(\)\_\+\`\-\=\[\]\{\}\|\;\'\:\"\,\.\/\<\>\?])/sprintf("=%02X", ord($1))/eg;  # rule #2,#3
   return $txt;
}

=head2 C<$quoted=quoted_printable($txt)>

returns its argument converted to Quoted-Printable

=cut

sub quoted_printable($) {
   my ($txt)=@_;
   $txt =~ s/([^ \t\n!-<>-~])/sprintf("=%02X", ord($1))/eg;  # rule #2,#3
   $txt =~ s/([ \t]+)$/join('', map { sprintf("=%02X", ord($_)) } split('', $1))/egm;                        # rule #3 (encode whitespace at eol)
   return $txt;
}

=head2 C<%args=parse_eq_cl($txt)>

parse a string like 

   "search=hhh.html Default=no title debug=0"

into a hash
    'search'  -> 'hhh.html'
    'default' -> 'no title'
    'debug'   -> '0'

return that hash

=cut

sub parse_eq_cl($) {
   my ($cl)=@_;
   return if !$cl;
   $cl =~ s/^\s+//;
   $cl =~ s/\s+$//;
   my %args=();
   my $arg;
   my $val;

   ($cl =~ /(\w+)=/g) && ($arg=$1);
   while ($cl =~ /\G(.*?)\s+(\w+)=/gc) {
      $val=$1;
      $args{lc($arg)}=$val;
      $arg=$2;
      }
   ($cl =~ /\G(.*)/g) && ($val=$1);
   $args{lc($arg)}=$val;

   return %args;   
   
}   

=head2 C<$perl_pattern=fileglob_2_perlre($glob_pattern)>

Converts between shell-style globbing patterns and perl-regular expressions.

I.e. something like C<*.pl> becomes C<^.*\.pl$>

=cut

sub fileglob_2_perlre($) {
   my ($glob)=@_;
   return undef if !defined $glob;
   return ""    if $glob eq '';
   $glob='^\Q'.$glob.'\E$';
   $glob =~ s/\*/\\E.*\\Q/g;
   $glob =~ s/\?/\\E.\\Q/g;
   $glob =~ s/\\Q\\E//g;
   $glob =~ s/\\E\\Q//g;
   $glob =~ s/\\Q\\E//g;
   $glob =~ s/\\E\\Q//g;
   $glob =~ s/\\Q(.*?)\\E/quotemeta($1)/eg;
   return $glob;
}

=head2 C<$str=interpret_as_perl_string($str)>

Converts strings like '\t' or '\x46' etc into their true meanings, i.e.
a string '\t' becomes a string containing a TAB and a string '\x46' becomes
a string containing an 'F'.

=cut

sub interpret_as_perl_string($) {
   my ($in)=@_;
   my $out;
   eval '$out="'.$in.'"';
   return $out;
}   


END {}

1;
