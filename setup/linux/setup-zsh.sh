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

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    if command -v $1 &> /dev/null; then
        return 0
    else
        return 1
    fi
}

################################################################################
# Main Installation Functions
################################################################################

install_zsh() {
    print_banner "STEP 1: Installing Zsh"
    
    if check_command zsh; then
        print_info "Zsh is already installed!"
        zsh --version
    else
        print_info "Installing Zsh..."
        sudo apt update
        sudo apt install -y zsh
        print_success "Zsh installed successfully!"
    fi
}

install_ohmyzsh() {
    print_banner "STEP 2: Installing Oh My Zsh"
    
    if [ -d "$HOME/.oh-my-zsh" ]; then
        print_info "Oh My Zsh is already installed!"
    else
        print_info "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        print_success "Oh My Zsh installed successfully!"
    fi
}

install_plugins() {
    print_banner "STEP 3: Installing Zsh Plugins"
    
    # Install zsh-autosuggestions
    if [ -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
        print_info "zsh-autosuggestions already installed!"
    else
        print_info "Installing zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions \
            ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
        print_success "zsh-autosuggestions installed!"
    fi
    
    # Install zsh-syntax-highlighting
    if [ -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]; then
        print_info "zsh-syntax-highlighting already installed!"
    else
        print_info "Installing zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
            ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
        print_success "zsh-syntax-highlighting installed!"
    fi
}

install_powerlevel10k() {
    print_banner "STEP 4: Installing Powerlevel10k Theme"
    
    if [ -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
        print_info "Powerlevel10k already installed!"
    else
        print_info "Installing Powerlevel10k..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
            ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
        print_success "Powerlevel10k installed!"
    fi
}

configure_zshrc() {
    print_banner "STEP 5: Configuring .zshrc"
    
    ZSHRC="$HOME/.zshrc"
    
    # Backup existing .zshrc
    if [ -f "$ZSHRC" ]; then
        cp "$ZSHRC" "$ZSHRC.backup.$(date +%Y%m%d_%H%M%S)"
        print_info "Backed up existing .zshrc"
    fi
    
    # Update theme
    print_info "Setting Powerlevel10k theme..."
    sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$ZSHRC"
    
    # Update plugins
    print_info "Enabling plugins..."
    sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "$ZSHRC"
    
    # Add custom aliases if not already present
    print_info "Adding custom aliases..."
    if ! grep -q "# Custom aliases added by setup script" "$ZSHRC"; then
        cat >> "$ZSHRC" << 'EOF'

# Custom aliases added by setup script
alias ll="ls -ltra"
alias gd="git diff"
alias gcmsg="git commit -m"
alias gitc="git checkout"
alias gitm="git checkout master"
EOF
    fi
    
    print_success ".zshrc configured successfully!"
}

set_default_shell() {
    print_banner "STEP 6: Setting Zsh as Default Shell"
    
    if [ "$SHELL" = "$(which zsh)" ]; then
        print_info "Zsh is already your default shell!"
    else
        print_info "Changing default shell to Zsh..."
        chsh -s $(which zsh)
        print_success "Default shell changed to Zsh!"
        print_info "You'll need to log out and log back in for this to take effect."
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
    
    # Run installation steps
    install_zsh
    install_ohmyzsh
    install_plugins
    install_powerlevel10k
    configure_zshrc
    set_default_shell
    
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
    echo "=============================================================================="
    echo -e "${BLUE}                     [ Press ENTER to exit ]${NC}"
    echo "=============================================================================="
    read
}

# Run main function
main

exit 0
