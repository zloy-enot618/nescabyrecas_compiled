# Бронебойный Dockerfile для сборки Nesca
FROM ubuntu:14.04

ENV DEBIAN_FRONTEND=noninteractive
ENV QT_PATH=/opt/Qt
ENV QT_DESKTOP=$QT_PATH/5.4/gcc_64
ENV PATH=$QT_DESKTOP/bin:$PATH

# 1. Форсируем IPv4 (чтобы apt не зависал на старых серверах)
RUN echo "Acquire::ForceIPv4 \"true\";" > /etc/apt/apt.conf.d/99force-ipv4

# 2. Переводим репозитории на архивные и включаем исходники (deb-src)
RUN sed -i 's/archive.ubuntu.com/old-releases.ubuntu.com/g' /etc/apt/sources.list \
    && sed -i 's/security.ubuntu.com/old-releases.ubuntu.com/g' /etc/apt/sources.list \
    && sed -i 's/^# deb-src /deb-src /g' /etc/apt/sources.list

# 3. Ставим базовые зависимости (без dist-upgrade и без -qq, чтобы видеть прогресс)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    wget \
    make \
    curl \
    openssh-client \
    ca-certificates \
    p7zip \
    build-essential \
    pkg-config \
    libgl1-mesa-dev \
    libsm6 \
    libssh-dev \
    libice6 \
    libxext6 \
    libxrender1 \
    libfontconfig1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 4. Обновляем curl (починена ссылка на curl.se, добавлен --retry)
RUN apt-get update \
    && apt-get build-dep -y curl \
    && wget -q --retry-connrefused --tries=3 https://curl.se/download/curl-7.50.2.tar.bz2 \
    && tar -xvjf curl-7.50.2.tar.bz2 \
    && cd curl-7.50.2 \
    && ./configure \
    && make -j$(nproc) \
    && make install \
    && cd .. && rm -rf curl-7.50.2*

# 5. Качаем и ставим Qt 5.4.2 (используем надежное зеркало, добавлен --retry)
RUN mkdir -p /tmp/qt \
    && curl -fL --retry 3 -o /tmp/qt/installer.run 'https://mirrors.ocf.berkeley.edu/qt/archive/qt/5.4/5.4.2/qt-opensource-linux-x64-5.4.2.run' \
    && chmod 755 /tmp/qt/installer.run && /tmp/qt/installer.run --dump-binary-data -o /tmp/qt/data \
    && mkdir $QT_PATH && cd $QT_PATH \
    && 7zr x /tmp/qt/data/qt.54.gcc_64/5.4.2-0qt5_essentials.7z > /dev/null \
    && 7zr x /tmp/qt/data/qt.54.gcc_64/5.4.2-0qt5_addons.7z > /dev/null \
    && 7zr x /tmp/qt/data/qt.54.gcc_64/5.4.2-0icu_53_1_ubuntu_11_10_64.7z > /dev/null \
    && /tmp/qt/installer.run --runoperation QtPatch linux $QT_DESKTOP qt5 \
    && rm -rf /tmp/qt

# 6. Мультимедиа зависимости для Qt
RUN apt-get install -y --no-install-recommends qtmultimedia5-dev \
    && rm -rf /var/lib/apt/lists/*

# 7. Клонируем исходники Nesca
RUN cd /tmp && git clone https://github.com/pantyusha/nesca.git

# 8. Компилируем (используем все ядра)
RUN cd /tmp/nesca && qmake && make -j$(nproc)

# 9. Создаем юзера
RUN groupadd -r user && useradd --create-home --gid user user \
    && echo 'user ALL=NOPASSWD: ALL' > /etc/sudoers.d/user \
    && mv /tmp/nesca /home/user/

USER user
WORKDIR /home/user/nesca
ENV HOME=/home/user
