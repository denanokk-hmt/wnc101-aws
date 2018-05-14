 
FROM node:8.11.1
#FROM centos

#RUN yum install -y epel-release
#RUN yum install -y nodejs npm

ADD . /src
COPY package.json /src/package.json
RUN cd /src; npm install --save
RUN npm install pm2 -g

COPY . /src

#WORKDIR /src

EXPOSE 8080
CMD ["pm2-docker", "/src/bin/www"]

