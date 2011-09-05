#!/bin/bash

# esx-halt.sh - Simple script to safely halt an ESXi host from ssh
# Copyright (C) 2011  Davide Ferrari

if [ $# -lt 1 ]
then
  cat << EOF
  Error! please specify a server name.
  
  Usage: 
	$(basename $0) SERVERNAME
EOF
 exit 255
fi

ESXI_HOST="$1"
ESXI_USER="root"
SSH_CMD="ssh -n ${ESXI_USER}@${ESXI_HOST}"
# SHUTDOWNER is used as a hack to prevent this script to shut down
# the guest where the script is running, and it must be set to a
# name known to ESXi. Leave it empty if you don't care about it.
SHUTDOWNER="ups-control"

function isVMPoweredOff() {

  $SSH_CMD "vim-cmd vmsvc/power.getstate $1"|grep -q "Powered off"

}

function shutDownVM() {

  echo -n "Shutting down VMID $1... "
  $SSH_CMD "vim-cmd vmsvc/power.shutdown $1" >/dev/null 2>&1 && { echo OK; return 0; } || { echo KO; return 255; }

}

function powerOffVM() {

  echo -n "Powering off (forcing) VMID $1... "
  $SSH_CMD "vim-cmd vmsvc/power.off $1" >/dev/null 2>&1 && { echo OK; return 0; } || { echo KO; return 255; }

}

function stopAllVMs() {

  $SSH_CMD "vim-cmd vmsvc/getallvms"|tail -n +2 |grep -v "${SHUTDOWNER}"|awk '{print $1}'|while read vmid
  do 
    if ! isVMPoweredOff $vmid
    then
      shutDownVM $vmid || powerOffVM $vmid
    fi
  done

}

function haltHost() {

  echo -e "\nNow halting the host..."
  $SSH_CMD "halt"

}

function checkAllVMsOff() {

  echo -n "Checking if all VMs are really powered off..."
  $SSH_CMD "vim-cmd vmsvc/getallvms"|tail -n +2 |grep -v "${SHUTDOWNER}"|awk '{print $1}'|while read vmid
  do
    c=0
    echo -n " $vmid"
    while ! isVMPoweredOff $vmid
    do
      sleep 5
      ((c++))
      (( c > 12 )) && { echo "Giving up on $vmid"; break; }
      echo -n "."      
    done
    echo -n " OFF"
  done

}

# do the real stuff
stopAllVMs && checkAllVMsOff && haltHost
