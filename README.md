# Music Finder

A cross-platform utility to easily search for and download music tracks in MP3 format.

## Features

- **Cross-Platform Compatibility**: Works on Windows, macOS, and Linux
- **Simple GUI Interface**: Easy-to-use dialog boxes for entering search terms
- **Automatic Dependency Management**: Automatically installs required tools:
  - yt-dlp for downloading
  - jq for JSON processing
  - FFmpeg for audio conversion
  - Zenity (on non-Windows platforms) for GUI dialogs
- **Intelligent OS Detection**: Uses the appropriate tools for each operating system
  - PowerShell dialogs on Windows
  - Zenity on Linux/macOS
- **Organized Downloads**: Saves all downloaded music to your Music directory

## Requirements

The script handles most dependencies automatically but requires:
- Bash shell (native on Linux/macOS, via Git Bash or WSL on Windows)
- Internet connection
- Basic system permissions to install tools in your home directory

## Installation

1. Clone this repository:
   ```
   git clone https://github.com/Siddhesh9000/music-finder.git
   ```

2. Make the script executable:
   ```
   chmod +x music-finder.sh
   ```

3. Run the script:
   ```
   ./music-finder.sh
   ```

## Usage

1. Run the script
2. Enter the name of the song you want to download when prompted
3. The script will search for the song, download it, and convert it to MP3
4. Downloaded files are saved to your ~/Music directory

## How It Works

1. The script identifies your operating system
2. It installs necessary dependencies in your ~/.local/bin directory
3. It creates a GUI prompt for you to enter a song name
4. It searches YouTube for the song
5. It downloads the first match and converts it to MP3 format
6. It saves the file to your Music directory

## Troubleshooting

- If the script fails to install dependencies, try running it with sudo (on Linux/macOS)
- On Windows, make sure you're running in Git Bash or a similar Bash environment
- If downloads fail, check your internet connection
- Enable debug mode (set DEBUG=1 in the script) for detailed logs

## Legal Disclaimer

This tool is intended for downloading content that you have the right to access. Please respect copyright laws and only download content that you are legally permitted to obtain.
