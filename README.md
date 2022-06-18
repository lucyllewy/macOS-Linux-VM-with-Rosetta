## Rosetta-enabled virtual machine based on Apple Sample Code

### Live stream

The [Live stream recording](https://youtu.be/OrMjQtPxo5Y) where this was built
and tested is on YouTube.

### Building the app

To build and run you need to be an active Apple Developer ($99 per year fee
applies).

If or when you are an active Apple Developer perform the following to build and
run the VM:

1. Open XCode and select from the menu bar `XCode` -> `Settings`
1. In the settings dialog navigate to `Accounts`
1. If your account is not listed click the `+` button at the bottom of the list
   and login to your Apple Developer account
1. Close the settings window
1. Open the `RosettaVM.xcodeproj` project file in XCode
1. Click the left-hand sidebar entry at the top of the tree labelled
   `RosettaVM`
1. In the right-hand pane navigate to the TARGETS entry `RosettaVM`
1. Click the top-bar entry labelled `Signing & Capabilities`
1. In the `Team` drop-down select your Apple Developer account/team
1. Click the `>` (Run) button at the top-left of the XCode window

### Once the app is build and running

You should be prompted by the app to select a Linux installer ISO.
[Ubuntu 22.04](https://cdimage.ubuntu.com/ubuntu/releases/22.04/release/ubuntu-22.04-live-server-arm64.iso)
server is known to be compatible (there is no desktop version for ARM64 CPUs).

Once you've supplied the app with an installation ISO file it should start the
Virtual Machine. You need to follow the standard installation of the distro that
you have downloaded.

Once installed, you need to execute the following commands inside the Linux VM
to enable Rosetta to intercept x86_64 binaries:

```bash
sudo mkdir /var/run/rosetta
sudo mount -t virtiofs ROSETTA /var/run/rosetta
sudo /usr/sbin/update-binfmts --install rosetta /var/run/rosetta/rosetta \
    --magic "\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00" \
    --mask "\xff\xff\xff\xff\xff\xfe\xfe\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff" \
    --credentials yes --preserve no --fix-binary yes
```

Now you should be able to execute x86_64 Linux binaries as though they were
native. Bare in mind, however, that you need all your Linux app's required
libraries in x86_64. On Ubuntu these are installable by adding the following to
your `/etc/apt/sources.list` file (ensure you change `jammy` to the codename of
the version of Ubuntu you are running):

```
deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ jammy main restricted
deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ jammy-updates main restricted
deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ jammy universe
deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ jammy-updates universe
deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ jammy multiverse
deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ jammy-updates multiverse
deb [arch=amd64] http://security.ubuntu.com/ubuntu jammy-security main restricted
deb [arch=amd64] http://security.ubuntu.com/ubuntu jammy-security universe
deb [arch=amd64] http://security.ubuntu.com/ubuntu jammy-security multiverse
```

You also need to tell APT and dpkg to enable `amd64` repositories:

```bash
sudo dpkg --add-architecture amd64
```

When you make changes to the `/etc/apt/sources.list` file, or add an additional
architecture with the `dpkg` command, you should run `sudo apt update` to update
your cache of known packages.

To install an x86_64/amd64 library in Ubuntu once you've updated your
`/etc/apt/sources.list` you need to append `:amd64` to each package name, e.g.:

```bash
sudo apt install libx11-6:amd64
```
