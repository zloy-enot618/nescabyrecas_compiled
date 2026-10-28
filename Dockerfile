FROM ubuntu:14.04

ENV DEBIAN_FRONTEND=noninteractive
ENV QT_PATH=/opt/Qt
ENV QT_DESKTOP=$QT_PATH/5.4/gcc_64
ENV PATH=$QT_DESKTOP/bin:$PATH

# 1. Форсируем IPv4 (чтобы apt не зависал)
RUN echo "Acquire::ForceIPv4 \"true\";" > /etc/apt/apt.conf.d/99force-ipv4

# 2. ПОЛНАЯ ЗАМЕНА sources.list на рабочее зеркало Aliyun (Trusty EOL)
#    Это решает проблему 404, так как здесь есть и бинарные пакеты, и исходники.
RUN echo "deb https://mirrors.aliyun.com/ubuntu/ trusty main restricted universe multiverse" > /etc/apt/sources.list && \
    echo "deb-src https://mirrors.aliyun.com/ubuntu/ trusty main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb https://mirrors.aliyun.com/ubuntu/ trusty-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb-src https://mirrors.aliyun.com/ubuntu/ trusty-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb https://mirrors.aliyun.com/ubuntu/ trusty-security main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb-src https://mirrors.aliyun.com/ubuntu/ trusty-security main restricted universe multiverse" >> /etc/apt/sources.list

# 3. Установка базовых зависимостей (с флагом для старых Release-файлов)
RUN apt-get update -o Acquire::Check-Valid-Until=false && \
    apt-get install -y --no-install-recommends \
    git wget make curl openssh-client ca-certificates p7zip \
    build-essential pkg-config libgl1-mesa-dev libsm6 libssh-dev \
    libice6 libxext6 libxrender1 libfontconfig1 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 4. Обновление curl
RUN apt-get update -o Acquire::Check-Valid-Until=false && \
    apt-get build-dep -y curl && \
    wget -q --retry-connrefused --tries=3 https://curl.se/download/curl-7.50.2.tar.bz2 && \
    tar -xvjf curl-7.50.2.tar.bz2 && cd curl-7.50.2 && \
    ./configure && make -j$(nproc) && make install && \
    cd .. && rm -rf curl-7.50.2*

# 5. Установка Qt 5.4.2 (зеркало Беркли)
RUN mkdir -p /tmp/qt && \
    curl -fL --retry 3 -o /tmp/qt/installer.run 'https://mirrors.ocf.berkeley.edu/qt/archive/qt/5.4/5.4.2/qt-opensource-linux-x64-5.4.2.run' && \
    chmod 755 /tmp/qt/installer.run && /tmp/qt/installer.run --dump-binary-data -o /tmp/qt/data && \
    mkdir $QT_PATH && cd $QT_PATH && \
    7zr x /tmp/qt/data/qt.54.gcc_64/5.4.2-0qt5_essentials.7z > /dev/null && \
    7zr x /tmp/qt/data/qt.54.gcc_64/5.4.2-0qt5_addons.7z > /dev/null && \
    7zr x /tmp/qt/data/qt.54.gcc_64/5.4.2-0icu_53_1_ubuntu_11_10_64.7z > /dev/null && \
    /tmp/qt/installer.run --runoperation QtPatch linux $QT_DESKTOP qt5 && \
    rm -rf /tmp/qt

# 6. Мультимедиа зависимости
RUN apt-get update -o Acquire::Check-Valid-Until=false && \
    apt-get install -y --no-install-recommends qtmultimedia5-dev && \
    rm -rf /var/lib/apt/lists/*

# 7. Клонирование и компиляция Nesca
RUN cd /tmp && git clone https://github.com/pantyusha/nesca.git && \
    cd /tmp/nesca && qmake && make -j$(nproc)

# 8. Подготовка пользователя и финальный образ
RUN groupadd -r user && useradd --create-home --gid user user && \
    echo 'user ALL=NOPASSWD: ALL' > /etc/sudoers.d/user && \
    mv /tmp/nesca /home/user/

USER user
WORKDIR /home/user/nesca
ENV HOME=/home/user
