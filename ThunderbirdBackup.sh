#!/bin/bash

# -----------------------------------------------------------------------
# Thunderbird profile backup script
# See more information at:
# http://www.it-rem.ru/perenos-profilya-thunderbird-na-drugoy-disk.html
# -----------------------------------------------------------------------

#Configuration

BACKUP_FOLDER=/store/Backups/Thunderbird
THUNDERBIRD_PROFILE_PATH=/store/Software/Thunderbird/biiyroo1.default
BACKUP_FILENAME=thunderbird-profile-`date +"%Y_%m_%d"`
ATTEMPTS_TO_STOP_THUNDERBIRD=5
LEAVE_FILES_AFTER_CLEAN_UP=5
BACKUP_COMPRESSION_RATE=6
RESTART_THUNDERBIRD_IF_RUNNED=1
IS_THUNDERBIRD_RUNNED=0
LOCK_FILE=/tmp/thunderbird-backup.lock

# -----------------------------------------------------------------------

# Check for only one copy of the script running

# create empty lock file if none exists
cat /dev/null >> $LOCK_FILE
read lastPID < $LOCK_FILE

# if lastPID is not null and a process with that pid exists , exit
[ ! -z "$lastPID" -a -d /proc/$lastPID ] && exit

# not running, save my pid in the lock file
echo $$ > $LOCK_FILE

echo "Starting.."

# -----------------------------------------------------------------------

# Check if we already have backup for period

if [ "$1" != "force" ];
then
    if [[ $(find $BACKUP_FOLDER -type f -print -quit) ]];
    then
        LAST_BACKUP_FILE=$( find $BACKUP_FOLDER -type f -print0 | xargs -0 ls -lt | grep -v '^total' | awk '{print $(NF)}' | head -n 1)
        LAST_BACKUP_FILE_DATE=$(date -r $LAST_BACKUP_FILE '+%Y%m%d')
        LAST_SAT_DATE=$(date -d "last-saturday" '+%Y%m%d')
        # If last backup date greater than last saturday then exit
        if [ $LAST_BACKUP_FILE_DATE -ge $LAST_SAT_DATE ];
        then
            echo "Fresh backup already exists, exiting.."
            exit;
        fi
    fi
fi

# -----------------------------------------------------------------------

# If thunderbird running ask user to close it
# If user answer No, exiting
# If user say Yes, than check again, if it still running ask again

for ((i=1; i<=$ATTEMPTS_TO_STOP_THUNDERBIRD; i++))
do
    if pgrep "thunderbird" > /dev/null;
    then

        IS_THUNDERBIRD_RUNNED=1

        if [ $i -eq 1 ]; then
                MSG="I want to do regular backup."
        else
                MSG="Thunderbird still running."
        fi

        echo "$MSG. Could you please close Thunderbird?"

        zenity \
                --question \
                --title="Thunderbird backup" \
                --text="$MSG\nCould you please close Thunderbird?" \
                --display=:0.0

        # if No btn pressed exit
        if [ $? -eq 1 ]; then exit; fi

    else
            break
    fi
done


# If user say few times that he close thunderbird
# but it still running, show error and exiting

if pgrep "thunderbird" > /dev/null
then
    zenity --error --text "Can't do backup - Thunderbird still running.." --display=:0.0
    echo "Error: Can't do backup - Thunderbird still running..";
    exit
fi

# -----------------------------------------------------------------------

# Now we can do backup
# Note: to disable silent mode remove below ">/dev/null" and "-q" flag

pushd $THUNDERBIRD_PROFILE_PATH > /dev/null
cd ..
zip -$BACKUP_COMPRESSION_RATE \
    -r "$BACKUP_FOLDER/$BACKUP_FILENAME.zip" \
    -q \
    `basename $THUNDERBIRD_PROFILE_PATH`
popd > /dev/null

# -----------------------------------------------------------------------

# Clean up old archives
if [[ $(find $BACKUP_FOLDER -type f -print -quit) ]];
then
    FILES_LIST=$(find $BACKUP_FOLDER -type f -print0 | xargs -0 ls -lt | grep -v '^total' | awk '{print $(NF)}')
    COUNTER=$LEAVE_FILES_AFTER_CLEAN_UP

    for FILE in $FILES_LIST
    do
            ((COUNTER--));
            if [ $COUNTER -ge 0 ]; then continue; fi
            rm $FILE
    done
fi
# -----------------------------------------------------------------------

# Show notify message that backup created

if [ -f "$BACKUP_FOLDER/$BACKUP_FILENAME.zip" ];
then
    echo "Thunderbird backup successfully created"
    notify-send "Thunderbird backup successfully created"
else
    echo "Error: Thunderbird backup hasn't created. Undefined error happend"
    zenity --error --text "Thunderbird backup hasn't created\nUndefined error happend" --display=:0.0
fi

# -----------------------------------------------------------------------

# Start thunderbird if it running when script starts
# and user shutdown it just for backup

if [ $IS_THUNDERBIRD_RUNNED -eq 1 ];
then
    if [ $RESTART_THUNDERBIRD_IF_RUNNED -eq 1 ];
    then
        echo "Now you can rerun thunderbird if needed"
        # In this place you can start thunderbird, smth like:
        # thunderbird &
        # unfortunately in my Kubuntu this command starts
        # thunderbird with empty profile, so I disabled it
    fi
fi
