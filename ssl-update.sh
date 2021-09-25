#!/usr/bin/env bash
###
# -
#
# params:
#   $1 -
#
# return: none
# set -e

#
# Source where expected the full chain certificate and private key
# files could be found.
#   eg.: s3://lambda-letsencrypt-ti/letsencrypt_internal/Certs/chaordicsystems.com/fullchain.pem
#
S3_BUCKET="s3://lambda-letsencrypt-ti/letsencrypt_internal/Certs"
# Destination where the certs will be downloaded
OUTPUT_DIR="tmp_certs"
# full chain and private key of the certificate.
CHAIN_FILENAME="fullchain.pem"
PRIVK_FILENAME="privkey.pem"
# Strict number of days that will be remaining to expire the certificate
MAX_DAYS=30

#
# Global variables
#
##
# hooks to be called with methods to perform the renew
declare -A g_hooks=()

declare -Ar MSG_LEVEL=([warn]="[WARNING]: "
                       [info]="[INFO]: "
                       [error]="[ERROR]: "
                      )
declare -Ar LEVEL_COLORS=([warn]='\033[1;33m'
                          [info]='\033[32m'
                          [error]='\033[31m'
                         )
#
# Commands that this script depends on
#
CMDS_DEPS="aws ssh date openssl"


# variable opulated via cli
g_domain="chaordicsystems.com"
g_fqdn="docker-registry.chaordicsystems.com"
g_port="5000"
g_extend=""


################################## functions ##################################
###
# pmsg - pop message on the screen
#
# params:
#   $1 [string] - level of the message
#
# return: none
pmsg() {
    local level=$1

    shift
    echo -e "${LEVEL_COLORS[$level]}${MSG_LEVEL[$level]}\033[0m${@}"
}

###
# check_deps - verify if dependencies can be found as a command at bash
#
# params:
#   $1 [string] - list of sapce separated commands
#
# return: none
#
# ps: in case a command can not be found the script ends set -e
check_deps() {
    local cmds="$1"

    for cmd in $CMDS_DEPS; do
        type command $cmd 1>/dev/null
    done
}

###
# make_sure_output_dir - garatee the output dir exists
#
# params:
#   $1 [string] - dir name
#
# return: none
make_sure_output_dir() {
    local target="$1"
    [ -d "$OUTPUT_DIR" ] || mkdir -p "$OUTPUT_DIR"
}

###
# get_cert - downlaad the full cert file from the server
#
# params:
#   $1 [string]  - the full qualify name of a domain server listen for https
#   $2 [integer] - port number that the server listen at (https default 443)
#   $3 [string]  - destination path to save the certificate
#
# return:
#  - [integer] the error code for openssl
#  - [string] from bash expantion the fqdn.crt this file contain the actual
#    certificate for the server
get_cert() {
    local fqdn="$1" port=$2 dst_dir="$3"
    local err=0 file_name=""
    local cert=""

    cert=$(echo | openssl s_client -connect "$fqdn:$port" 2>&1)
    err=$?
    if [ $err -eq 0 ]; then
        file_name="${fqdn}.crt"
        cat << EOF > "${dst_dir}/${file_name}"
"$cert"
EOF
    fi

    echo "$file_name"
    return $err
}

###
# get_cert_from_s3 - download the full and private files from s3
#
# params:
#   $1 [string] - domain expected to be in the s3 as the dir
#
# return [integer]: the return code of aws command, in case fullchain fails
#   the private key will no be dowloaded and a error is retured.
# See man aws s3 return code
get_cert_from_s3() {
    local domain="$1" dst_dir="$2"
    local ret=0

    aws s3 cp "$S3_BUCKET/$domain/$CHAIN_FILENAME" "$dst_dir"
    ret=$?
    if [ $ret -eq 0 ]; then
        aws s3 cp "$S3_BUCKET/$domain/$PRIVK_FILENAME" "$dst_dir"
        ret=$?
    fi

    return $ret
}

###
# get_expired_date - read expired date from the fullchain cert filename
#
# params:
#   $1 [string] - target directory
#   $2 [string] - file name downloade in the $1
#
# return [integer]: the code returned by openssl command
get_expired_date() {
    local chain_path_filename="$1"
    openssl x509 -noout -enddate -in "$chain_path_filename" | awk -F'=' '{print $2}'
    return $?
}

###
# get_days_from_now - get the number of days to expire; if diff is less than zero
# the certificate already expired by the absolute number, if greater than zero
# still n numbers remaing to expire; if equal zero expired at the moment of the run of the script.
#
# params:
#   $1 [string] - date that ends the certificate in GMT
#   e.g: "Sep 14 13:04:32 2021 GMT"
#
# return [string]: diff is the number of days from the expire date until the moment of the run
#   of the script. if diff <= 0, cert expired; if diff > 0 diff days remaining to expire.
get_days_from_now() {
    local cert_expired_date="$1" diff=0
    let diff=($(date +%s -d "$cert_expired_date")-$(date +%s))/86400
    echo "$diff"
}

###
# get_cert_subject - get the fqdn even if is a wild card domain
#
# params:
#   $1 [string] - target directory
#   $2 [string] - full chain file name downloaded at $1
#
# return: the code returned openssl
get_cert_subject() {
    local chain_path_filename="$1"
    openssl x509 -noout -subject -in "$chain_path_filename" | awk -F'= ' '{print $2}'
    return $?
}


##################################### main ####################################
[ -f ".env" ] && source ".env"

pmsg info "loading hooks ..."
for hook in $(ls -1 hooks/*.sh); do
    source "$hook"
done

pmsg info "checking dependencies ..."
check_deps "$CMDS"
pmsg info "making sure output dir ..."
make_sure_output_dir "$OUTPUT_DIR"

pmsg info "getting the actual certificate for domain '${g_fqdn}:${g_port}' ..."
actual_cert_filename=$(get_cert "$g_fqdn" "$g_port" "$OUTPUT_DIR")
if [ $? -ne 0 ]; then
    pmsg error "getting actual certificate for '$g_fqdn' failed!!!"
    exit 1
fi

ndays=$(get_days_from_now "$(get_expired_date ${OUTPUT_DIR}/${actual_cert_filename})")
fqdn="$(get_cert_subject ${OUTPUT_DIR}/${actual_cert_filename})"
if [ $ndays -le 0 ]; then
    pmsg warn "the certificate for '$fqdn' expired by $ndays day(s)!!!"

    pmsg info "downloading certificate from S3 ..."
    # get_cert_from_s3 "$g_domain" "$OUTPUT_DIR"
    if [ $? -ne 0 ]; then
        pmsg error "failed downloading chain and or private key for '$g_domain'!"
        exit 1
    fi
else
    pmsg warn "the certificate '$fqdn' will expire in $ndays day(s) no action will be taken."
    # exit 1
fi

# ndays=$(get_days_from_now "$(get_expired_date . $CHAIN_FILENAME)")
# # ndays=$(get_days_from_now "Sep 14 13:04:32 2021 GMT")
# fqdn=$(get_cert_subject . $CHAIN_FILENAME)
# if [ $ndays -le 0 ]; then
#     pmsg warn "!!!! the FQDN '$g_fqdn' expired !!!!!"
#     #issue_new cert
# else
#     pmsg warn "the cert '$fqdn' will expire in $ndays day(s)!"
#     # issue new cert
# fi

${g_hooks["$g_fqdn"]} "$(cat ${OUTPUT_DIR}/${CHAIN_FILENAME})" "$(cat ${OUTPUT_DIR}/${PRIVK_FILENAME})" "$g_extend"
err=$?
[ $err -ne 0 ] && pmsg error "hook function '${g_hooks[$g_fqdn]}' has failed with error $err"
