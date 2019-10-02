#!/bin/sh
#
# To configure Alsamixer for voice calls do:
#
# Speaker Right -> Voice
# Call Noise Cancellation -> Unmute
# Call Output -> Speakerphone
# Call -> 100
# Mic2 -> 40
# Left -> Mic 2
# Voice -> 55
#
# And then have the following running in background to see modem
# status notifications:
#
# $ cat /dev/motmdm1 &
#

if [ "$1" == "" ]; then
	echo "usage: $0 phonenumber"
	exit 1
fi

# Use ,0 at the end for calling line id, ,1 to disable
echo "Dialing number ${1}.."
printf "ATD%s,0\r" "${1}" > /dev/motmdm1

trap hangup_ctrl_c INT

hangup_ctrl_c() {
	echo "Hanging up.."
	printf "ATH\r" > /dev/motmdm1
	exit
}

echo "Press ctrl-c to hang up"
while true; do
	# List current calls
	printf "AT+CLCC\r" > /dev/motmdm1

	# Show network strength
	printf "AT+RSSI?\r" > /dev/motmdm1
	sleep 2
done
