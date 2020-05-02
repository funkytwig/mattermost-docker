#!/bin/bash 
set -u # or set -o nounset

## DEFINE VARS ##

. .env # put configuration varable in here

date=`date "+%a_%d%b%Y_%H%M"`
seq=`date +%s` # julian seconds
datetime=`date "+%Y%m%d%H%M"`

backup_dir=$backup_path/${backup_name}_${seq}_F_${date}
new_backup=$backup_login:$backup_dir
latest_backup=$backup_path/${backup_name}_9999999999_current
user=`id -u -n`
basename=`basename $0 .sh`
logfile=/var/log/$basename.$user.log
lockfile=/tmp/${user}_${backup_name}_${basename}.lock

## FUNCTIONS ##

function log {
  logstamp=`date +%D_%R`
  log_text="$logstamp $basename $1"

  if [ $interactive -eq 1 ]; then
    echo $log_text
  fi
  echo "$logstamp $basename($$) $1" >> $logfile
}

## MAIN ##

log ""
log "START BACKUP"
log ""
log "Backup "
log "  from $what_to_backup"
log "  to   $new_backup"
log ""

if [ -f ${lockfile} ]; then
  log "Another script is running (${lockfile} exists), exiting"
  exit 1
fi

touch $lockfile

#sudo -u ben bash -c "docker-compose down"







if false; then
   
#sudo -u ben bash -c "docker exec -ti mattermost-docker_db_1 /bin/bash -c "pg_dump -U $DB_USER $DB" > $DB.sql"

docker exec -ti mattermost-docker_db_1 /bin/bash -c "pg_dump -U $DB_USER $DB" > $DB.sql

ls -lh $DB.sql


first_run=`ssh $backup_login "if [ -d $latest_backup ]; then echo 1; else echo 0; fi "`

if [ $first_run -eq 0 ]; then
  log "No $backup_login:$latest_backup, first time run"
  log ""
fi

if [ $first_run -eq 0 ]; then
  rsync -avh $what_to_backup/ $new_backup/
else
  rsync -avh $what_to_backup/ $new_backup/ --link-dest=$latest_backup
fi

log ""

if [ $? -eq 0 ]; then
  ssh $backup_login "touch -t $datetime $backup_dir"
  ssh $backup_login "rm $latest_backup"
  ssh $backup_login "ln -s $backup_dir $latest_backup"
  log "Backup worked :-)"
  ssh $backup_login "du --max-depth=1 -h $backup_dir"
else # failed so bacup probably only partial
  ssh $backup_login "rm -rf $backup_dir"
  log "Backup FAILED :-( - deleted $backup_dir"
fi



fi







# Rename last _F_ backup each houre to _H_ for backups > 2 hours old delete ones > 2 houres that are left 

log "Folding _F_ backups into hourly _H_ backup"

# set cut for DDMonYYYY
cut_from=${#backup_name}
let cut_from=$cut_from-2
let cut_to=$cut_from+11

# Get list of hours (DDMonYYYY) which have files older than 2 hours
hours=`ssh $backup_login \
  "find $backup_path -name \"*_F_*\" -maxdepth 1 -mmin +120|rev|cut -c$cut_from-$cut_to|rev|sort|uniq"`

del_list=`ssh $backup_login \
  "find $backup_path -name \"*_F_*\" -maxdepth 1 -mmin +120|sort"`

for hour in $hours; do
  oldest_file=`ssh $backup_login "ls -td ${backup_path}/*${hour}*|sort|tail -1"`
  rename_to=`echo $oldest_file| sed "s/_F_/_H_/g"`
  log "Rename $oldest_file to $rename_to"
   ssh $backup_login  "mv $oldest_file $rename_to"
done

for file in $del_list; do
  log "rm $file"
   ssh $backup_login "rm -rf $file"
done









# Rename last _H_ backup each day houre  to _D_ for backups > 2 days old delete ones > 2 days that are left 

log "Folding _H_ backups into daily _D_ backup"

# set cut for DDMonYYYY
cut_from=${#backup_name}
let cut_from=$cut_from+1
let cut_to=$cut_from+8

# Get list of days (DDMonYYYY) which have files older then 2 days
days=`ssh $backup_login \
  "find $backup_path -name \"*_H_*\" -maxdepth 1 -mtime +2|rev|cut -c$cut_from-$cut_to|rev|sort|uniq"`

del_list=`ssh $backup_login \
  "find $backup_path -name \"*_H_*\" -maxdepth 1 -mtime +2|sort"`

for day in $days; do
  oldest_file=`ssh $backup_login "ls -td ${backup_path}/*${day}*|sort|tail -1"`
  rename_to=`echo $oldest_file| sed "s/_H_/_D_/g"`
  log "Rename $oldest_file to $rename_to"
  ssh $backup_login  "mv $oldest_file $rename_to"
done

for file in $del_list; do
  log "rm $file"
  ssh $backup_login "rm -rf $file"
done














# sudo -u ben bash -c "docker-compose up -d"

rm $lockfile
