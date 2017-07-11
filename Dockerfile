FROM alpine:3.4
LABEL maintainer "Unified Streaming <support@unified-streaming.com>"

########## ORIGIN RELATED INSTALLATION ###########

RUN apk --update add apache2 \
 && rm -f /var/cache/apk/*

RUN wget -q -O /etc/apk/keys/alpine@unified-streaming.com.rsa.pub \
  http://apk.unified-streaming.com/alpine@unified-streaming.com.rsa.pub

RUN apk --update \
        --repository http://apk.unified-streaming.com/repo \
        add \
          mp4split \
          mod_smooth_streaming \
 && rm -f /var/cache/apk/*

RUN mkdir -p /run/apache2 \
 && ln -s /dev/stderr /var/log/apache2/error.log \
 && ln -s /dev/stdout /var/log/apache2/access.log \
 && mkdir -p /var/www/unified-origin

COPY unified-origin.conf.in /etc/apache2/conf.d/unified-origin.conf.in
COPY s3_auth.conf.in /etc/apache2/conf.d/s3_auth.conf.in
COPY remote_storage.conf.in /etc/apache2/conf.d/remote_storage.conf.in
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY index.html /var/www/unified-origin/index.html
COPY clientaccesspolicy.xml /var/www/unified-origin/clientaccesspolicy.xml
COPY crossdomain.xml /var/www/unified-origin/crossdomain.xml

########## END ORIGIN RELATED INSTALLATION ########

########## SNAP RELATED INSTALLATION ##############

ARG SNAP_VERSION=latest

ENV SNAP_VERSION=${SNAP_VERSION}
ENV SNAP_TRUST_LEVEL=0
ENV SNAP_LOG_LEVEL=0
ENV CI_URL=https://s3-us-west-2.amazonaws.com/snap.ci.snap-telemetry.io
ENV SNAP_URL="http://127.0.0.1:8181"
ENV SNAP_GITHUB_URL="https://raw.githubusercontent.com/intelsdi-x/snap-docker/master"

ADD ${CI_URL}/snap/${SNAP_VERSION}/linux/x86_64/snapteld /opt/snap/sbin/snapteld
ADD ${CI_URL}/snap/${SNAP_VERSION}/linux/x86_64/snaptel /opt/snap/bin/snaptel
ADD ${SNAP_GITHUB_URL}/init_snap /usr/local/bin/init_snap

COPY snapteld.conf /etc/snap/snapteld.conf

# set environment variable
ENV PATH /opt/snap/sbin:$PATH
ENV PATH /opt/snap/bin:$PATH

# Download the necessary plugin : psutil, apache, influxdb
# Create the directory for plugin first
RUN mkdir -p /opt/snap/plugins \
	/opt/snap/tasks \
	/var/log/snap

# Download the plugins
ENV OS=linux
ENV ARCH=x86_64
ADD https://github.com/intelsdi-x/snap-plugin-collector-psutil/releases/download/10/snap-plugin-collector-psutil_${OS}_${ARCH} \
	/opt/snap/plugins/snap-plugin-collector-psutil
ADD https://github.com/intelsdi-x/snap-plugin-collector-apache/releases/download/5/snap-plugin-collector-apache_${OS}_${ARCH} \ 
	/opt/snap/plugins/snap-plugin-collector-apache
ADD https://github.com/intelsdi-x/snap-plugin-publisher-influxdb/releases/download/22/snap-plugin-publisher-influxdb_${OS}_${ARCH} \
	/opt/snap/plugins/snap-plugin-publisher-influxdb

# Copy task
COPY apache-task.yaml /opt/snap/tasks

# Make necessary files to be executable
RUN chmod +x /opt/snap/plugins/snap-plugin-collector-psutil
RUN chmod +x /opt/snap/plugins/snap-plugin-collector-apache
RUN chmod +x /opt/snap/plugins/snap-plugin-publisher-influxdb
RUN chmod +x /usr/local/bin/entrypoint.sh
RUN chmod +x /opt/snap/sbin/snapteld
RUN chmod +x /opt/snap/bin/snaptel
RUN chmod +x /usr/local/bin/init_snap

########## END  RELATED INSTALLATION ##############

####### SUPERVISORD RELATED INSTALLATION ##########

ENV PYTHON_VERSION=2.7.12-r0
ENV PY_PIP_VERSION=8.1.2-r0
ENV SUPERVISOR_VERSION=3.3.1

RUN apk update && apk add -u python=$PYTHON_VERSION py-pip=$PY_PIP_VERSION
RUN pip install supervisor==$SUPERVISOR_VERSION

COPY supervisord.conf /etc/supervisord.conf
RUN mkdir -p /var/log/supervisor

###### END SUPERVISORD RELATED INSTALLATION ########

EXPOSE 80
EXPOSE 8181

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

#CMD ["-D", "FOREGROUND"]
CMD ["--nodaemon", "--configuration", "/etc/supervisord.conf"]