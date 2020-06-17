# vim:set ft=dockerfile:
FROM centos:7

ARG MARIADB_ENTERPRISE_TOKEN

# Update System
RUN yum -y install epel-release && \
    yum -y upgrade

# Install Some Basic Dependencies
RUN yum -y install bind-utils \
    bc \
    boost \
    curl \
    expect \
    file \
    jemalloc \
    less \
    libaio \
    libcurl \
    libnl \
    libxml2 \
    locales \
    locales-all \
    lsof \
    monit \
    nano \
    net-tools \
    nmap \
    numactl-libs \
    openssh-clients \
    openssh-server \
    openssl \
    perl \
    perl-DBI \
    psmisc \
    python3 \
    rsync \
    rsyslog \
    snappy \
    sudo \
    sysvinit-tools \
    vim \
    wget \
    which \
    zlib && \
    yum clean all && \
    rm -rf /var/cache/yum

# Default env variables
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
ENV TINI_VERSION=v0.18.0

# Add Tini Init Process
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /usr/bin/tini

# Add MariaDB Enterprise Setup Script
ADD https://dlm.mariadb.com/enterprise-release-helpers/mariadb_es_repo_setup /tmp

RUN chmod +x /usr/bin/tini /tmp/mariadb_es_repo_setup && \
    /tmp/mariadb_es_repo_setup --token=${MARIADB_ENTERPRISE_TOKEN} --apply

# Install MariaDB/ColumnStore packages
RUN yum -y install MariaDB-server \
    MariaDB-columnstore-platform \
    MariaDB-columnstore-engine && \
    columnstore-post-install && \
    yum clean all && \
    rm -rf /var/cache/yum

# Copy Files To Image
COPY config/monit.d/ /etc/

COPY scripts/columnstore-restart \
     scripts/columnstore-init \
     scripts/columnstore-bootstrap /usr/bin/

# Set Permissions
RUN chmod +x /usr/bin/columnstore-bootstrap \
    /usr/bin/columnstore-init \
    /usr/bin/columnstore-restart

# Work Around For https://jira.mariadb.org/browse/MCOL-3830
RUN rm -rf /etc/systemd/system/mariadb.service.d \
    /usr/lib/systemd/system/mariadb.service \
    /usr/lib/systemd/system/mariadb@.service \
    /usr/share/mysql/systemd/mariadb.service \
    /usr/share/mysql/systemd/mariadb@.service

# Expose MariaDB Port
EXPOSE 3306

# Create Persistent Volumes
VOLUME ["/etc/columnstore", "/var/lib/columnstore", "/var/lib/mysql"]

# Copy Entrypoint To Image
COPY scripts/docker-entrypoint.sh /usr/bin/

# Make Entrypoint Executable & Create Legacy Symlink
RUN chmod +x /usr/bin/docker-entrypoint.sh && \
    ln -s /usr/bin/docker-entrypoint.sh /docker-entrypoint.sh

# Bootstrap
ENTRYPOINT ["/usr/bin/tini","--","docker-entrypoint.sh"]

CMD columnstore-bootstrap && monit -I
