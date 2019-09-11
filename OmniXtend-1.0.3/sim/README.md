## Demo Video

A demo video is shown [here](./OmniXtendDemo.mov)
## Obtaining required software

You will need to either build a virtual machine or install several dependencies.
*Note*: Tested with kernel version 5.0.0.27-generic

To build the virtual machine:
1. Install [Vagrant 2.2.5](https://vagrantup.com) and [VirtualBox 6.0](https://virtualbox.org)
2. Clone the repository `git clone https://github.com/chipsalliance/omnixtend.git`
3. make sure you have [enabled virtualization in your environment](https://stackoverflow.com/questions/33304393/vt-x-is-disabled-in-the-bios-for-both-all-cpu-modes-verr-vmx-msr-all-vmx-disabl)
4. `cd omnixtend/tutorial`
5. `vagrant up`
6. `vagrant ssh`

The `vagrant up` command brings up only the default `vagrant` login with the
password `vagrant`. Dependencies may or may not have been installed for you to
proceed with running P4 programs. Please refer the [existing
issues](https://github.com/p4lang/tutorials/issues) to help fix your problem or
create a new one if your specific problem isn't addressed there.


## Run OmniXtend Simulation

Please, follow step by step [here](./src/README.md).
