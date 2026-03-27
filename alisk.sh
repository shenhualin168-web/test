#!/usr/bin/env bash

#====================================================
#	System Request:Centos 7
#	Author:	Coffee Zhang (Modified by User)
#	Dscription: Socks5 Installation (Auto Install - Public IP Only)
#	Version: 1.1
#====================================================

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

cd "$(
    cd "$(dirname "$0")" || exit
    pwd
)" || exit

rm -rf $(pwd)/$0
#fonts color
Green="\033[32m"
Red="\033[31m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"
source '/etc/os-release'

OK="${Green}[OK]${Font}"
error="${Red}[错误]${Font}"

# 固定配置
Port="5188"
ss_user="admin"
ss_pass="facai168"

# 判断是否为内网IP的函数
is_private_ip() {
    local ip=$1
    # 内网IP段：
    # 10.0.0.0/8
    # 172.16.0.0/12
    # 192.168.0.0/16
    # 127.0.0.0/8
    # 169.254.0.0/16 (链路本地)
    
    if [[ $ip =~ ^10\. ]] || \
       [[ $ip =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] || \
       [[ $ip =~ ^192\.168\. ]] || \
       [[ $ip =~ ^127\. ]] || \
       [[ $ip =~ ^169\.254\. ]]; then
        return 0  # 是内网IP
    else
        return 1  # 是公网IP
    fi
}

# 只获取公网IP
get_public_ips() {
    local all_ips=($(ip -4 addr | sed -ne 's|^.* inet \([^/]*\)/.* scope global.*$|\1|p' | awk '{print $1}'))
    local public_ips=()
    
    for ip in "${all_ips[@]}"; do
        if ! is_private_ip "$ip"; then
            public_ips+=("$ip")
        fi
    done
    
    echo "${public_ips[@]}"
}

check_system() {
    if [[ "${ID}" == "centos" && ${VERSION_ID} -ge 7 ]]; then
        echo -e "${OK} ${GreenBG} 当前系统为 Centos ${VERSION_ID} ${VERSION} ${Font}"
        INS="yum"
	$INS -y install lsof wget zip unzip curl bash-completion ca-certificates wget vim curl net-tools epel-release bind-utils
	yum remove firewalld -y ; yum install -y iptables-services ; iptables -F ; iptables -t filter -F ; systemctl enable iptables.service ; service iptables save ; systemctl start iptables.service
    else
        echo -e "${Error} ${RedBG} 当前系统为 ${ID} ${VERSION_ID} 请使用centos7，安装中断 ${Font}"
        exit 1
    fi
}

is_root() {
    if [ 0 == $UID ]; then
        echo -e "${OK} ${GreenBG} 当前用户是root用户，进入安装流程 ${Font}"
        sleep 1
    else
        echo -e "${Error} ${RedBG} 当前用户不是root用户，请切换到使用 'sudo -i' 切换到root用户后重新执行脚本 ${Font}"
        exit 1
    fi
}

judge() {
    if [[ 0 -eq $? ]]; then
        echo -e "${OK} ${GreenBG} $1 完成 ${Font}"
        sleep 1
    else
        echo -e "${Error} ${RedBG} $1 失败${Font}"
        exit 1
    fi
}

sic_optimization() {
    sed -i '/^\*\ *soft\ *nofile\ *[[:digit:]]*/d' /etc/security/limits.conf
    sed -i '/^\*\ *hard\ *nofile\ *[[:digit:]]*/d' /etc/security/limits.conf
    echo '* soft nofile 65536' >>/etc/security/limits.conf
    echo '* hard nofile 65536' >>/etc/security/limits.conf

    if [[ "${ID}" == "centos" ]]; then
        sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
        setenforce 0
    fi
}

port_set() {
    echo -e "${OK} ${GreenBG} 使用固定端口: ${Port} ${Font}"
}

port_exist_check() {
    if [[ 0 -eq $(lsof -i:"${Port}" | grep -i -c "listen") ]]; then
        echo -e "${OK} ${GreenBG} ${Port} 端口未被占用 ${Font}"
        sleep 1
    else
        echo -e "${Error} ${RedBG} 检测到 ${Port} 端口被占用，以下为 ${Port} 端口占用信息 ${Font}"
        lsof -i:"${Port}"
        echo -e "${OK} ${GreenBG} 5s 后将尝试自动 kill 占用进程 ${Font}"
        sleep 5
        lsof -i:"${Port}" | awk '{print $2}' | grep -v "PID" | xargs kill -9
        echo -e "${OK} ${GreenBG} kill 完成 ${Font}"
        sleep 1
    fi
}

user_set() {
    echo -e "${OK} ${GreenBG} 使用固定账号: ${ss_user} 密码: ${ss_pass} ${Font}"
}

ip_list() {
    # 获取所有IP用于显示
    echo -e "${OK} ${GreenBG} 检测到的公网IP: ${Font}"
    local public_ips=($(get_public_ips))
    for ip in "${public_ips[@]}"; do
        echo -e "   ${Green}${ip}${Font}"
    done
    
    if [ ${#public_ips[@]} -eq 0 ]; then
        echo -e "${error} ${RedBG} 未检测到公网IP，请检查网络配置 ${Font}"
        exit 1
    fi
    
    echo -e "${OK} ${GreenBG} 可用公网IP个数: ${#public_ips[@]} ${Font}"
    
    # 将公网IP数组导出供后续使用
    ips=("${public_ips[@]}")
}

ss_install() {
    if [ -e /usr/local/sbin/xray ];then
        echo -e "${OK} ${GreenBG} Xray已安装，跳过下载 ${Font}"
    else
        wget -O /usr/local/sbin/xray-linux-64.zip --no-check-certificate https://my.oofeye.com/Xray-linux-64.zip
        cd /usr/local/sbin ; unzip -o xray-linux-64.zip
        chmod +x /usr/local/sbin/xray
    fi

    cat <<EOF > /etc/systemd/system/xray.service
[Unit]
Description=Socks5 Service
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/sbin/xray run -config /etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable xray.service &> /dev/null
}

config_install () {
    mkdir -p /etc/xray
    mkdir -p /var/log/v2ray
    >/etc/xray/config.json
    
    cat <<EOF >> /etc/xray/config.json
{
  "log": {
        "access": "/var/log/v2ray/access.log",
        "error": "/var/log/v2ray/error.log",
        "loglevel": "warning"
    },
  "inbounds": [
EOF

    # 清空或创建账号文件
    >/root/${Port}.txt
    
    for ((i = 0;i < ${#ips[@]}; i++)); do
        # 只将公网IP写入账号文件
        echo -e "${ips[i]}\t${Port}\t${ss_user}\t${ss_pass}" >>/root/${Port}.txt
        
        cat <<EOF >> /etc/xray/config.json
    {
    "port": "${Port}",
      "listen": "${ips[i]}", 
      "tag": "$((i+1))", 
      "protocol": "socks", 
      "settings": {
        "auth": "password",
        "accounts": [
          {
  	    "user":"${ss_user}",
            "pass": "${ss_pass}"
          }
        ],
	"udp": true
      }, 
      "streamSettings": {
        "network": "tcp" 
        }
      },
EOF
    done
    
    sed -i '$d' /etc/xray/config.json
    echo '    }
  ],
  "outbounds": [' >> /etc/xray/config.json

    for ((i = 0;i < ${#ips[@]}; i++)); do
        cat <<EOF >> /etc/xray/config.json
    {
      "protocol": "freedom", 
      "settings": { }, 
      "sendThrough": "${ips[i]}",
      "tag": "$((i+1))"
    },
EOF
    done

    echo '    {
      "protocol": "blackhole", 
      "settings": { }, 
      "tag": "blocked"
    }
  ], 
  "dns": {
    "servers": [
      "https+local://1.1.1.1/dns-query",
	  "1.1.1.1",
	  "1.0.0.1",
	  "8.8.8.8",
	  "8.8.4.4",
	  "localhost"
    ]
  },
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [' >> /etc/xray/config.json

    for ((i = 0;i < ${#ips[@]}; i++)); do
        cat <<EOF >> /etc/xray/config.json
      {
        "type": "field",
        "inboundTag": "$((i+1))",
        "outboundTag": "$((i+1))"
      },
EOF
        # 测试每个公网IP的出口
        echo -e "${OK} ${GreenBG} 测试出口IP: ${ips[i]} ${Font}"
        curl --interface ${ips[i]} -s http://ip.sb
        echo ""
    done
    
    sed -i '$d' /etc/xray/config.json

    echo '      }
    ]
  }
}
'  >>  /etc/xray/config.json

    systemctl start xray.service
    echo -e "${OK} ${GreenBG} 配置文件已生成，账号信息保存在 /root/${Port}.txt ${Font}"
    echo -e "${GreenBG}==================== 账号信息 ====================${Font}"
    cat /root/${Port}.txt
    echo -e "${GreenBG}==================================================${Font}"
}

# 主安装流程
is_root
check_system
ip_list
sic_optimization
port_set
port_exist_check
user_set
ss_install
config_install
judge "安装"
