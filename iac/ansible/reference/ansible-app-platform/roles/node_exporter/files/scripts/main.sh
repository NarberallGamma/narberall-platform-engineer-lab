#!/bin/bash

 #ALL: search for string all:check1 check2 check3 ...
 for i in $(grep "^all:" /etc/prometheus/scripts/list_of_checks| awk -F\: '{print $3}');do
   #execute checkN script
   period=$(grep "^all:" /etc/prometheus/scripts/list_of_checks| awk -F\: '{print $2}')
   current_min=$(date +%M)
   if [ $period = "15" ];then
	if [ $current_min = "0" ] || [ $current_min = "15" ] || [ $current_min = "30" ] || [ $current_min = "45" ]; then
          /etc/prometheus/scripts/${i}.sh > /var/run/prometheus/${i}.prom
	fi
   fi
 done


 #search for string hostname:check1 check2 check3 ...
 for i in $(grep `hostname` /etc/prometheus/scripts/list_of_checks| awk -F\: '{print $2}');do
   #execute checkN script
   /etc/prometheus/scripts/${i}.sh > /var/run/prometheus/${i}.prom
 done
 
