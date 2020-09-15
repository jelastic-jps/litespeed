#!/bin/bash 

XMLSTARLET=$(which xmlstarlet) 
ED_CMD="ed --inplace"

setWorkers() { 
   WORKERS_COUNT=${1} 
   if [ -n "${WORKERS_COUNT}" ] && [[ "${WORKERS_COUNT}" =~ ^[0-9]+$ ]] && [ "${WORKERS_COUNT}" -ge "0" ] && [ "${WORKERS_COUNT}" -le "128" ] >/dev/null; then 
       true 
   else 
       echo '{"result":"5001","message":"Wrong value. Please use the integer between 0 and 128"}'; 
       return 1; 
   fi 
   if [ -e /var/www/conf/lslbd_config.xml ]; then 
       SERVER_CONFIG="/var/www/conf/lslbd_config.xml" 
       CONFIG_XPATH="loadBalancerConfig" 
   else 
       SERVER_CONFIG="/var/www/conf/httpd_config.xml" 
       CONFIG_XPATH="httpServerConfig" 
   fi 
   local xmlstarlet_output=$(mktemp);
   $XMLSTARLET $ED_CMD -d "${CONFIG_XPATH}/workerProcesses" ${SERVER_CONFIG} &>>${xmlstarlet_output}; 
   $XMLSTARLET $ED_CMD -s "${CONFIG_XPATH}" -t elem -n "workerProcesses" -v ${WORKERS_COUNT} ${SERVER_CONFIG} &>>${xmlstarlet_output} && echo '{"result":"0","message":"Value applied successfully"}' || { local log_message=$(cat ${xmlstarlet_output}| tr -d '"\n'); echo "{\"result\":\"5002\",\"message\":\"Error occured. Value is not applied\",\"log\":\"$log_message\"}"; rm -f ${xmlstarlet_output}; return 2; }
   rm -f ${xmlstarlet_output}
}

case ${1} in 
   setWorkers) 
       setWorkers "${2}" 
       ;; 
esac
