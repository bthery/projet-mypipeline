#!/bin/bash

#
# Projet Architecture Distribuée : MyPipeline
#
# Benjamin THERY  <benjamin.thery@grenoble-inp.org> / <benjamin.thery@atos.net>
# Dominique POPEK <dominique.popek@grenoble-inp.org> / <dominique.popek@atos.net>
#
# Script de deploiement:
#
# Permet d'installer automatiquement les services demandés sur le noeud.
# Télécharge les archives, compile les application et modifie tous les fichiers
# de configurations et les scripts de lancement avec les adresses des différents
# noeuds.
#
#    Usage: mypipeline-install.sh <install_dir> <node_type> [<node_id>]
#
#    Node types: zookeeper, kafka, feeder, streaming, spark, cassandra, all
#    Note id: Only used for kafka to specify the broker ID
#

#set -x
#set -e

#
# Env Configuration
#
ROOT_DIR=$1
NODE_TYPE=$2
NODE_ID=$3

ENV_FILE=${ROOT_DIR}/myenv.sh
DIST=redhat # debian|redhat

# Set this if we are behind Atos web proxy
#PROXY=http://193.56.47.8:8080/

#
# Hosts
#
# Check /etc/hosts contains these hostnames (also see mypipeline-hosts file)
KAFKA_BROKERS=kafka01:9092,kafka02:9092,kafka03:9092
ZOOKEEPERS=zookeeper01:2181
CASSANDRA_HOST=cassandra01
SPARK_HOST=spark01

usage() {
    echo "Usage: $0 <install_dir> <node_type> [<node_id>]"
    echo ""
    echo "Node types: zookeeper, kafka, feeder, streaming, spark, cassandra, all"
    echo "Note id: Only used for kafka to specify the broker ID"
}

print_banner() {
    echo "------------------------------------------------------------"
    echo "$*"
    echo "------------------------------------------------------------"
}

#
# Install common dependencies
#
install_deps() {
    print_banner "Install common dependencies"
    if [ "$DIST" = "redhat" ]; then
        $SUDO yum install -y epel-release wget bzip2 java-1.8.0-openjdk-headless
    elif [ "$DIST" = "debian" ]; then
        $SUDO apt install wget bzip2 java-1.8.0-openjdk
    else
        echo "ERROR: Unknown distribution: $DIST"
    fi
}

#
# MyPipeline
#
install_mypipeline() {
    print_banner "Install MyPipeline"

    if [ ! -d MyPipeline ]; then
        if [ ! -e MyPipeline.tar.gz ]; then
            wget https://msbd-distsys.gitlab.io/files/MyPipeline.tar.gz
        fi
        tar xzf MyPipeline.tar.gz
        cp ${MYPIPELINE_HOME}/environment.bash ${MYPIPELINE_HOME}/environment.bash.orig
    fi

    MYPIPELINE_HOME=${ROOT_DIR}/MyPipeline
    ENV_FILE=${MYPIPELINE_HOME}/environment.bash

    sed -i "s@MYPIPELINE_HOME=TO-BE_COMPLETED@MYPIPELINE_HOME=${MYPIPELINE_HOME}@" $ENV_FILE

    echo "ROOT_DIR=${ROOT_DIR}" >> $ENV_FILE

    if ! grep -q $ENV_FILE $HOME/.bashrc; then
        echo ". $ENV_FILE" >> $HOME/.bashrc
    fi
}

#
# Scala 2.10.6
#
install_scala() {
    print_banner "Scala"

    if [ ! -d scala-2.10.6 ]; then
        if [ ! -e scala-2.10.6.tgz ]; then
            wget https://downloads.lightbend.com/scala/2.10.6/scala-2.10.6.tgz
        fi
        tar xzf scala-2.10.6.tgz
    fi

    SCALA_HOME=${ROOT_DIR}/scala-2.10.6
    echo "export SCALA_HOME=${SCALA_HOME}" >> $ENV_FILE
    echo "export PATH=${SCALA_HOME}/bin:\${PATH}" >> $ENV_FILE
}

#
# SBT 0.13
#
install_sbt() {
    print_banner "Install SBT"

    if [ ! -d sbt ]; then
        if [ ! -e sbt-0.13.17.tgz ]; then
            wget https://piccolo.link/sbt-0.13.17.tgz
            tar xzf sbt-0.13.17.tgz
        fi
    fi

    mkdir $HOME/bin 2> /dev/null

    if [ ! -e  ~/bin/sbt/sbt-launch.jar ]; then
        cp sbt/bin/sbt-launch.jar ~/bin
    fi

    if [ ! -e  ~/bin/sbt ]; then
        cat > ~/bin/sbt <<'EOT'
#!/bin/bash
SBT_OPTS="-Xms512M -Xmx1536M -Xss1M -XX:+CMSClassUnloadingEnabled -XX:MaxPermSize=256M"
java $SBT_OPTS -jar `dirname $0`/sbt-launch.jar "$@"
EOT
    chmod u+x ~/bin/sbt
    fi
}

#
# ZooKeeper 3.4.13
#
install_zookeeper() {
    print_banner "Install ZooKeeper"

    # zookeeper-3.4.10 has been removed from apache mirrors
    # need to download zookeeper-3.4.13 instead
    #
    #if [ ! -e zookeeper-3.4.10.tar.gz ]; then
    #    wget http://apache.mirrors.ovh.net/ftp.apache.org/dist/zookeeper/zookeeper-3.4.10/zookeeper-3.4.10.tar.gz
    #   tar xzf zookeeper-3.4.13.tar.gz
    #fi

    if [ ! -d zookeeper-3.4.13 ]; then
        if [ ! -e zookeeper-3.4.13.tar.gz ]; then
            wget http://apache.mirrors.ovh.net/ftp.apache.org/dist/zookeeper/zookeeper-3.4.13/zookeeper-3.4.13.tar.gz
        fi
        tar xzf zookeeper-3.4.13.tar.gz
    fi

    ZOOKEEPER_HOME=${ROOT_DIR}/zookeeper-3.4.13
    cp ${ZOOKEEPER_HOME}/conf/zoo_sample.cfg ${ZOOKEEPER_HOME}/conf/zoo.cfg

    sed -i "s@ZOOKEEPER_HOME=TO-BE-COMPLETED@ZOOKEEPER_HOME=${ZOOKEEPER_HOME}@" $ENV_FILE

    # Customize ZooKeeper metadata directory
    sed -i "s@dataDir=/tmp/zookeeper@dataDir=${ROOT_DIR}/zookeeper_data@" ${ZOOKEEPER_HOME}/conf/zoo.cfg

    # Configure JVM properties
    echo 'export JVMFLAGS="-Xmx400m"' > ${ZOOKEEPER_HOME}/conf/java.env
}

start_zookeeper() {
    . ${MYPIPELINE_HOME}/environment.bash
    ${MYPIPELINE_HOME}/my_scripts/mypipeline--start_zookeeper.bash
}

#
# Kafka 1.0.0 for Scala 2.11
#
install_kafka() {
    print_banner "Install Kafka"

    local BROKER_ID=$1

    if [ -z $BROKER_ID ]; then
        echo "ERROR: Kafka broker id not specified"
        return 1
    fi

    if [ ! -d kafka_2.11-1.0.0 ]; then
        if [ ! -e kafka_2.11-1.0.0.tgz ]; then
            wget https://archive.apache.org/dist/kafka/1.0.0/kafka_2.11-1.0.0.tgz
        fi
        tar xzf kafka_2.11-1.0.0.tgz
    fi

    KAFKA_HOME=${ROOT_DIR}/kafka_2.11-1.0.0
    sed -i "s@KAFKA_HOME=TO-BE-COMPLETED@KAFKA_HOME=${KAFKA_HOME}@" $ENV_FILE

    # Configure ZooKeeper addresses and ports
    sed -i "s@zookeeper.connect=localhost:2181@zookeeper.connect=${ZOOKEEPERS}@" ${KAFKA_HOME}/config/server.properties

    # Configure broker ID
    sed -i "s@broker.id=.*@broker.id=${BROKER_ID}@" ${KAFKA_HOME}/config/server.properties

    # Customize logs directory
    sed -i "s@log.dirs=.*@log.dirs=${ROOT_DIR}/kafka-logs@" ${KAFKA_HOME}/config/server.properties

    # Set ZooKeeper server in topic create script
    sed -i "s@--zookeeper localhost:2181@--zookeeper ${ZOOKEEPERS}@" ${MYPIPELINE_HOME}/my_scripts/mypipeline--create_kafka_topic.bash
}

start_kafka() {
    print_banner "Start Kafka"

    . ${MYPIPELINE_HOME}/environment.bash

    # Configure JVM properties
    #   vi ${KAFKA_HOME}/bin/kafka-server-start.sh
    #   OR
    #   set KAFKA_HEAP_OPTS="-Xmx512M -Xms512M"
    export KAFKA_HEAP_OPTS="-Xmx400M -Xms400M"

    # Start Kafka
    ${MYPIPELINE_HOME}/my_scripts/mypipeline--start_kafka.bash > kafka.out &

    # Create Kafka topic
    # Edit ${MYPIPELINE_HOME}/my_scripts/mypipeline--create_kafka_topic.bash


    # Create topic
    ${MYPIPELINE_HOME}/my_scripts/mypipeline--create_kafka_topic.bash
}

#
# Spark 1.6.3
#
install_spark() {
    print_banner "Install Spark 1.6.3"

    if [ ! -d spark-1.6.3-bin-hadoop2.6 ]; then
        if [ ! -e spark-1.6.3-bin-hadoop2.6.tgz ]; then
            wget https://archive.apache.org/dist/spark/spark-1.6.3/spark-1.6.3-bin-hadoop2.6.tgz
        fi
        tar xzf spark-1.6.3-bin-hadoop2.6.tgz
    fi

    sed -i "s@SPARK_HOME=TO-BE-COMPLETED@SPARK_HOME=${ROOT_DIR}/spark-1.6.3-bin-hadoop2.6@" $ENV_FILE

    # Configure Spark Server address in scripts
    sed -i "s@spark://.*:7077@spark://${SPARK_HOST}:7077@" $MYPIPELINE_HOME/my_scripts/mypipeline--start_spark_worker.bash
    sed -i "s@-i 127.0.0.1 -h 127.0.0.1@-i ${SPARK_HOST} -h ${SPARK_HOST}@" $MYPIPELINE_HOME/my_scripts/mypipeline--start_spark_master.bash
}

#
# Cassandra 3.11.1
#
install_cassandra() {
    print_banner "Install Cassandra"

    if [ ! -d apache-cassandra-3.11.1 ]; then
        if [ ! -e apache-cassandra-3.11.1-bin.tar.gz ] ; then
            wget http://archive.apache.org/dist/cassandra/3.11.1/apache-cassandra-3.11.1-bin.tar.gz
        fi
        tar xzf apache-cassandra-3.11.1-bin.tar.gz
    fi

    CASSANDRA_HOME=${ROOT_DIR}/apache-cassandra-3.11.1
    sed -i "s@CASSANDRA_HOME=TO-BE-COMPLETED@CASSANDRA_HOME=${CASSANDRA_HOME}@" $ENV_FILE

    # Change listen addresses
    sed -i "s@rpc_address: .*@rpc_address: ${CASSANDRA_HOST}@" ${CASSANDRA_HOME}/conf/cassandra.yaml
    sed -i "s@listen_address: .*@listen_address: ${CASSANDRA_HOST}@" ${CASSANDRA_HOME}/conf/cassandra.yaml
    sed -i "s@seeds: \".*\"@seeds: \"${CASSANDRA_HOST}\"@"  ${CASSANDRA_HOME}/conf/cassandra.yaml

    # Change jvm min/max heap size
    sed -i "s@#-Xms4G@-Xms500M@" ${CASSANDRA_HOME}/conf/jvm.options
    sed -i "s@#-Xmx4G@-Xmx500M@" ${CASSANDRA_HOME}/conf/jvm.options

    # Install cassandra python drivers
    if [ $DIST == "debian" ]; then
        $SUDO apt install python-pip
        $SUDO pip2 install --user cassandra-driver==3.12.0
    elif [ $DIST == "redhat" ]; then
        #easy_install-2.7 -U --user pip
        $SUDO yum install -y python2-pip
        pip2.7 install --user cassandra-driver==3.12.0
    else
        echo "ERROR: Unknown distribution: $DIST"
    fi

    # Allow Cassandra to be run as root (for docker) : add -R option
	if ! grep -q "cassandra -f -R" ${MYPIPELINE_HOME}/my_scripts/mypipeline--start_cassandra.bash; then
		sed -i "s@cassandra -f@cassandra -f -R@" ${MYPIPELINE_HOME}/my_scripts/mypipeline--start_cassandra.bash
	fi

    # Add cassandra address to cqlsh commands in cassandra script
	if ! grep -q ${CASSANDRA_HOST} ${MYPIPELINE_HOME}/my_scripts/mypipeline--delete_cassandra_tables.bash; then
       sed -i "s@\(cqlsh -e .*\)@\1 ${CASSANDRA_HOST}@" ${MYPIPELINE_HOME}/my_scripts/mypipeline--delete_cassandra_tables.bash
	fi
	if ! grep -q ${CASSANDRA_HOST} ${MYPIPELINE_HOME}/my_scripts/mypipeline--create_cassandra_tables.bash; then
       sed -i "s@\(cqlsh -e .*\)@\1 ${CASSANDRA_HOST}@" ${MYPIPELINE_HOME}/my_scripts/mypipeline--create_cassandra_tables.bash
	fi
	if ! grep -q ${CASSANDRA_HOST} ${MYPIPELINE_HOME}/my_scripts/mypipeline--query_cassandra.bash; then
	   sed -i "s@\(cqlsh -e .*\)@\1 ${CASSANDRA_HOST}@" ${MYPIPELINE_HOME}/my_scripts/mypipeline--query_cassandra.bash
	fi
}

start_cassandra() {
    print_banner "Start Cassandra"
    # Start Cassandra
    . ${MYPIPELINE_HOME}/environment.bash
    ${MYPIPELINE_HOME}/my_scripts/mypipeline--start_cassandra.bash

    # Create table
    $MYPIPELINE_HOME/my_scripts/mypipeline--delete_cassandra_tables.bash
    $MYPIPELINE_HOME/my_scripts/mypipeline--create_cassandra_tables.bash
}

#
# Feeder application
#
install_feeder() {
    print_banner "Build feeder application"

    # Configure feeder
    # Set Kafka brokers
    sed -i "s@kafkaHost = \"localhost:9092\"@kafkaHost = \"${KAFKA_BROKERS}\"@" ${MYPIPELINE_HOME}/feeder/src/main/resources/application.conf

    # IMPORTANT: Must be built once the configuration have been modified !!!
    # The configuration seems to be embedded in the jar file.
    # It is not read dynamicaly.
    # I lost a couple of hours trying to understand why it didn't work!
    if [ ! -e ${MYPIPELINE_HOME}/feeder/target/scala-2.10/feeder-assembly-1.0.jar ] ; then
      cd ${MYPIPELINE_HOME}
      sbt feeder/assembly
      cd ${ROOT_DIR}
    fi

    print_banner "Extract dataset"

    if [ ! -e ${MYPIPELINE_HOME}/datasets/dating/ratings.csv ] ; then
      bzip2 -d -k ${MYPIPELINE_HOME}/datasets/dating/ratings.csv.bz2
    fi

    # Change jvm min/max heap size
    # Edit ${MYPIPELINE_HOME}/my_scripts/mypipeline--start_feederapp.bash
    # Set java memory option: -Xmx300m
    sed -i "s@-Xmx1g@-Xmx300m@" ${MYPIPELINE_HOME}/my_scripts/mypipeline--start_feederapp.bash

    # Configure log4j or you may not see any error traces
    LOG4J_CONF=${MYPIPELINE_HOME}/log4j.properties
    cat > ${LOG4J_CONF} <<'EOT'
log4j.rootLogger=DEBUG, A1
log4j.appender.A1=org.apache.log4j.ConsoleAppender
log4j.appender.A1.layout=org.apache.log4j.PatternLayout
log4j.appender.A1.layout.ConversionPattern=%-4r [%t] %-5p %c %x - %m%n
log4j.logger.com.foo=WARN
EOT
    sed -i "s@java @java -Dlog4j.configuration=file://${LOG4J_CONF} @" ${MYPIPELINE_HOME}/my_scripts/mypipeline--start_feederapp.bash
}

start_feeder() {
    print_banner "Start feeder"

    . ${MYPIPELINE_HOME}/environment.bash
    cd ${MYPIPELINE_HOME}
    ${MYPIPELINE_HOME}/my_scripts/mypipeline--start_feederapp.bash
}

#
# Streaming application
#
install_streaming() {
    print_banner "Build streaming application"

    # Configure Cassandra host and Kafka brokers in sources
    SRC=${MYPIPELINE_HOME}/streaming/src/main/scala/com/bythebay/pipeline/spark/streaming/StreamingRatings.scala
    sed -i "s@\"spark.cassandra.connection.host\", \"127.0.0.1\"@\"spark.cassandra.connection.host\", \"${CASSANDRA_HOST}\"@" $SRC
    sed -i "s@brokers = \"localhost:9092,localhost:9093\"@brokers = \"${KAFKA_BROKERS}\"@" $SRC

    # Build application
    if [ ! -e ${MYPIPELINE_HOME}/streaming/target/scala-2.10/streaming-assembly-1.0.jar ] ; then
      cd ${MYPIPELINE_HOME}
      sbt streaming/assembly
      cd ${ROOT_DIR}
    fi

    # Configure Spark server
    sed -i "s@spark://127.0.0.1:7077@spark://${SPARK_HOST}:7077@" ${MYPIPELINE_HOME}/my_scripts/mypipeline--start_spark_streaming_ratingsapp.bash
}

start_streaming() {
    print_banner "Start streaming app"

    . ${MYPIPELINE_HOME}/environment.bash
    cd ${MYPIPELINE_HOME}
    ${MYPIPELINE_HOME}/my_scripts/mypipeline--start_spark_streaming_ratingsapp.bash
}

#
# Main
#

echo "[$0: $(date)]"

# Use sudo if current user is not root
if [ $USER = root ]; then
    SUDO="" # sudo
else
    SUDO=sudo
fi

# Check parameters
if [ -z ${ROOT_DIR} ] || [ -z ${NODE_TYPE} ]; then
    usage $0
    exit 1
fi

# Set proxy if needed
if [ "$PROXY" != "" ]; then
    export http_proxy=$PROXY
    export https_proxy=$PROXY
    if [ "$DIST" = "redhat" ]; then
        if ! grep -q "^proxy=" /etc/yum.conf ; then
            echo "proxy=$PROXY" >> /etc/yum.conf
        fi
    fi
fi

export LC_ALL=C
cd ${ROOT_DIR}

# Install requirements for all nodes
install_deps
install_mypipeline

if [ "$NODE_TYPE" == "zookeeper" ]; then
    install_zookeeper
elif [ "$NODE_TYPE" == "kafka" ]; then
    install_kafka $NODE_ID
elif [ "$NODE_TYPE" == "cassandra" ]; then
    install_cassandra
elif [ "$NODE_TYPE" == "feeder" ]; then
    install_scala
    install_sbt
    install_feeder
elif [ "$NODE_TYPE" == "streaming" ]; then
    install_scala
    install_sbt
    install_streaming
elif [ "$NODE_TYPE" == "spark" ]; then
    install_spark
elif [ "$NODE_TYPE" == "all" ]; then
    install_zookeeper
    install_kafka $NODE_ID
    install_cassandra
    install_spark
    install_scala
    install_sbt
    install_feeder
    install_streaming
fi

echo "[$0: $(date)]"
