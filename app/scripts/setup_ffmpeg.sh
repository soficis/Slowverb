#!/bin/bash
# FFmpeg Installation Script for macOS and Linux
# Run this script to install FFmpeg for Slowverb

set -e

echo "========================================"
echo "  Slowverb FFmpeg Setup Script"
echo "========================================"
echo ""

# Detect operating system
OS="$(uname -s)"
echo "Detected OS: $OS"
echo ""

install_ffmpeg_macos() {
    echo "Installing FFmpeg on macOS..."
    
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        echo "Homebrew not found. Installing Homebrew first..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    echo "Installing FFmpeg via Homebrew..."
    brew install ffmpeg
    
    echo ""
    echo "✅ FFmpeg installed successfully!"
}

install_ffmpeg_linux() {
    echo "Installing FFmpeg on Linux..."
    
    # Detect Linux distribution
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    else
        DISTRO="unknown"
    fi
    
    echo "Detected distribution: $DISTRO"
    
    case $DISTRO in
        ubuntu|debian|pop|mint|elementary)
            echo "Using apt package manager..."
            sudo apt update
            sudo apt install -y ffmpeg
            ;;
        fedora)
            echo "Using dnf package manager..."
            sudo dnf install -y ffmpeg
            ;;
        centos|rhel)
            echo "Using yum package manager..."
            sudo yum install -y epel-release
            sudo yum install -y ffmpeg
            ;;
        arch|manjaro|endeavouros)
            echo "Using pacman package manager..."
            sudo pacman -S --noconfirm ffmpeg
            ;;
        opensuse*)
            echo "Using zypper package manager..."
            sudo zypper install -y ffmpeg
            ;;
        *)
            echo "⚠️  Unknown distribution: $DISTRO"
            echo "Please install FFmpeg manually:"
            echo "  - Ubuntu/Debian: sudo apt install ffmpeg"
            echo "  - Fedora: sudo dnf install ffmpeg"
            echo "  - Arch: sudo pacman -S ffmpeg"
            exit 1
            ;;
    esac
    
    echo ""
    echo "✅ FFmpeg installed successfully!"
}

# Main installation logic
case $OS in
    Darwin)
        install_ffmpeg_macos
        ;;
    Linux)
        install_ffmpeg_linux
        ;;
    *)
        echo "❌ Unsupported operating system: $OS"
        echo "For Windows, please run: scripts/download_ffmpeg.ps1"
        exit 1
        ;;
esac

# Verify installation
echo ""
echo "Verifying FFmpeg installation..."
if command -v ffmpeg &> /dev/null; then
    echo ""
    ffmpeg -version | head -1
    echo ""
    echo "========================================"
    echo "  FFmpeg is ready for Slowverb!"
    echo "========================================"
else
    echo "❌ FFmpeg installation failed."
    echo "Please try installing manually."
    exit 1
fi
