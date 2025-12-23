#!/bin/bash

################################################################################
# CrowdStrike Falcon Agent Automated Installation Script for macOS
# Version: 3.0
# Description: One-click automated installation with fixed URL, auto CCID config,
#              interactive token input, and automated configuration
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

# Configuration - FIXED VALUES
readonly SCRIPT_VERSION="3.0"
readonly LOG_FILE="/var/log/crowdstrike_install.log"
readonly TEMP_DIR="/tmp/cs_install_$$"
readonly CROWDSTRIKE_PKG_URL="https://s3-public-test1.s3.ap-northeast-1.amazonaws.com/crowdstrike/FalconSensorMacOS.MaverickGyr.pkg"
readonly FALCON_APP_PATH="/Applications/Falcon.app"
readonly FALCON_CTL_PATH="${FALCON_APP_PATH}/Contents/Resources/falconctl"
readonly CCID="E3E08A20CAE84445821F3AC16D1C2B53-B5"
readonly FALCON_SERVICE_PATH="/Library/LaunchDaemons/com.crowdstrike.falcond.plist"

################################################################################
# Utility Functions
################################################################################

log() {
    local level="$1"
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

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

print_input() {
    echo -e "${BLUE}[INPUT]${NC} $@"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use: sudo ./cs.sh)"
        exit 1
    fi
}

# Cleanup function
cleanup() {
    local exit_code=$?
    if [[ -d "${TEMP_DIR}" ]]; then
        rm -rf "${TEMP_DIR}"
        log "INFO" "Temporary directory cleaned up"
    fi
    if [[ ${exit_code} -eq 0 ]]; then
        log "INFO" "=== CrowdStrike Installation Completed Successfully ==="
    else
        log "ERROR" "=== Installation Failed with Exit Code ${exit_code} ==="
    fi
    return ${exit_code}
}

trap cleanup EXIT

################################################################################
# Input & Validation Functions
################################################################################

# Interactive token input with validation
get_and_validate_token() {
    local token=""
    local valid=0
    
    while [[ ${valid} -eq 0 ]]; do
        print_input "Enter CrowdStrike Provisioning Token (8 digits):"
        read -r -p "Token: " token
        
        # Validate: exactly 8 digits
        if [[ -z "${token}" ]]; then
            print_error "Token cannot be empty"
            continue
        fi
        
        if ! [[ "${token}" =~ ^[0-9]{8}$ ]]; then
            print_error "Token must be exactly 8 digits. You entered: ${token}"
            continue
        fi
        
        print_success "Token validated successfully: ${token:0:4}****"
        valid=1
    done
    
    echo "${token}"
}

# Validate macOS version
validate_macos_version() {
    local min_version="10.13"
    local current_version=$(sw_vers -productVersion)
    
    print_status "Detected macOS version: ${current_version}"
    
    if ! [[ "${current_version}" > "${min_version}" ]] && ! [[ "${current_version}" == "${min_version}" ]]; then
        print_error "macOS version ${current_version} is not supported (minimum required: ${min_version})"
        log "ERROR" "Unsupported macOS version: ${current_version}"
        return 1
    fi
    
    print_success "macOS version compatible"
    return 0
}

# Check for required tools
check_dependencies() {
    local missing_deps=()
    
    print_status "Checking system dependencies..."
    
    for cmd in curl installer pkgutil launchctl; do
        if ! command -v "${cmd}" &> /dev/null; then
            missing_deps+=("${cmd}")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing required tools: ${missing_deps[*]}"
        log "ERROR" "Missing dependencies: ${missing_deps[*]}"
        return 1
    fi
    
    print_success "All required dependencies available"
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
# Download & Installation Functions
################################################################################

# Create temporary directory
setup_temp_directory() {
    if ! mkdir -p "${TEMP_DIR}"; then
        print_error "Failed to create temporary directory"
        return 1
    fi
    print_status "Temporary directory: ${TEMP_DIR}"
    log "INFO" "Temporary directory created"
    return 0
}

# Download CrowdStrike installer
download_installer() {
    local output_file="${TEMP_DIR}/CrowdStrike.pkg"
    
    print_status "Downloading CrowdStrike Falcon Agent..."
    log "INFO" "Download URL: ${CROWDSTRIKE_PKG_URL}"
    
    if ! curl -fSL --max-time 600 --progress-bar -o "${output_file}" "${CROWDSTRIKE_PKG_URL}"; then
        print_error "Failed to download CrowdStrike installer from: ${CROWDSTRIKE_PKG_URL}"
        log "ERROR" "Download failed"
        return 1
    fi
    
    # Verify file exists and is not empty
    if [[ ! -f "${output_file}" ]] || [[ ! -s "${output_file}" ]]; then
        print_error "Downloaded file is empty or does not exist"
        log "ERROR" "Downloaded file validation failed"
        return 1
    fi
    
    local file_size=$(du -h "${output_file}" | cut -f1)
    print_success "Installer downloaded successfully (${file_size})"
    log "INFO" "Installer downloaded: ${output_file}"
    
    echo "${output_file}"
    return 0
}

# Verify package integrity
verify_package() {
    local pkg_path="$1"
    
    print_status "Verifying package integrity..."
    
    if pkgutil --check-signature "${pkg_path}" &> /dev/null; then
        print_success "Package signature verified"
        log "INFO" "Package signature verification passed"
    else
        print_warning "Package signature verification failed (continuing anyway)"
        log "WARNING" "Package signature verification failed"
    fi
    
    return 0
}

# Install CrowdStrike package
install_crowdstrike() {
    local pkg_path="$1"
    
    print_status "Installing CrowdStrike Falcon Agent..."
    log "INFO" "Starting installation from: ${pkg_path}"
    
    if ! installer -pkg "${pkg_path}" -target / -verboseR 2>&1 | tee -a "${LOG_FILE}"; then
        print_error "Installation failed"
        log "ERROR" "CrowdStrike installation failed"
        return 1
    fi
    
    # Verify installation
    sleep 2
    if [[ -d "${FALCON_APP_PATH}" ]]; then
        print_success "CrowdStrike Falcon Agent installed successfully"
        log "INFO" "Installation verified - Falcon.app found"
        return 0
    else
        print_error "Installation verification failed - Falcon.app not found"
        log "ERROR" "Post-installation verification failed"
        return 1
    fi
}

################################################################################
# Configuration Functions
################################################################################

# Configure CrowdStrike with CCID and Token
configure_crowdstrike() {
    local falcon_token="$1"
    
    print_status "Configuring CrowdStrike Falcon Agent..."
    log "INFO" "Starting CrowdStrike configuration with CCID: ${CCID}"
    
    # Verify falconctl exists
    if [[ ! -f "${FALCON_CTL_PATH}" ]]; then
        print_error "CrowdStrike CLI tool (falconctl) not found at: ${FALCON_CTL_PATH}"
        log "ERROR" "falconctl not found"
        return 1
    fi
    
    # Step 1: Set Customer ID (CCID)
    print_status "Setting Customer ID (CCID)..."
    if ! "${FALCON_CTL_PATH}" -s --cid="${CCID}" 2>&1 | tee -a "${LOG_FILE}"; then
        print_warning "CCID configuration encountered issues"
        log "WARNING" "CCID configuration warning"
    else
        print_success "CCID configured: ${CCID}"
        log "INFO" "CCID configured successfully"
    fi
    
    sleep 1
    
    # Step 2: Set Provisioning Token
    print_status "Setting Provisioning Token..."
    if ! "${FALCON_CTL_PATH}" -s --provisioning-token="${falcon_token}" 2>&1 | tee -a "${LOG_FILE}"; then
        print_warning "Token configuration encountered issues"
        log "WARNING" "Token configuration warning"
    else
        print_success "Provisioning Token configured"
        log "INFO" "Token configured successfully"
    fi
    
    sleep 1
    
    # Step 3: Enable Falcon service to auto-start
    print_status "Enabling CrowdStrike Falcon service..."
    if [[ -f "${FALCON_SERVICE_PATH}" ]]; then
        if ! launchctl load -w "${FALCON_SERVICE_PATH}" 2>&1 | tee -a "${LOG_FILE}"; then
            print_warning "Service startup configuration encountered issues"
            log "WARNING" "Service startup warning"
        else
            print_success "Falcon service enabled for auto-start"
            log "INFO" "Falcon service enabled"
        fi
    fi
    
    sleep 2
    
    # Step 4: Start the service
    print_status "Starting CrowdStrike Falcon service..."
    if ! "${FALCON_CTL_PATH}" -s 2>&1 | tee -a "${LOG_FILE}"; then
        print_warning "Service start encountered issues"
        log "WARNING" "Service start warning"
    else
        print_success "CrowdStrike Falcon service started"
        log "INFO" "Falcon service started successfully"
    fi
    
    return 0
}

# Verify service is running
verify_service_running() {
    print_status "Verifying CrowdStrike Falcon service status..."
    
    sleep 3
    
    # Check if falcond process is running
    local max_attempts=10
    local attempt=0
    
    while [[ ${attempt} -lt ${max_attempts} ]]; do
        if pgrep -f "falcond" > /dev/null; then
            print_success "CrowdStrike Falcon daemon (falcond) is running"
            log "INFO" "Falcon service verification successful"
            return 0
        fi
        
        print_status "Waiting for Falcon service to start... (${attempt}/${max_attempts})"
        sleep 2
        ((attempt++))
    done
    
    print_warning "CrowdStrike Falcon daemon is not yet running - service may start shortly"
    log "WARNING" "Falcon daemon not running after verification attempts"
    return 0
}

# Display service status
display_service_status() {
    print_status "Checking CrowdStrike service details..."
    
    if [[ -f "${FALCON_CTL_PATH}" ]]; then
        echo ""
        print_status "--- Falcon Service Status ---"
        "${FALCON_CTL_PATH}" -q 2>&1 | tee -a "${LOG_FILE}" || true
        echo ""
    fi
}

################################################################################
# Main Installation Flow
################################################################################

main() {
    print_status "========================================="
    print_status "CrowdStrike Falcon Agent Installation v${SCRIPT_VERSION}"
    print_status "========================================="
    echo ""
    
    log "INFO" "=== CrowdStrike Installation Started ==="
    log "INFO" "Script Version: ${SCRIPT_VERSION}"
    log "INFO" "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    
    # Pre-installation checks
    print_status "Performing pre-installation checks..."
    echo ""
    
    check_root || exit 1
    validate_macos_version || exit 1
    check_dependencies || exit 1
    
    echo ""
    
    # Check if already installed
    if check_crowdstrike_installed; then
        print_warning "CrowdStrike may already be installed"
        read -p "Continue with installation? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Installation cancelled by user"
            log "INFO" "Installation cancelled"
            exit 0
        fi
    fi
    
    echo ""
    
    # Get token from user
    print_status "Token input required"
    echo ""
    local falcon_token=$(get_and_validate_token)
    echo ""
    
    # Setup installation
    print_status "Setting up installation environment..."
    setup_temp_directory || exit 1
    echo ""
    
    # Download
    print_status "Downloading installation package..."
    local pkg_file
    pkg_file=$(download_installer) || exit 1
    echo ""
    
    # Verify
    verify_package "${pkg_file}" || exit 1
    echo ""
    
    # Install
    print_status "Installing CrowdStrike Falcon Agent..."
    echo ""
    install_crowdstrike "${pkg_file}" || exit 1
    echo ""
    
    # Configure
    print_status "Configuring CrowdStrike Falcon Agent..."
    echo ""
    configure_crowdstrike "${falcon_token}" || exit 1
    echo ""
    
    # Verify service
    print_status "Verifying installation..."
    echo ""
    verify_service_running || exit 1
    display_service_status
    echo ""
    
    # Success
    print_success "========================================="
    print_success "Installation and Configuration Completed!"
    print_success "========================================="
    print_status "Log file: ${LOG_FILE}"
    echo ""
    log "INFO" "Installation completed successfully"
}

################################################################################
# Script Entry Point
################################################################################

main "$@"
