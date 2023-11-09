#!/bin/bash
# Use this file to configure the environment variables needed by the application

# base directory of the local Wordpress install
export wpbasedir="/var/www/search/"

# logfile, for debug output
export logfile="/tmp/solari-crawler.log"

# login on https://home.solari.com
export solari_username="username@domain.com"

# password on https://home.solari.com
export solari_password="password"

# number of lastest posts on home.solari.com to iterate through and to add locally
export nb_iteration="100"

# ####################################################
# # You usually don't need to edit below this point. # 
# ####################################################

# these variables define 
export COOKIEGETTER="bin/cookiegetter.sh"
export UPDATER="bin/solari_latest_update.sh"
export CREATOR="bin/mycreate.sh"
export FIXER="bin/fixcheck.sh"
export CATPARSER="bin/mycategories.sh"
export TAGSPARSER="bin/mytags.sh"

# any random image (preferably small), made to test uploading to the Wordpress
export pixelimg="./pixel.png"

# EOF
#
#
