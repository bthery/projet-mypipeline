#!/bin/bash

#
# Projet Architecture Distribuée : MyPipeline
#
# Benjamin THERY  <benjamin.thery@grenoble-inp.org> / <benjamin.thery@atos.net>
# Dominique POPEK <dominique.popek@grenoble-inp.org> / <dominique.popek@atos.net>
#
# Script pour télécharger toutes les archives nécessaires au projet
#

#set -x
#set -e

DESTDIR=$1

PROXY=
#PROXY=http://193.56.47.8:8080/
#PROXY=http://193.56.47.20:8080/

export http_proxy=$PROXY
export https_proxy=$PROXY

print_banner() {
    echo "------------------------------------------------------------"
    echo "$*"
    echo "------------------------------------------------------------"
}

download_all() {
    if [ ! -e MyPipeline.tar.gz ]; then
        wget https://msbd-distsys.gitlab.io/files/MyPipeline.tar.gz
    fi

    if [ ! -e scala-2.10.6.tgz ]; then
        wget https://downloads.lightbend.com/scala/2.10.6/scala-2.10.6.tgz
    fi

    if [ ! -e sbt-0.13.17.tgz ]; then
        wget https://piccolo.link/sbt-0.13.17.tgz
    fi

    # zookeeper-3.4.10 has been removed from apache mirrors
    # need to download zookeeper-3.4.13 instead
    #if [ ! -e zookeeper-3.4.10.tar.gz ]; then
    #    wget https://github.com/apache/zookeeper/archive/release-3.4.10.tar.gz
    #fi
    if [ ! -e zookeeper-3.4.13.tar.gz ]; then
        wget http://apache.mirrors.ovh.net/ftp.apache.org/dist/zookeeper/zookeeper-3.4.13/zookeeper-3.4.13.tar.gz
    fi

    if [ ! -e kafka_2.11-1.0.0.tgz ]; then
        wget https://archive.apache.org/dist/kafka/1.0.0/kafka_2.11-1.0.0.tgz
    fi

    if [ ! -e spark-1.6.3-bin-hadoop2.6.tgz ]; then
        wget https://archive.apache.org/dist/spark/spark-1.6.3/spark-1.6.3-bin-hadoop2.6.tgz
    fi

    if [ ! -e apache-cassandra-3.11.1-bin.tar.gz ] ; then
        wget http://archive.apache.org/dist/cassandra/3.11.1/apache-cassandra-3.11.1-bin.tar.gz
    fi
}

#
# Main
#

if [ "$DESTDIR" != "" ]; then
	cd $DESTDIR
fi

print_banner "Download archives to $PWD"

download_all

