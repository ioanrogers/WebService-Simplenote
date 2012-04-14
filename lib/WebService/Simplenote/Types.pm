package WebService::Simplenote::Types;

# ABSTRACT Custom type library

use Moose::Util::TypeConstraints;

enum 'SystemTags', [qw/pinned unread markdown list/];

no Moose::Util::TypeConstraints;
