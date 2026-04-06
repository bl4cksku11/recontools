#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  External Pentest Tooling — Kali Linux Installer
# ─────────────────────────────────────────────────────────────

set -uo pipefail
 
RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[1;33m'
BLU='\033[0;34m'
GRY='\033[0;90m'
NC='\033[0m'
 
GOBIN="/usr/local/go/bin"
GOPATH_BIN="$HOME/go/bin"
LOG_FILE="/tmp/recon_install.log"
 
pass() { echo -e "${GRN}[+]${NC} $1"; }
fail() { echo -e "${RED}[!]${NC} $1"; }
info() { echo -e "${BLU}[*]${NC} $1"; }
warn() { echo -e "${YLW}[~]${NC} $1"; }
step() { echo -e "\n${GRY}────────────────────────────────────────${NC}"; echo -e "${BLU}[>]${NC} $1"; }
 
check_root() {
    if [[ $EUID -ne 0 ]]; then
        fail "Run as root: sudo bash $0"
        exit 1
    fi
}
 
banner() {
    echo -e "${BLU}"
    echo "  ╔═══════════════════════════════════════════╗"
    echo "  ║   External Pentest Tooling — Kali Setup   ║"
    echo "  ║           bl4cksku11 / ZeroTrust          ║"
    echo "  ╚═══════════════════════════════════════════╝"
    echo -e "${NC}"
}
 
setup_go() {
    step "Checking Go installation"
    if command -v go &>/dev/null; then
        GO_VER=$(go version | awk '{print $3}')
        pass "Go already installed: $GO_VER"
        return
    fi
 
    info "Installing Go..."
    GO_VERSION="1.22.3"
    if wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz; then
        rm -rf /usr/local/go
        tar -C /usr/local -xzf /tmp/go.tar.gz
        rm /tmp/go.tar.gz
        export PATH=$PATH:$GOBIN:$GOPATH_BIN
        if ! grep -q "/usr/local/go/bin" /etc/profile.d/go.sh 2>/dev/null; then
            echo "export PATH=\$PATH:/usr/local/go/bin:$HOME/go/bin" > /etc/profile.d/go.sh
        fi
        pass "Go ${GO_VERSION} installed"
    else
        warn "Go download failed — check your internet connection"
    fi
}
 
install_apt_tools() {
    step "Installing apt packages"
    apt-get update -qq 2>>"$LOG_FILE"
 
    APT_TOOLS=(
        nmap
        curl
        wget
        git
        python3
        python3-pip
        golang-go
        dnsutils
        whois
        jq
        unzip
        libpcap-dev
        build-essential
        pipx
    )
 
    for tool in "${APT_TOOLS[@]}"; do
        if dpkg -s "$tool" &>/dev/null; then
            pass "$tool already installed"
        else
            info "Installing $tool..."
            if apt-get install -y -qq "$tool" 2>>"$LOG_FILE"; then
                pass "$tool installed"
            else
                warn "$tool failed — check $LOG_FILE"
            fi
        fi
    done
}
 
go_install() {
    local name=$1
    local pkg=$2
    export PATH=$PATH:$GOBIN:$GOPATH_BIN
 
    if command -v "$name" &>/dev/null; then
        pass "$name already installed"
        return
    fi
 
    info "Installing $name..."
    if GOPATH="$HOME/go" go install "$pkg" 2>>"$LOG_FILE"; then
        if [[ -f "$GOPATH_BIN/$name" ]]; then
            cp "$GOPATH_BIN/$name" /usr/local/bin/
        fi
        pass "$name installed"
    else
        warn "$name failed — check $LOG_FILE"
    fi
}
 
install_go_tools() {
    step "Installing Go-based tools"
    export PATH=$PATH:$GOBIN:$GOPATH_BIN
 
    go_install "subfinder" "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
    go_install "httpx"     "github.com/projectdiscovery/httpx/cmd/httpx@latest"
    go_install "dnsx"      "github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
    go_install "nuclei"    "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
    go_install "katana"    "github.com/projectdiscovery/katana/cmd/katana@latest"
    go_install "ffuf"      "github.com/ffuf/ffuf/v2@latest"
    go_install "amass"     "github.com/owasp-amass/amass/v4/...@master"
}
 
install_trufflehog() {
    step "Installing TruffleHog"
    if command -v trufflehog &>/dev/null; then
        pass "trufflehog already installed"
        return
    fi
    info "Downloading trufflehog..."
    if curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh \
        | sh -s -- -b /usr/local/bin 2>>"$LOG_FILE"; then
        pass "trufflehog installed"
    else
        warn "trufflehog failed — check $LOG_FILE"
    fi
}
 
install_gitleaks() {
    step "Installing Gitleaks"
    if command -v gitleaks &>/dev/null; then
        pass "gitleaks already installed"
        return
    fi
    info "Fetching latest gitleaks release..."
    GL_VER=$(curl -s https://api.github.com/repos/gitleaks/gitleaks/releases/latest | jq -r '.tag_name' | tr -d 'v')
    if [[ -z "$GL_VER" || "$GL_VER" == "null" ]]; then
        warn "Could not fetch gitleaks version from GitHub API — check $LOG_FILE"
        return
    fi
    GL_URL="https://github.com/gitleaks/gitleaks/releases/download/v${GL_VER}/gitleaks_${GL_VER}_linux_x64.tar.gz"
    if curl -sSL "$GL_URL" -o /tmp/gitleaks.tar.gz 2>>"$LOG_FILE"; then
        tar -xzf /tmp/gitleaks.tar.gz -C /usr/local/bin gitleaks 2>>"$LOG_FILE"
        rm -f /tmp/gitleaks.tar.gz
        pass "gitleaks v${GL_VER} installed"
    else
        warn "gitleaks download failed — check $LOG_FILE"
    fi
}
 
install_cloud_tools() {
    step "Installing cloud enumeration tools"
 
    # ── cloud_enum ──────────────────────────────────────────
    if command -v cloud_enum &>/dev/null || [[ -f /opt/recon-tools/cloud_enum/cloud_enum.py ]]; then
        pass "cloud_enum already installed"
    else
        info "Installing cloud_enum..."
        mkdir -p /opt/recon-tools
        rm -rf /opt/recon-tools/cloud_enum  # clean any partial clone
 
        if git clone -q https://github.com/initstring/cloud_enum.git /opt/recon-tools/cloud_enum 2>>"$LOG_FILE"; then
            # Try pip with --break-system-packages first (needed on Kali / Debian 12+)
            if pip3 install -q --break-system-packages \
                -r /opt/recon-tools/cloud_enum/requirements.txt 2>>"$LOG_FILE"; then
 
                # Write a bash wrapper — more reliable than symlinking a .py file
                cat > /usr/local/bin/cloud_enum << 'WRAPPER'
#!/usr/bin/env bash
exec python3 /opt/recon-tools/cloud_enum/cloud_enum.py "$@"
WRAPPER
                chmod +x /usr/local/bin/cloud_enum
                pass "cloud_enum installed → /usr/local/bin/cloud_enum"
            else
                warn "cloud_enum deps failed — trying pipx..."
                if command -v pipx &>/dev/null; then
                    pipx install /opt/recon-tools/cloud_enum 2>>"$LOG_FILE" \
                        && pass "cloud_enum installed via pipx" \
                        || warn "cloud_enum failed entirely — check $LOG_FILE"
                else
                    warn "cloud_enum failed — install manually: pip3 install --break-system-packages -r /opt/recon-tools/cloud_enum/requirements.txt"
                fi
            fi
        else
            warn "cloud_enum git clone failed — check $LOG_FILE"
        fi
    fi
 
    # ── s3scanner ───────────────────────────────────────────
    if command -v s3scanner &>/dev/null; then
        pass "s3scanner already installed"
    else
        info "Installing s3scanner..."
        if pip3 install -q --break-system-packages s3scanner 2>>"$LOG_FILE"; then
            pass "s3scanner installed"
        else
            warn "s3scanner pip failed — trying pipx..."
            if command -v pipx &>/dev/null; then
                pipx install s3scanner 2>>"$LOG_FILE" \
                    && pass "s3scanner installed via pipx" \
                    || warn "s3scanner failed entirely — check $LOG_FILE"
            else
                warn "s3scanner failed — check $LOG_FILE"
            fi
        fi
    fi
}
 
update_nuclei_templates() {
    step "Updating Nuclei templates"
    if command -v nuclei &>/dev/null; then
        info "Pulling latest templates..."
        if nuclei -update-templates -silent 2>>"$LOG_FILE"; then
            pass "Nuclei templates updated"
        else
            warn "Template update failed — check $LOG_FILE"
        fi
    else
        warn "Nuclei not found — skipping template update"
    fi
}
 
verify_tools() {
    step "Verifying installations"
    echo ""
 
    TOOLS=(
        nmap
        httpx
        nuclei
        subfinder
        amass
        dnsx
        ffuf
        katana
        trufflehog
        gitleaks
        cloud_enum
        s3scanner
        curl
        jq
        whois
    )
 
    ALL_OK=true
    for tool in "${TOOLS[@]}"; do
        if command -v "$tool" &>/dev/null; then
            VER=$( { "$tool" --version 2>/dev/null || "$tool" -version 2>/dev/null || echo "installed"; } | head -1 )
            printf "  ${GRN}✓${NC} %-15s ${GRY}%s${NC}\n" "$tool" "$VER"
        else
            printf "  ${RED}✗${NC} %-15s ${RED}NOT FOUND${NC}\n" "$tool"
            ALL_OK=false
        fi
    done
 
    echo ""
    if $ALL_OK; then
        pass "All tools installed successfully"
    else
        warn "Some tools are missing — review $LOG_FILE"
        warn "Re-run the script or install missing tools manually"
    fi
}
 
path_reminder() {
    step "PATH setup"
    info "Add this to your ~/.bashrc or ~/.zshrc if Go tools aren't found after reboot:"
    echo ""
    echo -e "  ${GRY}export PATH=\$PATH:/usr/local/go/bin:\$HOME/go/bin${NC}"
    echo ""
    info "Apply immediately without reboot:"
    echo -e "  ${GRY}source /etc/profile.d/go.sh${NC}"
}
 
# ─── MAIN ───────────────────────────────────────────────────
 
banner
check_root
 
: > "$LOG_FILE"
 
install_apt_tools
setup_go
install_go_tools
install_trufflehog
install_gitleaks
install_cloud_tools
update_nuclei_templates
verify_tools
path_reminder
 
echo ""
pass "Done. Full log at $LOG_FILE"
echo ""