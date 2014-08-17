#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use File::Basename qw(basename);
use File::Spec;
use File::Slurp;
use FindBin;
use JSON::XS qw(decode_json);
use Time::HiRes;
use Algorithm::Tree::Diff qw(tree_diff);
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);

my $algo = 'diffX';
GetOptions(
	"algorithm|a=s" => \$algo,
);

my $dir = File::Spec->catfile($FindBin::Bin, '..', 'generated', 'n100');
$ENV{DEBUG} = 0;

my @files = glob "$dir/*.json";
my $cnt = 0;
my $sum = 0;
for my $file (@files) {
	my $basename = basename $file;
	my $json = read_file($file);
	my $case = decode_json($json);

	my $st = Time::HiRes::time();
	my @script = tree_diff($case->{before}, $case->{after}, +{ algo => $algo });
	my $et = Time::HiRes::time();
	my $msec = ($et - $st) * 1000;

	warn
		sprintf('(%4s/%4s) %s takes %d msec, and %d patches generated.',
		++$cnt, scalar(@files), $basename, $msec, scalar(@script));
	$sum += $msec;
}
warn 'Total: ' . $sum / 1000 . ' sec';
