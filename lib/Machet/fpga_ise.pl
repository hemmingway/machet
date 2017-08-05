#!/usr/bin/perl -w
#
# File       : fpga_ise.pl
# Author     : wangxf
# Company    : CPUxOS
# Description: Xilinx Synthesis Technology(XST)
# Revisions  : 
#
# Date        Author           Description
# 2017-07-24  wangxf           Created
#
#
#


use strict;


sub fpga_ise {

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

  	my @SYNCONSTRAINT_FILES  = @MAIN::XIL_SYNCONSTRAINT_FILES; 
  	my @PARCONSTRAINT_FILES  = @MAIN::XIL_PARCONSTRAINT_FILES;
  	my @XSTOPTIONS           = @MAIN::XIL_XSTOPTIONS;
  	my @NGDBUILDOPTIONS      = @MAIN::XIL_NGDBUILDOPTIONS;
  	my @MAPOPTIONS           = @MAIN::XIL_MAPOPTIONS;
  	my @PAROPTIONS           = @MAIN::XIL_PAROPTIONS;
  	my @BITGENOPTIONS        = @MAIN::XIL_BITGENOPTIONS;
  	my @TRACEOPTIONS         = @MAIN::XIL_TRACEOPTIONS;


  	# Local variables
  	my $XSTPRJ_FILE = '';         # Content of .prj file for XST
  	my $XSTXST_FILE = '';         # Content of .xst file for XST
  	my $UCF_FILE ='';             # Xilinx constraint file content

  	my $XST_COMMAND = '';         # Command to start XST
  	my $NGDBUILD_COMMAND = '';    # Command to start NGDBUILD
  	my $MAP_COMMAND = '';         # Command to start MAP
  	my $PAR_COMMAND = '';         # Command to start PAR
  	my $BITGEN_COMMAND = '';      # Command to start BITGEN
  	my $TRACE_COMMAND = '';       # Command to start TRACE


  	my $fileloc;                  # Location of file
  	my $line;                     # Single line
  	my $ret = 1;                  # Return value


  	# Create constraints directory if not present
  	unless (-d convPath($CALLDIR."/constraints")) {
    	systemCall("mkdir constraints");
  	}
  	unless (-d convPath($CALLDIR."/constraints/gen")) {
    	chdir("constraints");
    	systemCall("mkdir gen");
    	chdir("..");
  	}
 	# Create XST directory if not present
  	unless (-d convPath($CALLDIR."/xst")) {
    	systemCall("mkdir xst");
  	}
  	# Create NGDBUILD directory if not present
  	unless (-d convPath($CALLDIR."/ngdbuild")) {
    	systemCall("mkdir ngdbuild");
  	}
  	# Create MAP directory if not present
  	unless (-d convPath($CALLDIR."/map")) {
    	systemCall("mkdir map");
  	}
  	# Create PAR directory if not present
  	unless (-d convPath($CALLDIR."/par")) {
    	systemCall("mkdir par");
 	}
  	# Create BITGEN directory if not present
  	unless (-d convPath($CALLDIR."/bitgen")) {
    	systemCall("mkdir bitgen");
  	}
  	# Create TRACE directory if not present
  	unless (-d convPath($CALLDIR."/trace")) {
    	systemCall("mkdir trace");
  	}



  	# ----------------------------------------------------------------------------
  	# Build all constraint files
  	print "-----------------------------------------------------------------------------\n";
  	print " Gathering constraint files (XCF and UCF)                                    \n";
  	print "-----------------------------------------------------------------------------\n";

  	# Generate UCF file
  	# Clean up file list and remove nonexistent files
  	foreach (1..@SYNCONSTRAINT_FILES) {
    	# Take first entry in array and check if file exists
    	$line = shift(@SYNCONSTRAINT_FILES);

    	# Expand to absolute path
    	$fileloc = expandToAbsolutePath($line);
    	
		# Check if file exists
    	if (-f convPath($fileloc)) {
      		push(@SYNCONSTRAINT_FILES, $fileloc);
    	}
    	else {
      		printf ("Warning: \"%s\" does not exist\n", convPath($fileloc));
    	}
  	}

  	# Report
  	if ($VERBOSE == 1) {
    	print "  Synthesis constraint files read:\n";
    	foreach (@SYNCONSTRAINT_FILES) {
      		printf ("    %s\n", convPath($_));
    	}
  	}

	# Build single constraint file from all files in list
  	$UCF_FILE = "";
  	foreach $fileloc (@SYNCONSTRAINT_FILES) {
    	# Header
    	$UCF_FILE .= "################################################################################\n";
    	$UCF_FILE .= "# Constraints taken from ".convPath($fileloc)."\n";
    	$UCF_FILE .= "################################################################################\n";
    	# Read file and append whole content to single file
    	open(CONFILE, "< $fileloc") or die "Could not open constraint file!";
    	# Read file
    	while (defined($line = <CONFILE>)) {
      		$UCF_FILE .= $line;
    	}
    	close(CONFILE);
    	$UCF_FILE .= "\n\n";
  	}
  	# Write file
  	$fileloc = convPath($CALLDIR."/constraints/gen/".$IMP_NAME[0].".gen.xcf");
  	open(CONFILE, "> $fileloc") or die "Could not write constraint file!";
  	print CONFILE $UCF_FILE;
  	close(CONFILE);
  	# Report
  	if ($VERBOSE == 1) {
    	printf ("  Wrote \"%s\"\n", $fileloc);
  	}

  	# Generate UCF file
  	# Clean up file list and remove nonexistent files
  	foreach (1..@PARCONSTRAINT_FILES) {
    	# Take first entry in array and check if file exists
    	$line = shift(@PARCONSTRAINT_FILES);
    	# Expand to absolute path
    	$fileloc = expandToAbsolutePath($line);
    	# Check if file exists
    	if (-f convPath($fileloc)) {
      		push(@PARCONSTRAINT_FILES, $fileloc);
    	}
    	else {
      		printf ("Warning: \"%s\" does not exist\n", convPath($fileloc));
    	}
  	}

  	# Report
  	if ($VERBOSE == 1) {
    	print "  PAR constraint files read:\n";
    	foreach (@PARCONSTRAINT_FILES) {
      		printf ("    %s\n", convPath($_));
    	}
  	}

  	# Build single constraint file from all files in list
  	$UCF_FILE = "";
  	foreach $fileloc (@PARCONSTRAINT_FILES) {
    	# Header
    	$UCF_FILE .= "################################################################################\n";
    	$UCF_FILE .= "# Constraints taken from ".convPath($fileloc)."\n";
    	$UCF_FILE .= "################################################################################\n";
    	# Read file and append whole content to single file
    	open(CONFILE, "< $fileloc") or die "Could not open constraint file!";
    	# Read file
    	while (defined($line = <CONFILE>)) {
      		$UCF_FILE .= $line;
    	}
    	close(CONFILE);
    	$UCF_FILE .= "\n\n";
  	}
  	# Write file
  	$fileloc = convPath($CALLDIR."/constraints/gen/".$IMP_NAME[0].".gen.ucf");
  	open(CONFILE, "> $fileloc") or die "Could not write constraint file!";
  	print CONFILE $UCF_FILE;
  	close(CONFILE);
  	# Report
  	if ($VERBOSE == 1) {
    	printf ("  Wrote \"%s\"\n", $fileloc);
  	}


  	# ----------------------------------------------------------------------------
  	# Build XST project file from source file list
  	if ($SYN == 1) {

    	print "-----------------------------------------------------------------------------\n";
    	print " Building .prj file for XST                                                  \n";
    	print "-----------------------------------------------------------------------------\n";

    	# Check file type of all source files in list. Remove every file from
    	# beginning of list, check if file type is supported, add entry to project
    	# file and put file back to end of source file list. Not supported file
    	# types are removed from list
    	foreach (1..@SOURCEFILE_LIST) {
      		# Remove first entry from source file list
      		$line = shift(@SOURCEFILE_LIST);

      		# Verilog
      		if ($line =~ m/\.v$/i) {
        		push(@SOURCEFILE_LIST, $line);
       	 		$line = 'verilog work "'.$line.'"'."\n";
        		$XSTPRJ_FILE .= $line;
      		}
      		# VHDL
      		elsif ($line =~ m/\.vhd$/i) {
        		push(@SOURCEFILE_LIST, $line);
        		$line = 'vhdl work "'.$line.'"'."\n";
        		$XSTPRJ_FILE .= $line;
      		}
      		# Something
      		else {
        		printf ("Warning: \"%s\" is unsupported file type\n", convPath($line));
      		}
    	}

    	# Write .prj file
    	$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".prj");
    	open(PRJFILE, "> $fileloc") or die "Could not write XST project file!";
    	print PRJFILE $XSTPRJ_FILE;
    	close(PRJFILE);

    	# Report
    	if ($VERBOSE == 1) {
    		printf ("  Wrote \"%s\"\n", $fileloc);
    	}


    	# ----------------------------------------------------------------------------
    	# Build XST config file and synthesis script
    	print "-----------------------------------------------------------------------------\n";
    	print " Building .xst file and synthesis script file for XST                        \n";
    	print "-----------------------------------------------------------------------------\n";

    	# Set temp and work dir
    	$XSTXST_FILE = 'set -tmpdir "'.$CALLDIR.'/xst"'."\n";
    	$XSTXST_FILE .= 'set -xsthdpdir "'.$CALLDIR.'/xst/hdp"'."\n";
    	# Add run options
    	$XSTXST_FILE .= "run\n";
    	# Infut file list (.prj file)
    	$XSTXST_FILE .= "-ifn ".$CALLDIR."/".$IMP_NAME[0].".prj\n";
    	# Input file format
    	$XSTXST_FILE .= "-ifmt mixed\n";
    	# Output file
    	$XSTXST_FILE .= "-ofn ".$CALLDIR."/xst/".$IMP_NAME[0].".ngc\n";
    	# Output format
    	$XSTXST_FILE .= "-ofmt NGC\n";
    	# Synthesis constraint file
    	$XSTXST_FILE .= "-uc ".$CALLDIR."/constraints/gen/".$IMP_NAME[0].".gen.xcf\n";
    	# FPGA part
    	$XSTXST_FILE .= "-p ".$FPGAPART[0]."\n";
    	# Top level
    	$XSTXST_FILE .= "-top ".$TOPLEVEL[0]."\n";
    	# Include path
    	$XSTXST_FILE .= "-vlgincdir { ";
    	foreach (@INCLUDE_PATHS) {
    		$XSTXST_FILE .= '"'.$_.'" ';
    	}
    	$XSTXST_FILE .= "}\n";
    	# Defines
    	if (@VERILOG_DEFINES > 0) {
    		$XSTXST_FILE .= "-define { ";
    		foreach (1..@VERILOG_DEFINES) {
    	    	$line = $VERILOG_DEFINES[$_ - 1];
        		# Convert from Verilog format (`define DEF 32) to XST format (DEF="32")
        		$line =~ s/^(\w+?)[ ]+(.+)/$1="$2"/;
        		# Append to string
        		$XSTXST_FILE .= $line." ";
        		if ($_ < @VERILOG_DEFINES) {
          			$XSTXST_FILE .= "| ";
        		}
      		}
      		$XSTXST_FILE .= "}\n";
    	}
    	# Netlists directory
    	$XSTXST_FILE .= '-sd { "'.$CALLDIR.'/netlists"'." }\n";
    	# Other options from config file
    	foreach (@XSTOPTIONS) {
    		$XSTXST_FILE .= $_."\n";
    	}

    	# Write .xst file
    	$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".xst");
    	open(XSTFILE, "> $fileloc") or die "Could not write .xst file!";
    	print XSTFILE $XSTXST_FILE;
    	close(XSTFILE);
    	# Report
    	if ($VERBOSE == 1) {
    		printf ("  Wrote \"%s\"\n", $fileloc);
    	}

    	# Create batch file
    	# XST command line
    	$XST_COMMAND = 'xst -ifn "'.$CALLDIR."/".$IMP_NAME[0].'.xst" -ofn "'.$IMP_NAME[0].'.srp"';
    	$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".xil.xst");
    	writeBatch($fileloc, "xst", $XST_COMMAND);

	}



	# ----------------------------------------------------------------------------
  	# Place and route script
  	if ($PAR == 1) {

    	# Create all batch files for place and route
    	print "-----------------------------------------------------------------------------\n";
    	print " Building script files for NGDBUILD, MAP, PAR and BITGEN                     \n";
    	print "-----------------------------------------------------------------------------\n";

    	# NGDBUILD command line
    	$line = "ngdbuild";
    	# Part
    	$line .= " -p ".$FPGAPART[0];
    	# Netlist directory
    	$line .= " -sd ".$CALLDIR."/netlists";
    	# Temp file location for .ngo files
    	$line .= " -dd ".$CALLDIR."/ngdbuild";
    	# User constraint file
    	$line .= " -uc ".$CALLDIR."/constraints/gen/".$IMP_NAME[0].".gen.ucf";
    	# Always regenerate .ngo files
    	$line .= " -nt on";
    	# User options from config file
    	foreach (@NGDBUILDOPTIONS) {
      		$line .= " ".$_;
    	}
    	# Input netlist
    	$line .= ' "'.$CALLDIR."/xst/".$IMP_NAME[0].'.ngc"';
    	# Output file
    	$line .= " ".$CALLDIR."/ngdbuild/".$IMP_NAME[0].".ngd";

    	# Create batch file
    	$NGDBUILD_COMMAND = $line;
    	$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".xil.ngdbuild");
    	writeBatch($fileloc, "ngdbuild", $NGDBUILD_COMMAND);

    	# MAP command line
    	$line = "map";
    	# Part
    	$line .= " -p ".$FPGAPART[0];
    	# User options from config file
    	foreach (@MAPOPTIONS) {
      		$line .= " ".$_;
    	}
   		# Input file (.ngd)
    	$line .= " ".$CALLDIR."/ngdbuild/".$IMP_NAME[0].".ngd";
    	# Output file
    	$line .= " -o ".$CALLDIR."/map/".$IMP_NAME[0].".map.ncd";
    	# PCF file
    	$line .= " ".$CALLDIR."/map/".$IMP_NAME[0].".pcf";

		# Create batch file
		$MAP_COMMAND = $line;
		$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".xil.map");
		writeBatch($fileloc, "map", $MAP_COMMAND);

		# PAR command line
		$line = "par";
		# Overwrite old results
		$line .= " -w";
		# User options from config file
		foreach (@PAROPTIONS) {
			$line .= " ".$_;
		}
		# Input file (.ncd)
		$line .= " ".$CALLDIR."/map/".$IMP_NAME[0].".map.ncd";
		# Output file
		$line .= " ".$CALLDIR."/par/".$IMP_NAME[0].".par.ncd";
		# PCF file
		$line .= " ".$CALLDIR."/map/".$IMP_NAME[0].".pcf";

		# Create batch file
		$PAR_COMMAND = $line;
		$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".xil.par");
		writeBatch($fileloc, "par", $PAR_COMMAND);

		# BITGEN command line
		$line = "bitgen";
		# Overwrite old results
		$line .= " -w";
		# User options from config file
		foreach (@BITGENOPTIONS) {
			$line .= " ".$_;
		}
		# Input file (.ncd)
		$line .= " ".$CALLDIR."/par/".$IMP_NAME[0].".par.ncd";
		# Output file
		$line .= " ".$CALLDIR."/bitgen/".$IMP_NAME[0].".bit";
		# PCF file
		$line .= " ".$CALLDIR."/map/".$IMP_NAME[0].".pcf";

		# Create batch file
		$BITGEN_COMMAND = $line;
		$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".xil.bitgen");
		writeBatch($fileloc, "bitgen", $BITGEN_COMMAND);
	}



  	# ----------------------------------------------------------------------------
  	# Timing analysis script
  	if ($TIMING == 1) {
		# Create batch file for tracer
		print "-----------------------------------------------------------------------------\n";
		print " Building script file for TRACE                                              \n";
		print "-----------------------------------------------------------------------------\n";

		# TRACE command line
		$line = "trce";
		# User options from config file
		foreach (@TRACEOPTIONS) {
			$line .= " ".$_;
		}
		# Input file
		$line .= " ".$CALLDIR."/par/".$IMP_NAME[0].".par.ncd";
		# .pcf file
		$line .= " ".$CALLDIR."/map/".$IMP_NAME[0].".pcf";
		# .ucf file
		$line .= " -ucf ".$CALLDIR."/constraints/gen/".$IMP_NAME[0].".gen.ucf";
		# Output file (text)
		$line .= " -o ".$CALLDIR."/trace/".$IMP_NAME[0].".twr";
		# Output file (XML)
		$line .= " -xml ".$CALLDIR."/trace/".$IMP_NAME[0].".twx";

		# Create batch file
		$TRACE_COMMAND = $line;
		$fileloc = convPath($CALLDIR."/".$IMP_NAME[0].".xil.trace");
		writeBatch($fileloc, "trace", $TRACE_COMMAND);

  	}



	# ----------------------------------------------------------------------------
  	# Run commands
  	unless ($DRY == 1) {
		if ($SYN == 1) {
			print "-----------------------------------------------------------------------------\n";
		  	print " Starting FPGA synthesis                                                     \n";
		  	print "-----------------------------------------------------------------------------\n";
		  	# Start XST and stop on error
		  	chdir("xst");
		  	$ret = systemCall($XST_COMMAND);
		  	chdir("..");
		  	if ($ret != 0) {
		    	return($ret);
		  	}
		}

		if ($PAR == 1) {
			print "-----------------------------------------------------------------------------\n";
		  	print " Starting NGDBUILD                                                           \n";
		  	print "-----------------------------------------------------------------------------\n";
		  	# Start NGDBUILD and stop on error
		  	chdir("ngdbuild");
		  	$ret = systemCall($NGDBUILD_COMMAND);
		  	chdir("..");
		  	if ($ret != 0) {
		    	return($ret);
		  	}

		  	print "-----------------------------------------------------------------------------\n";
		  	print " Starting MAP                                                                \n";
		  	print "-----------------------------------------------------------------------------\n";
		  	# Start MAP and stop on error
		  	chdir("map");
		  	$ret = systemCall($MAP_COMMAND);
		  	chdir("..");
		  	if ($ret != 0) {
		    	return($ret);
		  	}

		  	print "-----------------------------------------------------------------------------\n";
		  	print " Starting PAR                                                                \n";
		  	print "-----------------------------------------------------------------------------\n";
		  	# Start PAR and stop on error
		  	chdir("par");
		  	$ret = systemCall($PAR_COMMAND);
		  	chdir("..");
		  	if ($ret != 0) {
		    	return($ret);
		  	}

		  	print "-----------------------------------------------------------------------------\n";
		  	print " Starting BITGEN                                                             \n";
		  	print "-----------------------------------------------------------------------------\n";
		  	# Start BITGEN and stop on error
		  	chdir("bitgen");
		  	$ret = systemCall($BITGEN_COMMAND);
		  	chdir("..");
		  	if ($ret != 0) {
		    	return($ret);
		  	}
		}

		if ($TIMING == 1) {
			# Start batch file
		  	print "-----------------------------------------------------------------------------\n";
		  	print " Starting TRACE                                                              \n";
		  	print "-----------------------------------------------------------------------------\n";
		  	# Start TRACE and stop on error
		  	chdir("trace");
		  	$ret = systemCall($TRACE_COMMAND);
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
