package Algorithm::Tree::Diff::diffX::Node;
use strict;
use warnings;
use utf8;
use Carp; 

use Algorithm::Tree::Diff::Util qw(append_pointer_token);

# remove for performance
# use Class::Accessor::Lite (
# 	ro => [qw/
# 		id
# 		var
# 		type
# 		equal_key
# 		label
# 	/],
# 	#	key
# 	rw => [qw/
# 		parent
# 		children
# 	/],
# );

my $id = 1;
sub new {
	my ($class, %args) = @_;

	my $self = bless {
		id => $id++,
		var => $args{var},
		key => $args{key},
		parent => $args{parent},
		children => [],
	}, $class;

	$self->{type} = $self->_type;
	$self->{label} = ($self->is_scalar ? $self->{var} : '');

	my $key_comp = $self->{parent} && $self->{parent}->is_hash ? $self->{key} : '';
	$self->{equal_key} = join(':', $self->{type}, $key_comp, $self->{label});


	return $self;
}

sub move_to {
	my ($self, $new_parent, $key) = @_;
	if ($new_parent && $new_parent->is_hash && ! defined($key)) {
		croak 'key is required in hash container';
	}

	# remove
	if ($self->{parent}) {
		if ($new_parent && $new_parent == $self->{parent} && $key eq $self->{key}) {
			return (0);
		}
		my $cur_index = $self->{parent}->indexof($self);
		if ($self->{parent}->is_array) {
			# move to left
			for (my $i = $cur_index + 1; $i < $self->{parent}->child_count; $i++) {
				my $sibling = $self->{parent}->{children}->[$i];
				$sibling->key($sibling->key - 1);
			}
		}
		splice(@{ $self->{parent}->{children} }, $cur_index, 1);
	}

	my $replaced;

	# add
	if ($new_parent) {
		if ($new_parent->is_array) {
			if (defined($key)) {
				# insert
				# move to right
				for (my $i = $key; $i < $new_parent->child_count; $i++) {
					my $sibling = $new_parent->{children}->[$i];
					$sibling->key($sibling->{key} + 1);
				}
				splice(@{ $new_parent->{children} }, $key, 0, $self);
				$self->key($key);
			} else {
				# push into the last
			}
		} elsif ($new_parent->is_hash) {
			# TODO: tuning
			my @new_children;
			for my $child (@{ $new_parent->{children} }) {
				if ($child->{key} eq $key) {
					$child->{parent} = undef;
					$replaced = $child;
				} else {
					push(@new_children, $child);
				}
			}
			$new_parent->{children} = \@new_children;

			push(@{ $new_parent->{children} }, $self);
			$self->key($key);
		}

	}

	$self->{parent} = $new_parent;
	return (1, $replaced);
}

sub key {
	my $self = shift;
	if (@_) {
		$self->{key} = shift;
	}
	return $self->{key};
}

sub path {
	my $self = shift;
	my $fix = shift;
	if ($self->{fixed_path}) {
		return $self->{fixed_path};
	}
	if ($self->{parent}) {
		# key is already escaped
		my $path = append_pointer_token($self->{parent}->path, $self->{key}, 1);
		if ($fix) {
			$self->{fixed_path} = $path;
		}
		return $path;
	} else {
		return '';
	}
}

sub own_var {
	my $self = shift;
	return [] if $self->is_array;
	return {} if $self->is_hash;
	return $self->{var};
}

sub _type {
	my $self = shift;
	if (! defined($self->{var})) {
		return 'n';
	}
	my $ref = ref($self->{var});
	if ($ref eq 'ARRAY') {
		return 'a';
	} elsif ($ref eq 'HASH') {
		return 'h';
	} elsif (! $ref) {
		return 's';
	}
	croak 'Invalid type: ' . $ref;
}

sub is_array  { shift->{type} eq 'a' }
sub is_hash   { shift->{type} eq 'h' }
sub is_scalar { shift->{type} eq 's' }
sub is_null   { shift->{type} eq 'n' }

sub descendants {
	my $self = shift;
	my @d = ($self);
	push(@d, @{ $_->descendants }) for @{ $self->{children} };
	return \@d;
}

sub has_ancestor {
	my ($self, $ancestor) = @_;
	return 1 if $self == $ancestor;
	if ($self->{parent}) {
		return $self->{parent}->has_ancestor($ancestor);
	}
	return 0;
}

sub child_count { scalar(@{ shift->{children} }) }

sub indexof {
	my ($self, $child) = @_;

	my $i;
	my $cc = $self->child_count;
	for ($i = 0; $i < $cc; $i++) {
		last if $self->{children}->[$i] == $child;
	}
	if ($i == $cc) {
		return undef; # not found
	}
	return $i;
}

sub dump_node {
	my ($self, $depth, $dumped) = @_;
	$depth ||= 0;
	$dumped ||= '';
	$dumped .= "\t" for (1..$depth);
	$dumped .= sprintf('%s@%s (%s)', $self->{id}, $self->path, $self->{equal_key}) . "\n";
	$dumped = dump_node($_, $depth + 1, $dumped) for @{ $self->{children} };
	return $dumped;
}

1;

