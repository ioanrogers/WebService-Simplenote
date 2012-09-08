package WebService::Simplenote::Role::Logger;

# ABSTRACT: Common logging interface

use v5.10.1;
use Moo::Role;
use Log::Any qw//;

has logger => (
    is       => 'ro',
    #isa      => Object,
    lazy     => 1,
    default  => sub { return Log::Any->get_logger },
);

1;
