FROM ubuntu:bionic
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y python3.8 && \
    apt-get install -y \
      qemu-kvm \
      libvirt-bin \
      python-libvirt \
      gir1.2-libvirt-glib-1.0 \
      gir1.2-libosinfo-1.0 \
      python-ipaddr \
      python3-yaml \
      libosinfo-1.0-0 \
      intltool \
      itstool \
      gir1.2-gtksource-3.0 \
      libxml2-utils \
      python-gi \
      python3-libvirt \
      python3-libxml2 \
      curl \
      wget \
      apt-transport-https \
      nano \
      openssh-client \
      cpio \
      python3-pip && \
    ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
    apt-get -qq install -y \
      locales \
      tzdata && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -m 700 ~/.ssh && \
    python3 -m pip install requests

COPY . /guest-builder
WORKDIR /guest-builder
CMD ["tail", "-f", "/dev/null"]
