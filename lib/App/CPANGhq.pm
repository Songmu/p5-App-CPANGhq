package App::CPANGhq;
use 5.008001;
use strict;
use warnings;

our $VERSION = "0.01";

use Config;
use CPAN::DistnameInfo;
use File::Basename;
use JSON;
use List::UtilsBy qw/max_by/;
use Module::Metadata;
use version 0.77;

sub run {
    my ($class, @argv) = @_;

    my @modules = @argv;
    my $self = $class->new;
    for my $module (@modules) {
        my $dist_path = $self->search_mirror_index($module);
        my $d = CPAN::DistnameInfo->new($dist_path);
        my $dist_name = $d->dist;

        unless (Module::Metadata->new_from_module($module)) {
            print "Installing $module\n";
            !system 'cpanm', '--notest', $module or die $!;
        }

        my $repo = $self->resolve_repo($dist_name);

        if ($repo) {
            !system 'ghq', 'get', $repo or warn $!;
        }
        else {
            warn "repository of $module have not found";
        }
    }
}

sub new {
    bless {}, shift;
}

sub resolve_repo {
    my ($self, $dist_name) = @_;

    my $base = "$Config{sitearchexp}/.meta";
    my @dirs = glob "$base/$dist_name*";

    my @candidate_dirs;
    for my $d (@dirs) {
        my $dirbase = basename $d;
        my ($version) = $dirbase =~ m!\A\Q$dist_name\E-([^-]+)\z!ms;
        next unless $version;
        push @candidate_dirs, [$d, $version];
    }

    my $dir = max_by { version->parse($_->[1]) } @candidate_dirs;
       $dir = $dir->[0];

    my $meta = "$dir/MYMETA.json";
    my $meta_info = decode_json(do {
        local $/;
        open my $fh, '<', $meta or die $!;
        <$fh>
    });

    $meta_info->{resources}{repository}{url};
}

our @MIRRORS = qw/http%www.cpan.org http%cpan.metacpan.org/;

sub packages_file {
    my $self = shift;

    $self->{packages_file} ||=
        max_by { +(stat($_))[9] } #mtime
        grep {-f $_}
        map  {
            "$ENV{HOME}/.cpanm/sources/$_/02packages.details.txt";
        } @MIRRORS;
}

sub search_mirror_index {
    my ($self, $module) = @_;

    open my $fh, '<', $self->packages_file or return;
    while (<$fh>) {
        if (my (undef, $tar_path) = $_ =~ m!^
            \Q$module\E
            \s+
            ([\w\.]+)  # version
            \s+
            (\S*)      # tar path
        !mx) {
            return $tar_path;
        }
    }
}


1;
__END__

=encoding utf-8

=head1 NAME

App::CPANGhq - It's new $module

=head1 SYNOPSIS

    use App::CPANGhq;

=head1 DESCRIPTION

App::CPANGhq is ...

=head1 LICENSE

Copyright (C) Songmu.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Songmu E<lt>y.songmu@gmail.comE<gt>

=cut

