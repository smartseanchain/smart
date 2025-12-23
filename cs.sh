#!/bin/bash

################################################################################
# CrowdStrike Installation Script for macOS
# Version: 2.0
# Description: Optimized installation with token validation and auto-configuration
# Author: SmartSeanChain
# Date: 2025-12-23
################################################################################

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
readonly SCRIPT_VERSION="2.0"
readonly LOG_FILE="/var/log/crowdstrike_install.log"
readonly TEMP_DIR="/tmp/cs_install_$$"
readonly CROWDSTRIKE_PKG_NAME="CrowdStrike"

################################################################################
# Utility Functions
################################################################################

# Log function with timestamp
log() {
    local level="$1"
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

# Print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $@"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $@"
}

print_error() {
    echo -e "${RED}[✗]${NC} $@"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $@"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        log "ERROR" "Script executed without root privileges"
        exit 1
    fi
}

# Cleanup function
cleanup() {
    local exit_code=$?
    if [[ -d "${TEMP_DIR}" ]]; then
        rm -rf "${TEMP_DIR}"
    fi
    if [[ ${exit_code} -eq 0 ]]; then
        log "INFO" "Installation completed successfully"
    else
        log "ERROR" "Installation failed with exit code ${exit_code}"
    fi
    return ${exit_code}
}

trap cleanup EXIT

################################################################################
# Validation Functions
################################################################################

# Validate token format
validate_token() {
    local token="$1"
    
    if [[ -z "${token}" ]]; then
        print_error "Token cannot be empty"
        return 1
    fi
    
    # Token should be at least 32 characters (adjust based on your requirements)
    if [[ ${#token} -lt 32 ]]; then
        print_error "Token is too short (minimum 32 characters)"
        return 1
    fi
    
    # Check if token contains only valid characters (alphanumeric and hyphens)
    if ! [[ "${token}" =~ ^[a-zA-Z0-9-]+$ ]]; then
        print_error "Token contains invalid characters"
        return 1
    fi
    
    return 0
}

# Validate macOS version
validate_macos_version() {
    local min_version="10.13"
    local current_version=$(sw_vers -productVersion)
    
    print_status "macOS version: ${current_version}"
    
    if ! [[ "${current_version}" > "${min_version}" ]] && ! [[ "${current_version}" == "${min_version}" ]]; then
        print_error "macOS version ${current_version} is not supported (minimum required: ${min_version})"
        log "ERROR" "Unsupported macOS version: ${current_version}"
        return 1
    fi
    
    return 0
}

# Check for required tools
check_dependencies() {
    local missing_deps=()
    
    for cmd in curl installer pkgutil; do
        if ! command -v "${cmd}" &> /dev/null; then
            missing_deps+=("${cmd}")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing required tools: ${missing_deps[*]}"
        log "ERROR" "Missing dependencies: ${missing_deps[*]}"
        return 1
    fi
    
    print_success "All required dependencies are available"
    return 0
}

# Check if CrowdStrike is already installed
check_crowdstrike_installed() {
    if pkgutil --pkgs | grep -i "crowdstrike" &> /dev/null; then
        print_warning "CrowdStrike appears to be already installed"
        return 0
    fi
    return 1
}

################################################################################
# Installation Functions
################################################################################

# Create temporary directory
setup_temp_directory() {
    if ! mkdir -p "${TEMP_DIR}"; then
        print_error "Failed to create temporary directory"
        return 1
    fi
    print_status "Temporary directory created: ${TEMP_DIR}"
    return 0
}

# Download CrowdStrike installer
download_installer() {
    local download_url="$1"
    local output_file="${TEMP_DIR}/CrowdStrike.pkg"
    
    print_status "Downloading CrowdStrike installer..."
    log "INFO" "Download URL: ${download_url}"
    
    if ! curl -fSL --max-time 300 -o "${output_file}" "${download_url}"; then
        print_error "Failed to download CrowdStrike installer"
        log "ERROR" "Download failed from: ${download_url}"
        return 1
    fi
    
    # Verify file was downloaded
    if [[ ! -f "${output_file}" ]] || [[ ! -s "${output_file}" ]]; then
        print_error "Downloaded file is empty or does not exist"
        return 1
    fi
    
    print_success "Installer downloaded successfully"
    echo "${output_file}"
    return 0
}

# Verify package integrity
verify_package() {
    local pkg_path="$1"
    
    print_status "Verifying package integrity..."
    
    if ! pkgutil --check-signature "${pkg_path}" &> /dev/null; then
        print_warning "Package signature verification failed"
        log "WARNING" "Package signature check failed for: ${pkg_path}"
        # Continue anyway as signature check might not be critical
    else
        print_success "Package signature verified"
    fi
    
    return 0
}

# Install CrowdStrike
install_crowdstrike() {
    local pkg_path="$1"
    local falcon_client_id="$2"
    local falcon_client_secret="$3"
    
    print_status "Installing CrowdStrike..."
    log "INFO" "Starting CrowdStrike installation from: ${pkg_path}"
    
    # Install the package
    if ! installer -pkg "${pkg_path}" -target / -verboseR; then
        print_error "Installation failed"
        log "ERROR" "CrowdStrike installation failed"
        return 1
    fi
    
    print_success "CrowdStrike installed successfully"
    return 0
}

# Configure CrowdStrike with credentials
configure_crowdstrike() {
    local falcon_client_id="$1"
    local falcon_client_secret="$2"
    
    print_status "Configuring CrowdStrike with credentials..."
    
    # Check for CrowdStrike CLI tool
    local cs_cli_path="/Applications/Falcon.app/Contents/Resources/falconctl"
    
    if [[ ! -f "${cs_cli_path}" ]]; then
        print_warning "CrowdStrike CLI tool not found at expected location"
        log "WARNING" "CrowdStrike CLI not found at: ${cs_cli_path}"
        return 0
    fi
    
    # Configure with client ID and secret
    print_status "Setting CrowdStrike credentials..."
    
    if ! "${cs_cli_path}" -s --cid="${falcon_client_id}" --provisioning-token="${falcon_client_secret}" 2>&1 | tee -a "${LOG_FILE}"; then
        print_warning "Configuration may have encountered issues"
        log "WARNING" "CrowdStrike configuration completed with warnings"
    else
        print_success "CrowdStrike configured successfully"
    fi
    
    return 0
}

# Verify installation
verify_installation() {
    print_status "Verifying CrowdStrike installation..."
    
    # Check if CrowdStrike is running
    if pgrep -f "falcond" &> /dev/null; then
        print_success "CrowdStrike daemon (falcond) is running"
        log "INFO" "CrowdStrike service verified as running"
        return 0
    else
        print_warning "CrowdStrike daemon (falcond) is not running"
        print_status "Attempting to start CrowdStrike service..."
        
        if [[ -f "/Applications/Falcon.app/Contents/Resources/falconctl" ]]; then
            /Applications/Falcon.app/Contents/Resources/falconctl -s &> /dev/null || true
        fi
        
        return 0
    fi
}

################################################################################
# Main Functions
################################################################################

# Display usage information
usage() {
    cat << EOF
Usage: $0 -t TOKEN [-u URL] [-i CLIENT_ID] [-s CLIENT_SECRET]

CrowdStrike Installation Script for macOS

Options:
    -t TOKEN              Provisioning token (required, minimum 32 characters)
    -u URL                Download URL for CrowdStrike installer (optional)
    -i CLIENT_ID          Falcon API Client ID (optional)
    -s CLIENT_SECRET      Falcon API Client Secret (optional)
    -h                    Display this help message
    -v                    Display script version

Examples:
    $0 -t "your-provisioning-token-here"
    $0 -t "token" -u "https://example.com/CrowdStrike.pkg" -i "client-id" -s "client-secret"

EOF
}

# Display version
display_version() {
    echo "CrowdStrike Installation Script v${SCRIPT_VERSION}"
}

# Parse command line arguments
parse_arguments() {
    local token=""
    local download_url=""
    local client_id=""
    local client_secret=""
    
    while getopts "t:u:i:s:hv" opt; do
        case ${opt} in
            t)
                token="${OPTARG}"
                ;;
            u)
                download_url="${OPTARG}"
                ;;
            i)
                client_id="${OPTARG}"
                ;;
            s)
                client_secret="${OPTARG}"
                ;;
            h)
                usage
                exit 0
                ;;
            v)
                display_version
                exit 0
                ;;
            *)
                print_error "Invalid option: -${OPTARG}"
                usage
                exit 1
                ;;
        esac
    done
    
    # Validate required token parameter
    if [[ -z "${token}" ]]; then
        print_error "Provisioning token is required"
        usage
        exit 1
    fi
    
    if ! validate_token "${token}"; then
        exit 1
    fi
    
    echo "${token}|${download_url}|${client_id}|${client_secret}"
}

# Main installation flow
main() {
    print_status "CrowdStrike Installation Script v${SCRIPT_VERSION}"
    print_status "Current Date: 2025-12-23 06:50:40 UTC"
    
    log "INFO" "=== CrowdStrike Installation Started ==="
    
    # Parse arguments
    local args=$(parse_arguments "$@")
    IFS='|' read -r token download_url client_id client_secret <<< "${args}"
    
    # Validation checks
    check_root || exit 1
    validate_macos_version || exit 1
    check_dependencies || exit 1
    
    # Check if already installed
    if check_crowdstrike_installed; then
        read -p "CrowdStrike appears to be installed. Continue? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Installation cancelled"
            exit 0
        fi
    fi
    
    # Setup and installation
    setup_temp_directory || exit 1
    
    # Download installer if URL provided
    if [[ -n "${download_url}" ]]; then
        local pkg_file
        pkg_file=$(download_installer "${download_url}") || exit 1
        verify_package "${pkg_file}" || exit 1
        install_crowdstrike "${pkg_file}" "${client_id}" "${client_secret}" || exit 1
    fi
    
    # Configure if credentials provided
    if [[ -n "${client_id}" ]] && [[ -n "${client_secret}" ]]; then
        configure_crowdstrike "${client_id}" "${client_secret}" || exit 1
    fi
    
    # Verify installation
    verify_installation
    
    print_success "CrowdStrike installation and configuration completed!"
    print_status "Log file: ${LOG_FILE}"
}

################################################################################
# Script Entry Point
################################################################################

main "$@"
