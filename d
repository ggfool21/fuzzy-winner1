const clipboardy = require('clipboardy');
const axios = require('axios');

// Configuration
const API_URL = 'https://your-vercel-app.vercel.app/api/animal-data';
const CHECK_INTERVAL = 1000; // Check clipboard every 1 second

let lastClipboardContent = '';
let isProcessing = false;

// Function to validate clipboard format (JobId|Generation|DisplayName)
function validateClipboardFormat(content) {
    const parts = content.split('|');
    
    // Must have exactly 3 parts
    if (parts.length !== 3) return false;
    
    const [jobId, generation, displayName] = parts;
    
    // JobId should be a valid format (letters/numbers)
    if (!jobId || jobId.length < 10) return false;
    
    // Generation should contain $ and M/s or similar
    if (!generation.includes('$') || (!generation.includes('M') && !generation.includes('K') && !generation.includes('B'))) return false;
    
    // DisplayName should not be empty
    if (!displayName || displayName.trim().length === 0) return false;
    
    return true;
}

// Function to parse clipboard data
function parseClipboardData(content) {
    const [jobId, generation, displayName] = content.split('|');
    
    return {
        jobId: jobId.trim(),
        generation: generation.trim(),
        displayName: displayName.trim(),
        timestamp: new Date().toISOString(),
        source: 'clipboard'
    };
}

// Function to send data to Vercel API
async function sendToAPI(data) {
    try {
        console.log('📤 Sending to API:', data);
        
        const response = await axios.post(API_URL, data, {
            headers: {
                'Content-Type': 'application/json'
            },
            timeout: 10000 // 10 second timeout
        });
        
        console.log('✅ API Response:', response.status, response.statusText);
        return true;
        
    } catch (error) {
        console.error('❌ API Error:', error.message);
        if (error.response) {
            console.error('Response status:', error.response.status);
            console.error('Response data:', error.response.data);
        }
        return false;
    }
}

// Main clipboard monitoring function
async function monitorClipboard() {
    try {
        if (isProcessing) return; // Skip if already processing
        
        const currentContent = await clipboardy.read();
        
        // Check if clipboard content has changed
        if (currentContent !== lastClipboardContent) {
            console.log('📋 Clipboard changed:', currentContent.substring(0, 50) + '...');
            
            // Validate format
            if (validateClipboardFormat(currentContent)) {
                isProcessing = true;
                console.log('🎯 Valid animal data detected!');
                
                // Parse the data
                const animalData = parseClipboardData(currentContent);
                console.log('📊 Parsed data:', animalData);
                
                // Send to API
                const success = await sendToAPI(animalData);
                
                if (success) {
                    console.log('🚀 Successfully sent animal data to API!');
                } else {
                    console.log('💥 Failed to send to API, will retry on next detection');
                }
                
                isProcessing = false;
            } else {
                console.log('⚠️  Invalid format, ignoring clipboard change');
            }
            
            lastClipboardContent = currentContent;
        }
        
    } catch (error) {
        console.error('🔥 Clipboard monitor error:', error.message);
        isProcessing = false;
    }
}

// Start monitoring
console.log('🔄 Starting clipboard monitor...');
console.log('📋 Monitoring format: JobId|Generation|DisplayName');
console.log('🌐 API endpoint:', API_URL);
console.log('⏱️  Check interval:', CHECK_INTERVAL + 'ms');
console.log('---');

// Initial clipboard read
clipboardy.read().then(content => {
    lastClipboardContent = content;
    console.log('📋 Initial clipboard content length:', content.length);
}).catch(err => {
    console.error('❌ Failed to read initial clipboard:', err.message);
});

// Set up monitoring interval
setInterval(monitorClipboard, CHECK_INTERVAL);

// Handle process termination
process.on('SIGINT', () => {
    console.log('\n🛑 Stopping clipboard monitor...');
    process.exit(0);
});

process.on('SIGTERM', () => {
    console.log('\n🛑 Stopping clipboard monitor...');
    process.exit(0);
});

console.log('✅ Clipboard monitor started! Press Ctrl+C to stop.');
