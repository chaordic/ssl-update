import_certificate() {
    set -x
    local fullchain_content="$1"
    local privkey_content="$2"

    local dst_dir="/mnt/certs/"
    local container_name="platform-registry"
    local host="docker-registry.chaordicsystems.com"
    local ssh_output=""

    echo "import_cert()" 1>&2
    set +x
    return 0
}
