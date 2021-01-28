#!/usr/bin/perl
## ---------------------------------------------------- #
## File : check_mandator_licenses.pl
## Author : Ricardo Oliveira @ Eurotux SA
## Email : rmo@eurotux.com
## Date : 28/01/2021
## ---------------------------------------------------- #
##
## Plugin check for nagios / icinga, changed from Nagios::Plugin to Monitoring::Plugin
##
## License Information:
## This program is free software; you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation; either version 3 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program.  If not, see <http://www.gnu.org/licenses/>. 
##
## ---------------------------------------------------- # 

package DBI;
require DBI;
use Getopt::Long;
use Monitoring::Plugin;


$dbtype = "mysql";
$VERSION = 'v1.1';
$LICENSE=<<_LIC_;
This nagios plugin is free software, and comes with ABSOLUTELY 
NO WARRANTY. It may be used, redistributed and/or modified under 
the terms of the GNU General Public Licence (see 
http://www.fsf.org/licensing/licenses/gpl.txt).
_LIC_


$np = Monitoring::Plugin->new(  
  usage => "Usage: %s [--dbserver=<host>] [--dbname=<database name> ] [--dbuser=<database user>] "
      . "[ --dbpass=<database pass> ] ",
  version => $VERSION,
  license => $LICENSE,
  extra => "-------\nDeveloped by Eurotux Informatica SA (https://eurotux.com/)\ni-doit version 1.15.2 supported",
  blurb => "i-doit license monitoring plugin",
);

$np->add_arg(
  spec => 'dbserver=s',
  help => '--dbserver database server hostname',
  required => 1,
  default => 'localhost',
);

$np->add_arg(
  spec => 'dbname=s',
  help => '--dbname database name (usually idoit_system)',
  required => 1,
  default => 'idoit_system',
);

$np->add_arg(
  spec => 'dbuser=s',
  help => '--dbuser database server username (usually a read-only user)',
  required => 1,
);

$np->add_arg(
  spec => 'dbpass=s',
  help => '--dbpass database server password (self-explanatory)',
  required => 1,
);

$np->getopts;




# FETCH MANDATOR/TENANT LIST, CORRESPONDING DB AND CURRENTLY LICENSED OBJECTS
connectdb($np->opts->dbname) or $np->nagios_die( "Could not connect to database" );

my $query = "SELECT isys_mandator__id, isys_mandator__title, isys_mandator__db_name, isys_mandator__license_objects FROM isys_mandator";
my $sth=execsql($query) or $np->nagios_die( "Unable to execute query on idoit's master database" );
while (@data = $sth->fetchrow) {
	$MANDATORTITLEs{$data[0]}=$data[1];
	$MANDATORDBs{$data[0]}=$data[2];
	$MANDATORLicObjs{$data[0]}=$data[3];
};




# GET OBJECT COUNT FOR EACH MANDATOR/TENANT
foreach $m (keys %MANDATORDBs) {
	connectdb($MANDATORDBs{$m}) or $np->nagios_die("Could not connect to database" );

	my $queryC = "SELECT COUNT(isys_obj__id) AS count FROM isys_obj INNER JOIN isys_obj_type ON isys_obj__isys_obj_type__id = isys_obj_type__id WHERE (isys_obj__status = 2) AND isys_obj__id NOT IN (SELECT isys_obj__id FROM isys_obj WHERE isys_obj__const IN  ( 'C__OBJ__ROOT_LOCATION','C__OBJ__PERSON_GUEST','C__OBJ__PERSON_READER','C__OBJ__PERSON_EDITOR','C__OBJ__PERSON_AUTHOR','C__OBJ__PERSON_ARCHIVAR','C__OBJ__PERSON_ADMIN','C__OBJ__PERSON_GROUP_READER','C__OBJ__PERSON_GROUP_EDITOR','C__OBJ__PERSON_GROUP_AUTHOR','C__OBJ__PERSON_GROUP_ARCHIVAR','C__OBJ__PERSON_GROUP_ADMIN','C__OBJ__NET_GLOBAL_IPV4','C__OBJ__NET_GLOBAL_IPV6','C__OBJ__PERSON_API_SYSTEM','C__OBJ__RACK_SEGMENT__2SLOT','C__OBJ__RACK_SEGMENT__4SLOT','C__OBJ__RACK_SEGMENT__8SLOT' )) AND isys_obj__isys_obj_type__id NOT IN (SELECT isys_obj_type__id FROM isys_obj_type WHERE isys_obj_type__const IN ( 'C__OBJTYPE__RELATION','C__OBJTYPE__PARALLEL_RELATION','C__OBJTYPE__NAGIOS_SERVICE','C__OBJTYPE__NAGIOS_HOST_TPL','C__OBJTYPE__NAGIOS_SERVICE_TPL' ))";
	my $sthC = execsql($queryC) or $np->nagios_die( "Unable to execute query on tenant $MANDATORTITLEs{$$m}'s database" );
	while (@dataC = $sthC->fetchrow) {
		$MANDATORUSEDObjs{$m}=$dataC[0];
	}
}


# COMPARE CURRENT OBJECTCOUNT AND LICENSED OBJECTS
# OUTPUT USEFUL PERFORMANCE DATA
foreach $m (keys %MANDATORDBs) {
 if ( $MANDATORUSEDObjs{$m}  >= $MANDATORLicObjs{$m} ) {
 	$np->add_message( CRITICAL, qq/TENANT $MANDATORTITLEs{$m} (ID $m): $MANDATORUSEDObjs{$m} used objects of $MANDATORLicObjs{$m} available\n/ );
 }
}


foreach $m (keys %MANDATORDBs) {
$np->add_perfdata( 
label => $MANDATORTITLEs{$m},
value => $MANDATORUSEDObjs{$m},
);
}



($code, $message) = $np->check_messages();
$np->plugin_exit( $code, $message );




# FUNCTIONS

sub connectdb {
  $db = shift(@_);
  $data_source = "dbi:$dbtype:dbname=$db;host=".$np->opts->dbserver;
  $dbh = DBI->connect("$data_source", $np->opts->dbuser, $np->opts->dbpass)
	        || $np->plugin_exit (UNKNOWN, $0);
}
	
sub disconnectdb {
  $dbh->disconnect;
}
	
sub execsql {
 my ($sql_statement);
 ($sql_statement) = @_;
 my $sth = $dbh->prepare($sql_statement) || &error('prep_sql', $0);
  if ($dbh) {   
    if (defined($sql_statement)) {
		$sth->execute || &error('sql', $0); 
	} else {
	    $np->plugin_exit (UNKNOWN, $0);
	}
   } else {
	  $np->plugin_exit (UNKNOWN, $0);
   }

 return $sth;
}

