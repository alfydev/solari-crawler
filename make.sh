#!/bin/bash
# This script will make all the dependencies and functionality test to run the application, and report back
# If you execute it with the "run" argument, it will execute the application after passing all the checks

if [ "$(whoami)" == "root" ] ; then
        echo "Error: don't run as root"
        exit
fi


chmod u+x *.sh bin/*.sh 2> /dev/null

if [ ! -x ./config.sh ] ; then
	echo "Error: config.sh file not present in local directory"
	exit
fi

source ./config.sh
if [ ! $? -eq 0 ]; then
	echo "Error sourcing config.sh"
	exit
fi

### SYSTEM DEPENDENCIES
echo "Checking system dependencies"

echo "... checking /tmp/"
if [ ! -w "/tmp/" ] ; then
	echo "Error: /tmp/ is not writable"
	exit
fi


echo "... checking jq"
if [ ! -x "$(which jq)" ] ; then
	echo "Error: jq not found. Install with apt install jq or see: https://jqlang.github.io/jq/download/"
	exit
fi

echo "... checking curl"
if [ ! -x "$(which curl)" ] ; then
	echo "Error: curl not found. Install with apt install curl or see: https://curl.se/download.html"
	exit
fi

echo "... checking grep"
if [ ! -x "$(which grep)" ] ; then
	echo "Error: grep command not found."
	exit
fi

echo "... checking wc"
if [ ! -x "$(which wc)" ] ; then
	echo "Error: wc command not found."
	exit
fi

echo "... checking sed"
if [ ! -x "$(which sed)" ] ; then
	echo "Error: sed command not found."
	exit
fi

echo "... checking htmlutils"
if [ ! -x "$(which hxclean)" ] || [ ! -x "$(which hxselect)" ] || [ ! -x "$(which hxnormalize)" ] ; then
	echo "Error: you need html-xml-utils installed (hxselect, hxclean and hxnormalize executable in your path). Do apt install html-xml-utils or see: https://www.w3.org/Tools/HTML-XML-utils/"
	exit
fi


echo "... checking Wordpress command line interface"
if [ ! -x "$(which wp)" ] || [ "$(wp cli version | grep "WP-CLI" | wc -l)" -eq 0 ] ; then
	echo "Error: wp cli not found. Make sure you have the wp command in your path. See: https://wp-cli.org/#installing"
	exit
fi


### LOCAL DEPENDENCIES
echo "Checking local dependencies"
chmod u+x $COOKIEGETTER $UPDATER $CREATOR $FIXER $TAGSPARSER 2> /dev/null

echo "... checking cookie getter"
if [ ! -x "$COOKIEGETTER" ] ; then
	echo "Error: cannot execute cookie getter script, please check config.sh"
	exit
fi

echo "... checking updater"
if [ ! -x "$UPDATER" ] ; then
	echo "Error: cannot execute updater script, please check config.sh"
	exit
fi

echo "... checking creator"
if [ ! -x "$CREATOR" ] ; then
	echo "Error: cannot execute creator script, please check config.sh"
	exit
fi

echo "... checking fixer"
if [ ! -x "$FIXER" ] ; then
	echo "Error: cannot execute fixer script, please check config.sh"
	exit
fi

echo "... checking category parser"
if [ ! -x "$CATPARSER" ] ; then
	echo "Error: cannot execute category parser script, please check config.sh"
	exit
fi

echo "... checking tags parser"
if [ ! -x "$TAGSPARSER" ] ; then
	echo "Error: cannot execute tags parser script, please check config.sh"
	exit
fi


### 
echo "Making other miscellaneous checks"

echo "... checking logfile"
touch "$logfile" 2> /dev/null
if [ ! $? -eq 0 ] || [ ! -w $logfile ] ; then
        echo "Error writing to logfile $logfile please check config.sh"
        exit
fi

echo "... checking iteration number"
re='^[0-9]+$'
if ! [[ $nb_iteration =~ $re ]] ; then
   echo "Error: nb_iteration is not a number in config.sh"
   exit
fi

if [ "$nb_iteration" -lt 1 ] || [ "$nb_iteration" -gt 100 ] ; then
   echo "Error: nb_iteration is invalid in config.sh"
   exit
fi

echo "... checking local Wordpress installation"

if [ ! -d "$wpbasedir" ] || [ ! -f "$wpbasedir/wp-config.php" ] || [ ! -d "$wpbasedir/wp-content/uploads" ] ; then
	echo "Error: there is not valid Wordpress installation in $wpbasedir please check config.sh"
	exit
fi

echo "... checking that username and password are defined"

if [ -z "$solari_username" ] || [ -z "$solari_password" ] ; then
	echo "Error: solari username and/or password not defined in config.sh"
	exit
fi

echo "... checking if the user can write to the Wordpress installation"
if [ ! -w "$wpbasedir/wp-content/uploads" ] ; then
	echo "Error: the uploads directory of the local Wordpress installation is not writable. This will cause problems importing media files (e.g. featured images). Please adjust the permissions and retry".
	exit
fi

year=$(date "+%Y")
month=$(date "+%m")

if [ -d "$wpbasedir/wp-content/uploads/$year/$month" ] && [ ! -w "$wpbasedir/wp-content/uploads/$year/$month" ] ; then
	echo "Error: the uploads directory for this month in the local Wordpress installation is not writable. This will cause problems importing media files (e.g. featured images). Please adjust the permissions and retry".
	exit
fi

# pixel image test

echo "... checking to import a pixel image and removing it"
echo "... importing pixel image"
pixel=$(realpath "$pixelimg")
if [ ! -f "$pixel" ] ; then
	echo "Error: pixel image $pixelimg not found"
	exit
fi


rpwd=$(pwd)
cd "$wpbasedir"
res=$(wp media import "$pixel" 2>&1)

if [ $(echo "$res" | grep "Success:" | wc -l) -eq 0 ] ; then
	echo "Error: unable to import the pixel image. This will cause problems importing media files (e.g. featured images). Please fix the issue and retry. Here is the full output:"
	echo "$res"
	exit
fi

imageid=$(echo "$res" | grep "as attachment ID" | tr ' ' '\n' | tail -n 1 | tr -d '.')
if ! [[ $imageid =~ $re ]] ; then

   echo "Warning: could not get the upload attachment ID in order to remove it. You can remove $pixelimg manually from the Wordpress."

else

   echo "... removing pixel image"
   res2=$(wp post delete "$imageid" --force 2>&1)

   if [ $(echo "$res2" | grep "Success:" | wc -l) -eq 0 ] ; then
	echo "Warning: could not delete the uploaded media ID $imageid. You can remove $pixelimg manually from the Wordpress. Here is the full output:"
	echo "$res2"
   fi



fi

cd $rpwd

if [ -z "$1" ] || [ "$1" != "run" ] ; then

	echo "... trying to get Solari cookie"
	cookie=$($COOKIEGETTER 2>&1)

	if [ $(echo "$cookie" | grep "Error:" | wc -l) -ne 0 ] || [ $(echo "$cookie" | grep "wordpress_logged_in_" | wc -l) -ne 1 ] ; then
	        echo "Error: could not get cookie. Check your Solari credentials in config.sh. Here is the full output:"
	        echo "$cookie"
	        exit
	fi

	echo "All checks passed, you are ready to execute the application"
	exit

fi

##### EXECUTION

echo "############# Starting application at $(date +'%F:%T')" >> $logfile
echo "Running application now at at $(date +'%F:%T'). Check $logfile for debug output."

echo "Getting cookie" >> $logfile
cookie=$($COOKIEGETTER 2>&1)

if [ $(echo "$cookie" | grep "Error:" | wc -l) -ne 0 ] || [ $(echo "$cookie" | grep "wordpress_logged_in_" | wc -l) -ne 1 ] ; then

        echo "Error: could not get cookie. Here is the full output:" >> $logfile
        echo "$cookie" >> $logfile
        exit
fi

echo "Success getting cookie" >> $logfile
echo "Running updater" >> $logfile

$UPDATER home.solari.com "$cookie" "$nb_iteration" >> $logfile 2>> $logfile

echo "############# Finished application at $(date +'%F:%T')" >> $logfile
echo "Finished application at $(date +'%F:%T')"

