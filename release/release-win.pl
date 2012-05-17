#!/usr/bin/perl

# Release script for Windows Executables.  Note that this is run
# after release-unix.pl, which will create the needed tag directories
# and update the version variables accordingly.  This assumes that you
# have been building TSK with libewf on your system in one of the trunk
# or branch directories and it will copy libewf from there. 
#
#
# This requires Cygwin with:
# - git 
# - zip
#
# It has been used with Visual Studio 9.0 Express.  It may work with other
# versions.
#
# THIS IS NOT FULLY TESTED WITH GIT YET

use strict;

my $TESTING = 1;
print "TESTING MODE (no commits)\n" if ($TESTING);


# Function to execute a command and send output to pipe
# returns handle
# exec_pipe(HANDLE, CMD);
sub exec_pipe {
    my $handle = shift(@_);
    my $cmd    = shift(@_);

    die "Can't open pipe for exec_pipe"
      unless defined(my $pid = open($handle, '-|'));

    if ($pid) {
        return $handle;
    }
    else {
        $| = 1;
        exec("$cmd") or die "Can't exec program: $!";
    }
}



# Read a line of text from an open exec_pipe handle
sub read_pipe_line {
    my $handle = shift(@_);
    my $out;

    for (my $i = 0; $i < 100; $i++) {
        $out = <$handle>;
        return $out if (defined $out);
    }
    return $out;
}




unless (@ARGV == 1) {
	print stderr "Missing arguments: tag_version\n";
	print stderr "    for example: release-win.pl sleuthkit-3.1.0\n";
	die "stopping";
}


my $RELDIR = `pwd`;	# The release directory
chomp $RELDIR;
my $SVNDIR = "$RELDIR/../";
my $TAGNAME = $ARGV[0];
my $TSKDIR = "${SVNDIR}";


my $BUILD_LOC = `which vcbuild`;
chomp $BUILD_LOC;
die "Unsupported build system.  Verify redist location" 
    unless ($BUILD_LOC =~ /Visual Studio 9\.0/);

my $REDIST_LOC = $BUILD_LOC . "/../../redist/x86/Microsoft.VC90.CRT";
die "Missing redist dir $REDIST_LOC" unless (-d "$REDIST_LOC");


#######################
# Build the execs

# Make sure we have no changes in the current tree
exec_pipe(*OUT, "git status -s | grep \"^ M\"");
my $foo = read_pipe_line(*OUT);
if ($foo ne "") {
    print "Changes stil exist in current repository -- commit them\n";
    # @@@ die "stopping";
}

# Make sure src dir is up to date
print "Updating source directory\n";
chdir ("$TSKDIR") or die "Error changing to TSK dir $TSKDIR";
# @@@ `git pull`;

# Verify the tag exists
exec_pipe(*OUT, "git tag | grep \"${TAGNAME}\"");
my $foo = read_pipe_line(*OUT);
if ($foo eq "") {
    print "Tag ${TAGNAME} doesn't exist\n";
    die "stopping";
}
close(OUT);

# @@@ `git checkout -q ${TAGNAME}`;

# Parse the config file to get the version number
open (IN, "<configure.ac") or die "error opening configure.ac to get version";
my $VER = "";
while (<IN>) {
	if (/^AC_INIT\(sleuthkit, ([\d\w\.]+)\)/) {
		$VER = $1;
		last;
	}
}
die "Error finding version in configure.ac" if ($VER eq "");
print "Version found in configure.ac: $VER\n";
die "tag name and configure.ac have different versions ($TAGNAME vs $VER)" 
	if ("sleuthkit-".$VER != $TAGNAME);


# Verify LIBEWF is built
die "LIBEWF missing" unless (-d "$ENV{'LIBEWF_HOME'}");
die "libewf dll missing" 
	unless (-e "$ENV{'LIBEWF_HOME'}/msvscpp/release/libewf.dll" ); 


sub build_core {
	print "Building TSK source\n";
	chdir "win32" or die "error changing directory into win32";
	# Get rid of everything in the release dir (since we'll be doing * copy)
	`rm -f release/*`;
	`rm BuildErrors.txt`;
	`vcbuild /errfile:BuildErrors.txt tsk-win.sln "Release|Win32"`; 
	die "Build errors -- check win32/BuildErrors.txt" if (-s "BuildErrors.txt");

	# Do a basic check on some of the executables
	die "mmls missing" unless (-x "release/mmls.exe");
	die "fls missing" unless (-x "release/fls.exe");
	die "hfind missing" unless (-x "release/hfind.exe");
	chdir "..";
}


#######################
# Package the execs

# Runs in root sleuthkit dir
sub package_core {
	# Verify that the directory does not already exist
	my $rfile = "sleuthkit-win32-${VER}";
	my $rdir = $RELDIR . "/" . $rfile;
	die "Release directory already exists: $rdir" if (-d "$rdir");

	# We already checked that it didn't exist
	print "Creating file in ${rdir}\n";

	mkdir ("$rdir") or die "error making release directory: $rdir";
	mkdir ("${rdir}/bin") or die "error making bin release directory: $rdir";
	mkdir ("${rdir}/lib") or die "error making lib release directory: $rdir";
	mkdir ("${rdir}/licenses") or die "error making licenses release directory: $rdir";


	`cp win32/release/*.exe \"${rdir}/bin\"`;
	`cp win32/release/*.dll \"${rdir}/bin\"`;
	`cp win32/release/*.lib \"${rdir}/lib\"`;

	# basic cleanup
	`rm \"${rdir}/bin/callback-sample.exe\"`;
	`rm \"${rdir}/bin/posix-sample.exe\"`;


	# mactime
	`echo 'my \$VER=\"$VER\";' > \"${rdir}/bin/mactime.pl\"`;
	`cat tools/timeline/mactime.base >> \"${rdir}/bin/mactime.pl\"`;


	# Copy standard files
	`cp README.txt \"${rdir}\"`;
	`unix2dos \"${rdir}/README.txt\"`;
	`cp win32/docs/README-win32.txt \"${rdir}\"`;
	`cp NEWS.txt \"${rdir}\"`;
	`unix2dos \"${rdir}/NEWS.txt\"`;
	`cp licenses/cpl1.0.txt \"${rdir}/licenses\"`;
	`unix2dos \"${rdir}/licenses/cpl1.0.txt\"`;
	`cp licenses/IBM-LICENSE \"${rdir}/licenses\"`;
	`unix2dos \"${rdir}/licenses/IBM-LICENSE\"`;

	# MS Redist dlls and manifest
	`cp \"${REDIST_LOC}\"/* \"${rdir}/bin\"`;
	print "******* Using Updated Manifest File *******\n";
	`cp \"${RELDIR}/Microsoft.VC90.CRT.manifest\" \"${rdir}/bin\"`;

	# Zip up the files - move there to make the path in the zip short
	chdir ("$RELDIR") or die "Error changing directories to $RELDIR";
	`zip -r ${rfile}.zip ${rfile}`;

	die "ZIP file not created" unless (-e "${rfile}.zip");

	print "File saved as ${rfile}.zip\n";
}


##############################

# Starts and ends in root sleuthkit dir
sub build_framework {
	print "Building TSK framework\n";

	chdir "framework/win32/framework" or die "error changing directory into framework/win32";
	# Get rid of everything in the release dir (since we'll be doing * copy)
	# @@@ `rm -f release/*`;
	`rm BuildErrors.txt`;
	`vcbuild /errfile:BuildErrors.txt framework.sln "Release|Win32"`; 
	# @@@ die "Build errors -- check framework/win32/framework/BuildErrors.txt" if (-e "BuildErrors.txt" && -s "BuildErrors.txt");

	# Do a basic check on some of the executables
	die "libtskframework.dll missing" unless (-x "Release/libtskframework.dll");
	die "tsk_analyzeimg missing" unless (-x "Release/tsk_analyzeimg.exe");
	die "HashCalcModule.dll missing" unless (-x "Release/HashCalcModule.dll");

	chdir "../../..";
}

sub package_framework {
	# Verify that the directory does not already exist
	my $rfile = "sleuthkit-framework-win32-${VER}";
	my $rdir = $RELDIR . "/" . $rfile;
	die "Release directory already exists: $rdir" if (-d "$rdir");

	# We already checked that it didn't exist
	print "Creating file in ${rdir}\n";

	mkdir ("$rdir") or die "error making release directory: $rdir";
	mkdir ("${rdir}/bin") or die "error making bin release directory: $rdir";
	mkdir ("${rdir}/modules") or die "error making module release directory: $rdir";
	mkdir ("${rdir}/config") or die "error making config release directory: $rdir";
	mkdir ("${rdir}/licenses") or die "error making licenses release directory: $rdir";

	chdir "framework" or die "error changing directory into framework";

	`cp win32/framework/release/*.exe \"${rdir}/bin\"`;
	`cp win32/framework/release/*.dll \"${rdir}/bin\"`;


	# Copy standard files
	`cp README.txt \"${rdir}\"`;
	`unix2dos \"${rdir}/README.txt\"`;
	`cp ../licenses/cpl1.0.txt \"${rdir}/licenses\"`;
	`unix2dos \"${rdir}/licenses/cpl1.0.txt\"`;
	`cp ../licenses/IBM-LICENSE \"${rdir}/licenses\"`;
	`unix2dos \"${rdir}/licenses/IBM-LICENSE\"`;

	# MS Redist dlls and manifest
	`cp \"${REDIST_LOC}\"/* \"${rdir}/bin\"`;
	print "******* Using Updated Manifest File *******\n";
	`cp \"${RELDIR}/Microsoft.VC90.CRT.manifest\" \"${rdir}/bin\"`;

	# Zip up the files - move there to make the path in the zip short
	chdir ("$RELDIR") or die "Error changing directories to $RELDIR";
	`zip -r ${rfile}.zip ${rfile}`;

	die "ZIP file not created" unless (-e "${rfile}.zip");

	print "File saved as ${rfile}.zip\n";
}

#build_core();
#package_core();
build_framework();
package_framework();
