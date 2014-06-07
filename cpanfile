requires 'CPAN::DistnameInfo';
requires 'Class::Accessor::Lite::Lazy', '0.03';
requires 'Getopt::Long';
requires 'JSON';
requires 'List::UtilsBy';
requires 'Module::CPANfile';
requires 'Module::Metadata';
requires 'Pod::Usage';
requires 'perl', '5.008001';
requires 'version', '0.77';

on configure => sub {
    requires 'CPAN::Meta';
    requires 'CPAN::Meta::Prereqs';
    requires 'Module::Build';
};

on test => sub {
    requires 'Test::More', '0.98';
};
