# This image is the base image for all OpenShift v3 language container images.
FROM centos/s2i-core-centos7:1

ENV SUMMARY="Base python 3.6 image with essential libraries and tools used as a base for \
python applications." \
    DESCRIPTION="The s2i-python36 image, being built upon s2i-core, provides any \
images layered on top of it with all the tools needed to use source-to-image \
functionality." \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 

LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="s2i py36" \
      com.redhat.component="s2i-py368-container" \
      name="irfius/s2i-py368-centos7" \
      version="1" \
      maintainer="Irfius <irfius@tuta.io>" \
      io.openshift.s2i.scripts-url="image:///usr/libexec/s2i"

COPY ./s2i/bin/ $STI_SCRIPTS_PATH

# This is the list of basic dependencies that all language container image can
# consume.
RUN rpm --import http://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7 && \
    yum -y install --setopt=tsflags=nodocs epel-release && \
    yum -y update && \
    INSTALL_PKGS="python36 python36-pip python36-devel" && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    yum -y clean all --enablerepo='*' && \
    chown -R 0:0 /opt/* && \
    pip3 install -U pip

CMD ["/usr/libexec/s2i/usage"]