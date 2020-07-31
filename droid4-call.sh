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
# $ cat /dev/gsmtty1 &
#

if [ "$1" == "" ]; then
	echo "usage: $0 phonenumber"
	exit 1
fi

# Use ,0 at the end for calling line id, ,1 to disable
echo "Dialing number ${1}.."
printf "U1234ATD%s,0\r" "${1}" > /dev/gsmtty1

trap hangup_ctrl_c INT

hangup_ctrl_c() {
	echo "Hanging up.."
	printf "U1234ATH\r" > /dev/gsmtty1
	exit
}

echo "Press ctrl-c to hang up"
while true; do
	# List current calls
	printf "U1234AT+CLCC\r" > /dev/gsmtty1

	# Show network strength
	printf "U1234AT+RSSI?\r" > /dev/gsmtty1
	sleep 2
done
