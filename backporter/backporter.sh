#!/bin/bash

# T contains all translations
declare -A T;
# K contains all keys in the $target_english_path file
declare -a K;
# L contains all locales in target_dir
declare -a L;
# key prefix for new (source) english key names
declare new_english="N";
# key prefix for old (target) english key names
declare old_english="O";
# key prefix for new (source) language key names
declare new_lang="n";
# key prefix for old (target) language key names
declare old_lang="o";

declare file_prefix="Language";
declare file_ext="properties";
declare file_sep="_";

declare english_file="${file_prefix}.${file_ext}";
declare source_dir
declare target_dir
declare lang_file;
declare source_english_path;
declare target_english_path;
declare source_lang_path;
declare target_lang_path;


#### Base functions

# returns true if line is a translation line (as opposed to comments or blank lines), false otherwise
# $1 is the line
function is_key_line() {
	[ $(echo $1 | grep = -c) -gt 0 ]
}
# returns true if key exists in array T, false otherwise
# $1 is the key prefix
# $2 is the key name
function exists_key() {
	[ ${T[$1,$2]+abc} ]
}
# returns true if value of a given key has changed amongst 2 key prefixes, false otherwise
# $1 is one key prefix
# $2 is the other key prefix
# $3 is the key name
function value_changed() {
	[[ ${T[$1,$3]} != ${T[$2,$3]} ]]
}
# returns the result of counting occurrences of a regexp in the T value given by provided keys
# $1 is one key prefix
# $2 is the key name
# $3 is the regex which occurrences will be counted
function grep_value() {
	echo ${T[$1,$2]} | grep -E "$3" -c
}

#### Core API functions

function english_value_changed() {
	value_changed $new_english $old_english $1
}
function lang_value_changed() {
	value_changed $new_lang $old_lang $1
}
function exists_in_new() {
	exists_key $new_english $1
}
function exists_in_old() {
	exists_key $old_english $1
}
function is_translated() {
	[[ $(grep_value $1 $2 "(Automatic [^)]+?)") -eq 0 ]]
}
function is_automatic_copy() {
	[[ $(grep_value $1 $2 "(Automatic Copy)") -gt 0 ]]
}
function is_automatic_translation() {
	[[ $(grep_value $1 $2 "(Automatic Translation)") -gt 0 ]]
}

#### Top level functions

# sets source and target paths for Language.properties files
function set_english_paths() {
	source_english_path=$source_dir/$english_file
	target_english_path=$target_dir/$english_file
}

# sets source and target paths for Language_$1.properties files
function set_lang_paths() {
	lang_file="${file_prefix}${file_sep}$1.${file_ext}";
	source_lang_path=$source_dir/$lang_file
	target_lang_path=$target_dir/$lang_file
}

# reads a file and inserts keys in T (also in K if applicable)
# $1 is the file name path
# $2 is the key prefix where keys will be stored
function read_locale_file() {
	lines=$(cat $1 | wc -l)
	echo -n "  Reading file $1        "
	counter=0
	while read line; do
		perc=$(( 100 * (counter+1) / lines ))
		printf "\b\b\b\b\b"
		printf "%5s" "${perc}%"
		(( counter++ ))
		if is_key_line "$line" ; then
			key=$(echo $line | sed s/=.*//)
			value=$(echo $line | sed -E s/^[^=]+=//)
			T[$2,$key]=$value
			if [[ $2 == $old_english ]]; then
				K[${#K[@]}]=$key
			fi;
		else
			: #echo -n "."
		fi
	done < $1
	echo;
}

function backport() {
	echo
	echo "Backporting to $1"
	clear_translations
	read_lang_files $1
	file="${target_lang_path}.backported"
	file_hrr_improvements="${target_lang_path}.review.improvements"
	file_hrr_changes="${target_lang_path}.review.changes"
    declare -A result;
	result_string="";
	echo -n "  Writing into $file: "

	rm -f $file $file_hrr_improvements $file_hrr_changes
	while read line; do
		result[$file]="$line"
		result[$file_hrr_improvements]="$line"
		result[$file_hrr_changes]="$line"
		char="x"
		if is_key_line "$line" ; then
			key=$(echo $line | sed s/=.*//)						# Let process the key....
			if exists_in_new $key; then							# key exists in newer version
				if is_translated $new_lang $key; then			#	key is translated in the newer version :)
					if is_translated $old_lang $key; then		#		key is also translated in the old version
						if english_value_changed $key; then		#			english original changed amongst versions 	> there is a semantic change, human review required
							result[$file_hrr_changes]="${key}=${T[$new_lang,$key]}"
							char="r"
						else									#			english unchanged amongst versions
							if lang_value_changed $key; then	#				translation changed amongst version		> there is a refinement, human review requirement
								result[$file_hrr_improvements]="${key}=${T[$new_lang,$key]}"
								char="R"
							else								#				translation unchanged amongst version		> none to do
								char="."
							fi
						fi
					else										#		key is not translated in the old version		> lets try to backport it
						if english_value_changed $key; then		#			english original changed amongst versions 	> there is a semantic change, human review required
							result[$file_hrr_changes]="${key}=${T[$new_lang,$key]}"
							char="r"
						else									#			english unchanged amongst versions 			> backport it!
							result[$file]="${key}=${T[$new_lang,$key]}"
							char="B"
						fi
					fi
				else											#	key is untranslated in the newer version			> almost none to do :(
					if is_automatic_copy $old_lang $key; then	#		old translation is a mere copy
						if is_automatic_translation $new_lang $key; then #	new translation is automatic				> lets backport
							result[$file]="${key}=${T[$new_lang,$key]}"
							char="b"
						else
							char="c"
						fi
					else
						char="t"
					fi
				fi
			else												# key doesn't exist in newer version
				char="X"
			fi
		else
			char="#"
		fi
		echo ${result[$file]} >> $file
		echo ${result[$file_hrr_improvements]} >> $file_hrr_improvements
		echo ${result[$file_hrr_changes]} >> $file_hrr_changes
		echo -n $char
		result_string=$result_string$char"\n"
	done < $target_lang_path
	echo;
	echo "  Summary" # commented echoes will be displayed in verbose mode (future option)
	echo "  - $(echo -e $result_string | grep B -c) keys backported"
	#echo "  - $(echo -e $result_string | grep b -c) automatically translated keys backported "
	echo "  - $(echo -e $result_string | grep X -c) deprecated keys which don't exist in $source_english_path"
	#echo "  - $(echo -e $result_string | grep x -c) uncovered cases"
	if [[ $(diff $target_lang_path $file_hrr_improvements | wc -l) -eq 0 ]]; then
		rm  $file_hrr_improvements;
		#echo "  - No improvements over previous translations in $target_lang_path"
	else
		echo "  - $(echo -e $result_string | grep R -c) improvements over previous translations. Please review $file_hrr_improvements. You can diff it with $target_lang_path"
	fi
	if [[ $(diff $target_lang_path $file_hrr_changes | wc -l) -eq 0 ]]; then
		rm  $file_hrr_changes;
		#echo "  - No semantic changes in $target_lang_path"
	else
		echo "  - $(echo -e $result_string | grep r -c) semantic changes. Please review $file_hrr_changes. You can diff it with $target_lang_path"
	fi
}

function clear_translations() {
	for key in "${K[@]}"; do
		unset 'T[$new_lang,$key]'
	 	unset 'T[$old_lang,$key]'
	done;
}

function echo_legend() {
	echo
	echo "Backport Legend:"
	echo "   #: No action, line is a comment"
	echo "   X: No action, key doesn't exist in newer version"
	echo "   t: No action, key is automatic translated in older version and untranslated in newer one"
	echo "   c: No action, key is automatic copied both in older and newer versions"
	echo "   b: Backport!, key is automatic copied in older and automatic translated in newer one."
	echo "   B: Backport!, key untranslated in older and translated in newer one, same english meaning."
	echo "   r: No action, key translated in newer, but different english meaning. Human review required (semantic change, echoed to $file_hrr_changes)"
	echo "   R: No action, key translated in newer and older, translations are different but same english meaning. Human review required (refinement, echoed to $file_hrr_improvements)"
	echo "   .: No action, key translated in newer and older, same english meaning and translation"
	echo "   x: No action, uncovered case"
	echo
	echo "Done."
}

function read_english_files() {
	echo "Reading english files"
	set_english_paths
	read_locale_file $source_english_path $new_english
	read_locale_file $target_english_path $old_english
}

function read_lang_files() {
	set_lang_paths $1
	read_locale_file $source_lang_path $new_lang
	read_locale_file $target_lang_path $old_lang
}

function compute_locales() {
	for language_file in $(ls $target_dir/${file_prefix}${file_sep}*.$file_ext); do
		locale=$(echo $language_file | sed -E "s:$target_dir\/${file_prefix}${file_sep}([^\.]+).$file_ext:\1:")
		L[${#L[@]}]=$locale
	done
	locales="${L[@]}"
	echo "Backport process will be done for '$locales'"
}

function usage() {
	echo "Usage: $0 <source dir> <target dir>"
	echo "   <source dir> and <target dir> must contain language files (Language.properties et al)"
	#echo "   <locale> is the locale where the backport is to be applied"
	echo "   Translations will be backported from source to target. Only language files in target are backported"
	exit 1
}

echo "Liferay language key backporter v0.3"
test $# -eq 2 || usage;
source_dir=$1
target_dir=$2
compute_locales
read_english_files
for locale in "${L[@]}"; do
	backport $locale
done
echo_legend


#### test functions

function test_old_keys() {
	for key in "${K[@]}"; do
		echo "$key:"

		echo -n " - is_translated: "
		if (is_translated $old_lang $key); then
			echo "yes"
		else
			echo "no"
		fi;
		echo -n " - is_automatic_copy: "
		if is_automatic_copy $old_lang $key; then
		echo "yes"
		else
			echo "no"
		fi;
		echo -n " - is_automatic_translation: "
		if is_automatic_translation $old_lang $key; then
			echo "yes"
		else
			echo "no"
		fi;
		echo -n " - english_value_changed: "
		if english_value_changed $key; then
			echo "yes"
		else
			echo "no"
		fi;
		echo -n " - lang_value_changed: "
		if lang_value_changed $key; then
			echo "yes"
		else
			echo "no"
		fi;
		echo -n " - exists_in_new: "
		if exists_in_new $key; then
			echo "yes"
		else
			echo "no"
		fi;
		echo -n " - exists_in_old: "
		if exists_in_old $key; then
			echo "yes"
		else
			echo "no"
		fi;
		echo;
	done;
}
