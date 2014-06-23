package App::CPANGhq;
use 5.008001;
use strict;
use warnings;

our $VERSION = "0.02";

use Config;
use File::Basename qw/basename/;
use version 0.77 ();
use Getopt::Long ();
use Pod::Usage ();
use MetaCPAN::Client;

our @MIRRORS = qw/http%www.cpan.org http%cpan.metacpan.org/;

use Class::Accessor::Lite::Lazy 0.03 (
    new     => 1,
    ro_lazy => {
        client => sub { MetaCPAN::Client->new },
    }
);

## class methods
sub run {
    my ($class, @argv) = @_;

    my ($opt, $argv) = $class->parse_options(@argv);
    my @modules = @$argv;

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
        my $repo = $self->resolve_repo($module);
        if ($repo) {
            !system 'ghq', 'get', $repo or do { warn $! if $! };
        }
        else {
            warn "Repository of $module is not found.\n";
        }
    }
}

sub resolve_repo {
    my ($self, $name) = @_;

    my $repo;
    eval {
        my $module = $self->client->module($name);
        my $release = $self->client->release($module->distribution);
        if ($release->resources->{repository}) {
            $repo = $release->resources->{repository}{url};
        }
    };

    return $repo;
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
