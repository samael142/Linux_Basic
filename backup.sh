#!/bin/bash

PASSWORD="1234567890"

mkdir /~/mysql_bak
cd /~/mysql_bak

for s in mysql $(mysql --skip-column-names -u root -p${PASSWORD} -e "SHOW DATABASES"); do
    mkdir -p "$s"
    for t in $(mysql --skip-column-names -u root -p${PASSWORD} -e "SHOW TABLES FROM $s;"); do
        mysqldump --add-drop-table --single-transaction --quick -u root -p${PASSWORD} "$s" "$t" | gzip -1 > "$s/${t}.gz"
    done
done
