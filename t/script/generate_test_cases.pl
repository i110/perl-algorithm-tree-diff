#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use FindBin;
use File::Spec;
use lib File::Spec->catfile($FindBin::Bin, '..', '..', 'lib');
use lib File::Spec->catfile($FindBin::Bin, '..', 'lib');
use File::Path qw(mkpath);
use File::Temp;
use JSON::XS qw(encode_json);
use Algorithm::Tree::Diff::Test::CaseGenerator;

use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);

my ($N, $D, $P, $count, $outdir) = (10, undef, 3, 1, undef);
GetOptions(
	"n|n=i" => \$N,
	"max_depth|d=i" => \$D,
	"patch|p=i" => \$P,
	"count|c=i" => \$count,
	"outdir|o=s" => \$outdir
);
if ($outdir) {
	die "$outdir is not a Directory" if -f $outdir;
	mkpath $outdir unless -d $outdir;
}

my $generator = Algorithm::Tree::Diff::Test::CaseGenerator->new;
for (1..$count) {
	warn 'Generating.. ' . $_;
	my $before = $generator->generate_tree($N, $D);
	my ($after, $patches) = $generator->patch($before, $P);

	my $json = encode_json(+{
		before => $before,
		after => $after,
		patches => $patches,
	});

	if ($outdir) {
		my $fh = File::Temp->new(
    		TEMPLATE => 'XXXXXX',
    		DIR      => $outdir,
    		SUFFIX   => '.json',
			UNLINK   => 0,
    	);
		print $fh $json;
		close $fh;
	} else {
		print $json, "\n";
	}
}

