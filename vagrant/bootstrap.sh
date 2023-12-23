#!/bin/bash
set -eu -o pipefail

# nodejs source for apt
curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -

add-apt-repository ppa:openjdk-r/ppa
apt-get update
packages=(
    parallel       # utility
    unzip          # tessera startup script dependency
    openjdk-11-jdk     # tessera runtime dependency
    libleveldb-dev # constellation dependency
    libsodium-dev  # constellation dependency
    nodejs         # cakeshop dependency
)
apt-get install -y ${packages[@]}

CVER="0.3.2"
CREL="constellation-$CVER-ubuntu1604"
CONSTELLATION_OUTPUT_FILE="constellation.tar.xz"
POROSITY_OUTPUT_FILE="/usr/local/bin/porosity"

SOLC_VER="0.5.5"
SOLC_OUTPUT_FILE="/usr/local/bin/solc"

TESSERA_HOME=/home/vagrant/tessera
mkdir -p ${TESSERA_HOME}
TESSERA_VERSION="21.7.0"
if [ "$TESSERA_VERSION" \> "21.7.0" ] || [ "$TESSERA_VERSION" == "21.7.0" ]; then
    TESSERA_DL_URL="https://oss.sonatype.org/content/groups/public/net/consensys/quorum/tessera/tessera-dist/${TESSERA_VERSION}/tessera-dist-${TESSERA_VERSION}.tar"
    TESSERA_ENCLAVE_DL_URL="https://oss.sonatype.org/content/groups/public/net/consensys/quorum/tessera/enclave-jaxrs/${TESSERA_VERSION}/enclave-jaxrs-${TESSERA_VERSION}.tar"

    TESSERA_OUTPUT_FILE="${TESSERA_HOME}/tessera.tar"
    TESSERA_ENCLAVE_OUTPUT_FILE="${TESSERA_HOME}/enclave.tar"
else
    TESSERA_DL_URL="https://oss.sonatype.org/content/groups/public/net/consensys/quorum/tessera/tessera-app/${TESSERA_VERSION}/tessera-app-${TESSERA_VERSION}-app.jar"
    TESSERA_ENCLAVE_DL_URL="https://oss.sonatype.org/content/groups/public/net/consensys/quorum/tessera/enclave-jaxrs/${TESSERA_VERSION}/enclave-jaxrs-${TESSERA_VERSION}-server.jar"

    TESSERA_OUTPUT_FILE="${TESSERA_HOME}/tessera.jar"
    TESSERA_ENCLAVE_OUTPUT_FILE="${TESSERA_HOME}/enclave.jar"
fi

CAKESHOP_HOME=/home/vagrant/cakeshop
mkdir -p ${CAKESHOP_HOME}
CAKESHOP_VERSION="0.12.1"
CAKESHOP_OUTPUT_FILE="${CAKESHOP_HOME}/cakeshop.war"

QUORUM_VERSION="21.4.2"
QUORUM_OUTPUT_FILE="geth.tar.gz"

# download binaries in parallel
echo "Downloading binaries ..."
parallel --link wget -q -O ::: \
    ${CONSTELLATION_OUTPUT_FILE} \
    ${TESSERA_OUTPUT_FILE} \
    ${TESSERA_ENCLAVE_OUTPUT_FILE} \
    ${QUORUM_OUTPUT_FILE} \
    ${POROSITY_OUTPUT_FILE} \
    ${CAKESHOP_OUTPUT_FILE} \
    ${SOLC_OUTPUT_FILE} \
    ::: \
    https://github.com/jpmorganchase/constellation/releases/download/v$CVER/$CREL.tar.xz \
    ${TESSERA_DL_URL} \
    ${TESSERA_ENCLAVE_DL_URL} \
    https://artifacts.consensys.net/public/go-quorum/raw/versions/v${QUORUM_VERSION}/geth_v${QUORUM_VERSION}_linux_amd64.tar.gz \
    https://github.com/jpmorganchase/quorum/releases/download/v1.2.0/porosity \
    https://github.com/jpmorganchase/cakeshop/releases/download/v${CAKESHOP_VERSION}/cakeshop-${CAKESHOP_VERSION}.war \
    https://github.com/ethereum/solidity/releases/download/v${SOLC_VER}/solc-static-linux

# install constellation
echo "Installing Constellation ${CVER}"
tar xfJ ${CONSTELLATION_OUTPUT_FILE}
cp ${CREL}/constellation-node /usr/local/bin && chmod 0755 /usr/local/bin/constellation-node
rm -rf ${CREL}
rm -f ${CONSTELLATION_OUTPUT_FILE}

# make solc executable
chmod 0755 ${SOLC_OUTPUT_FILE}

# install tessera
echo "Installing Tessera ${TESSERA_VERSION}"

if [ "$TESSERA_VERSION" \> "21.7.0" ] || [ "$TESSERA_VERSION" == "21.7.0" ]; then
    mkdir ${TESSERA_HOME}/tessera
    mkdir ${TESSERA_HOME}/enclave-jaxrs
    tar --strip-components 1 --directory ${TESSERA_HOME}/tessera -xvf ${TESSERA_OUTPUT_FILE}
    tar --strip-components 1 --directory ${TESSERA_HOME}/enclave-jaxrs -xvf ${TESSERA_ENCLAVE_OUTPUT_FILE}

    echo "TESSERA_SCRIPT=${TESSERA_HOME}/tessera/bin/tessera" >> /home/vagrant/.profile
    echo "ENCLAVE_SCRIPT=${TESSERA_HOME}/enclave-jaxrs/bin/enclave-jaxrs" >> /home/vagrant/.profile
else
    echo "TESSERA_JAR=${TESSERA_OUTPUT_FILE}" >> /home/vagrant/.profile
    echo "ENCLAVE_JAR=${TESSERA_ENCLAVE_OUTPUT_FILE}" >> /home/vagrant/.profile
fi

# install Quorum
echo "Installing Quorum ${QUORUM_VERSION}"
tar xfz ${QUORUM_OUTPUT_FILE} -C /usr/local/bin
rm -f ${QUORUM_OUTPUT_FILE}

# install Porosity
echo "Installing Porosity"
chmod 0755 ${POROSITY_OUTPUT_FILE}

# install cakeshop
echo "Installing Cakeshop ${CAKESHOP_VERSION}"
echo "CAKESHOP_JAR=${CAKESHOP_OUTPUT_FILE}" >> /home/vagrant/.profile

# copy examples
cp -r /vagrant/examples /home/vagrant/quorum-examples
chown -R vagrant:vagrant /home/vagrant/quorum-examples

# from source script
cp /vagrant/go-source.sh /home/vagrant/go-source.sh
chown vagrant:vagrant /home/vagrant/go-source.sh

# done!
echo "
 ____  _     ____  ____  _     _
/  _ \/ \ /\/  _ \/  __\/ \ /\/ \__/|
| / \|| | ||| / \||  \/|| | ||| |\/||
| \_\|| \_/|| \_/||    /| \_/|| |  ||
\____\\____/\____/\_/\_\\____/\_/  \|
--------                    ---------
        \     Examples     /
         ------------------
"
echo
echo 'The Quorum vagrant instance has been provisioned. Examples are available in ~/quorum-examples inside the instance.'
echo "Use 'vagrant ssh' to open a terminal, 'vagrant suspend' to stop the instance, and 'vagrant destroy' to remove it."
