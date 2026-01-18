require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const http = require('http');
const https = require('https');
const { WebSocketServer } = require('ws');
const os = require('os');
const Anthropic = require('@anthropic-ai/sdk');
const OpenAI = require('openai');
const multer = require('multer');

// Claude API for transcript analysis
const claude = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY || '' });

// OpenAI Whisper for audio transcription
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY || '' });

// File upload config for audio
const upload = multer({ dest: path.join(__dirname, 'uploads'), limits: { fileSize: 25 * 1024 * 1024 } });

const app = express();
const PORT = 3000;

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.static(path.join(__dirname, 'public')));

// HTTP server (for app gateway sync + dashboard)
const httpServer = http.createServer(app);

// HTTPS server (for phone camera — getUserMedia requires secure context)
let server;
const certPath = path.join(__dirname, 'cert.pem');
const keyPath = path.join(__dirname, 'key.pem');
let httpsServer = null;
if (fs.existsSync(certPath) && fs.existsSync(keyPath)) {
    httpsServer = https.createServer(
        { cert: fs.readFileSync(certPath), key: fs.readFileSync(keyPath) },
        app
    );
    server = httpsServer;
    console.log('HTTPS + HTTP servers');
} else {
    server = httpServer;
    console.log('HTTP only — phone camera will NOT work without certs.');
}

// ============================================================
// WEBRTC SIGNALING (WebSocket)
// ============================================================
// WebSocket on HTTPS (for camera signaling) and HTTP (for dashboard viewer)
const wss = new WebSocketServer({ server });
const wssHttp = new WebSocketServer({ server: httpServer });
const rooms = new Map(); // roomId -> { sender, viewer }

function handleSignaling(ws) {
    let joinedRoom = null;
    let role = null;

    ws.on('message', (raw) => {
        let msg;
        try { msg = JSON.parse(raw); } catch { return; }
        if (!msg || typeof msg !== 'object') return;

        if (msg.type === 'join') {
            joinedRoom = msg.room || 'default';
            role = msg.role;
            if (!rooms.has(joinedRoom)) rooms.set(joinedRoom, {});
            rooms.get(joinedRoom)[role] = ws;
            console.log(`[${joinedRoom}] ${role} joined`);

            const room = rooms.get(joinedRoom);
            if (room.sender && room.viewer) {
                room.sender.send(JSON.stringify({ type: 'ready' }));
                room.viewer.send(JSON.stringify({ type: 'ready' }));
            }
            return;
        }

        if (!joinedRoom) return;
        const room = rooms.get(joinedRoom);
        if (!room) return;
        const other = role === 'sender' ? room.viewer : room.sender;
        if (other && other.readyState === 1) {
            other.send(JSON.stringify(msg));
        }
    });

    ws.on('close', () => {
        if (joinedRoom && rooms.has(joinedRoom)) {
            const room = rooms.get(joinedRoom);
            if (room[role] === ws) delete room[role];
            if (!room.sender && !room.viewer) rooms.delete(joinedRoom);
            console.log(`[${joinedRoom}] ${role} left`);
        }
    });
}

wss.on('connection', handleSignaling);
wssHttp.on('connection', handleSignaling);

// ============================================================
// IN-MEMORY STORAGE
// ============================================================
let allMessages = [];
let connectedDevices = new Map();
let securityPersonnel = new Map();
let activePanics = new Map();
let activatedCameras = new Map();
let stats = {
    totalMessages: 0,
    panicAlerts: 0,
    incidentReports: 0,
    witnessConfirmations: 0,
    securityResponses: 0,
    sosAlerts: 0,
    triageReports: 0,
    shelterUpdates: 0,
    missingPersons: 0,
    broadcasts: 0
};

// ============================================================
// CLAUDE TRANSCRIPT ANALYSIS
// ============================================================
async function analyzeTranscript(transcript, messageId) {
    try {
        const response = await claude.messages.create({
            model: 'claude-sonnet-4-20250514',
            max_tokens: 512,
            messages: [{
                role: 'user',
                content: `You are an emergency dispatch AI analyst. Analyze this audio transcript from a live incident recording captured via a panic button on a phone. Be concise and actionable.

Transcript: "${transcript}"

Respond in this exact JSON format:
{
  "threatLevel": "low|medium|high|critical",
  "summary": "1-2 sentence summary of the situation",
  "actionItems": ["item1", "item2"],
  "detectedThreats": ["threat1"],
  "recommendedResponse": "brief recommended action for dispatch"
}`
            }]
        });
        const text = response.content[0].text;
        // Parse the JSON from Claude's response
        const jsonMatch = text.match(/\{[\s\S]*\}/);
        if (jsonMatch) {
            const analysis = JSON.parse(jsonMatch[0]);
            // Store analysis on the message
            const msg = allMessages.find(m => m.id === messageId);
            if (msg) {
                msg.aiAnalysis = analysis;
                console.log(`   Claude analysis complete for ${messageId}: ${analysis.threatLevel}`);
            }
            return analysis;
        }
    } catch (err) {
        console.error('Claude analysis failed:', err.message);
    }
    return null;
}

// Server-side transcription from base64 audio embedded in messages
async function transcribeBase64Audio(base64Audio, messageId) {
    const audioPath = path.join(__dirname, 'uploads', `msg_${messageId}.m4a`);
    try {
        // Decode base64 and write to temp file
        const buffer = Buffer.from(base64Audio, 'base64');
        fs.writeFileSync(audioPath, buffer);
        console.log(`\nWhisper (base64): decoding ${Math.round(buffer.length / 1024)}KB for message ${messageId}`);

        // Transcribe with Whisper
        const transcription = await openai.audio.transcriptions.create({
            file: fs.createReadStream(audioPath),
            model: 'whisper-1',
            language: 'en',
            response_format: 'text'
        });

        const transcript = (typeof transcription === 'string' ? transcription : transcription.text || '').trim();
        console.log(`   Whisper result: "${transcript.substring(0, 120)}"`);

        // Store transcript on the message and remove the base64 audio (save memory)
        const msg = allMessages.find(m => m.id === messageId);
        if (msg) {
            msg.data.audioTranscript = transcript;
            delete msg.data.audioBase64;

            // Now run Claude analysis
            if (transcript.length > 5) {
                analyzeTranscript(transcript, messageId);
            }
        }

        try { fs.unlinkSync(audioPath); } catch {}
    } catch (err) {
        console.error(`Whisper (base64) failed for ${messageId}:`, err.message);
        try { fs.unlinkSync(audioPath); } catch {}
    }
}

// ============================================================
// API: MESSAGES
// ============================================================
app.post('/api/messages', (req, res) => {
    const { deviceId, deviceName, deviceRole, dutyStatus, timestamp, messages } = req.body;

    console.log(`\nReceived sync from ${deviceName} (${deviceId?.substring(0, 8) || 'unknown'}...) role=${deviceRole || 'civilian'}`);

    connectedDevices.set(deviceId, {
        name: deviceName,
        role: deviceRole || 'civilian',
        dutyStatus: dutyStatus || 'off_duty',
        lastSeen: new Date(timestamp)
    });

    if (deviceRole === 'security' || deviceRole === 'admin') {
        securityPersonnel.set(deviceId, {
            name: deviceName,
            dutyStatus: dutyStatus || 'off_duty',
            lastSeen: new Date(timestamp),
            skills: [],
            respondingTo: null
        });
    }

    if (messages && Array.isArray(messages)) {
        let newCount = 0;
        messages.forEach(msg => {
            const exists = allMessages.some(m => m.id === msg.id);
            if (!exists) {
                allMessages.push({ ...msg, receivedAt: new Date(), gatewayDevice: deviceName });
                newCount++;
                stats.totalMessages++;
                switch (msg.type) {
                    case 'panic': stats.panicAlerts++; break;
                    case 'incident-report': stats.incidentReports++; break;
                    case 'witness-confirm': stats.witnessConfirmations++; break;
                    case 'security-response': stats.securityResponses++; break;
                    case 'sos': stats.sosAlerts++; break;
                    case 'triage': stats.triageReports++; break;
                    case 'shelter': stats.shelterUpdates++; break;
                    case 'missing-person': stats.missingPersons++; break;
                    case 'broadcast': stats.broadcasts++; break;
                }

                if (msg.type === 'panic' && msg.data?.panicId) {
                    activePanics.set(msg.data.panicId, {
                        senderId: msg.senderId, senderName: msg.senderName,
                        latitude: msg.data?.latitude, longitude: msg.data?.longitude,
                        emergencyType: msg.data?.emergencyType,
                        severity: msg.data?.severityScore || 5,
                        witnesses: 0, responders: [],
                        description: msg.data?.description, timestamp: msg.timestamp,
                        simulated: !!msg.simulated
                    });
                }
                if (msg.type === 'witness-confirm' && msg.data?.confirmedPanicId) {
                    const panic = activePanics.get(msg.data.confirmedPanicId);
                    if (panic) {
                        panic.witnesses = (panic.witnesses || 0) + 1;
                        if (panic.witnesses >= 3 && panic.severity < 10) panic.severity = Math.min(panic.severity + 2, 10);
                    }
                }
                if (msg.type === 'security-response' && msg.data?.respondingToPanicId) {
                    const panic = activePanics.get(msg.data.respondingToPanicId);
                    if (panic && !panic.responders.includes(msg.senderId)) panic.responders.push(msg.senderId);
                    if (securityPersonnel.has(msg.senderId)) {
                        const guard_ = securityPersonnel.get(msg.senderId);
                        guard_.dutyStatus = 'responding';
                        guard_.respondingTo = msg.data.respondingToPanicId;
                        if (msg.data?.latitude) guard_.lat = msg.data.latitude;
                        if (msg.data?.longitude) guard_.lng = msg.data.longitude;
                    }
                }
                if (msg.type === 'security-status') {
                    securityPersonnel.set(msg.senderId, {
                        name: msg.senderName,
                        dutyStatus: msg.data?.isOnDuty ? 'on_duty' : 'off_duty',
                        lat: msg.data?.latitude, lng: msg.data?.longitude,
                        skills: msg.data?.skills || [],
                        respondingTo: null, lastSeen: new Date()
                    });
                }
            }
        });
        console.log(`   New messages: ${newCount}`);

        // Trigger Claude analysis for any messages with audio transcripts (fire-and-forget)
        messages.filter(m => m.data?.audioTranscript && !m.simulated).forEach(msg => {
            analyzeTranscript(msg.data.audioTranscript, msg.id);
        });

        // Server-side Whisper transcription for messages with embedded audio (base64)
        // This handles the background auto-fire case where the iOS app couldn't do the upload
        messages.filter(m => m.data?.audioBase64 && !m.data?.audioTranscript && !m.simulated).forEach(msg => {
            transcribeBase64Audio(msg.data.audioBase64, msg.id);
        });
    }

    res.json({ success: true, message: `Received ${messages?.length || 0} messages`, totalStored: allMessages.length });
});

app.get('/api/messages', (req, res) => {
    const { type, limit = 100 } = req.query;
    let filtered = allMessages;
    if (type && type !== 'all') filtered = allMessages.filter(m => m.type === type);
    filtered.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
    res.json(filtered.slice(0, parseInt(limit)));
});

app.get('/api/stats', (req, res) => {
    const now = Date.now();
    for (const [id, g] of securityPersonnel) {
        if (now - new Date(g.lastSeen).getTime() > 120000) securityPersonnel.delete(id);
    }
    // When ?real=true, compute stats from non-simulated messages only
    let effectiveStats = stats;
    if (req.query.real === 'true') {
        effectiveStats = { totalMessages:0, panicAlerts:0, incidentReports:0, witnessConfirmations:0,
            securityResponses:0, sosAlerts:0, triageReports:0, shelterUpdates:0, missingPersons:0, broadcasts:0 };
        allMessages.filter(m => !m.simulated).forEach(msg => {
            effectiveStats.totalMessages++;
            switch (msg.type) {
                case 'panic': effectiveStats.panicAlerts++; break;
                case 'incident-report': effectiveStats.incidentReports++; break;
                case 'witness-confirm': effectiveStats.witnessConfirmations++; break;
                case 'security-response': effectiveStats.securityResponses++; break;
                case 'sos': effectiveStats.sosAlerts++; break;
                case 'triage': effectiveStats.triageReports++; break;
                case 'shelter': effectiveStats.shelterUpdates++; break;
                case 'missing-person': effectiveStats.missingPersons++; break;
                case 'broadcast': effectiveStats.broadcasts++; break;
            }
        });
    }
    res.json({
        ...effectiveStats,
        connectedDevices: connectedDevices.size,
        securityOnDuty: Array.from(securityPersonnel.values()).filter(g => g.dutyStatus === 'on_duty' || g.dutyStatus === 'responding').length,
        activePanicCount: activePanics.size,
        devices: Array.from(connectedDevices.entries()).map(([id, info]) => ({
            id: id.substring(0, 8) + '...', name: info.name,
            role: info.role, dutyStatus: info.dutyStatus, lastSeen: info.lastSeen
        }))
    });
});

app.get('/api/security', (req, res) => {
    res.json(Array.from(securityPersonnel.entries()).map(([id, info]) => ({
        id: id.substring(0, 8) + '...', fullId: id, name: info.name,
        dutyStatus: info.dutyStatus, latitude: info.lat, longitude: info.lng,
        skills: info.skills, respondingTo: info.respondingTo, lastSeen: info.lastSeen
    })));
});

app.get('/api/panics', (req, res) => {
    const panics = Array.from(activePanics.entries()).map(([id, info]) => ({
        id, ...info, responderCount: info.responders.length
    }));
    panics.sort((a, b) => b.severity - a.severity);
    res.json(panics);
});

// ============================================================
// WHISPER TRANSCRIPTION + CLAUDE ANALYSIS
// ============================================================
// Transcribe-only: returns transcript to the app. Does NOT create messages or run Claude.
// The app shows the transcript to the user, user submits, then the full report syncs to dashboard.
app.post('/api/transcribe', upload.single('audio'), async (req, res) => {
    const file = req.file;
    if (!file) return res.status(400).json({ error: 'No audio file' });

    console.log(`\nWhisper transcription request: ${file.originalname || file.filename} (${Math.round(file.size / 1024)}KB)`);

    try {
        const audioPath = file.path + '.m4a';
        fs.renameSync(file.path, audioPath);

        const transcription = await openai.audio.transcriptions.create({
            file: fs.createReadStream(audioPath),
            model: 'whisper-1',
            language: 'en',
            response_format: 'text'
        });

        const transcript = (typeof transcription === 'string' ? transcription : transcription.text || '').trim();
        console.log(`   Whisper result: "${transcript.substring(0, 120)}"`);

        try { fs.unlinkSync(audioPath); } catch {}

        res.json({ success: true, transcript: transcript });
    } catch (err) {
        console.error('Whisper failed:', err.message);
        try { fs.unlinkSync(file.path); } catch {}
        try { fs.unlinkSync(file.path + '.m4a'); } catch {}
        res.status(500).json({ error: 'Transcription failed: ' + err.message });
    }
});

// Full incident detail: panic + related messages + nearby cameras
app.get('/api/incident/:panicId', (req, res) => {
    const panicId = req.params.panicId;
    const panic = activePanics.get(panicId);
    if (!panic) return res.status(404).json({ error: 'Panic not found' });

    // Find all related messages (the panic itself, witness confirmations, security responses, incident reports with this panicId)
    const related = allMessages.filter(m =>
        (m.data?.panicId === panicId) ||
        (m.data?.confirmedPanicId === panicId) ||
        (m.data?.respondingToPanicId === panicId)
    ).sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));

    // Find transcript — prioritize exact panicId match, fallback to senderId
    let transcripts = allMessages.filter(m =>
        m.data?.audioTranscript && m.data?.panicId === panicId
    );
    if (transcripts.length === 0) {
        transcripts = allMessages.filter(m =>
            m.data?.audioTranscript && m.senderId === panic.senderId
        );
    }

    // Find cameras within 500m
    const nearbyCameras = [];
    if (panic.latitude && panic.longitude) {
        for (const cam of cameras) {
            const dist = distanceMeters(panic.latitude, panic.longitude, cam.location.latitude, cam.location.longitude);
            if (dist <= 500) {
                const activation = activatedCameras.get(cam.id);
                nearbyCameras.push({ ...cam, distance: Math.round(dist), isActivated: !!activation, activation });
            }
        }
        nearbyCameras.sort((a, b) => a.distance - b.distance);
    }

    // Get AI analysis from any transcript message
    const aiAnalysis = transcripts.find(m => m.aiAnalysis)?.aiAnalysis || null;
    const transcript = transcripts.find(m => m.data?.audioTranscript)?.data?.audioTranscript || null;

    res.json({
        panic: { id: panicId, ...panic, responderCount: panic.responders.length },
        relatedMessages: related,
        transcript,
        aiAnalysis,
        nearbyCameras,
        timeline: related.map(m => ({
            type: m.type, senderName: m.senderName, timestamp: m.timestamp,
            description: m.data?.description || m.data?.estimatedArrival || formatTypeServer(m.type)
        }))
    });
});

function formatTypeServer(type) {
    return (type || '').replace(/[-_]/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
}

app.get('/api/analysis/:messageId', (req, res) => {
    const msg = allMessages.find(m => m.id === req.params.messageId);
    if (!msg) return res.status(404).json({ error: 'Message not found' });
    res.json({ messageId: msg.id, aiAnalysis: msg.aiAnalysis || null, transcript: msg.data?.audioTranscript || null });
});

app.delete('/api/messages/simulation', (req, res) => {
    const before = allMessages.length;
    allMessages = allMessages.filter(m => !m.simulated);
    const removed = before - allMessages.length;
    // Rebuild stats from remaining real messages
    stats = { totalMessages: allMessages.length, panicAlerts:0, incidentReports:0, witnessConfirmations:0,
              securityResponses:0, sosAlerts:0, triageReports:0, shelterUpdates:0,
              missingPersons:0, broadcasts:0 };
    activePanics.clear();
    allMessages.forEach(msg => {
        switch (msg.type) {
            case 'panic': stats.panicAlerts++; break;
            case 'incident-report': stats.incidentReports++; break;
            case 'witness-confirm': stats.witnessConfirmations++; break;
            case 'security-response': stats.securityResponses++; break;
            case 'sos': stats.sosAlerts++; break;
            case 'triage': stats.triageReports++; break;
            case 'shelter': stats.shelterUpdates++; break;
            case 'missing-person': stats.missingPersons++; break;
            case 'broadcast': stats.broadcasts++; break;
        }
        if (msg.type === 'panic' && msg.data?.panicId) {
            activePanics.set(msg.data.panicId, {
                senderId: msg.senderId, senderName: msg.senderName,
                latitude: msg.data?.latitude, longitude: msg.data?.longitude,
                emergencyType: msg.data?.emergencyType,
                severity: msg.data?.severityScore || 5,
                witnesses: 0, responders: [],
                description: msg.data?.description, timestamp: msg.timestamp
            });
        }
    });
    res.json({ success: true, message: `Cleared ${removed} simulation messages`, totalStored: allMessages.length });
});

app.delete('/api/messages', (req, res) => {
    const count = allMessages.length;
    allMessages = [];
    connectedDevices.clear();
    securityPersonnel.clear();
    activePanics.clear();
    activatedCameras.clear();
    stats = { totalMessages:0, panicAlerts:0, incidentReports:0, witnessConfirmations:0,
              securityResponses:0, sosAlerts:0, triageReports:0, shelterUpdates:0,
              missingPersons:0, broadcasts:0 };
    res.json({ success: true, message: `Cleared ${count} messages`, totalStored: 0 });
});

app.get('/api/map-data', (req, res) => {
    const mapMessages = allMessages.filter(m =>
        (m.data?.latitude && m.data?.longitude) || m.data?.location || m.data?.lastSeenLocation
    ).map(m => ({
        id: m.id, type: m.type, latitude: m.data?.latitude, longitude: m.data?.longitude,
        location: m.data?.location || m.data?.lastSeenLocation,
        senderName: m.senderName, senderRole: m.senderRole, timestamp: m.timestamp,
        emergencyType: m.data?.emergencyType, severityScore: m.data?.severityScore,
        panicId: m.data?.panicId, data: m.data,
        simulated: !!m.simulated
    }));
    res.json(mapMessages);
});

// ============================================================
// CAMERA SYSTEM
// ============================================================
const cameras = [
    { id: 'cam-1', name: 'Drexel 33rd & Market', location: { latitude: 39.9566, longitude: -75.1899 }, status: 'online', type: 'campus', coverageRadius: 200 },
    { id: 'cam-2', name: 'SEPTA 30th St Station', location: { latitude: 39.9557, longitude: -75.1822 }, status: 'online', type: 'transit', coverageRadius: 150 },
    { id: 'cam-3', name: 'Rittenhouse Square', location: { latitude: 39.9496, longitude: -75.1718 }, status: 'online', type: 'public', coverageRadius: 250 },
    { id: 'cam-4', name: 'Temple University Main', location: { latitude: 39.9812, longitude: -75.1553 }, status: 'offline', type: 'campus', coverageRadius: 200 }
];

function distanceMeters(lat1, lon1, lat2, lon2) {
    const R = 6371000;
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a = Math.sin(dLat/2)**2 + Math.cos(lat1*Math.PI/180)*Math.cos(lat2*Math.PI/180)*Math.sin(dLon/2)**2;
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function checkCameraActivation() {
    for (const [panicId, panic] of activePanics) {
        if (!panic.latitude || !panic.longitude) continue;
        for (const cam of cameras) {
            const dist = distanceMeters(panic.latitude, panic.longitude, cam.location.latitude, cam.location.longitude);
            if (dist <= cam.coverageRadius && !activatedCameras.has(cam.id)) {
                activatedCameras.set(cam.id, { panicId, activatedAt: new Date(), reason: `Incident ${Math.round(dist)}m away`, distance: Math.round(dist) });
                console.log(`Camera ${cam.name} auto-activated`);
            }
        }
    }
}

app.get('/api/cameras', (req, res) => {
    checkCameraActivation();
    // Check which cameras have active WebRTC senders
    const liveRooms = Array.from(rooms.entries()).filter(([, r]) => r.sender).map(([id]) => id);
    const result = cameras.map(cam => {
        const activation = activatedCameras.get(cam.id);
        const isLive = liveRooms.includes(cam.id);
        return { ...cam, status: isLive ? 'online' : cam.status, isActivated: !!activation, activation: activation || null, isLive };
    });
    res.json(result);
});

app.post('/api/cameras/:id/activate', (req, res) => {
    const cam = cameras.find(c => c.id === req.params.id);
    if (!cam) return res.status(404).json({ error: 'Camera not found' });
    activatedCameras.set(cam.id, { panicId: req.body.panicId || 'manual', activatedAt: new Date(), reason: req.body.reason || 'Manually activated', distance: 0 });
    res.json({ success: true, camera: cam.id, status: 'activated' });
});

app.post('/api/cameras/:id/deactivate', (req, res) => {
    activatedCameras.delete(req.params.id);
    res.json({ success: true, camera: req.params.id, status: 'deactivated' });
});

// ============================================================
// SERVE & START
// ============================================================
app.get('/', (req, res) => { res.sendFile(path.join(__dirname, 'public', 'index.html')); });

if (require.main === module) {
    const nets = os.networkInterfaces();
    const addrs = [];
    for (const name of Object.keys(nets)) {
        for (const n of nets[name]) {
            if (n.family === 'IPv4' && !n.internal) addrs.push(n.address);
        }
    }

    // HTTP on port 3000 (for app sync + dashboard)
    httpServer.listen(PORT, '0.0.0.0', () => {
        console.log(`\n   HTTP on port ${PORT} (dashboard + app sync)`);
    });

    // HTTPS on port 3443 (for phone camera)
    if (httpsServer) {
        httpsServer.listen(3443, '0.0.0.0', () => {
            console.log(`   HTTPS on port 3443 (phone camera)`);
            console.log(`
========================================================
   MAYDAY DISPATCH DASHBOARD

   Dashboard:    http://localhost:${PORT}
   App syncs to: http://<MAC-IP>:${PORT}/api/messages`);
            for (const a of addrs) {
                console.log(`   Phone camera: https://${a}:3443/camera.html`);
            }
            console.log(`
   Cameras: ${cameras.length} configured
========================================================`);
        });
    }
}

module.exports = app;
