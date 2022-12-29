#!/bin/bash

set -e
# 日志颜色
tm=$(date +'%Y%m%d %T')
COLOR_G="\x1b[0;32m" # green
RESET="\x1b[0m"
info() {
  echo -e "${COLOR_G}[$tm] [Info] ${1}${RESET}"
}
info "$hostname 开始安装k8s。。。"
#安装sshpass
yum -y install yum-utils net-utils sshpass
if [ $? == 0 ]; then
  info "sshpass安装成功。"
fi
[ -f /root/.ssh/id_rsa ] || ssh-keygen -t rsa -q -P "" -f /root/.ssh/id_rsa
dockerversion=$(awk '/dockerversion/{print $2}' base.sh)
info "安装docker版本为$dockerversion"

kubernetesversion=$(awk '/kubernetesversion/{print $2}' base.sh)
info "安装docker版本为$kubernetesversion"

MASTER_IP=$(awk '/LoadBalancerIp/{print $2}' base.sh)
# #     # 替换 apiserver.demo 为 您想要的 dnsName
# #ssh -n ${username}@${ip} -p $port export APISERVER_NAME=apiserver.demo
APISERVER_NAME=apiserver.demo
# #     # Kubernetes 容器组所在的网段，该网段安装完成后，由 kubernetes 创建，事先并不存在于您的物理网络中
# #ssh -n ${username}@${ip} -p $port export POD_SUBNET=10.100.0.1/16
POD_SUBNET=10.100.0.1/16
while read line; do
  rule=$(echo $line | awk '!/^$|#|dockerversion|kubernetesversion|LoadBalancerIp/{print $1}')     #取节点角色
  hostname=$(echo $line | awk '!/^$|#|dockerversion|kubernetesversion|LoadBalancerIp/{print $2}') #主机名
  ip=$(echo $line | awk '!/^$|#|dockerversion|kubernetesversion|LoadBalancerIp/{print $3}')       #ip
  username=$(echo $line | awk '!/^$|#|dockerversion|kubernetesversion|LoadBalancerIp/{print $4}') #用户名
  password=$(echo $line | awk '!/^$|#|dockerversion|kubernetesversion|LoadBalancerIp/{print $5}') #密码
  port=$(echo $line | awk '!/^$|#|dockerversion|kubernetesversion|LoadBalancerIp/{print $6}')     #ssh端口

  {

    if [ ! "$rule" == '' ]; then #判断rule字符串是否为空
      # echo $rule
      #echo $ip开始安装k8s。。。
      # echo $username
      # echo $password
      # echo $port

      sshpass -p $password ssh-copy-id -f -p $port -i ~/.ssh/id_rsa.pub ${username}@${ip} "-o StrictHostKeyChecking=no"
      ssh-copy-id -p $port ${username}@${ip} -f
      if [ $? == 0 ]; then
        info "copy到$ip ssh-copy-id的成功"
      fi
      # 修改 hostname
      ssh -n ${username}@${ip} -p $port hostnamectl set-hostname $hostname #既然ssh默认读取标准输入，那我们就将其输入重定向即可
      # 查看修改结果
      ssh -n ${username}@${ip} -p $port hostnamectl status
      if [ $? == 0 ]; then
        info "$ip主机hostname修改为$hostname"
      fi
      # 设置 hostname 解析
      # ssh -n ${username}@${ip} -p $port echo "127.0.0.1   $(hostname)" >>/etc/hosts
      # if [ $? == 0 ]; then
      #   info "$ip主机设置 hostname 解析"
      # fi

      # 阿里云 docker hub 镜像
      ssh -n ${username}@${ip} -p $port export REGISTRY_MIRROR=https://registry.cn-hangzhou.aliyuncs.com
      # 在 master 节点和 worker 节点都要执行
      if [ $? == 0 ]; then
        info "$ip主机配置阿里云 docker hub 镜像"
      fi
      # 安装 docker
      # 参考文档如下
      # https://docs.docker.com/install/linux/docker-ce/centos/
      # https://docs.docker.com/install/linux/linux-postinstall/

      # # 卸载旧版本
      # ssh -n ${username}@${ip} -p $port yum remove -y docker \
      #   docker-client \
      #   docker-client-latest \
      #   docker-ce-cli \
      #   docker-common \
      #   docker-latest \
      #   docker-latest-logrotate \
      #   docker-logrotate \
      #   docker-selinux \
      #   docker-engine-selinux \
      #   docker-engine
      # if [ $? == 0 ]; then
      #   info "$ip主机卸载旧版本 docker"
      # fi
      # # 设置 yum repository
      ssh -n ${username}@${ip} -p $port yum install -y yum-utils \
        device-mapper-persistent-data \
        lvm2
      #ssh -n ${username}@${ip} -p $port [ -d /etc/yum.repos.d/back ] || mkdir -p /etc/yum.repos.d/back
      #ssh -n ${username}@${ip} -p $port mv /etc/yum.repos.d/* /etc/yum.repos.d/back
      ssh -n ${username}@${ip} -p $port yum clean all
      ssh -n ${username}@${ip} -p $port yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
      if [ $? == 0 ]; then
        info "$ip主机设置 yum repository"
      fi
      # # 安装并启动 docker

      ssh -n ${username}@${ip} -p $port yum install -y docker-ce-$dockerversion docker-ce-cli-$dockerversion containerd.io-1.2.13
      if [ $? == 0 ]; then
        info "$ip主机安装docker完成"
      fi
      ssh -n ${username}@${ip} -p $port "test -d /etc/docker  || mkdir /etc/docker"
      # "daemon添加镜像加速器..."

      scp -P $port daemon.json ${username}@${ip}:/etc/docker/daemon.json
      if [ $? == 0 ]; then
        info "$ip主机daemon添加镜像加速器"
      fi
      ssh -n ${username}@${ip} -p $port mkdir -p /etc/systemd/system/docker.service.d

      # Restart Docker
      ssh -n ${username}@${ip} -p $port systemctl daemon-reload
      ssh -n ${username}@${ip} -p $port systemctl enable docker
      ssh -n ${username}@${ip} -p $port systemctl restart docker
      if [ $? == 0 ]; then
        info "$ip主机启动docker"
      fi
      # 安装 nfs-utils
      # 必须先安装 nfs-utils 才能挂载 nfs 网络存储
      ssh -n ${username}@${ip} -p $port yum install -y nfs-utils
      ssh -n ${username}@${ip} -p $port yum install -y wget
      if [ $? == 0 ]; then
        info "$ip主机安装wget"
      fi
      # 关闭 防火墙
      ssh -n ${username}@${ip} -p $port systemctl stop firewalld
      ssh -n ${username}@${ip} -p $port systemctl disable firewalld
      if [ $? == 0 ]; then
        info "$ip主机关闭firewalld"
      fi

      # 关闭 SeLinux
      # ssh -n ${username}@${ip} -p $port `setenforce 0 &>/dev/null`
      # echo "$ip 主机关闭开始。。。"
      ssh -n ${username}@${ip} -p $port sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
      if [ $? == 0 ]; then
        info "$ip主机关闭 SeLinux"
      fi
      # 关闭 swap
      ssh -n ${username}@${ip} -p $port swapoff -a
      ssh -n ${username}@${ip} -p $port "sed -ri 's/.*swap.*/#&/' /etc/fstab"
      if [ $? == 0 ]; then
        info "$ip主机关闭 swap"
      fi
      # 修改 /etc/sysctl.conf
      # 如果有配置，则修改
      info "$ip 开始修改/etc/sysctl.conf"
      # ssh -n ${username}@${ip} -p $port sed -i "s#^net.ipv4.ip_forward.*#net.ipv4.ip_forward=1#g" /etc/sysctl.conf
      # ssh -n ${username}@${ip} -p $port sed -i "s#^net.bridge.bridge-nf-call-ip6tables.*#net.bridge.bridge-nf-call-ip6tables=1#g" /etc/sysctl.conf
      # ssh -n ${username}@${ip} -p $port sed -i "s#^net.bridge.bridge-nf-call-iptables.*#net.bridge.bridge-nf-call-iptables=1#g" /etc/sysctl.conf
      # ssh -n ${username}@${ip} -p $port sed -i "s#^net.ipv6.conf.all.disable_ipv6.*#net.ipv6.conf.all.disable_ipv6=1#g" /etc/sysctl.conf
      # ssh -n ${username}@${ip} -p $port sed -i "s#^net.ipv6.conf.default.disable_ipv6.*#net.ipv6.conf.default.disable_ipv6=1#g" /etc/sysctl.conf
      # ssh -n ${username}@${ip} -p $port sed -i "s#^net.ipv6.conf.lo.disable_ipv6.*#net.ipv6.conf.lo.disable_ipv6=1#g" /etc/sysctl.conf
      # ssh -n ${username}@${ip} -p $port sed -i "s#^net.ipv6.conf.all.forwarding.*#net.ipv6.conf.all.forwarding=1#g" /etc/sysctl.conf
      # 可能没有，追加
      ssh -n ${username}@${ip} -p $port "echo "net.ipv4.ip_forward = 1" >>/etc/sysctl.conf"
      ssh -n ${username}@${ip} -p $port "echo "net.bridge.bridge-nf-call-ip6tables = 1" >>/etc/sysctl.conf"
      ssh -n ${username}@${ip} -p $port "echo "net.bridge.bridge-nf-call-iptables = 1" >>/etc/sysctl.conf"
      ssh -n ${username}@${ip} -p $port "echo "net.ipv6.conf.all.disable_ipv6 = 1" >>/etc/sysctl.conf"
      ssh -n ${username}@${ip} -p $port "echo "net.ipv6.conf.default.disable_ipv6 = 1" >>/etc/sysctl.conf"
      ssh -n ${username}@${ip} -p $port "echo "net.ipv6.conf.lo.disable_ipv6 = 1" >>/etc/sysctl.conf"
      ssh -n ${username}@${ip} -p $port "echo "net.ipv6.conf.all.forwarding = 1" >>/etc/sysctl.conf"
      # 执行命令以应用
      ssh -n ${username}@${ip} -p $port sysctl -p
      if [ $? == 0 ]; then
        info "$ip主机修改 /etc/sysctl.conf"
      fi
      # 配置K8S的yum源
      scp -P $port kubernetes.repo ${username}@${ip}:/etc/yum.repos.d/kubernetes.repo
      if [ $? == 0 ]; then
        info "$ip主机添加了K8S的yum源"
      fi
      # 卸载旧版本
      #先初始化kubeadm
      # if [ "$rule" == "master" ]; then

      ssh -n ${username}@${ip} -p $port yum remove -y kubelet kubeadm kubectl
      # fi
      if [ $? == 0 ]; then
        info "$ip卸载旧版本kubelet kubeadm kubectl"
      fi
      # 安装kubelet、kubeadm、kubectl
      # 将 ${1} 替换为 kubernetes 版本号，例如 1.19.0
      ssh -n ${username}@${ip} -p $port "yum install -y kubelet-${kubernetesversion} kubeadm-${kubernetesversion} kubectl-${kubernetesversion}"
      if [ $? == 0 ]; then
        info "$ip安装kubelet kubeadm kubectl成功"
      fi
      # 重启 docker，并启动 kubelet
      ssh -n ${username}@${ip} -p $port systemctl daemon-reload
      ssh -n ${username}@${ip} -p $port systemctl restart docker
      ssh -n ${username}@${ip} -p $port systemctl enable kubelet
      # ssh -n ${username}@${ip} -p $port systemctl start kubelet

      ssh -n ${username}@${ip} -p $port docker version

      #     # 只在 master 节点执行
      #     # 替换 x.x.x.x 为 master 节点的内网IP
      #     # export 命令只在当前 shell 会话中有效，开启新的 shell 窗口后，如果要继续安装过程，请重新执行此处的 export 命令
      # ssh -n ${username}@${ip} -p $port export MASTER_IP=$(ip)
      # #MASTER_IP=$(echo $line | awk '/LoadBalancerIp/{print $2}')
      # #     # 替换 apiserver.demo 为 您想要的 dnsName
      # #ssh -n ${username}@${ip} -p $port export APISERVER_NAME=apiserver.demo
      # APISERVER_NAME=apiserver.demo
      # #     # Kubernetes 容器组所在的网段，该网段安装完成后，由 kubernetes 创建，事先并不存在于您的物理网络中
      # #ssh -n ${username}@${ip} -p $port export POD_SUBNET=10.100.0.1/16
      # POD_SUBNET=10.100.0.1/16
      ssh -n ${username}@${ip} -p $port echo "${ip}    ${hostname}" >>/etc/hosts
      #ssh -n ${username}@${ip} -p $port echo "${MASTER_IP}    ${APISERVER_NAME}" >>/etc/hosts

      #     # 只在 master 节点执行

      #     # 脚本出错时终止执行
      #     ssh -n ${username}@${ip} -p $port set -e

      #     # ssh -n ${username}@${ip} -p $port    if [ ${#POD_SUBNET} -eq 0 ] || [ ${#APISERVER_NAME} -eq 0 ]; then
      #     #       echo -e "\033[31;1m请确保您已经设置了环境变量 POD_SUBNET 和 APISERVER_NAME \033[0m"
      #     #       echo 当前POD_SUBNET=$POD_SUBNET
      #     #       echo 当前APISERVER_NAME=$APISERVER_NAME
      #     #       exit 1
      #     #     fi
      ssh -n ${username}@${ip} yum install -y ipvsadm ipset
      ssh -n ${username}@${ip} -p $port modprobe -- ip_vs
      ssh -n ${username}@${ip} -p $port modprobe -- ip_vs_rr
      ssh -n ${username}@${ip} -p $port modprobe -- ip_vs_wrr
      ssh -n ${username}@${ip} -p $port modprobe -- ip_vs_sh
      ssh -n ${username}@${ip} -p $port modprobe -- nf_conntrack_ipv4
      ssh -n ${username}@${ip} -p $port lsmod | grep -e ip_vs -e nf_conntrack_ipv4
      if [ $? == 0 ]; then
        info "$ip配置ip_vs -e nf_conntrack_ipv4模块成功"
      fi
      #     # kubeadm init
      #     # 根据您服务器网速的情况，您需要等候 3 - 10 分钟
      if [ "$rule" == "master" ]; then
        ssh -n ${username}@${ip} -p $port kubeadm reset -f
        ssh -n ${username}@${ip} -p $port rm -rf /etc/kubernetes/
        ssh -n ${username}@${ip} -p $port rm -rf /var/lib/etcd
        ssh -n ${username}@${ip} -p $port rm -rf /var/lib/cni/
        ssh -n ${username}@${ip} -p $port rm -rf /etc/cni/net.d
        ssh -n ${username}@${ip} -p $port rm -rf /root/.kube/
        ssh -n ${username}@${ip} -p $port ipvsadm --clear
        if [ "$hostname" == "master01" ]; then
          #     # 查看完整配置选项 https://godoc.org/k8s.io/kubernetes/cmd/kubeadm/app/apis/kubeadm/v1beta2
          # ssh -n ${username}@${ip} -p $port rm -f /${username}/kubeadm-config.yaml
          # sed -i "s/\$version/$kubernetesversion/g" kubeadm-config.yaml
          # sed -i "s/\$APISERVER_NAME/$APISERVER_NAME/g" kubeadm-config.yaml
          # sed -i "s#\$POD_SUBNET#$POD_SUBNET#g" kubeadm-config.yaml

          # scp -P $port kubeadm-config.yaml ${username}@${ip}:/${username}/kubeadm-config.yaml
          # MASTER_IP=$(echo $line | awk '/LoadBalancerIp/{print $2}')
          # #     # 替换 apiserver.demo 为 您想要的 dnsName
          # #ssh -n ${username}@${ip} -p $port export APISERVER_NAME=apiserver.demo
          # APISERVER_NAME=apiserver.demo
          # #     # Kubernetes 容器组所在的网段，该网段安装完成后，由 kubernetes 创建，事先并不存在于您的物理网络中
          # #ssh -n ${username}@${ip} -p $port export POD_SUBNET=10.100.0.1/16
          # POD_SUBNET=10.100.0.1/16
          #ssh -n ${username}@${ip} -p $port echo "${ip}    ${hostname}" >>/etc/hosts
          ssh -n ${username}@${ip} -p $port echo "${MASTER_IP}    ${APISERVER_NAME}" >>/etc/hosts
          ssh -n ${username}@${ip} -p $port kubeadm config images pull --image-repository=registry.aliyuncs.com/google_containers
          ssh -n ${username}@${ip} -p $port "kubeadm init --image-repository=registry.aliyuncs.com/google_containers --kubernetes-version=v$kubernetesversion --pod-network-cidr=$POD_SUBNET --control-plane-endpoint=$APISERVER_NAME --upload-certs"

          # #     # 配置 kubectl
          ssh -n ${username}@${ip} -p $port mkdir /root/.kube/
          ssh -n ${username}@${ip} -p $port cp -i /etc/kubernetes/admin.conf /root/.kube/config
          ssh -n ${username}@${ip} -p $port chown $(id -u):$(id -g) $HOME/.kube/config

          #获取certificate-key的值
          #kubeadm init phase upload-certs --upload-certs|awk 'END{print $NF}'

        fi
      fi

    fi
  } &

done <base.sh
wait
while read line2; do
  # #初始化第二、三个 master 节点

  # #在 demo-master-b-1 和 demo-master-b-2 机器上执行
  # #只在 第一个 master 节点 demo-master-a-1 上执行
  # #kubeadm token create --print-join-command

  # # 只在第二、三个 master 节点 demo-master-b-1 和 demo-master-b-2 执行
  # # 替换 x.x.x.x 为 ApiServer LoadBalancer 的 IP 地址
  # export APISERVER_IP=x.x.x.x
  # # 替换 apiserver.demo 为 前面已经使用的 dnsName
  # export APISERVER_NAME=apiserver.demo
  # echo "${APISERVER_IP}    ${APISERVER_NAME}" >>/etc/hosts
  # # 使用前面步骤中获得的第二、三个 master 节点的 join 命令
  # kubeadm join apiserver.demo:6443 --token ejwx62.vqwog6il5p83uk7y \
  #   --discovery-token-ca-cert-hash sha256:6f7a8e40a810323672de5eee6f4d19aa2dbdb38411845a1bf5dd63485c43d303 \
  #   --control-plane --certificate-key 70eb87e62f052d2d5de759969d5b42f372d0ad798f98df38f7fe73efdf63a13c
  #获取加入命令
  #  kubeadm init phase upload-certs --upload-certs
  #  kubeadm token create --print-join-command
  rule=$(echo $line2 | awk '!/^$|#|dockerversion|kubernetesversion|LoadBalancerIp/{print $1}')     #取节点角色
  hostname=$(echo $line2 | awk '!/^$|#|dockerversion|kubernetesversion|LoadBalancerIp/{print $2}') #主机名
  ip=$(echo $line2 | awk '!/^$|#|dockerversion|kubernetesversion|LoadBalancerIp/{print $3}')       #ip
  username=$(echo $line2 | awk '!/^$|#|dockerversion|kubernetesversion|LoadBalancerIp/{print $4}') #用户名
  password=$(echo $line2 | awk '!/^$|#|dockerversion|kubernetesversion|LoadBalancerIp/{print $5}') #密码
  port=$(echo $line2 | awk '!/^$|#|dockerversion|kubernetesversion|LoadBalancerIp/{print $6}')     #ssh端口

  if [ "$rule" == "master" ]; then
    info "开始安装其他master节点"

    if [ "$hostname" == "master01" ]; then
      # sshpass -p $password ssh-copy-id -f -p $port -i ~/.ssh/id_rsa.pub ${username}@${ip} -o StrictHostKeyChecking=no

      certificatekey=$(ssh -n ${username}@${ip} -p $port kubeadm init phase upload-certs --upload-certs | awk 'END{print $NF}')
      info "${certificatekey}"

      export token=$(ssh -n ${username}@${ip} -p $port kubeadm token create --print-join-command)
      info "${token}"
      #     # 安装 calico 网络插件
      #     # 参考文档 https://docs.projectcalico.org/v3.13/getting-started/kubernetes/self-managed-onprem/onpremises
      ssh -n ${username}@${ip} -p $port echo "安装calico-3.13.1"
      ssh -n ${username}@${ip} -p $port rm -f calico-3.13.1.yaml
      ssh -n ${username}@${ip} -p $port wget https://kuboard.cn/install-script/calico/calico-3.13.1.yaml
      sleep 10
      ssh -n ${username}@${ip} -p $port kubectl apply -f calico-3.13.1.yaml

    elif [ ! "$hostname" == "master01" ]; then

      # sshpass -p $password ssh-copy-id -f -p $port -i ~/.ssh/id_rsa.pub ${username}@${ip} -o StrictHostKeyChecking=no

      scp -P $port /etc/hosts ${username}@${ip}:/etc/hosts
      #ssh -n ${username}@${ip} -p $port export MASTER_IP=$(ip)
      # MASTER_IP=$(echo $line | awk '/LoadBalancerIp/{print $2}')
      #     # 替换 apiserver.demo 为 您想要的 dnsName
      # ssh -n ${username}@${ip} -p $port kubeadm reset -f
      # ssh -n ${username}@${ip} -p $port rm -rf /etc/cni/net.d
      # ssh -n ${username}@${ip} -p $port rm -rf $HOME/.kube/config
      # ssh -n ${username}@${ip} -p $port systemctl stop kubelet
      #APISERVER_NAME=apiserver.demo
      #     # Kubernetes 容器组所在的网段，该网段安装完成后，由 kubernetes 创建，事先并不存在于您的物理网络中
      #ssh -n ${username}@${ip} -p $port echo "${MASTER_IP}    ${APISERVER_NAME}" >>/etc/hosts
      info "$ip执行kubeadm 加入master"
      ssh -n ${username}@${ip} -p $port "${token}  --control-plane --certificate-key ${certificatekey}"
      ssh -n ${username}@${ip} -p $port mkdir /root/.kube/
      ssh -n ${username}@${ip} -p $port cp -i /etc/kubernetes/admin.conf /root/.kube/config
      ssh -n ${username}@${ip} -p $port chown $(id -u):$(id -g) $HOME/.kube/config
      info "$ip加入master成功"
    fi
  elif [ "$rule" == "node" ]; then
    # sshpass -p $password ssh-copy-id -f -p $port -i ~/.ssh/id_rsa.pub ${username}@${ip} -o StrictHostKeyChecking=no
    scp -P $port /etc/hosts ${username}@${ip}:/etc/hosts
    #ssh -n ${username}@${ip} -p $port export MASTER_IP=$(ip)
    # MASTER_IP=$(echo $line | awk '/LoadBalancerIp/{print $2}')
    #     # 替换 apiserver.demo 为 您想要的 dnsName
    # ssh -n ${username}@${ip} -p $port kubeadm reset -f
    # ssh -n ${username}@${ip} -p $port rm -rf /var/lib/etcd

    # ssh -n ${username}@${ip} -p $port rm -rf /etc/kubernetes/
    # ssh -n ${username}@${ip} -p $port systemctl stop kubelet
    info "$ip执行kubeadm 加入node"
    # ssh -n ${username}@${ip} -p $port "rm -rf /var/lib/kubelet/"
    ssh -n ${username}@${ip} -p $port "kubeadm reset -f"
    ssh -n ${username}@${ip} -p $port "docker system prune -a -f"
    ssh -n ${username}@${ip} -p $port "systemctl stop kubelet"
    ssh -n ${username}@${ip} -p $port "rm -rf /etc/kubernetes/"
    ssh -n ${username}@${ip} -p $port "${token}"

  fi

done <base.sh

info "Kubernetes集群安装成功"

kubeadm reset -f
systemctl stop kubelet
rm -rf /etc/kubernetes/
rm -rf /etc/cni/net.d
rm -rf $HOME/.kube/config
