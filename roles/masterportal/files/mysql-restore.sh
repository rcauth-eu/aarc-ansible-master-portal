#! /bin/sh

MYSQL_USER=root
MYSQL_PASSWORD=

echo -ne "password for user $MYSQL_USER: "
stty -echo
read MYSQL_PASSWORD
stty echo


function restore() {
    echo "Restoring $1 (assume compressed)";
    (
        echo "SET AUTOCOMMIT=0;"
        echo "SET UNIQUE_CHECKS=0;"
        echo "SET FOREIGN_KEY_CHECKS=0;"
        gunzip -dc "$1"
        echo "SET FOREIGN_KEY_CHECKS=1;"
        echo "SET UNIQUE_CHECKS=1;"
        echo "SET AUTOCOMMIT=1;"
        echo "COMMIT;"
    ) | mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD"
}

restore "$1"

