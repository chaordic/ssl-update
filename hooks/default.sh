##
# overwrite this var if you prefer to use a different user
# than the global one
#
# SSH_USER="<my prefered user>"


CERT_FILE_PREFIX="STAR_"
CERT_FILE_SUFFIX=".ca_ssl_bundle"
PRIV_FILE_PREFIX="STAR_"
PRIV_FILE_SUFFIX=".key"

#
# Parameters accepted via cli
#
SHORT_OPTS="i:s:p:"
LONG_OPTS=(
    "ips:"
    "subject:"
    "ssl_path:"
)

_subject=""
_list_ips=""
_ssl_path="/etc/nginx/ssl"

parse_params() {
    local params=$1
    local ret=0

    set -- $params
    opts=$(getopt \
           --longoptions "$( printf "%s," ${LONG_OPTS[@]} )" \
           --name "$(basename $BASH_SOURCE)" \
           --options "$SHORT_OPTS" \
           -- "$@"
        )

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ips|-i)
                _list_ips="$2"
                shift 2
                ;;

            --subject|-s)
                _subject="$2"
                shift 2
                ;;
            --ssl_path|-p)
                _ssl_path="$2"
                shift 2
                ;;
            *)
                pmsg error "error 1: '$1' parameter not found!" 1>&2
                shift
                ret=1
                ;;
        esac
    done

    return $ret
}

get_cert_filename() {
    local subject="$1"
    echo "${CERT_FILE_PREFIX}$(tr '.' '_' <<<$subject)${CERT_FILE_SUFFIX}"
}

get_priv_filename() {
    local subject="$1"
    echo "${PRIV_FILE_PREFIX}$(tr '.' '_' <<<$subject)${PRIV_FILE_SUFFIX}"
}

import_certificate() {
    local fullchain_content="$1"
    local privkey_content="$2"
    local extended="$3"

    local ssh_output="" ifs_bk=$'$IFS'
    local cert_file="" priv_file=""
    local prev_last="" last_line="" flag="" ret=0 aux=0

    if ! parse_params "$extended"; then return 1; fi

    if [ -z "$SSH_USER" ]; then
        echo "SSH_USER variable has not been defined!\nAborting renew." 1>&2
        return 1
    fi

    cert_file="$(get_cert_filename $_subject)"
    priv_file="$(get_priv_filename $_subject)"
    SSH_USER="alessandroelias"
    IFS=','
    for ip in $_list_ips; do
        ssh_output=$(ssh -T -o IdentitiesOnly=yes -o PreferredAuthentications=publickey $SSH_USER@$ip "
sudo su -- <<'EOFSU' 2>&1
set -e;\
pushd $_ssl_path;\
cp -a $cert_file ${cert_file}.expired;\
cp -a $priv_file ${priv_file}.expired;\
cat <<'EOF' > $cert_file
$fullchain_content
EOF
cat <<'EOF' > $priv_file
$privkey_content
EOF
chown root:www-data $cert_file;\
chown root:www-data $priv_file;\
chmod 0640 $priv_file;\
popd;\
nginx -s reload
echo "exiting,\$?";
EOFSU
")
        last_line=$(tail -1 <<<"$ssh_output")
        if [[ "$last_line" =~ exiting,[0-9]+ ]]; then
            read flag aux <<<$last_line
            if ! is_number "$aux"; then
                ret=1
                aux=1
                pmsg error "last line must be a number; success (0) or failure (!= 0)" 1>&2
            fi
        else
            pmsg error "last line must be a number; success (0) or failure (!= 0)" 1>&2
            ret=1
            aux=1
        fi

        if [ $aux -ne 0 ]; then
            pmsg error "from host '$ip'" 1>&2
            echo "$ssh_output" 1>&2
        fi
    done

    IFS=$'$ifs_bk'

    return $ret
}

##
# Load helpers
#
for helper in $(ls lib/*.sh); do source "$helper"; done
