#!/usr/bin/env bash
set -x
WORK_DIR=./backup
MARKUP_DIR=./backup/.markup
# load ENVs
if [ ! -f .env ]
then
  export $(cat .env | xargs)
fi
# mkdir backup
if [ ! -d $WORK_DIR ]; then
	mkdir $WORK_DIR
fi
# mkdir markups
if [ ! -d $WORK_DIR/markup ]; then
	mkdir $MARKUP_DIR
fi
# replace mirrors
if [ ! -d $WORK_DIR/etc/apt/sources.list.d ]; then
	mkdir -p $WORK_DIR/etc/apt/sources.list.d
fi
if [ ! -f $WORK_DIR/etc/apt/sources.list.d/raspi.list ]; then
	sudo cp /etc/apt/sources.list.d/raspi.list $WORK_DIR/etc/apt/sources.list.d
	sudo sed -i 's|http://archive.raspberrypi.org|https://mirrors.sjtug.sjtu.edu.cn|g' /etc/apt/sources.list.d/raspi.list
	sudo apt update
fi
#if [ ! -f $WORK_DIR/etc/apt/sources.list ]; then
#	sudo cp /etc/apt/sources.list $WORK_DIR/etc/apt/
#	sudo sed -i 's|http://deb.debian.org|https://mirrors.sjtug.sjtu.edu.cn|g' /etc/apt/sources.list
#	sudo apt update
#fi
# install essentials
sudo apt install -y build-essential nload htop neovim curl
# install zeortier
if [ ! -f $MARKUP_DIR/.zerotier ]; then
	curl -s https://install.zerotier.com | sudo bash
	sudo zerotier-cli join $NETWORK_ID
	sudo zerotier-cli orbit $MOON_ID $MOON_ID
	touch $MARKUP_DIR/.zerotier
fi
# install docker
if [ ! -f $MARKUP_DIR/.docker ]; then
	sudo apt-get remove docker docker-engine docker.io containerd runc
	sudo apt-get update
	sudo apt-get install -y \
    	apt-transport-https \
    	ca-certificates \
    	curl \
    	gnupg \
    	lsb-release
	#curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
	#echo \
  	#"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
  	#$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	echo \
  	"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://mirror.sjtu.edu.cn/docker-ce/linux/debian \
  	$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	sudo apt-get update sudo apt-get install -y docker-ce docker-ce-cli containerd.io
	sudo usermod -aG docker $USER
        sudo bash -c 'cat <<- EOF > /etc/docker/daemon.json
        {
          "registry-mirrors": ["https://docker.mirrors.sjtug.sjtu.edu.cn"]
        }
        EOF'
        sudo systemctl restart docker 
	touch $MARKUP_DIR/.docker
fi
# install docker-compose
if [ ! -f $MARKUP_DIR/.docker-compose ]; then
	sudo apt install -y python3-pip libffi-dev
        sudo pip3 install docker-compose
	touch $MARKUP_DIR/.docker-compose
fi
