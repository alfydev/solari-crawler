#!/bin/bash
# this will update the Wordpress DB with the latest posts from home.solari.com (or another hostname)
# It also only gets the 1st page, so if there are more than 100 new entries, it will take only 100
# If there are more than 100 entries, use the normal script mytotalscraper.sh

URL="https://$1/wp-json/wp/v2/"

if [ "$(whoami)" == "root" ] ; then
        echo "Error: don't run as root"
        exit
fi

if [ -z "$3" ] ; then
	echo "Error: Usage is $0 <WP hostname> <COOKIE string> <nb of past articles to search>"
	exit
fi

re='^[0-9]+$'
if ! [[ $3 =~ $re ]] ; then
     echo "Error: third argument is not a number."
     exit
fi

echo "Starting $0 at $(date +'%F:%T')" 

tempstring="updates.$(date +'%F:%T')"
tempdir="$tempstring/$1"

COOKIE="$2"

if [ -d "$tempstring" ] ; then
	echo "Error: directory $tempstring already exists, not overwriting"
	exit
fi

#mycreatepath=$(realpath $0 | sed "s/$(basename $0)//g")
#mycreate="$mycreatepath""mycreate.sh"
mycreate="$CREATOR"

if [ ! -x "$mycreate" ] ; then
        echo "Error: could not find $mycreate, not adding any posts"
        exit
fi

#mycategoriespath=$(realpath $0 | sed "s/$(basename $0)//g")
#mycategories="$mycategoriespath""mycategories.sh"
mycategories="$CATPARSER"

if [ ! -x "$mycategories" ] ; then
        echo "Error: could not find $mycategories, not adding products"
        exit
fi

#mytagspath=$(realpath $0 | sed "s/$(basename $0)//g")
#mytags="$mytagspath""mytags.sh"
mytags="$TAGSPARSER"

if [ ! -x "$mytags" ] ; then
        echo "Error: could not find $mytags, not adding products"
        exit
fi


mkdir $tempstring 2> /dev/null

if [ ! -d "$tempstring" ] ; then
	echo "Error: directory $tempstring could not be created, exiting"
	exit
fi

mkdir $tempdir 2> /dev/null
mkdir $tempdir/pages 2> /dev/null
mkdir $tempdir/posts 2> /dev/null
mkdir $tempdir/categories 2> /dev/null
mkdir $tempdir/tags 2> /dev/null

########################################
# POSTS
########################################

DUMPDIR="./$tempdir/posts"
echo "Getting posts from $1"

tot=0

res=$(curl --cookie "$COOKIE" $URL"posts?per_page=$3&orderby=date&order=desc" 2> /dev/null | jq)

countlines=$(echo "$res" | grep '"slug":' | wc -l)
tot=$(($tot + $countlines))
minus=$(($countlines - 1))

echo "$res" > $DUMPDIR/page-1.json	

echo "All done dumping posts. Total: $tot posts"
echo "------"




########################################
# PAGES
########################################

DUMPDIR="./$tempdir/pages"
echo "Getting pages from $1"

tot=0

res=$(curl --cookie "$COOKIE" $URL"pages?per_page=$3&orderby=date&order=desc" 2> /dev/null | jq)

countlines=$(echo "$res" | grep '"slug":' | wc -l)
tot=$(($tot + $countlines))
minus=$(($countlines - 1))

echo "$res" > $DUMPDIR/page-1.json	

echo "All done dumping pages. Total: $tot pages"
echo "------"


########################################
# CATEGORIES
########################################

DUMPDIR="./$tempdir/categories"
echo "Getting categories from $1"

tot=0

res=$(curl --cookie "$COOKIE" $URL"categories?per_page=100" 2> /dev/null | jq)

countlines=$(echo "$res" | grep '"slug":' | wc -l)
tot=$(($tot + $countlines))
minus=$(($countlines - 1))

echo "$res" > $DUMPDIR/page-1.json	

echo "All done dumping categories. Total: $tot categories"
echo "------"


########################################
# TAGS
########################################

DUMPDIR="./$tempdir/tags"
echo "Getting tags from $1"

tot=0

res=$(curl --cookie "$COOKIE" $URL"tags?per_page=100" 2> /dev/null | jq)

countlines=$(echo "$res" | grep '"slug":' | wc -l)
tot=$(($tot + $countlines))
minus=$(($countlines - 1))

echo "$res" > $DUMPDIR/page-1.json	

echo "All done dumping tags. Total: $tot tags"
echo "------"


echo "Now creating articles by calling mycreate.sh for posts"
$mycreate "./$tempdir/posts/page-1.json"

echo "Now creating articles by calling mycreate.sh for pages"
$mycreate "./$tempdir/pages/page-1.json"

echo "Now creating and assigning right categories by calling mycategories.sh for posts"
$mycategories "./$tempdir/posts/page-1.json"

echo "Now creating and assigning right categories by calling mycategories.sh for pages"
$mycategories "./$tempdir/pages/page-1.json"

echo "Now creating and assigning right tags by calling mytags.sh for pages"
$mytags "./$tempdir/pages/page-1.json"

echo "Now creating and assigning right tags by calling mytags.sh for posts"
$mytags "./$tempdir/posts/page-1.json"


echo "Script $0 is done at $(date +'%F:%T')" 

rm -rf $tempstring
