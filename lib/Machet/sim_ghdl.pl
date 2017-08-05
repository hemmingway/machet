#!/usr/bin/perl -w
#
# File       : sim_ghdl.pl
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


sub sim_ghdl {

	my $VERBOSE           = $MAIN::VERBOSE;              # Enable full comments

  	my $DRY               = $MAIN::DRY;                  # Perform dry run only, creates only scripts
  	my $COM               = $MAIN::COM;                  # Command line option for simulation compile run
  	my $RUN               = $MAIN::RUN;                  # Command line option for simulation start
  	my $NODUMP            = $MAIN::NODUMP;               # Command line option to disable value change dumps in simulation
  	my $WAVE              = $MAIN::WAVE;                 # Command line option to display waveform

  	my $CALLDIR           = $MAIN::CALLDIR;              # Directory from where this script is called
  	my @IMP_NAME          = @MAIN::IMP_NAME;             # Implementation name
  	my @TOPLEVEL          = @MAIN::TOPLEVEL;             # Top level module name for FPGA or SIM run

  	my @SOURCEFILE_LIST   = @MAIN::SOURCEFILE_LIST;      # Complete list of all source files with absolute path

  	my @GHDL_COMOPTIONS   = @MAIN::GHDL_COMOPTIONS;      # Options to parse to GHDL compiler
  	my @GHDL_RUNOPTIONS   = @MAIN::GHDL_RUNOPTIONS;      # Options to parse to GHDL for simulation run


  	# Local variables
  	my @COMPILE_COMMAND;          # Command list to start compiler
  	my $RUN_COMMAND = '';         # Command to start simulation
  	my $RUN_COMMAND_NODUMP = '';  # Command to start simulation without dumpvar file
  	my $WAVE_COMMAND = '';        # Command to display waveform

  	my $compileCommand;           # Name of logfile, imp name expanded with testcase name
  	my $fileloc;                  # Location of file
  	my $line;                     # Single line

  	my $ret = 1;                  # Return value of system calls

 	# Create simulation directory
  	unless (-d convPath($CALLDIR."/ghdl")) {
    	systemCall("mkdir ghdl");
  	}


  	# ----------------------------------------------------------------------------
  	# Build compile batch file
  	if ($COM == 1) {

    	print "-----------------------------------------------------------------------------\n";
    	print " Building compile script files                                               \n";
    	print "-----------------------------------------------------------------------------\n";

    	# Command for compile run
    	# Add only supported file types
    	foreach (1..@SOURCEFILE_LIST) {
      		# Remove first entry from file list
      		$line = shift(@SOURCEFILE_LIST);

      		# VHDL file
      		if ($line =~ m/\.vhd$/i) {
        		$compileCommand = "ghdl -a";
        		foreach (@GHDL_COMOPTIONS) {
          			$compileCommand .= " ".$_;
        		}
        		$compileCommand .= " ".convPath($line);
        		push(@COMPILE_COMMAND, $compileCommand);
      		}
      		# Something
      		else {
        		printf ("Warning: \"%s\" is unsupported file type\n", convPath($line));
      		}
      		push(@SOURCEFILE_LIST, $line);
    	}

    	push(@COMPILE_COMMAND, "ghdl -e ".$TOPLEVEL[0]);

    	# Write batch file
    	$line = '';
    	foreach (@COMPILE_COMMAND) {
      		$line .= $_."\n";
    	}
    	chomp($line);
    	$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".com");
    	writeBatch($fileloc, "ghdl", $line);

  	}


  	# ----------------------------------------------------------------------------
  	# Build simulation batch file
  	if ($RUN == 1) {
    	print "-----------------------------------------------------------------------------\n";
    	print " Building simulation script files                                            \n";
    	print "-----------------------------------------------------------------------------\n";

    	# Command for simulation run
    	$RUN_COMMAND = "ghdl -r ".$TOPLEVEL[0];

    	foreach $line (@GHDL_RUNOPTIONS) {
      		$RUN_COMMAND .= " ".$line;
    	}

    	$RUN_COMMAND_NODUMP = $RUN_COMMAND;
    	$RUN_COMMAND .= ' --wave="'.$IMP_NAME[0].'.ghw"';

    	# Write batch file
    	$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".run");
    	writeBatch($fileloc, "ghdl", $RUN_COMMAND);
    	$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".run.nodump");
    	writeBatch($fileloc, "ghdl", $RUN_COMMAND_NODUMP);
  	}


  	# ----------------------------------------------------------------------------
  	# Build wave display batch file
  	if ($WAVE == 1) {
    	print "-----------------------------------------------------------------------------\n";
    	print " Building waveform script files                                              \n";
    	print "-----------------------------------------------------------------------------\n";

    	# Command for wave display
    	$WAVE_COMMAND = "gtkwave ".$IMP_NAME[0].".ghw";

    	# Write batch file
    	$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".wave");
    	writeBatch($fileloc, "ghdl", $WAVE_COMMAND);
  	}



  	# ----------------------------------------------------------------------------
  	# Run commands
  	unless ($DRY == 1) {
    	if ($COM == 1) {
      		print "-----------------------------------------------------------------------------\n";
      		print " Starting compile and elaboration                                            \n";
      		print "-----------------------------------------------------------------------------\n";

      		# Start compile run
      		foreach (@COMPILE_COMMAND) {
        		chdir("ghdl");
        		$ret = systemCall($_);
        		chdir("..");
        		if ($ret != 0) {
          			return($ret);
        		}
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
      		chdir("ghdl");
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
      		chdir("ghdl");
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
