FROM ubuntu:18.04

LABEL maintainer="a.badmaev@clicknet.pro"

# set timezone
ENV TZ=Europe/Moscow
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone


# install dependencies
RUN apt-get update && apt-get install -y \
    gawk wget git-core diffstat unzip texinfo gcc-multilib \
    build-essential chrpath socat cpio python3 python3-pip python3-pexpect \
    xz-utils debianutils iputils-ping python3-git python3-jinja2 libegl1-mesa libsdl1.2-dev \
    pylint3 xterm python3-distutils libyaml-dev libelf-dev curl locales


# symlink from python3 to python
RUN ln -s /usr/bin/python3 /usr/bin/python


# set locale for Bitbake
RUN locale-gen en_US.UTF-8 && update-locale
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8


# set user for Bitbake
RUN useradd -ms /bin/bash defuser
USER defuser
WORKDIR /home/defuser


# install repo tool and get source files
RUN mkdir -p ~/.bin && \
    PATH="${HOME}/.bin:${PATH}" && \
    curl https://storage.googleapis.com/git-repo-downloads/repo > ~/.bin/repo && \
    chmod a+rx ~/.bin/repo && \
    mkdir yocto-dev && cd yocto-dev && \
    repo init -u https://github.com/polarfire-soc/meta-polarfire-soc-yocto-bsp \
    -b d3b63021c3a521a3f08908d005e2df5d0d1ca8c9 -m tools/manifests/riscv-yocto.xml && \
    repo sync && \
    repo rebase


# add files for linux kernel upgrade to container
ADD ./kernel_update yocto-dev


# set your name and email for git
RUN git config --global user.email "a.badmaev@clicknet.pro" && \
    git config --global user.name "ananda"


# build image with upgraded kernel
RUN cd yocto-dev/meta-polarfire-soc-yocto-bsp && \
    # select needed commits 
    git checkout d3b63021c3a521a3f08908d005e2df5d0d1ca8c9 && cd .. && \
    cd meta-riscv/ && git checkout 6f495435ed9269030e16b9051b9012ce42038c04 && cd .. && \
    cd openembedded-core/ && git checkout 38e3d5bd3d05ed00a2fc55e3729cb8a6d4e4132f && cd .. && \
    cd openembedded-core/bitbake/ && git checkout 9a5dd1be63395c76d3fac2c3c7ba6557fe47b442 && cd ../.. && \
    cd meta-openembedded/ && git checkout f92b959f4a52ec7596aace92c8d37a370a132f30 && cd .. && \
    # changes for kernel upgrade
    mv 0001-V2-GPIO-Driver-updates.patch meta-polarfire-soc-yocto-bsp/recipes-kernel/linux/files && \
    rm openembedded-core/meta/classes/kernel.bbclass && \
    mv kernel.bbclass openembedded-core/meta/classes/ && \
    cd openembedded-core && git add -A && \
    git commit -m "kernel.bbclass" && cd .. && \
    rm meta-polarfire-soc-yocto-bsp/recipes-kernel/linux/mpfs-linux_5.%.bb && \
    mv mpfs-linux_5.%.bb meta-polarfire-soc-yocto-bsp/recipes-kernel/linux/ && \
    cd meta-polarfire-soc-yocto-bsp && git add -A && \
    git commit -m "GPIO driver patch and mpfs-linux" && cd .. && \
    # build image 
    . ./meta-polarfire-soc-yocto-bsp/polarfire-soc_yocto_setup.sh && \
    echo 'BB_NUMBER_THREADS = "4"' >> conf/local.conf && \
    MACHINE=icicle-kit-es-sd bitbake core-image-minimal-dev




