#!/bin/bash

#
# nas - simple script to mount personal NAS mount points
#
# Currently limited to mounting and unmounting nfs shares, expandable to others
#

VERSION="1.1.1"

# Action parameter from user is required
ACTION=${1:-"null"}

# Configuration file with our defined NAS mount points and protocols
NAS_CONFIG_FILE=/etc/nas.conf

# Define these variable here so they're global when used in functions
HOST_OK=false
MOUNTED_FS=false

NFS_V3_OPTIONS="-t nfs -o nfsvers=3"
NFS_V4_OPTIONS="-t nfs -o nfsvers=4"

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
  fi
}

if [[ ! -f "$NAS_CONFIG_FILE" ]]
then
  echo "Error: Please configure $NAS_CONFIG_FILE with your NAS mount points"
  exit 1
fi

# Process very line of config file, acting on each item
while read NAS_SERVER NAS_PROTOCOL NAS_MOUNT_REMOTE NAS_MOUNT_LOCAL
do

  # Ignore commented out lines
  if [[ ${NAS_SERVER:0:1} != "#" && ${#NAS_SERVER} -gt 0 ]]
  then
    case $ACTION in
      "mount")
        printf "Mounting %-14s %-16s (%-4s) at %-16s  " ${NAS_SERVER} ${NAS_MOUNT_REMOTE} $NAS_PROTOCOL $NAS_MOUNT_LOCAL
        mount_nfs
      ;;
      "unmount" | "umount")
        unmount_fs
      ;;
      "status")
        check_mount report
      ;;
      *)
        echo
        echo "nas <command>"
        echo
        echo "Commands: mount, unmount, status"
        echo
        exit 0
      ;;
    esac
  fi
done < "$NAS_CONFIG_FILE"
