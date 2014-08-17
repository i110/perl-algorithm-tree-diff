use strict;
use warnings;
use utf8;
use Test::Deep;
use Test::More;
use File::Basename qw(basename);
use File::Spec;
use File::Slurp;
use FindBin;
use JSON::Patch;
use JSON::XS qw(decode_json);

use Algorithm::Tree::Diff::diffX qw(tree_diff);

my $dir = File::Spec->catfile($FindBin::Bin, 'generated', 'n100');

$ENV{DEBUG} = 0;

my @files = glob "$dir/*.json";
# FIXME
# @files = splice(@files, 0, 10);
# @files = (File::Spec->catfile($dir, 'ce1gAX.json'));
for my $file (@files) {
	subtest $file => sub {
		my $basename = basename $file;
		# diag "Case " . $basename;
		my $json = read_file($file);
		my $case = decode_json($json);
		my @script = tree_diff($case->{before}, $case->{after});

diag explain $case if $ENV{DEBUG};
diag explain \@script if $ENV{DEBUG};
		my $ctx = JSON::Patch->new(operations => \@script)->patch($case->{before});
# diag explain $ctx->document if $ENV{DEBUG};
		ok($ctx->result, "Failed to patch on $basename");
		cmp_deeply($ctx->document, $case->{after}, "Failed to compare deeply on $basename");
	};
}

done_testing;

