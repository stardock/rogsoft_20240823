#!/bin/sh

#alias echo_date='echo $(date +%Y年%m月%d日\ %X)'
export KSROOT=/koolshare
source $KSROOT/scripts/base.sh
model=$(nvram get productid)
#=================================================

_get_model(){
	local odmpid=$(nvram get odmpid)
	local MODEL=$(nvram get productid)
	if [ -n "${odmpid}" ];then
		echo "${odmpid}"
	else
		echo "${MODEL}"
	fi
}

get_cpu_temp(){
	# CPU温度
	cpu_temp_origin=$(cat /sys/class/thermal/thermal_zone0/temp)
	cpu_temp="$(awk 'BEGIN{printf "%.1f\n",('$cpu_temp_origin'/'1000')}')°C"
}

get_sta_info(){
	# 对于华硕路由器，其2.4G的mac地址和br0相等，5G-1 mac地址需要加4，5G-2mac地址需要需要加8
	# 如 br0 mac：A0:36:BC:70:33:C0
	# 2.4G mac：A0:36:BC:70:33:C0
	# 5.2G mac：A0:36:BC:70:33:C4
	# 5.8G mac：A0:36:BC:70:33:D8
	local raido_type=$1

	local ifname_0=$(nvram get wl0_ifname)
	local ifname_1=$(nvram get wl1_ifname)
	local ifname_2=$(nvram get wl2_ifname)
	
	[ -n "${ifname_0}" ] && local mac_tail_if0=$(ifconfig ${ifname_0} | grep HWaddr | awk '{print $5}' | awk -F":" '{print $NF}' | grep -o . | tail -n1)
	[ -n "${ifname_1}" ] && local mac_tail_if1=$(ifconfig ${ifname_1} | grep HWaddr | awk '{print $5}' | awk -F":" '{print $NF}' | grep -o . | tail -n1)
	[ -n "${ifname_2}" ] && local mac_tail_if2=$(ifconfig ${ifname_2} | grep HWaddr | awk '{print $5}' | awk -F":" '{print $NF}' | grep -o . | tail -n1)
	
	[ -n "${ifname_0}" ] && local mac_tail_24g=$(ifconfig br0 | grep HWaddr | awk '{print $5}' | awk -F":" '{print $NF}' | grep -o . | tail -n1)
	[ -n "${ifname_1}" ] && local mac_tail_52g=$(awk -v x=${mac_tail_24g} 'BEGIN { printf "%02X\n", x + 4}' | grep -o . | tail -n1)
	[ -n "${ifname_2}" ] && local mac_tail_58g=$(awk -v x=${mac_tail_24g} 'BEGIN { printf "%02X\n", x + 8}' | grep -o . | tail -n1)

	### [ -n "${ifname_0}" ] && echo mac_tail_if0 $mac_tail_if0
	### [ -n "${ifname_1}" ] && echo mac_tail_if1 $mac_tail_if1
	### [ -n "${ifname_2}" ] && echo mac_tail_if2 $mac_tail_if2

	### [ -n "${ifname_0}" ] && echo mac_tail_24g $mac_tail_24g
	### [ -n "${ifname_1}" ] && echo mac_tail_52g $mac_tail_52g
	### [ -n "${ifname_2}" ] && echo mac_tail_58g $mac_tail_58g

	if [ "${mac_tail_if0}" == "${mac_tail_24g}" ];then
		interface_24g=${ifname_0}
	fi
	
	if [ "${mac_tail_if1}" == "${mac_tail_24g}" ];then
		interface_24g=${ifname_1}
	fi
	
	if [ "${mac_tail_if2}" == "${mac_tail_24g}" ];then
		interface_24g=${ifname_2}
	fi

	if [ "${mac_tail_if0}" == "${mac_tail_52g}" ];then
		interface_52g=${ifname_0}
	fi

	if [ "${mac_tail_if1}" == "${mac_tail_52g}" ];then
		interface_52g=${ifname_1}
	fi

	if [ "${mac_tail_if2}" == "${mac_tail_52g}" ];then
		interface_52g=${ifname_2}
	fi

	if [ -n "${ifname_2}" ];then
		if [ "${mac_tail_if0}" == "${mac_tail_58g}" ];then
			interface_58g=${ifname_0}
		fi

		if [ "${mac_tail_if1}" == "${mac_tail_58g}" ];then
			interface_58g=${ifname_1}
		fi

		if [ "${mac_tail_if2}" == "${mac_tail_58g}" ];then
			interface_58g=${ifname_2}
		fi
	fi
	
	### [ -n "${ifname_0}" ] && echo 2.4G: ${interface_24g}
	### [ -n "${ifname_1}" ] && echo 5.2G: ${interface_52g}
	### [ -n "${ifname_2}" ] && echo 5.8G: ${interface_58g}
}

get_tmp_pwr_hnd(){
	local __spilt__="&nbsp;&nbsp;|&nbsp;&nbsp"

	# 1. get wireless eth info
	if [ "$(_get_model)" == "RAX80" -o "$(_get_model)" == "RAX50" -o "$(_get_model)" == "RAX70" ];then
		# netgear model
		interface_24g=$(nvram get wl0_ifname)
		interface_52g=$(nvram get wl1_ifname)
	else
		# asus model
		get_sta_info
	fi

	interface_24g_isup=$(wl -i ${interface_24g} isup)
	interface_52g_isup=$(wl -i ${interface_52g} isup)
	interface_58g_isup=$(wl -i ${interface_58g} isup)

	# 2G info
	if [ "${interface_24g_isup}" == "1" ];then
		interface_24g_temp_o=$(wl -i ${interface_24g} phy_tempsense | awk '{print $1}')
		interface_24g_temp_c="$(expr ${interface_24g_temp_o} / 2 + 20)°C"
		interface_24g_pwer_o=$(wl -i ${interface_24g} txpwr_target_max | awk -F":" '{print $3}' | awk '{print $1}')
		interface_24g_pwer_d="${interface_24g_pwer_o} dBm"
		interface_24g_pwer_p="$(awk -v x=${interface_24g_pwer_o} 'BEGIN { printf "%.2f\n", 10^(x/10)}') mw"
	else
		interface_24g_temp_c="offline"
		interface_24g_pwer_d="offline"
		interface_24g_pwer_p="offline"
	fi	

	# 5G-1 info
	if [ "${interface_52g_isup}" == "1" ];then
		interface_52g_temp=$(wl -i ${interface_52g} phy_tempsense | awk '{print $1}')
		interface_52g_temp_c="$(expr ${interface_52g_temp} / 2 + 20)°C"
		interface_52g_power=$(wl -i ${interface_52g} txpwr_target_max | awk -F":" '{print $3}' | awk '{print $1}')
		interface_52g_pwer_d="${interface_52g_power} dBm"
		interface_52g_pwer_p="$(awk -v x=${interface_52g_power} 'BEGIN { printf "%.2f\n", 10^(x/10)}') mw"
	else
		interface_52g_temp_c="offline"
		interface_52g_pwer_d="offline"
		interface_52g_pwer_p="offline"
	fi

	# 5G-2/6G info
	if [ "${interface_58g_isup}" == "1" ];then
		interface_58g_temp=$(wl -i ${interface_58g} phy_tempsense | awk '{print $1}')
		interface_58g_temp_c="$(expr ${interface_58g_temp} / 2 + 20)°C"
		interface_58g_power=$(wl -i ${interface_58g} txpwr_target_max | awk -F":" '{print $3}' | awk '{print $1}')
		interface_58g_pwer_d="${interface_58g_power} dBm"
		interface_58g_pwer_p="$(awk -v x=${interface_58g_power} 'BEGIN { printf "%.2f\n", 10^(x/10)}') mw"
	else
		interface_58g_temp_c="offline"
		interface_58g_pwer_d="offline"
		interface_58g_pwer_p="offline"
	fi

	# intergrare info
	if [ -n "${interface_58g}" ];then
		if [ "${model}" == "GT-AXE11000" -o "${model}" == "ET8" -o "${model}" == "ET12" -o "${model}" == "RT-BE96U" ];then
			wl_temp="2.4G：${interface_24g_temp_c} ${__spilt__} 5G：&nbsp;${interface_52g_temp_c} ${__spilt__} 6G：&nbsp;${interface_58g_temp_c}"
		else
			wl_temp="2.4G：${interface_24g_temp_c} ${__spilt__} 5G-1：${interface_52g_temp_c} ${__spilt__} 5G-2：${interface_58g_temp_c}"
		fi
		
		if [ -n "${interface_24g_power}" -o -n "${interface_52g_power}" -o -n "${interface_58g_power}" ];then
			if [ "${model}" == "GT-AXE11000" -o "${model}" == "ET8" -o "${model}" == "ET12" -o "${model}" == "RT-BE96U" ];then
				wl_txpwr="2.4G：${interface_24g_pwer_d} / ${interface_24g_pwer_p} <br /> 5G：&nbsp;${interface_52g_pwer_d} / ${interface_52g_pwer_p} <br /> 6G：&nbsp;${interface_58g_pwer_d} / ${interface_58g_pwer_p}"
			else
				wl_txpwr="2.4G：${interface_24g_pwer_d} / ${interface_24g_pwer_p} <br /> 5G-1：${interface_52g_pwer_d} / ${interface_52g_pwer_p} <br /> 5G-2：${interface_58g_pwer_d} / ${interface_58g_pwer_p}"
			fi
		else
			wl_txpwr=""
		fi
	else
		wl_temp="2.4G：${interface_24g_temp_c} ${__spilt__} 5G： ${interface_52g_temp_c}"

		if [ -n "${interface_24g_power}" -o -n "${interface_52g_power}" ];then
			wl_txpwr="2.4G：${interface_24g_pwer_d} / ${interface_24g_pwer_p} <br /> 5G：&nbsp;&nbsp;&nbsp;${interface_52g_pwer_d} / ${interface_52g_pwer_p}"
		fi
	fi
}
get_mhz(){
	cpu_mhz="null"
	if [ -x "/koolshare/bin/mhz" ];then
		cpu_mhz=$(/koolshare/bin/mhz -c)
	fi
}

get_system_info(){
	kernel_ver=$(uname -r 2>/dev/null)
	hardware_type=$(uname -m 2>/dev/null)
	#build_date_cst=$(uname -v | cut -d " " -f4-9)

	if [ "$(nvram get odmpid)" == "TUF-AX4200Q" -o "$(nvram get odmpid)" == "TX-AX6000" -o "$(nvram get odmpid)" == "ZenWiFi_BD4" -o "$(nvram get odmpid)" == "TUF_6500" -o "$(nvram get odmpid)" == "GS7" ];then
		build_date_cst=$(uname -v | awk '{print $(NF-5),$(NF-4),$(NF-3),$(NF-2),$NF}')
		build_date=$(date -D "%a %b %d %H:%M:%S %Y" -d "${build_date_cst}" +"%Y-%m-%d %H:%M:%S")
	else
		build_date_cst=$(uname -v | awk '{print $(NF-5),$(NF-4),$(NF-3),$(NF-2),$(NF-1),$NF}')
		build_date=$(date -D "%a %b %d %H:%M:%S %Z %Y" -d "${build_date_cst}" +"%Y-%m-%d %H:%M:%S")
	fi

	# BCM: #1 SMP PREEMPT Wed Jan 22 22:58:22 CST 2025
	# MTK: #1 SMP Mon May 6 18:18:06 CST 2024
	if [ -z "${kernel_ver}" ];then
		kernel_ver="null"
	fi

	if [ -z "${hardware_type}" ];then
		hardware_type="null"
	fi
	
	if [ -z "${build_date}" ];then
		build_date="null"
	fi
}
get_tmp_pwr_mtk(){
	local __spilt__="&nbsp;&nbsp;|&nbsp;&nbsp"
	interface_24g_temp_c=$(iwpriv ra0 stat | grep "CurrentTemperature" | head -n1 | awk -F '= ' '{print $2}')°C
	interface_52g_temp_c=$(iwpriv rax0 stat | grep "CurrentTemperature" | head -n1 | awk -F '= ' '{print $2}')°C

	wl_temp="2.4G：${interface_24g_temp_c} ${__spilt__} 5G： ${interface_52g_temp_c}"
}

get_tmp_pwr_ipq(){
	#网卡温度
	WIFI_2G_DISABLE=$(iwconfig ath0|grep "Encryption key:off")
	WIFI_5G_DISABLE=$(iwconfig ath1|grep "Encryption key:off")
	
	interface_2g_temperature=$(thermaltool -i wifi0 -get|sed -n 's/.*temperature: \([0-9][0-9]\).*/\1/p') 2>/dev/null
	interface_5g1_temperature=$(thermaltool -i wifi1 -get|sed -n 's/.*temperature: \([0-9][0-9]\).*/\1/p') 2>/dev/null
	[ -z "${WIFI_2G_DISABLE}" ] && interface_2g_temperature_c="${interface_2g_temperature}°C" || interface_2g_temperature_c="offline"
	[ -z "${WIFI_5G_DISABLE}" ] && interface_5g1_temperature_c="${interface_5g1_temperature}°C" || interface_5g1_temperature_c="offline"
	wl_temp="2.4G：${interface_2g_temperature_c} &nbsp;&nbsp;|&nbsp;&nbsp; 5G：${interface_5g1_temperature_c}"
	
	interface_2g_power=$(iwconfig ath0|sed -n 's/.*Tx-Power.*\([0-9][0-9]\).*/\1/p') 2>/dev/null
	interface_5g1_power=$(iwconfig ath1|sed -n 's/.*Tx-Power.*\([0-9][0-9]\).*/\1/p') 2>/dev/null
	[ -z "${WIFI_2G_DISABLE}" ] && interface_2g_power_d="${interface_2g_power} dBm" || interface_2g_power_d="offline"
	[ -z "${WIFI_2G_DISABLE}" ] && interface_2g_power_p="$(awk -v x=${interface_2g_power} 'BEGIN { printf "%.2f\n", 10^(x/10)}') mw" || interface_2g_power_p="offline"
	[ -z "${WIFI_5G_DISABLE}" ] && interface_5g1_power_d="${interface_5g1_power} dBm" || interface_5g1_power_d="offline"
	[ -z "${WIFI_5G_DISABLE}" ] && interface_5g1_power_p="$(awk -v x=${interface_5g1_power} 'BEGIN { printf "%.2f\n", 10^(x/10)}') mw" || interface_5g1_power_p="offline"
	wl_txpwr="2.4G：${interface_2g_power_d} / ${interface_2g_power_p} <br /> 5G：&nbsp;&nbsp;&nbsp;${interface_5g1_power_d} / ${interface_5g1_power_p}"
}

get_tmp_pwr(){
	if [ "$(nvram get odmpid)" == "TX-AX6000" -o "$(nvram get odmpid)" == "TUF-AX4200Q" -o "$(nvram get odmpid)" == "RT-AX57_Go" -o "$(nvram get odmpid)" == "GS7" ];then
		get_tmp_pwr_mtk
	elif [ "$(nvram get odmpid)" == "ZenWiFi_BD4" -o "$(nvram get odmpid)" == "TUF_6500" ];then
		get_tmp_pwr_ipq
	else
		get_tmp_pwr_hnd
	fi
}

get_cpu_temp
get_tmp_pwr
get_mhz
get_system_info
#=================================================
http_response "${cpu_temp}@@${wl_temp}@@${wl_txpwr}@@${cpu_mhz}@@${kernel_ver}@@${hardware_type}@@${build_date}"
