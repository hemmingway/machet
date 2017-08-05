#!/usr/bin/perl -w
#
# File       : utils.pl
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
package Machet::Utils;


use strict;
use warnings;
use Exporter 'import';

use B;
use Carp qw(croak);
use TOML::Parser 0.03;

our (@ISA, @EXPORT, @EXPORT_OK, $VERSION, @_NAMESPACE, $PARSER);


$VERSION = "0.97";

@ISA=qw(Exporter);
@EXPORT = qw(from_toml to_toml);
@EXPORT_OK=qw();
$PARSER = TOML::Parser->new(inflate_boolean  => sub { $_[0] });


##########################################################################################
# Check if a path is an absolute or relative path

sub check_absolute_path {
	my $OS = $MAIN::OS;
  	my $path;

  	# Function accepts only one parameter
  	unless (@_ == 1) {
    	die("checkAbsolutePath called with illegal number of arguments");
  	}

 	 # Store path
  	$path = $_[0];

  	if ($OS eq "WIN") {
    	# Check if path begins with drive letter
    	if ($path =~ m/^[a-zA-Z]:/) {
      		return (1);
    	}
    	else {
      		return (0);
    	}
  	}
  	else {
    	# Check if path begins with "/"
    	if ($path =~ m/^\//) {
      		return (1);
    	}
    	else {
      		return (0);
    	}
  	}
}



##########################################################################################
#  Expands a path with project base directory if path does not point to an
#  absolute location

sub expand_to_absolute_path {
	my $PROJECTBASE = $MAIN::PROJECTBASE;
  	my $path;

  	# Function accepts only one parameter
  	unless (@_ == 1) {
    	die("expandToAbsolutePath called with illegal number of arguments");
  	}

  	# Store path
  	$path = $_[0];

  	# Check if path is absolute or relative
  	unless (check_absolute_path($path)) {
    	# Expand to complete path
    	$path = $PROJECTBASE."/".$path;
  	}

  	return $path;
}


##########################################################################################
#  Wrapper for system() command
#   returns a usable exit code (system returns code from executed command and
#   from system command (i.e. sh, etc.) itself)

sub system_call {
	my $command;
  	my $ret;

  	# Function accepts only one parameter
  	unless (@_ == 1) {
    	die("systemCall called with illegal number of arguments");
  	}

  	# Store command
  	$command = $_[0];

	# Print the command, commit it
	print "> $command \n";

  	$ret = system("$command");

  	$ret = ($ret >> 8) | ($ret & 0xFF);

  	return($ret);
}



##########################################################################################
#  Creates shell script and batch file
#  Parameters:
#    1. location and name of file to create, file ending will be appended automatically
#    2. directory in which the command will be started
#    3. command to run

sub write_batch {

	my $VERBOSE = $MAIN::VERBOSE;

  	my $location;
  	my $dir;
  	my $command;

  	# Function accepts only three parameters
  	unless (@_ == 3) {
    	die("genBatch called with illegal number of arguments");
  	}

  	$location = $_[0];
  	$dir = $_[1];
  	$command = $_[2];

  	# Create Unix sh script
 	open(SHFILE, "> $location.sh") or die "Could not write sh script file!";
  	print SHFILE "#! /bin/sh\ncd ".$dir."\n".$command."\ncd ..\n";
  	close(SHFILE);
    printf ("  Wrote \"%s.sh\"\n", $location);

 	# Create Windows batch file
  	open(BATFILE, "> $location.bat") or die "Could not write batch file!";
  	print BATFILE "cd ".$dir."\n".$command."\ncd ..\n";
  	close(BATFILE);
    printf ("  Wrote \"%s.bat\"\n", $location);
 
}


##########################################################################################
####

sub to_toml {
    my $stuff = shift;
    local @_NAMESPACE = ();
    _to_toml($stuff);
}

sub _to_toml {
    my ($stuff) = @_;

    if (ref $stuff eq 'HASH') {
        my $res = '';
        my @keys = sort keys %$stuff;
        for my $key (grep { ref $stuff->{$_} ne 'HASH' } @keys) {
            my $val = $stuff->{$key};
            $res .= "$key = " . _serialize($val) . "\n";
        }
        for my $key (grep { ref $stuff->{$_} eq 'HASH' } @keys) {
            my $val = $stuff->{$key};
            local @_NAMESPACE = (@_NAMESPACE, $key);
            $res .= sprintf("[%s]\n", join(".", @_NAMESPACE));
            $res .= _to_toml($val);
        }
        return $res;
    } else {
        croak("You cannot convert non-HashRef values to TOML");
    }
}

sub _serialize {
    my $value = shift;
    my $b_obj = B::svref_2object(\$value);
    my $flags = $b_obj->FLAGS;

    return $value
        if $flags & ( B::SVp_IOK | B::SVp_NOK ) and !( $flags & B::SVp_POK ); # SvTYPE is IV or NV?

    my $type = ref($value);
    if (!$type) {
        return string_to_json($value);
    } elsif ($type eq 'ARRAY') {
        return sprintf('[%s]', join(", ", map { _serialize($_) } @$value));
    } elsif ($type eq 'SCALAR') {
        if (defined $$value) {
            if ($$value eq '0') {
                return 'false';
            } elsif ($$value eq '1') {
                return 'true';
            } else {
                croak("cannot encode reference to scalar");
            }
        }
        croak("cannot encode reference to scalar");
    }
    croak("Bad type in to_toml: $type");
}

my %esc = (
    "\n" => '\n',
    "\r" => '\r',
    "\t" => '\t',
    "\f" => '\f',
    "\b" => '\b',
    "\"" => '\"',
    "\\" => '\\\\',
    "\'" => '\\\'',
);
sub string_to_json {
    my ($arg) = @_;

    $arg =~ s/([\x22\x5c\n\r\t\f\b])/$esc{$1}/g;
    $arg =~ s/([\x00-\x08\x0b\x0e-\x1f])/'\\u00' . unpack('H2', $1)/eg;

    return '"' . $arg . '"';
}

sub from_toml {
    my $string = shift;
    local $@;
    my $toml = eval { $PARSER->parse($string) };
    return wantarray ? ($toml, $@) : $toml;
}


# Dummy
1;

__END__

