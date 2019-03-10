FROM centos:latest
MAINTAINER benjamin thery

ENV project_dir /home/projet-mypipeline

# Uncomment if you're behind a proxy
#ENV proxy http://193.56.47.8:8080/
#RUN echo proxy=${proxy} >> /etc/yum.conf

RUN mkdir ${project_dir}
WORKDIR ${project_dir}

# Install sshd
RUN yum install -y openssh-server
RUN ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N ''
RUN ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key -N ''
RUN sed -i "s/#PermitRootLogin yes/PermitRootLogin yes/" /etc/ssh/sshd_config
RUN sed -i "s/#PubkeyAuthentication yes/PubkeyAuthentication yes/" /etc/ssh/sshd_config
RUN echo root:password | chpasswd
#EXPOSE 22
#CMD ["/usr/sbin/sshd", "-D"]

# Install tools and common dependencies
RUN yum install -y epel-release
RUN yum install -y iproute bash-completion screen vim wget bzip2 java-1.8.0-openjdk-headless

# Copy installation script
COPY mypipeline-install.sh ${project_dir}
COPY switch-proxy.sh ${project_dir}

# Copy tarball of all components and expand them
ADD *gz ${project_dir}/
RUN chown -R root:root ${project_dir}/MyPipeline
RUN chmod -R o-w ${project_dir}/MyPipeline

# Customize /root/.bashrc
RUN echo "cd ${project_dir}" >> /root/.bashrc

# Run installation
#RUN ${project_dir}/mypipeline-install.sh ${project_dir}

