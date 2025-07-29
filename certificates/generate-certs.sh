#!/bin/bash

#
# Certificate Generation Script for Development HTTPS Server
# Generates self-signed certificates and private keys for local development
# Part of security enhancement implementation for Node.js application
#

set -e  # Exit immediately if a command exits with a non-zero status

# Configuration
CERT_DIR="$(dirname "$0")"
PRIVATE_KEY="$CERT_DIR/private-key.pem"
CERTIFICATE="$CERT_DIR/certificate.pem"
DAYS_VALID=365
KEY_SIZE=2048

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if OpenSSL is available
check_openssl() {
    if ! command -v openssl &> /dev/null; then
        print_error "OpenSSL is not installed or not in PATH"
        print_error "Please install OpenSSL to generate certificates"
        print_error "  Ubuntu/Debian: sudo apt-get install openssl"
        print_error "  CentOS/RHEL: sudo yum install openssl"
        print_error "  macOS: brew install openssl"
        exit 1
    fi
    
    print_status "OpenSSL version: $(openssl version)"
}

# Function to create certificates directory if it doesn't exist
create_cert_directory() {
    if [[ ! -d "$CERT_DIR" ]]; then
        mkdir -p "$CERT_DIR"
        print_status "Created certificates directory: $CERT_DIR"
    fi
}

# Function to backup existing certificates
backup_existing_certs() {
    local backup_needed=false
    
    if [[ -f "$PRIVATE_KEY" ]]; then
        local backup_key="${PRIVATE_KEY}.backup.$(date +%Y%m%d_%H%M%S)"
        mv "$PRIVATE_KEY" "$backup_key"
        print_warning "Backed up existing private key to: $backup_key"
        backup_needed=true
    fi
    
    if [[ -f "$CERTIFICATE" ]]; then
        local backup_cert="${CERTIFICATE}.backup.$(date +%Y%m%d_%H%M%S)"
        mv "$CERTIFICATE" "$backup_cert"
        print_warning "Backed up existing certificate to: $backup_cert"
        backup_needed=true
    fi
    
    if [[ "$backup_needed" == true ]]; then
        print_status "Existing certificates have been backed up"
    fi
}

# Function to generate private key
generate_private_key() {
    print_status "Generating RSA private key ($KEY_SIZE bits)..."
    
    openssl genrsa -out "$PRIVATE_KEY" $KEY_SIZE 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        print_success "Private key generated: $PRIVATE_KEY"
        chmod 600 "$PRIVATE_KEY"  # Restrict access to private key
        print_status "Set private key permissions to 600 (owner read/write only)"
    else
        print_error "Failed to generate private key"
        exit 1
    fi
}

# Function to generate self-signed certificate
generate_certificate() {
    print_status "Generating self-signed certificate (valid for $DAYS_VALID days)..."
    
    # Create a temporary configuration file for the certificate
    local config_file=$(mktemp)
    cat > "$config_file" << EOF
[req]
default_bits = $KEY_SIZE
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C=US
ST=Development
L=LocalHost
O=Development Organization
OU=Development Unit
CN=localhost

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = *.localhost
IP.1 = 127.0.0.1
IP.2 = ::1
EOF

    # Generate the certificate
    openssl req -new -x509 -key "$PRIVATE_KEY" -out "$CERTIFICATE" \
        -days $DAYS_VALID -config "$config_file" -extensions v3_req 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        print_success "Certificate generated: $CERTIFICATE"
        chmod 644 "$CERTIFICATE"  # Allow read access for certificate
        print_status "Set certificate permissions to 644 (owner read/write, others read)"
    else
        print_error "Failed to generate certificate"
        rm -f "$config_file"
        exit 1
    fi
    
    # Clean up temporary config file
    rm -f "$config_file"
}

# Function to display certificate information
display_certificate_info() {
    print_status "Certificate Information:"
    echo
    
    # Display certificate details
    openssl x509 -in "$CERTIFICATE" -text -noout | grep -E "(Subject:|Issuer:|Not Before:|Not After :|DNS:|IP Address:)" | while read line; do
        echo "  $line"
    done
    
    echo
    print_status "Certificate fingerprint (SHA256):"
    echo "  $(openssl x509 -noout -fingerprint -sha256 -in "$CERTIFICATE" | cut -d= -f2)"
}

# Function to create .gitignore for certificates directory
create_gitignore() {
    local gitignore_file="$CERT_DIR/.gitignore"
    
    # Don't overwrite existing .gitignore
    if [[ ! -f "$gitignore_file" ]]; then
        cat > "$gitignore_file" << EOF
# Ignore all certificate files for security
*.pem
*.key
*.crt
*.csr
*.p12
*.pfx

# Ignore backup files
*.backup.*

# Allow this script and documentation
!generate-certs.sh
!README.md
!.gitignore
EOF
        print_success "Created .gitignore file: $gitignore_file"
    fi
}

# Function to display usage instructions
display_usage_instructions() {
    echo
    print_success "Certificate generation completed successfully!"
    echo
    print_status "Usage Instructions:"
    echo "  1. The HTTPS server can now use these certificates:"
    echo "     - Private Key: $PRIVATE_KEY"
    echo "     - Certificate: $CERTIFICATE"
    echo
    echo "  2. In your Node.js server code, use:"
    echo "     const fs = require('fs');"
    echo "     const https = require('https');"
    echo "     const options = {"
    echo "       key: fs.readFileSync('$PRIVATE_KEY'),"
    echo "       cert: fs.readFileSync('$CERTIFICATE')"
    echo "     };"
    echo "     https.createServer(options, app).listen(443);"
    echo
    echo "  3. Access your development server at:"
    echo "     https://localhost (if running on port 443)"
    echo "     or https://localhost:PORT (for other ports)"
    echo
    print_warning "Browser Security Warning:"
    echo "  Your browser will show a security warning because this is a self-signed certificate."
    echo "  For development, you can safely proceed by clicking 'Advanced' > 'Proceed to localhost'."
    echo
    print_status "To regenerate certificates, simply run this script again."
}

# Function to validate generated files
validate_certificates() {
    print_status "Validating generated certificates..."
    
    # Check if private key is valid
    if openssl rsa -in "$PRIVATE_KEY" -check -noout 2>/dev/null; then
        print_success "Private key validation: PASSED"
    else
        print_error "Private key validation: FAILED"
        exit 1
    fi
    
    # Check if certificate is valid
    if openssl x509 -in "$CERTIFICATE" -noout 2>/dev/null; then
        print_success "Certificate validation: PASSED"
    else
        print_error "Certificate validation: FAILED"
        exit 1
    fi
    
    # Verify certificate and key match
    local key_modulus=$(openssl rsa -noout -modulus -in "$PRIVATE_KEY" 2>/dev/null | openssl md5)
    local cert_modulus=$(openssl x509 -noout -modulus -in "$CERTIFICATE" 2>/dev/null | openssl md5)
    
    if [[ "$key_modulus" == "$cert_modulus" ]]; then
        print_success "Certificate and private key match: PASSED"
    else
        print_error "Certificate and private key match: FAILED"
        exit 1
    fi
}

# Main execution function
main() {
    echo "==============================================="
    echo "  Development HTTPS Certificate Generator"
    echo "  Security Enhancement Implementation"
    echo "==============================================="
    echo
    
    # Check prerequisites
    check_openssl
    
    # Create directory structure
    create_cert_directory
    
    # Backup existing certificates if they exist
    backup_existing_certs
    
    # Generate new certificates
    generate_private_key
    generate_certificate
    
    # Validate generated certificates
    validate_certificates
    
    # Display certificate information
    display_certificate_info
    
    # Create .gitignore for security
    create_gitignore
    
    # Display usage instructions
    display_usage_instructions
    
    echo
    print_success "Certificate generation process completed successfully!"
}

# Show help if requested
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Development HTTPS Certificate Generator"
    echo
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --key-size N   Set RSA key size (default: $KEY_SIZE)"
    echo "  --days N       Set certificate validity in days (default: $DAYS_VALID)"
    echo
    echo "This script generates self-signed certificates for local HTTPS development."
    echo "The certificates are suitable for development and testing only."
    echo
    echo "Generated files:"
    echo "  - private-key.pem: RSA private key"
    echo "  - certificate.pem: Self-signed X.509 certificate"
    echo
    echo "The certificate includes Subject Alternative Names (SAN) for:"
    echo "  - localhost"
    echo "  - *.localhost"
    echo "  - 127.0.0.1"
    echo "  - ::1 (IPv6 localhost)"
    exit 0
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --key-size)
            KEY_SIZE="$2"
            if ! [[ "$KEY_SIZE" =~ ^[0-9]+$ ]] || [[ "$KEY_SIZE" -lt 1024 ]]; then
                print_error "Invalid key size. Must be a number >= 1024"
                exit 1
            fi
            shift 2
            ;;
        --days)
            DAYS_VALID="$2"
            if ! [[ "$DAYS_VALID" =~ ^[0-9]+$ ]] || [[ "$DAYS_VALID" -lt 1 ]]; then
                print_error "Invalid days value. Must be a positive number"
                exit 1
            fi
            shift 2
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Execute main function
main

exit 0