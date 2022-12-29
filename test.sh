#!/bin/bash
yum install expect tcl-devel -y

while read line; do
    rule=$(echo $line | awk '!/^$|#|dockerversion|kubernetesversion|LoadBalancerIp/{print $1}')     #取节点角色
    hostname=$(echo $line | awk '!/^$|#|dockerversion|kubernetesversion|LoadBalancerIp/{print $2}') #主机名
    ip=$(echo $line | awk '!/^$|#|dockerversion|kubernetesversion|LoadBalancerIp/{print $3}')       #ip
    username=$(echo $line | awk '!/^$|#|dockerversion|kubernetesversion|LoadBalancerIp/{print $4}') #用户名
    password=$(echo $line | awk '!/^$|#|dockerversion|kubernetesversion|LoadBalancerIp/{print $5}') #密码
    port=$(echo $line | awk '!/^$|#|dockerversion|kubernetesversion|LoadBalancerIp/{print $6}')     #ssh端口
    if [ ! "$rule" == '' ]; then
        
    fi
done \
    <base.sh
