#!/bin/bash
# Installs the required dependencies and symlinks the config files
# VERSION: 0.1.2
# +---------------------------------------------------------------------------------------------------------------
# |Usage: bash install.sh [-h | --help] [-v | --verbose]
# |
# |  Install the required dependencies and symlink the appropriate files for .dotfiles
# |  This performs the following actions:
# |  - Backup existing dotfiles in ~/ to ~/.dotfiles_backup/
# |  - Check for required dependencies
# |  - Install required dependencies
# |  - Symlink config files from ~/.dotfiles/src/symlinked/
# |
# |  Options:
# |    -h, --help              Display this usage help
# |    -s, --silent             Run script without printing anything to stdout"
# +---------------------------------------------------------------------------------------------------------------
# Copyright 2022 Martin Cox
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions: The
# above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
# ----------------------------------------------------------------------------

# ---------------- #
# GLOBAL VARIABLES #
# ---------------- #

# Process ID of the spinner when it's running
# (the little loading spinner icon that's animated)
_SPIN_PID=""

# Colors for messages
NS='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BOLD='\033[1m'
ITALIC='\033[3m'

# Name of this installation script
scriptName="${FUNCNAME[0]}"

# ---------------- #
# GLOBAL FUNCTIONS #
# ---------------- #

# Print usage information for this script
# -------------------------------------------
# @ Arguments: NONE
# @ Usage: usage
# @ Return: Prints usage message (no return)
# -------------------------------------------
# @ Global Variables: NONE
# -------------------------------------------
usage() {
  echo -e "
  Usage: ${BOLD}$scriptName${NS} [${BOLD}-h${NS} | ${BOLD}--help${NS}] [${BOLD}-v${NS} | ${BOLD}--verbose${NS}]

  Install the required dependencies and symlink the appropriate files for .dotfiles
  This performs the following actions:
  - Backup existing dotfiles in ${ITALIC}~/${NS} to ${ITALIC}~/.dotfiles_backup/${NS}
  - Check for required dependencies
  - Install required dependencies
  - Symlink config files from ${ITALIC}~/.dotfiles/src/symlinked/${NS}

  ${DIM}Options:${NS}
    ${BOLD}-h${NS}, ${BOLD}--help${NS}              Display this usage help
    ${BOLD}-s${NS}, ${BOLD}--silent${NS}             Run script without printing anything to stdout"
}

# A function to generate and animate a spinning loading icon
# -----------------------------------------------------------
# @ Arguments:
# --> framerate [NUMBER] | Desired framerate     (optional)
# --> spinner   [STRING] | Characters to animate (optional)
# -----------------------------------------------------------
# @ Usage: _spinner [$framerate] [$spinner_characters_to_use]
# @ Return: no return value
# -------------------------------------------
# @ Global Variables: NONE
# -----------------------------------------------------------
_spinner() {
  # Duration between each frame of the animation
  local framerate=$1
  # Characters to animate for the spinner
  local spinner=$2
  # Number of animation frames to use
  local total_frames=$((${#spinner} - 1))

  # Animate the spinner indefinitely (until killed)
  while :; do
    # Loop through each character in the spinner
    for i in $(seq 0 $total_frames); do

      # Print the spinner frame
      echo -n " [${spinner:$i:1}]"

      # Clear previous for next animation frame
      echo -ne "\b\b\b\b"

      # Wait $framerate for the next frame
      sleep "$framerate"
    done
  done

}

# Function to show a spinner while something is loading
# -------------------------------------------
# @ Arguments: NONE
# @ Usage: show_spinner
# @ Return: Shows the animated icon until stopped (no return)
# -------------------------------------------
# @ Global Variables:
# --> $_SPIN_PID - Sets to PID of spinner process
# -------------------------------------------
# shellcheck disable=SC2120
show_spinner() {
  # Duration between each frame of the animation
  local framerate=${1:-0.2}
  # Characters to animate for the spinner
  local spinner=${2:-"/|\\-/|\\-"}

  # Start showing the spinner animation
  _spinner "$framerate" "$spinner" &
  # Update the $_SPIN_PID global variable
  _SPIN_PID=$!

  # Kill the spinner on any signal, including our own exit
  trap 'kill -9 $_SPIN_PID' $(seq 0 15) >/dev/null 2>&1
}

# Function to kill the spinner on demand
# -------------------------------------------
# @ Arguments: NONE
# @ Usage: stop_spinner
# @ Return: Shows the animated icon until stopped (no return)
# -------------------------------------------
# @ Global Variables:
# --> $_SPIN_PID - Resets back to ""
# -------------------------------------------
stop_spinner() {
  # Check if the _SPIN_PID process is still running or not
  if ps -p "$_SPIN_PID" >/dev/null; then
    # Kill the spinner PID
    kill $_SPIN_PID

    # Clear the $_SPIN_PID value
    _SPIN_PID=""
  fi
}

# A function to ask the user if they want to try again
# -------------------------------------------
# @ Arguments: NONE
# @ Usage: _try-again "Question to ask" $function_to_run_again
# @ Return: 0 on success, non-zero on error
# -------------------------------------------
# @ Global Variables: NONE
# -------------------------------------------
# shellcheck disable=SC2120
_try-again() {
  # Whether or not to try again
  # Default: y / yes
  local default_answer="y"
  # Question to ask in the prompt
  local question=${1:-"Would you like to try again?"}
  # Function to run again if answer is yes/y
  local func_to_run="$2"

  read -rp "$question [y/n]: " response

  # Anser is the response or the default
  response=${response:-"$default_answer"}

  # Convert the answer to lowercase
  response=$(echo "$response" | tr '[:upper:]' '[:lower:]')

  # Check if it's 'y' or 'yes'
  if [ "$response" == "y" ] || [ "$response" == "yes" ]; then
    # Check if the second argument is supplied
    if [ -n "$func_to_run" ]; then
      # Run the supplied function
      "$2"
    fi

    # We ARE going to try again
    return 0
  else
    # We ARE NOT going to try again
    return 1
  fi
}

# Function to print messages if we're in verbose mode
# -------------------------------------------
# @ Arguments: [STRING] --> Message to print
# @ Usage: print-msg "Message to print"
# @ Return: Prints message (no return)
# -------------------------------------------
# @ Global Variables: NONE
# -------------------------------------------
print-msg() {
  # Message to print
  local msg="$1"

  # Double check that the $msg argument was provided
  if [ -z "$msg" ]; then
    # An argumetn was not provided
    print-msg "${RED}[ERROR]${NS}: ${FUNCNAME[0]} - 'Message' argument is required but was not found"
  fi

  # Only print if we're in 'verbose mode'
  [ "$silent_mode" == "disabled" ] && echo -ne "$msg"
}

# ---------------- #
# SCRIPT VARIABLES #
# ---------------- #

# Optional packages to install on the machine
# optional_packages="code dkms firefox jq speedtest-cli pup nmap"

# General required packages for the config files
# These dependencies are required on all distributions/systems
req_deps_all="exa curl git nano"

# Required packages for Arch Linux installations
req_deps_arch="yay-git dhcpcd wpa_supplicant sudo ssh acpi man-db openssh pkgfile ufw unzip xdotool zip wget dmenu feh i3-gaps i3lock-color i3status inetutils lightdm lightdm-gtk-greeter xorg xterm code dkms firefox jq speedtest-cli pup nmap"

# Required packages for Ubuntu Linux installations
req_deps_ubuntu=""

# Required packages for Kali Linux installations
req_deps_kali=""

# Required packages for macOS installations
req_deps_macos="brew"

# Name of the OS we're running on (e.g. macos, arch, ubuntu, kali, etc.)
os_name=""

# List of packages that need to get installed
# This list is generated by the install script
declare -a pkgs_to_install=()

# Whether or not we're running in verbose mode
silent_mode="disabled"

# Directory containing the config files we're going to
# be symbolic linking to the ~/ directory
configFilesDir="$HOME/.dotfiles/src/symlinked"

# ---------------- #
# SCRIPT FUNCTIONS #
# ---------------- #

# Parse the command line arguments for this script
# -------------------------------------------
# @ Arguments: Must pass script arguments "$@"
# @ Usage: parse-args "$@"
# @ Return: Only modifies variables (no return)
# -------------------------------------------
# @ Global Variables:
# --> $silent_mode
# -------------------------------------------
parse-args() {
  # Check if there are any arguments provided
  if [ "$#" -ne 0 ]; then
    # There ARE arguments provided

    # Transform long options to short ones
    for arg in "$@"; do
      shift

      case "$arg" in
        "--help") set -- "$@" "-h" ;;
        "--quiet") set -- "$@" "-q" ;;
        *) set -- "$@" "$arg" ;;
      esac
    done

    # Parse short options
    while getopts ":hs" options; do
      # Check the different flags
      case $options in
      # Dispaly the usage information
      "h")
        usage
        return 0
        ;;
      "s") silent_mode="enabled" ;;
      # Unrecognized option
      \?)
        # Let them know we have an unrecognized option
        echo >&2 -e "${BOLD}$scriptName${NS}: ${RED}unrecognized option${NS} --> $OPTARG"

        # Print the usage information
        usage

        # Exit with an error
        return 1
        ;;
      :)
        # Signal that one of the options requires an argument and is missing it
        echo >&2 -e "${BOLD}$scriptName${NS}: ${RED}[ERROR]:${NS} Option ${BOLD}-$OPTARG${NS} requires an argument"

        # Print the usage information
        usage

        # Exit with an error
        return 1
        ;;
      esac
    done
  fi # End - Check for empty arguments

  # Remove the processed arguments
  shift $((OPTIND - 1))
}

# Function to check if the a specified bin is installed
# -------------------------------------------
# @ Argument: [REQUIRED] Command to test (e.g. curl)
# @ Usage: is-installed cmd
# @ Return: 0 on success, non-zero on error
# -------------------------------------------
# @ Global Variables: NONE
# -------------------------------------------
is-installed() {
  # Throw an error if no argument is provided
  if [ "$#" -eq 0 ]; then
    echo >&2 "$scriptName ${RED}[ERROR]${NS}: Command is required but was not found in arguments"
    return 1
  fi

  print-msg "Checking for presence of '$1'... "

  # Allow time to read the message
  sleep 0.5

  # Check if the command is found or not
  if ! command -v "$1" > /dev/null; then
    # Command is not found on the system

    print-msg "${RED}[ERROR]${NS}: '$1' command not found\n"

    return 1
  fi

  print-msg "${GREEN}[DONE]${NS}: '$1' command installed\n"

  return 0
}

# Function to check which OS we're running on
# -------------------------------------------
# @ Argument: NONE
# @ Usage: os_name=$(get-os-name)
# @ Return: Prints results
# -------------------------------------------
# @ Global Variables: NONE
# -------------------------------------------
get-os-name() {
  # Get the type of kernel we're on (Linux / macOS)
  # Also convert it to lowercase
  local kernel_type=""
        kernel_type=$(uname | tr '[:upper:]' '[:lower:]')

  # Check if we're on macOS
  if [ "$kernel_type" == "darwin" ]; then
    # We're running on macOS
    echo -ne "macos"
    return 0
  else
    print-msg "Checking for os-release file... "

    # Check for the presence of the /etc/os-release file (only on Linux)
    if [ ! -f /etc/os-release ]; then
      # The /etc/os-release file does not exist
      print-msg "${RED}[ERROR]${NS}: Error locating ${ITALIC}/etc/os-release${NS} file"
      return 1
    fi
  fi

  # Otherwise, get the Linux distro we're running on (convert it to lowercase)
  local linux_distro=""
        linux_distro=$(awk -F'"' '/^NAME/ { print tolower($2) }' /etc/os-release)

  case "$linux_distro" in
    "arch" | "arch linux")
      echo -ne "arch"
      ;;
    "ubuntu" | "ubuntu linux")
      echo -ne "ubuntu"
      ;;
    "kali" | "kali linux")
      echo -ne "kali"
      ;;
    *)
      echo -ne "unknown"
      return 1
      ;;
  esac

  return 0
}

# Check which dependencies need to be installed for all machines
# -------------------------------------------
# @ Argument: {STRING} --> OS to check depedencies for (e.g. macos, arch, kali, ubuntu, etc.)
# @ Usage: check-deps "os_name"
# @ Return: 0 or 1 (success / failure)
# -------------------------------------------
# @ Global Variables:
# --> $pkgs_to_install
# -------------------------------------------
# shellcheck disable=SC2120
check-deps() {
  # Which OS to check dependencies for
  # @default: pkgs that are required on ALL systems
  local os_to_check=${1:-"all"}

  # Dependencies to check for
  local deps_to_check=""

  case "$os_to_check" in
    "all")
      deps_to_check=$req_deps_all
      ;;
    "macos")
      deps_to_check=$req_deps_macos
      ;;
    "kali")
      deps_to_check=$req_deps_kali
      ;;
    "ubuntu")
      deps_to_check=$req_deps_ubuntu
      ;;
    "arch")
      deps_to_check=$req_deps_arch
      ;;
    *)
      # Not recognized OS to check
      echo >&2 "$scriptName ${RED}[ERROR]${NS}: Unrecognized OS to check in arguments"
      return 1
  esac

  for dep in $deps_to_check; do
    # Check if the command is valid in this system
    # If the command is not valid, add it to the list of
    # dependencies to install later
    is-installed "$dep" || pkgs_to_install+=("$dep")
  done

  # Return success
  return 0
}

# Rename the root dotfiles directory
# -----------------------------------------------------------
# @ Arguments: NONE
# -----------------------------------------------------------
# @ Usage: rename-dotfiles_dir
# @ Return: 0 on success, non-zero on failure
# -----------------------------------------------------------
# @ Global Variables: NONE
# -----------------------------------------------------------
rename-dotfiles_dir() {
  # Check to see if the directory is already renamed
  if [ ! -d "$HOME/.dotfiles" ]; then
    # The root directory is not yet renamed to be hidden
    print-msg "Renaming root dotfiles directory... "

    # Rename the root directory to make it hidden
    # and catch any errors if the command fails
    if ! mv "$HOME/dotfiles" "$HOME/.dotfiles" >/dev/null 2>&1; then
      # There was an error with the rename operation
      print-msg "${RED}[ERROR]${NS}: There was an error renaming the dotfiles directory\n"
      return 1
    else
      print-msg "${GREEN}[DONE]${NS}: Successfully renamed dotfiles\n"
    fi
  else
    print-msg "${ORANGE}[WARN]${NS}: Dotfiles directory already renamed\n"
    return 0
  fi
}

# Creates symbolic links to $HOME from $configFilesDir
# -----------------------------------------------------------
# @ Arguments: NONE
# -----------------------------------------------------------
# @ Usage: symlink-files
# @ Return: 0 on success, non-zero on failure
# -----------------------------------------------------------
# @ Global Variables: NONE
# -----------------------------------------------------------
symlink-files() {
  print-msg "Checking source directory for config files... "

  # Stores the current filename in the below loop
  local filename=""

  # Double check that the source directory is valid
  if [ -d "$configFilesDir" ]; then
    # "$configFilesDir" is a valid directory
    print-msg "${GREEN}[done]${NS}\n"

    # Loop through each file in the "$configFilesDir" directory
    for filepath in "$configFilesDir"/*; do
      # Get the base file name
      filename=$(basename "$filepath")

      print-msg "Creating symlink for '$filepath'... "

      # Create a symlink with the current file in the loop
      # and symlink it to the ~/ directory
      if ln -s "$filepath" "$HOME/.$filename" >/dev/null 2>&1; then
        # Error creating symbolic link
        print-msg "${GREEN}[done]${NS}\n"
      else
        # Error creating symbolic link
        print-msg "${RED}[error]${NS}: Error creating symbolic link for '$filename'\n"
      fi
    done
  else
    print-msg "${RED}[error]${NS}: Not a valid directory, evaluating: '$configFilesDir'\n"
    return 1
  fi
}

# ------------------------------------- #
# -|     MAIN INSTALLATION LOGIC     |- #
# ------------------------------------- #

# Parse the script arguments (if any)
parse-args "$@"

# Get the name of the OS we're running on currently
# Possible values: macos, arch, ubuntu, kali or unknown
os_name=$(get-os-name)

# ------------------ #
# CHECK DEPENDENCIES #
# ------------------ #

# Check all required dependencies
# Check required dependencies for this specific OS we're running on

# Check which method we're going to use to install the packages
# pacman, yay, apt, brew, npm, curl, etc.

# -------------------- #
# INSTALL DEPENDENCIES #
# -------------------- #

# Check if $pkgs_to_install is empty or not
# --> If it isn't empty, proceed to install the dependencies

# Install missing dependencies

# --> If it is empty, skip and proceed to next step

# ------------------- #
# RENAME DOTFILES DIR #
# ------------------- #

# Rename the dotfiles root directory
# and exit if it fails
if ! rename-dotfiles_dir; then
  echo -e "${RED}[ERROR]${NS}: Error with the 'rename-dotfiles_dir' function"
  exit 1
fi

# -------------------- #
# SYMLINK CONFIG FILES #
# -------------------- #

if ! symlink-files; then
  echo -e "${RED}[ERROR]${NS}: Error with the 'symlink-files' function"
  exit 1
fi


# ------------------- #
# CHANGE SHELL TO ZSH #
# ------------------- #

echo -ne "Ensuring zsh is installed... "

# # Check to be sure that zsh is already installed
if ! is_installed zsh >/dev/null 2>&1; then
  # zsh is not installed
  echo >&2 -ne "${RED}zsh not currently installed${NS}\n"
  exit 1
fi

echo -ne "${GREEN}[DONE]${NS}\n"

echo -ne "Checking if zsh is set as the shell... "

# Check if zsh is the shell already or not
if [[ "$(echo $SHELL)" != *"zsh"* ]]; then
  # zsh IS NOT set for the shell yet
  echo -ne "${RED}[DONE]${NS}: The current shell is not using zsh\n"
  echo -e "Trying running this command to set the default shell to ${ITALIC}'zsh'${NS}:\n\n"
  echo -e "\t sudo chsh -s \"$(which zsh)\"\n"
  echo -e "\nThen run this command to start using the ${ITALIC}zshrc${NS} config file\n\n"
  echo -e "\t . ~/.zshrc"
  exit 1
fi

# ------------------------------ #
# GRACEFULLY EXIT INSTALL SCRIPT #
# ------------------------------ #
