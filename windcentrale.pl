#!/usr/bin/perl -w
use strict;

use Data::Dumper;
use LWP::UserAgent;
use HTTP::Request;
use IO::Socket;
use XML::Simple;
use JSON qw(decode_json);

# Config for graphite host
my $graph_host = '10.0.0.18';
my $graph_port = 2003;
my $tag="windcentrale"; 
my $scriptdir = "/data2/scripts/wind/";

# read XML with molen info
my $file = "$scriptdir/molens.xml";
my $xml = new XML::Simple;
my $molens = $xml->XMLin($file);
#print Dumper $molens;

# read XML with winddirection info
my $windmapfile = "$scriptdir/windmap.xml";
my $xml2 = new XML::Simple;
my $windmap = $xml2->XMLin($windmapfile);
#print Dumper $windmap;

# For my molen in list
for my $molen (keys %$molens ) {
	my $url1 = $molens->{$molen}{'url1'};
	my $url2 = $molens->{$molen}{'url2'};
	my $url3 = $molens->{$molen}{'url3'};

	my $ua = new LWP::UserAgent;
	$ua->agent("Perl API Client/1.0");
	my $request = HTTP::Request->new("GET" => $url1);
	my $response = $ua->request($request);
	my $xml=XMLin($response->content);

	$request = HTTP::Request->new("GET" => $url2);
	$response = $ua->request($request);
	my $string=$response->content;

	$request = HTTP::Request->new("GET" => $url3);
	$response = $ua->request($request);
	my $json= decode_json($response->content);

	#Calc from url
	my $totalwindshares = $xml->{'productie'}{'winddelen'};
	my $daysum =  $xml->{'productie'}{'subset'}[0]{'sum'};
	my $monthsum =  $xml->{'productie'}{'subset'}[1]{'sum'};
	my $weeksum =  $xml->{'productie'}{'subset'}[2]{'sum'};
	my $yearsum =  $xml->{'productie'}{'subset'}[3]{'sum'};

	my $daytotal = $daysum / $totalwindshares * 1000;
	my $monthtotal = $monthsum / $totalwindshares; 
	my $weektotal = $weeksum / $totalwindshares;
	my $yeartotal = $yearsum / $totalwindshares;

	#Calc from url2
	my @values = split /,/, $string;
	my $windpower = $values[0];
	my $totalyield = $values[1];
	my $myyield = $values[2];
	my $power=$values[3];

	my @windforcevalues = split / /, $values[0];
	my $winddirectionstring = $windforcevalues[0];
	my $windforce = $windforcevalues[1];
	my $winddirection = $windmap->{$winddirectionstring}{'int'};

	#Calc from url3
	my $runpercentage = $json->{'runPercentage'};
	my $kwhforecast = $json->{'kwhForecast'};
	my $yearpercentage = (( $yeartotal * $totalwindshares ) / $kwhforecast ) * 100;

	my $socket = IO::Socket::INET -> new(PeerAddr => $graph_host,
					  				    PeerPort => $graph_port,
									    Proto => "tcp",
									    Type => SOCK_STREAM) or die "Couldn't connect to $graph_host:$graph_port: $@ \n";
							
	my $epoch=time();
	print $socket "$tag.$molen.day $daytotal $epoch\n";
	print $socket "$tag.$molen.week $weektotal $epoch\n";
	print $socket "$tag.$molen.month $monthtotal $epoch\n";
	print $socket "$tag.$molen.year $yeartotal $epoch\n";
	print $socket "$tag.$molen.power $power $epoch\n";
	print $socket "$tag.$molen.windforce $windforce $epoch\n";
	print $socket "$tag.$molen.yield $myyield $epoch\n";
	print $socket "$tag.$molen.totalyield $totalyield $epoch\n";
	print $socket "$tag.$molen.direction $winddirection $epoch\n";
	print $socket "$tag.$molen.runpercentage $runpercentage $epoch\n";
	print $socket "$tag.$molen.yearpercentage $yearpercentage $epoch\n";
	close($socket);
}
