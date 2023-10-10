#!/bin/sh
#------------------------------------------------------------------
# err_common.sh
#
# Common error handling routines.
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
SEALS_REPORT_ERROR_EMAIL=kaiwan.billimoria@gmail.com
#SEALS_REPORT_ERROR_URL=https://github.com/kaiwan/seals/issues

#--- Icons
# src: /usr/share/icons/Humanity/actions/
ICON_NEXT=go-next
ICON_BACK=go-previous
ICON_YES=add  #go-next
ICON_NO=remove   #gtk-remove
ICON_ADD=add  #gtk-add
ICON_REGISTER=player_record
ICON_SIGNIN=format-text-direction-ltr
ICON_EXIT=stock_mark   #system-log-out


# QP
# QuickPrint ;-)
# Print timestamp, script name, line#. Useful for debugging.
# [RELOOK / FIXME : not really useful as it doen't work as a true macro;
#  just prints _this_ script name, line#.]
QP()
{
	_ERR_HDR_FMT="%.23s %s[%s]: "
	_ERR_MSG_FMT="${_ERR_HDR_FMT}%s\n"
    [ ${COLOR} -eq 1 ] && fg_blue
	printf " QP: $_ERR_MSG_FMT" $(date +%F.%T.%N) " ${BASH_SOURCE[1]##*/}:${FUNCNAME[2]}" |tee -a ${LOGFILE_COMMON}
	dumpstack
	#printf " QP: $_ERR_MSG_FMT" $(date +%F.%T.%N) " ${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]}" |tee -a ${LOGFILE_COMMON}
    [ ${COLOR} -eq 1 ] && color_reset
	unset _ERR_HDR_FMT
	unset _ERR_MSG_FMT
}

STACK_MAXDEPTH=32  # arbit?
dumpstack()
{
#for frame in $(seq 1 $1)
local frame=1
local funcname

ShowTitle " Stack Call-trace:"
[ ${COLOR} -eq 1 ] && fg_blue
while [ true ]
do
  funcname=${FUNCNAME[${frame}]}
  printf "   [frame #${frame}] ${BASH_SOURCE[${frame}]}:${funcname}:${BASH_LINENO[${frame}]}"
  #printf "   [frame #${frame}] ${funcname}"
  [ ${frame} -ne 1 ] && printf "\n" || {
    [ ${COLOR} -eq 1 ] && fg_magenta
    printf "        <-- top of stack\n"
    [ ${COLOR} -eq 1 ] && fg_blue
  }
  [ "${funcname}" = "main" ] && break  # stop, reached 'main'
  [ ${frame} -ge ${STACK_MAXDEPTH} ] && break  # just in case ...
  let frame=frame+1
done |tee -a ${LOGFILE_COMMON}
[ ${COLOR} -eq 1 ] && color_reset
}

# params: the error message
cli_handle_error()
{
  #QP
  if [ $# -lt 1 ] ; then
	cecho "FatalError :: <no errmsg>"
  else
	cecho "FatalError :: $@"
  fi
  dumpstack
  [ ${COLOR} -eq 1 ] && color_reset
  exit 1
}

#--------------------- F a t a l E r r o r ----------------------------
# Exits with exit status 1 !
# Parameters:
# $1 : error message [optional]
#
# !NOTE! Do NOT use metacharacter (like /\<> etc) in the message body;
#  yad fails to interpret them..
#
# TODO / BUG ::
#  the entire background is filled with a blue-ish color; why?? yad bug? us?
FatalError()
{
 local msgpre_gui="<b><span foreground='Crimson'>Sorry, SEALS has encountered a fatal error.</span></b>\n\n"
 local msgpre_con="Sorry, SEALS has encountered a fatal error." # con: console-mode

 local errmsg_gui="<i>Details:</i>\n$(date):${name}:${FUNCNAME[ 1 ]}()"
 local errmsg_con="Details: $(date):${name}:${FUNCNAME[ 1 ]}()"

 local msgpost_gui="\n<span foreground='Crimson'>\
If you feel this is a bug or issue, kindly file a bug report here:
 https://github.com/kaiwan/seals/issues
(Or simply copy the full output above and email it here:</span>
${SEALS_REPORT_ERROR_EMAIL}\n
Many thanks.
"
 local msgpost_con="If you feel this is a bug or issue, *please* do raise it as an Issue on this project's GitHub repo
 (https://github.com/kaiwan/seals/issues) and copy/paste the full output, adding any relevant details...
Many thanks.
"
 local msg_gui msg_con

 [ $# -ne 1 ] && {
  msg_gui="${msgpre_gui}<span foreground='NavyBlue'>${errmsg_gui}</span>\n${msgpost_gui}"
  msg_con="${msgpre_con}
${errmsg_con}
${msgpost_con}"
 } || {
  msg_gui="${msgpre_gui}<span foreground='NavyBlue'>${errmsg_gui}\n \"${1}\"</span>\n${msgpost_gui}"
  msg_con="${msgpre_con}
${errmsg_con}
${1}
${msgpost_con}"
 }
 #cecho "Fatal Error! Details: ${errmsg} ${1}"

 [ ${GUI_MODE} -eq 1 ] && {

   #echo "${msg_con}"

   local title="SEALS: FATAL ERROR!"
   yad --title="${title}" --image=dialog-warning --text="${msg_gui}" \
	--button="Close!${ICON_NO}:0" \
	--wrap --text-align=center --button-layout=center --center \
	--selectable-labels --no-escape --dialog-sep --sticky --on-top --skip-taskbar 2>/dev/null &
   # also show on the console
   cli_handle_error "${msg_con}"  #"$@"
 } || {
   cli_handle_error "${msg_con}"  #"$@"
 }
 exit 1
} # end FatalError()

# Prompt
# Interactive: prompt the user to continue by pressing ENTER or
# abort by pressing Ctrl-C
# Parameter(s):
#  $1 : string to display (string)
#  $2 : string to display on signal trap [optional]
Prompt()
{
  local msg="*** User Abort detected!  ***"

 trap 'wecho "${msg}" ; dumpstack ; color_reset ; exit 3' HUP INT QUIT

 [ ${COLOR} -eq 1 ] && fg_magenta
 echo "$1
 [Press ENTER to continue, or Ctrl-C to abort now...]"

 # Failed with: read: read error: 0: Resource temporarily unavailable
 # sol: https://stackoverflow.com/questions/54775816/read-read-error-0-resource-temporarily-unavailable
 exec 3<&0 < /dev/tty  #/dev/null
 read -r x
 
 [ ${COLOR} -eq 1 ] && color_reset
} # end Prompt()
