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
LEAVE_FILES_AFTER_CLEAN_UP=3
BACKUP_COMPRESSION_RATE=6
RESTART_THUNDERBIRD_IF_RUNNED=1
IS_THUNDERBIRD_RUNNED=0

# -----------------------------------------------------------------------
echo STEP-1
# Check if we already have backup for period

if [ "$1" != "force" ]; then
	if [[ $(find $BACKUP_FOLDER -type f -print -quit) ]]; then
		LAST_BACKUP_FILE=$( find $BACKUP_FOLDER -type f -print0 | xargs -0 ls -lt | grep -v '^total' | awk '{print $(NF)}' | head -n 1)
		LAST_BACKUP_FILE_DATE=$(date -r $LAST_BACKUP_FILE '+%Y%m%d')
		LAST_SAT_DATE=$(date -d "last-saturday" '+%Y%m%d')
		# If last backup date greater than last saturday then exit
		if [ $LAST_BACKUP_FILE_DATE -ge $LAST_SAT_DATE ]; then exit; fi
	fi
fi

# -----------------------------------------------------------------------
echo STEP-2
# If thunderbird running ask user to close it
# If user answer No, exiting
# If user say Yes, than check again, if it still running ask again

for ((i=1; i<=$ATTEMPTS_TO_STOP_THUNDERBIRD; i++))
do
echo STEP-2a
	if pgrep "thunderbird" > /dev/null;	then
echo STEP-2b
		IS_THUNDERBIRD_RUNNED=1

		if [ $i -eq 1 ]; then
			MSG="I want to do regular backup."
		else
			MSG="Thunderbird still running."
		fi
echo STEP-2c
		zenity \
			--question \
			--title="Thunderbird backup" \
			--text="$MSG\nCould you please close Thunderbird?" \
			--display=:0.0 
echo STEP-2d
		# if No btn pressed exit
		if [ $? -eq 1 ]; then exit; fi
echo STEP-2e
	else
echo STEP-2f
		break
	fi
done
echo STEP-2g

# If user say few times that he close thunderbird
# but it still running, show error and exiting

if pgrep "thunderbird" > /dev/null
then
	zenity --error --text "Can't do backup - Thunderbird still running.." --display=:0.0 
	exit
fi

# -----------------------------------------------------------------------
echo STEP-3
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
if [[ $(find $BACKUP_FOLDER -type f -print -quit) ]]; then
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
echo STEP-4
# Show notify message that backup created

if [ -f "$BACKUP_FOLDER/$BACKUP_FILENAME.zip" ];
then
	notify-send "Thunderbird backup created"
else
	zenity --error --text "Thunderbird backup hasn't created\nUndefined error happend" --display=:0.0 
fi

# -----------------------------------------------------------------------
echo STEP-5
# Start thunderbird if it running when script starts
# and user shutdown it just for backup

if [ $IS_THUNDERBIRD_RUNNED -eq 1 ]; then
	if [ $RESTART_THUNDERBIRD_IF_RUNNED -eq 1 ]; then
		/usr/bin/thunderbird &
	fi
fi
