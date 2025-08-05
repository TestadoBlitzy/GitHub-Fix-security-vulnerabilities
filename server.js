const express = require('express');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const cors = require('cors');
const { body, validationResult } = require('express-validator');
const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');

// Initialize Express application
const app = express();

// Security middleware configuration
// Helmet.js - Set security headers automatically
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "https://fonts.googleapis.com"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
}));

// Rate limiting - 50 requests per 10 minutes to prevent DoS attacks
const limiter = rateLimit({
  windowMs: 10 * 60 * 1000, // 10 minutes
  limit: 50, // Limit each IP to 50 requests per windowMs
  standardHeaders: 'draft-8', // Return rate limit info in headers
  legacyHeaders: false, // Disable the `X-RateLimit-*` headers
  message: {
    error: 'Too many requests from this IP, please try again later.',
    retryAfter: '10 minutes'
  }
});
app.use(limiter);

// CORS configuration - Restrictive origin policy with dynamic validation
const allowedOrigins = ['http://localhost:3000', 'https://localhost:3443'];
const corsOptions = {
  origin: function (origin, callback) {
    // Allow requests with no origin (like mobile apps or curl requests)
    if (!origin) return callback(null, true);
    
    // Dynamic strict checking - validate origin against allowlist
    if (allowedOrigins.indexOf(origin) !== -1) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS policy'), false);
    }
  }, // Enhanced dynamic origin validation
  credentials: false,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
  maxAge: 86400 // 24 hours
};
app.use(cors(corsOptions));

// Body parsing middleware for input validation
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Input validation middleware (for future endpoints)
const validateInput = [
  body('*').escape(), // Escape all HTML characters in all fields
  (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Invalid input',
        details: errors.array()
      });
    }
    next();
  }
];

// Main route - Maintain identical "Hello, World!" response behavior
app.get('/', (req, res) => {
  res.status(200);
  res.set('Content-Type', 'text/plain');
  res.send('Hello, World!\n');
});

// Health check endpoint for monitoring
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Error occurred:', err.message);
  
  // Don't leak error details in production
  const isDevelopment = process.env.NODE_ENV !== 'production';
  
  res.status(err.status || 500).json({
    error: 'Internal Server Error',
    message: isDevelopment ? err.message : 'Something went wrong',
    timestamp: new Date().toISOString()
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: `Route ${req.method} ${req.path} not found`,
    timestamp: new Date().toISOString()
  });
});

// Server configuration
const hostname = '127.0.0.1';
const httpPort = 3000;
const httpsPort = 3443;

// HTTPS configuration with self-signed certificates for development
let httpsOptions = {};
const certPath = path.join(__dirname, 'certificates');
const keyFile = path.join(certPath, 'key.pem');
const certFile = path.join(certPath, 'cert.pem');

// Function to generate self-signed certificates if they don't exist
function generateSelfSignedCertificates() {
  const { execSync } = require('child_process');
  
  try {
    // Create certificates directory if it doesn't exist
    if (!fs.existsSync(certPath)) {
      fs.mkdirSync(certPath, { recursive: true });
    }
    
    // Generate self-signed certificate for development
    const opensslCmd = `openssl req -x509 -newkey rsa:2048 -keyout "${keyFile}" -out "${certFile}" -days 365 -nodes -subj "/C=US/ST=Development/L=Localhost/O=Development/OU=Testing/CN=localhost"`;
    
    console.log('Generating self-signed certificates for HTTPS...');
    execSync(opensslCmd, { stdio: 'inherit' });
    console.log('Certificates generated successfully');
    
  } catch (error) {
    console.warn('Warning: Could not generate SSL certificates. HTTPS server will not start.');
    console.warn('Error:', error.message);
    console.warn('To generate certificates manually, run:');
    console.warn(`mkdir -p ${certPath}`);
    console.warn(`openssl req -x509 -newkey rsa:2048 -keyout ${keyFile} -out ${certFile} -days 365 -nodes -subj "/C=US/ST=Development/L=Localhost/O=Development/OU=Testing/CN=localhost"`);
    return false;
  }
  
  return true;
}

// Load or generate HTTPS certificates
try {
  if (fs.existsSync(keyFile) && fs.existsSync(certFile)) {
    httpsOptions = {
      key: fs.readFileSync(keyFile),
      cert: fs.readFileSync(certFile)
    };
    console.log('SSL certificates loaded successfully');
  } else {
    if (generateSelfSignedCertificates()) {
      httpsOptions = {
        key: fs.readFileSync(keyFile),
        cert: fs.readFileSync(certFile)
      };
    }
  }
} catch (error) {
  console.warn('Warning: SSL certificates could not be loaded. HTTPS server will not start.');
  console.warn('Error:', error.message);
}

// Start HTTP server (maintains compatibility with existing setup)
const httpServer = http.createServer(app);
httpServer.listen(httpPort, hostname, () => {
  console.log(`HTTP Server running at http://${hostname}:${httpPort}/`);
  console.log('Security features enabled:');
  console.log('✓ Security headers (Helmet.js)');
  console.log('✓ Rate limiting (50 requests/10min)');
  console.log('✓ CORS protection');
  console.log('✓ Input validation ready');
});

// Start HTTPS server if certificates are available
if (httpsOptions.key && httpsOptions.cert) {
  const httpsServer = https.createServer(httpsOptions, app);
  httpsServer.listen(httpsPort, hostname, () => {
    console.log(`HTTPS Server running at https://${hostname}:${httpsPort}/`);
    console.log('✓ TLS/SSL encryption enabled');
  });
} else {
  console.log('HTTPS server not started - SSL certificates not available');
  console.log('Run the following commands to enable HTTPS:');
  console.log(`mkdir -p ${certPath}`);
  console.log(`openssl req -x509 -newkey rsa:2048 -keyout ${keyFile} -out ${certFile} -days 365 -nodes -subj "/C=US/ST=Development/L=Localhost/O=Development/OU=Testing/CN=localhost"`);
}

// Graceful shutdown handling
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  httpServer.close(() => {
    console.log('HTTP server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  httpServer.close(() => {
    console.log('HTTP server closed');
    process.exit(0);
  });
});

// Export app for testing purposes
module.exports = app;