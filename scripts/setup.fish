#!/usr/bin/env fish

# go to script directory
set -l script_dir (dirname (status -f))
cd $script_dir

echo ""
echo "Starting GNOME dotfiles setup..."
echo ""


## install "required" packages (fit to my usecase)
set -l dnf_packages gnome-extensions-app gnome-tweaks fastfetch syncthing spicetify-cli stow curl

for pkg in $dnf_packages
    if not rpm -q "$pkg" >/dev/null 2>&1
        echo "Installing $pkg..."
        sudo dnf install -y $pkg
        echo ""
    else
        echo "$pkg already installed."
    end
end
echo ""

## install spotify
if not flatpak list | grep -q com.spotify.Client
    echo "Installing Spotify via Flatpak..."
    flatpak install -y flathub com.spotify.Client
else    
    echo "Spotify is already installed (Flatpak)."
end
echo ""


## install fisher (to manage fish plugins)
if not functions -q fisher
    echo "Installing Fisher..."
    curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher
else 
    echo "Fisher already installed."
end
echo ""


## stow configs, wallpaper, themes, icons
echo "Symlinking dotfiles with GNU Stow"

for dir in (find . -maxdepth 1 -type d -not -name '.' | string replace './' '')
    if begin; test $dir != ".git"; and test $dir != "scripts"; and test $dir != "images"; end
        echo "Stowing $dir..."
        mkdir -p "$HOME/$dir"
        stow --adopt --target="$HOME/$dir" $dir
    end
end
# change files back to our files after adopting, as they are overwritten with the ones that already were on the system
git restore .
echo ""


## install GNOME extensions
set extensions_file "$script_dir/scripts/extensions.txt"

set extensions_dir "$HOME/.local/share/gnome-shell/extensions"

if test -f $extensions_file
    echo "Installing GNOME extensions from $extensions_file..."
    for uuid in (cat $extensions_file)
        set metadata_url "https://extensions.gnome.org/extension-info/?uuid=$uuid"
        set info (curl -s "$metadata_url")
        set download_url (echo $info | string match -r '"download_url": ?"([^"]+)"' | string replace -r '^.*: ?"([^"]+)"$' '$1')

        if test -n "$download_url"
            set full_url "https://extensions.gnome.org$download_url"
            echo "Downloading $uuid..."
            mkdir -p /tmp/gnome-extensions
            wget -q -O /tmp/gnome-extensions/$uuid.zip "$full_url"
            unzip -qo /tmp/gnome-extensions/$uuid.zip -d $extensions_dir/$uuid
            echo "Installed $uuid"
            gnome-extensions enable $uuid
        else
            echo "Failed to fetch $uuid from extensions.gnome.org"
        end
    end
else 
    echo "No extensions file found at $extensions_file"
end
echo ""


## apply themes
echo "Applying themes for GNOME shell, cursors, applications..."
python3 scripts/theme-changer.py Dracula
echo ""

gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'
gsettings set org.gnome.desktop.interface gtk-theme 'Dracula'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'


## set wallpaper
set wallpaper_path "file://$HOME/Pictures/Wallpaper/Spiderverse.jpg"
if test -f (string replace "file://" "" $wallpaper_path)
    echo "Setting wallpaper"
    gsettings set org.gnome.desktop.background picture-uri "$wallpaper_path"
else
    echo "Wallpaper not found at $wallpaper_path"
end
echo ""

set_color green
echo "Setup complete!"
set_color normal
