use Test::More qw(no_plan);
BEGIN {
  use lib qq"$ENV{MYDB_HOME}/lib";
  use lib qq"$ENV{MYDB_HOME}/usr/lib";
}

## First make sure we can find home
is (defined($ENV{MYDB_HOME}), 1, qq"MYDB_HOME is not defined, please set it with something like:
export MYDB_HOME=/some/path");
## Then try and load MyDb.pm
use_ok("MyDb");
## Check the health of the config
my $config = new MyDb(config_file => "$ENV{MYDB_HOME}/mydb.conf");
is(defined($config), 1, 'PRFConfig did not load properly.');
## If that worked, check the rest of the perl dependencies
MyDb::Resolve();
is($config->{database_name} ne 'test', 1, 'The database should not be test, did you set up your configuration');
is($config->{database_user} ne 'guest', 1, 'The database user should not be guest.');
is($config->{database_pass} ne 'guest', 1, 'The database user should not be guest.');
