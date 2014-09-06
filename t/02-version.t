use strict;
use warnings;

use Test::More;
use Dist::Zilla::Util::Test::KENTNL 1.003001 qw( dztest );
use Test::DZil qw( simple_ini );

my $test = dztest();
$test->add_file( 'dist.ini',
  simple_ini( [ 'Prereqs::Plugins', { ':version' => '1' } ], [ 'GatherDir', { ':version' => '2' } ], ) );
$test->build_ok;
$test->meta_path_deeply(
  '/prereqs/develop/requires/',
  [
    {
      'Dist::Zilla::Plugin::GatherDir'        => '2',
      'Dist::Zilla::Plugin::Prereqs::Plugins' => '1',
    }
  ]
);
note explain $test->builder->log_messages;
note explain $test->distmeta;

done_testing;

