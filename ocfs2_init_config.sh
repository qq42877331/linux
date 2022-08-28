#!/bin/bash

#设置开机启动ocfs2模块
cat <<EOF >/etc/modules-load.d/ocfs2.conf
ocfs2
ocfs2_dlmfs
EOF

#不等下次开机，现时手动打开一下
modprobe ocfs2 
modprobe ocfs2_dlmfs

#添加ol7 yum源，内含有ocfs2-tools工具
wget http://public-yum.oracle.com/public-yum-ol7.repo -O /etc/yum.repos.d/public-yum-ol7.repo
sed -i "s/gpgcheck=1/gpgcheck=0/g" /etc/yum.repos.d/public-yum-ol7.repo

yum install yum-plugin-downloadonly -y
mkdir ./ocfs2_pack && cd ./ocfs2_pack/
yum install --downloaddir=./ocfs2_pack/ ocfs2-tools net-tools iscsi-initiator-utils -y

num=1
q="no"

read -p "请输入ocfs2集群名称(按q退出)：" clustername
o2cb add-cluster $clustername

read -p "请输入存储服务器的NAME(按q退出)：  " hostname
read -p "请输入存储服务器的IP地址(按q退出)：  " ip
echo "${ip} ${hostname}" >>/etc/hosts

while [ $q != "yes" ]
do 
	read -p "请输入 node${num} 的IP地址(按q退出)：  " ip
	if [ $ip != "q" ] && [ ip != "Q" ]
	then
		echo "$ip node${num}" >>/etc/hosts
		o2cb add-node --ip $ip --port 7777 --number $num $clustername node${num}
	else
		q="yes"
	fi
	num=$(($num+1))
done 

mkdir /etc/ocfs2 &>/dev/null

systemctl enable o2cb.service && systemctl restart o2cb.service
systemctl enable ocfs2.service && systemctl enable ocfs2.service


iscsiadm -m session -o show
if [ $? != 0 ]
then 
	echo -e "请确认iscsi已经连接!\n"
else 
	lsblk 
	read -p "需要把哪块硬盘格式化为ocfs2文件系统？格式sdb sdc (不需要按q): " hd

	if [ $hd != "q" ] && [ $hd != "Q" ]
	then 
		mkfs.ocfs2 -b 4k -C 1M -L ser1_iscsi  -N 2 -T  vmstore -J block64 -F -x /dev/$hd
	fi
	
	mkdir /data &>/dev/null

	umount /data &>/dev/null

	mount.ocfs2 /dev/sdb /data
fi
