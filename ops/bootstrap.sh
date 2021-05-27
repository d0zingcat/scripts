#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#=======================================================================================#
#       OS required: Debian 9+(Other versions will not be supported)                    #       
#       Description: Out-of-box use for backing up and migration                        #
#       Author: d0zingcat <asong4love@gmail.com>                                        #
#       Thanks: Nobody                                                                  #
#       Intro: On-the-way                                                               #
#=======================================================================================#

clear
echo
echo '###################################################################################'
echo '# Easy backup and recover VPS for frequent VPS creatation and release             #'
echo '# Author: d0zingcat <asong4love@gmail.com>                                        #'
echo '# Blog: https://blog.d0zingcat.xyz/                                               #'
echo '###################################################################################'
echo

dp_backup_path=/Apps/Dphandler/
temp_dir=.temp/

# Colors
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

os_initial() {
        apt update
        apt upgrade -y
        apt dist-upgrade -y
        apt install -y build-essential lrzsz vim git g++ sudo zip wget nload htop iptables nvim socat snapd 
        snap install core
        snap install shadowsocks-libev
        apt remove docker docker-engine docker.io containerd runc
        apt install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common
        curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
        apt-key fingerprint 0EBFCD88
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
        apt update
        apt install -y docker-ce docker-ce-cli containerd.io
        curl -L "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        curl -s https://install.zerotier.com | bash
}

check_privilege() {
        if [ "$(id -u)" != "0" ]; then
                echo "[ERROR] You must be root to run this script!!!" >&2
                exit 1
        fi
}

add_user() {
        read -p 'Username to add: ' user
        adduser $user
        echo "User added successfully"
        usermod -aG docker $user
        usermod -aG sudo $user
}

# should only use this function on Alibaba cloud
uninstall_aegis() {
        wget http://update.aegis.aliyun.com/download/uninstall.sh
        chmod +x uninstall.sh
        ./uninstall.sh
        wget http://update.aegis.aliyun.com/download/quartz_uninstall.sh
        chmod +x quartz_uninstall.sh
        ./quartz_uninstall.sh
        pkill aliyun-service
        rm -fr /etc/init.d/agentwatch /usr/sbin/aliyun-service
        rm -rf /usr/local/aegis*
        iptables -I INPUT -s 140.205.201.0/28 -j DROP
        iptables -I INPUT -s 140.205.201.16/29 -j DROP
        iptables -I INPUT -s 140.205.201.32/28 -j DROP
        iptables -I INPUT -s 140.205.225.192/29 -j DROP
        iptables -I INPUT -s 140.205.225.200/30 -j DROP
        iptables -I INPUT -s 140.205.225.184/29 -j DROP
        iptables -I INPUT -s 140.205.225.183/32 -j DROP
        iptables -I INPUT -s 140.205.225.206/32 -j DROP
        iptables -I INPUT -s 140.205.225.205/32 -j DROP
        iptables -I INPUT -s 140.205.225.195/32 -j DROP
        iptables -I INPUT -s 140.205.225.204/32 -j DROP
}
enable_bbr() {
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
        sysctl -p
}
enable_ecn() {
	echo 'net.ipv4.tcp_ecn = 2' >> /etc/sysctl.conf
	echo 'net.ipv4.tcp_ecn_fallback = 1' >> /etc/sysctl.conf
	sysctl -p
}

install_acme() {
        git clone https://github.com/Neilpang/acme.sh.git
        cd ./acme.sh
        ./acme.sh --install
}
download_dpuploader() {
        git clone https://github.com/andreafabrizi/Dropbox-Uploader.git
        cp Dropbox-Uploader/dropbox_uploader.sh /usr/local/bin/
        chmod u+x /usr/local/bin/dropbox_uploader.sh
        dropbox_uploader.sh
}
compress_backup() {
        dir=$1
        dir=/tmp/
        filename=archive_$(date +%Y-%m-%dT%H%M%S).tar.gz
        tar -zcvf $dir$filename $HOME/
        dropbox_uploader.sh upload $dir$filename $2
}
purge_old_backups() {
        dropbox_uploader.sh list $1 | tail -n +2 | head --lines=$2 | awk '{print $3}' | xargs -I {} -n 1 dropbox_uploader.sh delete $1/{}
}
download_recovery() {
        dir=$1
        latest_file=$(dropbox_uploader.sh list $dir | tail -n 1 | awk '{print $3}')
        if [ -f $latest_file ]; then
                echo "File $latest_file already downloaded!"
        else
                dropbox_uploader.sh download $dir$latest_file
        fi
        tar zxvf $latest_file -C /
        chown -R $2:$2 /home/$2/
}
cleanup() {
        rm -rf $1
}
disable_root_login() {
        c=$(grep -E '^PermitRootLogin' /etc/ssh/sshd_config | wc -l)
        if [ $c -gt 0 ]; then
                sed -i -r 's/^PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
        else
                echo 'PermitRootLogin no' >> /etc/ssh/sshd_config
        fi
        systemctl reload sshd
}
# as the block seems to more and more strict theses days, choose http obfuscation ad least
compose_ss() {
        #read -ps 'Please enter the password(or visit this https://duckduckgo.com/?q=password+12&t=ffsb&ia=answer): ' pass
        port=$(( $RANDOM % 10000 + 10000))
        port=13579
        echo "port: $port"
        #pass=$(cat /dev/urandom | base64 | head -n 1 |cut -c -10)
		pass=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 10 ; echo '')
        echo 'password: '$pass
        method=chacha20-ietf-poly1305
        userinfo=$(echo -n "$method:$pass" | base64)
        outer_ip=$(curl -s https://ipinfo.io/ip)
        echo 'ip: '$outer_ip
        ss_link="ss://$userinfo@$outer_ip:$port#auto-ss"
        echo -e "For quick addition: \n$ss_link\n"
        #docker pull shadowsocks/shadowsocks-libev
        #cmd="docker run -e PASSWORD=$pass -e METHOD=$method -p$port:8388 -p$port:8388/udp -d shadowsocks/shadowsocks-libev"
        #cmd="docker run --network host -d -p $port:8388 -p $port:8388/udp mritd/shadowsocks -s '-s 0.0.0.0 -s :: -p 8388 -m $method -k $pass'"
        cmd="docker run -p $port:8388/tcp -p $port:8388/udp -v /usr/local/etc/shadowsocks-libev:/etc/shadowsocks-libev -d teddysun/shadowsocks-libev"
        cat > /usr/local/etc/shadowsocks-libev/config.json <<EOF
{
"server":"0.0.0.0",
"server_port":8388,
"method":"$method",
"timeout":300,
"password":"$pass",
"fast_open":false,
"nameserver":"8.8.8.8",
"mode":"tcp_and_udp",
"plugin":"v2ray-plugin",
"plugin_opts":"server"
}
EOF
        echo "cmoomand is: $cmd"
        id=`$cmd`
        echo "container id: $id"
}
#compose_ss_wss() {
#
#}

stop_ss() {
        docker ps | grep shadowsocks/shadowsocks-libev| awk '{print $1}'| xargs docker stop
}

download_frp() {
        curl -s https://api.github.com/repos/fatedier/frp/releases/latest | grep "browser_download_url" | cut -d '"' -f 4 | grep 'linux_amd64' | wget -qi -
        tar zxvf *.tar.gz
}
action=$1
[ -z $1 ] && action=nothing
case "$action" in
        init)
                # Initialization step
                if [ -d $temp_dir ]; then
                        echo "$temp_dir already existed! Skipping..."
                else
                        mkdir $temp_dir
                fi
                cd $temp_dir
                check_privilege
                os_initial
                read -p 'User desiered to recovery(create): ' recovery_user
                add_user $recovery_user
                enable_bbr
                download_dpuploader
                disable_root_login
                ;;
        backup)
                purge_old_backups $dp_backup_path 1
                compress_backup $temp_dir $dp_backup_path
                ;;
        recover)
                download_recovery $dp_backup_path $recovery_user
                ;;
        purge-aegis)
                uninstall_aegis
                ;;
        ss-start)
                compose_ss
                ;;
        ss-stop)
                stop_ss
                ;;
        cleanup)
                cleanup $temp_dir
                ;;
        acme)
                install_acme
                ;;
        *)
                echo 'Arguments error! [$(action)]'     
                ;;
esac
