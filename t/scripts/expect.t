#!/usr/bin/env perl
# ex:ts=8 sw=4:
# The option-list gate for share/fuguvm/expect/
#
# Tcl reads a leading hyphen in a send argument as an option. A
# generated value, such as the root password, can start with a
# hyphen at random. The send then fails with "bad flag", and the
# install fails with it. The separator -- ends the option list, so
# every later argument is data.
#
# No test drives these scripts, because each one needs a live
# console. This gate reads them instead.

use v5.36;
use Test::More;
use FindBin qw($RealBin);

my $dir = "$RealBin/../../share/fuguvm/expect";

my @files = sort glob("$dir/*.exp");
ok( scalar @files, 'share/fuguvm/expect holds expect scripts' )
	or BAIL_OUT('no expect script to check');

# True when the option list of this argument text stays open, and
# the first data argument starts with a variable.
sub unguarded ($args) {
	my @token = split ' ', $args;

	while ( @token && $token[0] =~ /\A-/ ) {
		return 0 if $token[0] eq '--';
		shift @token;
	}

	return @token && $token[0] =~ /\A["{]?\$/ ? 1 : 0;
}

for my $path (@files) {
	my $name = $path =~ s{.*/}{}r;

	open my $fh, '<', $path or do {
		fail("$name is readable");
		next;
	};

	my @bad;
	while ( my $line = <$fh> ) {
		next if $line =~ /\A\s*#/;
		my ($args) = $line =~ /(?:\A|[^\w])(?:exp_)?send\s+(\S.*?)\s*\z/
			or next;
		push @bad, "$.: $line" if unguarded($args);
	}
	close $fh;

	is_deeply( \@bad, [],
		"$name closes the option list of every variable send" );
}

done_testing();
