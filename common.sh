#!/bin/sh
#------------------------------------------------------------------
# common.sh
#
# Common convenience routines
# 
# (c) Kaiwan N Billimoria
# kaiwan -at- kaiwantech -dot- com
# MIT / GPL v2
#------------------------------------------------------------------
# The SEALS Opensource Project
# SEALS : Simple Embedded Arm Linux System
# Maintainer : Kaiwan N Billimoria
# kaiwan -at- kaiwantech -dot- com
# Project URL:
# https://github.com/kaiwan/seals

export TOPDIR=$(pwd)
ON=1
OFF=0

### UPDATE for your box
source ./err_common.sh || {
 echo "$name: could not source err_common.sh, aborting..."
 exit 1
}
source ./color.sh || {
 echo "$name: could not source color.sh, aborting..."
 exit 1
}

#-------------- r u n c m d -------------------------------------------
# Display and run the provided command.
# Parameter 1 : the command to run
runcmd()
{
local SEP="------------------------------"
[ $# -eq 0 ] && return
echo "${SEP}
$@
${SEP}"
eval $@
}

is_gui_supported()
{
 local GUI_MODE=0
 xdpyinfo >/dev/null 2>&1 && GUI_MODE=1
 # On Fedora (26), xdpyinfo fails when run as root; so lets do another check as well
 ps -e|egrep -w "X|Xorg|Xwayland" >/dev/null 2>&1 && GUI_MODE=1 || GUI_MODE=0
 #echo "GUI_MODE $GUI_MODE"
 echo ${GUI_MODE}
}

# If we're not in a GUI (X Windows) display, abort (reqd for yad)
gui_init()
{
 which xdpyinfo > /dev/null 2>&1 || {
   FatalError "xdpyinfo (package x11-utils) does not seem to be installed. Aborting...
 [Tip: try running as a regular user, not root]"
 }
 xdpyinfo >/dev/null 2>&1 || {
   FatalError "Sorry, we're not running in a GUI display environment. Aborting...
 [Tip: try running as a regular user, not root]"
 }
 which xrandr > /dev/null 2>&1 || {
   FatalError "xrandr (package x11-server-utils) does not seem to be installed. Aborting..."
 }

 #--- Screen Resolution stuff
 res_w=$(xrandr --current | grep '*' | uniq | awk '{print $1}' | cut -d 'x' -f1 | head -n1)
 res_h=$(xrandr --current | grep '*' | uniq | awk '{print $1}' | cut -d 'x' -f2 | tail -n1)
 let centre_x=${res_w}/3
 let centre_y=$res_h/3
 let centre_y=$centre_y-100

 CAL_WIDTH=$((${res_w}/3))
 let CAL_WIDTH=$CAL_WIDTH+200
 [ -z ${CAL_WIDTH} ] && CAL_WIDTH=600
 let CAL_HT=$res_h/2
 [ -z ${CAL_HT} -o ${CAL_HT} -lt 300 ] && CAL_HT=300 || true
 #echo "res_w=${res_w} res_h=${res_h} CAL_WIDTH=${CAL_WIDTH} CAL_HT=${CAL_HT}"
}

# logfile_post_process
# Issue: using the 'color' routines (like wecho, aecho, techo, etc) causes
# escape chars to get embedded into the logfile. This addresses how to get
# rid of the color escape sequences.
# $1 : logfile
logfile_post_process()
{
sed -i.bkp "/###\:\:\:/d" ${1}  # take a backup & get rid of the signature line
sed -i "s/\x1b.....//g" ${1}    # get rid of the ^[(B^[[m characters !
      # '\x1b' is ESC ! Find it, and then delete it and the following 5 chars
      # (the five .'s that follow specify this)
}

# genLogFilename
# Generates a logfile name that includes the date/timestamp
# Format:
#  ddMmmYYYY[_HHMMSS]
# Parameter(s)
# #$1 : String to prefix to log filename, null okay as well [required]
#  $1 : Include time component or not [required]
#    $1 = 0 : Don't include the time component (only date) in the log filename
#    $1 = 1 : include the time component in the log filename
genLogFilename()
{
 [ $1 -eq 0 ] && log_filename=$(date +%d%b%Y)
 [ $1 -eq 1 ] && log_filename=$(date +%d%b%Y_%H%M%S)
 echo ${log_filename}
}

# mysudo
# Simple front end to gksudo/sudo
# Parameter(s):
#  $1 : descriptive message
#  $2 ... $n : command to execute
mysudo()
{
[ $# -lt 2 ] && {
 #echo "Usage: mysudo "
 return
} || true
local msg=$1
shift
local cmd="$@"
aecho "${LOGNAME}: ${msg}"
[ ${DEBUG} -eq 1 ] && echo "mysudo():cmd: \"${cmd}\"" || true
sudo --preserve-env bash -c "${cmd}" && true
true
}

# check_root_AIA
# Check whether we are running as root user; if not, exit with failure!
# Parameter(s):
#  None.
# "AIA" = Abort If Absent :-)
check_root_AIA()
{
	if [ `id -u` -ne 0 ]; then
		Echo "Error: need to run as root! Aborting..."
		exit 1
	fi
}

# check_file_AIA
# Check whether the file, passed as a parameter, exists; if not, exit with failure!
# Parameter(s):
#  $1 : Pathname of file to check for existence. [required]
# "AIA" = Abort If Absent :-)
# Returns: 0 on success, 1 on failure
check_file_AIA()
{
	[ $# -ne 1 ] && return 1
	[ ! -f $1 ] && {
		Echo "Error: file \"$1\" does not exist. Aborting..."
		exit 1
	} || true
}

# check_folder_AIA
# Check whether the directory, passed as a parameter, exists; if not, exit with failure!
# Parameter(s):
#  $1 : Pathname of folder to check for existence. [required]
# "AIA" = Abort If Absent :-)
# Returns: 0 on success, 1 on failure
check_folder_AIA()
{
	[ $# -ne 1 ] && return 1
	[ ! -d $1 ] && {
		Echo "Error: folder \"$1\" does not exist. Aborting..."
		exit 1
	} || true
}

# check_folder_createIA
# Check whether the directory, passed as a parameter, exists; if not, create it!
# Parameter(s):
#  $1 : Pathname of folder to check for existence. [required]
# "IA" = If Absent :-)
# Returns: 0 on success, 1 on failure
check_folder_createIA()
{
	[ $# -ne 1 ] && return 1
	[ ! -d $1 ] && {
		Echo "Folder \"$1\" does not exist. Creating it..."
		mkdir -p $1 && return 0 || return 1
	} || true
}


# GetIP
# Extract IP address from ifconfig output
# Parameter(s):
#  $1 : name of network interface (string)
# Returns: IPaddr on success, non-zero on failure
GetIP()
{
	[ $# -ne 1 ] && return 1
	ifconfig $1 >/dev/null 2>&1 || return 2
	ifconfig $1 |grep 'inet addr'|awk '{print $2}' |cut -f2 -d':'
}

# get_yn_reply
# User's reply should be Y or N.
# Parameters ::
# $1       : prompt string to display
# $2 = 'y' : default is 'y', meaning, if user presses '[Enter]' key
# $2 = 'n' : default is 'n', meaning, if user presses '[Enter]' key
# Returns:
#  0  => user has answered 'Y'
#  1  => user has answered 'N'
# Lookup the value via $? in the caller.
get_yn_reply()
{
set +e   # temporarily turn off 'bash safe mode -e'
str="${1}"
while true
do
   echo -n "${str}"
   if [ "$2" = "y" ] ; then
	   echo " [y]"
   elif [ "$2" = "n" ] ; then
	   echo " [n]"
   fi
   [ $# -eq 1 ] && echo

   read -s -n1 reply    # -s: don't echo ; -n1 : read only 1 char

   case "$reply" in
   	y | yes | Y | YES ) 
		echo "<y>"
		return 0
		;;
   	n | N )	
		echo "<n>"
		return 1
		;;
	"" )    
		[ $# -eq 1 ] && {
		  echo "<no default, pl reenter your choice>"
		  continue
		}
		echo "<$2>"
		[ "$2" = "y" ] && return 0
		[ "$2" = "n" ] && return 1
		;;
   	*) aecho "*** Pl type 'Y' or 'N' ***"
   esac
done
set -e
}

# MountPartition
# Mounts the partition supplied as $1
# Parameters:
#  $1 : device node of partition to mount
#  $2 : mount point
# Returns:
#  0  => mount successful
#  1  => mount failed
MountPartition()
{
[ $# -ne 2 ] && {
 aecho "MountPartition: parameter(s) missing!"
 return 1
}

DEVNODE=$1
[ ! -b ${DEVNODE} ] && {
 aecho "MountPartition: device node $1 does not exist?"
 return 1
}

MNTPT=$2
[ ! -d ${MNTPT} ] && {
 aecho "MountPartition: folder $2 does not exist?"
 return 1
}

mount |grep ${DEVNODE} >/dev/null || {
 #echo "The partition is not mounted, attempting to mount it now..."
 mount ${DEVNODE} -t auto ${MNTPT} || {
  wecho "Could not mount the '$2' partition!"
  return 1
 }
}
return 0
}

## is_kernel_thread
# Param: PID
# Returns:
#   1 if $1 is a kernel thread, 0 if not, 127 on failure.
is_kernel_thread()
{
[ $# -ne 1 ] && {
 aecho "is_kernel_thread: parameter missing!" 1>&2
 return 127
}

prcs_name=$(ps aux |awk -v pid=$1 '$2 == pid {print $11}')
#echo "prcs_name = ${prcs_name}"
[ -z ${prcs_name} ] && {
 wecho "is_kernel_thread: could not obtain process name!" 1>&2
 return 127
}

firstchar=$(echo "${prcs_name:0:1}")
#echo "firstchar = ${firstchar}"
len=${#prcs_name}
let len=len-1
lastchar=$(echo "${prcs_name:${len}:1}")
#echo "lastchar = ${lastchar}"
[ ${firstchar} = "[" -a ${lastchar} = "]" ] && return 1 || return 0
}

#---------- c h e c k _ d e p s ---------------------------------------
# Checks passed packages - are they installed? (just using 'which';
# using the pkg management utils (apt/dnf/etc) would be too time consuming)
# Parameters:
#  $1 : 1 => fatal error, exit
#       0 => warn only
# [.. $@ ..] : space-sep string of all packages to check
# Eg.        check_deps "make perf spatch xterm"
check_deps()
{
local util needinstall=0
#report_progress

local severity=$1
shift

for util in $@
do
 which ${util} > /dev/null 2>&1 || {
   [ ${needinstall} -eq 0 ] && wecho "The following utilit[y|ies] or package(s) do NOT seem to be installed:"
   iecho "[!]  ${util}"
   needinstall=1
   continue
 }
done
[ ${needinstall} -eq 1 ] && {
   [ ${severity} -eq 1 ] && {
      FatalError "Kindly first install the required package(s) shown above \
(check console and log output too) and then retry, thanks. Aborting now..."
   } || {
      wecho "WARNING! The package(s) shown above are not present"
   }
} || true
} # end check_deps()

# Simple wrappers over check_deps();
# Recall, the fundamental theorem of software engineering FTSE:
#  "We can solve any problem by introducing an extra level of indirection."
#    -D Wheeler
# ;-)
check_deps_fatal()
{
check_deps 1 "$@"
}

check_deps_warn()
{
check_deps 0 "$@"
}

#----------------------------------------------------------------------
report_progress()
{
local frame=1
fg_grey
printf "$(date +%F.%H%M%S):${BASH_SOURCE[${frame}]}:${FUNCNAME[${frame}]}:${BASH_LINENO[0]}\n"
color_reset
}
