# NAME

Dancer::Plugin::Catmandu::SRU - SRU server backed by a searchable Catmandu::Store

# SYNOPSIS

    use Dancer;
    use Dancer::Plugin::Catmandu::SRU;

    sru_provider '/sru';

# CONFIGURATION

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

# AUTHOR

Nicolas Steenlant, `<nicolas.steenlant at ugent.be>`

# CONTRIBUTOR

Vitali Peil, `<vitali.peil at uni-bielefeld.de>`

# SEE ALSO

[SRU](https://metacpan.org/pod/SRU), [Catmandu](https://metacpan.org/pod/Catmandu), [Catmandu::Store](https://metacpan.org/pod/Catmandu::Store), [Dancer::Plugin::Catmandu::OAI](https://metacpan.org/pod/Dancer::Plugin::Catmandu::OAI)

# LICENSE

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
