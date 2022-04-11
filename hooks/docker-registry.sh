##
# This defines at global level that this domain should call this hook script
g_hooks['docker-registry.chaordicsystems.com']=restart_docker_registry

##
# overwrite this var if you prefer to use a different user
# than the global one
#
# SSH_USER="<my prefered user>"

restart_docker_registry() {
    local chain_path_filename="$1"
    local key_pathfilename="$2"

    local dst_dir="/mnt/certs/"
    local container_name="platform-registry"
    local host="docker-registry.chaordicsystems.com"
    local ssh_output=""

ssh_output=$(ssh -T ${SSH_USER}@${host} "
sudo su -- <<'EOFSU'
pushd $dst_dir &>/dev/null;\
id=\$(sudo docker ps --format \"{{.ID}}\" --filter name=$container_name);\
if [ -z \$id ]; then \
echo 1; exit 1;\
fi;\
cp -a STAR_chaordicsystems_com.ca_ssl_bundle.crt{,.expired};\
cp -a STAR_chaordicsystems_com.key{,.expired};\
cat <<'EOF' > STAR_chaordicsystems_com.ca_ssl_bundle.crt
$(cat $chain_path_filename)
EOF
cat <<'EOF' > STAR_chaordicsystems_com.key
$(cat $key_pathfilename)
EOF
chown root:www-data STAR_chaordicsystems_com.ca_ssl_bundle.crt;\
chown root:www-data STAR_chaordicsystems_com.key;\
chmod 0640 STAR_chaordicsystems_com.key;\
popd &>/dev/null;\
docker container restart \$id;\
echo \$?;
EOFSU
")

    return $(tail -1 <<<"$ssh_output")
}
