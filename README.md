# NAME

Dancer::Plugin::Catmandu::SRU - SRU server backed by a searchable Catmandu::Store

# SYNOPSIS

    #!/usr/bin/env perl
     
    use Dancer;
    use Catmandu;
    use Dancer::Plugin::Catmandu::SRU;
     
    Catmandu->load;
    Catmandu->config;
     
    my $options = {};

    sru_provider '/sru', %$options;
     
    dance;

# DESCRIPTION

[Dancer::Plugin::Catmandu::SRU](https://metacpan.org/pod/Dancer::Plugin::Catmandu::SRU) is a Dancer plugin to provide SRU services for [Catmandu::Store](https://metacpan.org/pod/Catmandu::Store)-s that support
CQL (such as [Catmandu::Store::ElasticSearch](https://metacpan.org/pod/Catmandu::Store::ElasticSearch)). Follow the installation steps below to setup your own SRU server.

# REQUIREMENTS

In the examples below an ElasticSearch 1.7.2 [https://www.elastic.co/downloads/past-releases/elasticsearch-1-7-2](https://www.elastic.co/downloads/past-releases/elasticsearch-1-7-2) server
will be used:

    $ cpanm Dancer Catmandu::SRU Catmandu::Store::ElasticSearch

    $ wget https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-1.7.2.zip
    $ unzip elasticsearch-1.7.2.zip
    $ cd elasticsearch-1.7.2
    $ bin/elasticsearch

# RECORDS

Records stored in the Catmandu::Store can be in any format. Preferably the format should be easy to convert into an
XML format. At a minimum each record contains an identifier '\_id'. In the examples below we'll configure the SRU
to serve Dublin Core records:

    $ cat sample.yml
    ---
    _id: 1
    creator:
     - Musterman, Max
     - Jansen, Jan
     - Svenson, Sven
    title:
     - Test record
    ...

# CATMANDU CONFIGURATION

ElasticSearch requires a configuration file to map record fields to CQL terms. Below is a minimal configuration 
required to query for '\_id' and 'title' and 'creator' in the ElasticSearch collection:

    $ cat catmandu.yml
    ---
    store:
      sru:
        package: ElasticSearch
        options:
          index_name: sru
          bags:
            data:
              cql_mapping:
                default_index: basic
                indexes:
                  _id:
                    op:
                      'any': true
                      'all': true
                      '=': true
                      'exact': true
                    field: '_id'
                  creator:
                    op:
                      'any': true
                      'all': true
                      '=': true
                      'exact': true
                    field: 'creator'
                  title:
                    op:
                      'any': true
                      'all': true
                      '=': true
                      'exact': true
                    field: 'title'

# IMPORT RECORDS

With the Catmandu configuration files in place records can be imported with the [catmandu](https://metacpan.org/pod/catmandu) command:

    # Drop the existing ElasticSearch 'sru' collection
    $ catmandu drop sru

    # Import the sample record
    $ catmandu import YAML to sru < sample.yml

    # Test if the records are available in the 'sru' collection
    $ catmandu export sru

# DANCER CONFIGURATION

The Dancer configuration file 'config.yml' contains basic information for the OAI-PMH plugin to work:

    * store - In which Catmandu::Store are the metadata records stored
    * bag   - In which Catmandu::Bag are the records of this 'store' (use: 'data' as default)
    * cql_filter -  A CQL query to find all records in the database that should be made available to SRU
    * default_record_schema - The metadataSchema to present records in 
    * limit - The maximum number of records to be returned in each SRU request
    * maximum_limit - The maximum number of search results to return
    * record_schemas - An array of all supported record schemas
        * identifier - The SRU identifier for the schema (see L<http://www.loc.gov/standards/sru/recordSchemas/>)
        * name - A short descriptive name for the schema
        * fix - Optionally an array of fixes to apply to the records before they are transformed into XML
        * template - The path to a Template Toolkit file to transform your records into this format

Below is a sample minimal configuration for the 'sample.yml' demo above:

    charset: "UTF-8"
    plugins:
        'Catmandu::SRU':
            store: sru
            bag: data
            default_record_schema: dc
            limit: 200
            maximum_limit: 500
            record_schemas:
                -
                    identifier: "info:srw/schema/1/dc-v1.1"
                    name: dc
                    template: dc.tt

# METADATA FORMAT TEMPLATE

For each metadata format a Template Toolkit file needs to exist which translate [Catmandu::Store](https://metacpan.org/pod/Catmandu::Store) records 
into XML records.  The example below contains an example file to transform 'sample.yml' type records into 
SRU DC:

    $ cat dc.tt
    <srw_dc:dc xmlns:srw_dc="info:srw/schema/1/dc-schema"
               xmlns:dc="http://purl.org/dc/elements/1.1/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xsi:schemaLocation="info:srw/schema/1/dc-schema http://www.loc.gov/standards/sru/recordSchemas/dc-schema.xsd">
    [%- FOREACH var IN ['title' 'creator' 'subject' 'description' 'publisher' 'contributor' 'date' 'type' 'format' 'identifier' 'source' 'language' 'relation' 'coverage' 'rights'] %]
        [%- FOREACH val IN $var %]
        <dc:[% var %]>[% val | html %]</dc:[% var %]>
        [%- END %]
    [%- END %]
    </srw_dc:dc>

# START DANCER

If all the required files are available, then a Dancer application can be started. See the 'demo' directory of 
this distribution for a complete example:

      $ ls 
      app.pl  catmandu.yml  config.yml  dc.tt
      $ cat app.pl
      #!/usr/bin/env perl
       
      use Dancer;
      use Catmandu;
      use Dancer::Plugin::Catmandu::SRU;
       
      Catmandu->load;
      Catmandu->config;
       
      my $options = {};

      sru_provider '/sru', %$options;
       
      dance;

      # Start Dancer
      $ perl ./app.pl
    
      # Test queries:
      $ curl "http://localhost:3000/sru"
      $ curl "http://localhost:3000/sru?version=1.1&operation=searchRetrieve&query=(_id+%3d+1)"
      $ catmandu convert SRU --base 'http://localhost:3000/sru' --query '(_id = 1)'

# AUTHOR

Nicolas Steenlant, `<nicolas.steenlant at ugent.be>`

# CONTRIBUTOR

Vitali Peil, `<vitali.peil at uni-bielefeld.de>`

Patrick Hochstenbach, `<patrick.hochstenbach at ugent.be>`

# SEE ALSO

[SRU](https://metacpan.org/pod/SRU), [Catmandu](https://metacpan.org/pod/Catmandu), [Catmandu::Store::ElasticSearch](https://metacpan.org/pod/Catmandu::Store::ElasticSearch) , [Catmandu::SRU](https://metacpan.org/pod/Catmandu::SRU)

# LICENSE

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
