#!/bin/bash

#
# Projet Architecture Distribuée : MyPipeline
#
# Benjamin THERY  <benjamin.thery@grenoble-inp.org> / <benjamin.thery@atos.net>
# Dominique POPEK <dominique.popek@grenoble-inp.org> / <dominique.popek@atos.net>
#
# Script pour créer les dockers qui vont héberger les différents services
# de l'application.
#
# Ce script:
# - télécharge toutes les archives nécessaires au projet
# - créé l'image docker de base a partir d'une image centos
#     - cette image est construite a partir du fichier Dockerfile
# - créé le reseau docker sur lequel les dockers vont communiquer
# - créé les differents dockers qui vont héberger les services avec leurs
#   hostnames et adresses IP
#
# Avec une VM Centos 7 configuré avec 6GB de mémoire et 15GB de disques,
# l'application mypipeline a tourné sur 6 dockers différents
# (en diminuant beaucoup la taille mémoires des différentes vm java)
# Cf. mypipeline-docker/mypipeline-install.sh
#

STAGE=$1

usage() {
    echo "Usage: $0 init_image|deploy_all|stop_all|destroy_all"
    echo ""
    echo "  init_image:  create base docker image for mypipeline dockers"
    echo "  deploy_all:  create and start all mypipeline dockers"
    echo "  stop_all:    stop all mypipeline dockers"
    echo "  destroy_all: remove all mypipeline dockers"
	echo ""
	echo "  To create image and docker for mypipeline application do:"
	echo ""
	echo "    $0 init_image"
	echo "    cat mypipeline-hosts >> /etc/hosts"
	echo "    ssh root@zookeeper01"
	echo "        cd /home/projet-mypipeline"
	echo "        ./mypipeline-install.sh $PWD all 1"
	echo "        exit"
	echo "    $0 deploy_all"
	echo ""
}

DOCKER_NET=mypipeline-net
DOCKER_IMG=bthery/mypipeline-base2:latest

DOCKERS="zookeeper01 kafka01 spark01 cassandra01 feeder streaming"
#DOCKERS="zookeeper01 kafka01 kafka02 kafka03 spark01 cassandra01 feeder streaming"


print_banner() {
    echo "------------------------------------------------------------"
    echo "$*"
    echo "------------------------------------------------------------"
}

#
# Create a docker: create_docker <docker_name> <ip_address>
#
create_docker() {
    local name=$1
    local ip=$2
    local force=$3

    print_banner "Create docker $name / $ip"

    if docker inspect $name >& /dev/null; then
        echo "Docker $name already exists"
        return 1
    fi

    docker create \
           --name=$name \
           --net=$DOCKER_NET \
           --ip=$ip \
           --hostname=$name \
           --add-host=zookeeper01:172.20.0.11 \
           --add-host=zookeeper02:172.20.0.12 \
           --add-host=zookeeper03:172.20.0.13 \
           --add-host=kafka01:172.20.0.21 \
           --add-host=kafka02:172.20.0.22 \
           --add-host=kafka03:172.20.0.23 \
           --add-host=spark01:172.20.0.31 \
           --add-host=cassandra01:172.20.0.41 \
           --add-host=cassandra02:172.20.0.42 \
           --add-host=cassandra03:172.20.0.43 \
           --add-host=feeder:172.20.0.2 \
           --add-host=streaming:172.20.0.3 \
           $DOCKER_IMG \
           /usr/sbin/sshd -D
    if [ $? == 1 ] ; then
        echo "Failed to create docker $name"
        return 1
    else
        echo "Docker $name created"
    fi
}

start_docker() {
    local name=$1

    print_banner "Start docker $name"
    docker start $name
}

copy_ssh_key() {
    local name=$1
    print_banner "Copy SSH public key to $name"
    docker exec $name mkdir /root/.ssh 2> /dev/null
    docker exec $name chmod 700 /root/.ssh
    docker cp $HOME/.ssh/id_dsa.pub $name:/root/.ssh/authorized_keys
    docker exec $name chmod 600 /root/.ssh/authorized_keys
    docker exec $name chown -R root:root /root/.ssh
    docker exec $name sed -i "s/#PubkeyAuthentication yes/PubkeyAuthentication yes/" /etc/ssh/sshd_config
}

create_all_dockers() {
    create_docker zookeeper01 172.20.0.11
#    create_docker zookeeper02 172.20.0.12
#    create_docker zookeeper03 172.20.0.13
    create_docker kafka01 172.20.0.21
#    create_docker kafka02 172.20.0.22
#    create_docker kafka03 172.20.0.23
    create_docker spark01 172.20.0.31
    create_docker cassandra01 172.20.0.41
#    create_docker cassandra02 172.20.0.42
#    create_docker cassandra03 172.20.0.43
    create_docker feeder 172.20.0.2
    create_docker streaming 172.20.0.3
}

start_all_dockers() {
    for docker in $DOCKERS; do
        start_docker $docker
    done
}

stop_all_dockers() {
    for docker in $DOCKERS; do
        print_banner "Stop docker $docker"
        docker stop $docker
    done
}

copy_all_ssh_key() {
    for docker in $DOCKERS; do
        copy_ssh_key $docker
    done
}

destroy_all_dockers() {
    print_banner "Remove all dockers: $DOCKERS"
    docker rm $DOCKERS
}

#
# Main
#

echo "[$0: $(date)]"

if [ "$STAGE" == "" ]; then
    usage
    exit 1
elif [ "$STAGE" == "init_image" ]; then
	# Download all the archives
	./mypipeline-download.sh mypipeline-docker

	# Build base image
    if ! docker image inspect $DOCKER_IMG >& /dev/null; then
        print_banner "Build docker image $DOCKER_IMG"
        docker build --tag=$DOCKER_IMG mypipeline-docker/
    fi

    # Create network
    if ! docker network inspect $DOCKER_NET >& /dev/null; then
        print_banner "Create docker network $DOCKER_NET"
        docker network create --subnet=172.20.0.0/16 $DOCKER_NET
    fi
fi

# 0. Add content of mypipeline-hosts file to /etc/hosts of the host system
#    so you can ssh to the different dockers
#
# cat mypipeline-hosts >> /etc/hosts

# Bon tout n'est pas encore automatiser,
# il faut encore customiser un peu l'image
#
# 1. Créer un premier docker à partir de l'image créée ci-dessus
if [ "$STAGE" == "init_image" ]; then
    create_docker zookeeper01 172.20.0.11
    start_docker zookeeper01
    copy_ssh_key zookeeper01
fi

# 2. Se connecter au docker et lancer le script d'installation mypipeline-install.sh
#
# C'est lui qui va mettre toutes les bonnes adresses des différents
# services dans tous les sources, fichiers de configurations et scripts
# pour que tout le monde puisse communiquer ensuite depuis plusieurs
# machines. Et builder les applications Scala.
#
# ssh root@zookeeper01 (mot de passe: password)
# cd /home/projet-mypipeline/
# ./mypipeline-install.sh
if [ "$STAGE" == "init_image" ]; then
    print_banner ""
    echo -e "\nFirst docker created: zookeeper01"
    echo    "Now connect to root@zookeeper01 and run './mypipeline-install.sh \$PWD all 1' to finalize the image"
    echo -e "Once done, re-run this script with stage2 parameter: $0 stage2\n"
    print_banner ""
fi

# 3. S'assurer que tout c'est bien passé, sortir du docker et mettre a jour l'image
#
# exit
# docker stop zookeeper01
# docker commit -m "Configure all services" -a "<author name>" <docker_id> bthery/mypipeline-base:latest
if [ "$STAGE" == "deploy_all" ]; then
    print_banner "Commit image changes"
    docker stop zookeeper01
    docker commit -m "Configure all services" -a "Benjamin Thery" zookeeper01 $DOCKER_IMG
fi

#
# On a maintenant une belle image qui peut servir pour tous les services
# avec un minimum de configuration.
#

# 4. Creer tous les dockers a partir de cette image
# Décommenter les 5 lignes ci-dessous, commenter celles de l'étape 1 et relancer le script
#
if [ "$STAGE" == "deploy_all" ]; then
    create_all_dockers
    start_all_dockers
fi

# 5. Se connecter aux differents docker et lancer les services comme decrit dans le TP
#    https://msbd-distsys.gitlab.io/lab2.html
#
# Voila on a distribué l'application mypipeline
if [ "$STAGE" == "deploy_all" ]; then
    print_banner ""
    echo -e "\nIf all went well, all dockers should be running now\n"
    docker ps
    print_banner ""
fi

if [ "$STAGE" == "stop_all" ]; then
    stop_all_dockers
elif [ "$STAGE" == "destroy_all" ]; then
    destroy_all_dockers
fi

echo "[$0: $(date)]"
