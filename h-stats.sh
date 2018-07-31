#!/usr/bin/env bash

#######################
# Functions
#######################


get_cards_hashes(){
        # hs is global
        hs=''
	for (( i=0; i < ${GPU_COUNT_NVIDIA}; i++ )); do
		local MHS=`cat $LOG_NAME | grep "Device \#${i}-${i} speed:" | tail -n 1 | awk '{ printf $7 }'`
		hs[$i]=`echo $MHS`
	done
}

get_nvidia_cards_temp(){
        echo $(jq -c "[.temp$nvidia_indexes_array]" <<< $gpu_stats)
}

get_nvidia_cards_fan(){
        echo $(jq -c "[.fan$nvidia_indexes_array]" <<< $gpu_stats)
}

get_miner_uptime(){
        local tmp=$(cat $DATE | head -n 1 | awk '{print}')
        local start=$(date +%s -d "$tmp")
        local now=$(date +%s)
        echo $((now - start))
}

get_total_hashes(){
        # khs is global
 	 local speed=`cat $LOG_NAME | grep -a "speed" | tail -n 1`
	 local rate=`echo $speed | awk '{printf $8"\n"}'`
	 local Total=0
	 case $rate in
        	 H/s)
                	 Total=`echo $speed | awk '{printf $7/1000}'`
         ;;
         	kH/s)
                	 Total=`echo $speed | awk '{printf("%.f\n", $7)}'`
         ;;
         	MH/s)
                	 Total=`echo $speed | awk '{printf("%.f\n", $7*1000)}'`
         ;;
         *)
                 	 Total=0
         ;;
	 esac
	 echo $Total
}

get_log_time_diff(){
        local getLastLogTime=`tail -n 100 $LOG_NAME | tail -n 1 | awk {'print $1'} | cut -b 11-18`
        local logTime=`date --date="$getLastLogTime" +%s`
        local curTime=`date +%s`
        echo `expr $curTime - $logTime`
}

#######################
# MAIN script body
#######################

. /hive/custom/$CUSTOM_MINER/h-manifest.conf
local LOG_NAME="$CUSTOM_LOG_BASENAME.log"
local DATE="$CUSTOM_LOG_BASENAME.date.log"

[[ -z $GPU_COUNT_NVIDIA ]] &&
        GPU_COUNT_NVIDIA=`gpu-detect NVIDIA`



# Calc log freshness
local diffTime=$(get_log_time_diff)
local maxDelay=120

# echo $diffTime

# If log is fresh the calc miner stats or set to null if not
if [ "$diffTime" -lt "$maxDelay" ]; then
        local hs=
        get_cards_hashes                                        # hashes array
        local hs_units='hs'                             # hashes utits
        local temp=$(get_nvidia_cards_temp)     # cards temp
        local fan=$(get_nvidia_cards_fan)               # cards fan
        local uptime=$(get_miner_uptime)        # miner uptime
        local algo=$(cat $LOG_NAME | head -n 20 | grep -a "add" | awk '{printf $4"\n"}')                 # algo

        # A/R shares by pool
        local ac=`cat $LOG_NAME | grep -c "accepted"`
        local rj=`cat $LOG_NAME | grep -c "rejected"`

        # make JSON
        stats=$(jq -nc \
                                --argjson hs "`echo ${hs[@]} | tr " " "\n" | jq -cs '.'`" \
                                --arg hs_units "$hs_units" \
                                --argjson temp "$temp" \
                                --argjson fan "$fan" \
                                --arg uptime "$uptime" \
                                --arg ac "$ac" --arg rj "$rj" \
                                --arg algo "$algo" \
                                '{$hs, $hs_units, $temp, $fan, $uptime, ar: [$ac, $rj], $algo}')
        # total hashrate in khs
        khs=$(get_total_hashes)
else
        stats=""
        Mhs=0
fi

# debug output
##echo temp:  $temp
##echo fan:   $fan
#echo stats: $stats
#echo khs:   $khs
