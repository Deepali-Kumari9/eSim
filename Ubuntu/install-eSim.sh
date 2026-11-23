#!/bin/bash
#=============================================================================
#          FILE: install-eSim.sh
# 
#         USAGE: ./install-eSim.sh --install 
#                            OR
#                ./install-eSim.sh --uninstall
#                
#   DESCRIPTION: Installation script for eSim EDA Suite (Ubuntu 25.04 & 24.04)
#
#       AUTHORS: Fahim Khan, Rahul Paknikar, Saurabh Bansode,
#                Sumanto Kar, Partha Singha Roy, Jayanth Tatineni,
#                Anshul Verma, Shiva Krishna Sangati, Harsha Narayana P
#  CONTRIBUTORS: Deepali Kumari (Ubuntu 25.04 Compatibility & Fixes)
#  ORGANIZATION: eSim Team, FOSSEE, IIT Bombay
#       CREATED: Wednesday 15 July 2015 15:26
#      REVISION: November 2026 - Ubuntu 25.04 Support
#=============================================================================

set -e
trap error_exit ERR

# Global variables
config_dir="$HOME/.esim"
config_file="config.ini"
eSim_Home="$(pwd)"
ngspiceFlag=0

error_exit() {
    echo -e "\n\nError! Kindly resolve the above error(s) and try again."
    echo -e "\nAborting Installation...\n"
    exit 1
}

# Function to detect Ubuntu version
get_ubuntu_version() {
    VERSION_ID=$(grep "^VERSION_ID" /etc/os-release | cut -d '"' -f 2)
    FULL_VERSION=$(lsb_release -d 2>/dev/null | grep -oP '\d+\.\d+(\.\d+)?' || echo "$VERSION_ID")
    echo "Detected Ubuntu Version: $VERSION_ID ($FULL_VERSION)"
}

# Function to dispatch to version script if available
run_version_script() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/install-eSim-scripts"
    
    case $VERSION_ID in
        "22.04")
            SCRIPT="$SCRIPT_DIR/install-eSim-22.04.sh"
            ;;
        "23.04")
            SCRIPT="$SCRIPT_DIR/install-eSim-23.04.sh"
            ;;
        "24.04"|"25.04"|"25."*)
            SCRIPT="$SCRIPT_DIR/install-eSim-24.04.sh"
            ;;
        *)
            echo "Unsupported Ubuntu version: $VERSION_ID ($FULL_VERSION)"
            exit 1
            ;;
    esac

    if [[ -f "$SCRIPT" ]]; then
        echo "Running script: $SCRIPT $ARGUMENT"
        bash "$SCRIPT" "$ARGUMENT"
        exit 0
    fi
}

function createConfigFile() {
    echo "Creating eSim configuration..."
    mkdir -p "$config_dir"
    cat <<EOF > "$config_dir/$config_file"
[eSim]
eSim_HOME = $eSim_Home
LICENSE = %(eSim_HOME)s/LICENSE
KicadLib = %(eSim_HOME)s/library/kicadLibrary.tar.xz
IMAGES = %(eSim_HOME)s/images
VERSION = %(eSim_HOME)s/VERSION
MODELICA_MAP_JSON = %(eSim_HOME)s/library/ngspicetoModelica/Mapping.json
EOF
}

function installNghdl() {
    echo "Installing NGHDL..........................."
    if [ -f "nghdl.zip" ]; then
        unzip -o nghdl.zip
    fi
    if [ -d "nghdl" ]; then
        cd nghdl/
        chmod +x install-nghdl.sh
        trap "" ERR
        ./install-nghdl.sh --install
        trap error_exit ERR
        ngspiceFlag=1
        cd ../
    fi
}

function installSky130Pdk() {
    echo "Installing SKY130 PDK......................"
    if [ -f "library/sky130_fd_pr.tar.xz" ]; then
        tar -xJf library/sky130_fd_pr.tar.xz
        sudo rm -rf /usr/share/local/sky130_fd_pr
        sudo mkdir -p /usr/share/local/
        sudo mv sky130_fd_pr /usr/share/local/
        sudo chown -R "$USER:$USER" /usr/share/local/sky130_fd_pr/
    fi
}

function installKicad() {
    echo "Installing KiCad..."
    ubuntu_version=$(grep "^VERSION_ID" /etc/os-release | cut -d '"' -f 2)

    # On Ubuntu 25.04, PPAs for older releases fail (404 Not Found)
    # Ubuntu universe ships KiCad 8 natively
    if [[ "$ubuntu_version" == "25.04" || "$ubuntu_version" == "25."* ]]; then
        echo "Ubuntu 25.04 detected: Installing KiCad 8 from official Ubuntu Universe repositories..."
        sudo apt-get update -qq || true
        sudo apt-get install -y --no-install-recommends kicad kicad-footprints kicad-libraries kicad-symbols kicad-templates
    else
        kicadppa="kicad/kicad-8.0-releases"
        if ! grep -q "^deb .*${kicadppa}" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
            echo "Adding KiCad-8 PPA..."
            sudo add-apt-repository -y "ppa:$kicadppa" || true
            sudo apt-get update -qq || true
        fi
        sudo apt-get install -y --no-install-recommends kicad kicad-footprints kicad-libraries kicad-symbols kicad-templates
    fi
    echo "KiCad installation completed successfully!"
}

function installDependency() {
    set +e
    trap "" ERR
    echo "Updating apt index files..................."
    sudo apt-get update -qq
    set -e
    trap error_exit ERR

    echo "Installing system packages and Python environment..."
    sudo apt-get install -y python3-venv python3-pip python3-setuptools \
        python3-pyqt5 python3-pyqt5.qsci python3-pyqt5.qtsvg \
        python3-matplotlib python3-numpy python3-scipy python3-psutil \
        xterm libcanberra-gtk3-module

    echo "Setting up virtual environment in $config_dir/env..."
    mkdir -p "$config_dir"
    rm -rf "$config_dir/env"
    python3 -m venv --system-site-packages "$config_dir/env"
    
    echo "Activating virtual environment..."
    source "$config_dir/env/bin/activate"

    echo "Upgrading pip and installing python dependencies..."
    pip install --upgrade pip setuptools wheel
    pip install watchdog
    pip install --upgrade https://github.com/hdl/pyhdlparser/tarball/master || pip install pyhdlparser || true
    pip install sandpiper-saas || true
}

function copyKicadLibrary() {
    echo "Configuring KiCad Library..."
    if [ -f "library/kicadLibrary.tar.xz" ]; then
        tar -xJf library/kicadLibrary.tar.xz -C library || true
    fi

    # Dynamically detect installed KiCad version (supports 8.0, 7.0, 6.0)
    kicad_config_dir="$HOME/.config/kicad"
    latest_version="8.0"
    if [ -d "$kicad_config_dir" ]; then
        detected=$(ls "$kicad_config_dir" | grep -E "^[0-9]+\.[0-9]+$" | sort -V | tail -n 1)
        [ -n "$detected" ] && latest_version="$detected"
    fi

    kicad_version_dir="$kicad_config_dir/$latest_version"
    mkdir -p "$kicad_version_dir"
    echo "Configuring KiCad symbol table for KiCad $latest_version in $kicad_version_dir..."

    if [ -f "library/kicadLibrary/template/sym-lib-table" ]; then
        cp library/kicadLibrary/template/sym-lib-table "$kicad_version_dir/"
    fi

    kicad_symbols_dir="/usr/share/kicad/symbols"
    if [ -d "library/kicadLibrary/eSim-symbols" ]; then
        sudo mkdir -p "$kicad_symbols_dir"
        sudo cp -r library/kicadLibrary/eSim-symbols/* "$kicad_symbols_dir/" || true
        sudo chown -R "$USER:$USER" "$kicad_symbols_dir" || true
    fi
    rm -rf library/kicadLibrary
    echo "KiCad Library successfully configured!"
}

function createDesktopStartScript() {
    echo "Creating eSim application launcher..."
    sudo bash -c "cat << 'EOF' > /usr/bin/esim
#!/bin/bash
export ESIM_HOME=\"$eSim_Home\"
if [ -f \"$config_dir/env/bin/activate\" ]; then
    source \"$config_dir/env/bin/activate\"
fi
export PYTHONPATH=\"\$ESIM_HOME/src:\$ESIM_HOME/src/frontEnd:\$PYTHONPATH\"
cd \"\$ESIM_HOME/src/frontEnd\"
exec python3 Application.py \"\$@\"
EOF"
    sudo chmod 755 /usr/bin/esim

    mkdir -p "$HOME/.local/share/applications"
    cat <<EOF > "$HOME/.local/share/applications/esim.desktop"
[Desktop Entry]
Version=1.0
Name=eSim
Comment=Open Source EDA Tool
Exec=/usr/bin/esim
Icon=$config_dir/logo.png
Terminal=false
Type=Application
Categories=Development;Engineering;Electronics;
StartupNotify=true
EOF
    chmod +x "$HOME/.local/share/applications/esim.desktop"
    [ -f "images/logo.png" ] && cp images/logo.png "$config_dir/" || true
}

####################################################################
#                   MAIN EXECUTION                                 #
####################################################################

if [ "$#" -ne 1 ]; then
    echo "USAGE : "
    echo "./install-eSim.sh --install"
    echo "./install-eSim.sh --uninstall"
    exit 1
fi

ARGUMENT=$1
if [[ "$ARGUMENT" != "--install" && "$ARGUMENT" != "--uninstall" ]]; then
    echo "Invalid argument: $ARGUMENT"
    echo "Usage: $0 --install | --uninstall"
    exit 1
fi

get_ubuntu_version

# Try running sub-script if present, otherwise execute inline installation
if [ -d "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/install-eSim-scripts" ]; then
    run_version_script
fi

# Fallback: Inline execution
if [[ "$ARGUMENT" == "--install" ]]; then
    createConfigFile
    installDependency
    installKicad
    copyKicadLibrary
    installNghdl
    installSky130Pdk
    createDesktopStartScript
    echo -e "\n\n========================================================"
    echo " eSim installation completed successfully on Ubuntu $VERSION_ID!"
    echo " Run 'esim' to launch the application."
    echo "========================================================"
fi
