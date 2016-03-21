#!/bin/sh

# Requirements: zenity (optional)
#

# source configuration
cfg="$HOME/.config/usermounts/usermounts.conf"
[ -e "$cfg" ] && . $cfg || return 2


## global variables

main_password=""
main_aborted="false"
mounted_count=0
mountpoints_count=0
foreground_mounts=""
background_mounts=""
mntpoints=""
retval=1

# check if we can run zenity
{ xset -q && type zenity; } >/dev/null 2>&1 && havex=1 || havex=0

##


# get all mountpoints
get_mntpoints() {
  # print all 'mntpoint' variables from all variables
  # existing in current environment
  set | while read line; do
    case "$line" in
      mntpoint*=*) echo "$line" ;;
    esac
  done
}

# check if mountpoint can be mounted in background
in_background() {
  rv=1
  eval curbg=\$mntbg$1
  case "$curbg" in
    true|1|yes|y)
      rv=0
      ;;
  esac
  return $rv
}

# get indexes of configured mountpoints
get_mntnums() {
  for rec in $mntpoints; do
    cnum="$(echo "$rec" | { IFS='=' read mname mvalue; printf "${mname#mntpoint} "; })"
    in_background "$cnum" \
      && background_mounts="$background_mounts $cnum" \
      || foreground_mounts="$foreground_mounts $cnum"
  done
}

# prompt for password in graphics if possible, otherwise in text
ask_password() {
  unset tmp_password
  if [ "$havex" -eq 1 ]; then
    tmp_password="$(zenity --password --title="$1")"
    return $?
  else
    stty -echo
    echo -n "${1}: "
    read tmp_password
    stty echo
    echo
    [ -n "$tmp_password" ] && return 0 || return 1
  fi
}

# check if something is already mounted on the mountpoint
mounted() {
  case $(mount) in
    *$1*) return 0 ;;
    * ) return 1 ;;
  esac
}

# prompt for and save the "main" password
main_password() {
  if [ -z "$main_password" ]; then
    ask_password "Enter main password" || return 1
    main_password="$tmp_password"
  fi
  return 0
}

# prompt for unique password
new_password() {
  unset new_password
  ask_password "$1" && new_password="$tmp_password" && return 0 || return 1
}

# record mount status
set_status() {
  [ "$1" -eq 0 ] && mounted_count="$(($mounted_count + 1))"
  return $1
}

# do the mounting
mountit() {
  # repeat for every mountpoint
  for num in $@; do
    # settings for current mountpoint
    eval curmntpoint=\$mntpoint$num
    eval curmntdev=\$mntdev$num # optional
    eval curmntcmd=\$mntcmd$num
    eval curauth=\$auth$num # optional
    # check if the mountpoint exists
    [ ! -e "$curmntpoint" ] && continue
    # check if the device (directory) to mount is present
    [ -n "$curmntdev" ] && [ ! -e "$curmntdev" ] && continue
    # check if the command is set
    [ -z "$curmntcmd" ] && continue
    mountpoints_count="$(($mountpoints_count + 1))"

    # retry in case of mount failure (incorrect password?)
    for try in 1 2 3; do
      if mounted $curmntpoint ; then
        # already mounted
        set_status 0
        break
      fi

      case "$curauth" in
        # no authentication necessary
        "none"|"no"|"n")
          $curmntcmd
          set_status "$?" && break
          ;;
        # unique password for this mountpoint
        "unique"|"u")
          if new_password "Enter password for $curmntpoint"; then
            echo "$new_password" | $curmntcmd
            set_status "$?" && break
          else
            # break if password was not entered
            break
          fi
          ;;
        # by default use "main" password
        *)
          # don't ask for main password again
          [ "$main_aborted" = "true" ] && break
          if main_password; then
            echo "$main_password" | $curmntcmd
            set_status "$?" && break || main_password=""
          else
            # break if password was not entered
            # and don't ask for main password again
            main_aborted="true"
            break
          fi
          ;;
      esac
    done
  done
}

# check if everything was mounted and exit
final_checks() {
  if [ "$mounted_count" -ne "$mountpoints_count" -a "$main_aborted" = "false" ]; then
    err="Some mounts failed.
    Make sure you have the same password for all encrypted mounts where 'main' password is used.
    Make sure you have permissions to mount the device and/or that you configured sudo(8) correctly."

    [ "$havex" -eq 1 ] && zenity --warning --text="$err"
    echo "$err" >&2
  else
    # success, we can return 0
    retval=0
  fi

  exit $retval
}


## main()

mntpoints="$(get_mntpoints)"

# nothing to do if no mountpoints were specified
[ -z "$mntpoints" ] && return 0

get_mntnums

# mount everything that needs to be done in foreground
# (we need to wait until it's mounted)
mountit $foreground_mounts

# check if there is anything to be mounted in background
if [ -n "$background_mounts" ]; then
  # can we do it in background? We need zenity to prompt for password.
  if [ "$havex" -eq 1 ]; then
    # from now on, all remaining tasks needs to be done in background
    { mountit $background_mounts; final_checks; } &
  else
    mountit $background_mounts
    final_checks
  fi
fi
