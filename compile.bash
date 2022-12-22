#!/bin/bash
# Icinga 2 Docker image | (c) 2020 Icinga GmbH | GPLv2+
set -exo pipefail

export PATH="/usr/lib/ccache:$PATH"
ccache -z

mkdir icinga2-bin
mkdir build
cd build

cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_SYSCONFDIR=/etc \
	-DCMAKE_INSTALL_LOCALSTATEDIR=/var -DICINGA2_RUNDIR=/run -DICINGA2_LTO_BUILD=ON \
	-DICINGA2_SYSCONFIGFILE=/etc/sysconfig/icinga2 -DICINGA2_WITH_{COMPAT,LIVESTATUS}=OFF ..

make
make test

make install "DESTDIR=$(pwd)/../icinga2-bin"
strip -g ../icinga2-bin/usr/lib/*/icinga2/sbin/icinga2

cd ..

rm icinga2-bin/etc/icinga2/features-enabled/mainlog.conf

ccache -s
