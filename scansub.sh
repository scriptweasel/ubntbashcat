#!/bin/bash

USER1=ubnt
USER2=username
PASS1=ubnt
PASS2=password1
PASS3=password2

function scanunit() {

FIRMWARE="$(sshpass -p $USEPASS ssh -o StrictHostKeyChecking=no $USEUSER@$DEVIP cat /etc/version)"
BOARDVER="$(sshpass -p $USEPASS ssh -o StrictHostKeyChecking=no $USEUSER@$DEVIP cat /etc/board.info | grep board.name  | awk -F'=' '{print $2}')"
CPEMAC="$(sshpass -p $USEPASS ssh -o StrictHostKeyChecking=no $USEUSER@$DEVIP cat /etc/board.info | grep board.hwaddr | sed 's/\(\w\w\)\(\w\w\)\(\w\w\)\(\w\w\)\(\w\w\)\(\w\w\)/\1:\2:\3:\4:\5:\6/g' | awk -F'=' '{print $2}')"
HOSTNM="$(sshpass -p $USEPASS ssh -o StrictHostKeyChecking=no $USEUSER@$DEVIP cat /tmp/system.cfg | grep resolv.host.1.name | awk -F'=' '{print $2}')"
SITESSID="$(sshpass -p $USEPASS ssh -o StrictHostKeyChecking=no $USEUSER@$DEVIP cat /tmp/system.cfg | grep wireless.1.ssid | awk -F'=' '{print $2}')"
NETMODE="$(sshpass -p $USEPASS ssh -o StrictHostKeyChecking=no $USEUSER@$DEVIP cat /tmp/system.cfg | grep netmode | awk -F'=' '{print $2}')"
#echo $NETMODE

if [ "$NETMODE" = "bridge" ]; then
#   echo "Unit is bridge mode."
   BRTBL="$(sshpass -p $USEPASS ssh -o StrictHostKeyChecking=no $USEUSER@$DEVIP brctl showmacs br0 | grep  $'  2\t' | grep -v yes | awk '{print $2}' | grep -c '')"
   if [ "$BRTBL" = 1 ]; then
#   echo $BRTBL
      RTRMAC="$(sshpass -p $USEPASS ssh -o StrictHostKeyChecking=no $USEUSER@$DEVIP brctl showmacs br0 | grep  $'  2\t' | grep -v yes | awk '{print $2}')"
#      echo "Expected router MAC: $RTRMAC"
   else
      if [ "$BRTBL" = 0 ]; then
#         echo "No non-local MACs exists on bridge table relative to the ethernet port.  Try to reboot radio, or ask customer to reboot router."
         RTRMAC="NO_BRMAC"
      else
#         echo "Too many non-local MACs on bridge table for ethernet.  Are you sure this is a CPE radio?"
         RTRMAC="TOO_MANY"
      fi
   fi
   #asdf
else
   if [ "$NETMODE" = "router" ]; then
#      echo "Unit is router mode."
	  DHCPTBL="$(sshpass -p $USEPASS ssh -o StrictHostKeyChecking=no $USEUSER@$DEVIP cat /var/tmp/dhcpd.leases | grep -c '')"
#	  echo "$DHCPTBL"
      if [ "$DHCPTBL" = 1 ]; then
         RTRMAC="$(sshpass -p $USEPASS ssh -o StrictHostKeyChecking=no $USEUSER@$DEVIP cat /var/tmp/dhcpd.leases | awk '{print $2}')"
#         echo "Expected router MAC: $RTRMAC"
      else
	 if [ "$DHCPTBL" = 0 ]; then
#	    echo "No dhcp server leases are currently in radio.  Try to reboot radio, or ask customer to reboot router."
            RTRMAC="NO_LEASES"
         else
#            echo "Too many non-local MACs on DHCP clients table.  Likely that router is in bridge mode."
            RTRMAC="RTR_BRIDGE"
         fi
      fi
   else
#      echo "Error determining unit mode."
       RTRMAC="MODE_ERROR"
   fi
fi

echo "$FIRMWARE - $BOARDVER - $CPEMAC - $NETMODE - $RTRMAC - $HOSTNM - $SITESSID"
echo "$DEVIP,$USEUSER,$USEPASS,$FIRMWARE,$BOARDVER,$CPEMAC,$NETMODE,$RTRMAC,$HOSTNM,$SITESSID" >> $FILEOUT

}

function network_address_to_ips() {
  # define empty array to hold the ip addresses
  ips=()
  # create array containing network address and subnet
  network=(${1//\// })
  # split network address by dot
  iparr=(${network[0]//./ })
  # check for subnet mask or create subnet mask from CIDR notation
  if [[ ${network[1]} =~ '.' ]]; then
    netmaskarr=(${network[1]//./ })
  else
    if [[ $((8-${network[1]})) -gt 0 ]]; then
      netmaskarr=($((256-2**(8-${network[1]}))) 0 0 0)
    elif  [[ $((16-${network[1]})) -gt 0 ]]; then
      netmaskarr=(255 $((256-2**(16-${network[1]}))) 0 0)
    elif  [[ $((24-${network[1]})) -gt 0 ]]; then
      netmaskarr=(255 255 $((256-2**(24-${network[1]}))) 0)
    elif [[ $((32-${network[1]})) -gt 0 ]]; then
      netmaskarr=(255 255 255 $((256-2**(32-${network[1]}))))
    fi
  fi
  # correct wrong subnet masks (e.g. 240.192.255.0 to 255.255.255.0)
  [[ ${netmaskarr[2]} == 255 ]] && netmaskarr[1]=255
  [[ ${netmaskarr[1]} == 255 ]] && netmaskarr[0]=255
  # generate list of ip addresses
  for i in $(seq 0 $((255-${netmaskarr[0]}))); do
    for j in $(seq 0 $((255-${netmaskarr[1]}))); do
      for k in $(seq 0 $((255-${netmaskarr[2]}))); do
        for l in $(seq 1 $((255-${netmaskarr[3]}-1))); do
          ips+=( $(( $i+$(( ${iparr[0]}  & ${netmaskarr[0]})) ))"."$(( $j+$(( ${iparr[1]} & ${netmaskarr[1]})) ))"."$(($k+$(( ${iparr[2]} & ${netmaskarr[2]})) ))"."$(($l+$((${iparr[3]} & ${netmaskarr[3]})) )) )
        done
      done
    done
  done
}


while getopts ":n:f:h" opt; do
  case $opt in
    n)
      CLIP=$OPTARG
      ;;
    f)
      FLOT=$OPTARG
      ;;
    h)
      echo ""
      echo "Usage:"
      echo "-------------"
      echo " -n IP.AD.DR.SS/SU.BN.ET.XX or -n IP.AD.DR.SS/CIDR"
      echo " -f Filename to store positive results in"
      echo " -h Duh... you used this option to display this"
      echo "-------------"
      echo ""
      exit
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done



#CLIP=$1
if [[ -n "$CLIP" ]]; then
  DEVIP2=$CLIP
else
  echo -n "Enter IP/Subnt :"; read DEVIP2
fi

#FLOT=$2
if [[ -n "$FLOT" ]]; then
  FILEOUT=$FLOT
else
  echo -n "Filename for results:"; read FILEOUT
fi

NETWK="$(echo $DEVIP2 | awk -F/ '{print $1}')"
SCIDR="$(echo $DEVIP2 | awk -F/ '{print $2}')"

echo "Network $NETWK, Subnet $SCIDR"
#######################sed -i.$(date +%s).bak '/172./d' ~/.ssh/known_hosts

network_address_to_ips $DEVIP2

for DEVIP in "${ips[@]}"
do
  echo -n "Is $DEVIP alive? -> "
  ping -q -c2 $DEVIP > /dev/null
  if [ "$?" = 0 ]; then
    echo "Yes"

echo -n "Is Mikrotik? -> "

############################# nmap -Pn -oG 8291test -p 8291 $DEVIP 2> /dev/null
MTIK="$(nmap -p 8291 -oG - $DEVIP | grep Ports | awk '{print $5}' | awk -F'/' '{print $2}')"
if [[ $MTIK == "open" ]] || [[ $MTIK == "filtered" ]]; then
   echo "Yes, skipping";
   #echo "$DEVIP -> MTIK" >> 216sub.txt
else
## echo $MTIK
   echo "Doesn't appear so"
   #echo "$DEVIP -> Not MTIK?" >> 216sub.txt
   HASSSH="$(nmap -p 22 -oG - $DEVIP | grep Ports | awk '{print $5}' | awk -F'/' '{print $2}')"
   if [[ $HASSSH == "open" ]] || [[ $HASSSH == "filtered" ]]; then
      echo -n "Authenticating to $DEVIP -> "
      sshpass -p $PASS1 ssh -o StrictHostKeyChecking=no $USER1@$DEVIP exit 2> /dev/null
      if [ "$?" = 0 ]; then
         echo "Authenticated $USER1 - $PASS1"
         USEUSER=$USER1; USEPASS=$PASS1
         scanunit
      else
         sshpass -p $PASS2 ssh -o StrictHostKeyChecking=no $USER2@$DEVIP exit 2> /dev/null
         if [ "$?" = "0" ]; then
            echo "Authenticated $USER2 - $PASS2"
            USEUSER=$USER2; USEPASS=$PASS2
            scanunit
         else
            sshpass -p $PASS1 ssh -o StrictHostKeyChecking=no $USER2@$DEVIP exit 2> /dev/null
            if [ "$?" = "0" ]; then
               echo "Authenticated $USER2 - $PASS1"
               USEUSER=$USER2; USEPASS=$PASS1
               scanunit
            else
               sshpass -p $PASS2 ssh -o StrictHostKeyChecking=no $USER1@$DEVIP exit 2> /dev/null
               if [ "$?" = "0" ]; then
                  echo "Authenticated $USER1 - $PASS2"
                  USEUSER=$USER1; USEPASS=$PASS2
                  scanunit
               else
                  sshpass -p $PASS3 ssh -o StrictHostKeyChecking=no $USER1@$DEVIP exit 2> /dev/null
                  if [ "$?" = "0" ]; then
                     echo "Authenticated $USER1 - $PASS3"
                     USEUSER=$USER1; USEPASS=$PASS3
                     scanunit
                  else
                     echo "Can't Authenticate"
####               exit
                  fi
               fi
            fi
         fi
      fi
   fi



##exit




fi






  else
    echo "No"
  fi

done



exit

