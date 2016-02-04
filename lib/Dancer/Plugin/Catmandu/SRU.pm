package Dancer::Plugin::Catmandu::SRU;

=head1 NAME

Dancer::Plugin::Catmandu::SRU - SRU server backed by a searchable Catmandu::Store

=cut

our $VERSION = '0.0401';

use Catmandu::Sane;
use Dancer::Plugin;
use Dancer qw(:syntax);
use Catmandu;
use Catmandu::Util qw(:all);
use Catmandu::Fix;
use Catmandu::Exporter::Template;
use SRU::Request;
use SRU::Response;

sub sru_provider {
    my ($path) = @_;

    my $setting = plugin_setting;

    my $default_record_schema = $setting->{default_record_schema};

    my $record_schemas = $setting->{record_schemas};

    my $record_schema_map = {};
    for my $schema (@$record_schemas) {
        $schema = {%$schema};
        my $identifier = $schema->{identifier};
        my $name = $schema->{name};
        if (my $fix = $schema->{fix}) {
            $schema->{fix} = Catmandu::Fix->new(fixes => $fix);
        }
        $record_schema_map->{$identifier} = $schema;
        $record_schema_map->{$name} = $schema;
    }

    my $bag = Catmandu->store($setting->{store})->bag($setting->{bag});

    my $default_limit = $setting->{limit} // $bag->default_limit;
    my $maximum_limit = $setting->{maximum_limit} // $bag->maximum_limit;

    my $database_info = "";
    if ($setting->{title} || $setting->{description}) {
        $database_info .= qq(<databaseInfo>\n);
        for my $key (qw(title description)) {
            $database_info .= qq(<$key lang="en" primary="true">$setting->{$key}</$key>\n) if $setting->{$key};
        }
        $database_info .= qq(</databaseInfo>);
    }

    my $index_info = "";
    if ($bag->can('cql_mapping') and my $indexes = $bag->cql_mapping->{indexes}) { # TODO all Searchable should have cql_mapping
        $index_info .= qq(<indexInfo>\n);
        for my $key (keys %$indexes) {
            my $title = $indexes->{$key}{title} || $key;
            $index_info .= qq(<index><title>$title</title><map><name>$key</name></map></index>\n);
        }
        $index_info .= qq(</indexInfo>);
    }

    my $schema_info = qq(<schemaInfo>\n);
    for my $schema (@$record_schemas) {
        my $title = $schema->{title} || $schema->{name};
        $schema_info .= qq(<schema name="$schema->{name}" identifier="$schema->{identifier}"><title>$title</title></schema>\n);
    }
    $schema_info .= qq(</schemaInfo>);

    my $config_info = qq(<configInfo>\n);
    $config_info .= qq(<default type="numberOfRecords">$default_limit</default>\n);
    $config_info .= qq(<setting type="maximumRecords">$maximum_limit</setting>\n);
    $config_info .= qq(</configInfo>);

    get $path => sub {
        content_type 'xml';

        my $params = params('query');
        my $operation = $params->{operation} // 'explain';

        if ($operation eq 'explain') {
            my $request  = SRU::Request::Explain->new(%$params);
            my $response = SRU::Response->newFromRequest($request);

            my $transport   = request->scheme;
            my $database    = substr request->path, 1;
            my $host        = request->host; $host =~ s/:.+//;
            my $port        = request->port;
            $response->record(SRU::Response::Record->new(
                recordSchema => 'http://explain.z3950.org/dtd/2.1/',
                recordData   => <<XML,
<explain xmlns="http://explain.z3950.org/dtd/2.1/">
<serverInfo protocol="SRU" method="GET" transport="$transport">
<host>$host</host>
<port>$port</port>
<database>$database</database>
</serverInfo>
$database_info
$index_info
$schema_info
$config_info
</explain>
XML
            ));
            return $response->asXML;
        }
        elsif ($operation eq 'searchRetrieve') {
            my $request  = SRU::Request::SearchRetrieve->new(%$params);
            my $response = SRU::Response->newFromRequest($request);
            if (@{$response->diagnostics}) {
                return $response->asXML;
            }

            my $schema = $record_schema_map->{$request->recordSchema || $default_record_schema};
            unless ($schema) {
                $response->addDiagnostic(SRU::Response::Diagnostic->newFromCode(66));
                return $response->asXML;
            }
            my $identifier = $schema->{identifier};
            my $fix = $schema->{fix};
            my $template = $schema->{template};
            my $layout = $schema->{layout};
            my $cql = $params->{query};
            if ($setting->{cql_filter}) {
                #BUG in edismax Solr 3.6: beware of indexes being to close to the first parenthesis
                $cql = "( $setting->{cql_filter}) and ( $cql)";
            }

            my $first = $request->startRecord || 1;
            my $limit = $request->maximumRecords || $default_limit;
            if ($limit > $maximum_limit) {
                $limit = $maximum_limit;
            }

            my $hits = eval {
                $bag->search(
                    %{ $setting->{default_search_params} || {} },
                    cql_query    => $cql,
                    sru_sortkeys => $request->sortKeys,
                    limit        => $limit,
                    start        => $first - 1,
                );
            } or do {
                my $e = $@;
                if ($e =~ /^cql error/) {
                    $response->addDiagnostic(SRU::Response::Diagnostic->newFromCode(10));
                    return $response->asXML;
                }
                die $e;
            };

            $hits->each(sub {
                my $data = $_[0];
                my $metadata = "";
                my $exporter = Catmandu::Exporter::Template->new(
                    template => $template,
                    file     => \$metadata,
                    fix      => $fix,
                );
                $exporter->add($data);
                $exporter->commit;
                $response->addRecord(SRU::Response::Record->new(
                    recordSchema => $identifier,
                    recordData   => $metadata,
                ));
            });
            $response->numberOfRecords($hits->total);
            return $response->asXML;
        }
        else {
            my $request  = SRU::Request::Explain->new(%$params);
            my $response = SRU::Response->newFromRequest($request);
            $response->addDiagnostic(SRU::Response::Diagnostic->newFromCode(6));
            return $response->asXML;
        }
    };
}

register sru_provider => \&sru_provider;

register_plugin;

1;

=head1 SYNOPSIS

    use Dancer;
    use Dancer::Plugin::Catmandu::SRU;

    sru_provider '/sru';

=head1 CONFIGURATION

    plugins:
        'Catmandu::SRU':
            store: search
            bag: publicationItem
            cql_filter: 'submissionstatus exact public'
            default_record_schema: mods
            limit: 200
            maximum_limit: 500
            record_schemas:
                -
                    identifier: "info:srw/schema/1/mods-v3.3"
                    name: mods
                    fix: 
                      - publication_to_mods()
                    template: views/mods.tt

=head1 AUTHOR

Nicolas Steenlant, C<< <nicolas.steenlant at ugent.be> >>

=head1 CONTRIBUTOR

Vitali Peil, C<< <vitali.peil at uni-bielefeld.de> >>

=head1 SEE ALSO

L<SRU>, L<Catmandu>, L<Catmandu::Store>, L<Dancer::Plugin::Catmandu::OAI>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
