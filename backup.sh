#!/bin/bash 
set -u # or set -o nounset

. .env # put configuration varable in here

date=`date "+%a_%d%b%Y_%H%M"`
seq=`date +%s` # julian seconds
datetime=`date "+%Y%m%d%H%M"`

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
  ssh $backup_login "touch -t $datetime $backup_dir"
  ssh $backup_login "rm $latest_backup"
  ssh $backup_login "ln -s $backup_dir $latest_backup"
  echo "Backup worked :-)"
  ssh $backup_login "du --max-depth=1 -h $backup_dir"
else # failed so bacup probably only partial
  ssh $backup_login "rm -rf $backup_dir"
  echo "Backup FAILED :-( - deleted $backup_dir"
fi

# Rename last _F_ to _D_ and delete other _F_

# set cut for DDMonYYYY
cut_from=${#backup_name}
let cut_from=$cut_from+1
let cut_to=$cut_from+8

# Get list of days (DDMonYYYY) which have files older then 2 days
days=`ssh $backup_login \
  "find $backup_path -name \"*_F_*\" -maxdepth 1 -mtime +2|rev|cut -c$cut_from-$cut_to|rev|sort|uniq"`

del_list=`ssh $backup_login \
  "find $backup_path -name \"*_F_*\" -maxdepth 1 -mtime +2|sort"`

for day in $days; do
  oldest_file=`ssh $backup_login "ls -td ${backup_path}/*${day}*|sort|tail -1"`
  rename_to=`echo $oldest_file| sed "s/_F_/_D_/g"`
  echo "Rename $oldest_file to $rename_to"
  ssh $backup_login  "mv $oldest_file $rename_to"
done

for file in $del_list; do
  echo "rm $file"
  ssh $backup_login "rm -rf $file"
done

# sudo -u ben bash -c "docker-compose up -d"
