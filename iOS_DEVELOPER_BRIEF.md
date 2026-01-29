# iOS App Development Brief - AutoDetail Hub

**Date:** January 2024  
**Target Platform:** iOS 13.0+  
**Architecture:** MVVM with Combine/async-await  
**Estimated Timeline:** 6-8 weeks

---

## Project Summary

We need you to develop an iOS app that connects to our AutoDetail Hub backend. The app allows customers to:

1. **Connect to the backend** via QR code or manual URL entry
2. **Create their profile** (name, car details, photo selection)
3. **Browse available services** and pricing
4. **Check appointment availability** with real-time capacity
5. **Book appointments** with selected services
6. **Upload photos** before and after work
7. **Receive admin messages** and notifications

### Key Architectural Decision

**Every iOS user gets a unique API key:**

- On first app launch, the backend automatically generates a unique API key
- This key is used for all subsequent requests
- The key is stored securely in iOS Keychain
- It serves as the user's unique identifier

---

## Backend API Ready

All API endpoints are **already built and ready to use**:

### User Management Endpoints

```
POST   /api/ios/init                    - Initialize and get API key
GET    /api/ios/profile                 - Get user profile
POST   /api/ios/profile                 - Update user profile
GET    /api/ios/messages                - Get unread messages
POST   /api/ios/messages/:id/read       - Mark message as read
```

### Booking Endpoints

```
GET    /api/client/services             - List all services
GET    /api/client/availability         - Check slot availability
POST   /api/client/appointments         - Create booking
GET    /api/client/appointments         - List user's bookings
GET    /api/client/appointments/:id     - Get booking details
POST   /api/client/appointments/:id/photos - Upload photos
```

### Photo Upload (S3)

```
POST   /api/uploads/presign             - Get S3 upload URL
PUT    [S3_URL]                         - Upload image to S3
```

### Admin Features (Web Console Ready)

- List all connected iOS users
- View user profiles with car details
- Send messages to users
- Set user priority (normal/high/blocked)
- Delete users

---

## User Flow Diagram

```
┌─────────────────────┐
│  App First Launch   │
└──────────┬──────────┘
           │
           ▼
   ┌───────────────────┐
   │ QR Code Scanner   │ ← Admin provides QR with URL
   │ OR Manual Entry   │
   └─────────┬─────────┘
             │
             ▼
   ┌────────────────────┐
   │ POST /api/ios/init │ ← Returns unique API key
   └─────────┬──────────┘
             │
             ▼
   ┌────────────────────────────┐
   │ Profile Setup Screen       │
   │ - Name                     │
   │ - Car Make                 │
   │ - Car Plate                │
   │ - Photo (camera/library/   │
   │   preset images)           │
   └─────────┬──────────────────┘
             │
             ▼
   ┌────────────────────────┐
   │ POST /api/ios/profile  │ ← Save profile
   └─────────┬──────────────┘
             │
             ▼
   ┌────────────────────┐
   │ Main App Ready     │
   │ - Services List    │
   │ - Bookings         │
   │ - Appointments     │
   │ - Messages         │
   │ - Profile          │
   └────────────────────┘
```

---

## Critical Implementation Details

### 1. API Key Storage (Keychain)

```swift
// Store API key securely in Keychain, NOT UserDefaults
// Use Security framework
// Key format: ios_[timestamp]_[random_hex]
```

### 2. Base URL Storage

```swift
// Store server base URL in UserDefaults
// Allow users to change server later (settings)
// Validate HTTPS connection
```

### 3. Photo Selection Flow

**Option 1: Preset Images** (Recommended for MVP)

- Provide 8-12 generic car photos in the app
- Users select one without uploading
- Fast and simple

**Option 2: Custom Photos**

- Camera + Photo library access
- Compress to JPEG (max 2MB)
- Upload via S3 presigned URL
- Include in profile

### 4. Appointment Booking

```
1. Get services list
2. Let user select service + date
3. Fetch availability for that date
4. Show time slots (with capacity indicator)
5. User selects time slot
6. POST to create appointment
7. Show confirmation
```

### 5. Photo Upload to Appointments

```
1. User selects photo (camera or library)
2. Compress image
3. POST /api/uploads/presign → get S3 URL
4. PUT image to S3
5. POST /api/client/appointments/:id/photos → link photo
```

---

## Data Models (Swift Structs)

See `iOS_APP_SPECIFICATION.md` - Data Models section for all structures including:

- UserProfile
- Service
- AvailabilitySlot
- Appointment
- Photo
- AdminMessage

---

## Admin Web Console Features (Already Built)

Users tab shows:

- ✅ All connected iOS users
- ✅ User profiles (name, car make, car plate, photo)
- ✅ API key for each user
- ✅ User status and activity
- ✅ Action buttons:
  - Send messages
  - Set priority (normal/high/blocked)
  - Delete user
- ✅ Search functionality
- ✅ Statistics (total users, active, high priority, blocked)

---

## Testing Checklist

- [ ] QR code scanning and URL entry work
- [ ] API key generation on first connection
- [ ] Profile creation and storage
- [ ] Service list loading
- [ ] Availability checking with timezone handling
- [ ] Booking creation
- [ ] Photo selection (preset or custom)
- [ ] Photo upload to S3
- [ ] Message retrieval and marking read
- [ ] Network error handling and retry
- [ ] Offline detection
- [ ] Local caching of services
- [ ] App resume after backgrounding

---

## Deliverables Expected

1. **iOS App (App Store Ready)**
   - Minimum iOS 13.0 support
   - HTTPS only
   - Secure Keychain for API key
   - Proper error handling
   - Loading states and spinners
   - Offline indicator

2. **Code Quality**
   - MVVM architecture
   - Unit tests (critical flows)
   - UI tests (onboarding + booking)
   - Clean, documented code
   - Proper error messages for users

3. **Documentation**
   - Code comments for complex logic
   - README with setup instructions
   - Known issues and limitations
   - Future enhancement ideas

4. **App Store Submission**
   - Icons and screenshots
   - Privacy policy
   - App description
   - Keywords

---

## Communication

**API Issues / Questions?**

- Check `/api/docs` endpoint for API documentation
- All endpoints are already working and tested
- Backend team available for API clarification

**Design Questions?**

- Recommended iOS design system (SF Symbols, native components)
- Follow Apple Human Interface Guidelines
- Dark mode support recommended

**Timeline Checkpoint**

- Week 2: Setup + onboarding done
- Week 4: Services + booking flow done
- Week 6: Photo upload + messages done
- Week 8: Polish + testing + submission

---

## File Reference

**Detailed Specification:** `iOS_APP_SPECIFICATION.md`
(Contains full API endpoint details, all data models, error handling, security considerations, and more)

---

## Success Criteria

✅ App launches and connects to server via QR code  
✅ User can create profile with name, car, and photo  
✅ Services list loads and displays with images  
✅ User can check availability and book appointments  
✅ User can upload photos to appointments  
✅ Admin can manage users from web console  
✅ Messages appear in app and can be marked read  
✅ All API calls use secure API key from Keychain  
✅ Network errors handled gracefully  
✅ App passes App Store review

---

## Next Steps

1. Review `iOS_APP_SPECIFICATION.md` for complete technical details
2. Clarify any questions about API or flow
3. Set up Xcode project with MVVM structure
4. Begin with onboarding/setup screens
5. Progress through booking flow
6. Integrate with actual backend
7. Test with web console admin features

**Let's build something great!** 🚀

---

_Document prepared for: [Developer Name]_  
_Project: AutoDetail Hub iOS App_  
_Backend Status: Ready for integration_ ✅
