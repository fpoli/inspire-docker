FROM ubuntu:14.04
MAINTAINER Federico Poli "federico.poli@cern.ch"


################
# Requirements #
################

RUN apt-get update

# Database
RUN apt-get install -y mariadb-server libmariadbclient-dev

# Webserver
RUN apt-get install -y \
    python-pip redis-server python-dev libssl-dev libxml2-dev libxslt-dev \
    gnuplot clisp automake pstotext gettext
RUN pip install invenio-devserver nose plumbum

# System
RUN apt-get install -y git unzip wget


###############
# Create user #
###############

RUN useradd --create-home --password docker docker
RUN echo "docker ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
ENV HOME /home/docker
USER docker


###################
# Install Invenio #
###################

# Preparing Invenio build folder
RUN git clone git@github.com:inveniosoftware/invenio.git /home/docker/invenio
WORKDIR /home/docker/invenio

# Installing Invenio requirements
RUN sudo pip install -r requirements.txt
#RUN sudo pip install -r requirements-extras.txt

# Building Invenio
RUN aclocal
RUN automake -a
RUN autoconf
RUN ./configure 
RUN make

# Preparing Invenio destination folders
RUN sudo mkdir -p /opt/invenio
RUN sudo chown docker:docker /opt/invenio
RUN sudo ln -s /opt/invenio/lib/python/invenio /usr/local/lib/python2.7/dist-packages/invenio

# Installing Invenio and plugins
RUN make install
RUN make install-jquery-plugins

# Configuration
ADD invenio-local.conf /opt/invenio/etc/invenio-local.conf
RUN /opt/invenio/bin/inveniocfg --update-all
RUN /opt/invenio/bin/inveniocfg --load-bibfield-conf


###################
# Create Database #
###################

ADD services.sh /home/docker/services.sh
RUN sudo chmod +x /home/docker/services.sh

ENV CFG_INSPIRE_BIBTASK_USER admin

RUN sudo /home/docker/services.sh start && \
        mysql -u root -e "CREATE DATABASE IF NOT EXISTS invenio DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci" && \
        mysql -u root -e "GRANT ALL PRIVILEGES ON invenio.* TO invenio@localhost IDENTIFIED BY 'my123p\$ss'" && \
        /opt/invenio/bin/inveniocfg --create-tables && \

        /opt/invenio/bin/inveniocfg --create-demo-site && \
        /opt/invenio/bin/inveniocfg --load-demo-records && \
    sudo /home/docker/services.sh stop


###########
# Startup #
###########

ADD startup.sh /home/docker/startup.sh
RUN sudo chmod +x /home/docker/startup.sh

WORKDIR /home/docker
EXPOSE :4000
ENTRYPOINT ["/home/docker/startup.sh"]
CMD ["serve", "-b", "0.0.0.0"]
