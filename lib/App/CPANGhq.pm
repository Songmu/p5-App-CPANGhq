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
use Getopt::Long ();
use Pod::Usage ();

sub run {
    my ($class, @argv) = @_;

    my ($opt, $argv) = $class->parse_options(@argv);
    my @modules = @$argv;

    if ($opt->{cpanfile}) {
        push @modules, $class->resolve_modules_from_cpanfile;
    }

    my $self = $class->new;

    $self->clone_modules(@modules);
}

sub parse_options {
    my ($class, @argv) = @_;

    my $parser = Getopt::Long::Parser->new(
        config => [qw/posix_default no_ignore_case bundling pass_through auto_help/],
    );

    local @ARGV = @argv;
    $parser->getoptions(\my %opt, qw/
        cpanfile
    /) or Pod::Usage::pod2usage(1);
    @argv = @ARGV;

    (\%opt, \@argv);
}

sub resolve_modules_from_cpanfile {
    my ($class, $file) = @_;

    require Module::CPANfile;
    my $cpanfile = Module::CPANfile->load($file);
    my $prereq_specs = $cpanfile->prereq_specs;

    my @modules;
    for my $phase (keys %$prereq_specs) {
        my $phase_of_prereqs = $prereq_specs->{$phase};
        my $requires_prereqs = $phase_of_prereqs->{requires};
        push @modules, keys %$requires_prereqs;
    }
    grep { $_ ne 'perl' } @modules;
}

sub new {
    bless {}, shift;
}

sub clone_modules {
    my ($self, @modules) = @_;

    for my $module (@modules) {
        my $dist_path = $self->search_mirror_index($module);
        my $d = CPAN::DistnameInfo->new($dist_path);
        my $dist_name = $d->dist;

        unless (Module::Metadata->new_from_module($module)) {
            print "Installing $module\n";
            !system 'cpanm', '--notest', $module or do {
                warn "Failed installing $module :" . ($! || '') . "\n";
                next;
            };
        }

        my $repo = $self->resolve_repo($dist_name);

        if ($repo) {
            !system 'ghq', 'get', $repo or do { warn $! if $! };
        }
        else {
            warn "Repository of $module is not found.\n";
        }
    }
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

App::CPANGhq - Clone module source codes with ghq

=head1 SYNOPSIS

    use App::CPANGhq;
    App::CPANGhq->run(@ARGV);

=head1 DESCRIPTION

App::CPANGhq is to clone module sources with C<ghq>.

This is a backend module of L<cpan-ghq>.

=head1 INSTALL

This module requires L<ghq|https://github.com/motemen/ghq> to be installed.

=head1 SEE ALSO

L<cpan-ghq>

=head1 LICENSE

Copyright (C) Songmu.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Songmu E<lt>y.songmu@gmail.comE<gt>

=cut

