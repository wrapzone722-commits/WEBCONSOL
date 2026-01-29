# iOS App Setup Instructions

This document contains all the information needed to integrate your iOS app with the AutoDetail Hub backend.

## Quick Start

### 1. Get Your API Key

The admin can generate your API key from the web console at:

```
https://your-domain.com/settings/api-keys
```

The API key format is: `org_[timestamp]_[random]`

Example: `org_1705671234_abc123def456`

### 2. Configure Your iOS App

Add the following base URL constant to your app:

```swift
let API_BASE_URL = "https://api.autodetailhub.com"  // or your production URL
let API_KEY = "org_YOUR_KEY_HERE"
```

### 3. Validate API Key (Optional but Recommended)

Before making requests, validate the key:

```swift
func validateAPIKey() {
    let url = URL(string: "\(API_BASE_URL)/api/auth/validate-key")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let body = ["apiKey": API_KEY]
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    URLSession.shared.dataTask(with: request) { data, response, error in
        if let data = data {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let isValid = json["valid"] as? Bool {
                print("API Key Valid: \(isValid)")
            }
        }
    }.resume()
}
```

## API Endpoints Available for iOS

### Customer-Facing Endpoints

#### 1. Browse Services

```
GET /api/client/services
```

Returns list of all available services.

**Implementation:**

```swift
func fetchServices() {
    let url = URL(string: "\(API_BASE_URL)/api/client/services")!

    URLSession.shared.dataTask(with: url) { data, response, error in
        guard let data = data else { return }

        if let services = try? JSONDecoder().decode([Service].self, from: data) {
            DispatchQueue.main.async {
                // Update UI with services
                self.services = services
                self.tableView.reloadData()
            }
        }
    }.resume()
}
```

#### 2. Create Appointment (Book Service)

```
POST /api/client/appointments
```

Submit a booking request.

**Implementation:**

```swift
func bookAppointment(
    startTime: Date,
    clientName: String,
    phone: String,
    carMake: String,
    carPlate: String,
    serviceName: String
) {
    let url = URL(string: "\(API_BASE_URL)/api/client/appointments")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let isoFormatter = ISO8601DateFormatter()
    let appointmentData: [String: Any] = [
        "startIso": isoFormatter.string(from: startTime),
        "clientName": clientName,
        "phone": phone,
        "carMake": carMake,
        "carPlate": carPlate,
        "serviceName": serviceName,
        "notes": ""
    ]

    request.httpBody = try? JSONSerialization.data(withJSONObject: appointmentData)

    URLSession.shared.dataTask(with: request) { data, response, error in
        guard let data = data else { return }

        if let appointment = try? JSONDecoder().decode(Appointment.self, from: data) {
            DispatchQueue.main.async {
                print("Appointment booked: \(appointment.id)")
                // Handle successful booking
            }
        }
    }.resume()
}
```

#### 3. Upload Photos

First, get presigned URL:

```swift
func getPresignedURL(appointmentId: String, kind: String) {
    let url = URL(string: "\(API_BASE_URL)/api/uploads/presign")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let data: [String: Any] = [
        "appointmentId": appointmentId,
        "kind": kind, // "work" or "defect"
        "filename": "photo_\(Date().timeIntervalSince1970).jpg",
        "contentType": "image/jpeg"
    ]

    request.httpBody = try? JSONSerialization.data(withJSONObject: data)

    URLSession.shared.dataTask(with: request) { data, response, error in
        guard let data = data else { return }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let uploadUrl = json["uploadUrl"] as? String,
           let photoRef = json["ref"] as? String {

            // Now upload to S3
            self.uploadPhotoToS3(uploadUrl: uploadUrl, photoRef: photoRef, appointmentId: appointmentId, kind: kind)
        }
    }.resume()
}

func uploadPhotoToS3(
    uploadUrl: String,
    photoRef: String,
    appointmentId: String,
    kind: String
) {
    let url = URL(string: uploadUrl)!
    var request = URLRequest(url: url)
    request.httpMethod = "PUT"
    request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")

    // Load your image data
    if let imageData = /* your image data */ {
        request.httpBody = imageData

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                // Photo uploaded successfully, now link it to appointment
                self.linkPhotoToAppointment(
                    appointmentId: appointmentId,
                    kind: kind,
                    photoRef: photoRef
                )
            }
        }.resume()
    }
}

func linkPhotoToAppointment(
    appointmentId: String,
    kind: String,
    photoRef: String
) {
    let url = URL(string: "\(API_BASE_URL)/api/client/appointments/\(appointmentId)/photos")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let data: [String: Any] = [
        "kind": kind,
        "photoUrls": [photoRef]
    ]

    request.httpBody = try? JSONSerialization.data(withJSONObject: data)

    URLSession.shared.dataTask(with: request) { data, response, error in
        print("Photo linked to appointment")
    }.resume()
}
```

#### 4. Get Appointment Status

```swift
func getAppointment(appointmentId: String) {
    let url = URL(string: "\(API_BASE_URL)/api/client/appointments/\(appointmentId)")!

    URLSession.shared.dataTask(with: url) { data, response, error in
        guard let data = data else { return }

        if let appointment = try? JSONDecoder().decode(Appointment.self, from: data) {
            DispatchQueue.main.async {
                // Update UI with appointment status
                print("Status: \(appointment.status)")
            }
        }
    }.resume()
}
```

## Data Models

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

struct Appointment: Codable {
    let id: String
    let source: String // "ios"
    let status: String // "new", "confirmed", "done", etc.
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

## Error Handling

All API responses follow a standard format:

**Success (2xx):**

```json
{
  "id": "...",
  "name": "...",
  ...
}
```

**Error (4xx, 5xx):**

```json
{
  "error": "Descriptive error message"
}
```

Always check `error` field in response to handle failures gracefully.

## Best Practices

1. **Cache Services**: Services rarely change, cache them for at least 1 hour
2. **Retry Logic**: Implement exponential backoff for network requests
3. **Timeouts**: Use 15-30 second timeouts for API calls
4. **User Feedback**: Show loading indicators during API calls
5. **Error Messages**: Display user-friendly error messages for API failures
6. **API Key Security**: Never hardcode API key in production. Use secure storage (Keychain)

## Testing

### Test Base URL (Development)

```
http://localhost:8080
```

### Test API Key

Ask the admin for a test API key.

### Test Endpoints

```bash
# Get services
curl http://localhost:8080/api/client/services

# Create appointment
curl -X POST http://localhost:8080/api/client/appointments \
  -H "Content-Type: application/json" \
  -d '{
    "startIso": "2024-02-15T14:00:00Z",
    "clientName": "Test User",
    "phone": "+1234567890",
    "carMake": "BMW",
    "carPlate": "ABC123",
    "serviceName": "Car Washing"
  }'
```

## Support

For issues or questions:

1. Check the error message from the API response
2. Verify your API key is correct
3. Ensure the backend is running and accessible
4. Contact the backend developer

---

**Backend Documentation**: See `iOS_API_INTEGRATION.md` for complete API specification.
