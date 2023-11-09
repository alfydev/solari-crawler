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

# path of the corresponding category json file
catpath=$(dirname $1)"/../categories/page-1.json"
if [ ! -f "$catpath" ]; then
	echo "Error: could not access corresponding category JSON on $catpath"
	exit
fi

# create the category for that JSON file
catname=$(realpath $1 | tr '/' '\n' | grep "\.solari\.com" | head -n 1)
if [ -z "$catname" ]; then
        echo "Error: could not get a solari.com qualified hostname for category, please check"
        exit
fi


echo "Checking posts in file $1 with category JSON in $catpath"


# function that checks if the category exists (otherwise create it) and if the post is assigned to it (and assigns to it)
function postCatParse {

	postslug="$1"
	catslug="$2"
	catnamesp="$3"
	catid=""
	
	echo "Checking post slug: $postslug category slug: $catslug name: $catnamesp"

	# look if the post exists, return otherwise
	wpsearchs=$(cd $wpbasedir ; wp post list --field=ID --name="$postslug" --json | tr -d "\[\]")
	postids="$wpsearchs"

	if [ -z "$postids" ] ; then
		echo "Post $postslug not found, not assigning any category"
		return
	fi 


	wpcheckslug=$(cd $wpbasedir ; wp term list category --slug="$catslug" --json)   

        if [ -z "$wpcheckslug" ] || [ "$wpcheckslug" == '[]' ]; then
                echo "Category with slug $catslug was not found"
                
                # creating category
                wpcreatecat=$(cd $wpbasedir ; wp term create category "$catnamesp" --slug="$catslug")

		if [ "$(echo "$wpcreatecat" | grep Success | wc -l)" == "0" ]; then
			echo "Error creating category with slug $catslug: $wpcreatecat"
			return
		else
			# echo "$wpcreatecat"
			catid=$(echo $wpcreatecat | tr ' ' '\n' | tail -n 1 | tr -d '.')
			echo "Success creating category with ID: $catid"
		fi
                
	else 
		catid=$(echo "$wpcheckslug" | jq .[0] | jq .term_id)
		echo "Category with slug $catslug was found with id $catid"
	fi	

	# check if we've got a category id
	re='^[0-9]+$'
	if ! [[ $catid =~ $re ]] ; then
	   echo "Error: category ID is not a number"; return
	fi

	# find if there are already categories assign, get them, return if good category already assigned
	
	wpsearcht=$(cd $wpbasedir ; wp post list --field=post_category --name="$postslug" --json | tr -d " \[\]")
	#echo $wpsearcht
	
	if [ "$(echo "$wpsearcht" | tr ',' '\n' | grep -x $catid | wc -l)" == "1" ] ; then # grep the whole line with grep -x
		echo "Category already assigned, not doing anything"
		return
	fi

	
	# concatenating the new category after the old ones
	newconcat=$wpsearcht",$catid"

	# Assign post to category
	
	echo "Assigning post ID $postids post slug $postslug category id $catid category slug $catslug with string: $newconcat"

	wpassign=$(cd $wpbasedir; wp post update "$postids" --post_category="$newconcat" 2>&1)
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
	
	cats=$(cat "$1" | jq .[$a] | jq .categories | tr -d ' \[\]\t\n' | tr ',' '\n')
	
	if [ -z "$cats" ] || [ "$cats" == "null" ] ; then
		echo "Post has no category assigned, skipping"
		a=$(($a+1))
		continue
	fi
	
	nbcats=$(echo "$cats" | wc -l)

	echo "Doing post $a (slug $slug), found $nbcats categories: $(echo $cats | tr '\n' '|')"
	
	b=1
	while [ "$b" -le "$nbcats" ] ; do
		thiscat=$(echo "$cats" | head -n $b | tail -n 1)
		thiscatname=$(cat $catpath | jq ".[] | select(.id==$thiscat)" | jq .name | sed -e 's/^"//' -e 's/"$//')
		thiscatslug=$(cat $catpath | jq ".[] | select(.id==$thiscat)" | jq .slug | sed -e 's/^"//' -e 's/"$//')
		
		if [ -z "$thiscatslug" ] || [ -z "$thiscatname" ] || [ "$thiscatslug" == "null" ] ; then
			echo "Error: category name or slug empty, skipping"
			a=$(($a+1))
			continue
		fi

		
		postCatParse "$slug" "$thiscatslug" "$thiscatname"
		
		b=$(($b+1))
	done
	echo "---"

	a=$(($a+1))

done

echo "all done for $a entries";

