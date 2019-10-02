#!/bin/sh

characters="$1"
card="1"
time="0.1"

send_dtmf() {
	card="${1}"
	tone="${2}"
	time="${3}"

	if ! amixer -q -c "${card}" sset "Call DTMF" "${tone}"; then
		echo "Setting DTMF tone ${tone} failed"
		return 1
	fi

	if ! amixer -q -c "${card}" sset "Call DTMF Send" on; then
		echo "Enabling DTMF ${tone} failed, trying to disable"
	fi
	sleep "${time}"
	if ! amixer -q -c "${card}" sset "Call DTMF Send" off; then
		echo "Disabling DTMF ${tone} failed"
		return 1
	fi
}

len=$(echo -n "${characters}" | wc -m)
i=0
while [ "${i}" -lt "${len}" ]; do
	tone=$(echo "${characters:$i:1}" | tr '[:lower:]' '[:upper:]')
	echo -n "${tone}"
	if ! send_dtmf "${card}" "${tone}" "${time}"; then
		exit 1
	fi
	sleep "${time}"
	let "i++"
done
echo
