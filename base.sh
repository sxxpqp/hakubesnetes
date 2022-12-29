#!/bin/bash
# 设置节点属性  主机名  ip 用户名 密码 ssh端口
#如 master master01 192.168.1.2 root 1 22
#node node01 192.168.1.2 root 1 22
master master01 192.168.1.161 root 1 22
master master02 192.168.1.162 root 1 22
master master03 192.168.1.163 root 1 22
node node01 192.168.1.164 root 1 22
# node node01 192.168.1.34 root Turing2022 22
# node node02 192.168.1.2 root 1 22
# node node03 192.168.1.2 root 1 22
#设置docker版本
dockerversion 20.10.21
#设置kubesnetes版本
kubernetesversion 1.21.14
#设置负载均衡ip 通过nginx haproxy
LoadBalancerIp 192.168.1.164
