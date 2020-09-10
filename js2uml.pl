#!/usr/bin/perl -w

# Firefox UML viewing instructions:
# 1. Set browser.tabs.remote.autostart=false in about:config
# 2. Restart anew or try URI about:restartrequired

# Safari UML viewing instructions:
# 1. Set Show Develop menu in menu bar under Advanced Preferences.
# 2. Unset Menu -> Develop -> Disable Local File Restrictions

# Configuration for executable target (UML browser for development):
my $browser_exec_path='x-www-browser';     # GNU/Linux (Default)
#my $browser_exec_path='firefox';           # GNU/Linux (Servo)
#my $browser_exec_path='chromium-browser';  # GNU/Linux (Blink)
#my $browser_exec_path='open -a Safari';    # Mac OS X (Safari)
#my $browser_exec_path='open -a Firefox';   # Mac OS X (Servo)
#my $browser_exec_path='iexplore.exe';      # Windows10 (IE)

#my $browser_exec_path='c:/Windows/SystemApps/Microsoft.MicrosoftEdge_8wekyb3d8bbwe/MicrosoftEdge.exe';
#my $browser_exec_path='c:/Windows/Program Files/Google Chrome/chrome.exe';
#my $browser_exec_path='c:/Windows/Program Files/Mozilla Firefox/firefox.exe';

#######################################################################################################################


use strict;
use warnings;
use File::Find;
use File::Copy;
use File::Slurp;
use Cwd;

my $cwd = Cwd::cwd();                                      # Let current working directory be defined.

my $num_args = $#ARGV + 1;                                 # Let number of args be defined by environment.
if ($num_args != 3) {
    print "\nUsage: js2uml.pl <js2uml executable> <source input directory> <uml output directory>\n";
}

my $exec_path=$ARGV[0];                                    # Let index.js executable path be argument 1.

my @js_dir;                                                # Let source file input directory be argument 2.
@js_dir[0]=$ARGV[1];

my $uml_dir=$ARGV[2];                                      # Let uml diagram output directory be argument 3.

mkdir($cwd . '/' . $uml_dir);                              # Create output directory if not already there.

find(\&wanted, @js_dir);                                   # Find wanted files in input directory.

system($browser_exec_path . ' ' . $cwd . '/' . $uml_dir);  # Launch browser and exit.
exit;


# Walk all JavaScript source files recursively.
sub wanted {
    /^.*\.js\z/s && # dir, _, name
    doexec();
}


# Duct-tape for failed AST test cases:
# * export keywords
# * import clauses
# * anonymous functions
sub doexec($@) {

	#if($File::Find::name eq 'modules/actions/circularize.js') {#Debug
	#	exit;
	#}
    
    my $buf = read_file($cwd . '/' . $File::Find::name);   # Read file into buffer.

    $buf =~ s/^export \*.*;\n//gm;                         # Remove all export keywords from buffer.
    $buf =~ s/export //g;

    $buf =~ s/^import[^;]*(\n.*;{0})*(\n)*.*;//gm;         # Remove all import clauses from buffer.

    # Remove all anonymous functions from buffer.
    $buf =~ s/\s*\=\s*function\(.*\)\s*\{\s*\n(^.*(\};){0}.*\n)*^.*\};/;/gm;
    $buf =~ s/function\s*(\n.*;{0})*(\n)*.*;/function anonymous();/gm;
    $buf =~ s/\(function anonymous\(/\(/gm;

    write_file('/tmp/' . $_ . '.tmp', $buf);               # Write to temp file from buffer.

    mkdir($cwd . '/' . $uml_dir . '/' . $File::Find::dir); # Copy directory structure into output directory.

    # Call js2uml with temp file
    system($cwd . '/' . $exec_path . ' -s /tmp/' . $_ . '.tmp -o ' . $cwd . '/' . $uml_dir . '/' . $File::Find::name . '.png');

    unlink('/tmp/' . $_ . '.tmp');                         # 7. Remove temp file

    #print $File::Find::name, "\n";                         # Debug: list files
}
