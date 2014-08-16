package Algorithm::Tree::Diff::diffX;
use strict;
use warnings;
use utf8;

use Data::Dumper;


package Node;
use Carp;

use Class::Accessor::Lite (
	ro => [qw/
		var
		path
		equal_key
		label
		parent
		children
	/],
	rw => [qw/
		var
		path
		hash_key
		index
	/],
);

sub new {
	my ($class, $var, %args) = @_;

	my $self = bless {
		var => $var,
		children => [],
	}, $class;

	my $hash_key = $args{hash_key};
	$self->{equal_key} = join(':', $self->type, ($hash_key || ''), $self->label);
	$self->{label} = ($self->is_scalar ? $self->var : '');
	return $self;
}

sub id {
	my $self = shift;
return $self->path;
	return \$self + 0;
}

sub type {
	my $self = shift;
	if (! defined($self->var)) {
		return 'n';
	}
	my $ref = ref($self->var);
	if ($ref eq 'ARRAY') {
		return 'a';
	} elsif ($ref eq 'HASH') {
		return 'h';
	} elsif (! $ref) {
		return 's';
	}
	croak 'Invalid type: ' . $ref;
}

sub is_array  { shift->type eq 'a' }
sub is_hash   { shift->type eq 'h' }
sub is_scalar { shift->type eq 's' }
sub is_null   { shift->type eq 'n' }

sub descendants {
	my $self = shift;
	my @d = ($self);
	push(@d, @{ $_->descendants }) for @{ $self->children };
	return \@d;
}

sub child_count { scalar(@{ shift->children }) }

sub sibling {
	my ($self, $offset) = @_;
	unless ($self->parent && $self->parent->is_array) {
		croak 'Only nodes which are array elements can have siblings';
	}
	return $self->parent->children->[$self->index + $offset];
}

sub left_siblings {
	my ($self) = @_;
	my @s;
	my $cur = $self;
	while (my $next = $cur->sibling(-1)) {
		shift(@s, $next);
		$cur = $next;
	}
	return \@s;
}
sub right_siblings {
	my ($self) = @_;
	my @s;
	my $cur = $self;
	while (my $next = $cur->sibling(11)) {
		push(@s, $next);
		$cur = $next;
	}
	return \@s;
}

sub increment_index {
	my ($self, $delta) = @_;
	unless ($self->parent && $self->parent->is_array) {
		croak 'Only nodes which are element of array can be incremented/decremented';
	}
	my $newIndex = $self->index + $delta;
	if ($newIndex < 0 || $newIndex >= scalar(@{ $self->parent->children })) {
		croak 'Out of Range: ' . $newIndex;
	}
	$self->index($newIndex);
}

sub dump_node {
	my ($self, $depth) = @_;
	$depth ||= 0;
	print "\t" for (1..$depth);
	print sprintf('%s (%s)', $self->path, $self->equal_key), "\n";
	dump_node($_, $depth + 1) for @{ $self->children };
}

sub insert {
	my ($self, $parent, $key) = @_;
	

}

sub delete {
	my ($self) = @_;
	if ($self->parent->is_array) {
		$_->increment_index(-1) for @{ $self->right_siblings };
		splice(@{ $self->children }, $self->index, 1);
	} elsif ($self->parent->is_hash) {
		$self->parent
	}
}

sub generate_tree {
	my ($class, $cur, $parent, $path, $hash_key, $index) = @_;
	my $node = Node->new($cur,
		parent => $parent,
		path => $path,
		hash_key => $hash_key,
		index => $index,
	);

	if ($node->is_array) {
		for (my $i = 0; $i < scalar(@{ $node->var }); $i++) {
			push(@{ $node->children}, $class->generate_tree($node->var->[$i], $node, $path . '/' . $i, undef, $i));
		}
	} elsif ($node->is_hash) {
		for my $k (sort keys %{ $node->var }) {
			my $comp = $k;
			$comp =~ s!/!\/!g;
			push(@{ $node->children}, $class->generate_tree($node->var->{$k}, $node, $path . '/' . $comp, $k, undef));
		}
	}
	return $node;
}

package main;
use Data::Dumper;


sub diff {
	my ($T1, $T2) = @_;

	my ($mapping, $inverse) = (+{}, +{});
	

	my $R1 = Node->generate_tree($T1, undef, '');
	my $R2 = Node->generate_tree($T2, undef, '');

	my $t1_nodes = $R1->descendants;
	my $t2_nodes = $R2->descendants;

my $t1_id_to_nodes = +{ map { $_->id => $_ } @$t1_nodes };
my $t2_id_to_nodes = +{ map { $_->id => $_ } @$t2_nodes };


	my $t2_key_to_nodes = +{};
	for my $t2_node (@$t2_nodes) {
		push(@{ $t2_key_to_nodes->{$t2_node->equal_key} }, $t2_node);
	}

	# traverse
	_bfs($R1, sub {
		my $v = shift;
 		unless ($mapping->{$v->id}) {
			my @candidates = @{ $t2_key_to_nodes->{$v->equal_key} || [] };

			my $max;
			for my $w (@candidates) {
				next if $inverse->{$w->id};

				my $fragment_mapping = +{};
				_match_fragment($v, $w, $mapping, $inverse, $fragment_mapping);
				if (scalar(keys %$fragment_mapping) > scalar(keys %$max)) {
					$max = $fragment_mapping;
				}
			}
			for my $x (keys %$max) {
				my $y = $max->{$x};
				$mapping->{$x} = $y;
				$inverse->{$y} = $x;
			}
		}
	});
print Dumper $mapping;
print Dumper $inverse;

$R1->dump_node;
$R2->dump_node;

	print '######################################################', "\n";
	# for my $vid (keys %$mapping) {
	# 	my $v = $t1_id_to_nodes->{$vid};
	# 	my $w = $t2_id_to_nodes->{$mapping->{$vid}};
	# 	die unless $v && $w;

	# 	print $v->path, "\t", $w->path, "\n";
	# }
	my $script = _generate_script($R1, $R2, $mapping, $inverse, $t1_id_to_nodes);
	for my $line (@$script) {
		print join("\t", @$line), "\n";
	}
}

sub _match_fragment {
	my ($v, $w, $mapping, $inverse, $fragment_mapping) = @_;
	return if $mapping->{$v->id};
	return if $inverse->{$w->id};
	if ($v->equal_key eq $w->equal_key) {
		$fragment_mapping->{$v->id} = $w->id;
		my $i = 0;
		while (1) {
			my $vc = $v->children->[$i];
			my $wc = $w->children->[$i];
			last unless $vc && $wc;
			_match_fragment($vc, $wc, $mapping, $inverse, $fragment_mapping);
			$i++;
		}
	}
}

sub _bfs {
	my ($cur, $cb) = @_;

	my @q = ($cur);
	while (@q) {
		my $cur = shift(@q);
		$cb->($cur);
		push(@q, @{ $cur->children });
	}
}

sub _generate_script {
	my ($r1, $r2, $mapping, $inverse, $t1_id_to_nodes) = @_;

	my @script;

	# traverse r1 to delete
	_bfs($r1, sub {
		my $v = shift;

		unless (exists($mapping->{$v->id})) {
			$v->delete;
			push(@script, [ '-', $v->path ]);
		}
	});

	# traverse r2 to insert or move
	_bfs($r2, sub {
		my $w = shift;

		unless (exists($inverse->{$w->id})) {
			push(@script, [ '+', $w->path, $w->label ]);
			if ($w->parent->is_array) {
				# move to right
				$w->parent->children->[$_]->increment_index(1) for ($w->index .. scalar(@{ $w->parent->children }) - 1);
			}
			return;
		}
		
		if (exists($inverse->{$w->id})) {
			my $v = $t1_id_to_nodes->{$inverse->{$w->id}};
			if ($v->parent && $w->parent) {
				if ($mapping->{$v->parent->id} eq $w->parent->id) {
					push(@script, [ 'm', $v->path, $w->path ]);
					if ($w->parent->is_array) {
						if ($v->index < $w->index) {
							# move to right
							$v->parent->children->[$_]->increment_index(-1) for ($v->index + 1 .. $w->index);
						} else {
							# move to left
							$v->parent->children->[$_]->increment_index(1)  for ($w->index .. $v->index - 1);
						}
					}
				} else {
					push(@script, [ 'm', $v->path, $w->path ]);
					if ($w->parent->is_array) {
						# move to right
						$w->parent->children->[$_]->increment_index(1) for ($w->index .. scalar(@{ $w->parent->children }) - 1);
					}
				}

				if (
					$mapping->{$v->parent->id} ne $w->parent->id ||
					(
						($v->parent->is_array && $w->parent->is_array) && 
						($v->index != $w->index)
					)
				) {
					push(@script, [ 'm', $v->path, $w->path ]);
				}
			}
		} else {
			push(@script, [ '+', $w->path, $w->label ]);
		}
	});

	return \@script;
}


diff(
	+{
		a => 'hoge',
		b => 3,
		c => undef,
		d => [
			'nullpo',
			+{
				x => 3,
				y => undef, 
			},
			'umpo',
		],
		e => +{
			1 => 1,
		},
	},
	+{
		a => 'hoge',
		b => 3,
		c => undef,
		d => [
			+{
				x => 3,
				y => undef, 
			},
			'nullpo',
			'umpo',
		],
		e => +{
			1 => 2,
		},
	},
);

1;

