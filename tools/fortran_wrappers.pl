#!/usr/bin/perl
#
# Processes the include/magma_z.h header file to generate
# control/magma_zf77.cpp     Fortran wrappers and
# control/magma_zfortran.F90 Fortran interfaces.
#
# @author Mark Gates

my $usage = "Usage: $0 [--wrappers|--interface] [-o output] magma_z.h\n";

use strict;
use Text::Balanced qw( extract_bracketed );
use Getopt::Long;
use Text::Wrap;

# --------------------
# declare constants and variables
my( $do_wrapper, $do_interface, $output,
	$pre, $return, $func, $is_gpu, $text, $rest, $comment,
	$funcf, $FUNCF,
	$wrapper, $call, $interface, $vars,
	$args, @args, $arg, $type, $base_type, $var, $first_arg, $is_ptr );

# ignore auxiliary functions which the user doesn't need
# ignore PLASMA functions (tstrf, incpiv)
# ignore misc functions in headers but not in library (larfg, getrf2, geqr2) (as of 2012-04-16)
my @ignore = qw(
	zlaqps
    zlatrd
    zlatrd2
    zlahr2
    zlahru
    zlabrd
    zlaex\d
    zlahr2_m
    zlahru_m
    
    ztstrf
    zgetrf_incpiv
    
    zlarfg
    zgetrf2
    zgeqr2
);
my $ignore = join( "|", @ignore );


print STDOUT "*********************************************\n";
print STDOUT "$ignore\n";


# map C base types to Fortran types
my %types = (
	'char'               => 'character       ',
	'int'                => 'integer         ',
	'magma_int_t'        => 'integer         ',
	'float'              => 'real            ',
	'double'             => 'double precision',
	'cuFloatComplex'     => 'complex         ',
	'cuDoubleComplex'    => 'complex*16      ',
	'magmaFloatComplex'  => 'complex         ',
	'magmaDoubleComplex' => 'complex*16      ',
);

# Fortran 90 has 132 line length limit, so wrap text
$Text::Wrap::separator = "  &\n";
$Text::Wrap::columns   = 90;
$Text::Wrap::unexpand  = 0;  # no tabs

# --------------------
# parse options
GetOptions(
	"wrappers"  => \$do_wrapper,
	"interface" => \$do_interface,
	"o=s"       => \$output,
) or die( "$!$usage" );

if ( not ($do_wrapper xor $do_interface) ) {
	die("Specify exactly one of --wrappers or --interface.\n$usage");
}
if ( $#ARGV != 0 ) {
	die("Specify exactly one header file as input.\n$usage");
}


# --------------------
# open output file and set as default for print
if ( $output ) {
	open( OUTPUT, ">$output" ) or die( $! );
	select OUTPUT;
}

# --------------------
# print header
if ( $do_wrapper ) {  #################### header for magma_zf77.cpp wrappers
	print <<EOT;
/*******************************************************************************
 *  This file is AUTOMATICALLY GENERATED by:
 *  $0 --wrappers $ARGV[0]
 *  Do not edit.
 ******************************************************************************/

#include <stdint.h>  // for uintptr_t

#include "magma.h"

/*
 * typedef comming from fortran.h file provided in CUDADIR/src directory
 * it will probably change with future release of CUDA when they use 64 bit addresses
 */
typedef size_t devptr_t;

#ifdef PGI_FORTRAN
#define DEVPTR(__ptr) ((magmaDoubleComplex*)(__ptr))
#else
#define DEVPTR(__ptr) ((magmaDoubleComplex*)(uintptr_t)(*(__ptr)))
#endif

#ifndef MAGMA_FORTRAN_NAME
#if defined(ADD_)
#define MAGMA_FORTRAN_NAME(lcname, UCNAME)  magmaf_##lcname##_
#elif defined(NOCHANGE)
#define MAGMA_FORTRAN_NAME(lcname, UCNAME)  magmaf_##lcname
#elif defined(UPCASE)
#define MAGMA_FORTRAN_NAME(lcname, UCNAME)  MAGMAF_##UCNAME
#endif
#endif

#ifndef MAGMA_GPU_FORTRAN_NAME
#if defined(ADD_)
#define MAGMA_GPU_FORTRAN_NAME(lcname, UCNAME)  magmaf_##lcname##_gpu_
#elif defined(NOCHANGE)
#define MAGMA_GPU_FORTRAN_NAME(lcname, UCNAME)  magmaf_##lcname##_gpu
#elif defined(UPCASE)
#define MAGMA_GPU_FORTRAN_NAME(lcname, UCNAME)  MAGMAF_##UCNAME##_GPU
#endif
#endif

#define PRECISION_z

#ifdef __cplusplus
extern "C" {
#endif

EOT
}
else {                #################### header for magma_zfortran.F90 interfaces
	print <<EOT;
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!  This file is AUTOMATICALLY GENERATED by:
!!  $0 --interface $ARGV[0]
!!  Do not edit.
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

#define PRECISION_z

module magma_zfortran

use magma_param

implicit none

!---- Fortran interfaces to MAGMA subroutines ----
interface

EOT
}


# --------------------
undef $/;  # slurp whole file
$_ = <>;

# strip out lines we don't want to copy
s/#ifndef MAGMA_Z_H\n//;
s/#define MAGMA_Z_H\n//;
s/#endif \/\* MAGMA_Z_H \*\/\n//;
s/#include .*\n//;
s/void zpanel_to_q.*\n//;
s/void zq_to_panel.*\n//;
s/#ifdef __cplusplus\nextern "C" {\n#endif\n//;
s/#ifdef __cplusplus\n}\n#endif\n//;
s/#define PRECISION_z\n//;
s/#undef PRECISION_z\n//;

while( $_ ) {
	if    ( s/^(\s*#[^\n]+\n+)// ) {
		# repeat pre-processor directives in both wrappers and interface output
		print $1;
	}
	elsif ( s|^(\s*//.*\n+)|| or
	        s|^(\s*/\*.*?\*/\n+)||s ) {
		# C++ style // and C-style /* ... */ comments
		# for Fortran output, prepend "! " to all lines
		$comment = $1;
		$comment =~ s/^/! /mg if ( $do_interface );
		print $comment;
	}
	elsif ( m/(.*?)^(magma_int_t|int|void)\s+magma_(\w+?)(_gpu)?\s*(\(.*)/ms ) {
		# parse magma function
		$pre    = $1;
		$return = $2;
		$func   = $3;
		$is_gpu = $4;
		$text   = $5;
		
		($args, $rest) = extract_bracketed( $text, '()' );
		$args =~ s/\n/ /g;
		$args =~ s/^\( *//;
		$args =~ s/ *\)$//;
		
		$funcf = "magmaf_$func$is_gpu";
		$FUNCF = $funcf;  #uc($funcf);
		if ( $is_gpu ) {
			$wrapper = sprintf( "#define %s MAGMA_GPU_FORTRAN_NAME( %s, %s )\n",
				${FUNCF}, $func, uc($func) );
		}
		else {
			$wrapper = sprintf( "#define %s MAGMA_FORTRAN_NAME( %s, %s )\n",
				${FUNCF}, $func, uc($func) );
		}
		
		my $match = $func =~ m/^($ignore)$/;
		print STDOUT "FUNC $func $match\n";
		if ( $func =~ m/^($ignore)$/ or $func =~ m/_mgpu/ ) {
			# ignore auxiliary functions and multi-GPU functions, since
			# we haven't dealt with passing arrays of pointers in Fortran yet
			$wrapper   = "";
			$interface = "";
		}
		elsif ( $func =~ m/get_\w+_nb/ ) {
			# special case for get_nb functions
			# is returning an int safe? otherwise, we could make these take an output argument.
			$wrapper  .= "magma_int_t ${FUNCF}( magma_int_t *m )\n{\n    return magma_$func( *m );\n}\n\n";
			$interface = "integer function $funcf( m )\n    integer :: m\nend function $funcf\n\n";
		}
		else {
			# build up wrapper and the call inside the wrapper, argument by argument
			$wrapper .= "void ${FUNCF}(\n    ";
			$call     = "magma_$func$is_gpu(\n        ";
			
			# build up Fortran interface and variable definitions, argument by argument
			$interface = "subroutine $funcf( ";
			$vars      = "";
			
			$first_arg = 1;
			@args = split( /, */, $args );
			foreach $arg ( @args ) {
				($type, $var) = $arg =~ m/^((?:const +)?\w+(?: *\*+)?) *(\w+[\[\]0-9]*)$/;
				if ( not $type ) {
					print "\nFAILED: func $func, arg $arg\n";
				}
				$base_type = $type;
				$base_type =~ s/\*//;
				$base_type =~ s/const +//;
				$base_type =~ s/^ +//;
				$base_type =~ s/ +$//;
				
				$is_ptr = ($type =~ m/\*/);
				if ( $is_ptr ) {
					unless( $first_arg ) {
						$wrapper   .= ",\n    ";
						$call      .= ",\n        ";
						$interface .= ", ";
					}
					if ( ($is_gpu and $var =~ m/^d\w+/) or $var eq "dT" ) {
						# for _gpu interfaces assume ptrs that start with "d" are device pointers
						# Also CPU interface for geqrf, etc., passes dT as device pointer (weirdly)
						$wrapper .= "devptr_t *$var";
						$call    .= "DEVPTR($var)";
						$vars    .= "    magma_devptr_t   :: $var\n";
					}
					else {
						$wrapper .= "$type$var";
						$call .= $var;
						if ( $var =~ m/^(info|iter|m)$/ ) {
							# special case for variables passed as pointers in C,
							# but are single values, not arrays.
							# e.g., see zhegvd and zcgesv
							$vars .= "    $types{$base_type} :: $var\n";
						}
						else {
							$vars .= "    $types{$base_type} :: $var(*)\n";
						}
					}
					$interface .= $var;
				}
				else {
					unless( $first_arg ) {
						$wrapper   .= ", ";
						$call      .= ", ";
						$interface .= ", ";
					}
					# convert scalars to pointers for Fortran interface
					$wrapper   .= "$type *$var";
					$call      .= "*$var";
					$interface .= $var;
					$vars      .= "    $types{$base_type} :: $var\n";
				}
				$first_arg = 0;
			}
			$wrapper .= " )\n{\n    $call );\n}\n\n";
			
			$interface .= " )\n";
			$interface  = Text::Wrap::wrap( "", "        ", $interface );
			$interface .= "${vars}end subroutine $funcf\n\n";
		}
		
		if ( $pre ) {
			print STDOUT "WARNING: ignoring unrecognized text before function: <<<\n$pre>>>\n";
		}
		
		if ( $do_wrapper ) {
			print $wrapper;
		}
		else {
			print $interface;
		}
		
		$_ = $rest;
		s/^ *;//;
	}
	else {
		print STDOUT "WARNING: ignoring unrecognized text at end of file: <<<\n$_>>>\n";
		last;
	}
	s/^\n+//;
}


# --------------------
# print footer
if ( $do_wrapper ) {  #################### footer for magma_zf77.cpp wrappers
	print <<EOT;

#ifdef __cplusplus
}
#endif
EOT
}
else {                #################### footer for magma_zfortran.F90 interfaces
	print <<EOT;
end interface

!---- Fortran-only subroutines (see $0 to edit) ----
contains

subroutine magmaf_zoff1d( ptrNew, ptrOld, inc, i)
    magma_devptr_t   :: ptrNew
    magma_devptr_t   :: ptrOld
    integer          :: inc, i

    ptrNew = ptrOld + (i-1) * inc * sizeof_complex_16
end subroutine magmaf_zoff1d

subroutine magmaf_zoff2d( ptrNew, ptrOld, lda, i, j)
    magma_devptr_t   :: ptrNew
    magma_devptr_t   :: ptrOld
    integer          :: lda, i, j

    ptrNew = ptrOld + ((j-1) * lda + (i-1)) * sizeof_complex_16
end subroutine magmaf_zoff2d

end module magma_zfortran
EOT
}
