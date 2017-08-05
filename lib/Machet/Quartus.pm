#!/usr/bin/perl -w
#
# File       : fpga_quartus.pl
# Author     : wangxf
# Company    : CPUxOS
# Description: Quartus II project
# Revisions  :
#
# Date        Author           Description
# 2017-07-24  wangxf           Created
#
#
#
package Machet::Quartus;


use Carp;
use Class::Ref;

use strict;
use vars qw($VERSION $Debug);


######################################################################
#### Configuration Section

$VERSION = '3.426';


#######################################################################
#######################################################################
#######################################################################

sub new {
    @_ >= 1 or croak 'usage: Machet::Quartus->new ({options})';
	my ($class, $ARGS) = (@_);

	my $self = bless {}, $class;
	
	my $obj = Class::Ref->new($ARGS);
	
	$self->{REF} = $obj;

	return ($self);
}


#######################################################################
#

sub run {
	my $self = shift;

	print "start run...\n";

	# config
 	print $self->{REF}->{'base'}{'mode'} . "\n";
	print $self->{REF}->{'base'}{'name'} . "\n";

	# opt
	print $self->{REF}->verbose . "\n";
	print $self->{REF}->clean . "\n";
	print $self->{REF}->dry . "\n";
	print $self->{REF}->tool_override . "\n";


	exit(0);
	
	# Variable from MAIN
  	my $VERBOSE              = $MAIN::VERBOSE;
  	my $DRY                  = $MAIN::DRY;
  	my $SYN                  = $MAIN::SYN;
  	my $PAR                  = $MAIN::PAR;
  	my $TIMING               = $MAIN::TIMING;

  	my $CALLDIR              = $MAIN::CALLDIR;
  	my $PROJECTBASE          = $MAIN::PROJECTBASE;
  	my @IMP_NAME             = @MAIN::IMP_NAME;
  	my @INCLUDE_PATHS        = @MAIN::INCLUDE_PATHS;
  	my @VERILOG_DEFINES      = @MAIN::VERILOG_DEFINES;
  	my @TOPLEVEL             = @MAIN::TOPLEVEL;
  	my @FPGAPART             = @MAIN::FPGAPART;

  	my @SOURCEFILE_LIST      = @MAIN::SOURCEFILE_LIST;

  	my @CONSTRAINT_FILES     = @MAIN::ALT_CONSTRAINT_FILES;
  	my @SDC_FILES            = @MAIN::ALT_SDC_FILES; 


  	# Local variables
  	my $TCL_FILE = '';            # TCL file for project generation
  	my $PROJGEN_COMMAND = '';     # Quartus command to create project
  	my $MAP_COMMAND = '';         # Command to start QUARTUS_MAP
  	my $FIT_COMMAND = '';         # Command to start QUARTUS_FIT
  	my $ASM_COMMAND = '';         # Command to start QUARTUS_ASM
  	my $STA_COMMAND = '';         # Command to start QUARTUS_STA

  	my $fileloc;                  # Location of file
  	my $tclFileLoc;               # Location of TCL file for project creation
  	my $line;                     # Single line
  	my $ret = 1;                  # Return value


  	# Create quartus directory if not present
  	unless (-d convPath($CALLDIR."/quartus")) {
    	systemCall("mkdir quartus");
  	}



	# ----------------------------------------------------------------------------
  	#Build Quartus II project TCL file
  	print "-----------------------------------------------------------------------------\n";
  	print " Building TCL script for project file generation                             \n";
  	print "-----------------------------------------------------------------------------\n";

  	# Load packages
  	$TCL_FILE = "load_package flow\n\n";

  	# Create project
  	$TCL_FILE .= "project_new ".$IMP_NAME[0]." -overwrite\n\n";

  	# Set toplevel
  	$TCL_FILE .= "set_global_assignment -name TOP_LEVEL_ENTITY ".$TOPLEVEL[0]."\n\n";

  	# Set FPGA part
  	$TCL_FILE .= "set_global_assignment -name DEVICE ".$FPGAPART[0]."\n\n";

  	# Includes
  	foreach (@INCLUDE_PATHS) {
    	$TCL_FILE .= 'set_global_assignment -name SEARCH_PATH "'.$_.'"'."\n\n";
  	}

  	$TCL_FILE .= "\n";

  	# Check file type of all source files in list. Remove every file from
  	# beginning of list, check if file type is supported, add entry to TCL
  	# file and put file back to end of source file list. Not supported file
  	# types are removed from list
  	foreach (1..@SOURCEFILE_LIST) {
    	# Remove first entry from source file list
    	$line = shift(@SOURCEFILE_LIST);

    	# Verilog
    	if ($line =~ m/\.v$/i) {
      		push(@SOURCEFILE_LIST, $line);
      		$line = 'set_global_assignment -name VERILOG_FILE "'.$line.'"'."\n";
      		$TCL_FILE .= $line;
    	}
    	# VHDL
    	elsif ($line =~ m/\.vhd$/i) {
      		push(@SOURCEFILE_LIST, $line);
      		$line = 'set_global_assignment -name VHDL_FILE "'.$line.'"'."\n";
      		$TCL_FILE .= $line;
    	}
      	# Something
    	else {
      		printf ("Warning: \"%s\" is unsupported file type\n", convPath($line));
    	}
  	}
  	$TCL_FILE .= "\n\n";

  	# Constraints
  	foreach (1..@CONSTRAINT_FILES) {
    	# Take first entry and check if file exists
    	$line = shift(@CONSTRAINT_FILES);
    	# Expand to absolute path
    	$fileloc = expandToAbsolutePath($line);
    	# Check if file exists
    	if (-f $fileloc) {
      		push(@CONSTRAINT_FILES, $fileloc);
    	}
    	else {
      		printf ("Warning: \"%s\" does not exist\n", convPath($fileloc));
    	}
  	}

  	# Report
  	if ($VERBOSE == 1) {
    	print "  Constraint files read:\n";
    	foreach (@CONSTRAINT_FILES) {
      		printf ("    %s\n", convPath($_));
    	}
  	}

  	# Append constraints to TCL file
  	foreach $fileloc (@CONSTRAINT_FILES) {
    	# Header
    	$TCL_FILE .= "################################################################################\n";
    	$TCL_FILE .= "# Constraints taken from ".convPath($fileloc)."\n";
    	$TCL_FILE .= "################################################################################\n";
    	# Read file and append whole content to single file
    	open(CONFILE, "<", $fileloc) or die "Could not open constraint file!";
    	# Read file
    	while (defined($line = <CONFILE>)) {
      		$TCL_FILE .= $line;
    	}
    	close(CONFILE);
    	$TCL_FILE .= "\n\n";
  	}

  	# Timing contraints
  	foreach (1..@SDC_FILES) {
    	# Take first entry and check if file exists
    	$line = shift(@SDC_FILES);
   		# Expand to absolute path
    	$fileloc = expandToAbsolutePath($line);
    	# Check if file exists
    	if (-f $fileloc) {
      		push(@SDC_FILES, $fileloc);
      		$TCL_FILE .= 'set_global_assignment -name SDC_FILE "'.$fileloc.'"'."\n";
    	}
    	else {
      		printf ("Warning: \"%s\" does not exist\n", convPath($fileloc));
    	}
  	}

  	# Close project
  	$TCL_FILE .= "project_close\n";


  	# Write TCL file
  	$tclFileLoc = convPath($CALLDIR."/".$IMP_NAME[0].".tcl");
  	open(TCLFILE, ">", $tclFileLoc) or die "Could not write tcl project file";
  	print TCLFILE $TCL_FILE;
  	close(TCLFILE);
  	if ($VERBOSE == 1) {
    	printf ("  Wrote \"%s\"\n", $tclFileLoc);
  	}




  	# ----------------------------------------------------------------------------
  	# Build synthesis scripts
  	if ($SYN == 1) {
    	print "-----------------------------------------------------------------------------\n";
    	print " Building script files for QUARTUS_MAP                                       \n";
    	print "-----------------------------------------------------------------------------\n";
    	$MAP_COMMAND = "quartus_map ".$IMP_NAME[0];

    	$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".alt.map");
    	writeBatch($fileloc, "quartus", $MAP_COMMAND);
  	}



  	# ----------------------------------------------------------------------------
  	# Build place and route scripts
  	if ($PAR == 1) {
    	print "-----------------------------------------------------------------------------\n";
    	print " Building script files for QUARTUS_FIT and QUARTUS_ASM                       \n";
    	print "-----------------------------------------------------------------------------\n";
    	$FIT_COMMAND = "quartus_fit ".$IMP_NAME[0];
    	$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".alt.fit");
    	writeBatch($fileloc, "quartus", $FIT_COMMAND);
	
    	$ASM_COMMAND = "quartus_asm ".$IMP_NAME[0];
    	$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".alt.asm");
    	writeBatch($fileloc, "quartus", $ASM_COMMAND);
  	}



  	# ----------------------------------------------------------------------------
  	# Build timing analysis scripts
  	if ($TIMING == 1) {
    	print "-----------------------------------------------------------------------------\n";
    	print " Building script files for QUARTUS_STA                                       \n";
    	print "-----------------------------------------------------------------------------\n";
    	$STA_COMMAND = "quartus_sta ".$IMP_NAME[0];
    	$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".alt.sta");
    	writeBatch($fileloc, "quartus", $STA_COMMAND);
  	}




  	# ----------------------------------------------------------------------------
  	# Run commands
  	unless ($DRY == 1) {

    	# Create Quartus II project
    	print "-----------------------------------------------------------------------------\n";
    	print " Building QUARTUS II project file                                            \n";
    	print "-----------------------------------------------------------------------------\n";
    	$PROJGEN_COMMAND = "quartus_sh -t ".convPath($tclFileLoc);
    	# Start QUARTUS_SH to create project file
    	chdir("quartus");
    	$ret = systemCall($PROJGEN_COMMAND);
    	chdir("..");
    	if ($ret != 0) {
      		return($ret);
    	}

    	# Run synthesis
    	if ($SYN == 1) {
      		print "-----------------------------------------------------------------------------\n";
      		print " Starting QUARTUS_MAP                                                        \n";
      		print "-----------------------------------------------------------------------------\n";
      		#Start QUARTUS_MAP and stop on error
      		chdir("quartus");
      		$ret = systemCall($MAP_COMMAND);
      		chdir("..");
      		if ($ret != 0) {
        		return($ret);
      		}
    	}

    	# Run place and route
    	if ($PAR == 1) {
      		print "-----------------------------------------------------------------------------\n";
      		print " Starting QUARTUS_CDB                                                        \n";
      		print "-----------------------------------------------------------------------------\n";
			#Start QUARTUS_CDB and stop on error


      		print "-----------------------------------------------------------------------------\n";
      		print " Starting QUARTUS_FIT                                                        \n";
      		print "-----------------------------------------------------------------------------\n";
      		#Start QUARTUS_FIT and stop on error
      		chdir("quartus");
      		$ret = systemCall($FIT_COMMAND);
      		chdir("..");
      		if ($ret != 0) {
        		return($ret);
      		}

      		print "-----------------------------------------------------------------------------\n";
      		print " Starting QUARTUS_ASM                                                        \n";
      		print "-----------------------------------------------------------------------------\n";
      		#Start QUARTUS_ASM and stop on error
      		chdir("quartus");
      		$ret = systemCall($ASM_COMMAND);
      		chdir("..");
      		if ($ret != 0) {
        		return($ret);
      		}
    	}

    	# Run timing analysis
    	if ($TIMING == 1) {
      		print "-----------------------------------------------------------------------------\n";
      		print " Starting QUARTUS_STA                                                        \n";
      		print "-----------------------------------------------------------------------------\n";
      		#Start QUARTUS_STA and stop on error
      		chdir("quartus");
      		$ret = systemCall($STA_COMMAND);
      		chdir("..");
      		if ($ret != 0) {
        		return($ret);
      		}
    	}
  	}

  	return($ret);

}


######################################################################
### Package return
1;
__END__


=pod



=cut
