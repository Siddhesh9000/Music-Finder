#!/bin/bash
# Enable debug logging (set DEBUG=1 for extra logs)
DEBUG=1
debug() {
    if [ "$DEBUG" -eq 1 ]; then
        echo "DEBUG: $1"
    fi
}

# Define installation directory for binaries
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

# Determine OS type
OS_TYPE=$(uname -s)
debug "OS_TYPE is $OS_TYPE"

# Set flag to choose GUI backend:
# If running on Windows (MINGW/CYGWIN), use PowerShell dialogs.
USE_POWERSHELL_GUI=0
if [[ "$OS_TYPE" == MINGW* || "$OS_TYPE" == CYGWIN* ]]; then
    USE_POWERSHELL_GUI=1
    echo "Detected Windows. Using PowerShell dialogs for GUI."
fi

# Function to install a dependency by downloading it if not already present
install_dependency() {
    local name="$1"
    local url="$2"
    local dest="$BIN_DIR/$name"
    if [[ ! -f "$dest" ]]; then
        echo "Installing $name from $url..."
        if [[ "$OS_TYPE" == "Linux" || "$OS_TYPE" == "Darwin" ]]; then
            if command -v wget &>/dev/null; then
                wget -O "$dest" "$url"
            elif command -v curl &>/dev/null; then
                curl -L --fail "$url" -o "$dest"
            else
                echo "Error: wget or curl is required to download $name."
                exit 1
            fi
        else
            # Windows: Use curl with verbose output
            if command -v curl &>/dev/null; then
                debug "Using curl to download $name"
                curl -v -L --fail -H "User-Agent: Mozilla/5.0" -H "Accept: application/octet-stream" "$url" -o "$dest"
            else
                echo "Error: curl is required on Windows."
                exit 1
            fi
        fi
        chmod +x "$dest"
    else
        debug "$name already installed at $dest"
    fi
}

# Install FFmpeg (specifically for Windows)
install_ffmpeg() {
    if [[ "$OS_TYPE" == MINGW* || "$OS_TYPE" == CYGWIN* ]]; then
        local FFMPEG_DIR="$BIN_DIR/ffmpeg"
        local FFMPEG_EXE="$BIN_DIR/ffmpeg.exe"
        local FFPROBE_EXE="$BIN_DIR/ffprobe.exe"
        
        if [[ ! -f "$FFMPEG_EXE" || ! -f "$FFPROBE_EXE" ]]; then
            echo "Installing FFmpeg for Windows..."
            # Create temporary directory for extraction
            local TEMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'ffmpeg-temp')
            debug "Created temp directory: $TEMP_DIR"
            
            # Download FFmpeg zip file
            local FFMPEG_URL="https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
            local ZIP_FILE="$TEMP_DIR/ffmpeg.zip"
            
            debug "Downloading FFmpeg from $FFMPEG_URL to $ZIP_FILE"
            curl -L --fail "$FFMPEG_URL" -o "$ZIP_FILE"
            
            # Extract the ZIP file
            echo "Extracting FFmpeg..."
            if command -v unzip &>/dev/null; then
                unzip -q "$ZIP_FILE" -d "$TEMP_DIR"
            else
                # Use PowerShell to extract if unzip is not available
                powershell -NoProfile -Command "Expand-Archive -Path \"$ZIP_FILE\" -DestinationPath \"$TEMP_DIR\" -Force"
            fi
            
            # Find and copy FFmpeg and FFprobe executables
            local FFM_BIN_DIR=$(find "$TEMP_DIR" -type d -name "bin" -print | head -n 1)
            debug "FFmpeg bin directory: $FFM_BIN_DIR"
            
            if [[ -d "$FFM_BIN_DIR" ]]; then
                cp "$FFM_BIN_DIR/ffmpeg.exe" "$BIN_DIR/"
                cp "$FFM_BIN_DIR/ffprobe.exe" "$BIN_DIR/"
                debug "Copied FFmpeg binaries to $BIN_DIR"
            else
                echo "Error: Could not find FFmpeg binaries in the extracted archive."
                gui_error "Failed to install FFmpeg. Please install it manually."
            fi
            
            # Clean up temporary directory
            rm -rf "$TEMP_DIR"
        else
            debug "FFmpeg already installed"
        fi
    else
        # For Linux/macOS, try to install ffmpeg using the package manager
        if command -v apt-get &>/dev/null; then
            sudo apt-get install -y ffmpeg 2>/dev/null
        elif command -v yum &>/dev/null; then
            sudo yum install -y ffmpeg 2>/dev/null
        elif command -v brew &>/dev/null; then
            brew install ffmpeg 2>/dev/null
        else
            echo "Warning: Could not install FFmpeg. Please install it manually."
        fi
    fi
}

# On Linux/macOS, try to install missing tools via apt (using sudo) if available
if [[ "$OS_TYPE" == "Linux" || "$OS_TYPE" == "Darwin" ]]; then
    sudo apt update -y 2>/dev/null
    sudo apt install -y wget curl zenity jq ffmpeg 2>/dev/null
fi

# Install yt-dlp and jq (use .exe for Windows)
if [[ "$OS_TYPE" == "Linux" || "$OS_TYPE" == "Darwin" ]]; then
    install_dependency "yt-dlp" "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp"
    install_dependency "jq" "https://github.com/stedolan/jq/releases/latest/download/jq"
else
    install_dependency "yt-dlp.exe" "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe"
    install_dependency "jq.exe" "https://github.com/stedolan/jq/releases/latest/download/jq-win64.exe"
    
    # Install FFmpeg for Windows
    install_ffmpeg
fi

# For non-Windows systems, install Zenity (AppImage) for the GUI
if [ "$USE_POWERSHELL_GUI" -eq 0 ]; then
    ZENITY_APPIMAGE="$BIN_DIR/zenity"
    if [[ ! -f "$ZENITY_APPIMAGE" ]]; then
        echo "Downloading Zenity..."
        install_dependency "zenity" "https://github.com/philippnormann/zenity-appimage/releases/download/continuous/Zenity-x86_64.AppImage"
    fi
    # Verify Zenity file size (expecting >1MB)
    if command -v stat &>/dev/null; then
        ZENITY_SIZE=$(stat -c%s "$ZENITY_APPIMAGE" 2>/dev/null || stat -f%z "$ZENITY_APPIMAGE")
    else
        ZENITY_SIZE=$(wc -c < "$ZENITY_APPIMAGE")
    fi
    debug "Zenity file size: $ZENITY_SIZE bytes"
    if [[ "$ZENITY_SIZE" -lt 1000000 ]]; then
        echo "Zenity download appears to be too small ($ZENITY_SIZE bytes)."
        echo "First 100 bytes of the downloaded file:"
        head -c 100 "$ZENITY_APPIMAGE"
        echo ""
        echo "It seems the file did not download correctly."
        exit 1
    fi
fi

# Ensure BIN_DIR is in PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    export PATH="$BIN_DIR:$PATH"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    source "$HOME/.bashrc" 2>/dev/null || true
fi

# Define GUI functions based on the backend
if [ "$USE_POWERSHELL_GUI" -eq 1 ]; then
    # Windows using PowerShell dialogs
    function gui_entry() {
        local prompt="$1"
        local title="${2:-Music Finder}"
        local result
        result=$(powershell -NoProfile -Command "[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic') | Out-Null; [Microsoft.VisualBasic.Interaction]::InputBox('$prompt', '$title', '')")
        echo "$result"
    }
    function gui_info() {
        local message="$1"
        local title="${2:-Info}"
        powershell -NoProfile -Command "[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null; [System.Windows.Forms.MessageBox]::Show('$message', '$title', 'OK', 'Information')"
    }
    function gui_error() {
        local message="$1"
        local title="${2:-Error}"
        powershell -NoProfile -Command "[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null; [System.Windows.Forms.MessageBox]::Show('$message', '$title', 'OK', 'Error')"
    }
    function gui_progress() {
        # Simple console output for progress on Windows
        echo "$1"
    }
else
    # Non-Windows, use Zenity
    function gui_entry() {
        "$ZENITY_APPIMAGE" --entry --title="Music Finder" --text="$1"
    }
    function gui_info() {
        "$ZENITY_APPIMAGE" --info --text="$1"
    }
    function gui_error() {
        "$ZENITY_APPIMAGE" --error --text="$1"
    }
    function gui_progress() {
        "$ZENITY_APPIMAGE" --progress --title="Downloading" --text="$1" --pulsate --auto-close
    }
fi

# Function to download music using the chosen GUI
download_music() {
    local song
    song=$(gui_entry "Enter song name:")
    if [[ -z "$song" ]]; then
        gui_error "No song entered!"
        exit 1
    fi
    gui_info "Searching for: $song"
    
    # Create Music directory if it doesn't exist
    MUSIC_DIR="$HOME/Music"
    mkdir -p "$MUSIC_DIR"
    debug "Music directory: $MUSIC_DIR"
    
    # Convert to Windows path format if needed
    if [[ "$OS_TYPE" == MINGW* || "$OS_TYPE" == CYGWIN* ]]; then
        MUSIC_DIR=$(cygpath -w "$MUSIC_DIR" 2>/dev/null || echo "$MUSIC_DIR")
        debug "Windows-formatted music directory: $MUSIC_DIR"
    fi
    
    SEARCH_URL="https://www.youtube.com/results?search_query=$(echo "$song" | sed 's/ /+/g')"
    debug "Search URL: $SEARCH_URL"
    
    # Get video ID using a more reliable method
    VIDEO_ID=$(curl -s "$SEARCH_URL" | grep -o 'watch?v=[^"]*' | head -n 1 | cut -d= -f2 | sed 's/&.*$//')
    debug "Found video ID: $VIDEO_ID"
    
    if [[ -z "$VIDEO_ID" ]]; then
        gui_error "No results found!"
        exit 1
    fi
    
    VIDEO_URL="https://www.youtube.com/watch?v=$VIDEO_ID"
    debug "Video URL: $VIDEO_URL"
    
    # Simplified file naming to avoid potential issues
    OUTPUT_TEMPLATE="$MUSIC_DIR/%(title)s.%(ext)s"
    
    if [[ "$OS_TYPE" == MINGW* || "$OS_TYPE" == CYGWIN* ]]; then
        debug "Running yt-dlp.exe on Windows"
        # Specify the path to ffmpeg for yt-dlp
        "$BIN_DIR/yt-dlp.exe" -x --audio-format mp3 --ffmpeg-location "$BIN_DIR" -o "$OUTPUT_TEMPLATE" "$VIDEO_URL"
    else
        debug "Running yt-dlp on Unix"
        yt-dlp -x --audio-format mp3 -o "$OUTPUT_TEMPLATE" "$VIDEO_URL" 
    fi
    
    if [ $? -eq 0 ]; then
        gui_info "Download complete! Saved in $MUSIC_DIR"
    else
        gui_error "Download failed. Check debug output for details."
    fi
}

# Start the music download process
download_music