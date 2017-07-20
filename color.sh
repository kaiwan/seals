#!/bin/bash
#------------------------------------------------------------------
# color.sh
#
# Common convenience routines for color support in bash.
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

#------------------- Colors!! Yay :-) -----------------------------------------
# Ref: https://stackoverflow.com/questions/5947742/how-to-change-the-output-color-of-echo-in-linux
# [Ans by Drew Noakes]
#--- Foreground Colors
fg_black() { tput setaf 0 
}
fg_red() { tput setaf 1
}
fg_green() { tput setaf 2 
}
fg_yellow() { tput setaf 3
}
fg_blue() { tput setaf 4
}
fg_magenta() { tput setaf 5
}
fg_cyan() { tput setaf 6
}
fg_white() { tput setaf 7
}
fg_grey() { tput setaf 8
}
 
#--- Background Colors
bg_white() { tput setab 7
}
bg_red() { tput setab 1
}
bg_yellow() { tput setab 3
}
bg_blue() { tput setab 4
}
bg_cyan() { tput setab 6
}

#--- Text Attributes  <-- NOK!
#tb=$(tput bold)  # bold
#tsb=$(tput smso)  # enter standout bold mode
#trb=$(tput rmso)  # exit standout bold mode
#trev=$(tput rev)  # reverse video
#tdim=$(tput dim)  # half-brightness
#tBell=$(tput bel)  # sound bell!

#--- Composite text attribs [ta] <-- NOK!
#taErr="${tb}${fg_red}${bg_white}${tBell}"
#taTitle="${tb}${fg_black}${bg_yellow}"
#taReg=""  # 'regular' msgs
#taBold="$(tput bold)"
#taBold="${tb}"
#taAbnormal="${fg_white}${bg_blue}"  # 'Abnormal' msgs - error msgs,...
#taDebug="${tdim}"

#  Reset text attributes to normal without clearing screen.
color_reset()
{ 
   tput sgr0 
} 

#--------------------- E c h o ----------------------------------------
# The _base_ echo/logging function.
# Parameters:
# $1        : a tag that speicifies the text attribute
# $2 ... $n : message to echo (to stdout and logfile)
# !WARNING! 
# Ensure you don't call any of the x[Ee]cho functions from here, as they
# call this func and it becomes infinitely recursive.
Echo()
{
 local SEP=" "
# echo "# = $# : params: $@"
 [ $# -eq 0 ] && return 1
 local numparams=$#
 local tag="${1}"
 [ ${numparams} -gt 1 ] && shift  # get rid of the tag, so that we can access the txt msg

# TODO - prefix the logging level : debug/info/warn/critical

 local dt=$(date +%a_%d%b%Y_%T.%N)
 local msgpfx1="[${dt}]"
 #local msgpfx1="[${dt}]"
 local msgpfx2="${SEP}${name}${SEP}${FUNCNAME[ 1 ]}()${SEP}"
 local msgtxt="$@"
 local msgfull_log="${msgpfx1}${msgpfx2}${msgtxt}"

 echo "${msgfull_log}" >> ${LOGFILE_COMMON}  # lets log it first anyhow

 if [ ${numparams} -eq 1 -o ${gCOLOR} -eq 0 ]; then   # no color/text attribute
    [ ${DEBUG} -eq 1 ] && echo "${msgfull_log}" || echo "${msgpfx1}${SEP}${msgtxt}" 
    return 0
 fi

 #--- 'color' or text attrib present!
 fg_green
 echo -n "${msgpfx1}${SEP}"
 [ ${DEBUG} -eq 1 ] && {
   fg_blue
   echo -n "${msgpfx2}"
 }
 color_reset                      # Reset to normal.
 
 case "${tag}" in
   REG)  #tput        # Deliberate: no special attribs for 'regular'
         ;;
   WARN) fg_white ; bg_red ; tput bold
         ;;
   ABNORMAL) fg_white ; bg_blue ; tput bold
         ;;
   BOLD)  tput bold
         ;;
   DDEBUG) tput dim ; fg_grey
         ;;
 esac

 echo "${msgtxt}"
 color_reset                      # Reset to normal.
 return 0
} # end Echo()

#--- Wrappers over Echo follow ---
# Parameters:
# $1 : message to echo (to stdout and logfile)

#--------------------- d e c h o --------------------------------------
# Debug echo :-)
decho()
{
 #[ $# -eq 0 ] && return 1
 [ ${DEBUG} -eq 1 ] && Echo DDEBUG "$1"
}
#--------------------- c e c h o ---------------------------------------
# Regular Color-echo.
cecho ()
{
 Echo REG "$1"
}
#--------------------- b e c h o ---------------------------------------
# Bold Color-echo.
becho ()
{
 Echo BOLD "$1"
}
#--------------------- a e c h o ---------------------------------------
# "Abnormal" message Color-echo.
aecho ()
{
 Echo ABNORMAL "$1"
}
#--------------------- w e c h o ---------------------------------------
# Warning message Color-echo.
wecho ()
{
 Echo WARN "$1"
}

#---


test_256()
{
for i in $(seq 0 255)
do
  tput setab $i
  printf '%03d ' $i
done
color_reset
}

