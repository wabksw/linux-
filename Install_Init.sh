#!/bin/bash
#author by bks
###2018-10-15  新增回收站功能,每天清空
###2018-12-24  新增同步系统硬件时间
###2019-03-19  新增安装docker,sysstat
###2019-04-23  新增grep，ll，ls命令查找高亮关键字
###2019-04-23  新增dstat
#查看当前占用I/O、cpu、内存等最高的进程信息
#dstat --top-mem --top-io --top-cpu
###2019-09-17  修复别名未生效bug
###2021-06-29  新增atop，记录系统资源与进程日志
#读取atop日志文件： atop  -r  XXX
 
#定义终端输出颜色
Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息:]${Font_color_suffix}"
Error="${Red_font_prefix}[错误:]${Font_color_suffix}"

#安装常用软件包
Install_Pack(){
        yum install wget ntpdate telnet dstat tmux vim sysstat net-tools perf atop -y
}

#启动服务
Start_Services(){
        sed -i "s/LOGGENERATIONS=28/LOGGENERATIONS=7/g" /etc/sysconfig/atop 
        systemctl enable --now atop
}

#定义别名、回收站
Recycle_Bin_And_Alias(){
cat >> /root/.bashrc << EOF
alias cls='clear'
alias vi='vim'
alias grep='grep --color'
alias ll='ls -l --color=auto'
alias ls='ls --color=auto'
alias rm='myrm'
myrm(){
    for target in \$@
    do
        if [[ "\$target" =~ ^-[rf]+$ ]]; then
            continue
        fi
    mv -i \$target ~/.recycle
    done
}
EOF
}

#禁用selinux和防火墙
Disable_Firewall_And_Selinux(){
        sed -i.bak 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
        systemctl disable firewalld
        systemctl stop firewalld
}

#创建安装包目录
Create_Directory(){
        mkdir -p /home/bks/tools
        mkdir ~/.recycle
}

#添加镜像源
Add_Mirror_Source(){
        mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
        curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.163.com/.help/CentOS7-Base-163.repo
        wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
        yum clean all
        yum makecache fast
}

#添加k8s需要的yum源
K8s_Source(){
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
EOF
}

#安装docker,默认不启用
Install_Docker(){
        yum install -y yum-utils
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y docker-ce
        systemctl stop docker
        systemctl disable docker
}

#时间同步
Time_Synchronization(){
        \cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
        /usr/sbin/ntpdate pool.ntp.org
cat >>  /var/spool/cron/root  << EOF
#time sync by bks
*/10 * * * * /usr/sbin/ntpdate pool.ntp.org && /sbin/hwclock -w >/dev/null 2>&1
0 0 * * * /usr/bin/rm -rf /root/.recycle/* >/dev/null 2>&1
EOF

#重启atop
cat >> /etc/cron.d/atop << EOF
0 1 * * * root systemctl try-restart atop
EOF

}

#配置主机名
Hostname_Config(){
        echo
        read -p "请输入主机名：" hostname
        hostnamectl set-hostname $hostname
}

Install_Pack
Start_Services
Recycle_Bin_And_Alias
Disable_Firewall_And_Selinux
Create_Directory
Add_Mirror_Source
K8s_Source
Install_Docker
Time_Synchronization
Hostname_Config

if [[ `echo $?` -eq 0 ]];then
        echo -e "${Info}   初始化服务器环境安装完成"
        rm -f Install_Init.sh
else
        echo -e "${Error}  初始化服务器环境安装失败"
fi
