#! /bin/sh
#
DIR="${DIR:-/var/preserve/dbbackup/MySQL}"
DATEMARK=`date '+%Y-%V-%A-%H%M'|tr A-Z a-z`
UTCTIME=`date -u '+%Y%m%d%H%M%SZ'`
DATEINFO=`date '+%Y-%m-%d %H:%M:%S %Z %z (%A, week %V)'`

. /etc/mysql

mkdir -p "$DIR"

MYSQL="mysql -u root --password="$PW""
MYSQLDUMP="mysqldump -u root --password="$PW" --single-transaction -q"

databases=`echo "show databases" | $MYSQL | egrep -v '^(Database|test)'`

for db in $databases
do
  ARCH="$DIR/db.$db.$DATEMARK.sql"
  (
  echo "-- Backup of database $db" ;
  echo "-- Dumped on $UTCTIME" ;
  echo "-- Compression: directly-compressed" ;
  echo "-- Dateinfo: $DATEINFO" ;
  $MYSQLDUMP --databases $db ) | gzip -c > ${ARCH}.gz
done

# remove dumpfiles older than 10 days
find "$DIR" -mtime +10 -type f -name \*.sql.gz -exec rm {} \;


