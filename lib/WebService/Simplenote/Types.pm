package WebService::Simplenote::Types;
use v5.10.1;
use strict;
use warnings;
use MooX::Types::MooseLike::Base;
use Scalar::Util qw/blessed/;
use DateTime qw//;
use Exporter 5.57 'import';
our @EXPORT_OK = ();

my $type_definitions = [
    {
        name       => 'WSSnSystemTag',
        subtype_of => 'Str',
        from       => 'MooX::Types::MooseLike::Base',
        test => sub {
            #my @tags = (qw/pinned unread markdown list/);
            #my %enum = map { $_ => undef } @tags;
            my %enum = (
                pinned   => undef,
                unread   => undef,
                markdown => undef,
                list     => undef,
            );
            exists $enum{$_[0]};
        },
        message => sub {"'$_[0]' is not a valid SystemTag!"},
    },
    {
        name       => 'WSSnDateTime',
        subtype_of => 'Object',
        from       => 'MooX::Types::MooseLike::Base',
        test => sub {
            if (blessed $_[0] && blessed $_[0] eq 'DateTime') {
                return 1;
            }
        },
        message => sub { $_[0] },
    },
];

sub to_DateTime {
    my $arg = shift; 

    # is it already a DateTime object?
    if (blessed $arg && blessed $arg eq 'DateTime') {
        return $arg;
    }
    
    # else an epoch
    my $dt = DateTime->from_epoch( epoch => $arg );

    return $dt;
}

MooX::Types::MooseLike::register_types($type_definitions, __PACKAGE__);

our %EXPORT_TAGS = ('all' => \@EXPORT_OK);

1;
