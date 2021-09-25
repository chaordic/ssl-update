g_hooks['docker-registry.chaordicsystems.com']=restart_docker_registry

##
# overwrite this var if you prefer to use a different user
# than the global one
#
# SSH_USER="<my prefered user>"

restart_docker_registry() {
    local fullchain_content=$1
    local privkey_content=$2

    local dst_dir="/mnt/certs/"
    local container_name="platform-registry"
    local host="docker-registry.chaordicsystems.com"
    local ssh_output=""

ssh -T ${SSH_USER}@${host} <<"EOFSSH"
sudo su -- <<EOFSU
set -x
id=$(sudo docker ps --format "{{.ID}}" --filter name=platform-registry)
echo $id
ls adasd
echo $?
EOFSU
EOFSSH

    # echo "out: $ssh_output" 1>&2
    # return $(tail -1 <<<"$ssh_output")
}
