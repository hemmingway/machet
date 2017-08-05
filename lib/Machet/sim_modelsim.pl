#!/usr/bin/perl -w
#
# File       : sim_modelsim.pl
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


sub sim_modelsim {

	my $VERBOSE           = $MAIN::VERBOSE;          # Enable full comments

  	my $DRY               = $MAIN::DRY;              # Perform dry run only, creates only scripts
  	my $TESTCASE          = $MAIN::TESTCASE;         # Name of selected testcase
  	my $COM               = $MAIN::COM;              # Command line option for simulation compile run
  	my $ELAB              = $MAIN::ELAB;             # Command line option for simulation elaboration
  	my $RUN               = $MAIN::RUN;              # Command line option for simulation start
  	my $INTER             = $MAIN::INTER;            # Command line option for interactive (GUI) simulation
  	my $NODUMP            = $MAIN::NODUMP;           # Command line option to disable value change dumps in simulation
  	my $WAVE              = $MAIN::WAVE;             # Command line option to display waveform

  	my $CALLDIR           = $MAIN::CALLDIR;          # Directory from where this script is called
  	my @IMP_NAME          = @MAIN::IMP_NAME;         # Implementation name
  	my @INCLUDE_PATHS     = @MAIN::INCLUDE_PATHS;    # List of include files (pointing to files directly)
  	my @VERILOG_DEFINES   = @MAIN::VERILOG_DEFINES;  # Verilog defines used for all files
  	my @TOPLEVEL          = @MAIN::TOPLEVEL;         # Top level module name for FPGA or SIM run

  	my @SOURCEFILE_LIST   = @MAIN::SOURCEFILE_LIST;  # Complete list of all source files with absolute path

  	my @VLOGOPTIONS       = @MAIN::MSIM_VLOGOPTIONS; # Options to parse to ModelSim vlog compilers
  	my @VCOMOPTIONS       = @MAIN::MSIM_VCOMOPTIONS; # Options to parse to ModelSim vcom compilers
  	my @VSIMOPTIONS       = @MAIN::MSIM_VSIMOPTIONS; # Options to parse to ModelSim vsim simulator

  	my $VLOGCFG_FILE = '';        # Configuration file for VLOG run, contains parameters and file names
  	my $VCOMCFG_FILE = '';        # Configuration file for VCOM run, contains parameters and file names
  	my $COMPILE_LIB_COMMAND;      # Command to create working library
  	my $COMPILE_VLOG_COMMAND;     # Command to start VLOG compiler
  	my $COMPILE_VCOM_COMMAND;     # Command to start VCOM compiler
  	my $ELAB_COMMAND = '';        # Command to start elaboration
  	my $RUN_COMMAND = '';         # Command to start simulation
  	my $WAVE_COMMAND = '';        # Command to display waveform

  	my $foundVerilog = 0;         # Set to 1 if Verilog file is found in file list
  	my $foundVhdl = 0;            # Set to 1 if VHDL file is found in file list
  	my $logfileName;              # Name of logfile, imp, name expanded with testcase name
  	my $fileloc;                  # Location of file
  	my $line;                     # Single line
  	my $currentEntry;             # Current entry from list
  	my $ret = 1;                  # Return value

  	# Create simulation directory
  	unless (-d convPath($CALLDIR."/modelsim")) {
    	systemCall("mkdir modelsim");
  	}


  	# Add testcase path to include paths
  	if ($TESTCASE ne "") {
    	$currentEntry = cleanPath($CALLDIR."/../testcases/".$TESTCASE);
    	# Check if testcase directory exists and append to include path list
    	if (-d convPath($currentEntry)) {
      		push(@INCLUDE_PATHS, $currentEntry);
    	}
    	# Else terminate run
    	else {
      		print "ERROR: Testcase \"$TESTCASE\" does not exist\n";
      		return(-1);
    	}
  	}

	# ----------------------------------------------------------------------------
  	# Build simulation compile batch files
  	if ($COM == 1) {

    	print "-----------------------------------------------------------------------------\n";
    	print " Building compile script files                                               \n";
    	print "-----------------------------------------------------------------------------\n";

    	# Building VLOG configuration file
    	# Include paths
    	if (@INCLUDE_PATHS > 0) {
      		$VLOGCFG_FILE .= "+incdir";
      		foreach $currentEntry (@INCLUDE_PATHS) {
        		$VLOGCFG_FILE .= "+".$currentEntry;
      		}
      		$VLOGCFG_FILE .= "\n";
    	}
    	# Defines
    	if (@VERILOG_DEFINES > 0) {
      		$VLOGCFG_FILE .= "+define";
     		# Convert to ModelSim syntax
      		foreach $currentEntry (@VERILOG_DEFINES) {
        		$currentEntry =~ s/^(\w+?)[ ]+(.+)/$1="$2"/;
        		# Append to string
        		$VLOGCFG_FILE .= "+".$currentEntry;
      		}
      		$VLOGCFG_FILE .= "\n";
    	}
    	# Options from config file
    	foreach $currentEntry (@VLOGOPTIONS) {
      		$VLOGCFG_FILE .= $currentEntry."\n";
    	}


    	# Building VCOM configuration file
    	# Options from config file
    	foreach $currentEntry (@VCOMOPTIONS) {
      		$VCOMCFG_FILE .= " ".$currentEntry."\n";
    	}


    	# Check file type of all source files in list. Remove every file from
    	# beginning of list, check if file type is supported, add entry to compiler
    	# config file and put file back to end of source file list. Not supported
    	# file types are removed from list
    	# Set $foundVerilog and $foundVhdl to tell the run section whether to lauch
    	# the corresponding compiler
    	foreach (1..@SOURCEFILE_LIST) {
      		# Remove first entry from source file list
      		$line = shift(@SOURCEFILE_LIST);

      		# Verilog files
      		if ($line =~ m/\.v$/i) {
        		push(@SOURCEFILE_LIST, $line);
				$VLOGCFG_FILE .= $line."\n";
				$foundVerilog = 1;
      		}
      		# VHDL files
      		elsif ($line =~ m/\.vhd$/i) {
        		push(@SOURCEFILE_LIST, $line);
				$VCOMCFG_FILE .= $line."\n";
				$foundVhdl = 1;
      		}
      		# Something
      		else {
        		printf ("Warning: \"%s\" is unsupported file type\n", convPath($line));
      		}
    	}

    	# Write config files
    	$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".vlog.cfg");
    	open(CFGFILE, "> $fileloc") or die "Could not open ModelSim VLOG config file!";
    	print CFGFILE $VLOGCFG_FILE;
    	close(CFGFILE);
    	#Report
    	if ($VERBOSE == 1) {
      		printf ("  Wrote \"%s\"\n", $fileloc);
    	}
    	$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".vcom.cfg");
    	open(CFGFILE, "> $fileloc") or die "Could not open ModelSim VCOM config file!";
    	print CFGFILE $VCOMCFG_FILE;
    	close(CFGFILE);
    	#Report
    	if ($VERBOSE == 1) {
      		printf ("  Wrote \"%s\"\n", $fileloc);
    	}


    	# Compile commands
    	$COMPILE_LIB_COMMAND = "vlib work";
    	$COMPILE_VLOG_COMMAND = "vlog -f ".convPath("../".$IMP_NAME[0].".vlog.cfg");
    	$COMPILE_VCOM_COMMAND = "vcom -f ".convPath("../".$IMP_NAME[0].".vcom.cfg");

    	# Write batch files
    	$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".com.lib");
    	writeBatch($fileloc, "modelsim", $COMPILE_LIB_COMMAND);

    	$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".com.vlog");
    	writeBatch($fileloc, "modelsim", $COMPILE_VLOG_COMMAND);

    	$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".com.vcom");
    	writeBatch($fileloc, "modelsim", $COMPILE_VCOM_COMMAND);
	}



  	# ----------------------------------------------------------------------------
  	# Build simulation run batch file
  	if (($ELAB == 1) || ($RUN == 1)) {
    	print "-----------------------------------------------------------------------------\n";
    	print " Building simulation script files                                            \n";
    	print "-----------------------------------------------------------------------------\n";

    	# Command for elaboration
    	$ELAB_COMMAND = "vsim";
    	$ELAB_COMMAND .= " -elab ".$IMP_NAME[0].".elab";
    	foreach $currentEntry (@VSIMOPTIONS) {
      		$ELAB_COMMAND .= " ".$currentEntry;
    	}
    	$ELAB_COMMAND .= " ".$TOPLEVEL[0];

    	# Write batch file
    	$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".elab");
    	writeBatch($fileloc, "modelsim", $ELAB_COMMAND);



    	# Expand logfile name with testcase name
    	$logfileName = $IMP_NAME[0];
    	unless ($TESTCASE eq "") {
      		$logfileName .= ".".$TESTCASE;
    	}
    	$logfileName .= ".log";

    	# Command for elaboration and simulation run
    	$RUN_COMMAND .= "vsim";
    	foreach $currentEntry (@VSIMOPTIONS) {
      		$RUN_COMMAND .= " ".$currentEntry;
    	}
   		# If logfile has been specified in @VSIMOPTIONS, the default logfile will be ignored
    	$RUN_COMMAND .= " -l ".$logfileName;
    	if ($INTER == 1) {
      		$RUN_COMMAND .= " -do ../".$IMP_NAME[0].".inter.do";
    	}
    	else {
      		$RUN_COMMAND .= " -c";
      		if ($NODUMP == 1) {
        		$RUN_COMMAND .= " -do ../".$IMP_NAME[0].".nodump.do";
      		}
      		else {
        		$RUN_COMMAND .= " -do ../".$IMP_NAME[0].".batch.do";
      		}
    	}
    	$RUN_COMMAND .= " -wlf ".$IMP_NAME[0].".wlf";
    	$RUN_COMMAND .= " ".$TOPLEVEL[0];

    	# Write batch file
    	$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".run");
    	writeBatch($fileloc, "modelsim", $RUN_COMMAND);



    	# Create do files if they are not present
    	$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".nodump.do");
    	createDoFile($fileloc, "nodump");

    	$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".batch.do");
    	createDoFile($fileloc, "batch");

    	$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".inter.do");
    	createDoFile($fileloc, "inter");
	}



  	if ($WAVE == 1) {
    	print "-----------------------------------------------------------------------------\n";
    	print " Building waveform script files                                              \n";
    	print "-----------------------------------------------------------------------------\n";
    	# Command for wave display
    	$WAVE_COMMAND = "vsim -view ".$IMP_NAME[0].".wlf";

    	# Write batch file
    	$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".wave");
    	writeBatch($fileloc, "modelsim", $WAVE_COMMAND);
  	}





  	# Start batch files
 	unless ($DRY == 1) {

			if ($COM == 1) {
		  	print "-----------------------------------------------------------------------------\n";
		  	print " Starting ModelSim compiler                                                  \n";
		  	print "-----------------------------------------------------------------------------\n";

		  	# Report
		  	if ($TESTCASE ne "") {
		    	print "  Compiling testcase \"$TESTCASE\"\n";
		  	}

		  	# Start compile and stop on errors
		  	chdir("modelsim");
		  	$ret = systemCall($COMPILE_LIB_COMMAND);
		  	chdir("..");
		  	if ($ret != 0) {
		    	return($ret);
		  	}

		  	if ($foundVerilog == 1) {
				chdir("modelsim");
				$ret = systemCall($COMPILE_VLOG_COMMAND);
				chdir("..");
				if ($ret != 0) {
		  			return($ret);
				}
		  	}

		  	if ($foundVhdl == 1) {
				chdir("modelsim");
				$ret = systemCall($COMPILE_VCOM_COMMAND);
				chdir("..");
				if ($ret != 0) {
		  			return($ret);
				}
		  	}    	
		}

		if ($ELAB == 1) {
			print "-----------------------------------------------------------------------------\n";
		  	print " Starting elaboration                                                        \n";
		  	print "-----------------------------------------------------------------------------\n";

		  	# Start elab and stop on errors
		  	chdir("modelsim");
		  	$ret = systemCall($ELAB_COMMAND);
		  	chdir("..");
		  	if ($ret != 0) {
		    	return($ret);
		  	}
		}

		if ($RUN == 1) {
			print "-----------------------------------------------------------------------------\n";
		  	print " Starting elaboration and simulation                                         \n";
		  	print "-----------------------------------------------------------------------------\n";

		  	# Start elab and simulation
		  	chdir("modelsim");
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
		  	chdir("modelsim");
		  	$ret = systemCall($WAVE_COMMAND);
		  	chdir("..");
		  	if ($ret != 0) {
		    	return($ret);
		  	}
		}
	}

  	return($ret);

}



# |-----------------------------------------------------------------------------
# | Template for ModelSim do file content
# |-----------------------------------------------------------------------------
sub createDoTemplate {
	my $template = '';

  	unless (@_ == 1) {
    	die("createDoTemplate called with illegal number of arguments");
  	}

 	 # Create do file for batch simulation without dump
  	if ($_[0] eq "nodump") {
    	$template .= "run -all\n";
    	$template .= "exit\n";
  	}
  	# Create do file for batch simulation
  	elsif ($_[0] eq "batch") {
    	$template .= "log -recursive *\n";
    	$template .= "run -all\n";
    	$template .= "exit\n";
  	}
  	# Create .do file for interactive simulation
  	elsif ($_[0] eq "inter") {
  	}
  	# Anything else results in error
  	else {
    	die("createDoTemplate called with illegal argument value");
  	}
  	return ($template);
}



# |-----------------------------------------------------------------------------
# | ModelSim do file creation
# |-----------------------------------------------------------------------------
sub createDoFile {
	my $VERBOSE           = $MAIN::VERBOSE;          # Enable full comments
  	my $doFile;
  	my $doMode;

  	unless (@_ == 2) {
  		die("createDoTemplate called with illegal number of arguments");
  	}

  	$doFile = $_[0];
  	$doMode = $_[1];

  	unless (-f $doFile) {
    	open(DOFILE, "> $doFile") or die "Could not open do file!";
    	print DOFILE createDoTemplate($doMode);
    	close(DOFILE);
    	#Report
    	if ($VERBOSE == 1) {
      		printf ("  Wrote \"%s\"\n", $doFile);
    	}	
  	}
  	else {
    	#Report
    	if ($VERBOSE == 1) {
      		printf ("  \"%s\" already exists\n", $doFile);
    	}
  	}
}




# Dummy
1;
