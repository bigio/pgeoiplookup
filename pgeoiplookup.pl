#!/usr/bin/perl

# BSD 2-Clause License
# 
# Copyright (c) 2018, Giovanni Bechis
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
# 
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

use strict;
use warnings;

use Getopt::Std;
use IP::Country::DB_File;
use Locale::Country;

use constant IPV6_ADDRESS => qr/^\s*((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4})?:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:)))(%.+)?\s*$/ox;

my %opts;
my $dbfile;
my $dbtime;
my $configfile = $ENV{"HOME"} . "/.pgeoiplookup";
my $IPV6_ADDRESS = IPV6_ADDRESS;
my $host;
my $cc;

sub usage() {
	print "Usage: pgeoiplokup.pl [ -f database file] ip address\n";
	exit;
}

# read config file
if ( -f $configfile ) {
open(my $fh, $configfile) or die "Can't open $configfile: $!";
while ( ! eof($fh) ) {
        defined( $_ = <$fh> )
        or die "readline failed for $configfile: $!";
        chomp();
        unless ( /^#/ ) {
                $dbfile = $_;
        }
}
close($fh);
}

getopts('f:h', \%opts);
if ( defined $opts{'h'} or ( ( not defined $opts{'f'} and ( ! -f $configfile) ) ) ) {
	usage;
}

if ( ( defined $opts{'f'} ) and (! -f $opts{'f'} ) ) {
	print "Cannot open database file $opts{'f'}\n";
	exit;
} elsif ( ( defined $dbfile ) and (! -f $dbfile ) ) {
	print "Cannot open database file $dbfile\n";
	exit;
} else {
	if ( ( defined $opts{'f'} ) and ( -f $opts{'f'} ) ) {
		$dbfile = $opts{'f'};
	}
	$host = shift;
}
if ( not defined $host ) {
	usage;
}

my $ipcc = IP::Country::DB_File->new($dbfile);
if ( $host =~ /^$IPV6_ADDRESS$/ ) {
	$cc = $ipcc->inet6_atocc($host);
} else {
	$cc = $ipcc->inet_atocc($host);
	# If ipv4 fails retry with ipv6, it could be an ipv6-only host
	if ( ! defined $cc ) {
		$cc = $ipcc->inet6_atocc($host);
	}
}
my $country = code2country($cc);
if ( not defined $country ) {
  $country = "XX";
}
$dbtime = $ipcc->db_time();
# If $cc is "**" the ip address is in private range
if ( ( not defined $cc ) or ( $cc eq "**" ) ) {
	print "GeoIP version $dbtime: cannot detect country for host: $host\n";
} else {
	print "GeoIP version $dbtime: $cc, $country\n";
}
