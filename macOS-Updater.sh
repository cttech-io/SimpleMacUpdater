#!/bin/bash

### Update Brew Packages
echo "Updating brew packages"
brew update && brew upgrade

### Check for macOS updates
read -p "Would you like to check for macOS udpates? (Y/N)" OS_UPDATE
    if [[ "$OS_UPDATE"]] =~ [Yy] ]]
    then
        echo "Checking for macOS updates"
        softwareupdate --list
    else
        exit
    fi