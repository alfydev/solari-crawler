#!/bin/bash
#wpbasedir="/var/www/html/solari.codinglab.ch"
#FIXERSCRIPT="/var/www/html/solari.codinglab.ch/solari-updater/fixcheck.sh"
echo "Starting $0 with wpbasedir $wpbasedir and FIXER $FIXER"

if [ "$(whoami)" == "root" ] ; then
        echo "Error: don't run as root"
        exit
fi

if [ -z "$1" ] || [ ! -f "$1" ] ; then
	echo "Error: usage is $0 <JSON FILE>"
	echo "The JSON file is expected to contain at least 1 post/object dumped from WP API"
	exit
fi

if [ ! -x "$FIXER" ]; then
	echo "Error: the fixer script is not available, please check"
	exit
fi


# create the category for that JSON file
catname=$(realpath $1 | tr '/' '\n' | grep "\.solari\.com" | head -n 1)
if [ -z "$catname" ]; then
	echo "Error: could not get a solari.com qualified hostname for category, please check"
	exit
fi

echo "Checking category $catname"

#### ASSIGN RIGHT CATEGORY ID
searchcat=$(cd $wpbasedir; wp term list category --name="$catname" --json)

if [ "$searchcat" == "[]" ] ; then
	echo "Category not found, creating"
	createcat=$(cd $wpbasedir; wp term create category "$catname" --description="Articles from $catname" --slug="$(echo $catname | tr '.' '-')")
	echo "Returned: $createcat"

	if [ "$(echo $createcat | grep Success | wc -l)" != "0" ] ; then
		catid=$(echo $createcat | tr ' ' '\n' | tail -n 1 | tr -d '.')
		echo "Created succesfully with ID $catid"
	else
		echo "Error: creating category with JSON file $1: $createcat"
		exit

	fi		
else
	catid=$(echo "$searchcat" | jq .[0] | jq .term_id)
	
	if [ "$catid" == "null" ] || [ -z "$catid" ] ; then
		echo "Error: getting category ID from JSON file $1: $searchcat"
		exit
	fi

	echo "Category already found with ID $catid"
fi
### END OF CATEGORY


a=0
while [ 1 ] ; do


	slug=$(cat "$1" | jq .[$a] | jq .slug | sed -e 's/^"//' -e 's/"$//') 
	if [ -z "$slug" ] || [ "$slug" == "null" ] ; then
		echo "Reached end of file"
		break	
	fi
	
	# Look for slug and category, skip if already present
	tslug=$(cat "$1" | jq .[$a] | jq .slug | sed -e 's/^"//' -e 's/"$//') 
	slug="$(echo $catname | tr '.' '-')"-"$tslug"

	wpcheckslug=$(cd $wpbasedir ; wp post list --field=name --name="$slug" --json | tr -d '\[\]')	
	
	# don't re-create post if present already
	if [ ! -z "$wpcheckslug" ] ; then
		echo "Post interation $a slug $tslug on category $catname already present, not creating"
		a=$(($a+1))
		continue
	fi 
	
	title=$(cat "$1" | jq .[$a] | jq .title | jq .rendered | sed -e 's/^"//' -e 's/"$//' | sed 's/\\n//g' | sed 's/\\t//g' | sed 's/\\"/"/g')
	excerpt=$(cat "$1" | jq .[$a] | jq .excerpt | jq .rendered | sed -e 's/^"//' -e 's/"$//' | sed 's/\\n//g' | sed 's/\\t//g'| sed 's/\\"/"/g')
	content=$(cat "$1" | jq .[$a] | jq .content | jq .rendered | sed -e 's/^"//' -e 's/"$//' | sed 's/\\n//g' | sed 's/\\t//g'| sed 's/\\"/"/g')
	link=$(cat "$1" | jq .[$a] | jq .link | sed -e 's/^"//' -e 's/"$//') 

	
	status=$(cat "$1" | jq .[$a] | jq .status | sed -e 's/^"//' -e 's/"$//')
	objecttype=$(cat "$1" | jq .[$a] | jq .type | sed -e 's/^"//' -e 's/"$//') 
	modified=$(cat "$1" | jq .[$a] | jq .date | sed -e 's/^"//' -e 's/"$//')
	featuredmedia=$(cat "$1" | jq .[$a] | jq ._links | jq '."wp:featuredmedia"[0]' | jq .href | sed -e 's/^"//' -e 's/"$//')
	authorhref=$(cat "$1" | jq .[$a] | jq ._links | jq .author[0] | jq .href | sed -e 's/^"//' -e 's/"$//')
	objecttype=$(cat "$1" | jq .[$a] | jq .type | sed -e 's/^"//' -e 's/"$//') 
	ismedia=0

	# convert media image into full path
	if [ ! -z "$featuredmedia" ] && [ "$featuredmedia" != "null" ] ; then 
	
		#murl=$(echo $featuredmedia | tr -d '"')
		murl=$featuredmedia
		echo "Getting featured media on url: $murl"
		featuredmediaimg=$(curl "$murl" 2> /dev/null | jq .source_url 2> /dev/null | sed -e 's/^"//' -e 's/"$//')
		if [ ! -z "$featuredmediaimg" ] ; then ismedia=1 ; fi
	fi
	
	# build the post create string

	# use a file for the content
	tfile="/tmp/mycreate.temp.$RANDOM.$RANDOM.$RANDOM.$RANDOM.$RANDOM"
	echo "$content" > $tfile
	
	wpstring=$(cd $wpbasedir; wp post create $tfile --post_date="$modified" --post_name="$slug" --post_title="$title" --post_excerpt="$excerpt" --post_status="$status" --post_category="$catid" 2>&1)

	rm -f $tfile
	
	if [ "$(echo "$wpstring" | grep Success | wc -l)" == "0" ]; then
		echo "Error creating post for slug $slug on $catname: $wpstring"
		echo "String was: wp post create --post_slug=$slug --post_title=$title --post_content=$content --post_excerpt=$excerpt --post_status=$status --post_category=\"$catid\""
	else
		
		echo "$wpstring"
		cpostid=$(echo $wpstring | tr ' ' '\n' | tail -n 1 | tr -d '.')
	fi

	# attach the featured image
	if [ "$ismedia" == 1 ] ; then
		echo "Attaching the featured image $featuredmedia to post id $cpostid - user is currently $(whoami)"
		
		wpaddmedia=$(cd $wpbasedir ; wp media import "$featuredmediaimg" --post_id=$cpostid --title="$featuredmedia" --desc="$featuredmedia" --featured_image)
		echo $wpaddmedia
	
	fi
	
	# put the meta for the original URL
	echo "Attaching url meta to post id $cpostid url: $link"
	wpattachurl=$(cd $wpbasedir ; wp post meta add $cpostid url "$link")
	echo $wpattachurl

	# call fixcheck.sh to see if it's subscriber content, more media files
	# only for home.solari.com
	if [ "$catname" == "home.solari.com" ] ; then
		echo "Calling the fixer script on post id $cpostid"
		$FIXER $cpostid 
	fi
	
	
	
	

# more: date, featured image, special field url


	
#	echo "Entry $a"
#	echo "-----"
#	echo "$title"
	#echo "$excerpt"
	#echo "$content"
	echo "Link: $link"
#	echo "$slug"
#	echo "$status"
##	echo "$objecttype"
#	echo "$modified"
#	echo "$featuredmedia"
#	echo "$featuredmediaimg"
#	echo "$authorhref"
	echo "------"
	
	
	a=$(($a + 1))

done

echo "all done for $a entries";

