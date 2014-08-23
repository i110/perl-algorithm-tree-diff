#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use Data::Dumper;
use File::Basename qw(basename);
use File::Spec;
use File::Slurp;
use FindBin;
use JSON::XS qw(decode_json);
use Time::HiRes;
use Algorithm::Tree::Diff qw(diff_tree);
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);

# my $algo = 'Naive';
my $algos = 'Naive,diffX';
GetOptions(
	"algorithms|a=s" => \$algos,
);
my @algos = split(',', $algos);

my $dir = File::Spec->catfile($FindBin::Bin, '..', 'generated', 'n5');
$ENV{DEBUG} = 0;

my @files = glob "$dir/*.json";
my $cnt = 0;
my $sums = +{};
# @files = splice(@files, 0, 10);
# @files = grep { $_ =~ /0NWmgy/ } @files;
print join("\t", qw(file algo msec length cost)), "\n";
for my $file (@files) {
	my $basename = basename $file;
	my $json = read_file($file);
	my $case = decode_json($json);

	warn join("\t", sprintf('(%4s/%4s)', ++$cnt, scalar(@files)), $basename);

	for my $algo (@algos) {

		my $st = Time::HiRes::time();
		my @script = diff_tree($case->{before}, $case->{after}, +{ algo => $algo });
		my $et = Time::HiRes::time();
		my $msec = ($et - $st) * 1000;

		my $cost = calc_script_cost(\@script);

		print join("\t", $basename, $algo, sprintf('%.2f', $msec), scalar(@script), $cost), "\n";
		$sums->{$algo} += $msec;
	}

	# warn
	# 	sprintf('(%4s/%4s) %s takes %d msec, and %d patches generated. cost = %d by %s',
	# 	++$cnt, scalar(@files), $basename, $msec, scalar(@script), $cost, $algo);
	# $sum += $msec;
}
# warn 'Total: ' . $sum / 1000 . ' sec';

sub calc_script_cost {
	my ($script) = @_;
	my $total_cost = 0;
	for my $patch (@$script) {
		my $cost;
		my $op = $patch->{op};
		if ($op eq 'add') {
			$cost = 2 + calc_value_cost($patch->{value});
		} elsif ($op eq 'remove') {
			$cost = 2;
		} elsif ($op eq 'move') {
			$cost = 3;
		} elsif ($op eq 'replace') {
			$cost = 2 + calc_value_cost($patch->{value});
		}
		$total_cost += $cost;
	}
	return $total_cost;
}

sub calc_value_cost {
	my ($value) = @_;
	my $cost = 1;

	if (ref($value) eq 'HASH') {
		for my $k (keys %$value) {
			$cost += calc_value_cost($value->{$k});
		}
	} elsif (ref($value) eq 'ARRAY') {
		for my $e (@$value) {
			$cost += calc_value_cost($e);
		}
	}

	return $cost;
}
