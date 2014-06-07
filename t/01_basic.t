use strict;
use warnings;
use utf8;
use Test::More;

use App::CPANGhq;

my $cpan_ghq = App::CPANGhq->new(
    packages_file => 't/data/02packages.details.txt',
    meta_dir      => 't/data/meta',
);

isa_ok $cpan_ghq, 'App::CPANGhq';
is $cpan_ghq->search_mirror_index('Riji'), 'S/SO/SONGMU/Riji-0.0.11.tar.gz';
is $cpan_ghq->search_mirror_index('Riji::CLI'), 'S/SO/SONGMU/Riji-0.0.11.tar.gz';
is $cpan_ghq->resolve_repo('Riji'), 'dummy0.0.11';

done_testing;
