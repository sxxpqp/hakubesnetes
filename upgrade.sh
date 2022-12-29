#！/bin/bash
set -e
#设置升级版本
upgradeversion=1.22.16

# 日志颜色
tm=$(date +'%Y%m%d %T')
COLOR_G="\x1b[0;32m" # green
RESET="\x1b[0m"
info() {
    echo -e "${COLOR_G}[$tm] [Info] ${1}${RESET}"
}
while read line3; do

    rule=$(echo $line3 | awk '!/^$|#|dockerversion|kubernetesversion|LoadBalancerIp/{print $1}')     #取节点角色
    hostname=$(echo $line3 | awk '!/^$|#|dockerversion|kubernetesversion|LoadBalancerIp/{print $2}') #主机名
    ip=$(echo $line3 | awk '!/^$|#|dockerversion|kubernetesversion|LoadBalancerIp/{print $3}')       #ip
    username=$(echo $line3 | awk '!/^$|#|dockerversion|kubernetesversion|LoadBalancerIp/{print $4}') #用户名
    password=$(echo $line3 | awk '!/^$|#|dockerversion|kubernetesversion|LoadBalancerIp/{print $5}') #密码
    port=$(echo $line3 | awk '!/^$|#|dockerversion|kubernetesversion|LoadBalancerIp/{print $6}')     #ssh端口

    if [ "$rule" == "master" ]; then
        info "开始升级master节点"

        if [ "$hostname" == "master01" ]; then
            # 第一个master节点升级命令
            info "master01节点升级开始"
            usernamem=$username
            ipm=$ip
            portm=$port
            ssh -n ${username}@${ip} -p $port yum install -y kubeadm-$upgradeversion --disableexcludes=kubernetes
            ssh -n ${username}@${ip} -p $port sudo kubeadm upgrade apply v$upgradeversion -y

            ssh -n ${username}@${ip} -p $port kubectl drain $hostname --ignore-daemonsets

            ssh -n ${username}@${ip} -p $port yum install -y kubelet-$upgradeversion kubectl-$upgradeversion --disableexcludes=kubernetes

            ssh -n ${username}@${ip} -p $port sudo systemctl daemon-reload
            ssh -n ${username}@${ip} -p $port sudo systemctl restart kubelet

            # ssh -n ${username}@${ip} -p $port "kubectl uncordon $hostname>/dev/null"
            info "master01节点升级完成"

        elif [ ! "$hostname" == "master01" ]; then
            #其他master节点升级命令
            info "$ip节点升级开始"
            ssh -n ${username}@${ip} -p $port yum install -y kubeadm-$upgradeversion --disableexcludes=kubernetes
            ssh -n ${username}@${ip} -p $port sudo kubeadm upgrade node

            ssh -n ${username}@${ip} -p $port kubectl drain $hostname --ignore-daemonsets

            ssh -n ${username}@${ip} -p $port yum install -y kubelet-$upgradeversion kubectl-$upgradeversion --disableexcludes=kubernetes

            ssh -n ${username}@${ip} -p $port sudo systemctl daemon-reload
            ssh -n ${username}@${ip} -p $port sudo systemctl restart kubelet

            ssh -n ${username}@${ip} -p $port kubectl uncordon $hostname
            info "$ip节点升级完成"
        fi

    elif [ "$rule" == "node" ]; then
        info "$ip节点升级开始"
        ssh -n ${username}@${ip} -p $port yum install -y kubeadm-$upgradeversion --disableexcludes=kubernetes
        ssh -n ${username}@${ip} -p $port sudo kubeadm upgrade node
        # ssh -n ${username}@${ip} -p $port kubectl drain $hostname --ignore-daemonsets --force
        # echo $ipm
        ssh -n ${usernamem}@${ipm} -p $portm "kubectl drain $hostname --ignore-daemonsets --force"

        ssh -n ${username}@${ip} -p $port yum install -y kubelet-$upgradeversion kubectl-$upgradeversion --disableexcludes=kubernetes

        ssh -n ${username}@${ip} -p $port sudo systemctl daemon-reload
        ssh -n ${username}@${ip} -p $port sudo systemctl restart kubelet

        ssh -n ${usernamem}@${ipm} -p $portm "kubectl uncordon $hostname"
        info "$ip节点升级完成"
    fi

done <base.sh

info "kuberenetes升级成功"
