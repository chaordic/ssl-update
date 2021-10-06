declare -A MSG_LEVEL=( [warn]="[WARNING]: "
                       [info]="[INFO]: "
                       [error]="[ERROR]: "
                      )
declare -A LEVEL_COLORS=( [warn]='\033[1;33m'
                          [info]='\033[32m'
                          [error]='\033[31m'
                         )

###
# pmsg - print message on the screen based on the level
#
# params:
#   $1 [in][string] - level of the message, represents the colorful
#
# return: none
pmsg() {
    local level=$1

    shift
    echo -e "${LEVEL_COLORS[$level]}${MSG_LEVEL[$level]}\033[0m${@}"
}

###
# is_number - check if only numbers is compound the parameter
#
# params:
#   $1 [in][integer] - string representing the suposed number
#
# return: 0 if is number otherwise 1
is_number() { [ -n "${1##*[!0-9]*}" ]; }
