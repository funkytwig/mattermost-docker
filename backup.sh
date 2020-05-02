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
  logstamp=`date +%D_%H%M_%S`
  log_text="$logstamp $1"

  if [ $interactive -eq 1 ]; then
    echo $log_text
  fi

  echo "$logstamp $1" >> $logfile
}

function log_file {
  while read line
  do
    log "${line}"
  done < "$1"
}

function run_cmd {
  tmp_log=/tmp/$$_cmd.log

  log "$1"

  bash -c "$1" > ${tmp_log} 2>&1

  ret=$?

  if [ -f ${tmp_log} ]; then
    log_file ${tmp_log}
  fi

  if [ ${ret} -ne 0 ]; then
    log "${ret} : $1"
  fi

  return ${ret}
}

function run_remote {
  tmp_log=/tmp/$$_cmd.log

  log "$backup_login $1"

  ssh $backup_login "$1" > ${tmp_log} 2>&1

  ret=$?

  if [ -f ${tmp_log} ]; then
    log_file ${tmp_log}
  fi

  if [ ${ret} -ne 0 ]; then
    log "${ret} : $1"
  fi

  return ${ret}
}

## MAIN ##

script_start=`date +%s` # julian seconds

log ""
log "START BACKUP"
log "  from $what_to_backup"
log "  to   $new_backup"
log ""

if [ -f ${lockfile} ]; then
  log "Another script is running (${lockfile} exists), exiting"
  exit 1
fi

touch $lockfile

#sudo -u ben bash -c "docker-compose down"







if true; then
   
#sudo -u ben bash -c "docker exec -ti mattermost-docker_db_1 /bin/bash -c "pg_dump -U $DB_USER $DB" > $DB.sql"

# Backup database
    
docker exec -ti mattermost-docker_db_1 /bin/bash -c "pg_dump -U $DB_USER $DB" > $DB.sql

run_cmd "rm -rf $DB.sql.gz"
run_cmd "gzip --best $DB.sql"

# Do backup

first_run=`ssh $backup_login "if [ -d $latest_backup ]; then echo 1; else echo 0; fi "`

if [ $first_run -eq 0 ]; then
  log "No $backup_login:$latest_backup, first time run"
  log ""
fi

if [ $first_run -eq 0 ]; then
  run_cmd "rsync -avh $what_to_backup/ $new_backup/"
else
  run_cmd "rsync -avh $what_to_backup/ $new_backup/ --link-dest=$latest_backup"
fi

log ""

if [ $? -eq 0 ]; then
  run_remote "touch -t $datetime $backup_dir"
  run_remote "rm $latest_backup"
  run_remote "ln -s $backup_dir $latest_backup"
  log "Backup worked :-)"
  run_remote "du --max-depth=1 -h $backup_dir"
else # failed so bacup probably only partial
  ssh run_remote "rm -rf $backup_dir"
  log "Backup FAILED :-( - deleted $backup_dir"
fi



fi





# Fold Backups 

# Rename last _F_ backup each houre to _H_ for backups > 2 hours old delete ones > 2 houres that are left 

log ""
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
  run_remote  "mv $oldest_file $rename_to"
done

for file in $del_list; do
  run_remote "rm -rf $file"
done


# Rename last _H_ backup each day houre  to _D_ for backups > 2 days old delete ones > 2 days that are left 

log "Folding _H_ backups into daily _D_ backup"

# set cut for DDMonYYYY_HH
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
  run_remote  "mv $oldest_file $rename_to"
done

for file in $del_list; do
  run_remote "rm -rf $file"
done














# sudo -u ben bash -c "docker-compose up -d"

script_end=`date +%s` # julian seconds

run_time=$(($script_end-$script_start))

log ""
log "END, run time=$run_time seconds"

rm $lockfile
