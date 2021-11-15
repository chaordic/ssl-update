##
# overwrite this var if you prefer to use a different user
# than the global one
#
# SSH_USER="<my prefered user>"


#
# Parameters accepted via cli
#
SHORT_OPTS="h:s:p:c:k:"
LONG_OPTS=(
    "host:"
    "subject:"
    "ssl_path:"
    "cert:"
    "priv:"
)

#
# Those variables are filled up via cli
# values assigned are default.
#
_subject=""
_hosts=""
_ssl_path="/etc/ssl/certs"
_priv_filename="STAR_chaordic_com_br.ca_ssl_bundle.crt"
_cert_filename="STAR_chaordic_com_br.key"

parse_params() {
    local params="$1"
    local ret=0 opts_output=""

    set -- $params
    opts_output=$(getopt --longoptions "$( printf "%s," ${LONG_OPTS[@]} )" \
                         --name "$(basename $BASH_SOURCE)" \
                         --options "$SHORT_OPTS" \
                         -- "$@" 2>&1)
    if [ $? -ne 0 ]; then
        echo "$opts_output" 1>&2
        return 1
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --host|-h)
                _hosts="$2"
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
            --cert|-c)
                _cert_filename="$2"
                shift 2
                ;;
            --priv|-k)
                _priv_filename="$2"
                shift 2
                ;;
            *)
                pmsg error "'$1' parameter not found!" 1>&2
                shift
                ret=1
                ;;
        esac
    done

    return $ret
}

import_certificate() {
    local fullchain_content="$1"
    local privkey_content="$2"
    local extended="$3"

    local ssh_output="" ifs_bk=$'$IFS'
    local last_line="" flag="" ret=0

    if ! parse_params "$extended"; then return 1; fi

    if [ -z "$SSH_USER" ]; then
        echo "SSH_USER variable has not been defined!\nAborting renew." 1>&2
        return 1
    fi

    IFS=','
    for host in $_hosts; do
        ssh_output=$(ssh -T -o IdentitiesOnly=yes -o PreferredAuthentications=publickey $SSH_USER@$host "
sudo su -- <<'EOFSU' 2>&1
set -e;\
pushd $_ssl_path;\
cp -a $_cert_filename ${_cert_filename}.expired;\
cp -a $_priv_filename ${_priv_filename}.expired;\
cat <<'EOF' > $_cert_filename
$fullchain_content
EOF
cat <<'EOF' > $_priv_filename
$privkey_content
EOF
chown root:www-data $_cert_filename;\
chown root:www-data $_priv_filename;\
chmod 0640 $_priv_filename;\
popd;\
nginx -s reload;\
echo "exiting,\$?";
EOFSU
")
        last_line=$(grep -Eo '^exiting,[0-9]$' <<<"$ssh_output")
        if [[ "$last_line" =~ exiting,[0-9]+ ]]; then
            read flag ret <<<"$last_line"
            if ! is_number "$ret"; then
                ret=1
                pmsg error "last line must be a number; success (0) or failure (!= 0)" 1>&2
            fi
        else
            pmsg error "last line must be a number; success (0) or failure (!= 0)" 1>&2
            ret=1
        fi

        if [ $ret -ne 0 ]; then
            pmsg error "from host '$host'" 1>&2
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
