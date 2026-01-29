# AutoDetail Hub iOS App Specification

**Version:** 1.0  
**Platform:** iOS 13.0+  
**Language:** Swift  
**Architecture:** MVVM with Combine/async-await

---

## Table of Contents

1. [Overview](#overview)
2. [App Architecture & Flow](#app-architecture--flow)
3. [Initialization & Setup](#initialization--setup)
4. [User Profile Management](#user-profile-management)
5. [API Integration](#api-integration)
6. [Data Models](#data-models)
7. [UI Requirements](#ui-requirements)
8. [Error Handling](#error-handling)
9. [Security](#security)
10. [Testing](#testing)

---

## Overview

The AutoDetail Hub iOS app allows customers to:

- Connect to a beauty/detail service backend
- Create and manage their profile (name, car details, photo)
- Browse available services
- View available appointment slots
- Create bookings
- Upload before/after photos
- Receive messages from admin

### Key Features

- **One-time Setup:** User connects to server once via QR code or manual address entry
- **Auto-generated API Key:** Backend generates unique API key on first connection
- **Profile Creation:** User fills in name, car make, car plate, and selects profile photo
- **Service Browsing:** Browse available services with pricing and duration
- **Appointment Booking:** Check availability and book appointments
- **Photo Upload:** Upload before/after photos to appointments
- **Admin Messages:** Receive push notifications for admin messages

---

## App Architecture & Flow

### Initialization Flow

```
┌─────────────────────────────────┐
│   App Launches for First Time   │
└──────────────┬──────────────────┘
               │
               ▼
    ┌──────────────────────┐
    │ Show Setup Screen    │
    │ - QR Code Scanner   │
    │ - Manual URL Entry  │
    └──────────┬───────────┘
               │
               ▼
    ┌──────────────────────────────┐
    │ POST /api/ios/init           │
    │ Returns: { apiKey, baseUrl } │
    └──────────┬───────────────────┘
               │
               ▼
    ┌──────────────────────────────┐
    │ Store API Key in Keychain    │
    │ Store Base URL               │
    └──────────┬───────────────────┘
               │
               ▼
    ┌──────────────────────────────┐
    │ Show Profile Setup Screen    │
    │ - Name Input                 │
    │ - Car Make Input             │
    │ - Car Plate Input            │
    │ - Photo Selection/Camera     │
    └──────────┬───────────────────┘
               │
               ▼
    ┌────────────────────────────┐
    │ POST /api/ios/profile      │
    │ Create User Profile        │
    └──────────┬─────────────────┘
               │
               ▼
    ┌──────────────────────┐
    │ Show Main App Tab    │
    │ Navigation Ready     │
    └──────────────────────┘
```

### Main App Navigation

```
Tab Bar Controller
├── Home / Dashboard
│   ├── Quick Stats
│   ├── Next Appointment
│   └── Quick Actions
├── Services
│   ├── Service List
│   └── Service Details
├── Bookings
│   ├── Active Appointments
│   ├── Past Appointments
│   └── Appointment Details
├── Messages
│   ├── Unread Messages
│   └── Message Center
└── Profile
    ├── User Info
    ├── Edit Profile
    ├── Uploaded Photos
    └── Settings
```

---

## Initialization & Setup

### Screen 1: Welcome / Setup Selection

**Title:** "Welcome to AutoDetail Hub"

**UI Elements:**

- App logo
- Description text
- "Scan QR Code" button
- "Enter Address Manually" button
- Version number

**Actions:**

- Scan QR code → Extract baseUrl and apiKey (if provided in QR)
- Manual entry → Show URL input field

### Screen 2: Server Connection

**If Manual Entry:**

- Text field for server URL (e.g., "https://autodetail.com")
- "Connect" button
- Loading spinner during connection

**Actions:**

- POST /api/ios/init
- Store apiKey in Keychain
- Store baseUrl in UserDefaults
- Show success message
- Proceed to Profile Setup

### Screen 3: Profile Setup

**Fields:**

1. **Full Name** (required, text input)
2. **Car Make** (required, text field with autocomplete, common values: BMW, Mercedes, Toyota, etc.)
3. **Car Plate** (required, text input, format varies by country)
4. **Profile Photo** (required, choice of):
   - Take photo with camera
   - Choose from photo library
   - Choose from preset images (provided by app)

**Preset Images Suggestion:**
The app can provide 8-12 generic car photos that users can choose from without needing to upload their own. Example:

- Black modern sedan
- White SUV
- Red sports car
- Blue sedan
- Silver truck
- Gray hatchback
- etc.

**Upload Photos:**
For profile photos taken with camera or from library:

1. Call `POST /api/uploads/presign` to get S3 upload URL
2. Compress image (max 2MB, JPEG)
3. Upload to S3 using presigned URL
4. Get returned S3 key/reference

**Submit Profile:**

- POST /api/ios/profile with all details
- Show loading indicator
- Handle errors (missing fields, network issues)
- On success → Show main app

---

## User Profile Management

### GET /api/ios/profile

**Headers:**

```
X-API-Key: [apiKey]
```

**Response:**

```json
{
  "id": "user-123",
  "apiKey": "ios_[timestamp]_[random]",
  "name": "John Doe",
  "carMake": "BMW",
  "carPlate": "ABC123",
  "profilePhotoUrl": "https://s3.example.com/...",
  "status": "active",
  "messages": [
    {
      "id": "msg-1",
      "text": "Your appointment is ready",
      "sentAt": "2024-01-20T10:30:00Z",
      "read": false
    }
  ]
}
```

**Usage:**

- Call on app launch to refresh user data
- Display profile info
- Check for unread messages

### POST /api/ios/profile

**Headers:**

```
X-API-Key: [apiKey]
Content-Type: application/json
```

**Request Body:**

```json
{
  "name": "John Doe",
  "carMake": "BMW",
  "carPlate": "ABC123",
  "profilePhotoUrl": "https://s3.example.com/..."
}
```

**Response:**

```json
{
  "id": "user-123",
  "apiKey": "ios_[timestamp]_[random]",
  "name": "John Doe",
  "carMake": "BMW",
  "carPlate": "ABC123",
  "profilePhotoUrl": "https://s3.example.com/..."
}
```

**Usage:**

- Update profile after initial setup
- Change car details
- Update profile photo
- Called from Profile edit screen

---

## API Integration

### Base Configuration

```swift
class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private var baseURL: URL
    private var apiKey: String

    func initialize(baseURL: URL, apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        // Store to Keychain and UserDefaults
    }

    private func request<T: Decodable>(
        _ endpoint: String,
        method: String = "GET",
        body: Encodable? = nil
    ) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(endpoint))
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}
```

### Endpoints

#### 1. Initialize Connection (First Launch)

**Endpoint:** `POST /api/ios/init`

**No authentication required**

**Response:**

```json
{
  "apiKey": "ios_1705767890_abc123def456",
  "baseUrl": "https://autodetail.com"
}
```

#### 2. Get Services

**Endpoint:** `GET /api/client/services`

**Headers:**

```
X-API-Key: [apiKey]
```

**Response:**

```json
[
  {
    "id": "service-1",
    "name": "Car Washing",
    "description": "Full exterior wash with premium products",
    "priceRub": 1500,
    "durationMinutes": 60,
    "imageUrl": "https://...",
    "createdAt": "2024-01-01T10:00:00Z"
  },
  {
    "id": "service-2",
    "name": "Interior Detailing",
    "description": "Deep clean of interior",
    "priceRub": 2500,
    "durationMinutes": 120,
    "imageUrl": "https://...",
    "createdAt": "2024-01-01T10:00:00Z"
  }
]
```

#### 3. Get Availability

**Endpoint:** `GET /api/client/availability?date=2024-01-25&serviceId=service-1&tzOffsetMinutes=-180`

**Parameters:**

- `date`: YYYY-MM-DD format (required)
- `serviceId`: Service ID (optional)
- `tzOffsetMinutes`: Client timezone offset in minutes (required, e.g., -180 for UTC+3)

**Response:**

```json
[
  {
    "startIso": "2024-01-25T08:00:00Z",
    "endIso": "2024-01-25T09:00:00Z",
    "startTime": "11:00",
    "remainingCapacity": 2,
    "totalCapacity": 2,
    "bookedCount": 0,
    "isAvailable": true
  },
  {
    "startIso": "2024-01-25T08:30:00Z",
    "endIso": "2024-01-25T09:30:00Z",
    "startTime": "11:30",
    "remainingCapacity": 1,
    "totalCapacity": 2,
    "bookedCount": 1,
    "isAvailable": true
  }
]
```

#### 4. Create Appointment

**Endpoint:** `POST /api/client/appointments`

**Headers:**

```
X-API-Key: [apiKey]
```

**Request Body:**

```json
{
  "startIso": "2024-01-25T08:00:00Z",
  "clientName": "John Doe",
  "phone": "+79991234567",
  "carMake": "BMW",
  "carPlate": "ABC123",
  "serviceName": "Car Washing",
  "notes": "Extra care on the paint"
}
```

**Response:**

```json
{
  "id": "appt-123",
  "source": "ios",
  "status": "new",
  "startIso": "2024-01-25T08:00:00Z",
  "clientName": "John Doe",
  "phone": "+79991234567",
  "carMake": "BMW",
  "carPlate": "ABC123",
  "serviceName": "Car Washing",
  "notes": "Extra care on the paint",
  "createdAt": "2024-01-20T10:30:00Z"
}
```

#### 5. Upload Photos

**Step 1: Get Presigned URL**

**Endpoint:** `POST /api/uploads/presign`

**Headers:**

```
X-API-Key: [apiKey]
```

**Request Body:**

```json
{
  "appointmentId": "appt-123",
  "kind": "work",
  "filename": "photo_20240120_103000.jpg",
  "contentType": "image/jpeg"
}
```

**Response:**

```json
{
  "uploadUrl": "https://s3.example.com/...?Signature=...",
  "accessUrl": "https://s3.example.com/...",
  "key": "appointments/appt-123/work/photo.jpg",
  "ref": "s3:appointments/appt-123/work/photo.jpg"
}
```

**Step 2: Upload to S3**

```swift
var request = URLRequest(url: URL(string: uploadUrl)!)
request.httpMethod = "PUT"
request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
request.httpBody = imageData

let (_, response) = try await URLSession.shared.data(for: request)
```

**Step 3: Link Photo to Appointment**

**Endpoint:** `POST /api/client/appointments/{appointmentId}/photos`

**Headers:**

```
X-API-Key: [apiKey]
```

**Request Body:**

```json
{
  "kind": "work",
  "photoUrls": ["s3:appointments/appt-123/work/photo.jpg"]
}
```

#### 6. Get Messages

**Endpoint:** `GET /api/ios/messages`

**Headers:**

```
X-API-Key: [apiKey]
```

**Response:**

```json
{
  "messages": [
    {
      "id": "msg-1",
      "text": "Your appointment is confirmed for tomorrow at 10:00",
      "sentAt": "2024-01-20T10:30:00Z",
      "read": false
    }
  ],
  "count": 1
}
```

#### 7. Mark Message as Read

**Endpoint:** `POST /api/ios/messages/{messageId}/read`

**Headers:**

```
X-API-Key: [apiKey]
```

**Response:**

```json
{
  "message": "Message marked as read"
}
```

---

## Data Models

### Core Models

```swift
// MARK: - User Profile
struct UserProfile: Codable {
    let id: String
    let apiKey: String
    let name: String
    let carMake: String
    let carPlate: String
    let profilePhotoUrl: String?
    let status: String
    let createdAt: String
}

// MARK: - Service
struct Service: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let priceRub: Int
    let durationMinutes: Int
    let imageUrl: String?
    let createdAt: String

    var formattedPrice: String {
        "\(priceRub) ₽"
    }
}

// MARK: - Availability Slot
struct AvailabilitySlot: Codable {
    let startIso: String
    let endIso: String
    let startTime: String // HH:mm
    let remainingCapacity: Int
    let totalCapacity: Int
    let bookedCount: Int
    let isAvailable: Bool

    var displayTime: String {
        startTime
    }

    var capacityPercentage: Double {
        Double(bookedCount) / Double(totalCapacity)
    }
}

// MARK: - Appointment
struct Appointment: Codable, Identifiable {
    let id: String
    let source: String // "ios"
    let status: String // "new", "confirmed", "done"
    let startIso: String
    let endIso: String?
    let clientName: String
    let phone: String?
    let carMake: String?
    let carPlate: String?
    let serviceName: String
    let notes: String?
    let workPhotos: [Photo]
    let defectPhotos: [Photo]
    let createdAt: String
    let updatedAt: String
}

struct Photo: Codable, Identifiable {
    let id: String
    let url: String
    let createdAt: String
}

// MARK: - Message
struct AdminMessage: Codable, Identifiable {
    let id: String
    let text: String
    let sentAt: String
    var read: Bool = false
}

// MARK: - API Response Wrappers
struct InitResponse: Codable {
    let apiKey: String
    let baseUrl: String
}

struct MessagesResponse: Codable {
    let messages: [AdminMessage]
    let count: Int
}
```

---

## UI Requirements

### Screens Overview

#### 1. **Setup / Onboarding Screens**

- Welcome screen
- QR code scanner
- Manual URL entry
- Profile setup (name, car, photo)
- Loading/confirmation

#### 2. **Home / Dashboard**

- User greeting
- Next appointment card
- Quick stats (total bookings, total spent)
- Quick action buttons (Book, Messages, Profile)

#### 3. **Services List**

- Filtered list of services
- Service cards showing:
  - Service name
  - Price
  - Duration
  - Image
- Search/filter options
- "Book" button per service

#### 4. **Service Details**

- Full service description
- Price breakdown (if applicable)
- Duration
- Photos gallery
- Reviews (optional)
- "Book Now" button

#### 5. **Booking Flow**

- Date picker (calendar)
- Time picker (available slots)
- Summary of service + price + time
- Confirm button
- Success screen with appointment details

#### 6. **Appointments List**

- Tabs: Active / Upcoming / Past / Cancelled
- Appointment cards showing:
  - Service name
  - Date and time
  - Car info
  - Status badge
  - "View Details" button

#### 7. **Appointment Details**

- Full appointment info
- Status
- Timeline (created → confirmed → completed)
- Photos section (work photos, defect photos)
- Upload photo button (if active)
- Cancel/reschedule buttons (if applicable)
- Notes section

#### 8. **Messages**

- List of messages with date
- Unread badge/indicator
- Message detail view
- Mark as read
- Delete message

#### 9. **Profile**

- User info card (name, car, photo)
- Edit button
- Logout button
- App version
- Help/Support link

### Design System Recommendations

**Colors:**

- Primary: Blue (#007AFF)
- Accent: Orange (#FF9500)
- Success: Green (#34C759)
- Error: Red (#FF3B30)
- Background: Light gray (#F2F2F7)

**Typography:**

- Headings: System Bold, 18-24pt
- Body: System Regular, 14-16pt
- Captions: System Regular, 12-13pt

**Components:**

- Standard iOS components (UITableView, UICollectionView, etc.)
- Large readable buttons (44pt minimum tap target)
- Cards with shadows for depth
- Loading spinners and progress indicators

---

## Error Handling

### HTTP Status Codes

| Code          | Meaning       | Action                                 |
| ------------- | ------------- | -------------------------------------- |
| 200           | Success       | Proceed normally                       |
| 400           | Bad Request   | Show error message, check input        |
| 401           | Unauthorized  | API key invalid/expired, show re-login |
| 404           | Not Found     | Show "not found" error                 |
| 500           | Server Error  | Show "try again later" message         |
| Network error | No connection | Show offline indicator                 |

### Error Messages (User-Friendly)

```swift
enum APIError: LocalizedError {
    case invalidResponse
    case decodingError
    case networkError
    case unauthorized
    case serverError(String?)
    case validationError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Unexpected response from server"
        case .decodingError:
            return "Failed to parse response"
        case .networkError:
            return "No internet connection"
        case .unauthorized:
            return "Invalid API key. Please reconnect."
        case .serverError(let message):
            return message ?? "Server error. Please try again."
        case .validationError(let message):
            return message
        }
    }
}
```

### Retry Logic

- Automatic retry on network errors (up to 3 times)
- Exponential backoff (1s, 2s, 4s)
- Manual "Retry" button in error alerts
- Show error in UI if all retries fail

---

## Security

### API Key Storage

**iOS Keychain:**

```swift
import Security

class KeychainManager {
    static let shared = KeychainManager()

    func save(apiKey: String) throws {
        let data = apiKey.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "autodetail_api_key",
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        try SecItemAdd(query as CFDictionary, nil)
            .checkStatus()
    }

    func retrieve() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "autodetail_api_key",
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)

        guard let data = result as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            return nil
        }
        return apiKey
    }
}
```

### Base URL Storage

**UserDefaults (encrypted on device):**

```swift
class AppConfig {
    static let shared = AppConfig()

    var baseURL: URL? {
        get {
            guard let url = UserDefaults.standard.string(forKey: "base_url") else {
                return nil
            }
            return URL(string: url)
        }
        set {
            UserDefaults.standard.set(newValue?.absoluteString, forKey: "base_url")
        }
    }
}
```

### HTTPS Only

- Always use HTTPS for all API calls
- Validate SSL certificates
- Consider certificate pinning for production

### Data Privacy

- Do not log API keys
- Do not include sensitive data in analytics
- Request location permission only when needed
- Request camera/photo library permission at time of use

---

## Testing

### Unit Tests

```swift
class APIClientTests: XCTestCase {
    var apiClient: APIClient!
    var mockSession: URLSession!

    override func setUp() {
        super.setUp()
        apiClient = APIClient()
        mockSession = URLSession(configuration: .ephemeral)
    }

    func testInitConnection() async throws {
        let response = try await apiClient.initConnection()
        XCTAssertNotNil(response.apiKey)
        XCTAssertNotNil(response.baseUrl)
    }

    func testGetServices() async throws {
        let services = try await apiClient.getServices()
        XCTAssertFalse(services.isEmpty)
    }

    func testGetAvailability() async throws {
        let date = "2024-01-25"
        let slots = try await apiClient.getAvailability(
            date: date,
            serviceId: "service-1",
            tzOffsetMinutes: -180
        )
        XCTAssertFalse(slots.isEmpty)
    }
}
```

### UI Tests

```swift
class OnboardingUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        super.setUp()
        app.launch()
    }

    func testOnboardingFlow() {
        // Test QR code scanning
        // Test manual URL entry
        // Test profile setup
        // Test successful profile creation
    }
}
```

### Integration Tests

- Test full user flow: Setup → Profile → Services → Booking → Upload photos
- Test network failures and recovery
- Test concurrent API requests
- Test data persistence across app restarts

---

## Implementation Checklist

- [ ] Setup Xcode project structure (MVVM pattern)
- [ ] Create APIClient with base request methods
- [ ] Implement Keychain manager for secure storage
- [ ] Create all data models
- [ ] Implement onboarding screens
  - [ ] Welcome screen
  - [ ] QR code scanner
  - [ ] Manual URL entry
  - [ ] Profile setup
- [ ] Create home/dashboard screen
- [ ] Implement services list and details
- [ ] Implement booking flow with date/time picker
- [ ] Create appointments list and detail view
- [ ] Implement photo upload functionality
- [ ] Add messaging system
- [ ] Create profile management screen
- [ ] Implement push notifications for messages
- [ ] Add error handling and retry logic
- [ ] Implement local caching (services, appointments)
- [ ] Write unit tests
- [ ] Write UI tests
- [ ] Beta testing
- [ ] App Store submission

---

## Deployment

### Environment Configuration

**Development:**

```
BASE_URL = http://localhost:8080 (or dev server)
API_VERSION = 1.0
LOG_LEVEL = debug
```

**Production:**

```
BASE_URL = https://api.autodetailhub.com
API_VERSION = 1.0
LOG_LEVEL = error
```

### App Store Submission

1. Create app in App Store Connect
2. Prepare screenshots and description
3. Set minimum iOS version (13.0)
4. Configure capabilities (Camera, Photo Library, Location if needed)
5. Submit for review
6. Monitor for feedback and respond

### Post-Launch

- Monitor crash reports in Xcode Organizer
- Track analytics (sessions, feature usage)
- Collect user feedback
- Plan updates based on usage patterns
- Communicate app updates to users

---

## Support & Documentation

**For Developers:**

- API documentation: `/api/docs` endpoint
- Error reference: See section on Error Handling
- Code samples: Provided in Data Models section

**For Users:**

- In-app help screen
- FAQ section
- Support email: support@autodetailhub.com
- Customer service hotline (if available)

---

## Version History

| Version | Date       | Changes               |
| ------- | ---------- | --------------------- |
| 1.0     | 2024-01-20 | Initial specification |

---

## Contact

**Project Manager:** [Contact Info]  
**Backend Lead:** [Contact Info]  
**Design Lead:** [Contact Info]

For questions or clarifications, please contact the project manager.
