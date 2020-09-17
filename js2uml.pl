#!/usr/bin/perl -w
# See README.md for details.

use strict;
use warnings;
use File::Find;
use File::Copy;
use File::Slurp;
use Config;
use Cwd;

# UML browser target
my $browser_linux='x-www-browser';                         # default
#my $browser_linux='firefox';
#my $browser_linux='chromium-browser';
my $browser_macos='open -a Safari';                        # default
#my $browser_macos='open -a Firefox';
#my $browser_macos='open -a Vivaldi';
my $browser_win10='iexplore.exe';                          # default
#my $browser_win10='c:/Windows/SystemApps/Microsoft.MicrosoftEdge_8wekyb3d8bbwe/MicrosoftEdge.exe';
#my $browser_win10='c:/Windows/Program Files/Mozilla Firefox/firefox.exe';
my $browser_other_msg='UML output was generated at ${cwd}/${uml_dir}.';

# Configuration file target
my @cfg_keys = qw(title header footer sourceFile output author borderColor backgroundcolor);
my $filename_local = $cwd . '/' . $uml_dir . '/' . "localconfig.js";
my $filename_global = $cwd . '/' . $exec_path;
$filename_global =~ s/\/index.js//;
$filename_global = $filename_global . "/../lib/" . "config.js"; 

my %vars;                                                  # Define global variable hash.

my $cwd = Cwd::cwd();                                      # Let current working directory be defined.
$vars{'cwd'} = $cwd;

my $num_args = $#ARGV + 1;                                 # Let number of args be defined by environment.
if ($num_args != 3) {
    print "\nUsage: js2uml.pl <path/to/index.js> <source input directory> <uml output directory>\n";
}

my $exec_path=$ARGV[0];                                    # Let index.js executable path be argument 1.

my @js_dir;                                                # Let source file input directory be argument 2.
@js_dir[0]=$ARGV[1];

my $uml_dir=$ARGV[2];                                      # Let uml diagram output directory be argument 3.
$vars{'uml_dir'} = $uml_dir;

makeLocalConfig();                                         # Modify config if not already there.
rename($filename_global, $filename_global . '.old') or die "$!";
copy($filename_local, $filename_global) or die "$!";       # Use local configuration

find(\&wanted, @js_dir);                                   # Find wanted files in input directory.

rename($filename_global . '.old', $filename_global);       # Restore global configuration

view();                                                    # Launch browser.

exit;


# Walk all JavaScript source files recursively.
sub wanted {
    /^.*\.js\z/s && # dir, _, name
    doexec();

}


# Pre-processing for failed AST test cases:
# * export keywords -> one word, turns into nothing
# * import clauses -> no nesting, turns into nothing
# * nested anonymous functions -> turns into "anonymous"
#TODO: put this into a functional language.
sub doexec {
    
    my $buf = read_file($cwd . '/' . $File::Find::name);   # Read file into buffer.

    $buf =~ s/^export \*.*;\n//gm;                         # Remove all export keywords from buffer.
    $buf =~ s/export //g;

    $buf =~ s/^import[^;]*(\n.*;{0})*(\n)*.*;//gm;         # Remove all import clauses from buffer.

    # Remove all nested anonymous functions from buffer
    $buf =~ s/function\s*?\(.*?\).*?\{{0}/anonymous/gm;    # Replace all anonymous functions with the generic key 'anonymous'.
    while($buf =~ /anonymous\s?\{/){                       # Find next occurrence of 'anonymous { '.
        my $tmp = $';
        $buf = $` . 'anonymous';
        $tmp =~ s/                                             # Erase the following token which begins after the l brace
            ([^\{\}])*?                                            # optional chars that are neither l nor r braces
            (\n ([^\{\}])*?)*?                                     # optional lines containing neither l nor r braces
            (                                                      # optional child
                \{                                                     # l brace
                (?0)                                                   # recursion
                ([^\}])*?                                              # optional chars that are not r braces
                (\n ([^\}])*?)*                                        # optional lines containing no r braces
            )*
            \}                                                     # r brace
        //x;                                               # Erase everything between matching and nested braces.
        $buf = $buf . $tmp;
    }
    write_file('/tmp/' . $_ . '.tmp', $buf);               # Write buffer to temp file

    mkdir($cwd . '/' . $uml_dir . '/' . $File::Find::dir); # Copy directory structure into output directory.

    print $File::Find::name, ": ";                         # Print filename

    # Call js2uml with temp file
    system($cwd . '/' . $exec_path . ' -s /tmp/' . $_ . '.tmp -o ' . $cwd . '/' . $uml_dir . '/' . $File::Find::name . '.png');

    #unlink('/tmp/' . $_ . '.tmp');                        # 7. Remove temp file.
}


# Print string containing vars by "${name}
# Precondition:
#     Variables are defined in %vars hash.
# Synopsis: 
#     #!/usr/bin/perl -w
#     use strict;
#     my %vars;
#     my $n = 10;
#     $vars{n}=$n;
#     puts('The value of n is ${n}').
# Output:
#     The value of n is 10.
sub puts{
    my $string = $_[0];
    my $token;

    while ($string =~ m/\$\{.*?\}/){                       # For each token.
        print($`);                                         # Print up to first token.
        $token = $&;                                       # Get token.
        $token =~ s/\$\{//;                                # Remove ${.
        $token =~ s/\}//;                                  # Remove }.
        print $vars{$token};                               # Print token by key.
        $string =~ s/^.*?\}//;                             # Update string.
    }
    print($string, "\n");
}


sub view{
    if($^O eq 'linux' && defined($browser_linux)) {            
        system($browser_linux . ' ' . $cwd . '/' . $uml_dir);  
    } elsif($^O eq 'MSWin32' && defined($browser_win10)) {
        system($browser_win10 . ' ' . $cwd . '/' . $uml_dir);
    } elsif($^O eq 'darwin' && defined($browser_macos)) {
        system($browser_macos . ' ' . $cwd . '/' . $uml_dir);
    } else {
        puts($browser_other_msg);
    }
}


sub makeLocalConfig{
    my %cfg_vars;

    mkdir($cwd . '/' . $uml_dir);                          # Create output directory if not already there.
    
    foreach my $file ($filename_local, $filename_global){  # for each file $_
        if (-e $file) {                                    # if config file exists
            open(my $fh, '<:encoding(UTF-8)', $file);      # open file
            print "✅ " . $file . "\n";
            while (my $row = <$fh>) {                      # for each row in file

                # get key
                chomp $row;                                # put line into row
                if(not($row =~ m/^\s*?\".*\"/)){           # if row does not fit "key"
                    next;                                  # skip line
                }
                $row =~ m/\s*?\".*?\"/;                    # look for key
                my $key = $&;                              # put match into key

                # get value
                my $temp = $';                             # put post into temp
                if(not($temp =~ m/\".*\"/g)){              # if temp does not fit "value"
                    next;                                  # skip line
                }
                $temp =~ m/\".*?\"/;                       # look for value
                my $value = $&;                            # put match into value

                # clean-up
                $key =~ s/^\s*//;                          # remove tab from key
                $key =~ s/\"//g;                           # remove quotes from key
                $value =~ s/\"//g;                         # remove quotes from value

                # user input
                print "❔\"" . $key . "\"\t\= \"" . $value . "\" [Y/n]? ";
                if(<STDIN> =~ /[nN]+/){                    # if user input is "no"
                    print '❔❔' . $key . " \= ";
                    $value = <STDIN>;                      # then get user input for value of key
                }
                $cfg_vars{$key} = $value;                  # put key=value into the hash

            }
            close $fh;                                     # close file
            last;                                          # do not move on to next file
        } else {
            warn "❌ " . $file . "\n";
        }
    }

    # check for missing keys in hash
    foreach ( @cfg_keys ) {                                # for each required config key $_
        if(not(exists($cfg_vars{$_}))){                    # if $_ does not exist in hash
            $cfg_vars{$_} = '';                            # fill empty key with blank value
        }
    }


    # create local config file
    if(not(-e $filename_local)){                           # if local config does not exist
        copy($filename_global,$filename_local) or die "$!";# copy from global config file
    }

    # write keys to local config from hash
    my $buf = read_file($filename_local);                  # read file into buffer
    foreach my $key (keys %cfg_vars ) {                    # for all keys in hash
        $buf =~ s/\"$key\": \".*?\"/"\"$key\": \"$cfg_vars{$key}\""/g;# overwrite line with key in buffer
    }
    write_file('/tmp/' . $_ . '.tmp', $buf);               # Write buffer to temp file
    print "✅ Config file saved at " . $filename_local . ".\n";
}