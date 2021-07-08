ARG QT_VERSION=5.15.2

# QT Installation Image --------------------------------------------------------
FROM ubuntu:18.04 AS qt-install

ARG QT_VERSION

RUN apt update && apt full-upgrade -y && apt install -y --no-install-recommends \
    sudo python3 python3-pip \
    && apt-get -qq clean

RUN python3 -m pip install setuptools

RUN chmod -R 777 /opt

RUN groupadd -r user && useradd --create-home --gid user user && echo 'user ALL=NOPASSWD: ALL' > /etc/sudoers.d/user


COPY scripts/install-qt.sh /home/user/
RUN chown user:user /home/user/install-qt.sh
RUN chmod a+x /home/user/install-qt.sh

USER user
WORKDIR /home/user

ENV HOME /home/user
ENV QT_VERSION=$QT_VERSION

# Install QT
RUN /home/user/install-qt.sh



# Build Image ------------------------------------------------------------------
FROM ubuntu:18.04

ARG OPENSSL_VERSION=1.1.1d
ARG LINUXDEPLOYQT_VERSION=continuous
ARG QT_VERSION


# Adapted from a12e/docker-qt by Aurélien Brooke

ENV DEBIAN_FRONTEND=noninteractive \
    OPENSSL_PREFIX=/usr/local/ssl \
    QMAKESPEC=linux-g++ \
    QT_PATH=/opt/qt \
    QT_PLATFORM=gcc_64 \
    QT_VERSION=$QT_VERSION

ENV \
    PATH=${QT_PATH}/${QT_VERSION}/${QT_PLATFORM}/bin:${OPENSSL_PREFIX}/bin:$PATH


RUN apt update -yq && apt install -yq software-properties-common \
&& add-apt-repository -y ppa:git-core/ppa \
 && apt update -yq && apt full-upgrade -yq && apt install -yq --no-install-recommends --fix-missing  \
    git \
    openssh-client \
    ca-certificates \
    locales \
    sudo \
    curl \
    build-essential \
    pkg-config \
    libgl1-mesa-dev \
    libsm6 \
    libice6 \
    libxext6 \
    libxrender1 \
    libfontconfig1 \
    libdbus-1-3 \
    libz-dev \
    fuse \
    file \
    libxkbcommon-x11-0 \
    wget \
    make libssl-dev zlib1g-dev \
    libbz2-dev libreadline-dev libsqlite3-dev llvm \
    libncurses5-dev libncursesw5-dev xz-utils tk-dev \
    libgstreamer-plugins-base1.0-0 \
    cmake s3cmd libpcre3-dev libnss3 libxcomposite1 libxtst6 jq \
    gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \ 
    gstreamer1.0-libav gstreamer1.0-tools gstreamer1.0-alsa libpulse-mainloop-glib0 \
    gstreamer1.0-pulseaudio libxrandr2 libxcursor1 libxi6 libxcb-icccm4 libxcb-image0 \
    libxcb-keysyms1 libxcb-render-util0 libxcb-render0 libxcb-xinerama0 \
    && apt-get -qq clean

COPY scripts/* /tmp/build/

# Download and install OpenSSL
RUN /tmp/build/install-openssl-linux.sh

# Download & install linuxdeployqt
RUN /tmp/build/install-linuxdeployqt.sh

# Reconfigure locale
RUN locale-gen en_US.UTF-8 && dpkg-reconfigure locales \
# Add group & user
    && groupadd -r user && useradd --create-home --gid user user && echo 'user ALL=NOPASSWD: ALL' > /etc/sudoers.d/user

# Copy QT toolchain
RUN chmod -R 777 /opt && mkdir -p /opt/qt/$QT_VERSION
COPY --from=qt-install /home/user/$QT_VERSION /opt/qt/$QT_VERSION/.

USER user
WORKDIR /home/user
ENV HOME /home/user



# $QT_PATH/$QT_VERSION/$QT_PLATFORM/bin is already prepended to $PATH
ENV QTDIR="${QT_PATH}/${QT_VERSION}/${QT_PLATFORM}"
ENV LD_LIBRARY_PATH="${QTDIR}/lib:${LD_LIBRARY_PATH}"
# $OPENSSL_PREFIX is provided by the docker image
ENV LIBRARY_PATH="${OPENSSL_PREFIX}/lib:${LIBRARY_PATH}"


# Installing Golang
RUN GOLANG_SHA256="aed845e4185a0b2a3c3d5e1d0a35491702c55889192bb9c30e67a3de6849c067" \
 && GOLANG_TARBALL="go1.14.4.linux-amd64.tar.gz" \
 && curl -L "https://dl.google.com/go/${GOLANG_TARBALL}" --output $GOLANG_TARBALL \
 && echo "${GOLANG_SHA256} ${GOLANG_TARBALL}" | sha256sum -c \
 && sudo tar -C /usr/local -xzf "${GOLANG_TARBALL}" \
 && rm "${GOLANG_TARBALL}" \
 && sudo ln -s /usr/local/go/bin/go /usr/local/bin

# Jenkins user needs a specific UID/GID to work
RUN sudo groupadd -g 1001 jenkins \
 && sudo useradd --create-home -u 1001 -g 1001 jenkins
USER jenkins
ENV HOME="/home/jenkins"

LABEL maintainer="jakub@status.im"
LABEL source="https://github.com/status-im/nim-status-client"
LABEL description="Build image for the Status Desktop client written in Nim."
