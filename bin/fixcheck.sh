#!/bin/bash
# find posts that might still be password-protected and have no obvious string such as please log-in, etc.

#wpbasedir="/var/www/html/solari.codinglab.ch"
#COOKIE_GETTER="/var/www/html/solari.codinglab.ch/solari-updater/cookiegetter.sh"
echo "Starting $0 with wpbasedir $wpbasedir and COOKIEGETTER $COOKIEGETTER"


if [ "$(whoami)" == "root" ] ; then
        echo "Don't run as root"
        exit
fi

if [ -z "$1" ] ; then
        echo "Error: usage is $0 <Wordpress ID> [cookie string] [class identifier]"
        exit
fi
re='^[0-9]+$'
if ! [[ $1 =~ $re ]] ; then
        echo "Error: usage is $0 <Wordpress ID> [cookie string] [class identifier]"
        exit
fi

if [ ! -z "$2" ] ; then
	cookiestring=$2
else
	cookiestring=$($COOKIEGETTER)
fi

if [ -z "$3" ] ; then
	classstring=".entry-content.clearfix"
else
	classstring=$3
fi

if [ $(echo $cookiestring | grep "wordpress_logged_in_" | wc -l) -eq 0 ] ; then
	echo "Error: getting cookie: $cookiestring"
	exit
fi

metaurl=$(cd $wpbasedir ; wp post meta get $1 url)
if [ $(echo "$metaurl" | grep "http" | wc -l) -eq 0 ] ; then
	echo "Error: getting meta url: $metaurl"
	exit
fi


echo "Examining post ID $1 with meta url: $metaurl"

if [ $(echo $metaurl | grep "\.solari\.com/" | wc -l) -eq 0 ] ; then
	echo "Warning: meta url $metaurl is not on the solari.com domain, ignoring"
	exit
fi

# get the content of the post in the Wordpress
grabart=$(cd $wpbasedir; wp post get $1 --field=content 2>&1)
if [ $(echo $grabart | grep '^Error' | wc -l) -eq 1 ] ; then
	echo "Error: getting for postid $1 the meta url: $grabart"
	exit
fi

# get the content of the html on the solari frontend
grabnew=$(curl --cookie "$cookiestring" "$metaurl" 2> /dev/null)
newcontent=$(echo "$grabnew" | hxclean 2> /dev/null | hxnormalize -x | hxselect -c "$classstring" 2> /dev/null)

if [ $(echo "$newcontent" | grep [a-zA-Z0-9] | wc -l) -eq 0 ] ; then
           echo "Error: could not scrap the content with curl for postid $1, hxclean and hxselect";
           exit
fi

# do the same as fixhome.sh, look for certain strings
echo "Looking for login string in Wordpress article"

if [ $(echo "$grabart" | grep -i "Please login to see\|to access subscriber content\|Please log-in to see\|available to subscribers\|not a subscriber yet" | wc -l ) -gt 0 ]; then 

	echo "Found a login string in postid $1, updating article"

else
	# login string not found, counting media files

	echo "Login string not found in postid $1, counting media files"

	mediafiles_frontend=$(echo "$newcontent" | tr '"' '\n' | tr '<' '\n' | tr '>' '\n' | tr ' ' '\n' | tr '?' '\n' | sort | uniq | grep -i "\.m4a\|\.m4v\|\.mp3\|\.mp4\|\.avi\|\.pdf\|MP3_file_icon\|PDF_file_icon")
	mediafiles_frontend_nb=$(echo "$mediafiles_frontend" | wc -l)
	mediafiles_article=$(echo "$grabart" | tr '"' '\n' | tr '<' '\n' | tr '>' '\n' | tr ' ' '\n' | tr '?' '\n' | sort | uniq | grep -i "\.m4a\|\.m4v\|\.mp3\|\.mp4\|\.avi\|\.pdf\|MP3_file_icon\|PDF_file_icon")
	mediafiles_article_nb=$(echo "$mediafiles_article" | wc -l)

	echo "Found $mediafiles_frontend_nb media files in solari front-end content, $mediafiles_article_nb in the article itself"
	if [ "$mediafiles_frontend_nb" -eq 0 ] ; then
	 	echo "Post ID $1 has no media file on frontend, skipping"
	 	exit
	fi

	# check if something to update

	if [ "$mediafiles_article_nb" -eq "$mediafiles_frontend_nb" ] ; then
		echo "Post ID $1 seems up to date, skipping"
		exit
	fi

	if [ "$mediafiles_article_nb" -gt "$mediafiles_frontend_nb" ] ; then
		echo "Error: Wordpress post ID $1 has more media files than grabbed content from frontend, aborting"
		exit
	fi

	if [ "$mediafiles_article_nb" -lt "$mediafiles_frontend_nb" ] ; then
		echo "Succcess: post ID $1 will be updated with frontend content of $metaurl"
	fi

fi
# article needs to be updated

# use a file for the content
tfile="/tmp/fixcheck.temp.$RANDOM.$RANDOM.$RANDOM.$RANDOM.$RANDOM"
echo "$newcontent" > $tfile

wpstring=$(cd $wpbasedir; wp post update $1 $tfile 2>&1)

rm -f $tfile

if [ "$(echo "$wpstring" | grep Success | wc -l)" -eq 0 ]; then
                echo "Error updating post ID $1: $wpstring"
                exit
fi


echo "$wpstring"
echo "---"

