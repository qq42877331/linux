#!/bin/bash

#请根据实际情况修改
cat <<EOF >>/etc/hosts
172.16.20.100 ntp
172.16.20.101 controller
172.16.20.102 compute
EOF

./root/ssh_truest.sh

sed -i "s/#UseDNS yes/UseDNS no/g" /etc/ssh/sshd_config 
if [ $? == 0 ] ;then echo -e "关闭UseDNS 成功\n " ;fi

sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config &&  setenforce 0 &>/dev/null
if [ $? == 0 ] ;then echo -e "关闭 selinux 成功\n" ;fi 

systemctl stop firewalld  && systemctl disable firewalld
if [ $? == 0 ] ;then echo -e "关闭 firewalld 成功\n" ;fi 

systemctl stop NetworkManager  && systemctl disable NetworkManager
if [ $? == 0 ] ;then echo -e "关闭 NetworkManager 成功\n" ;fi 

rm -rf /etc/yum.repos.d/*
if [ $? == 0 ] ;then echo -e "清除全部的repo文件 成功\n" ;fi 

cat <<EOF >/etc/yum.repos.d/cdrom.repo
[cdrom]
name = cdrom 
baseurl=file:///mnt/
gpgcheck = 0
EOF
if [ $? == 0 ] ;then echo -e "创建cdrom.repo文件 成功\n" ;fi 

if [ ! -f /iso/rhel-server-7.1-x86_64-dvd.iso  $$ ! -f /iso/rhel-osp-7.0-2015-02-23.2-x86_64.iso ] 
	then
		echo -e "检查/iso/目录是否存在下列文件\nrhel-server-7.1-x86_64-dvd.iso \nrhel-osp-6.0-2015-02-23.2-x86_64.iso \n" 
		exit
fi



umount /mnt
mount /iso/rhel-server-7.1-x86_64-dvd.iso /mnt/
yum repolist && yum makecache 
yum install httpd chrony ntpdate -y

if [ $? == 0 ] ;then echo -e "安装httpd chrony utpdata 成功\n" ;fi 

umount /mnt
mkdir /var/www/html/dvd
mkdir /var/www/html/openstack

cat <<EOF >>/etc/fstab
/iso/rhel-server-7.1-x86_64-dvd.iso     /var/www/html/dvd       iso9660 defaults        0 0 
/iso/rhel-osp-6.0-2015-02-23.2-x86_64.iso     /var/www/html/openstack       iso9660 defaults        0 0 
EOF

mount -a 

if [ $? == 0 ] ;
then 
	echo -e "配置自动挂载点/iso/rhel-server-7.1-x86_64-dvd.iso--->/var/www/html/dvd  成功\n 配置自动挂载点/iso/rhel-osp-6.0-2015-02-23.2-x86_64.iso--->/var/www/html/openstack  成功\n" 
fi 


sed -i "s/#allow 192.168\/16/allow 172.16.20.0\/24/g" /etc/chrony.conf && sed -i "s/#local stratum 10/local stratum 10/g" /etc/chrony.conf

if [ $? == 0 ] ;then echo -e "修改chrony.conf参数 成功\n" ;fi 

systemctl enable chronyd && systemctl restart  chronyd
if [ $? == 0 ] ;then echo -e "chronyd启动 成功\n" ;fi 

systemctl enable httpd && systemctl restart httpd
if [ $? == 0 ] ;then echo -e "httpd启动 成功\n" ;fi 

mv /etc/yum.repos.d/cdrom.repo /etc/yum.repos.d/cdrom.repo.bak
if [ $? == 0 ] ;then echo -e "备份dvd.repo yum源文件 成功\n" ;fi 

cat <<EOF >/etc/yum.repos.d/web.repo
[dvd]
name = dvd
baseurl = http://172.16.20.100/dvd/
gpgcheck = 0
enabled = 1

[RH7-RHOS-6.0-Installer]
name = RH7-RHOS-6.0-Installer
baseurl = http://172.16.20.100/openstack/RH7-RHOS-6.0-Installer/
gpgcheck = 0
enabled = 1

[RH7-RHOS-6.0]
name = RH7-RHOS-6.0
baseurl = http://172.16.20.100/openstack/RH7-RHOS-6.0/
gpgcheck = 0
enabled = 1

[RHEL-7-RHSCL-1.2]
name = RHEL-7-RHSCL-1.2
baseurl = http://172.16.20.100/openstack/RHEL-7-RHSCL-1.2/
gpgcheck = 0
enabled = 1

[RHEL7-Errata]
name = RHEL7-Errata
baseurl = http://172.16.20.100/openstack/RHEL7-Errata/
gpgcheck = 0
enabled = 1
EOF

if [ $? == 0 ] ;then echo -e "创建web.repo yum源文件 成功\n" ;fi 


yum repolist && yum makecache 
if [ $? == 0 ] ;then echo -e "测试web.repo yum源 成功\n" ;fi 


#同步配置文件到计算节点、控制节点
ssh root@compute " rm -rf /etc/yum.repos.d/* " && echo -e "删除compute节点/etc/yum.repos.d/* 成功\n" 
ssh root@controller " rm -rf /etc/yum.repos.d/* " && echo -e "删除controller节点/etc/yum.repos.d/* 成功\n" 

scp /etc/yum.repos.d/web.repo root@compute:/etc/yum.repos.d/ && echo -e " 拷贝/etc/yum.repos.d/web.repo到compute节点 成功\n" 
scp /etc/yum.repos.d/web.repo root@controller:/etc/yum.repos.d/ && echo -e " 拷贝/etc/yum.repos.d/web.repo到controller节点 成功\n" 


scp /etc/hosts root@compute:/etc/  && echo -e " 拷贝/etc/hosts到compute节点 成功\n" 
scp /etc/hosts root@controller:/etc/ && echo -e " 拷贝/etc/hosts到controller节点 成功\n" 

scp ./ssh_truest.sh root@compute:/root/  && echo -e " 拷贝ssh_truest.sh到compute节点 成功\n" 
scp ./ssh_truest.sh root@controller:/root/ && echo -e " 拷贝ssh_truest.sh到controller节点 成功\n" 



ssh root@compute " yum repolist && yum makecache " && echo -e "web.repo在compute节点上可用\n"
ssh root@controller " yum repolist && yum makecache " && echo -e "web.repo在controller节点上可用\n"

ssh root@compute " yum install -y lrzsz \
vim \
bash-completion \
net-tools \
openssl \
openssl-devel \
chrony.x86_64 \
zip \
unzip \
ntpdate \
telnet \
expect"

ssh root@controller " yum install -y lrzsz \
vim \
bash-completion \
net-tools \
openssl \
openssl-devel \
chrony.x86_64 \
zip \
unzip \
ntpdate \
telnet \
expect"


ssh root@compute " sed -i \"/^server [1-3]/ s/^/#/\" /etc/chrony.conf "
ssh root@compute " sed -i \"s/server 0.rhel.pool.ntp.org iburst/server ntp iburst/\" /etc/chrony.conf "
ssh root@compute "systemctl enable chronyd && systemctl restart  chronyd"
ssh root@compute "ntpdate ntp && echo -e \"cmpute节点ntp服务正常\n\"" 
ssh root@compute "bash /root/ssh_truest.sh && echo -e \"ssh互信成功\n\"" 

ssh root@controller " sed -i \"/^server [1-3]/ s/^/#/\" /etc/chrony.conf "
ssh root@controller " sed -i \"s/server 0.rhel.pool.ntp.org iburst/server ntp iburst/\" /etc/chrony.conf "
ssh root@controller "systemctl enable chronyd && systemctl restart  chronyd"
ssh root@controller "ntpdate ntp && echo -e \"controller节点ntp服务正常\n\""
ssh root@controller "bash /root/ssh_truest.sh && echo -e \"ssh互信成功\n\"" 


#在controller节点上操作，用packstack部署openstack
ssh root@controller "yum install -y openstack-packstack.noarch "
ssh root@controller "rm -rf /root/pack* "
ssh root@controller "packstack --gen-answer-file=/root/packstack.txt"

#修改应答文件
ssh root@controller "sed -i \"s/CONFIG_NTP_SERVERS=.*/CONFIG_NTP_SERVERS=ntp/g\" /root/packstack.txt"
ssh root@controller "sed -i \"s/CONFIG_COMPUTE_HOSTS=.*/CONFIG_COMPUTE_HOSTS=172.16.20.101,172.16.20.102/g\" /root/packstack.txt"
ssh root@controller "sed -i \"s/CONFIG_PROVISION_DEMO=y/CONFIG_PROVISION_DEMO=n/g\" /root/packstack.txt"
ssh root@controller "sed -i \"s/CONFIG_HORIZON_SSL=n/CONFIG_HORIZON_SSL=y/g\" /root/packstack.txt"
ssh root@controller "sed -i \"s/CONFIG_HEAT_INSTALL=n/CONFIG_HEAT_INSTALL=y/g\" /root/packstack.txt"
ssh root@controller "sed -i \"s/CONFIG_KEYSTONE_ADMIN_PW=.*/CONFIG_KEYSTONE_ADMIN_PW=adminh3c./g\" /root/packstack.txt"

#根据应答文件，开始部署openstak
ssh  root@controller "packstack --answer-file=/root/packstack.txt"
