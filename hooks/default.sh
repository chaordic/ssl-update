##
# overwrite this var if you prefer to use a different user
# than the global one
#
# SSH_USER="<my prefered user>"


DST_DIR="/etc/nginx/ssl"
CERT_FILE="STAR_chaordicsystems_com.ca_ssl_bundle"
PRIV_FILE="STAR_chaordicsystems_com.key"

import_certificate() {
    local fullchain_content="$1"
    local privkey_content="$2"
    local extended="$3"
    local ssh_output=""

    if [ -z "$SSH_USER" ]; then
        echo "SSH_USER variable has not been defined!\nAborting renew." 1>&2
        return 1
    fi

    ssh_output=$(ssh -T -o IdentitiesOnly=yes -o PreferredAuthentications=publickey $SSH_USER@$extended "
sudo su -- <<'EOFSU'
pushd $DST_DIR &>/dev/null;\
cp -a $CERT_FILE ${CERT_FILE}.expired;\
cp -a $PRIV_FILE ${PRIV_FILE}.expired;\
cat <<'EOF' > $CERT_FILE
$fullchain_content
EOF
cat <<'EOF' > $PRIV_FILE
$privkey_content
EOF
chown root:www-data $CERT_FILE;\
chown root:www-data $PRIV_FILE;\
chmod 0640 $PRIV_FILE;\
popd &>/dev/null;\
nginx -s reload
echo \$?;
EOFSU
")
    return $(tail -1 <<<"$ssh_output")
}
