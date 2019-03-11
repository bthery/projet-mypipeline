Projet Mypipeline
==================

MS Big Data 2018-2019 : Projet Systèmes Distribuées

Sources
-------

* [mypipeline-docker.sh](mypipeline-docker.sh)
    * Script for creating docker image deploying dockers

* [mypipeline-download.sh](mypipeline-download.sh)
    * Script for downloading archives for all components of the application

* [mypipeline-hosts](mypipeline-hosts)
    * File listing all hostnames and IP addresses used by the dockers

* [mypipeline-start-app.txt](mypipeline-start-app.txt)
    * File describing all the steps to execute to start the distributed MyPipeline application

* [mypipeline-fault-tolerant-kafka.txt](mypipeline-fault-tolerant-kafka.txt)
    * File describing the additional steps to execute to start the MyPipeline application with fault-toletant Kafka cluster

* [mypipeline-docker/Dockerfile](mypipeline-docker/Dockerfile)
    * Description file used to build the base docker image for the application nodes

* [mypipeline-docker/mypipeline-install.sh](mypipeline-docker/mypipeline-install.sh)
    * Script for configuring all the services. This is the script that will configure every components used by the application so they can communicate with each other in the cluster.

*  [mypipeline-docker/switch-proxy.sh](mypipeline-docker/switch-proxy.sh)
    * Helper script to switch web proxy on or off if needed

