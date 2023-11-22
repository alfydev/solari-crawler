#!/bin/bash

# we are expecting a "Please login to see" string in the html of this content to determine whether the cookie is working
PASSWORD_PROTECTED="https://home.solari.com/coming-thursday-money-markets-report-july-21-2022/"

if [ "$(whoami)" == "root" ] ; then
        echo "Don't run as root"
        exit
fi

# getting the cookie, the home.solari.com login and password are in this string
mylogin=$(printf %s "$solari_username" | jq -sRr @uri)
myp=$(echo "$solari_password" | base64 --decode)
if [ $? -ne 0 ] ; then echo "Error: could not decode password in $0" ; exit ; fi
mypass=$(printf %s "$myp" | jq -sRr @uri )
cookiestr=$(curl -v -X POST "https://home.solari.com" -H 'Content-Type:application/x-www-form-urlencoded' -d 'option=ap_user_login&redirect=https%3A%2F%2Fhome.solari.com%2F&userusername='$mylogin'&userpassword='$mypass'&remember=Yes&login=Login&pum_form_popup_id=170633'  2>&1 | grep "wordpress_logged_in_" | tr ' ' '\n' | grep "wordpress_logged_in_" | sed 's/;$//' | tail -n 1)

# check if we got a valid answer
if [ -z "$cookiestr" ] || [ $(echo "$cookiestr" | grep "wordpress_logged_in_" | wc -l) -ne 1 ] ; then
	echo "Error: getting the cookie failed"
	exit
fi

# checking if the cookie works on a password-pretected page
res=$(curl --cookie "$cookiestr" "$PASSWORD_PROTECTED" 2> /dev/null)

if [ "$(echo "$res" | grep -i "Please login to see" | wc -l)" -ne 0 ] ; then
	echo "Error: getting the cookie failed on curl"
	exit
fi

echo "$cookiestr"

#newcontent=$(echo "$res" | hxclean 2> /dev/null | hxselect -c ".entry-content.clearfix" 2> /dev/null)
#echo "---"
#echo "$newcontent"
