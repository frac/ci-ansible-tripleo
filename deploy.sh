#!/bin/bash
: ${OPT_BOOTSTRAP:=1}
: ${OPT_SYSTEM_PACKAGES:=0}
: ${OPT_WORKDIR:=$PWD/.cat}
: ${OPT_CLEANUP:=0}
: ${OPT_CONFIG:=$PWD/config/net-iso.yml}

clean_venv() {
    if [ -d $OPT_WORKDIR ]; then
        rm -rf $OPT_WORKDIR
    fi
}

setup() {

    if [ "$OPT_CLEANUP" = 1 ]; then
        clean_venv
    fi
    virtualenv $( [ "$OPT_SYSTEM_PACKAGES" = 1 ] && printf -- "--system-site-packages\n" ) $OPT_WORKDIR
    . $OPT_WORKDIR/bin/activate

    pip install -U -r requirements.txt

}

activate_venv() {
    . $OPT_WORKDIR/bin/activate
}

usage() {
    echo "$0: usage: $0 [options] virthost"
    echo "    -e, --extra-vars <file> [-e, --extra-vars <file2> ...]  Use specific file(s) for setting additional Ansible variables"
    echo "    -f, --config-file <file> select config file, default is config/net-iso.yml"
    echo "    -b, --build <build>    Specify a build to be used. Defaults to 'current-passed-ci'"
    echo "    -p, --playbook <playbook>    Specify playbook to be executed. Defaults to 'tripleo'"
    echo "    -r, --release <release>    Specify version of OpenStack to deploy. Defaults to 'mitaka'"
    echo "    -c, --clean    Clean the virtualenv before running a deployment"
    echo "    -h, --help    Display this help and exit"
}

while [ "x$1" != "x" ]; do
    case "$1" in
        --extra-vars|-e)
            EXTRA_VARS_FILE="$EXTRA_VARS_FILE-e @$2 "
            shift
            ;;

        --config-file|-f)
            OPT_CONFIG=$2
            shift
            ;;

        --build|-b)
            BUILD=$2
            shift
            ;;

        --help|-h)
            usage
            exit
            ;;

        --playbook|-p)
            PLAYBOOK=$2
            shift
            ;;

        --release|-r)
            RELEASE=$2
            shift
            ;;

        --clean|-c)
            OPT_CLEANUP=1
            ;;

        --) shift
            break
            ;;

        -*) echo "ERROR: unknown option: $1" >&2
            usage >&2
            exit 2
            ;;

        *)  break
            ;;
    esac

    shift
done

if [ "$#" -lt 1 ]; then
    echo "ERROR: You must specify a target machine." >&2
    usage >&2
    exit 2
fi

VIRTHOST=$1

if [ -n "$RELEASE" ] && [ -n "$OPT_UNDERCLOUD_URL" ]; then
    echo "WARNING: ignoring release $RELEASE because you have" >&2
    echo "         provided an explicit undercloud image URL." >&2

    RELEASE=
elif [ -z "$RELEASE" ] && [ -z "$OPT_UNDERCLOUD_URL" ]; then
    RELEASE=mitaka
fi
if [ -z "BUILD" ]; then
    BUILD=current-passed-ci
fi
if [ -z "$PLAYBOOK" ]; then
    PLAYBOOK=tripleo
fi

# we use this only if --undercloud-image-url was not provided on the
# command line.
: ${OPT_UNDERCLOUD_URL:=https://ci.centos.org/artifacts/rdo/images/${RELEASE}/delorean/stable/undercloud.qcow2}

echo "Setup ansible-tripleo-ci virtualenv and install dependencies"
setup
echo "Activate virtualenv"
activate_venv

# use exported ansible variables
source ansible_env
env | grep ANSIBLE
echo " "; echo " "

# add the virthost to the ssh config

if [ ! -f $OPT_WORKDIR/ssh.config.ansible ] || [ `grep --quiet "Host $VIRTHOST" $OPT_WORKDIR/ssh.config.ansible` ]; then
cat <<EOF >> $OPT_WORKDIR/ssh.config.ansible
Host $VIRTHOST
    User root
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
EOF
fi

echo "Installing OpenStack ${RELEASE:+"$RELEASE "}on host $VIRTHOST"
echo "Executing Ansible..."
set -x
ansible-playbook -vv playbooks/$PLAYBOOK.yml \
    --skip-tags "undercloud-post-install" \
    -e @$OPT_CONFIG \
    -e ansible_python_interpreter=/usr/bin/python \
    -e image_url=$OPT_UNDERCLOUD_URL \
    -e local_working_dir=$OPT_WORKDIR \
    -e virthost=$VIRTHOST \
    -e delorean_hash=$BUILD \
    $EXTRA_VARS_FILE
