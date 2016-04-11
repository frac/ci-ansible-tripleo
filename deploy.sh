#!/bin/bash
: ${OPT_SYSTEM_PACKAGES:=0}
: ${OPT_WORKDIR:=$PWD/.cat}
: ${OPT_CLEANUP:=0}
: ${REQUIREMENTS:=requirements.txt}

clean_virtualenv() {
    if [ -d $OPT_WORKDIR ]; then
        rm -rf $OPT_WORKDIR
    fi
}

install_deps () {
    yum -y install git virtualenv gcc libyaml
}

setup() {

    if [ "$OPT_CLEANUP" = 1 ]; then
        clean_virtualenv
    fi
    virtualenv $( [ "$OPT_SYSTEM_PACKAGES" = 1 ] && printf -- "--system-site-packages\n" ) $OPT_WORKDIR
    . $OPT_WORKDIR/bin/activate

    if [ "$OPT_CLONE" == 1 ]; then
        if ! [ -d "$OPT_WORKDIR/ci-ansible-tripleo" ]; then
            echo "Cloning ci-ansible-tripleo repository..."
            git clone ssh://github.com/redhat-openstack/ci-ansible-tripleo \
                $OPT_WORKDIR/ci-ansible-tripleo
        fi

        cd $OPT_WORKDIR/ci-ansible-tripleo
        git remote update
        git checkout --quiet origin/master
    fi

    pip install -r $REQUIREMENTS
}


usage() {
    echo "$0 [options] virthost"
    echo ""
    echo "   -i, --install-deps            Install C.A.T. dependencies (git, virtualenv, gcc, libyaml)"
    echo ""
    echo " * Basic options w/ defaults"
    echo "   -p, --playbook <playbook>     default: 'tripleo', Specify playbook to be executed."
    echo "   -z, --requirements <file>     default: 'requirements.txt', Specify the python setup tools requirements file."
    echo "   -b, --build <build>           default: 'current-passed-ci', Specify a build to be used. "
    echo "   -r, --release <release>       default: 'mitaka', Specify version of OpenStack to deploy. "
    echo "   -f, --config-file <file>      select config file, default is config/net-iso.yml"
    echo "   -e, --extra-vars <file>       Additional Ansible variables.  Supports multiple ('-e f1 -e f2')"
    echo ""
    echo " * Advanced options"
    echo "   -u, --undercloud-url <URI>    overrides --release.  URI for location of undercloud image"
    echo "   -w, --working-dir <directory> Location of ci-ansible-tripleo sources and virtual env"
    echo "   -c, --clean                   Clean the virtualenv before running a deployment"
    echo "   -g, --git-clone               Git clone the ci-ansible-tripleo repo"
    echo "   -s, --system-site-packages    Create virtual env with access to local site packages"
    echo "   -v, --ansible-debug           Invoke ansible-playbook with -vvvv "
    echo "   -h, -?, --help                Display this help and exit"
}

while [ "x$1" != "x" ]; do
    case "$1" in
        --install-deps|-i)
            OPT_INSTALL_DEPS=1
            ;;

        --playbook|-p)
            PLAYBOOK=$2
            shift
            ;;

        --requirements|-z)
            REQUIREMENTS=$2
            shift
            ;;

        --build|-b)
            BUILD=$2
            shift
            ;;

        --release|-r)
            RELEASE=$2
            shift
            ;;

        --config-file|-f)
            OPT_CONFIG=$2
            shift
            ;;

        --extra-vars|-e)
            EXTRA_VARS_FILE="$EXTRA_VARS_FILE-e @$2 "
            shift
            ;;

        # Advanced Options
        --undercloud-url|-u)
            OPT_UNDERCLOUD_URL=$2
            shift
            ;;

        --working-dir|-w)
            OPT_WORKDIR=$2
            shift
            ;;

        --clean|-c)
            OPT_CLEANUP=1
            ;;

        --git-clone|-g)
            OPT_CLONE=1
            ;;

        --system-site-packages|-s)
            OPT_SYSTEM_PACKAGES=1
            ;;

        --ansible-debug|-v)
            OPT_DEBUG_ANSIBLE=1
            ;;

        --help|-h|-?)
            usage
            exit
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

if [ "$OPT_CLONE" != 1 ]; then
    CAT_DIR=.
else
    CAT_DIR=$OPT_WORKDIR/ci-ansible-tripleo
fi

# Set this default after option processing, because the default depends
# on another option.
: ${OPT_CONFIG:=$CAT_DIR/config/net-iso.yml}

if [ "$OPT_INSTALL_DEPS" = 1 ]; then
    echo "NOTICE: installing dependencies (git, virtualenv, gcc, libyaml)"
    install_deps
    exit $?
fi

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
. $OPT_WORKDIR/bin/activate

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

if [ "$OPT_DEBUG_ANSIBLE" = 1 ]; then
    VERBOSITY=vvvv
else
    VERBOSITY=vv
fi

echo "Installing OpenStack ${RELEASE:+"$RELEASE "}on host $VIRTHOST"
echo "Executing Ansible..."
set -x
ansible-playbook -$VERBOSITY $CAT_DIR/playbooks/$PLAYBOOK.yml \
    --skip-tags "undercloud-post-install" \
    -e @$OPT_CONFIG \
    -e ansible_python_interpreter=/usr/bin/python \
    -e image_url=$OPT_UNDERCLOUD_URL \
    -e local_working_dir=$OPT_WORKDIR \
    -e virthost=$VIRTHOST \
    -e delorean_hash=$BUILD \
    $EXTRA_VARS_FILE
