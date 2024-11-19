#!/bin/bash

db_name=$1
db_password=$2
hd=$3
cpu=$4
ram=$5
version=$6
domain=$7
port=$8
work_dir=/root/created/omeka

echo "DB_NAME: ${db_name}"
echo "DB_PASSWORD: ${db_password}"
echo "HD: ${hd}"
echo "CPU: ${cpu}"
echo "RAM: ${ram}"
echo "VERSION: ${version}"
echo "DOMAIN: ${domain}"
echo "PORT: ${port}"

read -p "Does this look OK? Press 'y' to confirm: " -r REPLY
if [ "$REPLY" = "y" ];
then
  echo "Proceeding..."
else
  echo "Aborting."
  exit
fi

# create DB, users, import file
echo "CREATE DATABASE ${db_name};" > ${work_dir}/${db_name}_create.sql
echo "CREATE USER '${db_name}'@'localhost' IDENTIFIED BY '${db_password}';" >> ${work_dir}/${db_name}_create.sql
echo "GRANT ALL PRIVILEGES ON ${db_name}.* TO '${db_name}'@'localhost';" >> ${work_dir}/${db_name}_create.sql
echo "FLUSH PRIVILEGES;" >> ${work_dir}/${db_name}_create.sql
mysql --defaults-file=/root/.my.cnf < ${work_dir}/${db_name}_create.sql

echo "DONE WITH DB!"

#CREATE DIRECTORIES
mkdir -p /var/www/${db_name}/{logs,files,config,themes,modules}

#COPY AND EDIT CONFIG FILE
cp -r ./config/* /var/www/${db_name}/config

sed -i "s/USER/${db_name}/g" /var/www/${db_name}/config/database.ini
sed -i "s/DBNAME/${db_name}/g" /var/www/${db_name}/config/database.ini
sed -i "s/PASSWORD/${db_password}/g" /var/www/${db_name}/config/database.ini

echo "DONE WITH OMEKA S DIRECTORIES!"

#APACHE CONF

cp -r ./instance.conf.template /etc/apache2/sites-available/${db_name}.conf
sed -i "s/INSTANCE/${db_name}/g" /etc/apache2/sites-available/${db_name}.conf
sed -i "s/XXXXX/${port}/g" /etc/apache2/sites-available/${db_name}.conf
sed -i "s/DOMAIN/${domain}/g" /etc/apache2/sites-available/${db_name}.conf
a2ensite ${db_name}
service apache2 restart

echo "DONE WITH APACHE!"
#--memory="4596m" --memory-reservation="4096m"
docker run --name ${db_name}-${ram} -dit --net=host --memory="${ram}m" --cpus="${cpu}" -v /var/www/${db_name}:/var/www/html/volume -v /run/mysqld/mysqld.sock:/run/mysqld/mysqld.sock sephirothkod/omeka-s:${version} ${port}
