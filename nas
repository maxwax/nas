#!/bin/bash

#
# nas - simple script to mount personal NAS mount points
#
# Currently limited to mounting and unmounting nfs shares, expandable to others
#

VERSION="1.3.0"
VERSION_DATE="2022-0908"

# Configuration file with our defined NAS mount points and protocols
NAS_CONFIG_FILE=/etc/nas.conf

# Define these variable here so they're global when used in functions
HOST_OK=false
MOUNTED_FS=false

NFS_V3_OPTIONS="-t nfs -o nfsvers=3"
NFS_V4_OPTIONS="-t nfs -o nfsvers=4"

if [[ $EUID != 0 ]]
then
  echo "Error: Please run this script as root or with sudo".
  exit 1
fi

# Before we try mounting and wait for a long time, ping the nas server
# to ensure it's online and available
function check_host {

  # Default to false and return this back to the calling code
  HOST_OK=false

  # Ping the host once and see if its resolvable on the network
  ping -c 1 $NAS_SERVER > /dev/null 2>&1
  if [[ $? == 0 ]]
  then
    HOST_OK=true
  fi

}

# Before unmounting a filesystem, verify that its mounted
function check_mount {

  REPORT_MOUNT=${1:-"null"}

  # Default to false and return this back to the calling code
  MOUNTED_FS=false

  MOUNT_COUNT=$(mount | fgrep $NAS_MOUNT_LOCAL | cut -d " " -f 1 | wc -l)
  if [[ $MOUNT_COUNT == 1 ]]
  then
    MOUNTED_FS=true

    # Optional parameter tells us to report this mount to the user, for 'status'
    if [[ $REPORT_MOUNT == "report" ]]
    then
     mount | fgrep $NAS_MOUNT_LOCAL
    fi
  else
    if [[ $REPORT_MOUNT == "report" ]]
    then
      echo $NAS_MOUNT_LOCAL "unmounted"
    fi
  fi
}

# Mount an NFS share
function mount_nfs {

  # Check that the NAS servers is online
  check_host filer
  if [[ $HOST_OK == true ]]
  then
    if [[ ! -d $NAS_MOUNT_LOCAL ]]
    then
      echo "FAIL."
      echo " ERROR: mount point $NAS_MOUNT_LOCAL does not exist."
    else
      case $NAS_PROTOCOL in
        "nfs"|"nfs3"|"nfsv3")
          mount $NFS_V3_OPTIONS $NAS_SERVER:$NAS_MOUNT_REMOTE $NAS_MOUNT_LOCAL
          RESULT=$?
        ;;
        "nfs4"|"nfsv4")
          mount $NFS_V4_OPTIONS $NAS_SERVER:$NAS_MOUNT_REMOTE $NAS_MOUNT_LOCAL
          RESULT=$?

        ;;
      esac
      if [[ $RESULT == 0 ]]
      then
        echo "Mounted."
        if [[ $DEBUG ]]
        then
          mount | grep $NAS_MOUNT_LOCAL
        fi
      fi
    fi

  else
    echo "Host unavailable, not mounting."
  fi
}

# Unmount a local filesystem
function unmount_fs {

  check_mount $NAS_MOUNT_LOCAL
  if [[ $MOUNTED_FS == true ]]
  then
    echo "Unmounting $NAS_MOUNT_LOCAL"
    umount $NAS_MOUNT_LOCAL
    # Report status to user just in case it was not unmounted properly
    mount | grep $NAS_MOUNT_LOCAL
  fi
}

function list_mounts {
  # List all lines in the config file that start with 'id_'

  if [[ $(grep -e "^id_" $NAS_CONFIG_FILE | wc -l) -eq 0 ]]
  then
    echo "Error: There are no mount points configured in the configuration file."
    exit 1
  else
    NAS_TMP_FILE="/tmp/nas.tmp.$$"
    grep -e "^id_" $NAS_CONFIG_FILE > $NAS_TMP_FILE

    HEADER_COLUMNS="%-2s %-7s  %14s:%-22s %-23s %4s\n"
    DATA_COLUMNS="%-20s\n   %-8s  %14s:%-22s %-23s %4s\n"
    printf "$HEADER_COLUMNS" \
           "ID" "(Group)" "SERVER" "SOURCE" "TARGET" "NFSv"

    grep -e "^id_" $NAS_CONFIG_FILE | \
      while read MOUNT_ID MOUNT_GROUP NAS_SERVER NAS_PROTOCOL NAS_MOUNT_REMOTE NAS_MOUNT_LOCAL
    do
      printf "$DATA_COLUMNS" \
             $MOUNT_ID $MOUNT_GROUP $NAS_SERVER \
             $NAS_MOUNT_REMOTE $NAS_MOUNT_LOCAL $NAS_PROTOCOL
      echo
    done
    echo
  fi
}

function usage {
  # Report syntax usage to user

  echo "nas $VERSION - Automatically mount sets of Network Attached Storage"
  echo
  echo "Syntax:"
  echo "nas [options] <mount|unmount>"
  echo
  echo "--list       List available mount id lines from configuration file"
  echo "--help       Print this syntax information"
  echo "--debug      Enable verbose debugging information (if any)"
  echo
}

#----------------------------------------------------------------------------
# MAIN PROCESSING
#----------------------------------------------------------------------------

if [[ ! -f "$NAS_CONFIG_FILE" ]]
then
  echo "Error: Please configure $NAS_CONFIG_FILE with your NAS mount points"
  exit 1
fi

# Action parameter from user is required
#ACTION=${1:-"null"}

CMD_LIST=false

# Default to acting on items tagged default
GROUP="default"

while [ "$1" != "" ]
do
	case $1 in
		-d | --debug )
      echo "Debugging mode enabled"
			DEBUG=true
    ;;

		-h | --help )
		  usage
		  exit 0
    ;;

    # Show the mount status of each item in the config file
    # (regardless of group)
    "status")
      ACTION="status"
    ;;

    "mount")
      ACTION="mount"
      if [[ ! -z ${2} ]]
      then
        GROUP=$2
        if [[ $DEBUG ]]
        then
          echo "Set mount option to $GROUP"
        fi
      fi
    ;;

    "umount"|"unmount"|"un")
      ACTION="unmount"
      if [[ ! -z ${2} ]]
      then
        GROUP=$2
        if [[ $DEBUG ]]
        then
          echo "Set unmount option to $GROUP"
        fi
      fi
    ;;

    "list")
      ACTION="list"
    ;;

	esac
	shift
done

if [[ $DEBUG ]]
then
  echo "ACTION is $ACTION"
  echo "GROUP is  $GROUP"
fi

if [[ $ACTION == "" ]]
then
  echo "Error: You must specify an action to take"
  usage
  exit 1
fi

if [[ $GROUP == "default" ]]
then
  if [[ $ACTION == "mount" ]]
  then
    echo "Mounting all default filesystems"
  else
    echo "Unmounting all default filesystems - Use 'all' to unmount everything"
  fi
fi

case $ACTION in
  "mount"|"unmount")
    # Process very line of config file, acting on each item
    grep -e "^id_" $NAS_CONFIG_FILE | \
      while read MOUNT_ID \
                 MOUNT_GROUP \
                 NAS_SERVER \
                 NAS_PROTOCOL \
                 NAS_MOUNT_REMOTE \
                 NAS_MOUNT_LOCAL
    do
      # Ignore commented out lines
      if [[ ${NAS_SERVER:0:1} != "#" ]]
      then
        # Act on either all lines or lines matching a specific group
        if [[ $GROUP == "all" || $MOUNT_GROUP == "$GROUP" || $MOUNT_ID == "id_${GROUP}" ]]
        then
          case $ACTION in
            "mount")
              printf "Mounting %-14s %-16s (%-4s) at %-16s  " ${NAS_SERVER} ${NAS_MOUNT_REMOTE} $NAS_PROTOCOL $NAS_MOUNT_LOCAL
              mount_nfs
            ;;
            "unmount" | "umount")
              unmount_fs
            ;;
          esac
        fi
      fi
    done
  ;;

  "status")
    # Process very line of config file, acting on each item
    grep -e "^id_" $NAS_CONFIG_FILE | \
      while read MOUNT_ID \
                 MOUNT_GROUP \
                 NAS_SERVER \
                 NAS_PROTOCOL \
                 NAS_MOUNT_REMOTE \
                 NAS_MOUNT_LOCAL
    do
      if [[ ${NAS_SERVER:0:1} != "#" ]]
      then
        check_mount report
      fi
    done
  ;;

  "list")
    list_mounts
  ;;
esac
