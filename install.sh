#!/bin/bash
# Installs the required dependencies and symlinks the config files
# VERSION: 0.1.2

# ---------------- #
# GLOBAL VARIABLES #
# ---------------- #

# Process ID of the spinner when it's running
# (the little loading spinner icon that's animated)
_SPIN_PID=""

# Colors for messages
NOSTYLE='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'

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
  Usage: ${BOLD}${FUNCNAME[0]}${NOSTYLE} [${BOLD}-h${NOSTYLE} | ${BOLD}--help${NOSTYLE}] [${BOLD}-v${NOSTYLE} | ${BOLD}--verbose${NOSTYLE}]

  Install the required dependencies and symlink the appropriate files for .dotfiles

  ${DIM}Options:${NOSTYLE}
    ${BOLD}-h${NOSTYLE}, ${BOLD}--help${NOSTYLE}              Display this usage help
    ${BOLD}-v${NOSTYLE}, ${BOLD}--verbose${NOSTYLE}           Print messages verbosely, printing more info"

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

# ---------------- #
# SCRIPT VARIABLES #
# ---------------- #

# General required packages for the config files
# These dependencies are required on all distributions/systems
req_deps_all="exa curl git gh nmap pup nano"

# Required packages for Arch Linux installations
req_deps_arch="yay dhcpcd wpa_supplicant sudo ssh acpi"

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
verbose_mode="disabled"

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
# --> $verbose_mode
# -------------------------------------------
parse-args() {

  # Check if there are any arguments provided
  if [ "$#" -ne 0 ]; then

    # There are arguments provided
    # Transform long options to short ones
    for arg in "$@"; do

      shift

      case "$arg" in
      "--help") set -- "$@" "-h" ;;
      "--verbose") set -- "$@" "-v" ;;
      *) set -- "$@" "$arg" ;;

      esac

    done

    # Parse short options
    while getopts ":hv:" options; do

      # Check the different flags
      case $options in
      # Dispaly the usage information
      "h")
        usage
        exit 0
        ;;
      "v") verbose_mode="enabled" ;;
      # Unrecognized option
      \?)

        # Let them know we have an unrecognized option
        echo >&2 -e "${BOLD}${FUNCNAME[0]}${NOSTYLE}: ${RED}unrecognized option${NOSTYLE} --> $OPTARG"

        # Print the usage information
        usage

        # Exit with an error
        exit 1
        ;;
      :)

        # Signal that one of the options requires an argument and is missing it
        echo >&2 -e "${BOLD}${FUNCNAME[0]}${NOSTYLE}: ${RED}[ERROR]:${NOSTYLE} Option -$OPTARG requires an argument"

        # Print the usage information
        usage

        # Exit with an error
        exit 1
        ;;
      esac

    done

  fi # End - Argument parsing conditional

  # Remove the processed arguments
  shift $((OPTIND - 1))

}

# Function to print messages if we're in verbose mode
# -------------------------------------------
# @ Arguments: [STRING] --> Message to print
# @ Usage: print-verbose "Message to print"
# @ Return: Prints message (no return)
# -------------------------------------------
# @ Global Variables: NONE
# -------------------------------------------
print-it() {

  # Message to print
  local msg="$1"

  # Check if we're running verbosely or not
  if [ "$verbose_mode" == "enabled" ]; then

    #  We ARE printing verbosely
    echo -ne "$msg"

  fi

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

  if [ "$#" -eq 0 ]; then


    echo >&2 "${FUNCNAME[0]} \033[0;31m[ERROR]\033[0m: Command is required but was not found in arguments"
    return 1

  fi

  print-it "Checking for presence of '$1' command... "

  # Allow time to read the message
  sleep 0.5

  if ! command -v "$1" > /dev/null; then

    print-it "\033[0;31m[ERROR]\033[0m: '$1' command not found\n"

    return 1

  fi

  print-it "\033[0;32m[DONE]\033[0m: '$1' command installed\n"

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

  # Check if we're on Linux or macOS
  if [ "$kernel_type" == "darwin" ]; then

    # We're running on macOS
    echo -ne "macos"
    return 0

  fi

  # Otherwise, get the Linux distro we're running on (convert it to lowercase)
  local linux_distro=""
        linux_distro=$(grep -E '^NAME' /etc/os-release | grep -Eio '"[^"]+\"$' | sed 's/"//g' | tr '[:upper:]' '[:lower:]')

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
      echo >&2 "${FUNCNAME[0]} \033[0;31m[ERROR]\033[0m: Unrecognized OS to check in arguments"
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

# ---------------------- #
# -| ARGUMENT PARSING |- #
# ---------------------- #
# Parse the script arguments (if any)
parse-args "$@"

# Get the name of the OS we're running on currently
# Possible values: macos, arch, ubuntu, kali or unknown
os_name=$(get-os_name)

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

# -------------------- #
# SYMLINK CONFIG FILES #
# -------------------- #

# Sym link files in /src/symlinked to ~

# ------------------- #
# CHANGE SHELL TO ZSH #
# ------------------- #

# Change shell to zsh
# NOTE: This may require that we exit the shell and start a new one. This would be the final step for the user to perform

# Change source to ~/.zshrc

# ------------------------------ #
# GRACEFULLY EXIT INSTALL SCRIPT #
# ------------------------------ #