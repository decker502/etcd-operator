#!/bin/bash

set -o errexit
set -o pipefail
set -x 

usage()
{
    cat << EOF
Create self signed certificates

Usage : $(basename $0) -f <config> [-d <ssldir>]
      -h | --help         : Show this message
      -ip | --ip : member ip
      -d | --ssldir       : Directory where the certificates will be installed

      for each host.
           ex :
           $(basename $0) -ip "192.168.1.1" -d /srv/ssl
EOF
}

# Options parsing
while (($#)); do
    case "$1" in
        -h | --help)   usage;   exit 0;;
        -ip | --ip) MEMBER_IP="${2}"; shift 2;;
        -d | --ssldir) SSLDIR="${2}"; shift 2;;
        *)
            usage
            echo "ERROR : Unknown option"
            exit 3
        ;;
    esac
done

if [ -z ${MEMBER_IP} ]; then
    echo "ERROR: MEMBER_IP is missing. option -ip"
    exit 1
fi

if [ -z ${SSLDIR} ]; then
    SSLDIR="/etc/etcd/certs"
fi

tmpdir=$(mktemp -d /tmp/etcd_cacert.XXXXXX)
trap 'rm -rf "${tmpdir}"' EXIT
cd "${tmpdir}"

mkdir -p "${SSLDIR}"

export SAN="IP:127.0.0.1"

# Root CA
if [ -e "$SSLDIR/ca-key.pem" ]; then
    echo "test1:"${SSLDIR}
    # Reuse existing CA
    cp $SSLDIR/{ca.pem,ca-key.pem} .
else
echo "test2"
    openssl genrsa -out ca-key.pem 2048 > /dev/null 2>&1
    openssl req -x509 -new -nodes -key ca-key.pem -days 10000 -out ca.pem -subj "/CN=etcd-ca" > /dev/null 2>&1
    cp ca*.pem $SSLDIR/
fi

gen_key_and_cert() {
    local name=$1
    local subject=$2
    local config="
    [req]
    req_extensions = v3_req
    distinguished_name = req_distinguished_name
    [req_distinguished_name]
    [ v3_req ]
    basicConstraints = CA:FALSE
    keyUsage = nonRepudiation, digitalSignature, keyEncipherment
    extendedKeyUsage = clientAuth, serverAuth
    subjectAltName = ${SAN}
    "

    openssl genrsa -out ${name}-key.pem 2048 > /dev/null 2>&1

    openssl req -new -key ${name}-key.pem -out ${name}.csr -subj "${subject}" -config <(echo -e "${config}") > /dev/null 2>&1
    openssl x509 -req -in ${name}.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out ${name}.pem -days 10000 -extensions v3_req -extfile <(echo -e "${config}") > /dev/null 2>&1
    
}


# client
if ! [ -e "$SSLDIR/client.pem" ]; then
    gen_key_and_cert "client" "/CN=client"
    mv client*.pem ${SSLDIR}/
fi

IP=""
DNS=""

for domain in ${ETCD_DOMAINS[@]}; do
    DNS="${DNS}DNS:${domain},"
done

IP="IP:${MEMBER_IP},"
IP="${IP}IP:127.0.0.1"

export SAN=${DNS}${IP}

gen_key_and_cert "server-${MEMBER_IP}" "/CN=${MEMBER_IP}"
gen_key_and_cert "peer-${MEMBER_IP}" "/CN=${MEMBER_IP}"

unset SAN
# Install certs
mv server*.pem peer*.pem ${SSLDIR}/
