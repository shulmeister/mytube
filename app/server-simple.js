const express = require('express');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 3000;

console.log('🚀 Starting simple server...');
console.log('PORT:', PORT);
console.log('NODE_ENV:', process.env.NODE_ENV);

// Simple health check first
app.get('/health', (req, res) => {
    console.log('Health check requested');
    res.json({
        status: 'ok',
        message: 'Server is running',
        timestamp: new Date().toISOString(),
        port: PORT
    });
});

// Test endpoint
app.get('/test', (req, res) => {
    console.log('Test endpoint requested');
    res.json({
        message: 'Test successful',
        timestamp: new Date().toISOString()
    });
});

// Serve static files
app.use(express.static(path.join(__dirname, 'public')));

// Root route
app.get('/', (req, res) => {
    console.log('Root route requested');
    try {
        res.sendFile(path.join(__dirname, 'public', 'index.html'));
    } catch (error) {
        console.error('Error serving index.html:', error);
        res.status(500).send('Error loading page');
    }
});

// Error handling
app.use((error, req, res, next) => {
    console.error('Server error:', error);
    res.status(500).json({
        error: 'Internal server error',
        message: error.message
    });
});

// Start server
const server = app.listen(PORT, '0.0.0.0', () => {
    console.log(`✅ Simple server running on port ${PORT}`);
    console.log(`🌐 Test endpoints:`);
    console.log(`   Health: http://localhost:${PORT}/health`);
    console.log(`   Test: http://localhost:${PORT}/test`);
});

// Handle server errors
server.on('error', (error) => {
    console.error('❌ Server failed to start:', error);
    process.exit(1);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('📤 Received SIGTERM, shutting down gracefully');
    server.close(() => {
        console.log('✅ Server closed');
        process.exit(0);
    });
});

process.on('SIGINT', () => {
    console.log('📤 Received SIGINT, shutting down gracefully');
    server.close(() => {
        console.log('✅ Server closed');
        process.exit(0);
    });
});

console.log('🎯 Server setup complete, waiting for connections...');
