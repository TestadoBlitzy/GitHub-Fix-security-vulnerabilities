# Development HTTPS Certificates

This directory contains certificates and tools for enabling HTTPS/TLS encryption in the development environment as part of the comprehensive security enhancement implementation.

## Overview

As part of the security vulnerability remediation effort, this Node.js application has been upgraded from HTTP-only communication to support secure HTTPS connections. This directory provides the necessary certificates and management tools for local development with TLS encryption.

### Security Context

The original system used a "Security Through Isolation" model with localhost-only binding. The security enhancement adds multiple layers of protection:

- **HTTP Security Headers** via Helmet.js middleware
- **Rate Limiting** protection against abuse
- **Input Validation** and sanitization
- **HTTPS/TLS Encryption** for data in transit (this component)
- **CORS Configuration** for cross-origin security

## Directory Contents

```
certificates/
├── README.md           # This documentation file
├── generate-certs.sh   # Certificate generation script
├── cert.pem           # Self-signed X.509 certificate (example)
├── key.pem            # RSA private key (example)
└── .gitignore         # Security-focused git ignore rules
```

## Quick Start

### 1. Generate Development Certificates

Run the certificate generation script to create new self-signed certificates:

```bash
# From the certificates directory
./generate-certs.sh
```

Or from the project root:

```bash
# From project root
./certificates/generate-certs.sh
```

### 2. Start HTTPS Server

The certificates are automatically used by the Node.js server when HTTPS is enabled:

```javascript
const fs = require('fs');
const https = require('https');
const express = require('express');

const app = express();

// HTTPS server configuration
const httpsOptions = {
  key: fs.readFileSync('./certificates/key.pem'),
  cert: fs.readFileSync('./certificates/cert.pem')
};

// Start HTTPS server
https.createServer(httpsOptions, app).listen(443, '127.0.0.1', () => {
  console.log('HTTPS Server running on https://localhost');
});
```

### 3. Access Your Application

- **HTTPS**: `https://localhost` (port 443) or `https://localhost:PORT`
- **HTTP**: `http://localhost:3000` (if HTTP server is also running)

## Certificate Generation Script

### Basic Usage

```bash
./generate-certs.sh
```

The script will:
1. Check for OpenSSL availability
2. Backup any existing certificates
3. Generate a new 2048-bit RSA private key
4. Create a self-signed X.509 certificate (valid for 365 days)
5. Set appropriate file permissions
6. Validate the generated certificates
7. Display certificate information and usage instructions

### Advanced Usage

```bash
# Generate with custom key size
./generate-certs.sh --key-size 4096

# Generate with custom validity period
./generate-certs.sh --days 730

# Show help
./generate-certs.sh --help
```

### Certificate Configuration

The generated certificates include:

**Certificate Details:**
- **Subject**: CN=localhost, O=Development Organization
- **Key Size**: 2048-bit RSA (configurable)
- **Validity**: 365 days (configurable)
- **Signature Algorithm**: SHA-256 with RSA

**Subject Alternative Names (SAN):**
- `localhost`
- `*.localhost`
- `127.0.0.1` (IPv4)
- `::1` (IPv6)

## Security Considerations

### Development Environment Usage

⚠️ **IMPORTANT**: These certificates are for **development use only**.

- **Self-signed certificates** are not trusted by browsers by default
- Browsers will show security warnings that must be manually bypassed
- **Never use these certificates in production environments**

### Browser Security Warnings

When accessing `https://localhost`, you will see a security warning:

1. **Chrome/Edge**: Click "Advanced" → "Proceed to localhost (unsafe)"
2. **Firefox**: Click "Advanced" → "Accept the Risk and Continue"
3. **Safari**: Click "Show Details" → "Visit this website"

### File Permissions

The generation script automatically sets secure file permissions:

- **Private Key (`key.pem`)**: `600` (owner read/write only)
- **Certificate (`cert.pem`)**: `644` (owner read/write, others read)

### Git Security

A `.gitignore` file is automatically created to prevent accidentally committing certificates to version control:

```gitignore
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
```

## Certificate Management

### Regenerating Certificates

To create new certificates (e.g., when existing ones expire):

1. Run the generation script again: `./generate-certs.sh`
2. Existing certificates are automatically backed up with timestamps
3. New certificates are generated and validated
4. Restart your HTTPS server to use the new certificates

### Backing Up Certificates

Existing certificates are automatically backed up during regeneration:

```
key.pem.backup.20240729_143022
cert.pem.backup.20240729_143022
```

### Certificate Validation

The script includes built-in validation:

- **Private Key Validation**: Verifies RSA key integrity
- **Certificate Validation**: Confirms X.509 certificate format
- **Key-Certificate Matching**: Ensures the private key and certificate pair match

## Integration with Security Middleware

The HTTPS certificates work alongside other security enhancements:

### Complete Security Stack

```javascript
const express = require('express');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const cors = require('cors');
const { body, validationResult } = require('express-validator');
const https = require('https');
const fs = require('fs');

const app = express();

// Security middleware stack
app.use(helmet());                    // Security headers
app.use(rateLimit({                   // Rate limiting
  windowMs: 15 * 60 * 1000,          // 15 minutes
  max: 100                           // 100 requests
}));
app.use(cors({                        // CORS configuration
  origin: ['https://localhost'],
  credentials: false
}));

// HTTPS server with certificates
const httpsOptions = {
  key: fs.readFileSync('./certificates/key.pem'),
  cert: fs.readFileSync('./certificates/cert.pem')
};

https.createServer(httpsOptions, app).listen(443, '127.0.0.1');
```

## Troubleshooting

### Common Issues

**1. OpenSSL Not Found**
```bash
# Ubuntu/Debian
sudo apt-get install openssl

# CentOS/RHEL
sudo yum install openssl

# macOS
brew install openssl
```

**2. Permission Denied**
```bash
# Make script executable
chmod +x generate-certs.sh
```

**3. Port 443 Permission Error**
```bash
# Run with sudo for port 443, or use a different port
sudo node server.js

# Or configure to use port 8443
https.createServer(httpsOptions, app).listen(8443, '127.0.0.1');
```

**4. Certificate Validation Errors**
- Ensure OpenSSL is properly installed
- Check file permissions on generated certificates
- Verify the certificates directory is writable

### Certificate Information

To view certificate details:

```bash
# View certificate information
openssl x509 -in cert.pem -text -noout

# Check certificate expiration
openssl x509 -in cert.pem -noout -dates

# Verify certificate and key match
openssl x509 -noout -modulus -in cert.pem | openssl md5
openssl rsa -noout -modulus -in key.pem | openssl md5
```

## Development Workflow

### Initial Setup

1. Clone the repository
2. Run `./certificates/generate-certs.sh` to create certificates
3. Install dependencies: `npm install`
4. Start the server: `npm start`
5. Access via HTTPS: `https://localhost`

### Daily Development

- Certificates are valid for 365 days by default
- No need to regenerate unless expired or compromised
- HTTP server remains available on port 3000 for compatibility
- HTTPS provides encrypted communication for security testing

### Certificate Renewal

Set up a reminder to regenerate certificates before expiration:

```bash
# Check certificate expiration
openssl x509 -in ./certificates/cert.pem -noout -dates

# Example output:
# notBefore=Jul 29 15:04:27 2024 GMT
# notAfter=Jul 29 15:04:27 2025 GMT
```

## Production Considerations

🚨 **CRITICAL**: This certificate setup is for development only.

**For production deployments:**

1. **Use CA-signed certificates** from trusted authorities (Let's Encrypt, DigiCert, etc.)
2. **Implement proper certificate management** with automated renewal
3. **Use production-grade TLS configuration** with strong cipher suites
4. **Enable HSTS** (HTTP Strict Transport Security) headers
5. **Configure proper certificate chain** validation

**Production Certificate Management:**
- Use tools like Certbot for Let's Encrypt certificates
- Implement certificate monitoring and automatic renewal
- Use proper key management and storage solutions
- Regular security audits and certificate rotation

## References

- [OpenSSL Documentation](https://www.openssl.org/docs/)
- [Node.js HTTPS Module](https://nodejs.org/api/https.html)
- [Let's Encrypt - Free SSL/TLS Certificates](https://letsencrypt.org/)
- [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/)
- [OWASP Transport Layer Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Transport_Layer_Security_Cheat_Sheet.html)

---

**Security Enhancement Implementation**: This certificate management system is part of a comprehensive security upgrade that addresses multiple vulnerabilities including missing security headers, lack of input validation, absence of rate limiting, and HTTP-only communication. The combination of all security measures transforms the application from an "F" security grade to production-ready security standards.