#!/bin/sh
echo "Apply system and application defaults."

echo "System - Disable the 'Are you sure you want to open this application?' dialog"
defaults write com.apple.LaunchServices LSQuarantine -bool false

echo "System - Disable auto-correct"
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

echo "System - Disable smart quotes (not useful when writing code)"
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

echo "System - Disable smart dashes (not useful when writing code)"
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

echo "System - Avoid creating .DS_Store files on network volumes"
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

echo "System - Automatically restart if system freezes"
sudo systemsetup -setrestartfreeze on

echo "Keyboard - Enable keyboard access for all controls"
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

echo "Keyboard - Set a fast keyboard repeat rate"
defaults write NSGlobalDomain KeyRepeat -int 0

echo "Trackpad - Map bottom right corner to right-click"
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick -int 2
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
defaults -currentHost write NSGlobalDomain com.apple.trackpad.trackpadCornerClickBehavior -int 1
defaults -currentHost write NSGlobalDomain com.apple.trackpad.enableSecondaryClick -bool true

echo "Trackpad - Enable tap to click for current user and the login screen"
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

echo "Trackpad - Use CONTROL (^) with scroll to zoom"
defaults write com.apple.universalaccess closeViewScrollWheelToggle -bool true
defaults write com.apple.universalaccess HIDScrollZoomModifierMask -int 262144

echo "Trackpad - Follow keyboard focus while zoomed in"
defaults write com.apple.universalaccess closeViewZoomFollowsFocus -bool true

echo "Bluetooth - Increase sound quality for headphones/headsets"
defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)" -int 40

echo "Dock - Automatically hide and show"
defaults write com.apple.dock autohide -bool true

echo "Dock - Remove the auto-hiding delay"
defaults write com.apple.Dock autohide-delay -float 0

echo "Dock - Don’t show Dashboard as a Space"
defaults write com.apple.dock "dashboard-in-overlay" -bool true

echo "Finder - Show the $HOME/Library folder"
chflags nohidden $HOME/Library

echo "Finder - Show hidden files"
defaults write com.apple.finder AppleShowAllFiles -bool true

echo "Finder - Show filename extensions"
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

echo "Finder - Disable the warning when changing a file extension"
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

echo "Finder - Show path bar"
defaults write com.apple.finder ShowPathbar -bool true

echo "Finder - Show status bar"
defaults write com.apple.finder ShowStatusBar -bool true

echo "Finder - Display full POSIX path as window title"
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

echo "Finder - Use list view in all Finder windows"
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

echo "Finder - Disable the warning before emptying the Trash"
defaults write com.apple.finder WarnOnEmptyTrash -bool false

echo "Finder - Allow text selection in Quick Look"
defaults write com.apple.finder QLEnableTextSelection -bool true

echo "VSCode - Allow key repeat with Vim Mode"
defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false
defaults write com.microsoft.VSCodeInsiders ApplePressAndHoldEnabled -bool false
