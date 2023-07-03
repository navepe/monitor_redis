#!/bin/bash

nbd_env=$(ssh katie-002 "source /home/omgili/.ansible/venv/bin/activate && ansible nbd-env -i /home/omgili/ansible/hosts --list-hosts |grep -v "hosts"" |awk '{print $1}')
sparta_env=$(ssh katie-002 "source /home/omgili/.ansible/venv/bin/activate && ansible sparta -i /home/omgili/ansible/hosts --list-hosts |grep -v "hosts"" |awk '{print $1}')

max_connections=$(redis-cli config get maxclients |grep -Eo '[0-9]{0,5}')
current_connections=$(redis-cli info clients |grep -Eo '[0-9]{0,5}' |awk NR==1)
limit=$(echo "$(($max_connections * 80/100))")
ports=(7000 7001 7002)
hostname=$(echo "$HOSTNAME")
redis_instance="redis-001"

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

if [[ $hostname == $redis_instance ]]; then
	for port in "${ports[@]}"; do
		current_port=$(redis-cli -p "${port}" info clients |grep -Eo '[0-9]{0,5}' |awk NR==1)
		if [[ $current_port ]]; then
			echo "Redis is running on ${port}"
		else
			echo "Redis is not running on this ${port}"
		fi
	done
fi

