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
use feature qw(switch);

## Definitions.
my $debug=0;                                               # enable debugging mode (0/1)
my $colwidth=30;                                           # terminal column size
my $num_cols=3;                                            # columns in file listing output

## Debug particular file
my $debug_startfile;
my $debug_stopfile;
my $kill=0; # 400
given(0){
    when(1) {
        $debug_startfile='modules/actions/reverse.js';
        $debug_stopfile='modules/actions/restrict_turn.js';
    }
    when(2) {
        $debug_startfile='modules/actions/straighten_nodes.js'; #eturn geoVecDot(a, b, o) / geoVecDot(b, b, o);
        $debug_stopfile='modules/actions/join.js'; #8
    }
    when(3) {
        $debug_startfile='modules/osm/relation.js'; #return !!(this.tags.type && this.tags.type.match(/^restriction:?/));
        $debug_stopfile='modules/osm/index.js'; # 269
    }
    when(4) {
        $debug_startfile='modules/ui/preset_icon.js'; #const l = d * 2/3;
        $debug_stopfile='modules/ui/form_fields.js'; #79
    }
    when(5) {
        $debug_startfile='modules/ui/fields/address.js';
        $debug_stopfile='modules/ui/fields/index.js';
    }
    when(6) {
        $debug_startfile='modules/core/file_fetcher.js'; # `{\n    ` and colons and commas
        $debug_stopfile='modules/core/preferences.js';
    }
}


my $output_extension = '.png';                             # file extension format for uml class diagrams
my $tmp_extension = '';
my $default = 'js2uml.js';                                 # combined output file
my %vars;                                                  # global variable hash.
my $cwd = Cwd::cwd(); $vars{'cwd'} = $cwd;                 # current working directory
my $browser_linux='x-www-browser';                         # default target on linux
my $browser_macos='open -a Safari';                        # default target on darwin
my $browser_win10='iexplore.exe';                          # default target on MSWin32
my @cfg_keys_prompted;
my @cfg_keys_prompted =                                    # keys for which user is to be prompted
    qw(                                
    combineFiles

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
my $debug_skip=0;
if(defined $debug and $debug){                             # start skipping when startfile defined
    if(defined $debug_startfile){
        $debug_skip=1;
    }
}

if(exists $vars{'combineFiles'} and                        # if we are combining files
    $vars{'combineFiles'} =~ /[^nN]|(false)/){
    unlink('/tmp/' . $default . $tmp_extension);                   # remove default file
    open($fh, '>>', '/tmp/' . $default . $tmp_extension)           # open default file for prepending
        or die "$!";
    find(\&wantedCombined, @js_dir);                       # find wanted files in input directory
    close $fh;
    system($cwd . '/' . $exec_path . ' -s /tmp/' . 
            $default . $tmp_extension . ' -o ' . $cwd . 
            '/' . $uml_dir . '/' . $default . 
            $output_extension);
    view($cwd . '/' . $uml_dir . '/' . $default .          # call browser target
        $output_extension);                               
    if(not($debug)){
        unlink('/tmp/' . $default . $tmp_extension);               # remove temp file
    }
} else {
    find(\&wantedSeparate, @js_dir);
    view($cwd . '/' . $uml_dir);                           # call browser target
}

rename($filename_global . '.old', $filename_global);       # restore global configuration

exit;



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

        #debug
        if($debug){                                        # if debugging
            if(defined $ debug_stopfile and                # if stopfile reached
                $File::Find::name eq $debug_stopfile){
                unlink($filename_local);                   # remove local configuration file
                rename($filename_global . '.old',          # restore global configuration file
                    $filename_global);
                die;                                       # die
            } elsif (defined $debug_startfile and          # otherwise if startfile reached
                $File::Find::name eq $debug_startfile){
                $debug_skip=0;                             # unset debug_skip
            } elsif ($debug_skip==1) {                     # otherwise if debug_skip set
                goto SKIP;                                 # just get the next filename
            }
        }

        my $tmp = getNext();
        File::Slurper::write_text('/tmp/' . $_ .           # write buffer to temp file
            $tmp_extension,
        $tmp);
        mkdir($cwd . '/' . $uml_dir . '/' .                # copy directory structure into output directory
        $File::Find::dir); 
        print color('yellow');
        print $File::Find::name, ": ";                     # print filename
        print color('reset');

        # Call js2uml with temp file
        system($cwd . '/' . $exec_path . ' -s /tmp/' . 
            $_ . $tmp_extension . ' -o ' . $cwd . '/' . 
            $uml_dir . '/' . $File::Find::name . 
            $output_extension);

        if(not($debug)){
            unlink('/tmp/' . $_ . $tmp_extension);         # remove temp file
        }

        SKIP:
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
                print color('yellow');
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



# Pre-processing for failed AST test cases:
# * export keywords -> one word, turns into nothing
# * import clauses -> no nesting, turns into nothing
# * nested anonymous functions -> turns into "anonymous"
# Parameters: none
# Preconditions:
#     * global scalar is defined: $cwd
#     * global scalar is defined: $File::Find::name
sub getNext {

    my $buf = File::Slurper::read_text($cwd . '/' .        # read file into buffer
        $File::Find::name);

    removeCommentsAndStrings($buf);                        # avoid regex collisions
    if(not $kill){
        removeExportsAndImports($buf);
        removeFunctions($buf);
        fixInvocations($buf);
        fixVariableDeclarations($buf);
    }

    return $buf;
}



# forward slash /ab\nc/ -> #fs
# paragraph /*a\nbc*/   -> deleted
# back quote `a\nbc`    -> #bq
# double quote "abc"    -> #dq
# forward quote 'abc'   -> #fq
# comment // ...  $     -> deleted

sub removeCommentsAndStrings {
# (?<=[\&\:\?\+\-\*\/\%\=\(\[\,]\n?\s{0,12})
    my $x = join '|', (                                     # forward-slashed comments preceded by
        '(?<=[\&\:\?\+\-\*\/\%\=\(\[\,])(?<![\d\w\]\)])',
        '(?<=[\&\:\?\+\-\*\/\%\=\(\[\,])(?<![\d\w\]\)]\s?)',
        '(?<=[\&\:\?\+\-\*\/\%\=\(\[\,]\n?)(?<![\d\w\]\)]\s?)',
        '(?<=[\&\:\?\+\-\*\/\%\=\(\[\,]\n?\s?)(?<![\d\w\]\)]\s?)',
        '(?<=[\&\:\?\+\-\*\/\%\=\(\[\,]\n?\s?\s?\s?\s?)(?<![\d\w\]\)]\s?)'
    );

    my @symbs = (""    , "#bq", "#dq", "#fq", ""    , "#fs"); # symbol to replace match
    my @heads = ("\/\*", "\`" , "\"" , "\'" , "\/\/", "\/"); # token to begin match
    my @tails = ("\*\/", "\`" , "\"" , "\'" , ""    , "\/"); # token to end match
    my @looka = (""    , ""   , ""   , ""   , ""    , $x); # lookahead expressions for match

    my @arr;
    for (my $i = 0; $i < scalar @symbs; $i++) {
        push @arr, "(" . getRegex ($_[0], 
            $symbs[$i], $heads[$i], 
            $tails[$i], $looka[$i]) . ")";
    }
    my $match = join "|", @arr;

    # symbolize
    while ($_[0] =~ m/$match/) {
        my $last = $&;
        
        my $i=0;
        my $x=escape($heads[$i]);
        while(not $last =~ m/^($x)/) {
            $x=escape($heads[++$i]);
        }
        #print $& . "\n";
             my $pre = $`;
             my $post = $';

        my $newlines = buildLines(countLines($&) - 1);
        
        $_[0] = $pre . $symbs[$i] . $newlines . $post;
    }


    # TODO: assign all matches to a randomized, 
    # unique id and put them all in a hash.
    # These scalars can be used to resolve constants
    # and literals within method or class variables.


    # restore quotes in string matches
    for (my $i = 0; $i < scalar @symbs; $i++) {
        if(hasField($symbs[$i])){
            $_[0] =~ s/$symbs[$i]/$heads[$i]$symbs[$i]$tails[$i]/g;
        }
    }
}



# returns false when a scalar string input is empty and true otherwise
sub hasField {

    return not $_[0] =~ m/^$/;
}



# build a regex based on the five parameters ($string, $symbol, $head, $tail, $lookahead)
sub getRegex {

    if(not $_[2] =~ m/^(\/\/)/) {                    # only certain characters are greedy
        my $x = escape($_[2]);
        my $y = escape($_[3]);
        my $z = "($_[4])$x(((\\\\.)|(.)|(\\n))*?)$y";
        return $z;
    } else {

        return "(" . $_[4] . ")" . escape($_[2]) . ".*" . escape($_[3]);
    }
}



# prepend a backslash to each character in the string
sub escape {

    my $x = $_[0];
    $x =~ s/./\\$&/g;
    return $x;
}



sub removeExportsAndImports {
    $_[0] =~ s/export default /export /g;                  # remove all `export default`
    whiteout($_[0], 'export \*(.|\n)*?;');                 # remove all `export *...;`
    whiteout($_[0], 'export {{{}}}(.|\n)*?;');             # remove all `export {}...;`
    $_[0] =~ s/export //g;                                 # remove all `export `
    #whiteout($_[0], 'import [^;]*(\n.*?;{0})*?(\n)*?.*;'); # remove all import ...;`
    whiteout($_[0], 'import (.|\n)*?;');                   # remove all `import ...;`
}



sub removeFunctions {

    # Repair incompatible function-syntax from 
    $_[0] =~ s/(?<=\=\s)function\s[\w]*?\s*?\(.*?\).*?\{{0}(?=\{)/anonymous/g; # almost-anonymous -> anonymous signature
    $_[0] =~ s/function\s*?\(.*?\).*?\{{0}/anonymous/g;    # anonymous signature -> `anonymous`
    whiteout($_[0], 'anonymous{{{}}}');                   # remove (recursively) all anonymous definitions

    # TO-DO: for almost-anonymous functions, put invocation after definition, retaining signature.
    # TO-DO: for anonymous functions, assign a random word for signatures, retaining definitions.
}



# Append `.fixme=null` to the end of method call chains from a "problematic" class.
# E.g.: Object.method() => Object.method().fixme=null;
# E.g.: Object.method().method(); => Object.method().method().fixme=null;
# Parameters:
#     * scalar input string `$_[0]`
#     * 
# Preconditions: none
# Returns: none
sub fixInvocations {

    my @classes =                              # identifiers for problematic classes
    qw(
        window
        Object
    );
    my $behind = join '|', @classes;
    my $append = '.fixme=null';

    $_[0] =~                                   # append to the following token
        s/
        (?!(\.keys\())
        (?<=($behind))
        (
        (\.\w{1,32}\s?\()
        ([^\(\)])*?                            (?# optional chars that are neither l nor r parens)
        (\n ([^\(\)])*?)*?                     (?# optional lines containing neither l nor r parens)
        (                                      (?# beginning of optional child)
            \(                                 (?# l paren)
            (?0)                               (?# recursion)
            ([^\)])*?                          (?# optional chars that are not r parens)
            (\n ([^\)])*?)*                    (?# optional lines containing no r parens)
        )*                                     (?# ending of nth child)
        \)                                     (?# r paren)
        )+
        (?!\.)
        (?#$append)
        /$&$append/xg;                         # append token
}



# First, convert all comma separated declarations into multiple declarations.
# Then, find all declarations and prepend each assignment with `var`.
sub fixVariableDeclarations {
    # declarations use the keywords 'var' or 'let'

    # Find assignments that occur 

    my @declarations = (
        '(?<!(for.{0,250}))',
        '(?<!(if.{0,250}))',
        '(?<!(then.{0,250}))',
        '(?<!(\=\>.{0,250}))',
        '(?<!(\.))',
        '(?<!(\,(\n?)\s{0,12}))',
        '(?<!([\w]))',
        '(?<!([^\w]var ))',
        '(?<!([^\w]let ))',
        '(?<!([^\w]const ))',
        '(?<!([^\w]return ))',
        '(?<!(var\s))',
        '(?<!(let\s))',
        '(?<!(const\s))',
        '(?<!(return\s))',
        '(?<!([\[]))',
        '(?<!(^var ))',
        '(?<!(^let ))',
        '(?<!(^const ))',
        '(?<!(^return ))',

    );
    my $looka = join '', @declarations;

    # assignments occur with exactly one equals sign
    my @assignments = (
        '(?=(\=\s))'
    );
    my $lookb = join '', @assignments;

    $_[0] =~ s/$looka\w+\s$lookb/let $&/g;
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



# Count number of newlines
sub countLines {

    my $count=0;
    if(not $_[0]) {
        return 0;
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

    my $newlines;

    # interpret arg2 as nested recursion `{{{}}}`
    if($_[1] =~ m/\{\{\{\}\}\}/) {                         # if `{{{}}}` found at end of string in arg2
        my $pre = $`;                                      # let prelude be defined before the `{{{}}}`
        my $post= $';                                      # let postlude be defined after the `{{{}}}`
        while($_[0] =~ m/$pre\s?\{/) {                     # match the next `token {`
            $_[0] = $` . $pre;                             # truncate buffer at this point
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
            $newlines = buildLines(countLines($&) - 1);    # build string of newlines
            #print $tmp;
            $tmp =~ s/^$post//;                            # remove postlude only if it occurs thereafter
            $_[0] = $_[0] . $ newlines . $tmp;             # append newlines and modifications to truncated buffer
        }

    # interpret arg2 as multi-line `\n`
    } elsif ($_[1] =~ m/\\n/m) {                           # otherwise if arg2 has newlines
        while($_[0] =~ s/$_[1]//) {                        # remove next match of arg2 in arg1
            $newlines = buildLines(countLines($&) - 1);    # build string of newlines
            $_[0] = $` . $newlines . $';                   # insert newlines at the end
        }

    # do not interpret arg2
    } else {
        $_[0] =~ s/$_[1]//g;                               # remove next match of arg2 in arg1
    }
}