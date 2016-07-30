#!/bin/bash

# Version 2.0.6, Adapted for AOSPA.
# Used by CrystalPA

# We don't allow scrollback buffer
echo -e '\0033\0143'
clear

function gettop
{
	local TOPFILE=build/core/envsetup.mk
	if [ -n "$TOP" -a -f "$TOP/$TOPFILE" ] ; then
	echo $TOP
	else
	if [ -f $TOPFILE ] ; then
		# The following circumlocution (repeated below as well) ensures
		# that we record the true directory name and not one that is
		# faked up with symlink names.
		PWD= /bin/pwd
		else
		# We redirect cd to /dev/null in case it's aliased to
		# a command that prints something as a side-effect
		# (like pushd)
		local HERE=$PWD
		T=
		while [ \( ! \( -f $TOPFILE \) \) -a \( $PWD != "/" \) ]; do
		cd .. > /dev/null
		T=`PWD= /bin/pwd`
		done
	cd $HERE > /dev/null
		if [ -f "$T/$TOPFILE" ]; then
		echo $T
		fi
		fi
	fi
}


# Get current path
DIR="$(cd `dirname $0`; pwd)"
TOP="$(gettop)"
OUT="$(readlink $TOP/out)"
[ -z "${OUT}" ] && OUT="${TOP}/out"

# Prepare output customization commands
red=$(tput setaf 1)             #  red
grn=$(tput setaf 2)             #  green
blu=$(tput setaf 4)             #  blue
cya=$(tput setaf 6)             #  cyan
txtbld=$(tput bold)             # Bold
bldred=${txtbld}$(tput setaf 1) #  red
bldgrn=${txtbld}$(tput setaf 2) #  green
bldblu=${txtbld}$(tput setaf 4) #  blue
bldcya=${txtbld}$(tput setaf 6) #  cyan
txtrst=$(tput sgr0)             # Reset

#check for architecture
ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')

# Local defaults, can be overriden by environment
: ${PREFS_FROM_SOURCE:="false"}
: ${THREADS:="$(cat /proc/cpuinfo | grep "^processor" | wc -l)"}

# If there is more than one jdk installed, use latest 7.x
if [ "`update-alternatives --list javac | wc -l`" -gt 1 ]; then
        JDK7=$(dirname `update-alternatives --list javac | grep "\-7\-"` | tail -n1)
        JRE7=$(dirname ${JDK7}/../jre/bin/java)
        export PATH=${JDK7}:${JRE7}:$PATH
fi
JVER=$(javac -version  2>&1 | head -n1 | cut -f2 -d' ')

# Import command line parameters
DEVICE="$1"
EXTRAS="$2"

if [ $ARCH = "64" ]; then

# Get build version
MAJOR=$(cat $TOP/vendor/cpa/main.mk | grep 'ROM_VERSION_MAJOR := *' | sed  's/ROM_VERSION_MAJOR := //g')
MINOR=$(cat $TOP/vendor/cpa/main.mk | grep 'ROM_VERSION_MINOR := *' | sed  's/ROM_VERSION_MINOR := //g')
MAINTENANCE=$(cat $TOP/vendor/cpa/vendor.mk | grep 'ROM_VERSION_MAINTENANCE := *' | sed  's/CPA_VERSION_MAINTENANCE := //g')
CPA=$(cat $TOP/vendor/cpa/main.mk | grep 'ROM_VERSION_TAG := *' | sed  's/ROM_VERSION_TAG := //g')

if [ -n "$TAG" ]; then
        VERSION=$MAJOR.$MINOR$MAINTENANCE
else
        VERSION=$MAJOR.$MINOR$MAINTENANCE
fi

# If there is no extra parameter, reduce parameters index by 1
if [ "$EXTRAS" == "true" ] || [ "$EXTRAS" == "false" ]; then
        SYNC="$2"
        UPLOAD="$3"
else
        SYNC="$3"
        UPLOAD="$4"
fi

# Get start time
res1=$(date +%s.%N)

echo -e "${cya}Building ${bldcya}$CPA $VERSION for $DEVICE ${txtrst}";
echo -e "${bldgrn}Start time: $(date) ${txtrst}"

# Decide what command to execute
case "$EXTRAS" in
        threads)
                echo -e "${bldblu}Please enter desired building/syncing threads number followed by [ENTER]${txtrst}"
                read threads
                THREADS=$threads
        ;;
        clean|cclean)
                echo -e "${bldblu}Cleaning intermediates and output files${txtrst}"
                export CLEAN_BUILD="true"
                [ -d "${TOP}/out" ] && rm -Rf ${TOP}/out/*
        ;;
esac

echo -e ""

export DEVICE=$DEVICE

CHROMIUM=$(cat $TOP/vendor/cpa/products/$DEVICE/cpa_$DEVICE.mk | grep 'PREBUILD_CHROMIUM := *' | sed  's/PREBUILD_CHROMIUM := //g')
	if [ "$CHROMIUM" == "false" ]; then
        	export USE_PREBUILT_CHROMIUM=0
        	echo -e "In your $DEVICE tree CHROMIUM PREBUILT IS DISABLED!"
        else
        	export USE_PREBUILT_CHROMIUM=1        
	fi

#Generate Changelog
ZMIANY=$(cat $TOP/vendor/cpa/products/$DEVICE/cpa_$DEVICE.mk | grep 'CHCE_CHANGELOG := *' | sed  's/CHCE_CHANGELOG := //g')
	if [ "$ZMIANY" == "true" ]; then
        	export CHANGELOG=true
        	echo -e "Changelog for $DEVICE is enabled!"
        else
        	export CHANGELOG=false      
	fi

# Fetch latest sources
if [ "$SYNC" == "true" ]; then
        echo -e ""
        echo -e "${bldblu}Fetching latest sources${txtrst}"
        repo sync -j"$THREADS"
        echo -e ""
fi

if [ ! -r "${TOP}/out/versions_checked.mk" ] && [ -n "$(java -version 2>&1 | grep -i openjdk)" ]; then
        echo -e "${bldcya}Your java version still not checked and is candidate to fail, masquerading.${txtrst}"
        JAVA_VERSION="java_version=${JVER}"
fi

if [ -n "${INTERACTIVE}" ]; then
        echo -e "${bldblu}Dropping to interactive shell${txtrst}"
        echo -en "${bldblu}Remeber to lunch you device:"
        if [ "${VENDOR}" == "cpa" ]; then
                echo -e "[${bldgrn}lunch cpa_$DEVICE-userdebug${bldblu}]${txtrst}"
        else
                echo -e "[${bldgrn}lunch full_$DEVICE-userdebug${bldblu}]${txtrst}"
        fi
        bash --init-file build/envsetup.sh -i
else
        # Setup environment
        echo -e ""
        echo -e "${bldblu}Setting up environment${txtrst}"
        . build/envsetup.sh
        echo -e ""

        # lunch/brunch device
        echo -e "${bldblu}Lunching device [$DEVICE] ${cya}(Includes dependencies sync)${txtrst}"
        export PREFS_FROM_SOURCE
        lunch "cpa_$DEVICE-userdebug";
        
        echo -e "${bldblu}Starting compilation${txtrst}"
        mka bacon
fi
echo -e ""

# Get elapsed time
res2=$(date +%s.%N)
echo -e "${bldgrn}Total time elapsed: ${txtrst}${grn}$(echo "($res2 - $res1) / 60"|bc ) minutes ($(echo "$res2 - $res1"|bc ) seconds)${txtrst}"
else
echo -e "${bldred}This script only supports 64 bit architecture${txtrst}"
fi


