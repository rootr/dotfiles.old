#!/bin/bash
# Install script specifically for installing 
# software and configuring a macOS system.

# This script performs the following tasks
# - Check if homebrew is isntalled
# --| Install it if it's not already installed
# - Install dependencies with homebrew
# --| Including, 
#
# - Check for available software updates
# --| Install minor updates (not full upgrades)
#
# - Set the Dock layout and preferences

# Check if homebrew is installed already
if ! is-installed brew >/dev/null 2>&1; then
	# Brew is currently not installed
	print-msg "Brew not currently installed, installing homebrew... "
	
	# Start the homebrew installation with no user interaction
	if ! NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
		echo -ne "${RED}[ERROR]${NS}: There was an error with the homebrew installation\n"
		exit 1
	fi
fi # End - homebrew check