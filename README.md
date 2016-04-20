CI-Ansible-Tripleo (C.A.T)
==========================

The entry point for CAT is deploy.sh.  This script has the following interface:

```bash
$ ./deploy.sh --help
./deploy.sh [options] virthost

   -i, --install-deps            Install C.A.T. dependencies (git, virtualenv, gcc, libyaml)

 * Basic options w/ defaults
   -p, --playbook <playbook>     default: 'tripleo', Specify playbook to be executed.
   -z, --requirements <file>     default: 'requirements.txt', Specify the python setup tools requirements file.
   -r, --release <release>       default: 'mitaka', Specify version of OpenStack to deploy.
   -f, --config-file <file>      select config file, default is config/net-iso.yml
   -e, --extra-vars <file>       Additional Ansible variables.  Supports multiple ('-e f1 -e f2')

 * Advanced options
   -w, --working-dir <directory> Location of ci-ansible-tripleo sources and virtual env
   -c, --clean                   Clean the virtualenv before running a deployment
   -n, --no-clone                Skip cloning repo
   -s, --system-site-packages    Create virtual env with access to local site packages
   -v, --ansible-debug           Invoke ansible-playbook with -vvvv
   -h, -?, --help                Display this help and exit
```

How does it work?
-----------------

When run using defaults, deploy.sh will create the working directory "$PWD/.cat". This will be the root for virtualenv, into which the base dependency (Ansible 2) and other role dependencies are installed. By default this virtual env is created without access to the underlying system packages (e.g. virtualenv --system-site-packages ...), however this can be enabled by setting OPT_SYSTEM_PACKAGES=1.  Pro tip: use --clean in your interative dev scripts.

Images containg RDO binaries for the OpenStack Mitaka release are used by default.  This is able to be overridden via 2 mechanisms.

* "--release"  default: mitaka, is used to obtain the following image:
* https://ci.centos.org/artifacts/rdo/images/${RELEASE}/delorean/stable/undercloud.qcow2
* "--undercloud-image-url"  causes release to be ignored and uses a specific image.

The deploy.sh script first prepares and activates the virtualenv and installs the following roles via "pip install -U -r requirements.txt"

* https://git.openstack.org/openstack/tripleo-quickstart
* https://github.com/redhat-openstack/ansible-role-tripleo-overcloud.git#egg=ansible-role-tripleo-overcloud
* https://github.com/redhat-openstack/ansible-role-tripleo-overcloud-validate.git#egg=ansible-role-tripleo-overcloud-validate
* https://github.com/redhat-openstack/ansible-role-tripleo-tempest.git#egg=ansible-role-tripleo-tempest
* https://github.com/redhat-openstack/ansible-role-tripleo-overcloud-upgrade.git#egg=ansible-role-tripleo-overcloud-upgrade
* https://github.com/redhat-openstack/ansible-role-tripleo-undercloud-post.git/#egg=ansible-role-tripleo-undercloud-post

After setting up ssh.config.ansible and sourcing the env defined in the file "ansible_env" the script wraps an invocation of an Ansible playbook (playbooks/tripleo.yml).  Any playbook can be executed instead of tripleo.yml via --playbook.

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

# How to contribute

We're glad you asked!  Contributions and patches are welcome!  Feel free to log issues and/or discuss here:

[https://github.com/redhat-openstack/ci-ansible-tripleo/issues](https://github.com/redhat-openstack/ci-ansible-tripleo/issues)

Code reviews and patches are managed by Gerrit here:

[https://review.gerrithub.io/#/q/project:redhat-openstack/ci-ansible-tripleo](https://review.gerrithub.io/#/q/project:redhat-openstack/ci-ansible-tripleo)


### You easily set up an env to contribute a patch like this:

```bash
$ git clone ssh://github.com/redhat-openstack/ci-ansible-tripleo
Cloning into 'ci-ansible-tripleo'...
remote: Counting objects: 105, done.
remote: Compressing objects: 100% (42/42), done.
remote: Total 105 (delta 33), reused 8 (delta 8), pack-reused 53
Receiving objects: 100% (105/105), 18.28 KiB | 0 bytes/s, done.
Resolving deltas: 100% (45/45), done.
Checking connectivity... done.
$ cd ci-ansible-tripleo/
$ git review -s
Creating a git remote called "gerrit" that maps to:
	ssh://github-username@review.gerrithub.io:29418/redhat-openstack/ci-ansible-tripleo.git

$ git remote -v
gerrit	ssh://github-username@review.gerrithub.io:29418/redhat-openstack/ci-ansible-tripleo.git (fetch)
gerrit	ssh://github-username@review.gerrithub.io:29418/redhat-openstack/ci-ansible-tripleo.git (push)
origin	ssh://github.com/redhat-openstack/ci-ansible-tripleo (fetch)
origin	ssh://github.com/redhat-openstack/ci-ansible-tripleo (push)
```
* create a branch (git checkout -b my-groovy-idea)
* add files and commit
* Post review (git review)

The commit message should be of the form:

```bash
A single line description of the change

A multi-line description of the change, ideally with
context and/or URL to github issue.
```

To address feedback and iterate on reviews, amend your existing commit (git commit --amend) and run "git review" again



