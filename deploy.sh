#!/bin/bash

: ${OPT_BOOTSTRAP:=1}
: ${OPT_SYSTEM_PACKAGES:=0}
: ${OPT_WORKDIR:=$HOME/.cat}

setup() {

    virtualenv $( [ "$OPT_SYSTEM_PACKAGES" = 1 ] && printf -- "--system-site-packages\n" ) $OPT_WORKDIR
    . $OPT_WORKDIR/bin/activate

    pip install -U -r requirements.txt

}

activate_venv() {
    . $OPT_WORKDIR/bin/activate
}

usage() {
    echo "$0: usage: $0 [options] virthost [release]"
}

if [ "$#" -lt 1 ]; then
    echo "ERROR: You must specify a target machine." >&2
    usage >&2
    exit 2
fi

VIRTHOST=$1
RELEASE=$2
PLAYBOOK=$3
HASH=$4
${OPT_CONFIG:=$PWD/config/net-iso.yml}

if [ -n "$RELEASE" ] && [ -n "$OPT_UNDERCLOUD_URL" ]; then
    echo "WARNING: ignoring release $RELEASE because you have" >&2
    echo "         provided an explicit undercloud image URL." >&2

    RELEASE=
elif [ -z "$RELEASE" ] && [ -z "$OPT_UNDERCLOUD_URL" ]; then
    RELEASE=mitaka
fi
if [ -z "$HASH" ]; then
    HASH=current-passed-ci
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

#use exported ansible variables
export ANSIBLE_CONFIG=$PWD/ansible.cfg
export ANSIBLE_INVENTORY=$OPT_WORKDIR/hosts
export SSH_CONFIG=$OPT_WORKDIR/ssh.config.ansible
export ANSIBLE_SSH_ARGS="-F ${SSH_CONFIG}"
export ANSIBLE_TEST_PLUGINS=/usr/lib/python2.7/site-packages/tripleo-quickstart/playbooks/test_plugins:$VIRTUAL_ENV/usr/local/share/tripleo-quickstart/playbooks/test_plugins:playbooks/test_plugins
export ANSIBLE_LIBRARY=/usr/lib/python2.7/site-packages/tripleo-quickstart/playbooks/library:$VIRTUAL_ENV/usr/local/share/tripleo-quickstart/playbooks/library:playbooks/library
export ANSIBLE_ROLES_PATH=/usr/lib/python2.7/site-packages/tripleo-quickstart/playbooks/roles:$VIRTUAL_ENV/usr/local/share/tripleo-quickstart/playbooks/roles:$VIRTUAL_ENV/usr/local/share/

cat <<EOF > $OPT_WORKDIR/ssh.config.ansible
Host $VIRTHOST
    User root
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
EOF

ansible-playbook -vvvv playbooks/$PLAYBOOK.yml \
    --skip-tags "undercloud-post-install" \
    -e @$OPT_CONFIG \
    -e ansible_python_interpreter=/usr/bin/python \
    -e image_url=$OPT_UNDERCLOUD_URL \
    -e local_working_dir=$OPT_WORKDIR \
    -e virthost=$VIRTHOST \
    -e delorean_hash=$HASH
