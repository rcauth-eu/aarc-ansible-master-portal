#!/bin/sh

# MyProxy credential store
creddir=/var/lib/myproxy
# trusted CAs directory
cadir=${X509_CERT_DIR:-/etc/grid-security/certificates}

if [ $# -gt 0 ];then
    echo "Usage: $(basename $0)" >&2
    echo "  Cleans up myproxy credential dir" \
         "by removing expired or revoked credentials." >&2
    echo "  (credential directory = $creddir)" >&2
    exit 0
fi

# Prints warning on stderr
warning() {
    echo "$*" >&2
}

# Prints error on stderr and exits
error() {
    echo "ERROR: $*" >&2
    exit 1
}

# Prints a warning and reason for removing specified credential, then removes
# both the .creds and the .data files
removecred() {
    warning "Removing $1.{creds,data}: $2"
    rm $1.creds $1.data
}

# Parses and handles error code from openssl verify(1ssl) which should be the
# first argument.
# Return 0 when cert is valid, 1 when invalid (revoked or expired) in which case
# credentials are removed and exits on any other error (should be manually
# fixed).
handleerror() {
    credbase=$(basename $2 .creds)
    case "$1" in
        # OK
        0) return 0 ;;
        # Expired
        10) removecred $credbase "certificate has expired"
            return 1 ;;
        # Revoked
        23) removecred $credbase "certificate revoked"
            return 1 ;;
        # Unexpected errors
        2) error "$2 (err $1): unable to get issuer certificate" ;;
        3) error "$2 (err $1): unable to get certificate CRL" ;;
        4) error "$2 (err $1): unable to decrypt certificate's signature" ;;
        5) error "$2 (err $1): unable to decrypt CRL's signature" ;;
        6) error "$2 (err $1): unable to decode issuer public key" ;;
        7) error "$2 (err $1): certificate signature failure" ;;
        8) error "$2 (err $1): CRL signature failure" ;;
        9) error "$2 (err $1): certificate is not yet valid" ;;
        11) error "$2 (err $1): CRL is not yet valid" ;;
        12) error "$2 (err $1): CRL has expired" ;;
        13) error "$2 (err $1): format error in certificate's notBefore field" ;;
        14) error "$2 (err $1): format error in certificate's notAfter field" ;;
        15) error "$2 (err $1): format error in CRL's lastUpdate field" ;;
        16) error "$2 (err $1): format error in CRL's nextUpdate field" ;;
        17) error "$2 (err $1): out of memory" ;;
        18) error "$2 (err $1): self signed certificate" ;;
        19) error "$2 (err $1): self signed certificate in certificate chain" ;;
        20) error "$2 (err $1): unable to get local issuer certificate" ;;
        21) error "$2 (err $1): unable to verify the first certificate" ;;
        22) error "$2 (err $1): certificate chain too long" ;;
        24) error "$2 (err $1): invalid CA certificate" ;;
        25) error "$2 (err $1): path length constraint exceeded" ;;
        26) error "$2 (err $1): unsupported certificate purpose" ;;
        27) error "$2 (err $1): certificate not trusted" ;;
        28) error "$2 (err $1): certificate rejected" ;;
        29) error "$2 (err $1): subject issuer mismatch" ;;
        30) error "$2 (err $1): authority and subject key identifier mismatch" ;;
        31) error "$2 (err $1): authority and issuer serial number mismatch" ;;
        32) error "$2 (err $1): usage does not include certificate signing" ;;
        50) error "$2 (err $1): application verification failure" ;;
        *)  error "$2 (err $1): unknown openssl verify error" ;;
    esac
}

# Go to the myproxy credential directory
cd $creddir || error "Cannot change to myproxy credentials directory"

# Loop over all credentials
i=0
for cred in ./*.creds ; do
    # POSIX shell has no nullglob, protect against no matches
    if [ -e "$cred" ]; then
        # Grab last certificate in chain, which should be the EEC
        errtxt=$(sed -n $(sed -n '/BEGIN CERTIFICATE/=' $cred|tail -n1),\$p $cred |\
            openssl verify -CApath $cadir -crl_check |\
            grep error)
        if [ -n "$errtxt" ];then
            errnum=$(echo "$errtxt"|sed 's/^error \([0-9]\+\) .*$/\1/')
            handleerror $errnum $cred || i=$((i+1))
        fi
    fi
done
echo "$i credential(s) removed"
