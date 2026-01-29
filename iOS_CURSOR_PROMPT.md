# iOS App Development Prompt: AutoDetail Hub
## Complete Specification for Cursor / AI-Assisted Development

---

## 🎯 PROJECT OVERVIEW

### Application Purpose
Develop a native iOS app that allows car owners to connect to the AutoDetail Hub service backend and manage their car detailing/car wash appointments. Users can browse services, book appointments, upload photos, and receive admin messages.

### Key Characteristics
- **Platform:** iOS 13.0+
- **Language:** Swift
- **Architecture:** MVVM with Combine/async-await
- **Authentication:** API Key stored in iOS Keychain
- **Backend:** REST API (all endpoints pre-built and ready)
- **Timeline:** 6-8 weeks (2 week checkpoints)
- **App Store Ready:** Yes, with proper code signing and review preparation

### Unique Feature: Auto-Generated API Keys
- On first app launch, the backend automatically generates a unique API key
- This key is used for all subsequent authenticated requests
- Key is stored securely in iOS Keychain (NOT UserDefaults)
- Serves as the unique user identifier across the backend

---

## 📱 USER FLOWS

### Flow 1: First-Time Setup (Onboarding)
```
1. App Launches
2. Check if API key exists in Keychain
3. If NOT found → Show Welcome/Setup Screen
4. User Scan QR Code OR Enter Server URL Manually
5. POST /api/ios/init → Get unique API key
6. Store API key in Keychain + base URL in UserDefaults
7. Show Profile Setup Screen
8. User enters: Name, Car Make, Car Plate, Select Photo
9. POST /api/ios/profile → Create user profile
10. Show main app with TabBar navigation
11. API key stored for all future requests
```

### Flow 2: Main App Navigation (After Setup)
```
TabBar Navigation:
├── Home/Dashboard Tab
│   ├── User greeting + quick stats
│   ├── Next upcoming appointment
│   ├── Quick action buttons
│   └── Pull-to-refresh
│
├── Services Tab
│   ├── List of all available services
│   ├── Service details (tap to expand)
│   ├── Price, duration, description, image
│   └── "Book Service" button
│
├── Bookings Tab
│   ├── Active appointments (upcoming)
│   ├── Past appointments (completed/cancelled)
│   ├── Tap to view full details
│   ├── Upload photos to appointment
│   └── Cancel appointment option
│
├── Messages Tab
│   ├── List of all messages from admin
│   ├── Unread count badge
│   ├── Mark as read
│   ├── Timestamp for each message
│   └── Auto-refresh
│
└── Profile Tab
    ├── User name, car details
    ├── Profile photo
    ├── Edit profile option
    ├── Change car details
    ├── Change profile photo
    ├── Settings (change server, logout)
    └── App version info
```

### Flow 3: Booking Appointment
```
1. User taps "Book Service" (from Services tab)
2. Show date picker (next 30 days)
3. POST /api/client/availability → Fetch available slots
4. Show time slots with capacity indicator
5. User selects time slot
6. POST /api/client/appointments → Create booking
7. Show confirmation with appointment ID
8. Appointment appears in Bookings tab
```

### Flow 4: Photo Upload to Appointment
```
1. User navigates to appointment details
2. Sections for "Work Photos" and "Defect Photos"
3. Tap "Add Photo" button
4. Show options: Camera, Photo Library, Preset Images
5. Image selected/captured → Compress to JPEG (max 2MB)
6. POST /api/uploads/presign → Get S3 upload URL
7. PUT image to S3 URL
8. POST /api/client/appointments/{id}/photos → Link photo
9. Photo appears in appointment (with spinner during upload)
```

---

## 🔗 BACKEND API ENDPOINTS (COMPLETE REFERENCE)

### Authentication & Initialization

#### POST /api/ios/init
**Purpose:** Initialize connection and receive API key (first launch)  
**Authentication:** None required  
**Request Body:** Empty  

**Response (200 OK):**
```json
{
  "apiKey": "ios_1705767890_abc123def456",
  "baseUrl": "https://autodetail.com"
}
```

**Implementation Notes:**
- Call this endpoint when user connects via QR code or manual URL entry
- Store `apiKey` in iOS Keychain
- Store `baseUrl` in UserDefaults
- No X-API-Key header needed for this endpoint

---

### User Profile Management

#### GET /api/ios/profile
**Purpose:** Fetch current user's profile information  
**Authentication:** Required (X-API-Key header)  
**Headers:** `X-API-Key: [apiKey]`  

**Response (200 OK):**
```json
{
  "id": "user-123",
  "apiKey": "ios_1705767890_abc123def456",
  "name": "John Doe",
  "carMake": "BMW",
  "carPlate": "ABC123",
  "profilePhotoUrl": "https://s3.example.com/...",
  "status": "active",
  "createdAt": "2024-01-20T10:00:00Z",
  "lastSeenAt": "2024-01-20T14:30:00Z",
  "messages": [
    {
      "id": "msg-1",
      "text": "Your appointment is confirmed",
      "sentAt": "2024-01-20T10:30:00Z",
      "read": false
    }
  ]
}
```

**Error Responses:**
- 401: Invalid/missing API key
- 404: User not found (should not happen)

**Implementation Notes:**
- Call on app launch to refresh user data
- Check `messages` array for unread messages
- Update UI with user info

---

#### POST /api/ios/profile
**Purpose:** Create or update user profile (initial setup or editing)  
**Authentication:** Required (X-API-Key header)  
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

**Response (200 OK):**
```json
{
  "id": "user-123",
  "apiKey": "ios_1705767890_abc123def456",
  "name": "John Doe",
  "carMake": "BMW",
  "carPlate": "ABC123",
  "profilePhotoUrl": "https://s3.example.com/...",
  "status": "active",
  "createdAt": "2024-01-20T10:00:00Z"
}
```

**Validation Rules:**
- `name`: Required, 2-100 characters
- `carMake`: Required, 2-50 characters (BMW, Toyota, Mercedes, etc.)
- `carPlate`: Required, 2-20 characters
- `profilePhotoUrl`: Optional, valid image URL or S3 reference

**Implementation Notes:**
- Called during initial profile setup (after /api/ios/init)
- Also called when user edits their profile
- All fields can be updated later

---

### Messages

#### GET /api/ios/messages
**Purpose:** Fetch all messages for current user  
**Authentication:** Required (X-API-Key header)  
**Headers:** `X-API-Key: [apiKey]`  
**Query Parameters:** None  

**Response (200 OK):**
```json
{
  "messages": [
    {
      "id": "msg-1",
      "text": "Your appointment ABC-123 is confirmed",
      "sentAt": "2024-01-20T10:30:00Z",
      "read": false
    },
    {
      "id": "msg-2",
      "text": "Please review and confirm your appointment",
      "sentAt": "2024-01-20T09:00:00Z",
      "read": true
    }
  ]
}
```

**Implementation Notes:**
- Call periodically to check for new messages (suggest every 30-60 seconds)
- Display unread count in Messages tab badge
- Show timestamp in local device timezone

---

#### POST /api/ios/messages/:messageId/read
**Purpose:** Mark a specific message as read  
**Authentication:** Required (X-API-Key header)  
**Headers:** 
```
X-API-Key: [apiKey]
Content-Type: application/json
```

**Request Body:** Empty  

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Message marked as read"
}
```

**Implementation Notes:**
- Call when user views/reads a message
- Updates admin console to show read status
- No need to refresh entire messages list

---

### Services

#### GET /api/client/services
**Purpose:** Fetch list of all available services  
**Authentication:** Required (X-API-Key header)  
**Headers:** `X-API-Key: [apiKey]`  

**Response (200 OK):**
```json
[
  {
    "id": "service-1",
    "name": "Car Washing",
    "description": "Full exterior wash with premium products",
    "priceRub": 1500,
    "durationMinutes": 60,
    "imageUrl": "https://s3.example.com/service-1.jpg",
    "active": true,
    "createdAt": "2024-01-01T10:00:00Z"
  },
  {
    "id": "service-2",
    "name": "Interior Detailing",
    "description": "Deep clean of interior with vacuum and wipe",
    "priceRub": 2500,
    "durationMinutes": 120,
    "imageUrl": "https://s3.example.com/service-2.jpg",
    "active": true,
    "createdAt": "2024-01-01T10:00:00Z"
  }
]
```

**Implementation Notes:**
- Cache this response for at least 1 hour (reduce server load)
- Display service images using AsyncImage or SDWebImage
- Show price in RUB format
- Show duration in hours or hours:minutes format

---

#### GET /api/client/services/:id
**Purpose:** Fetch details for a single service  
**Authentication:** Required (X-API-Key header)  
**Headers:** `X-API-Key: [apiKey]`  

**Response (200 OK):**
```json
{
  "id": "service-1",
  "name": "Car Washing",
  "description": "Full exterior wash with premium products",
  "priceRub": 1500,
  "durationMinutes": 60,
  "imageUrl": "https://s3.example.com/service-1.jpg",
  "active": true,
  "createdAt": "2024-01-01T10:00:00Z"
}
```

**Implementation Notes:**
- Optional endpoint (use GET /api/client/services for list)
- Useful for showing expanded service details

---

### Availability & Booking

#### GET /api/client/availability
**Purpose:** Check available appointment slots for a given date  
**Authentication:** Required (X-API-Key header)  
**Headers:** `X-API-Key: [apiKey]`  
**Query Parameters:**
- `date`: Required, format YYYY-MM-DD (e.g., 2024-02-15)
- `serviceId`: Optional, filter by specific service
- `tzOffsetMinutes`: Required, client's timezone offset in minutes (e.g., -180 for UTC+3)

**Example Request:**
```
GET /api/client/availability?date=2024-02-15&serviceId=service-1&tzOffsetMinutes=-180
```

**Response (200 OK):**
```json
[
  {
    "startIso": "2024-02-15T08:00:00Z",
    "endIso": "2024-02-15T09:00:00Z",
    "startTime": "11:00",
    "endTime": "12:00",
    "remainingCapacity": 2,
    "totalCapacity": 2,
    "bookedCount": 0,
    "isAvailable": true
  },
  {
    "startIso": "2024-02-15T09:00:00Z",
    "endIso": "2024-02-15T10:00:00Z",
    "startTime": "12:00",
    "endTime": "13:00",
    "remainingCapacity": 0,
    "totalCapacity": 2,
    "bookedCount": 2,
    "isAvailable": false
  }
]
```

**Implementation Notes:**
- **CRITICAL:** Pass `tzOffsetMinutes` correctly!
  - UTC+3 (Moscow) = -180
  - UTC+0 (GMT) = 0
  - UTC-5 (EST) = 300
  - Calculate: `TimeZone.current.secondsFromGMT() / 60` (will be negative for east of GMT)
- Show available slots in local device time
- Disable booking for slots where `isAvailable` is false
- Show capacity indicator (2/2 booked, etc.)
- Refresh availability every time user changes date/service

---

#### POST /api/client/appointments
**Purpose:** Create a new appointment/booking  
**Authentication:** Required (X-API-Key header)  
**Headers:** 
```
X-API-Key: [apiKey]
Content-Type: application/json
```

**Request Body:**
```json
{
  "startIso": "2024-02-15T08:00:00Z",
  "clientName": "John Doe",
  "phone": "+79991234567",
  "telegram": "johndoe",
  "carMake": "BMW",
  "carPlate": "ABC123",
  "serviceName": "Car Washing",
  "notes": "Extra care needed - new paint"
}
```

**Field Requirements:**
- `startIso`: Required, ISO 8601 format, must match available slot
- `clientName`: Required, 2-100 characters (will use from profile if not provided)
- `phone`: Optional, international format preferred
- `telegram`: Optional, username without @
- `carMake`: Optional, will use from profile if not provided
- `carPlate`: Optional, will use from profile if not provided
- `serviceName`: Required, name of selected service
- `notes`: Optional, special requests or notes (max 500 chars)

**Response (201 Created):**
```json
{
  "id": "appt-789",
  "source": "ios",
  "status": "new",
  "startIso": "2024-02-15T08:00:00Z",
  "endIso": "2024-02-15T09:00:00Z",
  "clientName": "John Doe",
  "phone": "+79991234567",
  "telegram": "johndoe",
  "carMake": "BMW",
  "carPlate": "ABC123",
  "serviceName": "Car Washing",
  "notes": "Extra care needed - new paint",
  "workPhotos": [],
  "defectPhotos": [],
  "createdAt": "2024-02-15T10:30:00Z",
  "updatedAt": "2024-02-15T10:30:00Z"
}
```

**Error Responses:**
- 400: Missing required fields or invalid time slot
- 401: Invalid API key
- 409: Time slot no longer available

**Implementation Notes:**
- Show loading spinner during request
- Save appointment ID for later reference
- Show confirmation screen with appointment details
- Add to local Bookings list immediately
- Offer options: View appointment, Share booking ID, Continue booking

---

#### GET /api/client/appointments
**Purpose:** Fetch user's appointments (active and past)  
**Authentication:** Required (X-API-Key header)  
**Headers:** `X-API-Key: [apiKey]`  

**Response (200 OK):**
```json
[
  {
    "id": "appt-789",
    "source": "ios",
    "status": "new",
    "startIso": "2024-02-15T08:00:00Z",
    "endIso": "2024-02-15T09:00:00Z",
    "clientName": "John Doe",
    "phone": "+79991234567",
    "carMake": "BMW",
    "carPlate": "ABC123",
    "serviceName": "Car Washing",
    "workPhotos": [],
    "defectPhotos": [],
    "createdAt": "2024-02-15T10:30:00Z",
    "updatedAt": "2024-02-15T10:30:00Z"
  }
]
```

**Implementation Notes:**
- Call on app launch and Bookings tab open
- Sort by startIso (most recent first)
- Separate into "Upcoming" and "Past" sections
- Past = appointments where startIso is in the past

---

#### GET /api/client/appointments/:id
**Purpose:** Fetch details for a specific appointment  
**Authentication:** Required (X-API-Key header)  
**Headers:** `X-API-Key: [apiKey]`  

**Response (200 OK):** Same as single appointment object above

**Implementation Notes:**
- Used for detailed view of appointment
- Shows full details including all photos

---

### Photo Upload (S3 Integration)

#### POST /api/uploads/presign
**Purpose:** Get a presigned S3 URL to upload photos  
**Authentication:** Required (X-API-Key header)  
**Headers:** 
```
X-API-Key: [apiKey]
Content-Type: application/json
```

**Request Body:**
```json
{
  "appointmentId": "appt-789",
  "kind": "work",
  "filename": "photo_2024_01_20.jpg",
  "contentType": "image/jpeg"
}
```

**Field Explanations:**
- `appointmentId`: The ID of the appointment to attach photo to
- `kind`: Either "work" (after photo) or "defect" (before/defect photo)
- `filename`: Original filename (will be stored in S3)
- `contentType`: Must be "image/jpeg" (we only accept JPEG)

**Response (200 OK):**
```json
{
  "uploadUrl": "https://s3.example.com/...",
  "accessUrl": "https://s3.example.com/...",
  "key": "appointments/appt-789/work/photo.jpg",
  "ref": "s3:appointments/appt-789/work/photo.jpg"
}
```

**Implementation Notes:**
- `uploadUrl`: Use this for PUT request (upload image data)
- `key`: S3 object key
- `ref`: S3 reference, use this in the next POST call

---

#### PUT {uploadUrl}
**Purpose:** Upload image data to S3 using the presigned URL  
**Authentication:** None (URL is temporary and signed)  
**Headers:** 
```
Content-Type: image/jpeg
```

**Request Body:** Binary JPEG image data

**Implementation Notes:**
- Use the `uploadUrl` from /api/uploads/presign response
- HTTP method is PUT
- Upload the compressed JPEG image
- URL is valid for 60 seconds
- Show upload progress (use URLSessionUploadTask for progress)

---

#### POST /api/client/appointments/:id/photos
**Purpose:** Link uploaded photo to appointment  
**Authentication:** Required (X-API-Key header)  
**Headers:** 
```
X-API-Key: [apiKey]
Content-Type: application/json
```

**Request Body:**
```json
{
  "kind": "work",
  "photoUrls": ["s3:appointments/appt-789/work/photo.jpg"]
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Photo added to appointment"
}
```

**Implementation Notes:**
- Call after successfully uploading to S3
- `photoUrls` should match the `ref` from presign response
- Can upload multiple photos in single request
- Admin will see these in their console

---

## 📊 DATA MODELS (Swift Structs)

### User Profile
```swift
struct UserProfile: Codable {
    let id: String
    let apiKey: String
    let name: String
    let carMake: String
    let carPlate: String
    let profilePhotoUrl: String?
    let status: String // "active", "inactive", "banned"
    let createdAt: String
    let lastSeenAt: String?
    
    var initials: String {
        name.split(separator: " ")
            .map { String($0.prefix(1)) }
            .joined()
    }
}
```

### Service
```swift
struct Service: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let priceRub: Int
    let durationMinutes: Int
    let imageUrl: String?
    let active: Bool
    let createdAt: String
    
    var priceFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RUB"
        return formatter.string(from: NSNumber(value: priceRub)) ?? "\(priceRub) ₽"
    }
    
    var durationFormatted: String {
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60
        if hours > 0 && minutes > 0 {
            return "\(hours)ч \(minutes)мин"
        } else if hours > 0 {
            return "\(hours)ч"
        } else {
            return "\(minutes)мин"
        }
    }
}
```

### Availability Slot
```swift
struct AvailabilitySlot: Codable, Identifiable {
    let id = UUID()
    let startIso: String
    let endIso: String
    let startTime: String // Local time formatted "HH:mm"
    let endTime: String?  // Local time formatted "HH:mm"
    let remainingCapacity: Int
    let totalCapacity: Int
    let bookedCount: Int
    let isAvailable: Bool
    
    var capacityString: String {
        "\(remainingCapacity)/\(totalCapacity) доступно"
    }
    
    var startDate: Date {
        ISO8601DateFormatter().date(from: startIso) ?? Date()
    }
}
```

### Appointment
```swift
struct Appointment: Codable, Identifiable {
    let id: String
    let source: String // "ios", "admin"
    let status: String // "new", "confirmed", "in_progress", "done", "cancelled"
    let startIso: String
    let endIso: String?
    let clientName: String
    let phone: String?
    let telegram: String?
    let carMake: String?
    let carPlate: String?
    let serviceName: String
    let notes: String?
    let workPhotos: [Photo]
    let defectPhotos: [Photo]
    let createdAt: String
    let updatedAt: String
    
    var startDate: Date {
        ISO8601DateFormatter().date(from: startIso) ?? Date()
    }
    
    var isUpcoming: Bool {
        startDate > Date()
    }
    
    var statusColor: Color {
        switch status {
        case "confirmed": return .green
        case "in_progress": return .blue
        case "done": return .gray
        case "cancelled": return .red
        default: return .yellow
        }
    }
}
```

### Photo
```swift
struct Photo: Codable, Identifiable {
    let id: String
    let url: String
    let createdAt: String
}
```

### Admin Message
```swift
struct AdminMessage: Codable, Identifiable {
    let id: String
    let text: String
    let sentAt: String
    let read: Bool
    
    var sentDate: Date {
        ISO8601DateFormatter().date(from: sentAt) ?? Date()
    }
}
```

---

## 🏗️ ARCHITECTURE & CODE STRUCTURE

### MVVM Pattern with Combine

```
Project Structure:
├── App/
│   ├── AutoDetailHubApp.swift (main entry point)
│   └── AppDelegate.swift (if needed for lifecycle)
│
├── Models/
│   ├── UserProfile.swift
│   ├── Service.swift
│   ├── Appointment.swift
│   ├── AdminMessage.swift
│   └── APIModels.swift (codable structs)
│
├── ViewModels/
│   ├── AuthViewModel.swift (setup/onboarding)
│   ├── HomeViewModel.swift (dashboard)
│   ├── ServicesViewModel.swift (services list)
│   ├── BookingViewModel.swift (booking flow)
│   ├── AppointmentDetailViewModel.swift
│   ├── PhotoUploadViewModel.swift
│   ├── ProfileViewModel.swift
│   └── MessagesViewModel.swift
│
├── Views/
│   ├── ContentView.swift (main root)
│   ├── Auth/
│   │   ├── WelcomeScreen.swift
│   │   ├── QRCodeScannerScreen.swift
│   │   ├── ManualURLEntryScreen.swift
│   │   └── ProfileSetupScreen.swift
│   ├── Main/
│   │   ├── HomeTab.swift (dashboard)
│   │   ├── ServicesTab.swift
│   │   ├── BookingsTab.swift
│   │   ├── MessagesTab.swift
│   │   └── ProfileTab.swift
│   ├── Booking/
│   │   ├── DatePickerView.swift
│   │   ├── AvailabilitySlotsList.swift
│   │   └── BookingConfirmationView.swift
│   ├── AppointmentDetail/
│   │   ├── AppointmentDetailsView.swift
│   │   ├── PhotoGallery.swift
│   │   └── PhotoUploadView.swift
│   └── Components/
│       ├── LoadingView.swift
│       ├── ErrorView.swift
│       ├── ServiceCard.swift
│       └── AppointmentCard.swift
│
├── Services/
│   ├── APIClient.swift (HTTP client)
│   ├── KeychainService.swift (secure storage)
│   ├── ImageCompressionService.swift
│   ├── PhotoUploadService.swift (S3)
│   └── LocationService.swift (timezone)
│
├── Utilities/
│   ├── Constants.swift
│   ├── Extensions/
│   │   ├── String+Extensions.swift
│   │   ├── Date+Extensions.swift
│   │   └── Image+Extensions.swift
│   ├── Helpers/
│   │   ├── DateFormatter.swift
│   │   └── CurrencyFormatter.swift
│   └── ErrorHandling/
│       ├── APIError.swift
│       └── UserErrorMessage.swift
│
└── Resources/
    ├── Assets.xcassets
    ├── Localizable.strings
    └── PresetProfileImages/ (8-12 car photos)
```

---

## 🔐 SECURITY REQUIREMENTS

### 1. API Key Storage (CRITICAL)
- **NEVER** store API key in UserDefaults or plain text
- **ALWAYS** store in iOS Keychain using Security framework
- Access Keychain on every API request
- Provide option to logout (delete Keychain entry)

```swift
// Example Keychain storage
import Security

class KeychainService {
    static let shared = KeychainService()
    private let service = "com.autodetail.ios"
    
    func store(apiKey: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "apiKey",
            kSecValueData as String: apiKey.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.storeFailed }
    }
    
    func retrieve() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "apiKey",
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "apiKey"
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess else { throw KeychainError.deleteFailed }
    }
}
```

### 2. URL Validation
- Require HTTPS for all requests (except localhost during development)
- Validate certificate pinning if needed for production
- Show warning if user enters HTTP URL

### 3. Photo Uploads
- Compress images to max 2MB before upload
- Verify image type is JPEG only
- Delete temporary files after S3 upload
- Use URLSessionConfiguration with proper timeouts

### 4. Error Messages
- Show generic error messages to users
- Log detailed errors to console (development only)
- Never expose API keys, URLs, or sensitive data in error messages

### 5. Network Security
- Implement timeout (15-30 seconds) for all requests
- Handle expired API keys gracefully (show login screen)
- Implement exponential backoff for retries

---

## 🎨 UI/UX REQUIREMENTS

### Design System
- Use SwiftUI native components
- Follow iOS Human Interface Guidelines
- SF Symbols for all icons
- Support Dark Mode

### Color Palette (Suggest)
```swift
let primary = Color(red: 0.2, green: 0.5, blue: 1.0) // Blue
let success = Color.green
let warning = Color.orange
let error = Color.red
let background = Color(.systemBackground)
let secondaryBackground = Color(.systemGray6)
```

### Typography
- Headlines: System font, .title (bold)
- Body text: System font, .body
- Captions: System font, .caption

### Spacing & Layout
- Use standard iOS spacing (8, 16, 24 pts)
- Safe area insets for iPhone notch
- Bottom padding for Tab Bar
- Consistent horizontal margins (16pts)

---

## ⚠️ ERROR HANDLING

### Network Errors
```swift
enum APIError: Error {
    case invalidURL
    case networkError
    case invalidResponse
    case decodingError
    case serverError(statusCode: Int, message: String)
    case unauthorized // 401 - API key invalid
    case notFound // 404
    case rateLimited // 429
    case timeout
    case noInternetConnection
    
    var userMessage: String {
        switch self {
        case .networkError, .noInternetConnection:
            return "Проверьте интернет соединение"
        case .unauthorized:
            return "Сеанс истёк. Пожалуйста, переподключитесь"
        case .notFound:
            return "Данные не найдены"
        case .timeout:
            return "Истекло время ожидания. Проверьте интернет"
        case .serverError(_, let message):
            return message.isEmpty ? "Ошибка сервера. Повторите позже" : message
        default:
            return "Произошла ошибка. Повторите попытку"
        }
    }
}
```

### Validation Errors
- Show inline validation (red border, error message below field)
- Disable submit button if validation fails
- Show specific error for each field

### Photo Upload Errors
- Check file size before upload
- Handle network interruption during upload
- Provide retry button with exponential backoff
- Show upload progress (percentage)

---

## 📸 PHOTO HANDLING WORKFLOW

### Image Compression
```swift
func compressImage(_ image: UIImage, maxSizeMB: CGFloat = 2) -> Data? {
    var compression: CGFloat = 1.0
    var imageData = image.jpegData(compressionQuality: compression)
    
    let maxBytes = Int(maxSizeMB * 1024 * 1024)
    
    while let data = imageData, data.count > maxBytes && compression > 0.1 {
        compression -= 0.1
        imageData = image.jpegData(compressionQuality: compression)
    }
    
    return imageData
}
```

### Photo Upload Sequence
1. **Select Photo** → Camera/Library/Preset
2. **Compress** → JPEG max 2MB
3. **Get S3 URL** → POST /api/uploads/presign
4. **Upload to S3** → PUT with progress tracking
5. **Link Photo** → POST /api/client/appointments/{id}/photos
6. **Confirm** → Show photo in gallery

### Preset Images (MVP Recommendation)
Instead of requiring users to take/upload photos initially, provide 8-12 preset car images:
- Modern black sedan
- White SUV
- Red sports car
- Blue sedan
- Silver truck
- Gray hatchback
- Black SUV
- White hatchback

---

## 🧪 TESTING CHECKLIST

### Unit Tests
- [ ] APIClient request building and parsing
- [ ] KeychainService store/retrieve/delete
- [ ] Image compression utility
- [ ] Date formatting and timezone handling
- [ ] Model validation (name, phone, etc.)

### Integration Tests
- [ ] Complete onboarding flow (init → profile → main)
- [ ] Service list loading and caching
- [ ] Availability checking with timezone
- [ ] Booking creation end-to-end
- [ ] Photo upload to S3
- [ ] Message retrieval and marking read

### UI Tests
- [ ] QR code scanner flow
- [ ] Manual URL entry
- [ ] Profile setup with photo selection
- [ ] Service browsing
- [ ] Date/time picker
- [ ] Booking confirmation
- [ ] Photo upload progress

### Manual Testing
- [ ] Test on iPhone 12 mini (smallest screen)
- [ ] Test on iPhone 14 Pro Max (largest screen)
- [ ] Test with iPad (if supporting)
- [ ] Test dark mode toggle
- [ ] Test network error scenarios (airplane mode)
- [ ] Test offline to online transitions
- [ ] Test app backgrounding and resuming
- [ ] Test with slow network (simulate throttling)

### Backend Integration Testing
- [ ] Test with actual backend API
- [ ] Test all error scenarios (401, 404, 500)
- [ ] Test with invalid API key
- [ ] Test with expired slots (race condition)
- [ ] Test photo upload with poor network

---

## 📦 APP STORE SUBMISSION CHECKLIST

### Before Submission
- [ ] Minimum iOS 13.0 deployment target
- [ ] All screens support iPhone and iPad
- [ ] Dark mode fully supported
- [ ] Proper launch screen
- [ ] App icons (all sizes from Assets)
- [ ] Privacy policy URL added to Info.plist
- [ ] Permissions: Camera, Photo Library (Info.plist descriptions)

### App Metadata
- [ ] App name (max 30 chars)
- [ ] Subtitle (optional, 30 chars max)
- [ ] Description (4000 chars max)
- [ ] Keywords (100 chars max)
- [ ] Support URL
- [ ] Privacy policy URL
- [ ] Screenshots (5 per orientation)
- [ ] Preview video (optional)

### Privacy
- [ ] Privacy policy describes data collection
- [ ] Camera access explained
- [ ] Photo library access explained
- [ ] Network access explained
- [ ] No tracking without user consent

### Content Rating
- [ ] Complete content rating questionnaire
- [ ] No inappropriate content
- [ ] No personal data collection concerns

### Build Settings
- [ ] Code signing certificate setup
- [ ] Provisioning profile assigned
- [ ] Bundle ID registered in Apple Developer
- [ ] Version number incremented
- [ ] Build number incremented

---

## 🚀 DEVELOPMENT TIMELINE (Suggested)

### Week 1-2: Setup & Onboarding
- [ ] Xcode project setup (MVVM structure)
- [ ] Dependency management (Swift Package Manager)
- [ ] Welcome screen UI
- [ ] QR code scanner integration
- [ ] Manual URL entry screen
- [ ] API client setup with Combine
- [ ] Keychain service implementation
- [ ] Profile setup screen
- [ ] POST /api/ios/init integration
- [ ] POST /api/ios/profile integration

**Checkpoint:** User can scan QR code, enter URL, create profile, and reach main app

### Week 3-4: Services & Booking
- [ ] Services tab and list view
- [ ] Service detail view
- [ ] Date picker component
- [ ] GET /api/client/availability implementation
- [ ] Availability slots display
- [ ] Time slot selection
- [ ] POST /api/client/appointments implementation
- [ ] Booking confirmation screen
- [ ] Bookings tab (list of appointments)
- [ ] Appointment detail view

**Checkpoint:** User can browse services and complete booking

### Week 5-6: Photos & Messages
- [ ] Photo selection (camera/library/preset)
- [ ] Image compression utility
- [ ] POST /api/uploads/presign integration
- [ ] S3 upload with URLSession
- [ ] Upload progress indicator
- [ ] POST /api/client/appointments/{id}/photos
- [ ] Photo gallery in appointment detail
- [ ] Messages tab
- [ ] GET /api/ios/messages implementation
- [ ] POST /api/ios/messages/:id/read implementation
- [ ] Message notification indicator

**Checkpoint:** User can upload photos and receive messages

### Week 7: Profile & Polish
- [ ] Profile tab implementation
- [ ] Edit profile functionality
- [ ] POST /api/ios/profile (update)
- [ ] Logout functionality (delete Keychain)
- [ ] Settings screen (change server, etc.)
- [ ] Network error handling
- [ ] Loading states and spinners
- [ ] Empty state screens
- [ ] Offline detection indicator

**Checkpoint:** Complete feature set working

### Week 8: Testing & Submission
- [ ] Bug fixes from testing
- [ ] Unit and integration tests
- [ ] UI refinements
- [ ] Performance optimization
- [ ] Dark mode verification
- [ ] Accessibility check (Dynamic Type)
- [ ] App Store assets (icons, screenshots)
- [ ] Privacy policy
- [ ] Code signing setup
- [ ] Final build and submission

---

## 🔧 DEPENDENCIES (Recommended)

```swift
// Swift Package Manager dependencies

// HTTP Client (alternative to URLSession wrapper)
// .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.0.0")

// Image caching
// .package(url: "https://github.com/SDWebImage/SDWebImage.git", from: "5.0.0")

// QR Code (if not using native Vision framework)
// .package(url: "https://github.com/SwiftLee/QRCodeReader.swift.git", from: "10.0.0")

// Local storage/caching
// .package(url: "https://github.com/soffes/SAMKeychain.git", from: "1.5.2")

// Networking utilities
// .package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.0.0")

// Optional: SwiftUI helpers
// .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", from: "1.0.0")
```

For MVP, recommend using only native SwiftUI and Foundation (no external dependencies).

---

## 💬 API SUPPORT & QUESTIONS

### Backend Status
✅ All API endpoints are fully implemented and tested  
✅ S3 photo storage configured  
✅ Database schema ready (SQLite with foreign keys)  
✅ Admin web console ready (user management, messaging)

### If you encounter API issues:
1. Check `/api/docs` endpoint for live API documentation
2. Verify API key is stored correctly in Keychain
3. Ensure `X-API-Key` header is included in requests
4. Check timezone offset calculation for availability
5. Verify HTTPS certificate (production)

### Common Issues & Solutions

**Issue:** 401 Unauthorized on all requests
- **Solution:** Check if API key is correctly retrieved from Keychain. Log the key (masked) to verify format.

**Issue:** Availability returns empty slots
- **Solution:** Verify `tzOffsetMinutes` is correctly calculated. Check date format (YYYY-MM-DD). Ensure service exists.

**Issue:** S3 upload fails
- **Solution:** Verify image is JPEG. Check file size < 2MB. Ensure presigned URL hasn't expired (60 sec).

**Issue:** Messages not appearing
- **Solution:** Call GET /api/ios/messages periodically. Check `read` flag in response.

---

## 📝 CODE STYLE GUIDE

### Swift Conventions
- Use async/await (preferred) or Combine for async operations
- Property names: camelCase
- Function names: camelCase
- Enum cases: lowerCamelCase
- Type names: UpperCamelCase
- Constants: UPPER_SNAKE_CASE (for file-level constants)

### Comments
```swift
/// Detailed description of function/class
/// - Parameters:
///   - param1: Description of param1
/// - Returns: Description of return value
func doSomething(param1: String) -> Bool {
    // Implementation comment if needed
}
```

### Error Handling
Always handle errors explicitly:
```swift
// Good
do {
    try await apiClient.fetchServices()
} catch {
    showError(error.localizedDescription)
}

// Avoid
try? await apiClient.fetchServices() // Silent failures
```

---

## ✅ SUCCESS CRITERIA

The iOS app is considered complete when:

✅ **Onboarding**
- User can scan QR code with server URL
- Or manually enter server URL
- POST /api/ios/init returns API key
- API key stored securely in Keychain
- Profile setup screen collects all required data
- POST /api/ios/profile creates user successfully
- User reaches main app with tab bar navigation

✅ **Services**
- GET /api/client/services returns list
- Services display with images, price, duration
- Service caching implemented (1 hour TTL)
- Tap service to view details

✅ **Booking**
- Date picker allows selecting future dates
- GET /api/client/availability returns slots with timezone handling
- Slots display local time (not UTC)
- Capacity indicator shows availability
- POST /api/client/appointments creates booking
- Confirmation screen with appointment details
- Appointment appears in Bookings tab

✅ **Photos**
- Photo selection from camera/library/preset
- Image compression to JPEG max 2MB
- POST /api/uploads/presign returns S3 URL
- PUT to S3 with upload progress tracking
- POST /api/client/appointments/{id}/photos links photos
- Photos display in appointment detail

✅ **Messages**
- GET /api/ios/messages loads admin messages
- Unread count badge on Messages tab
- POST /api/ios/messages/:id/read marks as read
- Auto-refresh messages every 30-60 seconds

✅ **Profile**
- GET /api/ios/profile shows current user data
- Edit profile updates all fields
- POST /api/ios/profile (update) persists changes
- Logout deletes API key from Keychain
- Settings allow changing server URL

✅ **Quality**
- No API keys in logs or error messages
- Network errors handled gracefully
- Offline detection indicator
- Loading spinners on all async operations
- Dark mode fully supported
- Accessible to users with accessibility needs
- Responsive layout on all iPhone sizes

✅ **Testing**
- Unit tests for APIClient, Keychain, compression
- Integration tests for complete flows
- UI tests for onboarding and booking
- Manual testing on multiple devices
- All error scenarios tested

✅ **Submission Ready**
- Code signing configured
- App icons and launch screen prepared
- Privacy policy written and linked
- App Store metadata complete
- Screenshots and preview video ready
- Version number incremented
- Ready for App Store review

---

## 🎯 FINAL NOTES

### For Developer
- **Ask Questions:** If anything is unclear, ask before implementing. Better to clarify now than refactor later.
- **Test with Backend:** Integrate with actual API early (Week 1-2) rather than mocking all data.
- **Use Combine/async-await:** This is iOS 13.0+ compatible and modern Swift approach.
- **No External Dependencies (MVP):** Try to build with native SwiftUI/Foundation first.
- **Performance:** Test on iPhone 12 mini (slow device) to ensure smooth scrolling/animations.

### Provided Resources
- ✅ All API endpoints fully documented above
- ✅ Data models defined
- ✅ Error handling patterns included
- ✅ Keychain example code
- ✅ Image compression example
- ✅ Timeline and checklist provided
- ✅ Backend team available for API questions

### Next Steps
1. Copy this prompt to Cursor or your AI IDE
2. Start with Week 1-2 checklist (onboarding)
3. Create Xcode project with MVVM structure
4. Implement APIClient and KeychainService first
5. Build UI in parallel
6. Integrate with real backend early
7. Use checklists to track progress

---

**Document Version:** 1.1  
**Last Updated:** January 2024  
**Backend Status:** Production Ready ✅  
**Frontend Status:** Ready for Development 🚀

Good luck with the iOS app development! Ask questions and iterate frequently. 🎉
