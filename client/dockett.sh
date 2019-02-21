#!/usr/local/bin/bash  

APP_NAME=$(basename $0 | sed "s/\.sh$//")
APP_PID="$$"

   # set the user's folder
USER="Dana"
   # set the expiry time, currently 4 days
EXPIRY_DATE=$(date -j -v-4d +%s)
   # set the SSH user 
#SSH="sshuser@ssh2"
SSH="dockett@192.168.0.180"
   # set the SSH port
PORT="22"
   # set the latest backup folder
LATEST_BACKUP_FOLDER="latest"

# set the directories/folders
BASE_DIR="/app-data/dockett/"$USER"/"
BASE_FOLDER=$(date "+%Y-%m")
BASE_NAME=$(date "+%Y-%m-%d_%H:%M:%S")

   # name of the symlink folder pointing to the latest successful backup
BASE_LATEST="$BASE_DIR$LATEST_BACKUP_FOLDER"/

LOG_DIR=$HOME/
#LOG_FILE=$LOG_DIR$BASE_NAME.log
LOG_FILE=""

   # set the currently inprogress backup directory (incomplete)
##BACKUP_INPROGRESS=".inprogress"
   # rsync partial directory to store partially transferred files
RSYNC_PARTIAL=".partial"

   # build the SSH command
SSH_CMD="ssh -p $PORT $SSH"


#  NOTE: see rsyncd.conf man page for log file format output



# -----------------------------------------------------------------------------
# Log functions
# -----------------------------------------------------------------------------

@log_info() {

  echo "$APP_NAME $BASE_NAME: $1" >> $LOG_FILE

}

@log_warn()  { echo "$APP_NAME: [WARNING] $1" 1>&2; }
@log_error() { echo "$APP_NAME: [ERROR] $1" 1>&2; }



#-------------------------------------------------------------------------------
# get the epoch time for date passed in
#
# $1 = date to transform to epoch time
#-------------------------------------------------------------------------------
@epoch() {

  date -j -f "%Y-%m-%d_%H:%M:%S" "$1" "+%s" 

}

#-------------------------------------------------------------------------------
# run the command, either locally or remotely
#
# $1 = command to run
#-------------------------------------------------------------------------------
@run_cmd() {

  # we want to run the command remotely
  if [ -n "$SSH" ]; then 
    eval "$SSH_CMD '$1'"
   # we want to run the command locally
   else
    eval $1
  fi

}

#-------------------------------------------------------------------------------
# find a directory(s)
#
# $1 = path to directory
# $2 = directory name
# $3 = directory type (d=directory l=symbolic link)
#-------------------------------------------------------------------------------
@find_dir() {

  # find the directory(s)
  @run_cmd "find '$1' -maxdepth 1 -type $3 -name '$2' -prune | sort -r" 2>/dev/null

}

#-------------------------------------------------------------------------------
# make a directory
#
# $1 = path to directory to make
#-------------------------------------------------------------------------------
@mkdir() {

  # make the directory
  @run_cmd "mkdir -p -- '$1'"

}

#-------------------------------------------------------------------------------
# remove a directory
#
# $1 = path to directory to remove
#-------------------------------------------------------------------------------
@rmdir() {

  # remove the directory
  @run_cmd "rm -R -- '$1'"

}

#-------------------------------------------------------------------------------
# find the backup folders
#
# $1 = backup directory
# $2 = type (d=directory l=symbolic link)
#-------------------------------------------------------------------------------
@find_backup_folders() {

  # find the backup folders
  @find_dir $1 '\"????-??\"' $2

}

#-------------------------------------------------------------------------------
# find the backups
#
# $1 = backup folder
# $2 = type (d=directory l=symbolic link)
#-------------------------------------------------------------------------------
@find_backups() {

  # find the backups
  @find_dir $1 '\"????-??-??_??:??:??\"' $2

}

#-------------------------------------------------------------------------------
# find the last backup
#
# $1 = backup directory (current)
#-------------------------------------------------------------------------------
@find_last_backup() {

  # find all the back up folders
##  LOCATION=$(@find_backup_folders "$1" | head -n 1)

  # if the location (backup folder) exists, find the backups
##  if [ -n "$LOCATION" ]; then
##    @find_backups "$LOCATION" | head -n 1
##  fi

  
  # find the current backup
  @find_backups "$1" 'l' | head -n 1 


}

#-------------------------------------------------------------------------------
# expire the backup
#
# $1 = path to backup to expire
#-------------------------------------------------------------------------------
@expire_backup() {

  # remove the directory
  @rmdir "$1"

}

#-------------------------------------------------------------------------------
# expire any old backups
#
# $1 = path to backups
#-------------------------------------------------------------------------------
@expire_backups() {

  # for each backup folder found
  for FOLDER in $(@find_backup_folders "$1" 'd'); do

    # find the backups that exist in the backup folder
    for BACKUP in $(@find_backups "$FOLDER" 'd'); do
      BACKUP_NAME=$(basename "$BACKUP")
      BACKUP_DATE=$(@epoch "$BACKUP_NAME")

      # if the backup is passed the expiry date
      if [ $BACKUP_DATE -lt $EXPIRY_DATE ]; then
        echo Will_Be_Expired---$BACKUP_NAME
        @expire_backup "$BACKUP"
      fi

    done

    # if no backups found in the folder, expire the folder
    if [ -z "$(@find_backups "$FOLDER" 'd')" ]; then
      echo Expiring_Folder---$FOLDER
      @expire_backup "$FOLDER"
    fi

  done

}

#-------------------------------------------------------------------------------
# set the rsync flags
#-------------------------------------------------------------------------------
@set_rsync_flags() {

  # set to archive
  RSYNC_FLAGS="-a"

  # set to keep partially transferred files
  RSYNC_FLAGS=$RSYNC_FLAGS" --partial-dir="$RSYNC_PARTIAL

  # set the log file location 
  if [ -n "$LOG_FILE" ]; then
    RSYNC_FLAGS=$RSYNC_FLAGS" --log-file=$LOG_FILE"
  fi

  # use hardlinks to last save file to save space
  if [ -n "$LINK_DEST" ]; then
    RSYNC_FLAGS=$RSYNC_FLAGS" --link-dest="$LINK_DEST 
  fi

}

#-------------------------------------------------------------------------------
# link the files
#
# $1 = source 
# $2 = target 
#-------------------------------------------------------------------------------
@link_files() {

  @run_cmd "ln -s $1 $2"

}

#-------------------------------------------------------------------------------
# unlink the files (remove symbolic link)
#
# $1 = path to file to unlink
#-------------------------------------------------------------------------------
@unlink() {

  if [ -n "$1" ]; then
    @rmdir $1
  fi

}

#-------------------------------------------------------------------------------
# verify the directory exists
#
# $1 = path of directory
#-------------------------------------------------------------------------------
@verify_dir() {

  # create directory it it doesn't already exist
  if [ -n $(@find_dir $(dirname "$1") $(basename "$1") 'd') ]; then
    @mkdir $1
  fi

}

#-------------------------------------------------------------------------------
# make sure the prerequisites exist
#
#  verify
#  check
#  setup environment
#  prerequisite
#
#  fix me up please!!
# $1 = path to file to verfiy existance
#-------------------------------------------------------------------------------
@prerequisites() {

  # create backup folder it it doesn't already exist
  @verify_dir $BASE_DIR$BASE_FOLDER

  # create latest backup folder if it doesn't already exist
  @verify_dir $BASE_LATEST

  # create the base directory (user's) folder if it doesn't already exist
## this shouldn't need to be done as it's already checked (implied) when
## the backup folder is checked
##  @verify_dir $BASE_DIR


# Create log folder if it doesn't exist
##  if [ ! -d "$LOG_DIR" ]; then
##    @log_info "Creating log folder in '$LOG_DIR'"
##    mkdir -p -- "$LOG_DIR"
##  fi

}

  



#-------------------------------------------------------------------------------
#
# MAIN PROGRAM STARTS HERE
#
#-------------------------------------------------------------------------------


#CCYYMM=$(date -r /app-data/backups/A/latest +%Y-%m)"/"
#APPDATE=$(date -r /app-data/backups/A/latest +%Y-%m-%d)


# get the parameters passed
SOURCE="/root/"
DEST=$BASE_DIR$BASE_FOLDER/$BASE_NAME

# TODO:  
#
# put in lock file to signal backup already running
#
# send key to backup server
#
# look at: 
#  https://github.com/brettalton/rsync-over-ssh/blob/master/rsync.sh 
#  https://github.com/cytopia/linux-timemachine/blob/master/timemachine


# expire any old backups
echo EXPIRY_DATE: $(date -j -f %s $EXPIRY_DATE "+%Y-%m-%d_%H:%M:%S")
@expire_backups "$BASE_DIR"

# make sure all the prerequisites are met
@prerequisites

# get the last backup made
LINK_DEST=$(@find_last_backup "$BASE_LATEST")
echo LINK_DEST $LINK_DEST

# set the rsync flags
@set_rsync_flags
echo RSYNC_FLAGS: $RSYNC_FLAGS

# create the backup
rsync $RSYNC_FLAGS $SOURCE $SSH:$DEST
echo "rsync $RSYNC_FLAGS $SOURCE $SSH:$DEST"

# unlink the old backup
echo UNLINK $LINK_DEST
@unlink $LINK_DEST

# link the new backup
echo LINK $DEST $BASE_LATEST$BASE_NAME
@link_files $DEST $BASE_LATEST$BASE_NAME
