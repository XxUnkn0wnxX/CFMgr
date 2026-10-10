#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Pure supplied selected-WAN IPv4 policy for the admitted two-unit Ethernet
# DHCP/static/PPPoE/PPTP/L2TP profile. Source trusted modules/lib/ip.sh first.
# Sourcing defines functions only; subshells isolate caller state and scratch.
# Inputs must come from one completely acquired firmware/profile/config
# observation. These reports establish no freshness, egress or publish authority.

cfmgr_wan4_selection_report() (
	[ "$#" -eq 8 ] || return 1
	case $1 in
	off | fo | fb | lb | -) ;;
	*) return 1 ;;
	esac
	for _cfmgr_wan4_flag in "$2" "$3" "$5" "$6"; do
		case $_cfmgr_wan4_flag in
		0 | 1 | -) ;;
		*) return 1 ;;
		esac
	done
	case $4 in
	0 | 1 | -1 | -) ;;
	*) return 1 ;;
	esac
	_cfmgr_wan4_scope0=-
	_cfmgr_wan4_scope1=-
	if [ "$7" != - ]; then
		_cfmgr_wan4_scope0=$(cfmgr_ipv4_classify "$7") || return 1
		case $_cfmgr_wan4_scope0 in
		global | private | shared | nonpublic) ;;
		*) return 1 ;;
		esac
	fi
	if [ "$8" != - ]; then
		_cfmgr_wan4_scope1=$(cfmgr_ipv4_classify "$8") || return 1
		case $_cfmgr_wan4_scope1 in
		global | private | shared | nonpublic) ;;
		*) return 1 ;;
		esac
	fi

	# Validate even operands unused by the selected policy before any shortcut.
	_cfmgr_wan4_state=unknown
	_cfmgr_wan4_unit=-
	case $1 in
	-) _cfmgr_wan4_reason=mode-unavailable ;;
	off | fo | fb)
		case $2:$3 in
		1:0)
			_cfmgr_wan4_unit=0
			_cfmgr_wan4_reason=primary
			;;
		0:1)
			_cfmgr_wan4_unit=1
			_cfmgr_wan4_reason=primary
			;;
		-:* | *:-) _cfmgr_wan4_reason=primary-unavailable ;;
		*) _cfmgr_wan4_reason=primary-ambiguous ;;
		esac
		;;
	lb)
		case $4 in
		0 | 1)
			_cfmgr_wan4_unit=$4
			_cfmgr_wan4_reason=ddns-unit
			;;
		-) _cfmgr_wan4_reason=selector-unavailable ;;
		-1)
			if [ "$5" = - ] || [ "$6" = - ]; then
				_cfmgr_wan4_reason=connection-unavailable
			elif { [ "$5" = 1 ] && [ "$7" = - ]; } ||
				{ [ "$6" = 1 ] && [ "$8" = - ]; }; then
				_cfmgr_wan4_reason=address-unavailable
			elif [ "$5" = 1 ] && [ "$_cfmgr_wan4_scope0" = global ]; then
				_cfmgr_wan4_unit=0
				_cfmgr_wan4_reason=auto-global
			elif [ "$6" = 1 ] && [ "$_cfmgr_wan4_scope1" = global ]; then
				_cfmgr_wan4_unit=1
				_cfmgr_wan4_reason=auto-global
			elif [ "$5" = 1 ]; then
				_cfmgr_wan4_unit=0
				_cfmgr_wan4_reason=auto-connected
			elif [ "$6" = 1 ]; then
				_cfmgr_wan4_unit=1
				_cfmgr_wan4_reason=auto-connected
			else
				_cfmgr_wan4_reason=no-connected-wan
			fi
			;;
		esac
		;;
	esac
	if [ "$_cfmgr_wan4_unit" != - ]; then _cfmgr_wan4_state=selected; fi

	# Every output field is validated ASCII; the body includes its final LF.
	_cfmgr_wan4_row=$(printf 'wan4-selection\t1\t%s\t%s\t%s' \
		"$_cfmgr_wan4_state" "$_cfmgr_wan4_unit" "$_cfmgr_wan4_reason") || return 1
	_cfmgr_wan4_body_bytes=$((${#_cfmgr_wan4_row} + 1))
	printf '%s\nend\t%s\n' "$_cfmgr_wan4_row" "$_cfmgr_wan4_body_bytes" || return 1
) 2>/dev/null

cfmgr_wan4_source_report() (
	[ "$#" -eq 5 ] || return 1
	case $1 in
	0 | 1 | -) ;;
	*) return 1 ;;
	esac
	case $2 in
	dhcp | static | pppoe | pptp | l2tp | disabled | unsupported | -) ;;
	*) return 1 ;;
	esac
	for _cfmgr_wan4_ifname in "$3" "$4"; do
		[ "$_cfmgr_wan4_ifname" != - ] || continue
		[ "${#_cfmgr_wan4_ifname}" -le 15 ] || return 1
		case $_cfmgr_wan4_ifname in
		[abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789]*) ;;
		*) return 1 ;;
		esac
		case $_cfmgr_wan4_ifname in
		*[!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-]*) return 1 ;;
		esac
	done
	_cfmgr_wan4_scope=-
	if [ "$5" != - ]; then
		_cfmgr_wan4_scope=$(cfmgr_ipv4_classify "$5") || return 1
		case $_cfmgr_wan4_scope in
		global | private | shared | nonpublic) ;;
		*) return 1 ;;
		esac
	fi

	_cfmgr_wan4_state=unknown
	_cfmgr_wan4_interface=-
	_cfmgr_wan4_address=-
	if [ "$1" = 0 ]; then
		# Only the explicit enable flag proves administrative disablement.
		_cfmgr_wan4_state=inactive
		_cfmgr_wan4_reason=administratively-disabled
	elif [ "$1" = - ]; then
		_cfmgr_wan4_reason=enable-unavailable
	else
		_cfmgr_wan4_selected_interface=-
		case $2 in
		dhcp | static) _cfmgr_wan4_selected_interface=$3 ;;
		pppoe | pptp | l2tp) _cfmgr_wan4_selected_interface=$4 ;;
		esac
		if [ "$2" = disabled ] || [ "$2" = unsupported ] || [ "$2" = - ]; then
			# Firmware protocol coercion does not prove intentional disablement.
			_cfmgr_wan4_reason=protocol-unavailable
		elif [ "$_cfmgr_wan4_selected_interface" = - ]; then
			_cfmgr_wan4_reason=interface-unavailable
		elif [ "$5" = - ] || [ "$5" = 0.0.0.0 ]; then
			_cfmgr_wan4_reason=address-unavailable
		elif [ "$_cfmgr_wan4_scope" = nonpublic ]; then
			_cfmgr_wan4_reason=address-nonpublic
		else
			_cfmgr_wan4_state=candidate
			_cfmgr_wan4_interface=$_cfmgr_wan4_selected_interface
			_cfmgr_wan4_address=$5
			_cfmgr_wan4_reason=native-address
		fi
	fi

	_cfmgr_wan4_row=$(printf 'wan4-source\t1\t%s\t%s\t%s\t%s' \
		"$_cfmgr_wan4_state" "$_cfmgr_wan4_interface" \
		"$_cfmgr_wan4_address" "$_cfmgr_wan4_reason") || return 1
	_cfmgr_wan4_body_bytes=$((${#_cfmgr_wan4_row} + 1))
	printf '%s\nend\t%s\n' "$_cfmgr_wan4_row" "$_cfmgr_wan4_body_bytes" || return 1
) 2>/dev/null
