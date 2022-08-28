#!/bin/bash

#系统优化
sed -i s/SELINUX=enforcing/SELINUX=disabled/g /etc/selinux/config &&  setenforce 0
systemctl stop firewalld  && systemctl disable firewalld
systemctl stop NetworkManager  && systemctl disable NetworkManager

if [ ! -f /etc/yum.repos.d/Centos-7.repo ] 
then 
	rm -rf /etc/yum.repos.d/*
	curl http://mirrors.aliyun.com/repo/Centos-7.repo -o /etc/yum.repos.d/Centos-7.repo
	yum clean all && yum makecache 
fi 

yum -y install rpm-build
yum -y install gcc m4 net-tools bc xmlto asciidoc hmaccalc python-devel newt-devel perl pesign elfutils-devel zlib-devel binutils-devel bison audit-libs-devel java-devel numactl-devel pciutils-devel ncurses-devel perl-ExtUtils-Embed python-docutils iscsi-initiator-utils



#获取当前系统版本
sysver=`cat /etc/redhat-release  |awk -F " " '{print $4}'`
down_url="https://mirrors.aliyun.com/centos-vault/${sysver}/updates/Source/SPackages/"

echo -e "\033[31m\n当前系统版本：$sysver\n\033[0m"

echo -e "\033[31m当前内核版本：`uname -r ` \n\033[0m"

#提示信息
echo -e "\n$down_url \n"
echo -e "浏览器打开，下载较新kernel源包，并确保该源包与此脚本在同一目录下！\n"

#判断是否能继续
dir1=`pwd`
pack_name=`ls -l ${dir1} |grep kernel*.rpm |awk -F " " '{print $9}'`

if [ $pack_name == "" ] ; then echo -e "请准备好再尝试.\n" && exit ;fi

#判断是否存在已经编译的版本
if [ ! -f $dir1/rpmbuild/RPMS/x86_64/kernel-[0-9] ]
then 
	#rm -rf ./rpmbuild 
	rpm -ivh ${pack_name}

	#修改kernel.spec ，让新内核支持ocfs2模块
	line=$(cat -n $dir1/rpmbuild/SPECS/kernel.spec |grep "  mv \$i .config"|awk -F " " '{print $1}')
	sed -i "${line}i\  sed -i 's\/# CONFIG_OCFS2_FS is not set\/CONFIG_OCFS2_FS=m\/' \$i" $dir1/rpmbuild/SPECS/kernel.spec
	sed -i 's/\%define listnewconfig_fail 1/\%define listnewconfig_fail 0/' $dir1/rpmbuild/SPECS/kernel.spec

	#重装编译一次内核包，需要很长时间
	echo -e "编译内核包需要较长时间，请耐心等待。一会见!!!\n"
	rpmbuild -ba $dir1/rpmbuild/SPECS/kernel.spec
else
	"检测到有已经编译的版本，不再重新编译。重新编译 rm -rf ./rpmbuild后重试.\n"
fi 

yn=""
read "现在安装重编译后的kernel包吗？[yes or no ]:   " yn
if [ $yn == "yes" ] || [ $yn == "y" ]
then 
	#安装新生成的内核rpm包
	new_pack=$(ls -l $dir1/rpmbuild/RPMS/x86_64/ |awk -F " " '{print $9}'|grep kernel-[0-9])
	rpm -qpl $dir1/rpmbuild/RPMS/x86_64/${new_pack} |grep ocfs2
	rpm -ivh $dir1/rpmbuild/RPMS/x86_64/${new_pack} && echo -e "内核包安装完成.\n"
	#设置开机启动新版内核
	sudo awk -F\' '$1=="menuentry " {print i++ " : " $2}' /etc/grub2.cfg
	grub2-set-default 0 
	grub2-mkconfig -o /boot/grub2/grub.cfg
	
	yn=""
	read -p "kernel更新已经完成，你想现在重启此系统吗？ [ yes or no ]  :" yn

	if [ $yn == "y" -o $yn == "yes" ]
	then 
		init 6
	else
		echo -e "ok ! 请稍后手动重启！\n"
	fi
	
fi




