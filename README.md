# solari-crawler
This custom application in bash will crawl home.solari.com for posts and import them in a locally-installed Wordpress instance, with the correct categories and original URL meta field.

# Requirements
You need a few command line utils for this application to work.
* jq (do `apt install jq` or see: https://jqlang.github.io/jq/download/)
* curl (do `apt install curl`or see: https://curl.se/download.html)
* html-xml-utils (do `apt install html-xml-utils` or see: https://www.w3.org/Tools/HTML-XML-utils/)
* Git (do `apt install git-all` or see: https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) 
* Wordpress CLI: do `curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && chmod +x wp-cli.phar && sudo mv wp-cli.phar /usr/local/bin/wp` or see: https://wp-cli.org/#installing)
  

You also need:
* A working local Wordpress installation, whose /wp-content/uploads/ directory branch is writable by the user running the application
* A /tmp/ directory writable by the user running the application

# Test & Execution

Clone the repository (provide the appropriate credentials if requested):

  ```
  git clone https://github.com/alfydev/solari-crawler/
  cd solari-crawler
  chmod +x make.sh
  ```

Copy `config.sh.example` into `config.sh`, then edit the file and modify the variables according to the specificities of your instance. Make sure you input the base64-encoded value of the password, not the password itself (get with: `echo "mypassword" | base64`)

Test the application:

  ```./make.sh```

Address and fix any error message (usually dependency issues) and re-execute until it says "All checks passed, you are ready to execute the application". 

To execute the application:

  ```./make.sh run```

Check the logfile specified in `config.sh` for any debug information. You should see the missing posts being added to the local Wordpress instance.

When you have confirmed the application is running smoothly, you can add it to a daily crontab.

# Updating
First make sure you back-up your config.sh file. Then from the root directory of the application (`solari-crawler`), run:

  ```git pull```

And restore the config.sh. The application is up-to-date.





