package Algorithm::Tree::Diff::Test::CaseGenerator;
use strict;
use warnings;
use utf8;
use Carp;
use Clone;
use Data::Dumper;
use JSON::Pointer;
use JSON::Patch;
use String::Random qw(random_regex);
use Algorithm::Tree::Diff::Util qw(append_pointer_token pop_pointer_token pick);

sub new {
	my ($class, %args) = @_;
	return bless {%args}, $class;
}

sub generate_tree {
	my ($self, $n, $d) = @_;
	$n ||= 10;
	$d ||= (1 << 30); # means inf

	my $root = $self->generate_value(1, 1, 0, 0);
	my %pid_table    = ($n => $root);
	my %pdepth_table = ($n => 0);
	$n--;

	while ($n) {
		my $value = $self->generate_value(4, 4, 15, 1);

		my @pids = grep { $pdepth_table{$_} < $d } keys %pid_table;
		my $pid = $pids[int(rand(scalar(@pids)))];
		my ($p, $pdepth) = ($pid_table{$pid}, $pdepth_table{$pid});

		if (ref($p) eq 'ARRAY') {
			push(@{ $p }, $value);
		} elsif (ref($p) eq 'HASH') {
			my $key = 'K' . scalar(keys %$p);
			$p->{$key} = $value;
		}
		if (ref($value) =~ /^ARRAY|HASH$/) {
			if ($pdepth + 1 < $d) {
				$pid_table{$n} = $value;
				$pdepth_table{$n} = $pdepth + 1;
			}
		}
		$n--;
	}

	return $root;
}

sub generate_value {
	my ($self, $ap, $hp, $sp, $up) = @_;
	
	my $val;
	my $rand = rand($ap + $hp + $sp + $up);
	if ($rand < $ap) {
		$val = [];
	} elsif ($rand < $ap + $hp) {
		$val = +{};
	} elsif ($rand < $ap + $hp + $sp) {
		$val = $self->generate_scalar(1, 1);
	} else {
		$val = undef;
	}
	return $val;
}

sub generate_scalar {
	my ($self, $nump, $strp) = @_;

	my $val;
	my $rand = rand($nump + $strp);
	if ($rand < $nump) {
		$val = int(rand(64));
	} else {
		$val = random_regex('[A-Z]{3}');
	}

	return $val;
}

# FIXME
sub changed_new_paths {
	my ($path, $doc, $delta) = @_;
	my ($cur_new_path, $new_new_path);
	my ($parent_path, $key) = pop_pointer_token($path);
	my $parent = JSON::Pointer->get($doc, $parent_path);
	if ($parent) {
		if (ref($parent) eq 'ARRAY') {
			$cur_new_path = append_pointer_token($parent_path, scalar(@$parent));
			$new_new_path = append_pointer_token($parent_path, (scalar(@$parent) + $delta));
			
		} elsif (ref($parent) eq 'HASH') {
			unless (exists($parent->{$key}) && $delta > 0) {
				$cur_new_path = append_pointer_token($parent_path, 'K' . scalar(keys %$parent));
				$new_new_path = append_pointer_token($parent_path, 'K' . (scalar(keys %$parent) + $delta));
			}
		}
	}
	return ($cur_new_path, $new_new_path);
}

sub patch {
	my ($self, $tree, $n) = @_;
	$n ||= 1;

	my $current = Clone::clone($tree);
	my @patches;
	while ($n) {
		my $patch = $self->generate_patch($current);
		next unless $patch;
		push(@patches, $patch);

		my $ctx = JSON::Patch->new(operations => [ $patch ])->patch($current);
		unless ($ctx->result) {
			croak 'Cannot apply patch: ' . Dumper $patch;
		}

		$current = $ctx->document;


		$n--;
	}
	return wantarray ? ($current, \@patches) : $current;
}

sub generate_patch {
	my ($self, $tree) = @_;

	my $rand = rand(3); # cardinality of operation
	if ($rand < 1) {
		return $self->generate_add_patch($tree);
	} elsif ($rand < 2) {
		return $self->generate_remove_patch($tree);
	} else {
		return $self->generate_move_patch($tree);
	}
}

sub generate_add_patch {
	my ($self, $tree) = @_;
	my (undef, $new_paths) = $self->list_paths($tree);
	my $path = pick($new_paths);
	my $value = pick([ 0, 1 ]) ?  $self->generate_value(0, 0, 1, 1) : $self->generate_tree(4);
	return +{ op => 'add', path => $path, value => $value };
}

sub generate_remove_patch {
	my ($self, $tree) = @_;
	my ($paths) = $self->list_paths($tree);
	return undef unless @$paths;
	my $path = pick($paths);
	return +{ op => 'remove', path => $path };
}

sub generate_move_patch {
	my ($self, $tree) = @_;
	my ($paths, $new_paths) = $self->list_paths($tree);
	return undef unless @$paths;
	my $from = pick($paths);

	# To avoid invalid moving, once apply a remove operation and then re-generate path lists
	# This is not efficient, but maa iiya.
	my $cloned = Clone::clone($tree);
	my $removed = JSON::Pointer->remove($tree, $from);
	($paths, $new_paths) = $self->list_paths($removed);

	my $path = pick([@$paths, @$new_paths]);
	return +{ op => 'move', from => $from, path => $path };
}

sub list_paths {
	my ($self, $tree, $cur, $opts) = @_;
	$cur ||= '';
	$opts ||= +{};

	my (@paths, @new_paths);
	push(@paths, $cur) if $opts->{self};

	if (ref($tree) eq 'ARRAY') {
		for (my $i = 0; $i < scalar(@$tree); $i++) {
			my ($sub_paths, $sub_new_paths) =
				$self->list_paths($tree->[$i], append_pointer_token($cur, $i), +{ %$opts, self => 1 });
			push(@paths, @$sub_paths);
			push(@new_paths, @$sub_new_paths);
		}
		push(@new_paths, append_pointer_token($cur, scalar(@$tree)));
	} elsif (ref($tree) eq 'HASH') {
		for my $k (sort keys %$tree) {
			my ($sub_paths, $sub_new_paths) =
				$self->list_paths($tree->{$k}, append_pointer_token($cur, $k), +{ %$opts, self => 1 });
			push(@paths, @$sub_paths);
			push(@new_paths, @$sub_new_paths);
		}
		push(@new_paths, append_pointer_token($cur, 'K' . scalar(keys %$tree)));
	}

	return wantarray ? (\@paths, \@new_paths) : \@paths;
}

1;

