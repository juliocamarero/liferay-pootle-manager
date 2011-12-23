#!/bin/sh
#
### BEGIN INIT INFO
# Provides:             common-functions
# Required-Start:	$syslog $time
# Required-Stop:	$syslog $time
# Short-Description:	Functions used in scripts
# Description:		Common functions used across management scripts.
# 			There should not be script specific functions.
# Author:		Milan Jaroš, Daniel Sanz, Alberto Montero
# Version: 		1.0
# Dependences:
### END INIT INFO


####
## Check last command and echo it's state
####
    check_command() {
	if [ $? -eq 0 ]; then
		echo_yellow "OK"
	else
		echo_red "FAIL"
	fi
    }

####
## Create dir if does not exist
####
    check_dir() {
	if [ ! -d $1 ]; then
		echo -n "    Creating dir $1 "
		mkdir -p $1
	else
		echo -n "    Using dir $1 "
	fi
	check_command
	}

####
## Create dir if does not exist, delete its contents otherwise
####
    clean_dir() {
	if [ ! -d $1 ]; then
		echo -n "    Creating dir $1 "
		mkdir -p $1
	else
		echo -n "    Cleaning dir $1 "
		rm -Rf $1/*
	fi
	check_command
    }

####
## Report directory - function for development
####
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
## Get parameter
####
# $1 - Which parameter would you like to get
# $2 - Get parameter from this list (usually something like ${PROJECTS[$i]})
    get_param() {
	shift $1
	echo  $1
    }

####
## Verify parameters
####
# $1 - How many parameters should be passed on, otherwise fail...
# $2 - Message to be displayed if verification failed
# $* - Parameters to be verified
    verify_params() {
	[ "$#" -lt $(($1 + 2)) ] && echo_red "$2" && exit 1
    }