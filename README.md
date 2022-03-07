# Dotfiles Syncing
> Sync hidden config files between machines for easy setup and configuration.

### Using this Repo
> This repo can be installed and used on macOS and Linux system but currently the installer only works on macOS. The steps to download, install and start using these dotfiles is outlined below:

### Step 1: Clone the Repo
*Clone this repo to your home directory*
```bash
cd ~/
git clone https://github.com/rootr/dotfiles.git
```

This will clone the repo to your home directory and will create a `dotfiles` directory at `$HOME/`.

### Step 2: Run the Installer
*Run the installer to install the dependencies and symlink the appropriate config files to your home directory.*

```bash
bash ~/dotfiles/install.sh
```

### Installer Script
---
If using the `install.sh` script, the script will perform the following tasks depending on the operating system of the machine it's running on.

#### All Operating Systems
> These tasks are performed by the installer no matter what operating system it is run on.

- Backup current config files in the home directory
	- Backs them up to a `.dotfiles.old` directory that it creates

#### On macOS Machines
> These tasks are performed by the install script when run on a machine running a macOS operating system.

- Check if `homebrew` is installed or not
	- Install it, if it's not already installed
- Used `brew` to install:
	- [exa](https://github.com/ogham/exa "")
	- [pup](https://github.com/ericchiang/pup "")
	- [jq](https://github.com/stedolan/jq "")