#!/usr/bin/perl -w
# Load configs from lib/config.js.
# Preprocess files in directory given by second argument.
# Output UML class diagram(s) in format given by third argument.


use strict;
use warnings;
use File::Find;
use File::Copy;
use File::Slurper;
use Config;
use Cwd;
use utf8;
use Encode;
use open ':std', ':encoding(UTF-8)';
use Term::ANSIColor;


## Definitions.
my $debug=1;
my $colwidth=30;                                           # terminal column size
my $num_cols=3;
my $debug_stopfile='modules/index.js';
my $output_extension = '.png';                             # file extension format for uml class diagrams
my $default = 'js2uml.js';                                 # combined output file
my %vars;                                                  # global variable hash.
my $cwd = Cwd::cwd(); $vars{'cwd'} = $cwd;                 # current working directory
my $browser_linux='x-www-browser';                         # default target on linux
my $browser_macos='open -a Safari';                        # default target on darwin
my $browser_win10='iexplore.exe';                          # default target on MSWin32
my @cfg_keys_prompted =                                    # keys for which user is to be prompted
    qw(                                
    combineFiles
    title 
    header 
    hasLicense 
    copyleft 
    author 
    timestamp 
);


## Environment variables.
if ($#ARGV != 2) {                                         # if num args is not 3
    print ":(\njs2uml.pl .../index.js .../src/ .../uml/\n" # print usage
    and die;                                               # die
}
my $exec_path=$ARGV[0];                                    # index.js executable path is in argument 1
my @js_dir; $vars{'sourceFile'}=@js_dir[0]=$ARGV[1];       # source file input directory is in argument 2
my $uml_dir=$vars{'output'}=$vars{'uml_dir'}=$ARGV[2];     # uml diagram output directory is in argument 3


# Configuration files.
my $filename_local = $cwd . '/' . $uml_dir . '/' .         # local configuration file
    "localconfig.js";
my $filename_global = $cwd . '/' . $exec_path;             # global configuration file
$filename_global =~ s/\/index.js//;                        # remove trailing `/index.js`
$filename_global = $filename_global . "/../lib/" .         # append `/../lib/config.js`
    "config.js";

makeLocalConfig();                                         # modify config if not already there
rename($filename_global, $filename_global . '.old')        # try to make a backup of global config file
    or die "$!";
copy($filename_local, $filename_global) or die "$!";       # load the local configuration file

my $fh;
my $i=0;
my $lastDir=$cwd;
my $newlineCount=0;
if(exists $vars{'combineFiles'} and                        # if we are combining files
    $vars{'combineFiles'} =~ /[^nN]|(false)/){
    unlink('/tmp/' . $default . '.tmp');                   # remove default file
    open($fh, '>>', '/tmp/' . $default . '.tmp')           # open default file for prepending
        or die "$!";
    find(\&wantedCombined, @js_dir);                       # find wanted files in input directory
    close $fh;
    system($cwd . '/' . $exec_path . ' -s /tmp/' . 
            $default . '.tmp -o ' . $cwd . '/' . $uml_dir .
             '/' . $default . $output_extension);
    view($cwd . '/' . $uml_dir . '/' . $default .          # call browser target
        $output_extension);                               
    if(not($debug)){
        unlink('/tmp/' . $default . '.tmp');               # remove temp file
    }
} else {
    find(\&wantedSeparate, @js_dir);
    view($cwd . '/' . $uml_dir);                           # call browser target
}

rename($filename_global . '.old', $filename_global);       # restore global configuration

exit;


# Walk all JavaScript source files recursively and append contents to output directory tree
# Parameters: none
# Preconditions:
#     * global scalar is defined: $_
#     * global scalar is defined: $cwd
#     * global scalar is defined: $uml_dir
#     * global scalar is defined: $File::Find:dir
#     * global scalar is defined: $File::Find::name
#     * global scalar is defined: $exec_path
#     * global scalar is defined: $output_extension
sub wantedSeparate {
    if(/^.*\.js\z/s){
        my $tmp = getNext();
        File::Slurper::write_text('/tmp/' . $_ . '.tmp',   # write buffer to temp file
        $tmp);
        mkdir($cwd . '/' . $uml_dir . '/' .                # copy directory structure into output directory
        $File::Find::dir); 

        print $File::Find::name, ": ";                     # print filename

        # Call js2uml with temp file
        system($cwd . '/' . $exec_path . ' -s /tmp/' . $_ .
            '.tmp -o ' . $cwd . '/' . $uml_dir . '/' . 
            $File::Find::name . $output_extension);

        if(not($debug)){
            unlink('/tmp/' . $_ . '.tmp');                     # remove temp file
        }
    }
}


# Walk all JavaScript source files recursively and append contents to global file handle $fh
# Parameters: none
# Preconditions:
#     * global scalar is defined: $fh
sub wantedCombined {
    my $tmp;
    if(/^.*\.js\z/s){
        $tmp = getNext();
        say $fh $tmp;
    }

    if($debug){

        # print file and beginning line number in combined file
        if ($File::Find::dir ne $lastDir){
            if($lastDir and not $lastDir =~ m/$File::Find::dir/){
                print color('bold green');
                printf "\n\n\.\/%s:\n", $lastDir=$File::Find::dir;
                print color('reset');
                $i=0;
            } else {
                $lastDir=$File::Find::dir;
                #printf "\n\n\.\/%s:\n", $lastDir=$File::Find::dir;
            }
        } elsif (++$i % $num_cols == 0){
            printf "\n";
        }
        if($_ =~/^.*\.js\z/s){
            printf "%-d\t%-${colwidth}s", $newlineCount, $_;
        }

        #count newlines in tmp
        $newlineCount += countLines($tmp);
    }

}


# Count number of newlines
sub countLines {
    my $count=0;
    if(not $_[0]) {
        $_[0]= " ";
    }
    my @strings = split /\n/, $_[0];
    foreach my $str (@strings) {
        $count++;
    }
    return $count;
}


# Build string with n newlines
sub buildLines {
    my $string = "";
    for (my $i=$_[0]; $i > 0; $i--) {
        $string = $string . "\n";
    }
    return $string;
}


# Substitute globally with newlines preserved
# Replaces multi-line match with number of newlines in match
# Parameters:
#     * scalar string
#     * scalar match token (recursion is supported with `{}` at the end of the string)
sub whiteout{
    if($_[1] =~ m/\s?\{\}$/){                              # if `{}` found at end of string in arg2, interpret this as nested recursion
        my $token = $`;                                    # let new token be defined without `{}`
        while($_[0] =~ /$token\s?\{/){                     # match the next `token {`
            $_[0] = $` . $token;                           # truncate buffer at this point
            my $tmp = $';                                  # let tmp be what follows this
            $tmp =~                                        # remove the following nested token from tmp:
                s/                                         # let token begin after the l brace
                ([^\{\}])*?                                # optional chars that are neither l nor r braces
                (\n ([^\{\}])*?)*?                         # optional lines containing neither l nor r braces
                (                                          # optional child
                    \{                                     # l brace
                    (?0)                                   # recursion
                    ([^\}])*?                              # optional chars that are not r braces
                    (\n ([^\}])*?)*                        # optional lines containing no r braces
                )*
                \}                                         # r brace
            //x;
            $_[0] = $_[0] . $tmp;                          # append tmp to modified buffer
            my $newlines = buildLines(countLines($&));     # build string of newlines
            $_[0] =~ m/\n/m;
            $_[0] = $` . $newlines . $'; # insert newlines at the end
        }
    } else {                                               # otherwise perform replacement without further interpretation of arg2
        while($_[0] =~ s/$_[1]//m){                        # remove next match
            my $newlines = buildLines(countLines($&));     # build string of newlines
            $_[0] =~ m/\n/;
            $_[0] = $` . $newlines . $'; # insert newlines at the end
        }
    }
}


# Pre-processing for failed AST test cases:
# * export keywords -> one word, turns into nothing
# * import clauses -> no nesting, turns into nothing
# * nested anonymous functions -> turns into "anonymous"
# Parameters: none
# Preconditions:
#     * global scalar is defined: $cwd
#     * global scalar is defined: $File::Find::name
sub getNext {
    # debug
    # if(defined $debug and $debug){
    #     if($File::Find::name eq $debug_stopfile){
    #         unlink($filename_local);                     # remove local configuration file
    #         rename($filename_global . '.old',            # restore global configuration file
    #             $filename_global);
    #         die;
    #     }
    # }

    my $buf = File::Slurper::read_text($cwd . '/' .        # read file into buffer
     $File::Find::name);

    # eliminate regex collisions with JavaScript
    whiteout($buf,'\/\*.*?(\*\/){0}(\n.*?(\*\/){0})*\*\/');# remove all multi-line comments
    $buf =~ s/\/\/.*//g;                                   # remove all single-line comments
    $buf =~ s/\\\'/aYWikFnOZh/g;                           # hide all escaped single-quotes
    $buf =~ s/\'[^\']*(\n[^\']*)*.*?\'/\'mvNjNvTEKM\'/g;   # hide all single-quoted string contents
    $buf =~ s/\\\{/1wxPmKesLi/g;                           # hide all escaped l braces
    $buf =~ s/\\\}/A15I5oDTq7/g;                           # hide all escaped r braces

    $buf =~ s/export.*?;//g;                               # remove all `export *...;` from buffer
    $buf =~ s/export //g;                                  # remove all export keywords from buffer

    whiteout($buf,'^import[^;]*(\n.*;{0})*(\n)*.*;');      # remove all import clauses from buffer

    $buf =~ s/^\{.*?\}.*?from.*?;//g;                      # remove all `{...} from ...;`

    # Remove all nested anonymous functions from buffer
    $buf =~ s/function\s*?\(.*?\).*?\{{0}/anonymous/g;     # substitute `function (...)` with `anonymous`
    whiteout($buf,'anonymous {}');                         # remove all `anonymous {}`
    return $buf;

    # TO-DO: restore all regex substitutions from hash, especially each single-quoted string
}


# Print string containing vars by "${name}". 
# Parameters:
#     * string with references (e.g. ${x}) to variables that are to be printed
# Preconditions:
#     * global hash is defined: %vars
#     * any reference scalars in the scalar string parameter are defined in %vars
sub puts{
    my $string = $_[0];
    my $token;

    while ($string =~ m/\$\{.*?\}/){                       # for each token
        print($`);                                         # print up to first token
        $token = $&;                                       # get token
        $token =~ s/\$\{//;                                # remove ${
        $token =~ s/\}//;                                  # remove }
        print $vars{$token};                               # print token by key
        $string =~ s/^.*?\}//;                             # update string
    }
    print($string, "\n");
}


# Call the uml browser target.
# Parameters:
#     * scalar string: file or folder to open in browser
# Preconditions:
#     * global scalar is defined: $browser_linux 
#     * global scalar is defined: $browser_macos 
#     * global scalar is defined: $browser_win10
#     * global hash is defined: %vars
#     * global scalar is defined: $vars{'browserOtherMsg'}
sub view{
    if($debug){
        return;
    }
    if($^O eq 'linux' && defined($browser_linux)) {            
        system($browser_linux . ' ' . $_[0]);  
    } elsif($^O eq 'MSWin32' && defined($browser_win10)) {
        system($browser_win10 . ' ' . $_[0]);
    } elsif($^O eq 'darwin' && defined($browser_macos)) {
        system($browser_macos . ' ' . $_[0]);
    } else {
        puts($vars{'browserOtherMsg'});
    }
}


# Load configs from lib/config.js into the %vars hash.
# Parameters: none
# Preconditions:
#     * global scalar is defined: $cwd
#     * global scalar is defined: $uml_dir
#     * global scalar is defined: $filename_global
#     * global scalar is defined: $filename_local
#     * global hash is defined: %vars
#     * global array is defined: @cfg_keys_prompted
sub makeLocalConfig{
    mkdir($cwd . '/' . $uml_dir);                          # create output directory if not already there
    
    if (-e $filename_global . '.old'){                     # check if there is a restore file
        rename($filename_global . '.old',                  # restore global configuration
            $filename_global);
    }

    foreach my $file ($filename_local, $filename_global){  # for each file $_
        if (-e $file) {                                    # if config file exists
            open(my $fh, '<:encoding(UTF-8)', $file);      # open file
            print "✅ " . $file . "\n";
            while (my $buf = <$fh>) {                      # for each line `buf` in file
                chomp $buf;                                # put entire line into buf

                # get key
                my $key;
                if($buf =~ m/^\s*?\".*?\"/) {              # if matching `"key"` found
                    $key = $&;                             # put match into key
                    $buf = $';                             # put remainder into buf
                    $key =~ s/^\s*//;                      # remove leading spaces from key
                    $key =~ s/\"//g;                       # remove quotes from key
                } else {
                    next;                                  # otherwise skip line
                }

                # check if key is overridden
                if(exists($vars{$key})){                   # if key is overridden
                    next;                                  # skip line
                }

                # get value
                my $value;
                if($buf =~ m/\".*?\"/) {                   # if matching `"value"` found
                    $value = $&;                           # put match into value
                    $buf = $';                             # put remainder into buf
                    $value =~ s/\"//g;                     # remove quotes from value
                } else {
                    next;                                  # otherwise skip line
                }                             

                # get value's Boolean value
                my $bool;
                if(defined $value and
                    $value =~ m/[^nN]|(false)/){
                    $bool = 1;                             # put truth value of value in bool
                }
               
                # get comment
                my $comment;
                if($buf =~ m/\/\/\s?.*/) {                 # if matching `// comment` found
                    $comment = $&;                         # put match into comment
                    $comment =~ s/^\/\///;                 # remove leading // from comment

                    # get word
                    my $word;
                    while($buf =~ m/\?\([^\)]*\)\!/) {        # while matching ` ?(L:R)! ` found
                        
                        $word = $&;                        # put match into word
                        $buf = $';                         # put remainder into buf
                        if($bool) {                        # if bool is true
                            $word =~ s/\?\(//;             # remove leading `?(` from word
                            $word =~ s/\:.*?\)\!//;        # remove trailing `:R)! ` from word
                        }
                        else {
                            $word =~ s/\?\(.*?\://;        # remove leading `?(L:` from word
                            $word =~ s/\)\!//;             # remove trailing `)! ` from word
                        }
                        
                        if($word eq ""){                   # if word is empty string
                            $comment =~                    # replace ` ?(L:R)! ` with space
                            s/\s?\?\(.*\)\!\s?/ /;
                        } else {
                            $comment =~                    # replace `?(L:R)!` with word
                            s/\?\(.*?\)\!/$word/;
                        }
                    }
                } else {
                    $comment = $vars{'comment'};           # replace with the generic string
                }

                # user input
                if(grep(/^$key$/,@cfg_keys_prompted)) {    # if key is required
                    printf '❔%-12s = %-12s %s [Y/n]? ', 
                    $key, $value, $comment;                # ask user if value is OK
                    if(<STDIN> =~ /[nN]+/) {               # if user input is "no"
                        print '❔❔' . $key . " \= ";
                        $value = <STDIN>;                  # then get user input for value of key
                        $value =~ s/\n//;                  # remove newlines from value
                    }
                }

                # insert k=v into hash
                $vars{$key} = $value;                      # put key=value into the hash
            }
            close $fh;                                     # close file
            last;                                          # do not move on to next file
        } else {
            warn "❌ " . $file . "\n";                      # warn if config can't be opened
        }
    }

    # check for missing keys in hash
    foreach ( @cfg_keys_prompted ) {                       # for each required config key $_
        if(not(exists($vars{$_}))){                        # if $_ does not exist in hash
            $vars{$_} = '';                                # fill empty key with blank value
        }
    }

    # create local config file
    if(not(-e $filename_local)){                           # if local config does not exist
        copy($filename_global,                             # copy from global config file
            $filename_local) or die "$!";
    }

    # write keys to local config from hash
    my $buf = File::Slurper::read_text($filename_local);   # read file into buffer
    foreach my $key (keys %vars ) {                        # for all keys in hash
        $buf =~                                            # overwrite line with key in buffer
        s/\"$key\": \".*?\"/\"$key\": \"$vars{$key}\"/g;
    }
    File::Slurper::write_text($filename_local, $buf);      # write buffer to temp file
    print $vars{'notification'} . $filename_local . ".\n";
}
