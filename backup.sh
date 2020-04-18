#!/bin/bash -x
set -u # or set -o nounset

. .env # put configuration varable in here

date=`date "+%a_%d%b%Y_%H%M"`
seq=`date +%s` # julian seconds

backup_dir=$backup_path/${backup_name}_${seq}_F_${date}
new_backup=$backup_login:$backup_dir
latest_backup=$backup_path/${backup_name}_9999999999_current

#sudo -u ben bash -c "docker-compose down"

echo
echo Backing up database $DB
echo

#sudo -u ben bash -c "docker exec -ti mattermost-docker_db_1 /bin/bash -c "pg_dump -U $DB_USER $DB" > $DB.sql"

docker exec -ti mattermost-docker_db_1 /bin/bash -c "pg_dump -U $DB_USER $DB" > $DB.sql

ls -lh $DB.sql
echo

echo Backing up $what_to_backup to $new_backup
echo

first_run=`ssh $backup_login "if [ -d $latest_backup ]; then echo 1; else echo 0; fi "`

if [ $first_run -eq 0 ]; then
  echo "No $backup_login:$latest_backup, first time run"
  echo
fi

if [ $first_run -eq 0 ]; then
  rsync -avh $what_to_backup/ $new_backup/
else
  rsync -avh $what_to_backup/ $new_backup/ --link-dest=$latest_backup
fi

echo

if [ $? -eq 0 ]; then
  ssh $backup_login "rm $latest_backup"
  ssh $backup_login "ln -s $backup_dir $latest_backup"
  echo "Backup worked :-)"
  ssh $backup_login "du --max-depth=1 -h $backup_dir"
else # failed so bacup probably only partial
  ssh $backup_login "rm -rf $backup_dir"
  echo "Backup FAILED :-( - deleted $backup_dir"
fi

# sudo -u ben bash -c "docker-compose up -d"
