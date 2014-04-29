#!/usr/bin/env perl

use strict;
use warnings;
use Test::More import => ['!pass'];

use Dancer;
use Dancer::Test;

use lib 't/lib';
use TestApp;

response_status_is [GET => '/sru'], 200, "response for GET /sru is 200";

response_status_isnt [GET => '/sru'], 404, "response for GET /sru is not a 404";

my $res;
$res = dancer_response("GET", '/sru', {params => {version => "2.34", operation => "searchRetrieve"}});
like $res->{content}, qr/searchRetrieveResponse/, "Response ok";

done_testing 3;
