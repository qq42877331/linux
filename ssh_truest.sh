#!/bin/bash

'''
这个脚本会自己生成本地ssh pubkey，并根据hosts内容，找到相应主机并同步密钥过去，完全后ssh可以免密码登陆
  1、首先在/etc/hosts里填好ip与host的对应关系
  2、host的密码都是统一的
'''

[ -f ~/.ssh/id_rsa ] || ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa

echo -e "\033[31m 请把节点 [IP]、[计算机名] 添加到/etc/hosts\n \033[0m"

read -p "请输远端节点的root密码，要求全部节点使用同一密码：" nodepw

#定义一个put_sshkey方法
put_sshkey(){
/usr/bin/expect -c "
        set timeout 10
        spawn ssh-copy-id -o StrictHostKeyChecking=no -i /root/.ssh/id_rsa.pub root@$1
        expect {
            password: { send $2\r;interact; }
        
        }"
}

for i in `cat /etc/hosts |grep -v localhost | awk '{print $2}'`
do
                put_sshkey $i $nodepw
done

