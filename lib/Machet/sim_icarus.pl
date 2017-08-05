#!/usr/bin/perl -w
#
# File       : sim_icarus.pl
# Author     : wangxf
# Company    : CPUxOS
# Description: 
# Revisions  :
#
# Date        Author           Description
# 2017-07-24  wangxf           Created
#
#
#


use strict;


sub sim_icarus {

	my $VERBOSE           = $MAIN::VERBOSE;              # Enable full comments

  	my $DRY               = $MAIN::DRY;                  # Perform dry run only, creates only scripts
  	my $TESTCASE          = $MAIN::TESTCASE;             # Name of selected testcase
  	my $COM               = $MAIN::COM;                  # Command line option for simulation compile run
  	my $RUN               = $MAIN::RUN;                  # Command line option for simulation start
  	my $NODUMP            = $MAIN::NODUMP;               # Command line option to disable value change dumps in simulation
  	my $WAVE              = $MAIN::WAVE;                 # Command line option to display waveform

  	my $CALLDIR           = $MAIN::CALLDIR;              # Directory from where this script is called
  	my @IMP_NAME          = @MAIN::IMP_NAME;             # Implementation name
  	my @INCLUDE_PATHS     = @MAIN::INCLUDE_PATHS;        # List of include files (pointing to files directly)
  	my @VERILOG_DEFINES   = @MAIN::VERILOG_DEFINES;      # Verilog defines used for all files
  	my @TOPLEVEL          = @MAIN::TOPLEVEL;             # Top level module name for FPGA or SIM run

  	my @SOURCEFILE_LIST   = @MAIN::SOURCEFILE_LIST;      # Complete list of all source files with absolute path

  	my @IVERILOGOPTIONS   = @MAIN::ICAR_IVERILOGOPTIONS; # Options to parse to Icarus iverilog compilers
  	my @VVPOPTIONS        = @MAIN::ICAR_VVPOPTIONS;      # Options to parse to Icarus vvp runtime


  	# Local variables
  	my $IVERILOGCFG_FILE = '';    # Config file content for IVERILOG
  	my $COMPILE_COMMAND = '';     # Command list to start compiler
  	my $RUN_COMMAND = '';         # Command to start simulation
  	my $RUN_COMMAND_NODUMP = '';  # Command to start simulation without dumpvar file
  	my $WAVE_COMMAND = '';        # Command to display waveform

  	my $logfileName;              # Name of logfile, imp, name expanded with testcase name
  	my $fileloc;                  # Location of file
  	my $line;                     # Single line
  	my $currentPath;              # Current path that is evaluated

  	my $ret = 1;                  # Return value of system calls

  	# Create simulation directory
  	unless (-d convPath($CALLDIR."/icarus")) {
    	systemCall("mkdir icarus");
  	}



  	# Add testcase path to include paths
  	if ($TESTCASE ne "") {
    	$currentPath = cleanPath($CALLDIR."/../testcases/".$TESTCASE);
    	# Check if testcase directory exists and append to include path list
    	if (-d convPath($currentPath)) {
      		push(@INCLUDE_PATHS, $currentPath);
    	}
    	# Else terminate run
    	else {
      		print "ERROR: Testcase \"$TESTCASE\" does not exist\n";
      		return(-1);
    	}
  	}



  	# ----------------------------------------------------------------------------
  	# Build compile batch file
  	if ($COM == 1) {

    	print "-----------------------------------------------------------------------------\n";
    	print " Building compile script files                                               \n";
    	print "-----------------------------------------------------------------------------\n";


    	# Create Icarus Verilog configuration file
    	# Add source files
    	$IVERILOGCFG_FILE = "# Files\n";
    	foreach (1..@SOURCEFILE_LIST) {
      		# Remove first entry from file list
      		$line = shift(@SOURCEFILE_LIST);

      		# Verilog file
      		if ($line =~ m/\.v$/i) {
        		$IVERILOGCFG_FILE .= $line."\n";
      		}
      		# Something
      		else {
        		printf ("Warning: \"%s\" is unsupported file type\n", convPath($line));
      		}
      		push(@SOURCEFILE_LIST, $line);
    	}


    	# Add include paths
    	$IVERILOGCFG_FILE .= "\n# Include paths\n";
    	foreach (@INCLUDE_PATHS) {
      		$IVERILOGCFG_FILE .= "+incdir+".$_."\n";
    	}

    	# Add defines
    	$IVERILOGCFG_FILE .= "\n# Defines\n";
    	foreach (1..@VERILOG_DEFINES) {
      		# Remove first entry from defines list
      		$line = shift(@VERILOG_DEFINES);
      		# Convert from Verilog format (`define DEF 32) to Icarus Verilog format (DEF="32")
      		$line =~ s/^(\w+?)[ ]+(.+)/$1="$2"/;
      		$IVERILOGCFG_FILE .= "+define+".$line."\n";
      		push(@VERILOG_DEFINES, $line);
    	}

    	# Write config file
    	$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".icarus.cfg");
    	open(CFGFILE, "> $fileloc") or die "Could not open Icarus Verilog config file!";
    	print CFGFILE $IVERILOGCFG_FILE;
    	close(CFGFILE);
    	#Report
    	if ($VERBOSE == 1) {
      		printf ("  Wrote \"%s\"\n", $fileloc);
    	}



    	$COMPILE_COMMAND = "iverilog -s".$TOPLEVEL[0]. " -c../".$IMP_NAME[0].".icarus.cfg -o".$IMP_NAME[0].".vvp";
    	# Add options
    	foreach (@IVERILOGOPTIONS) {
      		$COMPILE_COMMAND .= " ".$_;
    	}
    	$COMPILE_COMMAND = convPath($COMPILE_COMMAND);

    	# Write batch file
    	$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".com");
    	writeBatch($fileloc, "icarus", $COMPILE_COMMAND);
  	}



  	# ----------------------------------------------------------------------------
  	# Build simulation batch file
  	if ($RUN == 1) {
    	
		print "-----------------------------------------------------------------------------\n";
    	print " Building simulation script files                                            \n";
    	print "-----------------------------------------------------------------------------\n";

    	# Expand logfile name with testcase name
   		$logfileName = $IMP_NAME[0];
    	unless ($TESTCASE eq "") {
      		$logfileName .= ".".$TESTCASE;
    	}
    	$logfileName .= ".log";

    	# Command for simulation run
    	$RUN_COMMAND = "vvp -l".$logfileName;
    	# Add options
    	foreach (@VVPOPTIONS) {
      		$RUN_COMMAND .= " ".$_;
    	}
    	$RUN_COMMAND .= " ".$IMP_NAME[0].".vvp -lxt2";
    	$RUN_COMMAND = convPath($RUN_COMMAND);
    	$RUN_COMMAND_NODUMP = $RUN_COMMAND." -none";

    	# Write batch files
    	$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".run");
    	writeBatch($fileloc, "icarus", $RUN_COMMAND);
    	$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".run.nodump");
    	writeBatch($fileloc, "icarus", $RUN_COMMAND_NODUMP);
  	}



  	# ----------------------------------------------------------------------------
  	# Build wave display batch file
  	if ($WAVE == 1) {
    	
		print "-----------------------------------------------------------------------------\n";
    	print " Building waveform script files                                              \n";
    	print "-----------------------------------------------------------------------------\n";

    	# Command for wave display
    	$WAVE_COMMAND = "gtkwave dump.lx2";

    	# Write batch file
    	$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".wave");
    	writeBatch($fileloc, "icarus", $WAVE_COMMAND);
  	}



  	# ----------------------------------------------------------------------------
  	# Run commands
  	unless ($DRY == 1) {
    	if ($COM == 1) {
      	print "-----------------------------------------------------------------------------\n";
      	print " Starting compile                                                            \n";
      	print "-----------------------------------------------------------------------------\n";

      	# Report
      	if ($TESTCASE ne "") {
        	print "  Compiling testcase \"$TESTCASE\"\n";
      	}
      	# Start compile run
      	chdir("icarus");
      	$ret = systemCall($COMPILE_COMMAND);
      	chdir("..");
      	if ($ret != 0) {
        	return($ret);
      	}
    }

    if ($RUN == 1) {
    	print "-----------------------------------------------------------------------------\n";
      	print " Starting simulation                                                         \n";
      	print "-----------------------------------------------------------------------------\n";

      	# Change command to nodump if option has been specified
      	if ($NODUMP == 1) {
        	$RUN_COMMAND = $RUN_COMMAND_NODUMP;
      	}
      	# Start elab and simulation
      	chdir("icarus");
      	$ret = systemCall($RUN_COMMAND);
      	chdir("..");
      	if ($ret != 0) {
        	return($ret);
      	}
    }

    if ($WAVE == 1) {
    	print "-----------------------------------------------------------------------------\n";
      	print " Displaying waveform                                                         \n";
      	print "-----------------------------------------------------------------------------\n";

      	# Start waveform viewer
      	chdir("icarus");
      	$ret = systemCall($WAVE_COMMAND);
      	chdir("..");
      	if ($ret != 0) {
        	return($ret);
      	}
    	}

  	}

  	return($ret);

}


# Dummy
1;
