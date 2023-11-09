# solari-crawler
This custom application in bash will crawl home.solari.com for posts and import them in a locally-installed Wordpress instance, with the correct categories and original URL meta field.

# Dependencies and Requirements
You need a few command line utils for this application to work.
* jq (do `apt install jq` or see: https://jqlang.github.io/jq/download/)
* curl (do `apt install curl`or see: https://curl.se/download.html)
* html-xml-utils (do `apt install html-xml-utils` or see: https://www.w3.org/Tools/HTML-XML-utils/)
* Git (do `apt install git-all` or see: https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) 
* Wordpress CLI: do `curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && chmod +x wp-cli.phar && sudo mv wp-cli.phar /usr/local/bin/wp` or see: https://wp-cli.org/#installing)
  

You also need:
* A working local Wordpress installation, whose /wp-content/uploads/ directory is writable by the user running the application
* A /tmp/ directory writable by the user running the application

# Installation

Clone the repository (provide the appropriate credentials if requested):

  ```
  git clone https://github.com/alfydev/solari-crawler/
  cd solari-crawler
  chmod +x make.sh
  ```

Edit the `config.sh` file and modify the variables according to the specifities of your instance.

Test the application:

  ```./make.sh```

Address and fix any error message (usually dependency issues) and re-execute until it says "All checks passed, you are ready to execute the application". You are then ready to execute the application:

  ```./make.sh run```

When you have confirmed the application is running smoothly, you can add it to a daily crontab.


