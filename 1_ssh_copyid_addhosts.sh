#!/bin/bash

nodepw=`cat ./nodepw `

#定义一个put_sshkey方法
yum install -y expect
put_sshkey(){
/usr/bin/expect -c "
        set timeout 10
        spawn ssh-copy-id -o StrictHostKeyChecking=no -i /root/.ssh/id_rsa.pub root@$1
        expect {
            password: { send $2\r;interact; }
        
        }"
}
cat /etc/hosts
read -p "hosts文件完成编辑了吗？[yes or no] :  " yn
if [ $yn == "no" ] || [ $yn == "n" ]
then 
	read -p "input iscsi server ip :" ip
	echo "$ip iscsi">>/etc/hosts
	i=1
	q="no"
	while [ $q != "yes" ]
	do 
		read -p "键入 node$i 的ip [q键退出]:  " ip
		if [ $ip != "q" ] && [ $ip != "Q" ]
		then	
			echo "$ip node${i}" >>/etc/hosts
		else
			q="yes"
		fi
		i=$(($i+1))
	done
fi 


echo -e "目前hosts文件内容如下：\n" && cat /etc/hosts


#生成本地ssh pubkey 
[ -f ~/.ssh/id_rsa ] || ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa


for i in `cat /etc/hosts |grep -v localhost | awk '{print $2}'`
do
	put_sshkey $i $nodepw
done

