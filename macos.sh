#!/bin/zsh
# Sets general macOS defaults. Run with `just link`
# Some changes require a logout/restart to take full effect.
set -e

# ----------------------------------------------------------------------------
# Finder
# ----------------------------------------------------------------------------

# show hidden files by default
defaults write com.apple.finder AppleShowAllFiles -bool true

# show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# show status bar
defaults write com.apple.finder ShowStatusBar -bool true

# show path bar
defaults write com.apple.finder ShowPathbar -bool true

# display full POSIX path as Finder window title
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# search the current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# avoid creating .DS_Store files on network volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

# use column view in all Finder windows by default
defaults write com.apple.finder FXPreferredViewStyle -string "clmv"

# show the ~/Library folder
chflags nohidden ~/Library

# ----------------------------------------------------------------------------
# Dock
# ----------------------------------------------------------------------------

# enable Dock auto-hide
defaults write com.apple.dock autohide -bool true

# do not show recent applications in the Dock
defaults write com.apple.dock show-recents -bool false

# set the icon size of Dock items (in pixels)
defaults write com.apple.dock tilesize -int 48

# ----------------------------------------------------------------------------
# Keyboard
# ----------------------------------------------------------------------------

# enable fast key repeat (requires reboot to take full effect)
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# disable press-and-hold for keys in favor of key repeat
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# ----------------------------------------------------------------------------
# Text input
# ----------------------------------------------------------------------------

# disable smart quotes and dashes (a must for writing code)
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# ----------------------------------------------------------------------------
# Screenshots
# ----------------------------------------------------------------------------

# save screenshots to the Desktop
defaults write com.apple.screencapture location -string "${HOME}/Desktop"

# save screenshots as PNGs
defaults write com.apple.screencapture type -string "png"

# disable shadow in window screenshots
defaults write com.apple.screencapture disable-shadow -bool true

# ----------------------------------------------------------------------------
# Safari
# ----------------------------------------------------------------------------

# show the full URL in the address bar
defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true

# enable the Develop menu and Web Inspector
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true

# ----------------------------------------------------------------------------
# Misc
# ----------------------------------------------------------------------------

# expand save/print panels by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# automatically quit the printer app once print jobs complete
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

# require password immediately after sleep/screensaver begins
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# ----------------------------------------------------------------------------
# Sharing
# ----------------------------------------------------------------------------

# enable Remote Login (sshd) for incoming ssh connections
# note: requires Full Disk Access for the terminal running this script
sudo systemsetup -setremotelogin on || echo "warning: could not enable Remote Login (grant Full Disk Access or toggle it in System Settings -> General -> Sharing)"

# ----------------------------------------------------------------------------
# Apply changes
# ----------------------------------------------------------------------------

# most changes need affected apps to be restarted for them to take effect (done using justfile)
