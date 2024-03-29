requires 'perl', 'v5.10.1';

on test => sub {
    requires 'Test::More', '0.88';
    requires 'Dancer::Test', '1.3123';
    requires 'YAML';
};

requires 'Dancer', '1.3123';
requires 'Catmandu', '>=0.8014';
requires 'Catmandu::Exporter::Template', '0.11';
requires 'SRU', '1.01';
