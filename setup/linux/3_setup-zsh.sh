#!/bin/bash

################################################################################
#                                                                              #
#   ███████╗███████╗██╗  ██╗    ███████╗███████╗████████╗██╗   ██╗██████╗    #
#   ╚══███╔╝██╔════╝██║  ██║    ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗   #
#     ███╔╝ ███████╗███████║    ███████╗█████╗     ██║   ██║   ██║██████╔╝   #
#    ███╔╝  ╚════██║██╔══██║    ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝    #
#   ███████╗███████║██║  ██║    ███████║███████╗   ██║   ╚██████╔╝██║        #
#   ╚══════╝╚══════╝╚═╝  ╚═╝    ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝        #
#                                                                              #
#                     Automated Zsh Setup Script v1.0                          #
#                         For Debian/Ubuntu Systems                            #
#                                                                              #
################################################################################

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
LOG_FILE="${HOME}/.zsh_setup_$(date +%Y%m%d_%H%M%S).log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

################################################################################
# Helper Functions
################################################################################

print_banner() {
    echo ""
    echo "=============================================================================="
    echo -e "${BLUE}$1${NC}"
    echo "=============================================================================="
    echo ""
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[i]${NC} $1"
}

check_command() {
    command -v "$1" &> /dev/null
}

################################################################################
# Main Installation Functions
################################################################################

install_zsh() {
    print_banner "STEP 1: Installing Zsh"

    if check_command zsh; then
        print_info "Zsh is already installed!"
        zsh --version || print_error "Failed to get zsh version"
    else
        print_info "Installing Zsh..."
        sudo apt update || { print_error "Failed to update package lists"; return 1; }
        sudo apt install -y zsh || { print_error "Failed to install zsh"; return 1; }

        # Verify installation
        if check_command zsh; then
            print_success "Zsh installed successfully!"
            zsh --version
        else
            print_error "Zsh installation verification failed"
            return 1
        fi
    fi
}

install_ohmyzsh() {
    print_banner "STEP 2: Installing Oh My Zsh"

    if [ -d "$HOME/.oh-my-zsh" ]; then
        print_info "Oh My Zsh is already installed!"
    else
        print_info "Installing Oh My Zsh..."

        # Check if curl is available
        if ! check_command curl; then
            print_error "curl is required but not installed"
            print_info "Installing curl..."
            sudo apt install -y curl || { print_error "Failed to install curl"; return 1; }
        fi

        if sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended 2>&1; then
            # Verify installation
            if [ -d "$HOME/.oh-my-zsh" ]; then
                print_success "Oh My Zsh installed successfully!"
            else
                print_error "Oh My Zsh installation verification failed"
                return 1
            fi
        else
            print_error "Failed to install Oh My Zsh"
            return 1
        fi
    fi
}

install_plugins() {
    print_banner "STEP 3: Installing Zsh Plugins"

    local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    # Check if git is available
    if ! check_command git; then
        print_error "git is required but not installed"
        print_info "Installing git..."
        sudo apt install -y git || { print_error "Failed to install git"; return 1; }
    fi

    # Install zsh-autosuggestions
    local autosuggestions_dir="${zsh_custom}/plugins/zsh-autosuggestions"
    if [ -d "$autosuggestions_dir" ]; then
        print_info "zsh-autosuggestions already installed!"
    else
        print_info "Installing zsh-autosuggestions..."
        if git clone https://github.com/zsh-users/zsh-autosuggestions "$autosuggestions_dir" 2>&1; then
            print_success "zsh-autosuggestions installed!"
        else
            print_error "Failed to install zsh-autosuggestions"
            return 1
        fi
    fi

    # Install zsh-syntax-highlighting
    local syntax_dir="${zsh_custom}/plugins/zsh-syntax-highlighting"
    if [ -d "$syntax_dir" ]; then
        print_info "zsh-syntax-highlighting already installed!"
    else
        print_info "Installing zsh-syntax-highlighting..."
        if git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$syntax_dir" 2>&1; then
            print_success "zsh-syntax-highlighting installed!"
        else
            print_error "Failed to install zsh-syntax-highlighting"
            return 1
        fi
    fi
}

install_powerlevel10k() {
    print_banner "STEP 4: Installing Powerlevel10k Theme"

    local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    local p10k_dir="${zsh_custom}/themes/powerlevel10k"

    if [ -d "$p10k_dir" ]; then
        print_info "Powerlevel10k already installed!"
    else
        print_info "Installing Powerlevel10k..."
        if git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir" 2>&1; then
            print_success "Powerlevel10k installed!"
        else
            print_error "Failed to install Powerlevel10k"
            return 1
        fi
    fi
}

configure_zshrc() {
    print_banner "STEP 5: Configuring .zshrc"

    local zshrc="$HOME/.zshrc"

    # Check if .zshrc exists
    if [ ! -f "$zshrc" ]; then
        print_error ".zshrc not found at $zshrc"
        print_info "Oh My Zsh installation may have failed"
        return 1
    fi

    # Backup existing .zshrc
    local backup_file="${zshrc}.backup.$(date +%Y%m%d_%H%M%S)"
    if cp "$zshrc" "$backup_file" 2>&1; then
        print_info "Backed up existing .zshrc to $backup_file"
    else
        print_error "Failed to backup .zshrc"
        return 1
    fi

    # Update theme
    print_info "Setting Powerlevel10k theme..."
    if grep -q "^ZSH_THEME=" "$zshrc"; then
        sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$zshrc" || {
            print_error "Failed to update ZSH_THEME"
            return 1
        }
    else
        echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> "$zshrc" || {
            print_error "Failed to add ZSH_THEME"
            return 1
        }
    fi

    # Update plugins
    print_info "Enabling plugins..."
    if grep -q "^plugins=" "$zshrc"; then
        sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "$zshrc" || {
            print_error "Failed to update plugins"
            return 1
        }
    else
        echo "plugins=(git zsh-autosuggestions zsh-syntax-highlighting)" >> "$zshrc" || {
            print_error "Failed to add plugins"
            return 1
        }
    fi

    # Add custom aliases if not already present
    print_info "Adding custom aliases..."
    if ! grep -q "# Custom aliases added by setup script" "$zshrc"; then
        cat >> "$zshrc" << 'EOF'

# Custom aliases added by setup script
alias ll="ls -ltra"
alias gd="git diff"
alias gcmsg="git commit -m"
alias gitc="git checkout"
alias gitm="git checkout master"
EOF
        if [ $? -eq 0 ]; then
            print_success "Custom aliases added!"
        else
            print_error "Failed to add custom aliases"
            return 1
        fi
    else
        print_info "Custom aliases already present in .zshrc"
    fi

    print_success ".zshrc configured successfully!"
}

set_default_shell() {
    print_banner "STEP 6: Setting Zsh as Default Shell"

    local zsh_path
    zsh_path="$(command -v zsh)" || { print_error "zsh command not found"; return 1; }

    if [ "$SHELL" = "$zsh_path" ]; then
        print_info "Zsh is already your default shell!"
    else
        print_info "Changing default shell to Zsh at $zsh_path..."
        if chsh -s "$zsh_path" 2>&1; then
            print_success "Default shell changed to Zsh!"
            print_info "You'll need to log out and log back in for this to take effect."
        else
            print_error "Failed to change default shell"
            print_info "You can manually run: chsh -s $zsh_path"
            return 1
        fi
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    clear
    
    cat << "EOF"
    
    ╔═══════════════════════════════════════════════════════════════════════╗
    ║                                                                       ║
    ║   ███████╗███████╗██╗  ██╗    ███████╗███████╗████████╗██╗   ██╗██╗ ║
    ║   ╚══███╔╝██╔════╝██║  ██║    ██╔════╝██╔════╝╚══██╔══╝██║   ██║██║ ║
    ║     ███╔╝ ███████╗███████║    ███████╗█████╗     ██║   ██║   ██║██║ ║
    ║    ███╔╝  ╚════██║██╔══██║    ╚════██║██╔══╝     ██║   ██║   ██║╚═╝ ║
    ║   ███████╗███████║██║  ██║    ███████║███████╗   ██║   ╚██████╔╝██╗ ║
    ║   ╚══════╝╚══════╝╚═╝  ╚═╝    ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝ ║
    ║                                                                       ║
    ║                    AUTOMATED ZSH SETUP SCRIPT                        ║
    ║                                                                       ║
    ╚═══════════════════════════════════════════════════════════════════════╝
    
EOF
    
    print_info "This script will install and configure:"
    echo "  • Zsh shell"
    echo "  • Oh My Zsh framework"
    echo "  • zsh-autosuggestions plugin"
    echo "  • zsh-syntax-highlighting plugin"
    echo "  • Powerlevel10k theme"
    echo "  • Custom aliases"
    echo ""
    
    read -p "Continue with installation? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Installation cancelled."
        exit 1
    fi
    
    # Run installation steps with error handling
    if ! install_zsh; then
        print_error "Zsh installation failed"
        return 1
    fi

    if ! install_ohmyzsh; then
        print_error "Oh My Zsh installation failed"
        return 1
    fi

    if ! install_plugins; then
        print_error "Plugin installation failed"
        return 1
    fi

    if ! install_powerlevel10k; then
        print_error "Powerlevel10k installation failed"
        return 1
    fi

    if ! configure_zshrc; then
        print_error ".zshrc configuration failed"
        return 1
    fi

    if ! set_default_shell; then
        print_error "Setting default shell failed"
        print_info "You may need to manually set zsh as your default shell"
    fi

    # Final message
    print_banner "INSTALLATION COMPLETE!"
    
    cat << "EOF"
    
                              _______________
                             |.------------.|
                             ||  SUCCESS!  ||
                             ||            ||
                             |+------------+|
                             +-..--------..-+
                            .--------------.
                           / /============\ \
                          / /==============\ \
                         /____________________\
                         \____________________/
    
EOF
    
    print_success "Zsh has been successfully installed and configured!"
    echo ""
    print_info "Next steps:"
    echo "  1. Exit your current shell and open a new terminal"
    echo "  2. Run 'p10k configure' to customize your Powerlevel10k theme"
    echo "  3. Enjoy your new shell!"
    echo ""
    print_info "Your old .zshrc has been backed up with a timestamp."
    echo ""
    print_info "Setup log saved to: $LOG_FILE"
    echo ""
    echo "=============================================================================="
    echo -e "${BLUE}                     [ Press ENTER to exit ]${NC}"
    echo "=============================================================================="
    read
}

# Run main function
main

exit 0
