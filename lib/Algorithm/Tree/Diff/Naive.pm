package Algorithm::Tree::Diff::Naive;
use strict;
use warnings;
use utf8;
use Carp;

use Exporter qw(import);
our @EXPORT_OK = qw(diff_tree);

use Algorithm::Tree::Diff::Util qw(append_pointer_token);

sub diff_tree {
	my ($T1, $T2) = @_;
	my $script = _diff($T1, $T2, '');
	return wantarray ? @$script : $script;
}

sub _diff {
	my ($T1, $T2, $path) = @_;

	if (ref($T1) ne ref($T2)) {
		return [ +{ op => 'replace', path => $path, value => $T2 } ];
	}

	if (ref($T1)) {
		if (ref($T1) eq 'HASH') {
			return _diff_hash($T1, $T2, $path);
		} elsif (ref($T1) eq 'ARRAY') {
			return _diff_array($T1, $T2, $path);
		} else {
			croak 'Invalid reference type : ' . ref($T1);
		}
	} else {
		if (defined($T1) && defined($T2)) {
			if ($T1 eq $T2) {
				return [];
			} else {
				return [ +{ op => 'replace', path => $path, value => $T2 } ];
			}
		} elsif (defined($T1) || defined($T2)) {
			return [ +{ op => 'replace', path => $path, value => $T2 } ];
		} else {
			return []; # undef and undef
		}
	}
}

sub _diff_hash {
	my ($T1, $T2, $path) = @_;
	my @patches;
	my $deleted = 0;

	for my $key (keys %$T1) {
		my $sub_path = append_pointer_token($path, $key);
		if (exists($T2->{$key})) {
			my $sub_patches = _diff($T1->{$key}, $T2->{$key}, $sub_path);
			push(@patches, @$sub_patches);
		} else {
			push(@patches, +{ op => 'remove', path => $sub_path }); 
			$deleted = 1;
		}
	}
	if (! $deleted && scalar(keys %$T1) == scalar(keys %$T2)) {
		return \@patches;
	}
	for my $key (keys %$T2) {
		if (! exists($T1->{$key})) {
			my $sub_path = append_pointer_token($path, $key);
			push(@patches, +{ op => 'add', path => $sub_path, value => $T2->{$key} });
		}
	}
	return \@patches;
}

sub _diff_array {
	my ($T1, $T2, $path) = @_;
	my @patches;

	my $T1_count = scalar(@$T1);
	my $T2_count = scalar(@$T2);

	my @iter = (0 .. ($T1_count > $T2_count ? $T1_count : $T2_count) - 1);
	if ($T1_count > $T2_count) {
		@iter = reverse @iter;
	}

	for my $i (@iter) {
		my $index_path = append_pointer_token($path, $i);
		if ($i < $T1_count && $i < $T2_count) {
			my $sub_patches = _diff($T1->[$i], $T2->[$i], $index_path);
			push(@patches, @$sub_patches);
		} elsif ($i < $T2_count) {
			push(@patches, +{ op => 'add', path => $index_path, value => $T2->[$i] });
		} elsif ($i < $T1_count) {
			push(@patches, +{ op => 'remove', path => $index_path });
		}
	}
	return \@patches;
}

1;

