#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin";

use Google::SMS;
use Carp;

my $usage = <<"END_USAGE";
sendsms - Send SMS using Google Voice

Syntax: sendsms <number> <message>

		number  : a valid 10-digit US number
		message : multiple words, doesn't have to be quoted

END_USAGE

my ($number, $message);
$number  = shift;
$message = join ' ', @ARGV;
if (!defined $number || $number !~ /\d{10}/ || !defined $message || $message eq "") {
	croak $usage . "\n";
}

my $gv = Google::SMS->new();

$gv->login(USERNAME => 'xxx', PASSWORD => 'xxx', NUMBER   => '9999999999');

if ($gv->sms($number, $message)) {
	print "Message $message to $number sent successfully!\n";
} 
else {
	print "Message sending *failed*\n";
}
