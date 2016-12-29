package Hans2::OneParamFile;

=head1 NAME

Hans2::OneParamFile - maintain a shared configuration file.

=head1 COPYRIGHT

Copyright 2003 Hans Ecke hans@ecke.ws under the terms of the GNU Library General Public License

=head1 SYNOPSIS

=head2 In a module

   use Hans2::OneParamFile;

   register_param($name,%specification);

   register_remove_param($name);

=head2 In the main script

   use Hans2::OneParamFile;

   my %key_value = check_param(
         'file'  => "xplanet.conf",
         'check' => {
            'XPLANET_DIR' => {
               'comment'  => [
                  'The main xplanet installation directory, with the markers/ subdirectory for',
                  'marker files, the images/ subdirectory for map images etc.',
                  "",
                  "If the environment variable XPLANET_DIR is set, its value overrides what you write down here.",
                             ],
               'default'  => $Bin,
               'env'      => 'XPLANET_DIR',
               'nr'       => $general_nr,
               },
            },
         );

=head1 DESCRIPTION

Reading, writing and maintaining a configuration file that is shared between
multiple scripts that don't know of each other.

The configuration file is a hash of key-value pairs. It contains comments to each key.
The values are not dynamic (i.e. no language or macros are supported).

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

=head2 C<%PARAMS>

A hash key -E<gt> value of the config file from the last time it was processed

=cut

        @EXP_VAR     = qw(
                          %PARAMS
                           );
        @EXPORT      = (qw(
                          &register_param
                          &register_remove_param
                          &check_param
                           ),@EXP_VAR);
        @NON_EXPORT  = qw(
                          $general_nr
                          $local_off
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

use Hans2::Cwd;
use Hans2::FindBin;
use Hans2::Util;
use Hans2::File;
use Hans2::Debug;
use Hans2::Debug::Indent;
use Hans2::Constants;
use Hans2::DataConversion;

$general_nr=-100;
$local_off=0;

my $comment='#';

my %registered_params=();
my %registered_remove_params=();

my @initial_comment;

sub make_initial_comment() {
   @initial_comment=(
   'In this configuration file, you can customize all the perl scripts by',
   "$author_name <$author_email>.",
   '',
   'Please ONLY edit the values of each item. The comment sections as well as',
   'those "<nr:6> <lastdefval:skfdjdsj>" lines at the top of each comment section',
   'are used by the programs. Any changes by you will either be deleted by the next',
   'time a script is run or in the worst case, make the configuration file unusable.',
   );
   unshift @initial_comment,'';
   push    @initial_comment,'';
   foreach(@initial_comment) {
      s/\s+$//;
      $_=sprintf("%-82s",$_);
      $_.='#';
      }
   unshift @initial_comment, ('#' x 83 );
   push    @initial_comment, ('#' x 83 );
   };

=head2 configuration key specification hashes

Configuration keys have meta data besides just their values. Possible keys are:

Required:

     comment     => array of comment items
     nr          => position in config file

Required only in some situations / Optional

     default     => the current default value
     env         => which environment variables default it
                    scalar or ref to array of alternatives
     lastdefval  => default value at the last time this key was examined
     read        => value read from config file
     write       => the value to write back into the config file
                    * value read from config file if it contains that entry 
                      and that value is different from the previous default
                    * else the default given to check_param() 
     cur         => computed value:
                    * from environment variables if I<env> is set and those 
                      environment variables exist
                    * else the 'write' value above  

=head2 C<register_param($key,%info)>

The next time the config file is read, register and process this key (with its specification
in %info) as well, even if not specifically requested.

This way, modules can register their interest in specific configuration information. The
main script does not have to know about that.

Example:

   register_param('XPLANET_EXECUTABLE',
                  'comment'  => [
                     'The name and path of the xplanet executable.',
                                ],
                  'default'  => "xplanet",
                  'env'      => 'XPLANET',
                  'nr'       => 5,
                  );

=cut

sub register_param($%) {
   my ($key,%opts)=@_;
   $registered_params{$key}=\%opts;
}   

sub register_remove_param($) {
   my ($key)=@_;
   $registered_remove_params{$key}=1;
}   

# in: filename
# out: original file contents
#      hash of
#      <var name> => ref of config hash
sub read_cfg($) {
   my ($file)=@_;
   my $txt=readfile($file) || die "could not read configuration file $file\n";
   my @txt=split(/\n/,$txt);
   my @comment=();
   my %cfg;
   my $nr=0;
   if($txt[0] =~ /^#+$/) {
      while($_=shift @txt) {
         last if !$_;
         last if /^[^#]/;
         }
      }   
   foreach (@txt) {
      s/^\s+//;
      s/\s+$//;
      next if !$_;
      if(/^${comment}(.*)/) {
         my $c=$1;
         $c=~ s/^\s//;
         push @comment,$c;
         }
      elsif(/^(\w+)\s*\=\s*(.*)$/) {
         my ($key,$val)=($1,$2);
         my @c=@comment;
         my $first_line=shift @c;
         while(!$c[0]) {
            shift @c;
            };
         while(!$c[$#c]) {
            pop @c;
            };
         my %first_params=anglebracketoptions_decode($first_line);
         if(!defined $first_params{'nr'}) {
            my $msg=<<EOT;
Config file $file, key $key: did not understand first line. 
Possible reasons:

Reason:   You edited that config file inappropriately
Solution: You might _not_ edit the comments section of the config file.
          Only adjust the value of each config key, nothing else.
          Delete the file and let the scripts re-create the default 
          config file for you.
          
Reason:   A programming error in the perl scripts
Solution: Contact the author via e-mail at $author_email and send him
          $file
             
EOT
            die $msg;
            }   
         $cfg{$key}={'read'      => $val,
                     'comment'   => \@c,
                     %first_params,
                     };
         @comment=();            
         $nr++;
         }
      else {
         die "did not understand line <$_> in configuration file $file\n";
         }
      }
   return ($txt,%cfg);      
}

# sort 2 parameter hashes by key name
sub sort_param($$%) {
   my ($a,$b,%cfg)=@_;
   if(defined $cfg{$a}->{'nr'} and defined $cfg{$b}->{'nr'}) {
      my $r=$cfg{$a}->{'nr'} <=> $cfg{$b}->{'nr'};
      return $r if $r;
      }
   return $a cmp $b;
}   

# in: filename and config hash
# out: write config file
sub write_cfg($$%) {
   my ($file,$ori_txt,%cfg)=@_;
   my $txt="";

   make_initial_comment();

   foreach(@initial_comment) {
      if(/^#+$/) {
         $txt.="##$_\n";
         }
      else {
         $txt.="# $_\n";
         }
      }
   $txt.="\n";   
   foreach my $key (sort { sort_param($a,$b,%cfg)} keys %cfg) {
      my $param=$cfg{$key};
      my @comment=@{$param->{'comment'}};
      my $val=$param->{'write'};
      $val=$param->{'read'} if !defined $param->{'write'};
      my %firstparam=('nr'=> $param->{'nr'});
      $firstparam{'lastdefval'}=$param->{'lastdefval'} if defined $param->{'lastdefval'};
      $firstparam{'lastdefval'}=$param->{'default'} if defined $param->{'default'};
      $txt.="# ".anglebracketoptions_encode(%firstparam)."\n";
      $txt.="#\n";
      foreach(@comment) {
         s/\s+$//;
         $txt.="# $_\n";
         }
      $txt.="\n";
      $txt.=sprintf("%-30s",$key)." = $val\n";
      $txt.="\n";
      }
   if($txt eq $ori_txt) {
      writedebug("not updating config file $file since it would be unchanged");
      return;
      }   
   writefile($file,$txt) || die "could not write to configuration file $file\n";
}      

=head2 C<check_param('file'=>$file,'remove'=>\@remove,'check'=>\%check)>

Where

   $file    : config file name
   @remove  : array of config items to remove from config file
   %check   : key => ref of configuration hash

Out: processed config hash read from the config file
     <variable name> => current values, including env vars

     Also sets the global %PARAMS variable

Example:

    my %cfg=check_param(
       'file'   => 'xplanet.conf',
       'check'  => {
          'EARTHQ_TEMPLATE_LAST' => {
             'comment'  => [            
                'Another template for the earthquake that occured last.',
                'Same syntax as the above.',
                ],
             'default'  => '$lat $long "O" image=none align=center color=yellow fontsize=$size # $info<CR>$lat $long "$info" image=none color=yellow transparent={255,255,255} # $detail $time',
             'nr'       => $conf_offset + 1,
             },                 
          'EARTHQ_TEMPLATE_OLD' => {
             'comment'  => [            
                'Another template for older, but bigger earthquakes.',
                'Same syntax as the above.',
                ],
             'default'  => '$lat $long "O" image=none align=center color=yellow fontsize=$size # $info<CR>$lat $long "$info" image=none color=yellow transparent={255,255,255} # $detail $time',
             'nr'       => $conf_offset + 2,
             },
          }
       )                    

=cut

sub check_param(%) {
   my (%opts)=@_;
   
   my $file_base=$opts{'file'};
   
   my $ind=Hans2::Debug::Indent->new("Processing $file_base config file");
   
   my $cwd=getcwd();


   #
   # add default remove parameters from register_remove_param()
   #
   my @remove;
   if($opts{'remove'} or %registered_remove_params) {
      my %rem=%registered_remove_params;
      foreach (@{ $opts{'remove'}}) {
         $rem{$_}=1;
         }
      @remove=keys %rem;
      }   
      

   #
   # add default parameters from register_param() and validate
   #
   # default it with the registered parameters
   my %check=%registered_params;
   # now add/override the given parameters
   { my %check_p=%{ $opts{'check'} };
   foreach my $key (keys %check_p) {
      $check{$key}=$check_p{$key};
      }
   }   
   
   #
   foreach my $key (keys %check) {
      foreach my $what ("nr","default","comment") {
         exists $check{$key}->{$what} || die "invalid parameter $key does not include $what\n";
         }
      }
   
   #
   # determine whether we already have a config file; reading of the file
   #
   
   my @file_tries=($file_base,
                   File::Spec->catfile($cwd,$file_base),
                   File::Spec->catfile($Bin,$file_base)
                   );
   my $file;
   foreach (@file_tries) {
      if(-f $_ and -r $_) {
         $file=$_;
         last;
         }
      }   
   my ($ori_cfg,%cfg);
   if(!$file) {
      $file=File::Spec->catfile($Bin,$file_base);
      warn "making new config file $file\n";
      %cfg=();
      $ori_cfg="";
      }
   else {   
      ($ori_cfg,%cfg)=read_cfg($file);
      }

   foreach my $rem_key (@remove) {
      if(exists $cfg{$rem_key}) {
         warn "deleting obsolete variable $rem_key\n";
         delete $cfg{$rem_key};
         }
      }
      
   # %check : parameter to this func, has keys
   #          comment               - comment block
   #          default               - default value 
   #          env        (optional) - env vars to find it in
   #          nr                    - pos in conf file
   #          
   # %cfg   : from config file, has keys
   #          comment               - old comment block, discard
   #          read                  - current val from config file
   #          nr                    - pos in conf file
   #          lastdefval (optional) - default value from last run
   #
   # %cfg gets updated, keys are added:
   #          cur                   - current, effective value
   #          write                 - value to write back into file

   foreach my $chk_key (sort {sort_param($a,$b,%check)} keys %check) {
   
      my $from_prog=$check{$chk_key};
      my $from_file=$cfg{$chk_key};
      
      $from_prog->{'write'}=$from_prog->{'default'};
      $from_prog->{'lastdefval'}=$from_prog->{'default'};
      if($from_file) {
         # if the key was already in the config file, take its value IF its not the previous default
         if(!$from_file->{'lastdefval'} or $from_file->{'lastdefval'} ne $from_file->{'read'}) {
            $from_prog->{'write'}=$from_file->{'read'};
            }
         }
      # otherwise, take what was given to this func, but make sure there is a 'nr' parameter   
      else {
         warn "Adding variable ".sprintf("%-30s",$chk_key)."=".$from_prog->{'default'}." to config file $file\n";
         }
      %{$cfg{$chk_key}}=%{$from_prog};
      $from_file=$cfg{$chk_key};
      # now everything is in %cfg and we evaluate the record   

      my $env=$from_file->{'env'};
      my @env;
      my $env_val=undef;
      # generate the list of env vars to check
      if($env) {
         if(ref($env)) {
            @env=@$env;
            }
         else {
            @env=($env);
            }
         }   
      # check all the environment variables 
      foreach $env (@env) {
         next if !defined $ENV{$env};
         $env_val=$ENV{$env};
         writedebug("found envval $env=$env_val for $chk_key");
         last;
         }

      # the correct value is the environment value, if found, otherwise the value from the config file
      $env_val=$from_file->{'write'} if !defined $env_val;   
      # now $env_val contains the value we are looking for, set 'cur' to it
      $from_file->{'cur'}=$env_val;
      # set the environment variables to the value, if we are calling other programs that depend on it
      foreach $env (@env) {
         $ENV{$env}=$env_val;
         }
      writedebug(sprintf("%-30s",$chk_key)."= $env_val (".$from_file->{'nr'}.")");
      }         
   
   write_cfg($file,$ori_cfg,%cfg);
   
   %PARAMS=();
   foreach my $key (keys %cfg) {
      $PARAMS{$key}=$cfg{$key}->{'cur'};
      }
   
  return %PARAMS;
}   
         
END {}

1;
