package Algorithm::Tree::Diff;
use 5.008005;
use strict;
use warnings;
use Carp;
use Module::Load;
use Module::Loaded;

our $VERSION = "0.01";

use Exporter qw(import);
our @EXPORT_OK = qw(diff_tree);

sub diff_tree {
	my ($T1, $T2) = (shift, shift);
	my %opts = ref($_[0]) ? %{$_[0]} : @_;
	$opts{algo} ||= 'diffX';
	
	my $module = do {
		if ($opts{algo} =~ /^\+(.+)$/) {
			$1;
		} else {
			'Algorithm::Tree::Diff::' . $opts{algo};
		}
	};
	unless (is_loaded($module)) {
		eval { load $module; 1 } or croak 'Cannot load module: ' . $module;
	}

	no strict 'refs';
	return *{"${module}::diff_tree"}{CODE}->($T1, $T2, \%opts);
}

1;
__END__

=encoding utf-8

=head1 NAME

Algorithm::Tree::Diff - It's new $module

=head1 SYNOPSIS

    use Algorithm::Tree::Diff;

=head1 DESCRIPTION

Algorithm::Tree::Diff is ...

=head1 LICENSE

Copyright (C) Ichito Nagata.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Ichito Nagata E<lt>nagata.ichito@dena.jpE<gt>

=cut

