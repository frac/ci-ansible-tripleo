# CI-Ansible-Tripleo (C.A.T)

The entry point for CAT is deploy.sh.  This script has the following interface:

```bash
$ ./deploy.sh --help
./deploy.sh: usage: ./deploy.sh [options] virthost
    -e, --extra-vars <file> [-e, --extra-vars <file2> ...]  Use specific file(s) for setting additional Ansible variables
    -b, --build <build>    Specify a build to be used. Defaults to 'current-passed-ci'
    -p, --playbook <playbook>    Specify playbook to be executed. Defaults to 'tripleo'
    -r, --release <release>    Specify version of OpenStack to deploy. Defaults to 'mitaka'
    -c, --clean    Clean the virtualenv before running a deployment
    -h, --help    Display this help and exit
```

When run using defaults, deploy.sh will create the working directory "$PWD/.cat". This will be the root for virtualenv, into which the base dependency (Ansible 2) and other role dependencies are installed. By default this virtual env is created without access to the underlying system packages (e.g. virtualenv --system-site-packages ...), however this can be enabled by setting OPT_SYSTEM_PACKAGES=1.  Pro tip: use --clean in your interative dev scripts.  

Images containg RDO binaries for the OpenStack Mitaka release are used by default.  This is able to be overridden via 2 mechanisms. 

* "--release"  default: mitaka, is used to obtain the following image:
* https://ci.centos.org/artifacts/rdo/images/${RELEASE}/delorean/stable/undercloud.qcow2
* "--undercloud-image-url"  causes release to be ignored and uses a specific image.


TODO: update help for this and other missing vars
TODO: add support for --undercloud-image-url to arg parsing

The deploy.sh script first prepares and activates the virtualenv and installs the following roles via "pip install -U -r requirements.txt"

* https://git.openstack.org/openstack/tripleo-quickstart
* https://github.com/redhat-openstack/ansible-role-tripleo-overcloud.git#egg=ansible-role-tripleo-overcloud
* https://github.com/redhat-openstack/ansible-role-tripleo-overcloud-validate.git#egg=ansible-role-tripleo-overcloud-validate
* https://github.com/redhat-openstack/ansible-role-tripleo-tempest.git#egg=ansible-role-tripleo-tempest
* https://github.com/redhat-openstack/ansible-role-tripleo-overcloud-upgrade.git#egg=ansible-role-tripleo-overcloud-upgrade
* https://github.com/redhat-openstack/ansible-role-tripleo-undercloud-post.git/#egg=ansible-role-tripleo-undercloud-post

TODO: we should allow a flag for additional roles, as adding to CAT is a common developer scenario.  This will lower the barrier to entry for contribution.  It's related to this, suggest same commits be used: https://github.com/redhat-openstack/ci-ansible-tripleo/issues/1

After setting up ssh.config.ansible and sourcing the env defined in the file "ansible_env" the scriptwraps an invocation of an Ansible playbook (playbooks/tripleo.yml).  Any playbook can be executed instead of tripleo.yml via --playbook.

```bash
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
```