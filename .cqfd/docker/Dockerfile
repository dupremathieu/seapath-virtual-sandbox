# Copyright (C) 2026, Savoir-faire Linux
# SPDX-License-Identifier: Apache-2.0

FROM debian:12

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

ARG TERRAFORM_VERSION=1.9.8

RUN set -x \
    && apt-get update \
    && apt-get install -y \
        ca-certificates \
        curl \
        git \
        gnupg \
        libvirt-clients \
        locales \
        openssh-client \
        python3-full \
        python3-libvirt \
        rsync \
        unzip \
        vim \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen \
    && curl -fsSLo /tmp/terraform.zip \
        "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
    && unzip /tmp/terraform.zip -d /usr/local/bin/ \
    && rm /tmp/terraform.zip \
    && python3 -m venv --system-site-packages /env \
    && /env/bin/pip install \
        ansible-core~=2.16.0 \
        ansible-lint \
        yamllint \
        six \
        netaddr \
        jmespath \
        libvirt-python \
    && rm -rf /var/lib/{apt,dpkg,cache,log}/*

ENV PATH="/env/bin:$PATH"
