FROM openjdk:8-alpine

# Setup useful environment variables
ENV CONF_HOME     /var/atlassian/confluence
ENV CONF_INSTALL  /opt/atlassian/confluence
ENV CONF_VERSION  6.10.1

ENV JAVA_CACERTS  $JAVA_HOME/jre/lib/security/cacerts
ENV CERTIFICATE   $CONF_HOME/certificate

ENV TZ			  CET-2CEDT-2

# Install Atlassian Confluence and helper tools and setup initial home
# directory structure.
RUN set -x \
	&& echo ${TZ} > /etc/TZ \
	&& apk update \
    && apk --no-cache add curl xmlstarlet bash ttf-dejavu libc6-compat apr-util apr-dev openssl openssl-dev gcc musl-dev make \
    && mkdir -p                "${CONF_HOME}" \
    && mkdir -p                "${CONF_INSTALL}/conf" \
    && curl -Ls                "https://www.atlassian.com/software/confluence/downloads/binary/atlassian-confluence-${CONF_VERSION}.tar.gz" | tar -xz --directory "${CONF_INSTALL}" --strip-components=1 --no-same-owner \
    && curl -Ls                "https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.44.tar.gz" | tar -xz --directory "${CONF_INSTALL}/confluence/WEB-INF/lib" --strip-components=1 --no-same-owner "mysql-connector-java-5.1.44/mysql-connector-java-5.1.44-bin.jar" \
    && echo -e                 "\nconfluence.home=$CONF_HOME" >> "${CONF_INSTALL}/confluence/WEB-INF/classes/confluence-init.properties" \
    && xmlstarlet              ed --inplace \
        --delete               "Server/@debug" \
        --delete               "Server/Service/Connector/@debug" \
        --delete               "Server/Service/Connector/@useURIValidationHack" \
        --delete               "Server/Service/Connector/@minProcessors" \
        --delete               "Server/Service/Connector/@maxProcessors" \
        --delete               "Server/Service/Engine/@debug" \
        --delete               "Server/Service/Engine/Host/@debug" \
        --delete               "Server/Service/Engine/Host/Context/@debug" \
                               "${CONF_INSTALL}/conf/server.xml" \
    && touch -d "@0"           "${CONF_INSTALL}/conf/server.xml" \
    && tar -xzvf ${CONF_INSTALL}/bin/tomcat-native.tar.gz -C /tmp \
    && cd /tmp/tomcat-native-1.2.16-src/native && ./configure --with-apr=/usr/bin/apr-1-config --with-java-home=/usr/lib/jvm/java-1.8-openjdk --with-ssl=yes --prefix=/usr && make && make install \
    && rm -r -f /tmp/tomcat-native-1.2.16-src \
    && apk del apr-dev openssl-dev gcc musl-dev make

# Use the default unprivileged account. This could be considered bad practice
# on systems where multiple processes end up being executed by 'daemon' but
# here we only ever run one process anyway.
RUN set -x \
	&& adduser -D -G root -g "ROS User" rosuser \
    && chmod -R 770           "${CONF_HOME}" \
    && chown -R rosuser:root  "${CONF_HOME}" \
    && chmod -R 770            "${CONF_INSTALL}/conf" \
    && chmod -R 770            "${CONF_INSTALL}/logs" \
    && chmod -R 770            "${CONF_INSTALL}/temp" \
    && chmod -R 770            "${CONF_INSTALL}/work" \
    && chown -R rosuser:root  "${CONF_INSTALL}/conf" \
    && chown -R rosuser:root  "${CONF_INSTALL}/logs" \
    && chown -R rosuser:root  "${CONF_INSTALL}/temp" \
    && chown -R rosuser:root  "${CONF_INSTALL}/work" \
    && chown rosuser:root     "${JAVA_CACERTS}"

USER rosuser

# Expose default HTTP connector port.
EXPOSE 8090 8091

# Set volume mount points for installation and home directory. Changes to the
# home directory needs to be persisted as well as parts of the installation
# directory due to eg. logs.
VOLUME ["/var/atlassian/confluence", "/var/atlassian/confluence/caches/indexes", "/opt/atlassian/confluence/logs"]

# Set the default working directory as the Confluence home directory.
WORKDIR /var/atlassian/confluence

COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]

# Run Atlassian Confluence as a foreground process by default.
CMD ["/opt/atlassian/confluence/bin/start-confluence.sh", "-fg"]
