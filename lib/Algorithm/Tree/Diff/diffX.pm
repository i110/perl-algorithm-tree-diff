package Algorithm::Tree::Diff::diffX;
use strict;
use warnings;
use utf8;

use Exporter qw(import);
our @EXPORT_OK = qw(diff_tree);

use Algorithm::Tree::Diff::diffX::Node;
use Algorithm::Tree::Diff::Util qw(escape_token);

sub diff_tree {
	my ($T1, $T2) = @_;

	my ($mapping, $inverse) = (+{}, +{});
	

	my $R1 = _build_tree($T1);
	my $R2 = _build_tree($T2);

	# roots must be match
	unless ($R1->{equal_key} eq $R2->{equal_key}) {
		return undef;
	}

	my $t1_nodes = $R1->descendants;
	my $t2_nodes = $R2->descendants;

	my $t1_id_to_nodes = +{ map { $_->{id} => $_ } @$t1_nodes };
	my $t2_id_to_nodes = +{ map { $_->{id} => $_ } @$t2_nodes };

	my $t2_key_to_nodes = +{};
	for my $t2_node (@$t2_nodes) {
		push(@{ $t2_key_to_nodes->{$t2_node->{equal_key}} }, $t2_node);
	}

	# traverse
	_bfs($R1, sub {
		my $v = shift;
 		return if defined($mapping->{$v->{id}});

		my $max_fragment;

		if ($v == $R1) {
			# root can only match with root
			$max_fragment = +{ $R1->{id} => $R2->{id} };
		} else {
			my @candidates = @{ $t2_key_to_nodes->{$v->{equal_key}} || [] };

			for my $w (@candidates) {
				next if defined($inverse->{$w->{id}});

				my $fragment_mapping = +{};
				_match_fragment($v, $w, $mapping, $inverse, $fragment_mapping);
				if (scalar(keys %$fragment_mapping) > scalar(keys %$max_fragment)) {
					$max_fragment = $fragment_mapping;
				}
			}
		}

		for my $x (keys %$max_fragment) {
			my $y = $max_fragment->{$x};
			$mapping->{$x} = $y;
			$inverse->{$y} = $x;
		}
	});

	my $script = _generate_script($R1, $R2, $mapping, $inverse, $t1_id_to_nodes, $t2_id_to_nodes);
	return wantarray ? @$script : $script;
}

sub _match_fragment {
	my ($v, $w, $mapping, $inverse, $fragment_mapping) = @_;
	return if defined($mapping->{$v->{id}});
	return if defined($inverse->{$w->{id}});
	# TODO: uncommentout
	# return unless defined($v->{var}) && defined($w->{var});
	if ($v->{equal_key} eq $w->{equal_key}) {
		$fragment_mapping->{$v->{id}} = $w->{id};
		my $i = 0;
		while (1) {
			my $vc = $v->{children}->[$i];
			my $wc = $w->{children}->[$i];
			last unless $vc && $wc;
			_match_fragment($vc, $wc, $mapping, $inverse, $fragment_mapping);
			$i++;
		}
	}
}

sub _dump_mapping {
	my ($m, $from_id_to_nodes, $to_id_to_nodes) = @_;
	my $dumped = '';
	my @keys = sort keys %$m;
	for my $id (@keys) {
		my $from = $from_id_to_nodes->{$id};
		my $to   = $to_id_to_nodes->{$m->{$id}};
		$dumped .= 'mapped ' . join(' => ' , map { sprintf('%s (%s)', $_->{id}, $_->path) } ($from, $to)) . "\n";
	}
	return $dumped;
}

sub _build_tree {
	my ($cur, $parent, $key) = @_;
	my $node = Algorithm::Tree::Diff::diffX::Node->new(
		var => $cur,
		key => $key,
		parent => $parent,
	);

	if ($node->is_array) {
		for (my $i = 0; $i < scalar(@{ $node->{var} }); $i++) {
			push(@{ $node->{children}}, _build_tree($node->{var}->[$i], $node, $i));
		}
	} elsif ($node->is_hash) {
		my @sorted = sort keys %{ $node->{var} };
		for my $k (@sorted) {
			$k = escape_token($k);
			push(@{ $node->{children}}, _build_tree($node->{var}->{$k}, $node, $k));
		}
	}
	return $node;
}


sub _bfs {
	my ($cur, $cb, $right_to_left) = @_;

	my @q = ($cur);
	while (@q) {
		my $cur = shift(@q);
		my $stop = 0;
		$cb->($cur, \$stop);
		unless ($stop) {
			my @nexts = @{ $cur->{children} };
			@nexts = reverse @nexts if $right_to_left;
			push(@q, @nexts);
		}

	};
}

sub _remove_all_descendants_mapping {
	my ($node, $mapping, $inverse) = @_;
	my $descendants = $node->descendants;
	for my $desc (@$descendants) {
		if (my $correspond_id = $mapping->{$desc->{id}}) {
			delete $mapping->{$desc->{id}};
			delete $inverse->{$correspond_id};
		}
	}

}

sub _generate_and_map_node {
	my ($w, $mapping, $inverse, $t1_id_to_nodes, $offset) = @_;

	my $var = $w->own_var;

	my $new_node = Algorithm::Tree::Diff::diffX::Node->new(
		var => $w->{var},
		key => $w->{key},
		parent => undef,
	);

	my $new_parent = $t1_id_to_nodes->{$inverse->{$w->{parent}->{id}}} or die 'assertion';
	my $key = $w->{key};
	if ($new_parent->is_array && $offset) {
		$key -= $offset;
	}
	# my ($success, $replaced) = $new_node->move_to($new_parent, $w->{key});
	my ($success, $replaced) = $new_node->move_to($new_parent, $key);

	my $op = 'add';
	if ($replaced) {
		$op = 'replace';
		_remove_all_descendants_mapping($replaced, $mapping, $inverse);
	}

	$mapping->{$new_node->{id}} = $w->{id};
	$inverse->{$w->{id}} = $new_node->{id};
	$t1_id_to_nodes->{$new_node->{id}} = $new_node;

	my $child_offset = 0;
	for my $child (@{ $w->{children} }) {
		if (exists($inverse->{$child->{id}})) {
			$child_offset++;
		} else {
			my (undef, $child_var) = _generate_and_map_node($child, $mapping, $inverse, $t1_id_to_nodes, $child_offset);
			if ($w->is_array) {
				push(@$var, $child_var);
			} elsif ($w->is_hash) {
				$var->{$child->{key}} = $child_var;
			}
		}
	}

	return ($op, $var);
}

sub _generate_script {
	my ($r1, $r2, $mapping, $inverse, $t1_id_to_nodes, $t2_id_to_nodes) = @_;
# use Test::More;
# diag '################################################';
# diag $r1->dump_node;
# diag $r2->dump_node;
# diag _dump_mapping($mapping, $t1_id_to_nodes, $t2_id_to_nodes);

	my @script;

	# add, replace and move
	_bfs($r2, sub {
		my $w = shift;
		return unless $w->{parent};

		# insert
		unless (exists($inverse->{$w->{id}})) {

			# my $new_node = Algorithm::Tree::Diff::diffX::Node->new(
			# 	var => $w->{var},
			# 	key => $w->{key},
			# 	parent => undef,
			# );

			# my $new_parent = $t1_id_to_nodes->{$inverse->{$w->{parent}->{id}}} or die 'assertion';
			# my ($success, $replaced) = $new_node->move_to($new_parent, $w->{key});

			# my $op = 'add';
			# if ($replaced) {
			# 	$op = 'replace';
			# 	_remove_all_descendants_mapping($replaced, $mapping, $inverse);
			# }


			# $mapping->{$new_node->{id}} = $w->{id};
			# $inverse->{$w->{id}} = $new_node->{id};
			# $t1_id_to_nodes->{$new_node->{id}} = $new_node;

# my $var = $w->own_var;
			my ($op, $var) = _generate_and_map_node($w, $mapping, $inverse, $t1_id_to_nodes);

			push(@script, +{ op => $op, path => $w->path(1), value => $var });
			return;
		}

		# move
		my $v = $t1_id_to_nodes->{$inverse->{$w->{id}}};
		return unless $v->has_ancestor($r1);
		if ($v->{parent} && $w->{parent}) {
			if ((! $mapping->{$v->{parent}->{id}}) || ($mapping->{$v->{parent}->{id}} ne $w->{parent}->{id})) {
				# parent is not matching

				my $new_parent = $t1_id_to_nodes->{$inverse->{$w->{parent}->{id}}}
					or die 'Corresponding parent is not found';

				my $current_path = $v->path;
				my ($success, $replaced) = $v->move_to($new_parent, $w->{key});
				if ($replaced) {
					_remove_all_descendants_mapping($replaced, $mapping, $inverse);
				}
				
				push(@script, +{ op => 'move', from => $current_path, path => $w->path(1) });

			} elsif ($v->{parent}->is_array) { # ignore hash (unordered)
				# parent is matched, but position is not

				my $current_path = $v->path;
				my ($success) = $v->move_to($v->{parent}, $w->key);
				if ($success) {
					push(@script, +{ op => 'move', from => $current_path, path => $w->path(1) });
				}
			}
		}

	});

	# remove
	_bfs($r1, sub {
		my ($v, $stop) = @_;
		unless (exists($mapping->{$v->{id}})) {
			my $current_path = $v->path;
			my ($success) = $v->move_to(undef);
			if ($success) {
				delete $t1_id_to_nodes->{$v->{id}};
				push(@script, +{ op => 'remove', path => $current_path });
				$$stop = 1;
			}
		}
	}, 1);

	return \@script;
}

1;

