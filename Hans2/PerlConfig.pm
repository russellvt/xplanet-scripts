package Hans2::PerlConfig;

=head1 NAME

Hans2::PerlConfig - parse a configuration file written in Perl

=head1 COPYRIGHT

Copyright 2003 Hans Ecke hans@ecke.ws under the terms of the GNU Library General Public License

A simplification and object-oriented rewrite of Parse::PerlConfig
Copyright (C) 1999 Michael Fowler, all rights reserved

=head1 SYNOPSIS

    my $parser=Hans2::PerlConfig->new(%options);

    my $return=$parser->eval_file($filename);
    my $return=$parser->eval($perlcode);

    # $symbol contains a ref to the symbol table hash
    my $symbols=$parser->symboltable();
    # %ssymbol contains a copy of the scalars in the symbol table
    my %ssymbols=$parser->scalar_symboltable();

    # set $return to PI
    my $return=$parser->value('atan2(1,1)*4');
    
    $parser->set_scalar('CONFIG_DIR','/usr/local/install');
    my $CFG_DIR=$parser->get_scalar('CONFIG_DIR');

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

use Data::Dumper;
use Hans2::FindBin;

our %thing_key2str = (
    'SCALAR' => '$',
    'ARRAY'  => '@',
    'HASH'   => '%',
#    'CODE'   => '&',
#    'GLOB'   => '*',
#    'IO'     => 'i',
    );

=head2 C<$parser=Hans::PerlConfig-E<gt>new(%options)>

Generate a new parser object. %options may contain:

   Taint_Clean (0) - whether we should un-taint the string and file
   Lexicals        - a hash containing variables we wish the 
                     namespace to be aware of
   Uses            - a list of modules the namespace should use
   
   Warn_default  (warn - the default behavior for warnings and errors:
   Error_default (die)   Possible are
                            warn       - warn if $^W is set
                            fwarn      - warn anyway
                            die        - die with error message
                            noop       - ignore
                            <code-ref> - do whatever the sub specifies 
   
   Warn_preparse        (noop)    - warn message that we start parsing now
   Warn_eval            (default) - problems with eval()
   Error_argument       (default) - bad argument to function
   Error_file_is_dir    (default) - config file is a directory
   Error_failed_open    (default) - could not open file
   Error_eval           (default) - could not eval
   Error_invalid_lexical(default) - invalid lexcial in config file namespace
   
=cut

sub new($%) {
   my ($proto,@args)=@_;
   my $class = ref($proto) || $proto;

   my $subname = (caller(0))[3];

   my %args = (
       Namespace_Base          =>      __PACKAGE__ . '::ConfigFile',

       Taint_Clean             =>       0,

       Warn_default            =>      'warn',
       Warn_preparse           =>      'noop',
       Warn_eval               =>      'default',

       Error_default           =>      'die',
       Error_argument          =>      'default',
       Error_file_is_dir       =>      'default',
       Error_failed_open       =>      'default',
       Error_eval              =>      'default',
       Error_invalid_lexical   =>      'default',
   );

   %args = (%args, @args);

   my $def_errsub  = _errsub($args{'Error_default'},'default');
   my $def_warnsub = _errsub($args{ 'Warn_default'},'default');

   my(%errsubs, %warnsubs);
   foreach my $handler (qw(
      argument
      file_is_dir
      failed_open
      eval
      )) {
      $errsubs{$handler} = _errsub($args{"Error_$handler"}, $def_errsub);
      }

   foreach my $handler (qw(preparse eval)) {
      $warnsubs{$handler} = _errsub($args{"Warn_$handler"}, $def_warnsub);
      }

   # This allows us to pass around %args, rather than each hash necessary.
   $args{'_errsubs'}  = \%errsubs;
   $args{'_warnsubs'} = \%warnsubs;

   my %lexicals;
   if (ref $args{Lexicals} eq 'HASH') {
       %lexicals = %{ $args{Lexicals} };
       }
   elsif (defined $args{Lexicals}) {
       $errsubs{'argument'}->("Lexicals argument must be a hashref in call to $subname.");
       }
   $args{Lexicals}=\%lexicals;    

   my $self=\%args;
   bless ($self, $class);

   $args{'lexicals_string'} = $self->_construct_lexicals_string();

   $args{'Namespace'} = $self->_construct_namespace();

   my $lexicals=$self->{'lexicals_string'};
   my $use_call=join("",map {"use $_;\n"} @{$self->{'Uses'}}); 

   $self->_do_eval($use_call."\n".$lexicals);
           
   return $self;
}

=head2 C<$return=$parser-E<gt>value($perlcode)>

Execute the string in scalar context and return its perl value
   
=cut

sub value($$) {
   my ($self,$str)=@_;
   our $out;
   local $out;

   $str = ($str =~ /(.*)/) if $self->{'Taint_Clean'};

   my $namespace=$self->{'Namespace'};
   my $opackage=__PACKAGE__;

   no strict;
   local $^W=undef;
   eval("package $namespace;\nsub huhu {$str;}\n".'$out=huhu();'."\npackage $opackage;\n");
   use strict;
   
   return $out;
}   

# internal function: evaluate a piece of perl code
sub _do_eval($$) {
   my ($self,$str)=@_;
   
   $str = ($str =~ /(.*)/) if $self->{'Taint_Clean'};

   my $namespace=$self->{'Namespace'};
   my $opackage=__PACKAGE__;
   my $return;

   no strict;
   $return=eval("package $namespace;\n$str;\n");
   use strict;
   eval("package $opackage;\n");
   $self->{'symboltable'}=_parse_symbols($namespace);
   
   return $return;
}

=head2 C<$symbols=$parser-E<gt>symboltable()>

Return a reference to the Parser's symbol table hash, of the form

   <sigil><variable name> => <variable value>

=cut

sub symboltable($) {
   my ($self)=@_;
   return $self->{'symboltable'};
}

=head2 C<%symbols=$parser-E<gt>scalar_symboltable()>

Return a copy of all scalars in the Parser's symbol table, of the form

   <variable name> => <variable value>

=cut

sub scalar_symboltable($) {
   my ($self)=@_;
   my %symbol;
   foreach(keys %{$self->{'symboltable'}}) {
      next if !/^\$(\w+)$/;
      my $var=$1;
      my $val=$self->{'symboltable'}->{$_};
      next if ref($val);
      $symbol{$var}=$val;
      }
   return %symbol
}

=head2 C<$return=$parser-E<gt>eval_file($filename)>

Execute the specified file and return the value of its last statement
   
=cut

sub eval_file($$) {
   my ($self,$file)=@_;
   $self->{_errsubs}->{'file_is_dir'}->("Config file \"$file\" is a directory.") if -d $file;
   $self->{_warnsubs}->{'preparse'}->("Preparing to parse config file \"$file\".");
   my @txt;
   {
      local $/;
      local *FILE;
      if(!open(FILE,"< $file")) {
          $self->{_errsubs}->{'failed_open'}->("Unable to open config file \"$file\": $!.");
          return;
          }
      @txt=<FILE>;
      close FILE;
      }   
   return $self->eval(join("",@txt));
}

=head2 C<$return=$parser-E<gt>eval($perlcode)>

Execute the string and return its perl value
   
=cut

sub eval($$) {
   my ($self,$string)=@_;

   my $subname = (caller(0))[3];

   my $eval_warn = $self->{_warnsubs}->{'eval'};

   local $SIG{__WARN__} = sub { $eval_warn->(join "", @_) };

   my $return=$self->_do_eval($string);

   my $error;
   if (defined($error = $self->{Error})) {
       $self->{_errsubs}->{'eval'}->("Configuration file raised an error: $error.");
       return;
       }
   elsif ($@) {
       $error = $@;
       1 while chomp($error);
       $self->{_errsubs}->{'eval'}->("Error in configuration eval: $error.");
       return;
       }

   return $return;

}

=head2 C<$parser-E<gt>set_scalar($name,$value)>

Set the scalar variable $name to $value in the parser
   
=cut

sub set_scalar($$$) {
   my ($self,$var,$val)=@_;
   my $namespace=$self->{'Namespace'};
   no strict 'refs';
   local $^W=undef;
   ${"${namespace}::${var}"}=$val;
   $self->{'symboltable'}->{'$'.$var}=$val;
}   

=head2 C<$value=$parser-E<gt>get_scalar($name)>

Get the scalar variable $name
   
=cut

sub get_scalar($$) {
   my ($self,$var)=@_;
   my $namespace=$self->{'Namespace'};
   no strict 'refs';
   local $^W=0;
   return ${"${namespace}::${var}"};
}   

# _parse_symbols($namespace) 
#
# This an internal function to do the actual parsing of
# symbols from a namespace.
sub _parse_symbols($) {
   my ($namespace)=@_;

   my %parsed_symbols;
 
   no strict 'refs';
   while (my($symbol, $glob) = each(%{"$namespace\::"})) {
       foreach my $thing (keys %thing_key2str) {
           my $value=undef;
           if ($thing eq 'SCALAR') {
               # Special case for scalars; we always get a scalar
               # reference, even if the underlying scalar is undefined.
               $value = ${*$glob{SCALAR}};
               }    
           else {
               $value = *$glob{$thing};
               }
           $parsed_symbols{"$thing_key2str{$thing}$symbol"} = $value if defined($value);
           }
       }

    return \%parsed_symbols;
}

# construct the perl code that puts a copy of our lexicals in
# the parser's namespace
sub _construct_lexicals_string($) {
   my ($self) = (@_);

   my $lexicals=$self->{'Lexicals'};

   return '' unless %{$lexicals};

   my $inv_lex_errsub = $self->{'_errsubs'}->{'invalid_lexical'};

   my $lexicals_string = '';

LEXICAL: while (my($key, $value) = each(%$lexicals)) {

       if ($key !~ /^([^_\W][\w\d]*|\w[\w\d]+)$/) {
          $inv_lex_errsub->(
             "Lexical name \"$key\" is invalid, must be a valid " .
             "identifier."
             );
          next LEXICAL;
          }
       elsif (ref($value) eq 'CODE') {
          $inv_lex_errsub->(
             "Lexical \"$key\" value is invalid, code references " .
             "are not allowed."
             );
          next LEXICAL;
          }
       elsif ($key eq 'parse_perl_config' && ref($value) eq 'HASH') {
          $inv_lex_errsub->(
             "Cannot have a hash lexical named \"parse_perl_config\"."
             );
          next LEXICAL;
          }
       $lexicals_string .= 'my ' . Data::Dumper->Dump([$value], ["*$key"]);
       }

    return $lexicals_string;
}

# construct the namespace identifier
sub _construct_namespace($) {
    my($self) = (@_);

    my $namespace;
    if (defined $self->{'Namespace'}) {
        $namespace = $self->{'Namespace'};
        }
    else {
        $namespace = $self->{'Namespace_Base'}.'::' . _rand_namespace();
        }

    if ($self->{'Taint_Clean'}) {
        # We've already filtered the namespace, but perl doesn't know
        # that; fake it.
        ($namespace) = ($namespace =~ /(.*)/);
        }

    return $namespace;
}

# whether a given namespace identifier is valid
sub _valid_namespace($) {
    my ($namespace) = @_;

    foreach my $ns_ele (split /::/, $namespace) {
        return 0 unless $ns_ele =~ /^[_A-Za-z][_A-Za-z0-9]*/;
        }

    return 1;
}

# return a random element of the argument array
sub random_array_elem(@) {
   $_[int(rand(scalar(@_)))];
}   

# construct a random string for the namespace identifier
sub _rand_namespace() {
   my $str="";
   my @allow=('a' .. 'z', 'A' .. 'Z', '0', '1' .. '9');
   for(1 .. 20) {
      $str.=random_array_elem(@allow);
      }
   my $me=$FindBin::Script;
   $me =~ s/\W//g;   
   $me = 'ME' if !$me;
   return $me.'::'.$$.'::'.$str;
}

sub _fwarn {  CORE::warn(shift() . "\n")          }
sub _warn  {  CORE::warn(shift() . "\n") if $^W   }
sub _die   {  CORE::die (shift() . "\n")          }
sub _noop  {                                      }

# _errsub <error spec> [<default coderef>]
#       Responsible for parsing the "default", "noop", "warn", "fwarn", and
#       "die" strings, and returning an appropriate code reference.

sub _errsub($$) {
    my($spec, $default) = (@_);
    $spec = lc($spec) unless ref($spec);

    (ref $spec eq 'CODE' )          &&      return $spec;
    (    $spec eq 'warn' )          &&      return \&_warn;
    (    $spec eq 'fwarn')          &&      return \&_fwarn;
    (    $spec eq 'die'  )          &&      return \&_die;
    (    $spec eq 'noop' )          &&      return \&_noop;

    # catch anything that falls through
    return (ref $default eq 'CODE') ? $default : \&_warn;
}

END {}

1;


