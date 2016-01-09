FROM ubuntu:15.10

# Enable multiverse
RUN sed -i "/^# deb .* multiverse$/ s/^# //" /etc/apt/sources.list

## some of this was merged from ubuntu_with_opensource_drivers - for simplicity here

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    apt-src \
    autoconf \
    automake \
    bash-completion \
    build-essential \
    command-not-found \
    cpp \
    devscripts \
    expect \
    freeglut3-dev \
    g++ \
    gcc \
    git-core \
    libc6-dev \
    libfreetype6-dev \
    libglu1-mesa-dev \
    libpixman-1-dev \
    libpng-dev \
    librsvg2-dev \
    make \
    man-db \
    mesa-common-dev \
    mesa-utils \
    nano \
    pkg-config \
    vim \
    wget \
    xserver-xorg-video-all

RUN adduser --disabled-password --gecos '' devel && adduser devel sudo && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers;

USER devel



### get sources ###

# grab cairo gl smoke tests (can build and run these if successful)
RUN git clone https://github.com/mrobinson/cairo-gl-smoke-tests.git /home/devel/cairo-gl-smoke-tests

# grab cairo src
RUN mkdir ~/src
RUN cd ~/src && sudo apt-src install cairo
RUN sudo chown devel -R ~/src/cairo*

RUN cd ~/src/cairo* && ln $PWD ../cairo -s

# Make a copy so we can check any differences when debugging issues
RUN mkdir ~/src/cairo-untouched
RUN cp -Rp ~/src/cairo/* ~/src/cairo-untouched


### configure and build ###

# ENV DEB_BUILD_OPTIONS=parallel=4
# Build without changes to check everything works
# https://wiki.debian.org/BuildingTutorial#Rebuild_without_changes
RUN cd ~/src/cairo && debuild -b -uc -us

#     Install these ^^^ - to make sure everything worked.
RUN cd ~/src && sudo dpkg -i *cairo*.deb

# Change --disable-gl to --enable-gl in debian/rules
RUN cd ~/src/cairo && \
    sed -e 's/--disable-gl/--enable-gl/' debian/rules > /tmp/rules && mv /tmp/rules debian/rules

RUN cd ~/src/cairo && grep able-gl ~/src/cairo/debian/rules

# Use expect script to add the patch to dpkg-source
ENV EDITOR=/usr/bin/vim.basic
ADD scripts/dpkg-source-commit.expect /home/devel/scripts/dpkg-source-commit.expect
RUN cd ~/src/cairo && expect -f /home/devel/scripts/dpkg-source-commit.expect

# Add libgl1-mesa-dev to debian/control
ADD scripts/add-gl-dep.diff /home/devel/scripts/add-gl-dep.diff
RUN cd ~/src/cairo/debian && patch < ~/scripts/add-gl-dep.diff

# Rebuild so symbol differences can be found
RUN cd ~/src/cairo && debuild -b -uc -us -tc 2>&1 | tee /tmp/debuild.log

# Generate and patch symbols
RUN cd ~/src/cairo && awk '/dpkg-gensymbols/{f=1;next} /dh_/{f=0} f' /tmp/debuild.log > /tmp/enable_gl-symbols.diff
RUN cd ~/src/cairo && cat /tmp/enable_gl-symbols.diff
RUN cd ~/src/cairo && patch debian/libcairo2.symbols < /tmp/enable_gl-symbols.diff


# Rebuild final time!
# TODO - None of this is signed as this is in build phase of Docker
RUN cd ~/src/cairo && debuild -b -uc -us

#  Install these ^^^:
RUN cd ~/src && sudo dpkg -i *cairo*.deb

# If cairo-gl built successfully, smoke tests will build
RUN cd ~/cairo-gl-smoke-tests && make

WORKDIR /home/devel/src/cairo
CMD bash
