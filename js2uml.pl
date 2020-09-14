#!/usr/bin/perl -w

# UML browser target
my $browser_linux='x-www-browser';      #default
#my $browser_linux='firefox';
#my $browser_linux='chromium-browser';
my $browser_macos='open -a Safari';     #default
#my $browser_macos='open -a Firefox';
#my $browser_macos='open -a Vivaldi';
my $browser_win10='iexplore.exe';       #default
#my $browser_win10='c:/Windows/SystemApps/Microsoft.MicrosoftEdge_8wekyb3d8bbwe/MicrosoftEdge.exe';
#my $browser_win10='c:/Windows/Program Files/Mozilla Firefox/firefox.exe';
my $browser_other_msg='UML output was generated at ${cwd}/${uml_dir}.';


use strict;
use warnings;
use File::Find;
use File::Copy;
use File::Slurp;
use Config;
use Cwd;

my %vars;                                                  # Define global variable hash.

my $cwd = Cwd::cwd();                                      # Let current working directory be defined.
$vars{'cwd'} = $cwd;

my $num_args = $#ARGV + 1;                                 # Let number of args be defined by environment.
if ($num_args != 3) {
    print "\nUsage: js2uml.pl <js2uml executable> <source input directory> <uml output directory>\n";
}

my $exec_path=$ARGV[0];                                    # Let index.js executable path be argument 1.

my @js_dir;                                                # Let source file input directory be argument 2.
@js_dir[0]=$ARGV[1];

my $uml_dir=$ARGV[2];                                      # Let uml diagram output directory be argument 3.
$vars{'uml_dir'} = $uml_dir;

mkdir($cwd . '/' . $uml_dir);                              # Create output directory if not already there.

find(\&wanted, @js_dir);                                   # Find wanted files in input directory.

if($^O eq 'linux' && defined($browser_linux)) {            # Launch browser and exit.
    system($browser_linux . ' ' . $cwd . '/' . $uml_dir);  
} elsif($^O eq 'MSWin32' && defined($browser_win10)) {
    system($browser_win10 . ' ' . $cwd . '/' . $uml_dir);
} elsif($^O eq 'darwin' && defined($browser_macos)) {
    system($browser_macos . ' ' . $cwd . '/' . $uml_dir);
} else {
    puts($browser_other_msg);
}
exit;


# Walk all JavaScript source files recursively.
sub wanted {
    /^.*\.js\z/s && # dir, _, name
    doexec();

}


# Duct-tape for failed AST test cases:
# * export keywords -> one word, turns into nothing
# * import clauses -> no nesting, turns into nothing
# * nested anonymous functions -> turns into "anonymous"
#TODO: put this into a functional language.
sub doexec {

    #if($File::Find::name eq 'modules/actions/circularize.js') {#Debug
    #    exit;
    #}
    
    my $buf = read_file($cwd . '/' . $File::Find::name);   # Read file into buffer.

    $buf =~ s/^export \*.*;\n//gm;                         # Remove all export keywords from buffer.
    $buf =~ s/export //g;

    $buf =~ s/^import[^;]*(\n.*;{0})*(\n)*.*;//gm;         # Remove all import clauses from buffer.

    # Remove all nested anonymous functions from buffer
    $buf =~ s/function\s*?\(.*?\).*?\{{0}/anonymous/gm;    # Replace all anonymous functions with the generic key 'anonymous'.
    while($buf =~ /anonymous\s?\{.*/){                     # Find next occurrence of 'anonymous { '.
        my $tmp = $';
        $buf = $` . 'anonymous';
        $tmp =~ s/                                             # Erase the following token which begins after the l brace
            (\n ([^\{\}])*?)*?                                     # optional lines containing neither l nor r braces
            ([^\{\}])*?                                            # optional chars that are neither l nor r braces
            (                                                      # optional child
                \{                                                     # l brace
                (?0)                                                   # recursion
                (\n ([^\}])*?)*                                        # optional lines containing no r braces
                ([^\}])*?                                              # optional chars that are not r braces
            )*
            \}                                                     # r brace
        //x;                                                   # Erase everything between matching and nested braces.
        $buf = $buf . $tmp;
    }
    write_file('/tmp/' . $_ . '.tmp', $buf);               # Write buffer to temp file

    mkdir($cwd . '/' . $uml_dir . '/' . $File::Find::dir); # Copy directory structure into output directory.

    print $File::Find::name, ": ";                         # Print filename

    # Call js2uml with temp file
    system($cwd . '/' . $exec_path . ' -s /tmp/' . $_ . '.tmp -o ' . $cwd . '/' . $uml_dir . '/' . $File::Find::name . '.png');

    #unlink('/tmp/' . $_ . '.tmp');                         # 7. Remove temp file.
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
