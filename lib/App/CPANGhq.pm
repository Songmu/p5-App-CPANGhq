package App::CPANGhq;
use 5.008001;
use strict;
use warnings;

our $VERSION = "0.02";

use Config;
use CPAN::DistnameInfo;
use File::Basename qw/basename/;
use JSON;
use List::UtilsBy qw/max_by/;
use Module::Metadata;
use version 0.77 ();
use Getopt::Long ();
use Pod::Usage ();

our @MIRRORS = qw/http%www.cpan.org http%cpan.metacpan.org/;

use Class::Accessor::Lite::Lazy 0.03 (
    new     => 1,
    ro_lazy => {
        packages_file => sub {
            max_by { +(stat($_))[9] } #mtime
            grep {-f $_}
            map  {
                "$ENV{HOME}/.cpanm/sources/$_/02packages.details.txt";
            } @MIRRORS;
        },
        installed_base => sub { $Config{sitelibexp} },
        search_inc     => sub {
            my $d = shift->installed_base;
            [$d, "$d/$Config{archname}"];
        },
        meta_dir => sub {
            shift->installed_base . "/$Config{archname}/.meta";
        }
    },
);

## class methods
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


## object methods
sub clone_modules {
    my ($self, @modules) = @_;

    for my $module (@modules) {
        my $dist_path = $self->search_mirror_index($module);
        unless ($dist_path) {
            warn "skip $module: distribution is not found in packages file.\n";
            next;
        }

        my $d = CPAN::DistnameInfo->new($dist_path);
        my $dist_name = $d->dist;

        unless (Module::Metadata->new_from_module($module, inc => $self->search_inc)) {
            warn "skip $module: not installed in site_perl.\n";
            next;
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

    my $base = $self->meta_dir;
    my @dirs = glob "$base/$dist_name*";

    my @candidate_metas;
    for my $d (@dirs) {
        my $dirbase = basename $d;
        next unless $dirbase =~ m!\A\Q$dist_name\E-[^-]+\z!ms;

        my $meta_json = "$d/MYMETA.json";
        next unless -f $meta_json && -r $meta_json;

        my $meta = decode_json(do {
            local $/;
            open my $fh, '<', $meta_json or die $!;
            <$fh>
        });

        push @candidate_metas, $meta;
    }

    my $meta = max_by { version->parse($_->{version})->numify } @candidate_metas;

    $meta && $meta->{resources}{repository}{url};
}

sub search_mirror_index {
    my ($self, $module) = @_;

    my $packages_file = $self->packages_file or die 'no packages file found';
    open my $fh, '<', $packages_file or die $!;
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
=for stopwords ghq

=encoding utf-8

=head1 NAME

App::CPANGhq - Clone module source codes with ghq

=head1 SYNOPSIS

    use App::CPANGhq;
    App::CPANGhq->run(@ARGV);

=head1 DESCRIPTION

App::CPANGhq is to clone module sources with L<ghq|https://github.com/motemen/ghq>.

This is a backend module of L<cpan-ghq>.

B<THE SOFTWARE IS STILL ALPHA QUALITY. API MAY CHANGE WITHOUT NOTICE.>

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
