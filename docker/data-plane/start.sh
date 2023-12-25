#!/bin/bash

# Reference: https://github.com/nginxinc/NGINX-Demos/blob/master/nginx-agent-docker/container/start.sh

handle_term()
{
    echo "received TERM signal"
    echo "stopping nginx-agent ..."
    kill -TERM "${agent_pid}" 2>/dev/null
    echo "stopping nginx ..."
    kill -TERM "${nginx_pid}" 2>/dev/null
}

trap 'handle_term' TERM

# NGINX Agent version detection, change in behaviour in v2.24.0+
AGENT_VERSION=`nginx-agent -v|awk '{print $3}'`
echo "=> NGINX Agent version $AGENT_VERSION"

# Launch nginx
echo "starting nginx ..."
su - nginx -s /bin/bash -c "/opt/app_protect/bin/bd_agent &"
su - nginx -s /bin/bash -c "/usr/share/ts/bin/bd-socket-plugin tmm_count 4 proc_cpuinfo_cpu_mhz 2000000 total_xml_memory 471859200 total_umu_max_size 3129344 sys_max_account_id 1024 no_static_config &"

while ([ ! -e /opt/app_protect/pipe/app_protect_plugin_socket ] || [ ! -e /opt/app_protect/pipe/ts_agent_pipe ])
do
 sleep 1
done

chown nginx:nginx /opt/app_protect/pipe/*
/usr/sbin/nginx -g "daemon off;" &
nginx_pid=$!

SECONDS=0
while ! ps -ef | grep "nginx: master process" | grep -v grep; do
    if (( SECONDS > 5 )); then
        echo "couldn't find nginx master process"
        exit 1
    fi
done

cat /etc/nginx-agent/nginx-agent.conf;

# start nginx-agent, pass args
echo "starting nginx-agent ..."
sg nginx-agent "/usr/bin/nginx-agent --server-host $NIM_HOST" &

agent_pid=$!

if [ $? != 0 ]; then
    echo "couldn't start the agent, please check the log file"
    exit 1
fi

wait_term()
{
    wait ${agent_pid}
    wait ${nginx_pid}
}

wait_term

echo "nginx-agent process has stopped, exiting."
