 
FROM node:8.11.1
#FROM centos

#RUN yum install -y epel-release
#RUN yum install -y nodejs npm
#
#ADD . /src
#COPY package.json /src/package.json
#RUN cd /src; npm install --save --no-audit
#RUN npm install pm2 -g
#COPY . /src
#
#EXPOSE 8080
#CMD ["pm2-docker", "/src/bin/www"]

#####################################

#RUN adduser dev
RUN useradd -ms /bin/bash dev
RUN usermod -aG root dev

#ENV HOME /home/dev
#WORKDIR /home/dev
#USER dev

ADD . /home/dev
COPY package.json /home/dev/package.json
RUN cd /home/dev; npm install --save --no-audit
RUN npm install pm2 -g
COPY . /home/dev

#RUN chmod 777 /src/logs
#RUN mkdir /usr/local/var
#RUN mkdir /usr/local/var/log

EXPOSE 8080
CMD ["pm2-docker", "/home/dev/bin/www"]

