#!/usr/bin/perl -w
# Duct-tape for failed AST test cases.
# 1. Remove all export keywords
# 2. Remove all "import {}" clauses
# 3. Remove all anonymous functions

use strict;
use warnings;
use File::Find;
use File::Copy;
use File::Slurp;
use Cwd ();
my $cwd = Cwd::cwd();


# Let number of args be defined by environment.
my $num_args = $#ARGV + 1;
if ($num_args != 2) {
	print "\nUsage: js2uml.pl <source input directory> <uml output directory>\n";
}

# Let source file input directory be argument 1.
my @js_dir;
@js_dir[0]=$ARGV[0];

# Let uml diagram output directory be argument 2.
my $uml_dir=$ARGV[1];

find(\&wanted, @js_dir);
exit;


# Regex for walking javascript source files recursively
sub wanted {
    /^.*\.js\z/s && # dir, _, name
    doexec();
}


sub doexec($@) {
	chdir $cwd;
	# 0. Read file into buffer.
	#$File::Slurp::file_name=$File::Find::name;
	my $buf = read_file($File::Find::name);

	# 1. Remove all export keywords from buffer.
	$buf =~ s/export //g;

	# 2. Remove all import clauses from buffer.
	$buf =~ s/^import[^;]*(\n.*;{0})*(\n)*.*;//gm;

	# 3. Remove all anonymous functions from buffer.
	#TODO

	# 4. Write to temp file from buffer
	write_file('/tmp/' . $_ . '.tmp', $buf);

	# 5. Copy directory structure into output directory
	mkdir($uml_dir . '/' . $File::Find::dir);

	# 6. Call js2uml with temp file
	chdir $cwd;
	system('bin/index.js -s /tmp/' . $_ . '.tmp -o ' . $uml_dir . '/' . $File::Find::name . '.png');

	# 7. Remove temp file
	unlink('/tmp/' . $_ . '.tmp');

	# Debug
	#print $File::Find::name, "\n";
}
