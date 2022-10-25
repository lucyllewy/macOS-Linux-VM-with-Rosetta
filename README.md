## Rosetta-enabled virtual machine based on Apple Sample Code

### Live stream

The [Live stream recording](https://youtu.be/OrMjQtPxo5Y) where this was built
and tested is on YouTube.

### Download correct Ubuntu
You see in the Live stream we failed to find the desktop version, but it does exist, the correct url is
https://cdimage.ubuntu.com/focal/daily-live/current/focal-desktop-arm64.iso 
If you just go to ubuntu.com/download on a Mac it will download the amd64 version, which is not the same as arm64. When you have the wrong version you will get the dialog box to select the image and then the app crashes.

### Building the app

The built app is downloadable at [the releases page](https://github.com/diddledani/macOS-Linux-VM-with-Rosetta/releases),
or you can build the app yourself with XCode 13 Beta.

If you want to build the VM app yoursef, rather than using the pre-built download,
do the following:

1. Open XCode-beta and select from the menu bar `XCode` -> `Settings`
1. In the settings dialog navigate to `Accounts`
1. If your account is not listed click the `+` button at the bottom of the list
   and login to your Apple Developer account (a free account is sufficient)
1. Close the settings window
1. Clone the git repository off GitHub, e.g.
   `git clone https://github.com/diddledani/macOS-Linux-VM-with-Rosetta.git`
1. Open the `RosettaVM.xcodeproj` project file in XCode
1. Click the left-hand sidebar entry at the top of the tree labelled
   `RosettaVM`
1. In the right-hand pane navigate to the TARGETS entry `RosettaVM`
1. Click the top-bar entry labelled `Signing & Capabilities`
1. In the `Team` drop-down select your Apple Developer account/team, and set
   the `Signing Certificate` drop-down to `Sign to run locally`
1. Click the `>` (Run) button at the top-left of the XCode window

### Setting up Rosetta

When you start the RosettaVM app, you should be prompted by the app to select
a Linux installer ISO.

- [Ubuntu 22.04 Desktop](https://cdimage.ubuntu.com/jammy/daily-live/current/jammy-desktop-arm64.iso) (This is a daily build of the ISO and is classed as unstable, meaning that any particular day's download may have bugs - There is currently no 'stable' ISO for the desktop release)
- [Ubuntu 22.04 Server](https://cdimage.ubuntu.com/releases/22.04/release/ubuntu-22.04-live-server-arm64.iso)

Once you've supplied the app with an installation ISO file it should start the
Virtual Machine. You need to follow the standard installation of the distro that
you have downloaded.

If you're using the Ubuntu Server ISO you will need to install `binfmt-support`
to provide the `update-binfmts` command which we will use below to enable the
Rosetta wrapper. To install `binfmt-support` run:

```bash
sudo apt install -y binfmt-support
```

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

### Installing the Ubuntu Desktop for graphical applications (Only when Server ISO were choosen)

When you install Ubuntu Server with the above ISO you will only have a command-line
environment. You can upgrade from Ubuntu Server to Ubuntu Desktop by evecuting the
following commands, which will take a while to complete:

```bash
sudo apt update
sudo apt -y full-upgrade
sudo apt -y install ubuntu-desktop^
```

Note: the `^` symbol is important when you want to install `ubuntu-desktop` as this
tells `apt` to use a `task` which defines the complete Ubuntu Desktop. If you omit
the symbol you may not get a fully-installed desktop. You won't need to use the `^`
for any *other* `apt install` calls, however, only for `ubuntu-desktop`.

Once the process completes, you should reboot the VM with the following command:

```bash
sudo reboot
```

After the VM reboots you should see the graphical login screen.
