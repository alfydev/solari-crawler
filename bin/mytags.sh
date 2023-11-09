#!/bin/bash
#wpbasedir="/var/www/html/solari.codinglab.ch"
echo "Starting $0 with wpbasedir $wpbasedir"

if [ "$(whoami)" == "root" ] ; then
        echo "Don't run as root"
        exit
fi


if [ -z "$1" ] || [ ! -f "$1" ] ; then
	echo "Error: usage is $0 <JSON FILE>"
	echo "The JSON file is expected to contain at least 1 object dumped from WP API"
	exit
fi

# path of the corresponding tags json file
tagspath=$(dirname $1)"/../tags/page-1.json"
if [ ! -f "$tagspath" ]; then
	echo "Error: could not access corresponding tags JSON on $tagspath"
	exit
fi

catname=$(realpath $1 | tr '/' '\n' | grep "\.solari\.com" | head -n 1)
if [ -z "$catname" ]; then
        echo "Error: could not get a solari.com qualified hostname for tags, please check"
        exit
fi


echo "Checking posts in file $1 with tags JSON in $tagspath"


# function that checks if the tag exists (otherwise create it) and if the post is assigned to it (and assigns to it)
function postTagParse {

	postslug="$1"
	catslug="$2"
	catnamesp="$3"
	catid=""
	
	echo "Checking post slug: $postslug tag slug: $catslug name: $catnamesp"

	# look if the post exists, return otherwise
	wpsearchs=$(cd $wpbasedir ; wp post list --field=ID --name="$postslug" --json | tr -d "\[\]")
	postids="$wpsearchs"

	if [ -z "$postids" ] ; then
		echo "Post $postslug not found, not assigning any tag"
		return
	fi 

	# if the tag contains http then ignore
	if [ $(echo "$catslug" | grep http | wc -l) -ne 0 ] || [ $(echo "$catnamesp" | grep http | wc -l) -ne 0 ] ; then
		echo "Warning: invalid tag, ignoring"
		return
	fi

	wpcheckslug=$(cd $wpbasedir ; wp term list post_tag --slug="$catslug" --json)   

        if [ -z "$wpcheckslug" ] || [ "$wpcheckslug" == '[]' ]; then
                echo "Tag with slug $catslug was not found"
                
                # creating tag
                wpcreatecat=$(cd $wpbasedir ; wp term create post_tag "$catnamesp" --slug="$catslug")

		if [ "$(echo "$wpcreatecat" | grep Success | wc -l)" == "0" ]; then
			echo "Error creating tag with slug $catslug: $wpcreatecat"
			return
		else
			# echo "$wpcreatecat"
			catid=$(echo $wpcreatecat | tr ' ' '\n' | tail -n 1 | tr -d '.')
			echo "Success creating tag with ID: $catid"
		fi
                
	else 
		catid=$(echo "$wpcheckslug" | jq .[0] | jq .term_id)
		echo "Tag with slug $catslug was found with id $catid"
	fi	

	# check if we've got a tag id
	re='^[0-9]+$'
	if ! [[ $catid =~ $re ]] ; then
	   echo "Error: tag ID is not a number"; return
	fi

	wpsearcht=$(cd $wpbasedir ; wp post term list $postids post_tag --json 2>&1 | tr -d " \[\]")
	#echo $wpsearcht

	if [ $(echo "$wpsearcht" | grep Error | wc -l) -ne 0 ] ; then
		echo "Error getting current tags for post $postslug: $wpsearcht"
		return
	fi
	
	
	if [ "$(echo "$wpsearcht" | tr ',' '\n' | grep $catslug | wc -l)" -ne 0 ] ; then 
		echo "Tag already assigned, not doing anything"
		return
	fi

	
	# Assign post to tag
	
	echo "Assigning post ID $postids post slug $postslug tag id $catid tag slug $catslug"

	wpassign=$(cd $wpbasedir; wp post term add $postids post_tag "$catslug" 2>&1)
	echo "$wpassign"
} 

a=0
while [ 1 ] ; do


	slug=$(cat "$1" | jq .[$a] | jq .slug | sed -e 's/^"//' -e 's/"$//') 
	if [ -z "$slug" ] || [ "$slug" == "null" ] ; then
		echo "Reached end of file"
		break	
	fi

	tslug=$slug
        slug="$(echo $catname | tr '.' '-')"-"$tslug"
	
	cats=$(cat "$1" | jq .[$a] | jq .tags | tr -d ' \[\]\t\n' | tr ',' '\n')
	
	if [ -z "$cats" ] || [ "$cats" == "null" ] ; then
		# echo "Post has no tags assigned, skipping"
		a=$(($a+1))
		continue
	fi
	
	nbcats=$(echo "$cats" | wc -l)

	echo "Doing post $a (slug $slug) on iteration $a, found $nbcats tags: $(echo $cats | tr '\n' '|')"
	
	b=1
	while [ "$b" -le "$nbcats" ] ; do
		thiscat=$(echo "$cats" | head -n $b | tail -n 1)
		thiscatname=$(cat $tagspath | jq ".[] | select(.id==$thiscat)" | jq .name | sed -e 's/^"//' -e 's/"$//')
		thiscatslug=$(cat $tagspath | jq ".[] | select(.id==$thiscat)" | jq .slug | sed -e 's/^"//' -e 's/"$//')
		
		if [ -z "$thiscatslug" ] || [ -z "$thiscatname" ] || [ "$thiscatslug" == "null" ] ; then
			echo "Error: tag name or slug empty, skipping"
			b=$(($b+1))
			continue
		fi

		
		postTagParse "$slug" "$thiscatslug" "$thiscatname"
		
		b=$(($b+1))
	done
	echo "---"

	a=$(($a+1))

done

echo "all done for $a entries";

