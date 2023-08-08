#!/bin/bash

tldr=/opt/homebrew/bin/tldr

### Update Brew Packages
echo "UPDATING BREW PACKAGES"
brew update && brew upgrade
echo "UPDATED BREW PACKAGES"

### Update TLDR cache
if [[ -f "$tldr" ]];
then
    echo "UPDATING TLDR CACHE"
    tldr -u
    echo "UPDATED TLDR CACHE"
fi

### Check for macOS updates
read -p "Would you like to check for macOS udpates? (Y/N)" OS_UPDATE
    if [[ "$OS_UPDATE"]] =~ [Yy] ]]
    then
        echo "CHECKING FOR 'macOS' UPDATES"
        softwareupdate --list
    else
        echo "ALL UPDATES COMPLETE"
        exit
    fi