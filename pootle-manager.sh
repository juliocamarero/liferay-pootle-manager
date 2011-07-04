#!/bin/bash
#
### BEGIN INIT INFO
# Provides:             pootle
# Required-Start:	$syslog $time
# Required-Stop:	$syslog $time
# Short-Description:	Manage pootle easily. 
# Description:		Provides some automatization processes and simplify
# 			management of Pootle.
# Author:		Milan Jaros, Daniel Sanz, Alberto Montero                               
# Version: 		1.9
# Dependences:		svn, native2ascii, pootle-2.1.2
### END INIT INFO

# TODO:
#	auto-run this script (cron - once per week?): pootle-manager.sh --update-repository --update-pootle-db
#	UNDER MAINTANANCE information into Apache Pootle root (line 281) 

### BEGIN OF CONFIGURATION

# Configuration of directories
# base dir for pootle installation
declare -x -r POOTLEDIR="/var/www/Pootle"
# translation files for Pootle DB update/sync
declare -x -r PODIR="$POOTLEDIR/po"
# temporal work dir for format conversions
declare -x -r TMP_DIR="/opt/pootle/po-lf"
declare -x -r TMP_PROP_IN_DIR="$TMP_DIR/prop_in"
declare -x -r TMP_PROP_OUT_DIR="$TMP_DIR/prop_out"
declare -x -r TMP_PO_DIR="$TMP_DIR/po"
# svn update/commit dir
declare -x -r SVNDIR="/var/projects/trunk"

# Configuration of credentials
declare -x -r SVN_USER="guest"
declare -x -r SVN_PASS=""
declare -x -r PO_USER="xxxxx"
declare -x -r PO_PASS="xxxxx"
      
# Servers configuration
declare -x -r PO_HOST="xxxxxx"
declare -x -r PO_PORT="80"
declare -x -r PO_SRV="http://$PO_HOST:$PO_PORT/pootle"
declare -x -r PO_COOKIES="$TMP_DIR/${PO_HOST}_${PO_PORT}_cookies.txt"
declare -x -r SVN_HOST="svn.liferay.com"
#declare -x -r SVN_HOST="127.0.0.1"
declare -x -r SVN_PORT="80"
declare -x -r SVN_PATH="/repos/public"
declare -x -r SVN_SRV="http://$SVN_HOST:$SVN_PORT/$SVN_PATH"
declare -x -r SVN_PATH_PLUGIN_PREFIX="/plugins/trunk/portlets/"
declare -x -r SVN_PATH_PLUGIN_SUFFIX="/docroot/WEB-INF/src/content/"

# List of projects 
declare -x -r PLUGIN_LIST="mail-portlet knowledge-portlet digg-portlet youtube-portlet wsrp-portlet wiki-navigation-portlet vimeo-portlet so-portlet private-messaging-portlet private-messaging-portlet"
# TODO: build PROJECT list as a reading of plugins + portal project

#declare -x PROJECTS[0]="portal ${SVN_SRV}/portal/trunk/portal-impl/src/content/"
declare -x PROJECTS[0]="mail-portlet ${SVN_SRV}${SVN_PATH_PLUGIN_PREFIX}mail-portlet${SVN_PATH_PLUGIN_SUFFIX}"
declare -x PROJECTS[1]="knowledge-portlet ${SVN_SRV}${SVN_PATH_PLUGIN_PREFIX}knowledge-base-portlet${SVN_PATH_PLUGIN_SUFFIX}"
declare -x PROJECTS[2]="digg-portlet ${SVN_SRV}${SVN_PATH_PLUGIN_PREFIX}digg-portlet${SVN_PATH_PLUGIN_SUFFIX}"
declare -x PROJECTS[3]="youtube-portlet ${SVN_SRV}${SVN_PATH_PLUGIN_PREFIX}youtube-portlet${SVN_PATH_PLUGIN_SUFFIX}"
declare -x PROJECTS[4]="wsrp-portlet ${SVN_SRV}${SVN_PATH_PLUGIN_PREFIX}wsrp-portlet${SVN_PATH_PLUGIN_SUFFIX}"
declare -x PROJECTS[5]="wiki-navigation-portlet ${SVN_SRV}${SVN_PATH_PLUGIN_PREFIX}wiki-navigation-portlet${SVN_PATH_PLUGIN_SUFFIX}"
declare -x PROJECTS[6]="vimeo-portlet ${SVN_SRV}${SVN_PATH_PLUGIN_PREFIX}vimeo-portlet${SVN_PATH_PLUGIN_SUFFIX}"
declare -x PROJECTS[7]="so-portlet ${SVN_SRV}${SVN_PATH_PLUGIN_PREFIX}so-portlet${SVN_PATH_PLUGIN_SUFFIX}"
declare -x PROJECTS[8]="private-messaging-portlet ${SVN_SRV}${SVN_PATH_PLUGIN_PREFIX}private-messaging-portlet${SVN_PATH_PLUGIN_SUFFIX}"
declare -x PROJECTS[9]="opensocial-portlet ${SVN_SRV}${SVN_PATH_PLUGIN_PREFIX}opensocial-portlet${SVN_PATH_PLUGIN_SUFFIX}"


# How does language file looks like (e.g. Language.properties) 
declare -x -r FILE="Language"
declare -x -r PROP_EXT="properties"
declare -x -r PO_EXT="po"
declare -x -r POT_EXT="pot"
declare -x -r LANG_SEP="_"

### END OF CONFIGURATION

### Declare useful variables
#declare -x -r SCRIPT_PATH=$(cd ${0%/*} && echo $PWD/${0##*/})
#declare -x -r SCRIPT_DIR=`dirname $SCRIPT_PATH`

    check_command() {
	if [ $? -eq 0 ]; then
		echo_yellow "OK"
	else 
		echo_red "FAIL"
	fi
    }

    check_dir() {
        echo -n "    Cleaning dir $1 "
	if [ ! -d $1 ]; then
		mkdir -p $1
	else 
		rm -Rf $1/*
	fi
	check_command
    }

# $1 - project
# $2 - dir
# $3 - file prefix
report_dir() {
	file "{$2}*" > "/var/tmp/$1/$3.txt"
}

####
## Wait for user "any key" input
####
    any_key() {
	echo -n "Press any key to continue..."
	read -s -n 1
	echo
    }
    
####
## Echo coloured messages
####
# $@ - Message (all parameters)
    COLOROFF="\033[1;0m"; GREEN="\033[1;32m"; RED="\033[1;31m"; LILA="\033[1;35m"
    YELLOW="\033[1;33m"; BLUE="\033[1;34m"; WHITE="\033[1;37m"; CYAN="\033[1;36m"
    #echo -e '\E[0;31m'"\033[1m$1\033[0m"
    echo_green() { echo -e "$GREEN$@$COLOROFF"; }    
    echo_red() { echo -e "$RED$@$COLOROFF"; }
    echo_lila() { echo -e "$LILA$@$COLOROFF"; }
    echo_yellow() { echo -e "$YELLOW$@$COLOROFF"; }
    echo_blue() { echo -e "$BLUE$@$COLOROFF"; }
    echo_white() { echo -e "$WHITE$@$COLOROFF"; }
    echo_cyan() { echo -e "$CYAN$@$COLOROFF"; } 
    
####
## Resolve parameters
####
# $1 - This parameter must contain $@ (parameters to resolve).
    resolve_params() {
    	params="$@"
    	[ "$params" = "" ] && export HELP=1
	for param in $params ; do
		if [ "$param" = "--pootle2repo" ] || [ "$param" = "-r" ]; then
			export UPDATE_REPOSITORY=1
		elif [ "$param" = "--repo2pootle" ] || [ "$param" = "-p" ]; then
			export UPDATE_POOTLE_DB=1
		elif [ "$param" = "--disable-new" ] || [ "$param" = "-d" ]; then
			export DISABLE_NEW=1
		elif [ "$param" = "--help" ] && [ "$param" = "-h" ] && [ "$param" = "/?" ]; then
			export HELP=1
		else
		        echo_red "PAY ATTENTION! You've used unknown parameter."
		        any_key
		fi
	done
	if [ $HELP ]; then
		echo_white ".: Pootle Manager 1.9 :."
		echo
		echo "This is simple Pootle management tool that syncrhonizes the translations from VCS repository to pootle DB and vice-versa, taking into account automatic translations (which are uploaded as suggestions to pootle). Please, you should have configured variables in the script."
		echo "Arguments:"
		echo "  -r, --pootle2repo	Sync. stores of pootle and prepares files for commit to VCS (does not commit any file)"
		echo "  -p, --repo2pootle	Updates all language files from VCS repository and update Pootle database."
		echo "  -d, --disable-new	(only in conjunction with -p) Disables detection of new languages added to projects on the file system." 
		echo 

		UPDATE_REPOSITORY=
		UPDATE_POOTLE_DB=
		DISABLE_NEW=
	else
		echo_green "[`date`] Pootle manager [START]"
	fi
    }
    
####
## SVN
####
# $1 - project
# $2 - repository
    checkout() {
	echo_white "  $1: checkout language files"
	
	if [ "" != "$1" ] && [ "" != "$2" ]; then 
		if [ ! -d "$SVNDIR/$1" ]; then
			echo_yellow "    Creating $SVNDIR/$1 for the first time"
			mkdir -p $SVNDIR/$1
			echo "    Checkout all files from $SVNDIR/$1"
			svn checkout --username "$SVN_USER" --password "$SVN_PASS"  $2 $SVNDIR/$1
			check_command
		else
			echo_yellow "    Updating $SVNDIR/$1" 
			svn update --username "$SVN_USER" --password "$SVN_PASS" --non-interactive $SVNDIR/$1
			check_command
		fi 
	fi

	check_dir "$TMP_PROP_IN_DIR/$1/svn"
    echo "    Backing up svn files"
	for language in `ls $SVNDIR/$1/*.properties` ; do
		echo "cp $language $TMP_PROP_IN_DIR/$1/svn/"
		cp "$language" "$TMP_PROP_IN_DIR/$1/svn/"
	done
    }

    checkout_projects() {
	echo_cyan "[`date`] Checkout projects..."
	projects_count=$((${#PROJECTS[@]} - 1))
	for i in `seq 0 $projects_count`;
	do
		checkout ${PROJECTS[$i]}		 
	done
    }

###
                                                                   
####
## File conversion/management
####
    native_2_ascii() {
	# Convert native2ascii (all files) - If this causes performance 
	#  issues then svn output can be catched and parsed to understand 
	#  which only files needs to be converted.
	echo_cyan "[`date`] Converting properties files to ascii ..."

	projects=`ls $SVNDIR`
	for project in $projects;
	do
		echo_white "  $project: converting properties to ascii"			
		
		cp $SVNDIR/$project/$FILE.$PROP_EXT $TMP_PROP_IN_DIR/$project
		languages=`ls "$SVNDIR/$project"`		
		for language in $languages ; do    
			pl="$TMP_PROP_IN_DIR/$project/$language"			
			echo -n  "    native2ascii $project/$language "			
			[ -f $pl ] && native2ascii -encoding utf8 $pl "$pl.ascii"
			[ -f "$pl.ascii" ] && mv --force "$pl.ascii" $pl 
			check_command
		done
	done
    }

    ascii_2_native() {
	echo_cyan "[`date`] Converting properties files to native ..."

	projects_count=$((${#PROJECTS[@]} - 1))
	for i in `seq 0 $projects_count`;
	do
		project=`echo ${PROJECTS[$i]}| cut -f1 -d ' '`
		echo_white "  $project: converting properties to native"			
		#check_dir "$TMP_PROP_OUT_DIR/$project"
		#cp -R $PODIR/$project/*.properties $TMP_PROP_OUT_DIR/$project
		languages=`ls "$TMP_PROP_OUT_DIR/$project"`		
		for language in $languages ; do    
			pl="$TMP_PROP_OUT_DIR/$project/$language"			
			echo -n  "    native2ascii $project/$language "			
			[ -f $pl ] && native2ascii -reverse -encoding utf8 $pl "$pl.native"
			[ -f "$pl.native" ] && mv --force "$pl.native" $pl 
			check_command
		done
	done
    }

    clean_orphan_keys() {
	echo_cyan "[`date`] Cleaning orphan keys from translation files ..."
	projects=`ls $SVNDIR`
	for project in $projects;
	do
		echo_white "  $project: cleaning orphan keys"
		languages=`ls "$SVNDIR/$project"`
		check_dir "$TMP_PROP_IN_DIR/$project/orphan"
		for language in $languages;
		do	
			if [ -f $SVNDIR/$project/$language ] && [ "$FILE.$PROP_EXT" != "$language" ]; then
				echo -n "    $project/$language "
				to="$TMP_PROP_IN_DIR/$project/$language"
				orphan="$TMP_PROP_IN_DIR/$project/orphan/$language"
				while read line; do
					isproperty=`echo $line | grep -E "^[^#].*?=" | sed -r "s/([^=]+=).*/\1/"`
					if [ "$isproperty" != "" ]; then
						isintemplate=`grep -F "${isproperty}" $SVNDIR/$project/$FILE.$PROP_EXT`
						if [ "$isintemplate" != "" ]; then
#							echo "'$isproperty' "
							echo $line >> $to		
						else
							echo
							echo_red "      key $isproperty not present in $FILE.$PROP_EXT"
							echo $line >> $orphan
						fi
					else
						echo $line >> $to		
					fi
				done < "$SVNDIR/$project/$language"
				check_command
			fi
		done

	done
    }

    split_automatic_prop() {
	echo_cyan "[`date`] Selecting automatic translations from properties files..."
	regex=".*\(Automatic (Translation|Copy)\)$"
	projects=`ls $TMP_PROP_IN_DIR`
	for project in $projects;
	do
		echo_white "  $project: processing automatic translations"
		languages=`ls "$TMP_PROP_IN_DIR/$project"`
		[ ! -d "$TMP_PROP_IN_DIR/$project/aut" ] && mkdir -p "$TMP_PROP_IN_DIR/$project/aut"
		# uncomment to filter the manual translations
		#[ ! -d "$TMP_PROP_IN_DIR/$project/man" ] && mkdir -p "$TMP_PROP_IN_DIR/$project/man"
		for language in $languages;
		do	
			if [ -f $TMP_PROP_IN_DIR/$project/$language ] && [ "$FILE.$PROP_EXT" != "$language" ]; then
				l=`echo $language  | cut -f2- -d _ | cut -f1 -d .`
				echo -n "    grep $project/$language "
				grep -E "$regex" "$TMP_PROP_IN_DIR/$project/$language" > "$TMP_PROP_IN_DIR/$project/aut/$language"
				# grep outputs 1 if no matches are found so check_command will show FAIL when there are no auto translations
				if [ $? != 0 ]; then
					echo -n " [no auto translations detected] "
				else
					echo -n " [auto translations detected] "
				fi
				# uncomment to filter the manual translations
				#grep -v -E "$regex" "$TMP_PROP_IN_DIR/$project/$language" > "$TMP_PROP_IN_DIR/$project/man/$language"
				check_command
			fi
		done
	done
    }

   empty_automatic_prop() {
	echo_cyan "[`date`] Substituting automatic translations by empty ones in properties files..."
	projects=`ls $TMP_PROP_IN_DIR`
	for project in $projects;
	do
		[ ! -d "$TMP_PROP_IN_DIR/$project/empty" ] && mkdir -p "$TMP_PROP_IN_DIR/$project/empty"
		
		# empty the values of the properties files
		echo_white "  $project: Substituting auto-translated keys"
		languages=`ls "$TMP_PROP_IN_DIR/$project/"`
		for language in $languages;
		do
			# should we do this
			if [ -f $TMP_PROP_IN_DIR/$project/$language ] && [ "$FILE.$PROP_EXT" != "$language" ]; then
				echo -n "    sed $project/$language "
				sed -r 's/([^=]+=).*\(Automatic (Translation|Copy)\)$/\1/' < "$TMP_PROP_IN_DIR/$project/$language" > "$TMP_PROP_IN_DIR/$project/empty/$language"
				check_command
			fi
		done
	done
    }

    # $1 - project
    # $2 - language
    refill_automatic_prop() {
	echo "    $1/$2"
	from="$TMP_PROP_OUT_DIR/$1/$2"
	to="$TMP_PROP_OUT_DIR/$1/$2.filled"
	template="$TMP_PROP_OUT_DIR/$1/$FILE.$PROP_EXT"
	orig="$TMP_PROP_IN_DIR/$1/$2"
	svnorig="$TMP_PROP_IN_DIR/$1/svn/$2"
	svnunix="$TMP_PROP_OUT_DIR/$1/$2.unix"

	cp $svnorig $svnunix
	dos2unix $svnunix

	#echo "Readling lines from $from"
	#echo "Checking template file $template"
	#echo "Writing result to $to"
	#echo "Original SVN is $svnorig"
	#echo "UnixSVN is $svnunix"

	[ -f "$to" ] && rm -f "$to"
	script="\
		use strict;\
		my %valuesFromSVN = ();\
		open FILE, '$svnunix';\
		while (my \$line = <FILE>) {\
			if (\$line =~ m/^[^#].+=/) {\
				(my \$key, my \$value) = split(/=/, \$line);\
				\$valuesFromSVN{\$key} = \$line;\
			}\
		}\
		close FILE;\
		my %valuesFromTemplate = ();\
		open FILE, '$template';\
		while (my \$line = <FILE>) {\
			if (\$line =~ m/^[^#].+=/) {\
				(my \$key, my \$value) = split(/=/, \$line);\
				\$valuesFromTemplate{\$key} = \$line;\
			}\
		}\
		close FILE;\
		open FROM, '$from';\
		open TO, '>$to';\
		while (my \$line = <FROM>) {\
			if (\$line =~ m/^[^#].+=/) {\
				(my \$key, my \$value) = split(/=/, \$line);\
				if (\$line eq \$valuesFromTemplate{\$key}) {\
					print TO \$valuesFromSVN{\$key};\
				} else {\
					print TO \$line;\
				}\
			} else {\
				print TO \$line;\
			}\
		}\
		close FROM;\
		close TO;\
		"
	perl -e "$script"
	rm -f $svnunix
	
	if [ "CRLF" = "`file $svnorig | grep -o CRLF`" ]; then
		unix2dos "$to"
	fi
	mv -f "$to" "$from"
    }

    # gets called after checkout from SVN and before native2ascii
    keep_template() {
	echo_cyan "[`date`] Keeping file templates for later exporting ..."

	projects_count=$((${#PROJECTS[@]} - 1))
	for i in `seq 0 $projects_count`;
	do
		project=`echo ${PROJECTS[$i]}| cut -f1 -d ' '`
		echo_white "  $project: creating .po file"			
		check_dir "$TMP_PO_DIR/$project"
		prop2po -i $PODIR/$project/$FILE.$PROP_EXT -o $TMP_PO_DIR/$project/ -P
	done
    }


####
## Pootle server communication
####

# to Pootle

    close_pootle_session() {
	# get logout page and delete cookies
	echo -n "    Closing pootle session... "
	curl -s -b "$PO_COOKIES" -c "$PO_COOKIES" "$PO_SRV/accounts/logout" > /dev/null
	check_command
	#[ -f "$PO_COOKIES" ] && rm "$PO_COOKIES"
    }

    start_pootle_session() {
	echo_white "  Opening new pootle session"
	close_pootle_session
	# 1. get login page (and cookies)
	echo -n "    Accessing Pootle login page... "
	curl -s -b "$PO_COOKIES" -c "$PO_COOKIES" "$PO_SRV/accounts/login" > /dev/null
	check_command
	# 2. post credentials, including one received cookie
	echo -n "    Posting credentials... "
 	curl -s -b "$PO_COOKIES" -c "$PO_COOKIES" -d "username=$PO_USER;password=$PO_PASS;csrfmiddlewaretoken=`cat ${PO_COOKIES} | grep csrftoken | cut -f7`" "$PO_SRV/accounts/login" > /dev/null
	check_command
    }

    upload_suggestions() {
	echo_cyan "[`date`] Uploading auto-translations as suggestions..."
	start_pootle_session
	projects=`ls $TMP_PROP_IN_DIR`
	for project in $projects;
	do
		echo_white "  $project: uploading automatic translations as suggestions"
		languages=`ls "$TMP_PROP_IN_DIR/$project/"`
		for language in $languages;
		do
			if [ -f "$TMP_PROP_IN_DIR/$project/$language" ] && [ "$FILE.$PROP_EXT" != "$language" ]; then
				l=`echo $language  | cut -f2- -d _ | cut -f1 -d .`
				#echo_white "Uploading: curl -b $PO_COOKIES -c $PO_COOKIES -F \"file=@$TMP_PROP_IN_DIR/$project/aut/$language\" -F \"overwrite=suggest\" -F \"do_upload=upload\" -F 	\"csrfmiddlewaretoken=`cat ${PO_COOKIES} | grep csrftoken | cut -f7`\" \"$PO_SRV/$l/$project/\""
				echo -n "    Uploading suggestions for $project/$l... "
				curl -s -b "$PO_COOKIES" -c "$PO_COOKIES" -F "file=@$TMP_PROP_IN_DIR/$project/aut/$language" -F "overwrite=suggest" -F "do_upload=upload" -F "csrfmiddlewaretoken=`cat ${PO_COOKIES} | grep csrftoken | cut -f7`" "$PO_SRV/$l/$project/" > /dev/null
				check_command
			fi
 		done
	done

	echo_white "  Closing pootle session"
	close_pootle_session
    }

    update_pootle_db() {
	echo_cyan "[`date`] Updating pootle database..."
	rm -f "$PODIR/$project/*"
	projects=`ls $TMP_PROP_IN_DIR`
	for project in $projects;
	do
		echo_white "  $project: copying project files"
		cp "$TMP_PROP_IN_DIR/$project/${FILE}.$PROP_EXT" "$PODIR/$project"
		languages=`ls "$TMP_PROP_IN_DIR/$project/empty/"`
		for language in $languages;
		do
			# assume $project was previously created in pootle
			cp "$TMP_PROP_IN_DIR/$project/empty/$language" "$PODIR/$project"
 		done
		# Detect new languages added to projects on the file system
		echo_white "  $project: detecting new translations for Pootle DB"
		[ ! "$DISABLE_NEW" ] && $POOTLEDIR/manage.py update_translation_projects --project="$project" -v 0
		# Update database as well as file system to reflect the latest version of translation templates
		echo_white "  $project: updating Pootle templates"
		$POOTLEDIR/manage.py update_from_templates --project="$project"	-v 0
		# Update the strings in database to reflect what is on disk
		echo_white "  $project: updating Pootle DB translations"
		$POOTLEDIR/manage.py update_stores --project="$project"	-v 0	
	done
    }

# from pootle

    update_pootle_files() {
	echo_cyan "[`date`] Updating pootle files from pootle DB..."
	projects_count=$((${#PROJECTS[@]} - 1))
	for i in `seq 0 $projects_count`;
	do
		project=`echo ${PROJECTS[$i]}| cut -f1 -d ' '`
		echo_white "  $project: synchronizing stores"
		# Save all translations currently in database to the file system
		$POOTLEDIR/manage.py sync_stores --project="$project" -v 0
	done
    }
 
    reformat_pootle_files() {
	echo_cyan "[`date`] Reformatting exported pootle files..."
	projects_count=$((${#PROJECTS[@]} - 1))
	for i in `seq 0 $projects_count`;
	do
		project=`echo ${PROJECTS[$i]}| cut -f1 -d ' '`
		languages=`ls $PODIR/$project`
		echo_white "  $project: reformatting files"
		check_dir "$TMP_PROP_OUT_DIR/$project"
		for language in $languages; do
			if [ "$language" != "$FILE.$PROP_EXT" ]; then
				echo "    $project/$language "
				lang=`echo $language  | cut -f2- -d _ | cut -f1 -d .`
				echo "    prop -> po $project/$language"
				prop2po -i "$PODIR/$project/$language" -o "$TMP_PO_DIR/$project/" -t "$PODIR/$project/$FILE.$PROP_EXT" 
				check_command
				echo "    po -> prop $project/$language"
				po2prop -i "$TMP_PO_DIR/$project/${FILE}_$lang.$PO_EXT" -o "$TMP_PROP_OUT_DIR/$project/" -t "$PODIR/$project/$FILE.$PROP_EXT" 
				check_command
			fi
		done
	    cp -f "$PODIR/$project/$FILE.$PROP_EXT" "$TMP_PROP_OUT_DIR/$project/"
	done
    }

    add_untranslated() {
	echo_cyan "[`date`] Adding automatic translations to untranslated entries..."
	projects_count=$((${#PROJECTS[@]} - 1))
	for i in `seq 0 $projects_count`;
	do
		project=`echo ${PROJECTS[$i]}| cut -f1 -d ' '`
		languages=`ls $PODIR/$project`
		[ ! -d "$TMP_PROP_OUT_DIR/$project" ] && mkdir -p "$TMP_PROP_OUT_DIR/$project"
		echo_white "  $project: refilling untranslated entries"
		for language in $languages; do
			refill_automatic_prop $project $language
		done
        done
    }

    prepare_vcs() {
	echo_cyan "[`date`] Preparing processed files to VCS dir for commit..."
	projects_count=$((${#PROJECTS[@]} - 1))
	for i in `seq 0 $projects_count`;
	do
		project=`echo ${PROJECTS[$i]}| cut -f1 -d ' '`
		languages=`ls $PODIR/$project`
		echo_white "  $project: processing files"
		for language in $languages; do
			if [ "$FILE.$PROP_EXT" != "$language" ] ; then
				echo -n "    $project/$language: "
				if [ "`diff $TMP_PROP_OUT_DIR/$project/$language $TMP_PROP_IN_DIR/$project/svn/$language`" != "" ]; then
					echo  "   * $SVNDIR/$project/$language"
					cp -f "$TMP_PROP_OUT_DIR/$project/$language" "$SVNDIR/$project/$language"
				fi
			fi
		done
        done
    }



####
## Top-level functions
####

    # checks out projects from SVN, updating pootle translations of each project so that:
    #  . only keys contained in Language.properties are processed
    #  . new languages are added to the pootle project
    #  . new/deleted keys in Language.properties are conveniently updated in pootle project
    #  . automatic translations are uploaded as suggestions instead of valid translations
    #  . automatic copies of keys are ommited
    # preconditions:
    #  . project must exist in pootle
    #  . templates language may not exist? (how affect exporting with comments?)
    svn2pootle() {
	# prepare working dirs
	check_dir $TMP_DIR
	check_dir $TMP_PROP_IN_DIR
	check_dir $TMP_PO_DIR

	#  (this forces to use svn co all the time)
	check_dir $SVNDIR 

	#checkout .properties files from SVN
	checkout_projects
	# makes sure that Language_*.properties do not have keys not present in Language.properties
	clean_orphan_keys
	# convert them to ascii format
	native_2_ascii
	# get .properties files only containing automatic copies/translations (will become suggestions)
	split_automatic_prop
	# substitute by empty strings all automatic translations in the ascii .properties files
	empty_automatic_prop
	# let Pootle read the translation files
	update_pootle_db
	# Pootle does not have a management API for uploading suggestions, we do that via HTTP post
	upload_suggestions
    }

    pootle2svn() {
	# prepare working dirs
	check_dir $TMP_PROP_OUT_DIR
	check_dir $TMP_PO_DIR
	# let Pootle write its DB contents to translation files
	update_pootle_files
	# generate and keep a .po file for later export format conversion
	keep_template
	# make sure comments and blank lines remain in place
	reformat_pootle_files
	# convert them back to native format (this must be done before further manipulations)
	ascii_2_native
	# any untranslated key exported by pootle is substituted by its automatic translation/copy
	add_untranslated
	# copy files to VCS working copy
	prepare_vcs
	# TODO: do commit or notify someone to do that

    }

####
## Update 
####
    update() {
	# There should be placed UNDER MAINTANANCE mechanism
	if [ $UPDATE_REPOSITORY ]; then
		pootle2svn
	fi
	if [ $UPDATE_POOTLE_DB ]; then
		svn2pootle
	fi
	[ ! $HELP ] &&	echo_green "[`date`] Pootle manager [DONE]"
    }
    
main() {
	resolve_params $@
	update
}

main $@
