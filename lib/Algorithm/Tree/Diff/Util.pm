package Algorithm::Tree::Diff::Util;
use strict;
use warnings;
use utf8;
use parent 'Exporter';
use Module::Functions;
use URI::Escape qw(uri_escape);
use JSON::Pointer::Syntax qw(escape_reference_token);

our @EXPORT_OK = get_public_functions();

sub escape_token {
	my ($token) = @_;
    return escape_reference_token(uri_escape($token));

}

sub append_pointer_token {
    my ($path, $token, $raw) = @_;
    return $path . '/' . ($raw ? $token : escape_token($token));
}

sub pop_pointer_token {
	my ($path) = @_;
	my @tokens = JSON::Pointer::Syntax->tokenize($path);
	my $poped = pop(@tokens);
	$path = join('', map { '/' . escape_reference_token($_) } @tokens);
	return wantarray ? ($path, $poped) : $path;
}

sub pick {
	my ($array) = @_;
	return $array->[int(rand(scalar(@$array)))];
}

1;

