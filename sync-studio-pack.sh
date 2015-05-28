#!/bin/bash
#
# sync-studio-pack.sh
#
# When ejecuted, it lookup first in CLOUD_PROJECTS_DIRECTORY for existing projects packed in tar.bz2
# and uses rsync to sync the files localy but only if the local copy is out dated, later execute
# Android Studio.
# 
# When Android Studio is closed, it lookup in LOCAL_PROJECTS_DIRECTORY for files changed after
# Android Studio startup, pack only modified projects and copy them to CLOUD_PROJECTS_DIRECTORY.
#
# Very useful if you work from several places and want to have in all places the same code.
# Executing Android Studio in this manner, before it starts, all the projects will be updated.
# And all the projects modified, later will be copied back to Dropbox, ownCloud, MegaSync, etc.
#
################################################################################################



####################################################################################
# Users should modify only this three vars: path of Android Studio, local projects #
# directory, and remote packed projects directory.                                 #
####################################################################################

# The Android Studio execution script
STUDIO="$HOME/studio.sh" # in my computer, studio.sh is a symlink to ~/android-studio/bin/studio.sh

# This directory should contain all of your Android Studio Projects
LOCAL_PROJECTS_DIRECTORY="$HOME/Android_Projects"

# if the directory below doesn't exist the script will create it
# This will be the directory which will hold the .tar.bz2 packed projects.
CLOUD_PROJECTS_DIRECTORY="$HOME/Dropbox/Android_Projects"

# When edited above vars uncomment the following lines

# echo Please edit the script
# exit 0


#########################################
# Less usual that you need to edit this #
#########################################
TEMP_DIRECTORY="/tmp"
LOCK_FILE="$HOME/.find-cnewer-file-for-sync"
TEST_HASH="NO_OK"
PACK_ALL_PROJECTS_ON_START="NO"
export IFS=$'\n'

###############################
# tools needed by this script #
###############################
FIND=`which find`
ECHO=`which echo`
BZIP2=`which bzip2`
TAR=`which tar`
MD5SUM=`which md5sum`
CAT=`which cat`
CUT=`which cut`
RM=`which rm`
CP=`which cp`
MKDIR=`which mkdir`
UNIQ=`which uniq`
MV=`which mv`
BASH=`which bash`
TOUCH=`which touch`
RSYNC=`which rsync`
LS=`which ls`
WC=`which wc`


# for debug purposes
function pause(){
    read -p "Paused ... "
}


function end(){
    $ECHO
    $ECHO "[*] Finished."
}

function delete_lock_file(){
    $ECHO
    $ECHO "[LOCK FILE] Deleting the lock file."
    $RM -f $LOCK_FILE  &> /dev/null
}

function pack_project(){
    PROJECT=$1
    $ECHO -n "[PACK] Saving $PROJECT ... "

    cd &> /dev/null
    $TAR -cvf "$TEMP_DIRECTORY/$PROJECT.tar" -C "$LOCAL_PROJECTS_DIRECTORY" "$PROJECT" &> /dev/null
    $BZIP2 -9 "$TEMP_DIRECTORY/$PROJECT.tar" &> /dev/null
    $MD5SUM "$TEMP_DIRECTORY/$PROJECT.tar.bz2" > "$LOCAL_PROJECTS_DIRECTORY/.$PROJECT.md5"

    if [ ! -e "$CLOUD_PROJECTS_DIRECTORY/$PROJECT/" ];then
        $MKDIR -p "$CLOUD_PROJECTS_DIRECTORY/$PROJECT/" &> /dev/null
    fi
    $RM -f "$CLOUD_PROJECTS_DIRECTORY/$PROJECT/$PROJECT.tar.bz2.old" &> /dev/null
    $MV "$CLOUD_PROJECTS_DIRECTORY/$PROJECT/$PROJECT.tar.bz2" "$CLOUD_PROJECTS_DIRECTORY/$PROJECT/$PROJECT.tar.bz2.old" &> /dev/null
    $MV "$TEMP_DIRECTORY/$PROJECT.tar.bz2" "$CLOUD_PROJECTS_DIRECTORY/$PROJECT" &> /dev/null
    $ECHO "Saved."
}


function pack_modified_projects(){
    $ECHO
    $ECHO "[PACK] Starting to pack modified projects."

    for PROJECT in `$FIND "$LOCAL_PROJECTS_DIRECTORY" -cnewer $LOCK_FILE | $CUT -d'/' -f5 | $UNIQ`;do
        pack_project $PROJECT
    done

    $ECHO "[PACK] Finished."
}


function execute_android_studio(){
    $ECHO
    $ECHO -n "[STUDIO] Starting Android Studio ... "
    $BASH $STUDIO &> /dev/null
    $ECHO "finished."
}


function create_lock_file() {
    $ECHO "[LOCK FILE] Creating the lock file."

    $RM -f $LOCK_FILE  &> /dev/null

    if [ -e $LOCK_FILE ]; then
	$ECHO "[LOCK FILE ERROR] Error deleting the lock file, still exists."
	exit 1
    fi

    $TOUCH $LOCK_FILE

    if [ ! -e $LOCK_FILE ]; then
	$ECHO "[LOCK FILE ERROR] Error creating the lock file."
	exit 1
    fi
}


# el primer parámetro es el fichero con el hash cacheado, el segundo el fichero encontrado en dropbox
function test_hases(){

    if [ ! -e $1 ]; then
	TEST_HASH="NO_OK"

    elif [ ! -e $2 ];then
	$ECHO "[HASH ERROR] The second parameter as file doesn't exists. Quitting"
	exit 1

    else
	C=$($CAT $1 | $CUT -d' ' -f1)
	F=$($MD5SUM $2 2> /dev/null | $CUT -d' ' -f1)

	if [ "$F" == "$C" ]; then
	    TEST_HASH="OK"
	else
	    TEST_HASH="NO_OK"
	fi
    fi

}


function sync_proyects(){
    $ECHO "[SYNC] Starting to sync all projects."
    for PROJECT in `$FIND $CLOUD_PROJECTS_DIRECTORY/ -mindepth 1 -maxdepth 1 -type d -printf "%f\n"`;do

	test_hases "$LOCAL_PROJECTS_DIRECTORY/.$PROJECT.md5" "$CLOUD_PROJECTS_DIRECTORY/$PROJECT/$PROJECT.tar.bz2"

	if [ "$TEST_HASH" == "OK" ];then
	    $ECHO "[SYNC] $PROJECT have not changed."
	else
	    $ECHO -n "[SYNC] $PROJECT have changed. Syncing ... "

	    $CP "$CLOUD_PROJECTS_DIRECTORY/$PROJECT/$PROJECT.tar.bz2" $TEMP_DIRECTORY &> /dev/null
	    $BZIP2 -d "$TEMP_DIRECTORY/$PROJECT.tar.bz2" &> /dev/null
	    $TAR -xvf "$TEMP_DIRECTORY/$PROJECT.tar" -C "$TEMP_DIRECTORY" &> /dev/null
	    if [ ! -e "$LOCAL_PROJECTS_DIRECTORY/$PROJECT" ]; then
		$MKDIR -p "$LOCAL_PROJECTS_DIRECTORY/$PROJECT"
	    fi
            $MD5SUM "$CLOUD_PROJECTS_DIRECTORY/$PROJECT/$PROJECT.tar.bz2" > "$LOCAL_PROJECTS_DIRECTORY/.$PROJECT.md5"
	    $RSYNC -r --delete "$TEMP_DIRECTORY/$PROJECT/" "$LOCAL_PROJECTS_DIRECTORY/$PROJECT" &> /dev/null
	    $RM -rf "$TEMP_DIRECTORY/$PROJECT"
 	    $RM -f "$TEMP_DIRECTORY/$PROJECT.tar"

            $ECHO "Done."
	fi

    done
    $ECHO
}


function pack_all_local_projects_if_needed(){
    if [ $PACK_ALL_PROJECTS_ON_START == "YES" ]; then
        $ECHO "[PACK] Starting to pack all projects."

        for PROJECT in `$FIND "$LOCAL_PROJECTS_DIRECTORY" -mindepth 1 -maxdepth 1 -type d -printf "%f\n"`;do
            pack_project $PROJECT
        done

        $ECHO "[PACK] Finished."
        $ECHO
    fi
}


function init(){
    $ECHO "[*] Initializing ..."
    $ECHO

    if [ -e $LOCK_FILE ]; then
	$ECHO "[* ERROR] It appears to be another execution of this script."
	$ECHO "[* ERROR] If you are sure that not, remove manually the file $LOCK_FILE"
	exit 1
    fi

    if [ "$FIND" == "" ] || \
	[ "$ECHO" == "" ] || \
	[ "$BZIP2" == "" ] || \
	[ "$TAR" == "" ] || \
	[ "$MD5SUM" == "" ] || \
	[ "$CAT" == "" ] || \
	[ "$CUT" == "" ] || \
	[ "$RM" == "" ] || \
	[ "$CP" == "" ] || \
	[ "$MKDIR" == "" ] || \
	[ "$UNIQ" == "" ] || \
	[ "$MV" == "" ] || \
	[ "$BASH" == "" ] || \
	[ "$TOUCH" == "" ] || \
	[ "$LS" == "" ] || \
	[ "$WC" == "" ] || \
	[ "$RSYNC" == "" ]; then

        echo "[* ERROR] Some tool needed for this script don't exist in this computer."
        exit 1
    fi

    if [ ! -e "$LOCAL_PROJECTS_DIRECTORY" ]; then
	$MKDIR -p "$LOCAL_PROJECTS_DIRECTORY"

        if [ ! -e "$LOCAL_PROJECTS_DIRECTORY" ]; then
            $ECHO "[* ERROR] Cannot create the local projects directory. Please, review the script configuration."
            exit 1
        fi
    fi

    if [ ! -e "$CLOUD_PROJECTS_DIRECTORY" ]; then
	$MKDIR -p "$CLOUD_PROJECTS_DIRECTORY"

        if [ ! -e "$CLOUD_PROJECTS_DIRECTORY" ]; then
            $ECHO "[* ERROR] Cannot create the cloud projects directory. Please, review the script configuration."
            exit 1

        else
            # because the Cloud directory was created
            # we try to pack all the existing projects in localy
            PACK_ALL_PROJECTS_ON_START="YES"


        fi
    else
        if [ $($LS $CLOUD_PROJECTS_DIRECTORY|$WC -l) == 0 ]; then
            # because the Cloud directory is empty
            # we try to pack all the existing projects in localy
            PACK_ALL_PROJECTS_ON_START="YES"            
        fi
    fi

    if [ ! -e "$STUDIO" ]; then
	$ECHO "[* ERROR] Android Studio startup script doesn't exist. Please, review the script configuration."
        exit 1
    fi

}


function main(){
    # prepare the local directory if it not exists
    init

    # If is the first execution and the Cloud destination path doesn't exists or
    # the Cloud destination directory is empty, all local projects will be packed
    # first to the Cloud Directory before start
    pack_all_local_projects_if_needed

    # sync projects changed to here, or projects that not exists too
    sync_proyects

    # create a dumb file to check files changed after its creation
    create_lock_file

    # execute Android Studio
    execute_android_studio

    # pack all projects with files changed after the creation of the lock file
    pack_modified_projects

    # delete the lock file
    delete_lock_file

    # end of the script
    end
}


main
