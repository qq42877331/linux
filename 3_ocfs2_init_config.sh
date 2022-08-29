#!/bin/bash

#设置开机启动ocfs2模块
cat <<EOF >/etc/modules-load.d/ocfs2.conf
ocfs2
ocfs2_dlmfs
EOF

#不等下次开机，现时手动打开一下
modprobe ocfs2 
modprobe ocfs2_dlmfs
if [ ! -f /etc/yum.repos.d/public-yum-ol7.repo ] 
then 
	#添加ol7 yum源，内含有ocfs2-tools工具
	wget http://public-yum.oracle.com/public-yum-ol7.repo -O /etc/yum.repos.d/public-yum-ol7.repo
	sed -i "s/gpgcheck=1/gpgcheck=0/g" /etc/yum.repos.d/public-yum-ol7.repo
fi

yum install ocfs2-tools net-tools iscsi-initiator-utils -y

umount /data &>/dev/null
mkdir /data &>/dev/null
mkdir /etc/ocfs2 &>/dev/null

num=1
q="no"
read -p "请输入ocfs2集群名称(已有按q)：" cname
if [ $cname != "q" ] && [ $cname != "Q" ] 
then 
	o2cb add-cluster $cname
	read -p "请输入iscsi服务器ip地址：  " ip 
	
	while [ $q != "yes" ]
	do 
		read -p "请输入 node${num} 的IP地址(结束按q)：  " ip
		if [ $ip != "q" ] && [ ip != "Q" ]
		then
			o2cb add-node --ip $ip --port 7777 --number $num $cname node${num}
		else
			q="yes"
		fi
		num=$(($num+1))
	done 
	o2cb register-cluster $cname
fi

systemctl enable o2cb.service && systemctl restart o2cb.service
systemctl enable ocfs2.service && systemctl restart ocfs2.service


iscsiadm -m session -o show
if [ $? != 0 ]
then 
	echo -e "请确认iscsi已经连接!\n"
else 
	lsblk 
	read -p "请问哪块是iscsi硬盘？如格式 sdX  ： " hd
	echo -e "\n"
	yn=""
	read -p "需要对$hd 进行格式操作吗？ [yes执行 q取消] ： " yn
	echo -e "\n"
	if [ $yn != "q" ] && [ $yn != "Q" ]
	then 
		mkfs.ocfs2 -b 4k -C 1M -L netdisk  -N 2 -T  vmstore -J block64 -F -x /dev/$hd
	fi

	mount.ocfs2 /dev/$hd /data  && echo -e "磁盘$hd挂载到/data成功！\n"
	echo -e "\n"
fi
