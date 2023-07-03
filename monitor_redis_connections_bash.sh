#!/bin/bash

nbd_env=$(ssh katie-002 "source /home/omgili/.ansible/venv/bin/activate && ansible nbd-env -i /home/omgili/ansible/hosts --list-hosts |grep -v "hosts"" |awk '{print $1}')
sparta_env=$(ssh katie-002 "source /home/omgili/.ansible/venv/bin/activate && ansible sparta -i /home/omgili/ansible/hosts --list-hosts |grep -v "hosts"" |awk '{print $1}')

max_connections=$(redis-cli config get maxclients |grep -Eo '[0-9]{0,5}')
current_connections=$(redis-cli info clients |grep -Eo '[0-9]{0,5}' |awk NR==1)
limit=$(echo "$(($max_connections * 80/100))")
ports=(7000 7001 7002)
hostname=$(echo "$HOSTNAME")

echo limit=$limit
echo current_connections=$current_connections

if [[ $current_connections -gt $limit ]]; then
	message="$HOSTNAME"' - Too Many Connections in redis'

  if [[ " ${nbd_env[*]} " =~ "$hostname" ]]; then
          python /home/omgili/scripts/send_message_to_slack.py "$message" "nbd_alerts_channel"
     elif [[ " ${sparta_env[*]} " =~ "$hostname" ]]; then
          python /home/omgili/scripts/send_message_to_slack.py "$message" "sparta_alerts_channel"
     else
          python /home/omgili/scripts/send_message_to_slack.py "$message" "devops_alerts_channel"
  fi
fi

if ! [[ -n $current_connections || $limit ]]; then
	connection_failed="$HOSTNAME"' - Failed to connect to redis'
  if [[ " ${nbd_env[*]} " =~ "$hostname" ]]; then
      	python /home/omgili/scripts/send_message_to_slack.py "$connection_failed" "nbd_alerts_channel"
     elif [[ " ${sparta_env[*]} " =~ "$hostname" ]]; then
  	python /home/omgili/scripts/send_message_to_slack.py "$connection_failed" "sparta_alerts_channel"
     else
        python /home/omgili/scripts/send_message_to_slack.py "$connection_failed" "devops_alerts_channel"
  fi
fi

if [[ $hostname == "redis-001" ]]; then   ### if hostname is redis-001
	for port in "${ports[@]}"; do    ### run on ports 7000, 7001 & 7002
		current_connection_port=$(redis-cli -p "${port}" info clients |grep -Eo '[0-9]{0,5}' |awk NR==1) ### check how many connection + specific port
		max_connections_port=$(redis-cli -p "${port}" config get maxclients |grep -Eo '[0-9]{0,5}')    ### check what is the max connections + port
		limit_port=$(echo "$(($max_connections_port * 80/100))")    ### calculate limit
		
		echo limit=$limit_port
		echo current_connections=$current_connection_port

		if [[ $current_connection_port -gt $limit_port ]]; then  ### if the current is bigger than 80%
			message_port="$HOSTNAME"'-Too Many Connections in redis' ### create a msg
			if [[ " ${nbd_env[*]} " =~ "redis-001" ]]; then   ### if the instance is member of nbd env - send a msg in the channel
				python /home/omgili/scripts/send_message_to_slack.py "$message_port" "nbd_alerts_channel"
			elif [[ " ${sparta_env[*]} " =~ "redis-001" ]]; then   ### sparta env
				python /home/omgili/scripts/send_message_to_slack.py "$message_port" "sparta_alerts_channel"
			else
				python /home/omgili/scripts/send_message_to_slack.py "$message_port" "devops_alerts_channel" ### the rest send to devops
			fi
		fi

		if ! [[ -n $current_connectionn_port || $limit_port ]]; then  ### if there is no value in current or limit - too many connection and it failes
			connection_failed_port="$HOSTNAME"'- Failed to connect to redis'
		        if [[ " ${nbd_env[*]} " =~ "redis-001" ]]; then
			        python /home/omgili/scripts/send_message_to_slack.py "$connection_failed_port" "nbd_alerts_channel"
		        elif [[ " ${sparta_env[*]} " =~ "redis-001" ]]; then
			        python /home/omgili/scripts/send_message_to_slack.py "$connection_failed_port" "sparta_alerts_channel"
		        else
			        python /home/omgili/scripts/send_message_to_slack.py "$connection_failed_port" "devops_alerts_channel"
			fi
		fi
		    

	done
fi

