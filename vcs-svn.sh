#!/bin/sh

# Load configuration
#. pootle-manager.conf
# Load common functions
. common-functions.sh

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