# This image is the base image for all OpenShift v3 language container images.
FROM centos/s2i-core-centos7:1

ENV SUMMARY="Base python 3.6 image with essential libraries and tools used as a base for \
python applications." \
    DESCRIPTION="The s2i-python36 image, being built upon s2i-core, provides any \
images layered on top of it with all the tools needed to use source-to-image \
functionality."

LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="s2i py36" \
      com.redhat.component="s2i-py36-container" \
      name="irfius/s2i-py36-centos7" \
      version="1" \
      maintainer="Irfius <irfius@tuta.io>"

# This is the list of basic dependencies that all language container image can
# consume.
RUN yum -y update && \
    yum install -y centos-release-scl epel-release && \
    yum -y update && \
    INSTALL_PKGS="python36 python36-pip python36-devel" && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    yum -y clean all --enablerepo='*' && \
    chown -R 0:0 /opt/* && \
    pip3 install -U pip