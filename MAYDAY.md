# Mayday — Community Safety Mesh Network

**Mayday** is a decentralized, mesh-based emergency response system built for Philadelphia. It uses Bluetooth Low Energy (BLE) mesh networking to create a peer-to-peer safety network that works even when cellular and WiFi infrastructure fails — in SEPTA underground stations, dense campus buildings, and during network outages.

When someone is in danger, they press a button — or just squeeze their iPhone's Action Button in their pocket — and the entire mesh knows. Security guards get alerted, nearby witnesses can confirm, and a dispatch dashboard lights up with real-time incident data, camera feeds, and response tracking.

---

## The Problem

Philadelphia faces real public safety challenges — campus robberies, incidents in SEPTA underground, and areas where calling 911 isn't fast enough or even possible. Existing solutions depend on cellular networks, require opening an app, or don't connect victims to the people closest to them.

**Mayday solves three specific problems:**

1. **No signal underground** — SEPTA stations, parking garages, and dense buildings have dead zones. Mayday's BLE mesh doesn't need cell service.
2. **Slow response loops** — Calling 911 routes through a centralized dispatcher who has no local context. Mayday alerts the nearest security guard directly, with GPS and incident type, before 911 even picks up.
3. **Isolated incidents** — A robbery victim is alone. Mayday turns every phone in range into a witness node that can corroborate, escalate, and track the response.

---

## System Architecture

Mayday has three layers:

```
+----------------------------------------------------------+
|                   DISPATCH DASHBOARD                      |
|   Real-time map, incident tracking, camera feeds,         |
|   security personnel management, severity scoring         |
+---------------------------+------------------------------+
                            |
                     Gateway Sync (HTTP)
                     (any device with internet
                      becomes a gateway)
                            |
+---------------------------+------------------------------+
|                    BLE MESH NETWORK                        |
|   MultipeerConnectivity (Bluetooth + WiFi Direct)         |
|   Multi-hop relay, 10-hop TTL, auto-discovery             |
|   Works completely offline                                 |
+---------------------------+------------------------------+
                            |
              +-------------+-------------+
              |             |             |
         Civilians    Security      Witnesses
         (panic,      (duty,        (confirm,
          report)      respond)      corroborate)
```

### Layer 1: BLE Mesh Network
- Apple MultipeerConnectivity framework (Bluetooth LE + WiFi Direct)
- Messages relay through up to 10 hops across the mesh
- UUID-based deduplication prevents message loops
- Auto-discovery and auto-connect with retry every 10 seconds
- Works completely offline — no internet required for local alerting

### Layer 2: Gateway Sync
- Any device that gains internet connectivity auto-promotes to a "gateway"
- Gateways sync all collected mesh messages to the dispatch dashboard every 30 seconds
- Other mesh nodes learn about gateway availability and hop distance
- When a gateway goes offline, the mesh continues functioning independently

### Layer 3: Dispatch Intelligence Dashboard
- Browser-based real-time command center
- Leaflet.js interactive map centered on Philadelphia
- Live incident tracking with severity scoring
- Security personnel locations and response status
- Auto-activating camera feeds near incidents
- Simulation mode for demos

---

## Features

### 1. Silent Panic Trigger (Action Button)

The most critical feature. A user can trigger a panic alert **without opening the app or looking at their phone**.

**How it works:**
- User assigns Mayday to their iPhone's Action Button (iPhone 15 Pro+) via iOS Shortcuts
- Pressing the Action Button silently starts recording audio and sends a panic alert to the mesh
- The phone stays in the pocket — no screen, no unlock, no interaction needed
- The alert broadcasts via BLE mesh to all nearby nodes
- Audio is saved locally for later evidence
- When the user opens the app later, they're prompted to add suspect description, clothing, direction of travel

**Also works via:**
- Siri: "Hey Siri, Mayday emergency"
- In-app panic button (big red button with emergency type selection)

**Technical implementation:**
- `AppIntents` framework with `SendPanicAlertIntent`
- `openAppWhenRun = false` for silent background execution
- `AVAudioRecorder` with background audio mode
- `AudioRecordingService` persists recording state across app launches

---

### 2. Mesh-Based Panic Network

When a panic fires, it propagates through the mesh:

```
User presses panic
    |
    v
BLE Mesh broadcasts to all connected nodes
    |
    +---> Nearby civilians see "Incident reported near you"
    |         |
    |         v
    |     Witness Mesh prompts: "Can you confirm?"
    |         |
    |         v
    |     3+ confirmations = severity escalation
    |
    +---> On-duty security guards get priority alert
    |         |
    |         v
    |     Guard taps "Respond" — broadcasts ETA
    |         |
    |         v
    |     User sees: "Security responding — ETA 2 min"
    |
    +---> Gateway device syncs to dashboard
              |
              v
          Dashboard shows incident on map
          Nearest camera auto-activates
          Dispatcher sees full context
```

---

### 3. Witness Mesh

When a panic alert reaches nearby users, they get a floating prompt:

> "An incident was reported near you. Can you safely confirm?"
>
> [Can't Confirm] [Add Note] [Confirm]

- Multiple confirmations increase the incident's severity score
- 3+ confirmations trigger automatic escalation
- Witnesses can add notes ("I can see it happening", "I heard shouting")
- This gives dispatchers **corroboration without requiring 911 calls**
- It's a decentralized verification layer

---

### 4. Multi-Organization Security Network

Security personnel from different organizations all operate on the same mesh:

| Organization | Coverage Area |
|---|---|
| Philadelphia Police | City-wide |
| Drexel Public Safety | Drexel + University City |
| Penn Police | UPenn + University City |
| Temple Police | Temple campus |
| SEPTA Transit Police | SEPTA stations |
| Campus Security | All universities |
| Private Security | City-wide |

**How guards join:**
1. Enter their organization's security code (e.g., `SEC-DREXEL-001`)
2. Select their department (Drexel Public Safety, Philly PD, etc.)
3. Tag their skills (CPR, First Aid, EMT, Armed, etc.)
4. Toggle "On Duty" when their shift starts

**On the mesh:**
- On-duty guards broadcast their location every 15 seconds
- Their nodes appear as blue shields on the network map
- When a panic fires, the nearest available guard gets a priority alert
- Guards tap "Respond" to claim the incident — other guards and the victim see the response
- Dashboard tracks which guard is responding to which incident

**Skill matching:**
- If an incident is medical, the system finds the nearest CPR/EMT-certified person
- Security guards, off-duty EMTs, and trained civilians can all be matched

---

### 5. Incident Classification & Severity Scoring

Every panic and incident report gets a severity score (1-10):

| Incident Type | Base Severity | With Weapons | With 3+ Witnesses |
|---|---|---|---|
| Assault | 8 | 10 | 10 |
| Robbery | 7 | 10 | 9 |
| Medical Emergency | 7 | — | 9 |
| Harassment | 5 | 8 | 7 |
| Theft | 5 | 8 | 7 |
| Car Break-In | 4 | 7 | 6 |
| Suspicious Activity | 3 | 6 | 5 |
| Vandalism | 3 | 6 | 5 |

Severity escalates when:
- Weapons are mentioned (+3)
- 3+ witnesses confirm (+2)
- Urgency is marked "critical" (+2)

The severity score drives prioritization on the dashboard and determines which security personnel are alerted first.

---

### 6. Incident-Centric Feed

The app's main feed groups related messages into **incident clusters**:

```
┌─────────────────────────────────────────────┐
│ ▌ ROBBERY                        2 min ago  │
│ ▌ "Being robbed near parking garage"        │
│ ▌                                           │
│ ▌ [Severity 7/10 — HIGH]                   │
│ ▌                                           │
│ ▌ 👤 Alex   👁 3 witnesses   🛡 1 responding│
│ ▌                                           │
│ ▌ ▼ Show 5 updates                         │
│ └───────────────────────────────────────────│
│   ● Panic Alert — Alex — 2 min ago         │
│   ● Witness Confirmed — Jordan — 1 min ago │
│   ● Witness Confirmed — Sam — 1 min ago    │
│   ● Witness Confirmed — Riley — 45s ago    │
│   ● Security Responding — Officer Davis     │
│     ETA: < 2 min                            │
└─────────────────────────────────────────────┘
```

A colored severity strip on the left edge gives instant visual priority. Standalone messages (broadcasts, safe zones, missing persons) appear below the incident clusters.

---

### 7. Incident Map (Philadelphia)

A MapKit-based view centered on Philadelphia showing:
- **Red pins** — Panic alerts (size scaled by severity)
- **Orange pins** — Incident reports
- **Blue shield markers** — On-duty security personnel with name labels
- **Green pins** — Safe zones / shelters
- **Small green checks** — Witness confirmations

Time filter: Last Hour / Last 24 Hours / All

Philly landmarks (Drexel, Temple, UPenn, SEPTA stations, Rittenhouse Square) appear as subtle gray reference pins.

---

### 8. Dispatch Intelligence Dashboard

A browser-based command center for dispatchers, campus police, and administrators.

**Map view:**
- Full-screen Leaflet.js map centered on Philadelphia
- Dark theme with inverted tiles (white roads on dark background)
- Pulsing red markers for active panics with severity numbers
- Blue shield markers for on-duty security
- Orange markers for incident reports
- Dotted red circles (danger zones) around active incidents
- Blue dashed lines from responding guards to their assigned incidents

**Panels:**
- **Right panel** — Live message feed with color-coded cards
- **Left panel** — Security personnel list and active panics
- **Bottom stats bar** — Panics, Incidents, Security On Duty, Witnesses, Devices
- **Camera panel** — Auto-activating camera feeds (see below)

**Simulation mode:** Generates realistic Philly-based incident data through a 15-phase scenario covering all message types.

---

### 9. Camera Integration

The dashboard supports live camera feeds that auto-activate when incidents occur nearby.

**How it works:**
- Cameras are configured with GPS coordinates and a coverage radius
- When a panic/incident is reported within a camera's radius, the camera auto-activates on the dashboard
- The camera panel slides up showing live MJPEG feeds
- A "LIVE" badge with recording indicator appears on active cameras
- The activation reason is shown ("Incident reported 150m away")

**Pre-configured cameras:**
| Camera | Location | Coverage |
|---|---|---|
| Drexel 33rd & Market | 39.9566, -75.1899 | 200m |
| SEPTA 30th St Station | 39.9557, -75.1822 | 150m |
| Rittenhouse Square | 39.9496, -75.1718 | 250m |
| Temple University Main | 39.9812, -75.1553 | 200m |

**For demos:** iPhones running MJPEG camera apps serve as IP cameras. Stream URLs are configurable via API.

---

### 10. Community Onboarding

First launch walks users through a 4-page setup:

1. **Welcome** — Mayday branding and tagline
2. **Features** — How the mesh works (panic, security, witness, map)
3. **Community** — Pick your organization (Drexel, Temple, UPenn, SEPTA, University City, Philadelphia Community)
4. **Name** — Set your display name for the mesh

The selected community determines:
- Which security organizations cover your area
- Default map center (Drexel campus vs Temple vs city-wide)
- Which mesh group you're associated with

---

### 11. Network Visualization

A canvas-based topology view showing the live mesh network:
- **Your device** at center (large node)
- **Connected peers** in inner ring
- **Multi-hop devices** in outer rings
- **Green nodes** — devices with internet (gateways)
- **Blue shield nodes** — on-duty security personnel
- **Red pulsing nodes** — near active incidents
- **Black nodes** — standard offline devices
- Connection lines show mesh routing paths
- Animated dots show message relay in real-time

---

## Technical Stack

### iOS App
| Component | Technology |
|---|---|
| Language | Swift 5 |
| UI Framework | SwiftUI |
| Mesh Networking | MultipeerConnectivity (BLE + WiFi Direct) |
| Location | CoreLocation |
| Audio Recording | AVFoundation |
| Siri/Shortcuts | AppIntents (iOS 16+) |
| Maps | MapKit |
| Persistence | UserDefaults (JSON) |
| Min iOS | 16.0 |

### Dashboard
| Component | Technology |
|---|---|
| Backend | Express.js (Node.js) |
| Frontend | HTML5 + CSS3 + Vanilla JS |
| Maps | Leaflet.js 1.9.4 |
| Deployment | Vercel (serverless) |
| Camera Feeds | MJPEG over HTTP |

---

## File Structure

```
pigeon/
├── CapsuleMesh/                          # iOS App
│   ├── CapsuleMeshApp.swift              # App entry + post-incident detection
│   ├── Models/
│   │   ├── MessageType.swift             # 16 message types
│   │   ├── MeshMessage.swift             # Message + data payload
│   │   ├── Peer.swift                    # Connected peer model
│   │   └── UserRole.swift                # UserRole, DutyStatus, UserSkill,
│   │                                     # IncidentType, Organization,
│   │                                     # SecurityOrganization
│   ├── Services/
│   │   ├── MeshNetworkService.swift      # Core mesh + security tracking +
│   │   │                                 # panic/witness/response handling
│   │   ├── GatewayService.swift          # Internet sync to dashboard
│   │   ├── AudioRecordingService.swift   # Silent background recording
│   │   ├── AppIntents.swift              # Siri + Action Button intents
│   │   ├── LocationService.swift         # GPS
│   │   ├── MessageStore.swift            # Message persistence
│   │   ├── DeviceIdentity.swift          # User profile + org + role
│   │   └── SimulationService.swift       # Demo simulation (7 scenarios)
│   ├── ViewModels/
│   │   └── MeshViewModel.swift
│   ├── Views/
│   │   ├── MainTabView.swift             # Tab bar (Feed/Mesh/Panic/Incidents/Settings)
│   │   ├── MessagesView.swift            # Incident-centric grouped feed
│   │   ├── PanicView.swift               # Panic button + form
│   │   ├── IncidentMapView.swift         # Philly incident map
│   │   ├── IncidentReportView.swift      # Detailed incident form
│   │   ├── SecurityDashboardView.swift   # Security duty + incident management
│   │   ├── WitnessPromptView.swift       # Witness corroboration overlay
│   │   ├── PostIncidentView.swift        # Post-recording appearance form
│   │   ├── NetworkMapView.swift          # Mesh topology visualization
│   │   ├── WelcomeView.swift             # 4-page onboarding
│   │   ├── SettingsView.swift            # App configuration
│   │   └── [legacy views]               # SOS, Triage, Shelter, etc.
│   └── Utilities/
│       ├── Constants.swift               # Mesh config + PhillyLocations
│       └── Theme.swift                   # MaydayBrand + all UI components
│
├── pigeon-dashboard/                     # Dispatch Dashboard
│   ├── server.js                         # Express API (messages, security,
│   │                                     # panics, cameras)
│   ├── public/index.html                 # Full dashboard UI
│   ├── package.json
│   └── vercel.json                       # Deployment config
│
└── MAYDAY.md                             # This file
```

---

## API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/messages` | Receive gateway syncs from app |
| GET | `/api/messages` | Retrieve messages (filter by type) |
| GET | `/api/stats` | Dashboard statistics |
| GET | `/api/map-data` | Messages with GPS coordinates |
| GET | `/api/security` | Security personnel locations |
| GET | `/api/panics` | Active panic incidents |
| GET | `/api/cameras` | Camera list with activation status |
| POST | `/api/cameras/:id/activate` | Manually activate camera |
| POST | `/api/cameras/:id/deactivate` | Deactivate camera |
| POST | `/api/cameras/config` | Update camera stream URLs |
| DELETE | `/api/messages` | Clear all data |

---

## Simulation Scenarios

| Scenario | Peers | Security | Gateways | Description |
|---|---|---|---|---|
| Normal | 10 | 2 | 2 | Regular activity |
| Disaster Response | 15 | 3 | 1 | High alert |
| Dense Urban | 25 | 5 | 5 | Frequent messages |
| Rural/Sparse | 4 | 1 | 1 | Spread out |
| No Internet | 10 | 2 | 0 | Mesh only |
| **Campus Safety** | **20** | **6** | **3** | **University campus** |
| **SEPTA Underground** | **15** | **4** | **1** | **Underground station** |

---

## Why Philadelphia

Mayday isn't generic safety tech — it's built for this city:

- **SEPTA underground** — No cell service in subway stations. BLE mesh works.
- **University City** — Drexel, UPenn, and the surrounding area have distinct security organizations that don't always coordinate. Mayday connects them on one mesh.
- **Temple campus** — North Philly has specific safety challenges. Campus police, Philly PD, and students are all on the same network.
- **Neighborhood patterns** — Incident classification uses severity scoring tuned for urban crime types (robbery, car break-ins, harassment).
- **Multi-jurisdiction** — Philly PD, campus police, SEPTA police, and private security all show up as distinct organizations on the dashboard. A dispatcher can see the full picture across jurisdictions.

---

## Demo Setup

### Dashboard
```bash
cd pigeon-dashboard
npm install
npm start
# Open http://localhost:3000
# Click "Simulate" to generate test data
```

### Camera Setup
1. Install "IPCamera Lite" (or similar MJPEG app) on 2-3 iPhones
2. Connect all devices to the same WiFi network
3. Note each phone's stream URL (shown in the camera app)
4. Configure via API:
```bash
curl -X POST http://localhost:3000/api/cameras/config \
  -H 'Content-Type: application/json' \
  -d '{"id":"cam-1","streamUrl":"http://192.168.1.101:8080/video","status":"online"}'
```

### iOS App
1. Open `CapsuleMesh.xcodeproj` in Xcode
2. Build to physical iPhone (BLE mesh requires real hardware)
3. Complete onboarding (pick community + name)
4. Go to Settings > enable Simulation > pick "Campus Safety"
5. For Action Button: Settings > Action Button > Shortcut > "Mayday Silent Alert"

---

## Team

Built for Philadelphia. Built for safety. Built on mesh.
