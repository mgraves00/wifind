#!/bin/sh

# Copyright (c) 2018 Michael Graves <mgraves@brainfat.net>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.


dprint() {
	if [ $DEBUG -eq 0 ]; then
		echo "$*"
	else
		echo `date` ": $*" >> $DEBUG_LOG
	fi
}

# taken from OpenBSD /usr/src/distrib/miniroot/install.sub
stripcom() {
	local _f=$1 _line
	[[ -f $_f ]] || return
	while read _line; do
		[[ -n ${_line%%#*} ]] && print -r -- "$_line"
	done <$_f
}

# taken from OpenBSD /usr/src/distrib/miniroot/install.sub
isin() {
	local _a=$1 _b
	shift
	for _b; do
		[[ $_a == "$_b" ]] && return 0
	done
	return 1
}

# taken from OpenBSD /usr/src/distrib/miniroot/install.sub
addel() {
	local _a=$1
	shift
	isin "$_a" $* && echo -n "$*" || echo -n "${*:+$* }$_a"
}

scan_wifi() {
	local _if=$1 _ssids
	_ssids=`ifconfig $_if scan | sed -nr -e 's/^[	 ]+nwid\ ([^ ]+)\ .*$/\1/p' | sed -r -e /\"\"/d`
	echo $_ssids
}

check_file() {
	local _f=$1 _stat
	if [ ! -f $1 ]; then
		dprint "$_f: file not found"
		return 1
	fi
	set -A _stat -- $(ls -nL $_f)
	if [[ "${_stat[0]}${_stat[2]}${_stat[3]}" != *---00 ]]; then
		dprint "$_f: bad permissions"
		return 1
	fi
	return 0
}

find_ssid() {
	local _a=$1 _b
	shift
	isin $_a $* && return 0
	return 1
}

usage() {
	echo "${0##*/} [-d] [-f config file] <interface>"
	exit 2
}

#### 

CFG=/etc/wifind
DEBUG=0
DEBUG_LOG="/tmp/wifind.log"
args=`getopt df: $*`
if [ $? -ne 0 ]; then
	usage
	# not reached
fi
set -- $args
while [ $# -ne 0 ]; do
	case "$1" in
	-d)
		DEBUG=1; shift;;
	-f)
		CFG="$2"; shift; shift;;
	--)
		shift; break;;
	esac
done

check_file $CFG || exit 1

if [ $# -lt 1 ]; then
	dprint "no interface specified"
	usage
	# not reached
fi
_if=$1; shift

# Make sure interface is up
ifconfig $_if up 2>/dev/null
sleep 5
_active_wifi="$(scan_wifi $_if)"
if [ ${#_active_wifi} -eq 0 ]; then
	dprint "no wifi found"
	exit 0
fi
stripcom $CFG | \
while IFS=: read -- _ssid _pass _opts; do
	if find_ssid $_ssid "$_active_wifi"; then
		ifconfig $_if -nwid -nwkey 2>/dev/null
		ifconfig $_if -wpa 2>/dev/null
		ifconfig $_if nwid $_ssid wpa wpakey $_pass $_opts 2>/dev/null || \
			dprint "error enabling $_ssid on $_if"; && \
			dprint "connected to $_ssid on $_if"
		break
	fi
done
# no ssid's found
exit 0
