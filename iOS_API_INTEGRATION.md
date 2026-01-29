# AutoDetail Hub - iOS App API Integration Guide

This guide explains how to integrate your iOS app with the web backend API for creating appointments and managing bookings.

## Base URL

```
Production: https://your-domain.com
Development: http://localhost:8080
```

## Authentication

### API Key Validation

Before making any requests, validate your API key:

```
POST /api/auth/validate-key
Content-Type: application/json

{
  "apiKey": "org_1234567890_abc"
}
```

**Response:**

```json
{
  "valid": true,
  "message": "API key is valid",
  "timestamp": "2024-01-19T10:30:00Z"
}
```

## Client-Facing Endpoints

### 1. Get Available Services

Fetch the list of all available services that customers can book.

```
GET /api/client/services
```

**Response:**

```json
[
  {
    "id": "service-123",
    "name": "Car Washing",
    "description": "Full car wash with premium products",
    "priceRub": 1500,
    "durationMinutes": 60,
    "imageUrl": "https://...",
    "createdAt": "2024-01-19T10:00:00Z"
  },
  {
    "id": "service-456",
    "name": "Detail Wash",
    "description": "Deep cleaning and detailing",
    "priceRub": 3000,
    "durationMinutes": 120,
    "imageUrl": "https://...",
    "createdAt": "2024-01-19T10:00:00Z"
  }
]
```

### 2. Get Single Service Details

```
GET /api/client/services/{serviceId}
```

**Response:**

```json
{
  "id": "service-123",
  "name": "Car Washing",
  "description": "Full car wash with premium products",
  "priceRub": 1500,
  "durationMinutes": 60,
  "imageUrl": "https://...",
  "createdAt": "2024-01-19T10:00:00Z"
}
```

### 3. Create Appointment (Booking)

Customer submits a booking request.

```
POST /api/client/appointments
Content-Type: application/json

{
  "startIso": "2024-02-15T14:00:00Z",
  "clientName": "John Doe",
  "phone": "+1234567890",
  "telegram": "johndoe",
  "carMake": "BMW",
  "carPlate": "ABC123",
  "serviceName": "Car Washing",
  "notes": "Extra care needed"
}
```

**Required Fields:**

- `startIso` - Appointment start time in ISO format
- `clientName` - Customer name
- `serviceName` - Name of the service to book

**Optional Fields:**

- `phone` - Customer phone number
- `telegram` - Telegram username (without @)
- `carMake` - Car make/brand
- `carPlate` - Car license plate number
- `notes` - Additional notes or special requests

**Response:**

```json
{
  "id": "appt-789",
  "source": "ios",
  "status": "new",
  "startIso": "2024-02-15T14:00:00Z",
  "clientName": "John Doe",
  "phone": "+1234567890",
  "telegram": "johndoe",
  "carMake": "BMW",
  "carPlate": "ABC123",
  "serviceName": "Car Washing",
  "notes": "Extra care needed",
  "createdAt": "2024-01-19T10:30:00Z"
}
```

### 4. Get Appointment Details

```
GET /api/client/appointments/{appointmentId}
```

**Response:**

```json
{
  "id": "appt-789",
  "source": "ios",
  "status": "new",
  "startIso": "2024-02-15T14:00:00Z",
  "endIso": null,
  "clientName": "John Doe",
  "phone": "+1234567890",
  "telegram": "johndoe",
  "carMake": "BMW",
  "carPlate": "ABC123",
  "serviceName": "Car Washing",
  "notes": "Extra care needed",
  "workPhotos": [],
  "defectPhotos": [],
  "createdAt": "2024-01-19T10:30:00Z",
  "updatedAt": "2024-01-19T10:30:00Z"
}
```

### 5. Search Appointments

Find appointments by phone or customer name.

```
GET /api/client/appointments?phone=+1234567890
GET /api/client/appointments?clientName=John
```

**Response:** Array of appointments matching the criteria.

### 6. Upload Photos to Appointment

Add "before" (work) or "after" (defect) photos to an appointment.

First, get a presigned S3 URL:

```
POST /api/uploads/presign
Content-Type: application/json

{
  "appointmentId": "appt-789",
  "kind": "work",
  "filename": "photo.jpg",
  "contentType": "image/jpeg"
}
```

**Response:**

```json
{
  "uploadUrl": "https://s3.example.com/...",
  "accessUrl": "https://s3.example.com/...",
  "key": "appointments/appt-789/work/photo.jpg",
  "ref": "s3:appointments/appt-789/work/photo.jpg"
}
```

Then upload to S3 using PUT request with the `uploadUrl`:

```
PUT {uploadUrl}
Content-Type: image/jpeg

[binary image data]
```

Finally, link the uploaded photo to the appointment:

```
POST /api/client/appointments/{appointmentId}/photos
Content-Type: application/json

{
  "kind": "work",
  "photoUrls": ["s3:appointments/appt-789/work/photo.jpg"]
}
```

## Error Responses

### 400 Bad Request

```json
{
  "error": "Missing required fields: startIso, clientName, serviceName"
}
```

### 401 Unauthorized

```json
{
  "valid": false,
  "error": "Invalid API key"
}
```

### 404 Not Found

```json
{
  "error": "Appointment not found"
}
```

### 500 Internal Server Error

```json
{
  "error": "Failed to create appointment"
}
```

## Implementation Example (Swift/Objective-C)

### 1. Validate API Key

```swift
let url = URL(string: "https://api.example.com/api/auth/validate-key")!
var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("application/json", forHTTPHeaderField: "Content-Type")

let body: [String: String] = ["apiKey": "org_1234567890_abc"]
request.httpBody = try JSONSerialization.data(withJSONObject: body)

let task = URLSession.shared.dataTask(with: request) { data, response, error in
  if let data = data {
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    let isValid = json?["valid"] as? Bool ?? false
    // Handle validation result
  }
}
task.resume()
```

### 2. Get Services

```swift
let url = URL(string: "https://api.example.com/api/client/services")!
URLSession.shared.dataTask(with: url) { data, response, error in
  if let data = data {
    let services = try JSONDecoder().decode([Service].self, from: data)
    // Display services in UI
  }
}.resume()
```

### 3. Create Appointment

```swift
let url = URL(string: "https://api.example.com/api/client/appointments")!
var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("application/json", forHTTPHeaderField: "Content-Type")

let appointment = [
  "startIso": "2024-02-15T14:00:00Z",
  "clientName": "John Doe",
  "phone": "+1234567890",
  "serviceName": "Car Washing"
]

request.httpBody = try JSONSerialization.data(withJSONObject: appointment)

URLSession.shared.dataTask(with: request) { data, response, error in
  if let data = data {
    let result = try JSONDecoder().decode(Appointment.self, from: data)
    // Handle successful booking
  }
}.resume()
```

## Data Models

### Service

```swift
struct Service: Codable {
  let id: String
  let name: String
  let description: String
  let priceRub: Int
  let durationMinutes: Int
  let imageUrl: String?
  let createdAt: String
}
```

### Appointment

```swift
struct Appointment: Codable {
  let id: String
  let source: String // "ios"
  let status: String // "new", "confirmed", etc.
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
}

struct Photo: Codable {
  let id: String
  let url: String
  let createdAt: String
}
```

## Rate Limiting

Currently, there are no rate limits. However, we recommend:

- Cache service list for at least 1 hour
- Implement exponential backoff for retries
- Use reasonable timeouts (15-30 seconds)

## Support

For API integration issues, please contact the development team.
