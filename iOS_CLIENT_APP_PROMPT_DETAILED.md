# 📱 iOS Клиентское Приложение для AutoDetail Hub
## Полный Промт для Cursor AI - Детальное Техническое Задание

---

## 🎯 АНАЛИЗ ПРОЕКТА И КОНТЕКСТ

### Что это за проект?
**AutoDetail Hub** — полнофункциональный SaaS для управления автомойками и детейлинг-сервисов.

**Структура:**
- **Backend:** Node.js/Express с SQLite базой + S3 для хранения фотографий
- **Admin Web:** React SPA для управления бизнесом (услуги, расписание, персонал, просмотр заказов)
- **iOS App (это ваша задача):** Native Swift приложение для **конечных клиентов** (водителей)

### Что уже готово на бэкенде?
✅ Все API endpoints реализованы и готовы  
✅ SQL схема с таблицами: `appointments`, `services`, `staff_members`, `staff_shifts`, `vehicles`, `work_settings`  
✅ S3 хранилище для фотографий (work photos и defect photos)  
✅ Система API ключей для iOS приложений  
✅ Admin панель на React для управления пользователями  

### Ваша задача
Разработать **нативное iOS приложение**, которое позволит клиентам:
1. **Подключиться** к мастерской по QR-коду или адресу
2. **Создать профиль** с информацией об авто
3. **Просмотреть услуги** с ценами и описанием
4. **Забронировать запись** на удобное время
5. **Загрузить фотографии** авто до/после работы
6. **Получать сообщения** от мастерской

---

## 🔧 ТЕКУЩАЯ АРХИТЕКТУРА BACKEND (АНАЛИЗ)

### API Endpoints для iOS клиента

#### 1. Initialization & Authentication
```
POST /api/ios/init
- Нет аутентификации на входе
- Возвращает: { apiKey: "ios_...", baseUrl: "https://..." }
- Используется: При первом запуске приложения

GET /api/ios/profile
- Header: X-API-Key
- Возвращает: UserProfile { id, name, carMake, carPlate, profilePhotoUrl, ... }
- Используется: Загрузка данных пользователя

POST /api/ios/profile
- Header: X-API-Key
- Отправляет: { name, carMake, carPlate, profilePhotoUrl }
- Возвращает: Updated UserProfile
- Используется: Сохранение/обновление профиля
```

#### 2. Services (Услуги)
```
GET /api/client/services
- Header: X-API-Key
- Возвращает: Array<Service>
  Service: {
    id, name, description, priceRub, durationMinutes,
    imageUrl, active, createdAt
  }
- Используется: Список доступных услуг

GET /api/client/services/:id
- Header: X-API-Key
- Возвращает: Single Service detail
```

#### 3. Availability & Booking
```
GET /api/client/availability?date=YYYY-MM-DD&tzOffsetMinutes=VALUE
- Header: X-API-Key
- Query: date (required), serviceId (optional), tzOffsetMinutes (required)
- Возвращает: Array<AvailabilitySlot>
  AvailabilitySlot: {
    startIso, endIso, startTime, endTime,
    remainingCapacity, totalCapacity, bookedCount, isAvailable
  }
- ВАЖНО: tzOffsetMinutes = Math.round(TimeZone.current.secondsFromGMT() / 60)
         Для UTC+3: -180, для UTC+0: 0, для UTC-5: 300

POST /api/client/appointments
- Header: X-API-Key
- Body: {
    startIso, clientName, phone, telegram,
    carMake, carPlate, serviceName, notes
  }
- Возвращает: Appointment { id, status, createdAt, ... }
- Используется: Создание записи на услугу

GET /api/client/appointments
- Header: X-API-Key
- Возвращает: Array<Appointment> всех бронирований пользователя

GET /api/client/appointments/:id
- Header: X-API-Key
- Возвращает: Full appointment details с workPhotos и defectPhotos
```

#### 4. Photo Upload (S3)
```
POST /api/uploads/presign
- Header: X-API-Key
- Body: {
    appointmentId, kind: "work"|"defect",
    filename, contentType: "image/jpeg"
  }
- Возвращает: { uploadUrl, accessUrl, key, ref }
- Используется: Получение S3 presigned URL

PUT {uploadUrl}
- Нет аутентификации (URL уже подписан)
- Body: Binary JPEG image data
- Используется: Загрузка фото на S3

POST /api/client/appointments/:id/photos
- Header: X-API-Key
- Body: { kind: "work"|"defect", photoUrls: [...] }
- Используется: Привязка фото к записи
```

#### 5. Messages
```
GET /api/ios/messages
- Header: X-API-Key
- Возвращает: { messages: Array<Message> }
  Message: { id, text, sentAt, read }

POST /api/ios/messages/:messageId/read
- Header: X-API-Key
- Используется: Отметить сообщение как прочитанное
```

#### 6. Other Client Endpoints
```
GET /api/client/vehicles
- Header: X-API-Key
- Возвращает: Array<Vehicle> (можно использовать для истории авто)

GET /api/client/vehicles/:id
- Детали транспортного средства
```

### Database Schema (для понимания)
```sql
appointments (
  id TEXT PRIMARY KEY,
  source TEXT CHECK (source IN ('ios', 'admin')),
  status TEXT CHECK (status IN ('new', 'confirmed', 'in_progress', 'done', 'cancelled')),
  start_iso TEXT,
  end_iso TEXT,
  client_id TEXT,  -- это X-API-Key пользователя
  client_name TEXT,
  phone TEXT,
  telegram TEXT,
  car_make TEXT,
  car_plate TEXT,
  service_name TEXT,
  notes TEXT,
  work_photos TEXT (JSON массив),
  defect_photos TEXT (JSON массив),
  created_at TEXT,
  updated_at TEXT
)

services (
  id TEXT PRIMARY KEY,
  name TEXT,
  description TEXT,
  price_rub INTEGER,
  duration_minutes INTEGER,
  image_url TEXT,
  active BOOLEAN,
  created_at TEXT,
  updated_at TEXT
)

staff_shifts (
  id TEXT PRIMARY KEY,
  staff_id TEXT,
  date_iso TEXT,
  planned_start TEXT,
  planned_end TEXT,
  actual_start_iso TEXT,
  actual_end_iso TEXT,
  status TEXT,
  notes TEXT,
  created_at TEXT,
  updated_at TEXT
)

work_settings (
  id TEXT PRIMARY KEY,
  settings_json TEXT, -- { slotStepMinutes, posts, bookingWindow, ... }
  updated_at TEXT
)
```

---

## 📐 АРХИТЕКТУРА iOS ПРИЛОЖЕНИЯ

### MVVM + Combine + SwiftUI

```
Project/
├── App/
│   ├── AutoDetailHubApp.swift (entry point)
│   └── AppCoordinator.swift (navigation routing)
│
├── Networking/
│   ├── APIClient.swift (базовый HTTP клиент)
│   ├── APIEnvironment.swift (dev/prod URLs)
│   ├── APIError.swift (error handling)
│   └── APIRequest.swift (request builder)
│
├── Services/
│   ├── KeychainService.swift (secure API key storage)
│   ├── AuthService.swift (инициализация и аутентификация)
│   ├── AppointmentService.swift (fetch appointments, create booking)
│   ├── ServiceService.swift (fetch services list)
│   ├── AvailabilityService.swift (check slots)
│   ├── PhotoUploadService.swift (S3 integration)
│   ├── ProfileService.swift (get/update user profile)
│   ├── MessageService.swift (fetch and mark messages)
│   └── LocationService.swift (timezone detection)
│
├── ViewModels/
│   ├── RootViewModel.swift (app state: initialized/not)
│   ├── OnboardingViewModel.swift (setup flow)
│   ├── HomeViewModel.swift (dashboard)
│   ├── ServicesViewModel.swift (services list)
│   ├── BookingViewModel.swift (booking flow)
│   ├── AppointmentDetailViewModel.swift (single appointment)
│   ├── ProfileViewModel.swift (user profile)
│   ├── MessagesViewModel.swift (inbox)
│   └── PhotoUploadViewModel.swift (photo upload)
│
├── Views/
│   ├── Root/
│   │   ├── RootView.swift (choose: onboarding or main app)
│   │   └── LoadingView.swift
│   │
│   ├── Onboarding/
│   │   ├── OnboardingContainerView.swift
│   │   ├── WelcomeScreen.swift
│   │   ├── QRCodeScannerView.swift
│   │   ├── ManualURLEntryView.swift
│   │   └── ProfileSetupView.swift (name, car, photo)
│   │
│   ├── MainApp/
│   │   ├── MainTabView.swift (tab bar controller)
│   │   ├── Tabs/
│   │   │   ├── HomeTab.swift (dashboard)
│   │   │   ├── ServicesTab.swift (услуги)
│   │   │   ├── BookingsTab.swift (мои записи)
│   │   │   ├── MessagesTab.swift (сообщения)
│   │   │   └── ProfileTab.swift (профиль)
│   │   │
│   │   ├── Services/
│   │   │   ├── ServiceListView.swift
│   │   │   ├── ServiceDetailView.swift
│   │   │   └── ServiceCard.swift (reusable)
│   │   │
│   │   ├── Booking/
│   │   │   ├── BookingFlowView.swift (container)
│   │   │   ├── DateSelectionView.swift
│   │   │   ├── TimeSlotSelectionView.swift
│   │   │   ├── BookingSummaryView.swift
│   │   │   └── BookingConfirmationView.swift
│   │   │
│   │   ├── Appointments/
│   │   │   ├── AppointmentListView.swift (upcoming + past)
│   │   │   ├── AppointmentDetailView.swift
│   │   │   └── PhotoGalleryView.swift (work + defect photos)
│   │   │
│   │   ├── Messages/
│   │   │   ├── MessageListView.swift
│   │   │   └── MessageDetailView.swift
│   │   │
│   │   ├── Profile/
│   │   │   ├── ProfileView.swift
│   │   │   ├── EditProfileView.swift
│   │   │   ├── SettingsView.swift
│   │   │   └── LogoutConfirmationView.swift
│   │   │
│   │   └── Components/
│   │       ├── LoadingOverlay.swift
│   │       ├── ErrorBanner.swift
│   │       ├── AppointmentCard.swift
│   │       ├── ServiceCard.swift
│   │       ├── MessageCell.swift
│   │       ├── PhotoUploadButton.swift
│   │       └── TimeSlotCard.swift
│   │
│   └── Shared/
│       ├── NavigationBackButton.swift
│       ├── EmptyStateView.swift
│       ├── ErrorAlertView.swift
│       └── SuccessAlertView.swift
│
├── Models/
│   ├── User.swift (UserProfile)
│   ├── Service.swift
│   ├── Appointment.swift
│   ├── AvailabilitySlot.swift
│   ├── Photo.swift
│   ├── Message.swift
│   ├── Vehicle.swift
│   └── APIResponse.swift (generic wrappers)
│
├── Utilities/
│   ├── Constants.swift (API URLs, etc.)
│   ├── Formatters/
│   │   ├── DateFormatter+Extensions.swift
│   │   ├── NumberFormatter+Extensions.swift
│   │   └── CurrencyFormatter.swift
│   ├── Extensions/
│   │   ├── String+Extensions.swift
│   │   ├── Date+Extensions.swift
│   │   ├── Image+Extensions.swift
│   │   └── Color+Extensions.swift
│   ├── Helpers/
│   │   ├── ImageCompression.swift
│   │   ├── TimezoneHelper.swift
│   │   └── NetworkMonitor.swift
│   └── Environment/
│       └── EnvironmentVariables.swift (debug settings)
│
├── Resources/
│   ├── Assets.xcassets
│   │   ├── Colors/
│   │   ├── Images/
│   │   ├── App Icon/
│   │   └── Launch Screen/
│   ├── Localizable.strings (RUS/ENG)
│   ├── Fonts/ (если используются кастомные)
│   └── PresetImages/ (8-12 фото авто для выбора)
│
└── Supporting Files/
    ├── Info.plist
    └── Config.xcconfig
```

---

## 🔐 SECURITY & STORAGE

### API Key Management (CRITICAL)
```swift
// ❌ НИКОГДА не делайте так:
UserDefaults.standard.setValue(apiKey, forKey: "apiKey") // UNSAFE!

// ✅ ВСЕГДА делайте так:
try KeychainService.shared.store(apiKey: apiKey, forKey: "ios_api_key")
```

**Почему Keychain?**
- Защищен iOS Security Framework
- Не доступен в backup iTunes
- Защищен от reverse engineering
- Удаляется при удалении приложения

### What to Store
- ✅ **API Key** → Keychain (SECURE)
- ✅ **Base URL** → UserDefaults (PUBLIC)
- ✅ **User ID** → Keychain (SECURE)
- ✅ **Device Token** (push) → Keychain
- ❌ **Password** → Never store (don't use password auth)
- ❌ **Personal data** → Use only during session

### Error Handling for API Key
```swift
// На 401 Unauthorized:
1. Очистить Keychain
2. Очистить UserDefaults
3. Показать alert "Сеанс истёк"
4. Вернуться на WelcomeScreen (переинициализация)
```

---

## 📊 ОСНОВНЫЕ ЭКРАНЫ И FLOWS

### Screen 1: Welcome Screen
**Когда показывается:** App start, если нет API key в Keychain

**Elements:**
- App logo
- "Подключиться к мастерской" (heading)
- "Отсканируйте QR код" button
- "Или введите адрес вручную" button
- Bottom text: "Требуется интернет соединение"

**Actions:**
- Tap "QR Code" → открыть QRCodeScannerView
- Tap "Manual" → открыть URLEntryView
- Scan QR → extract base_url → POST /api/ios/init

---

### Screen 2: QR Code Scanner
**Что отсканировать:**
```json
{
  "apiVersion": 1,
  "name": "AutoDetail Hub",
  "orgName": "My Car Wash",
  "baseUrl": "https://autodetail.example.com",
  "apiKey": "ios_1705767890_abc123def456"
}
```

**Elements:**
- Camera preview
- Scan rectangle overlay
- "Не видно QR кода?" → open "Enter Manually"
- "Отмена" button

**Processing:**
1. Scan QR → parse JSON
2. Validate baseUrl (HTTPS)
3. Validate apiKey format (starts with "ios_")
4. Store in Keychain
5. Store baseUrl in UserDefaults
6. POST /api/ios/init (if needed)
7. Proceed to ProfileSetupView

---

### Screen 3: Manual URL Entry
**Elements:**
- Text field: "https://..."
- Example: "autodetail.example.com"
- "Подключиться" button
- "Назад" button

**Validation:**
- URL должен быть валидный
- Добавить https:// если пользователь забыл
- Проверить HTTPS (не HTTP)

**Actions:**
1. User enters URL
2. POST /api/ios/init to that URL
3. Get back: { apiKey, baseUrl }
4. Store in Keychain + UserDefaults
5. Show ProfileSetupView

---

### Screen 4: Profile Setup
**When shown:** After successful init, before entering main app

**Elements:**
- Profile photo (tap to select)
- Options: Camera | Photo Library | Preset Images
- Text field: Full Name (required)
- Text field: Car Make (required, with autocomplete: BMW, Toyota, Mercedes, etc.)
- Text field: Car Plate (required)
- "Продолжить" button (enabled only if all fields valid)

**Car Make Autocomplete Suggestions:**
- BMW, Mercedes, Audi, Volkswagen
- Toyota, Honda, Hyundai, Kia
- Lada, Chevrolet, Ford, Volkswagen
- + allow free text input

**Photo Selection:**
1. **Preset Images**: Show 8-12 default car photos, user selects one
   - ✅ Fast, no upload needed
   - ✅ Recommended for MVP
2. **Camera**: User takes photo
   - Compress to JPEG max 2MB
   - POST /api/uploads/presign
   - PUT to S3
3. **Photo Library**: User picks existing photo
   - Compress, upload same way

**Validation:**
- Name: 2-100 characters
- Car Make: 2-50 characters
- Car Plate: 2-20 characters
- Photo: Selected (required)

**On Submit:**
```
POST /api/ios/profile
{
  "name": "John Doe",
  "carMake": "BMW",
  "carPlate": "ABC123",
  "profilePhotoUrl": "preset:car_1" or "s3:..."
}
```

**Response:** 200 OK → Show MainTabView

---

### Screen 5: Home Tab (Dashboard)
**Default tab on app launch**

**Elements:**
```
┌─────────────────────────┐
│ Привет, John Doe! 👋    │
├─────────────────────────┤
│ ┌─────────────────────┐ │
│ │ Следующая запись   │ │
│ │ BMW ABC123         │ │
│ │ Вторник, 15:00     │ │
│ │ Полировка авто     │ │ ← Card that opens AppointmentDetailView
│ │ 2500 ₽             │ │
│ └─────────────────────┘ │
├─────────────────────────┤
│ Быстрые действия        │
│ [Забронировать] [Сообщ.] │ ← Кнопки
├─────────────────────────┤
│ Мои услуги: 3 доступно │
│ Всего записей: 5        │
│ Последний заказ: Вчера  │
└─────────────────────────┘
```

**Data Sources:**
- GET /api/ios/profile (user greeting)
- GET /api/client/appointments (next appointment, total count)
- GET /api/ios/messages (unread count badge)

**Actions:**
- Tap next appointment → AppointmentDetailView
- Tap "Забронировать" → BookingFlowView
- Tap "Messages" → MessagesTab
- Pull to refresh → reload all data
- Swipe down → refresh

---

### Screen 6: Services Tab
**Browse all available services**

**Elements:**
```
┌─────────────────────────┐
│ Наши услуги             │
├─────────────────────────┤
│ ┌─────────────────────┐ │
│ │ [Image]             │ │
│ │ Полировка авто      │ │
│ │ 2500 ₽ • 120 минут  │ │
│ │ Защита лакокраски..│ │
│ │ [Забронировать]     │ │ ← ServiceCard
│ └─────────────────────┘ │
│ ┌─────────────────────┐ │
│ │ [Image]             │ │
│ │ Чистка салона      │ │
│ │ 1500 ₽ • 60 минут   │ │
│ │ [Забронировать]     │ │
│ └─────────────────────┘ │
└─────────────────────────┘
```

**Data:**
- GET /api/client/services → [Service]
- Cache for 1 hour (save bandwidth)

**Features:**
- Infinite scroll or pagination
- Service images loaded with AsyncImage
- Price formatted: "2 500 ₽"
- Duration formatted: "120 минут" or "2 часа"
- Tap card → ServiceDetailView

---

### Screen 7: Service Detail View
**Full details of one service**

**Elements:**
- Large image at top
- Service name (heading)
- Full description (scrollable)
- Price: 2500 ₽
- Duration: 2 часа 15 минут
- Features list (if available)
- "Забронировать услугу" button

**Data:**
- GET /api/client/services/:id

**Actions:**
- Tap "Забронировать" → BookingFlowView (with service pre-selected)

---

### Screen 8: Booking Flow (Multi-step)

#### Step 1: Date Selection
**Calendar picker (next 30 days)**
```
Дата записи
[← 15 Jan] [Jun 2024] [Jan 16 →]

Su Mo Tu We Th Fr Sa
       1  2  3  4  5
 6  7  8  9 10 11 12
13 14 15 16 17 18 19  ← Today highlighted
20 21 22 23 24 25 26
27 28 29 30 31

[Выбрано: 15 Jan]
[Далее] button
```

**Rules:**
- Only future dates (today + 30 days)
- Don't show Sundays if closed (from work_settings)
- Show available slots count below each date

**On Select Date:**
- GET /api/client/availability?date=YYYY-MM-DD
- Show loading spinner

#### Step 2: Time Slot Selection
**After date selected, show available times**
```
Выбранный день: Вторник, 15 января

Доступное время:
┌─────────────────────────┐
│ 08:00 - 09:00 ✓         │ (2/2 доступно)
│ Полировка авто          │
└─────────────────────────┘ ← Tap to select
┌─────────────────────────┐
│ 09:00 - 10:00 ✗         │ (0/2 ЗАНЯТО)
│ Полировка авто          │
└─────────────────────────┘
┌─────────────────────────┐
│ 10:00 - 11:00 ✓         │ (1/2 доступно)
│ Полировка авто          │
└─────────────────────────┘

[Выбрать] button (enabled only if slot selected)
```

**Data:**
- GET /api/client/availability?date=2024-01-15&tzOffsetMinutes=-180

**Display:**
- startTime: "08:00" (локальное время, НЕ UTC!)
- Capacity: "2/2 доступно" (remainingCapacity / totalCapacity)
- Show X if fully booked (isAvailable = false)
- Disable click if not available

**On Select Slot:**
- Store selected: startIso, endIso
- Proceed to Summary

#### Step 3: Booking Summary
**Review before confirming**
```
Подтверждение записи

Услуга: Полировка авто
Дата: Вторник, 15 января
Время: 08:00 - 09:00 (2 часа)
Цена: 2500 ₽
Вашей авто: BMW ABC123

[Подтвердить] [Отмена]
```

**Actions:**
- Tap "Подтвердить":
  - POST /api/client/appointments
  - Show loading
  - On success → Show ConfirmationView
  - On error → Show error alert with retry

#### Step 4: Confirmation
**After booking successful**
```
✓ Запись создана!

Номер записи: APT-12345
Дата: Вторник, 15 января
Время: 08:00 - 09:00
Цена: 2500 ₽

Что дальше:
1. Приезжайте за 10 минут до времени
2. Назовите номер записи
3. Мы отправим напоминание за 1 час

[Мои записи] [На главную]
```

---

### Screen 9: Bookings Tab
**List of all user's appointments**

**Split into sections:**
1. **Upcoming Appointments** (startIso > now)
2. **Past Appointments** (startIso < now)

**Each appointment card shows:**
```
┌─────────────────────────┐
│ Полировка авто          │ (serviceName)
│ Вторник, 15 янв • 08:00 │ (formatted date/time)
│ BMW ABC123              │ (carMake carPlate)
│ Статус: Подтверждена    │ (status with color: green/yellow/gray/red)
│ [Детали] button         │
└─────────────────────────┘
```

**Status Colors:**
- new: Yellow (🟡)
- confirmed: Green (🟢)
- in_progress: Blue (🔵)
- done: Gray (⚪)
- cancelled: Red (🔴)

**Data:**
- GET /api/client/appointments

**Actions:**
- Tap card → AppointmentDetailView
- Pull to refresh
- Empty state if no appointments

---

### Screen 10: Appointment Detail View
**Full details of single appointment**

**Elements:**
```
Полировка авто
──────────────
Вторник, 15 января 2024

Время: 08:00 - 09:00 (2 часа)
Статус: Подтверждена ✓
Цена: 2500 ₽
Номер: APT-12345

Ваше авто:
BMW ABC123

Примечания:
"Новая краска, требует особого внимания"

──────────────────────────
Фотографии до работы:
[Загрузить фото]
(No photos yet / list of photos)

Фотографии после работы:
[Загрузить фото]
(No photos yet / list of photos)
```

**Photo Upload Section:**
- Button: "Загрузить фото"
- Shows: Camera | Photo Library | Cancel
- On select:
  1. Compress image
  2. POST /api/uploads/presign (with kind: "work" or "defect")
  3. PUT to S3 URL
  4. POST /api/client/appointments/{id}/photos
  5. Show success & reload

**Data:**
- GET /api/client/appointments/:id

**Actions:**
- Tap "Загрузить фото" → Photo picker
- Tap photo → Full screen view
- Tap back → Return to list

---

### Screen 11: Messages Tab
**Inbox from car wash**

**Elements:**
```
Сообщения (3 новых)
───────────────────
[новое] Запись подтверждена!     [×]
       "Ваша запись APT-12345..."
       Сегодня, 10:30

[новое] Напоминание
       "Запись через 1 час"
       Вторник, 15 янв, 07:50

[прочитано] Спасибо за визит!
       "Ждём вас снова"
       Пн, 14 янв, 18:00
```

**Features:**
- Unread count badge (number in red circle)
- Mark as read on tap
- Swipe to delete (optional)
- Auto-refresh every 30 seconds

**Data:**
- GET /api/ios/messages
- On message tap: POST /api/ios/messages/{id}/read

**Empty State:**
- "Сообщений нет"
- "Здесь будут сообщения от мастерской"

---

### Screen 12: Profile Tab
**User profile & settings**

**Elements:**
```
ПРОФИЛЬ

[Profile Photo] ← Tap to change
John Doe

──────────────────────────
ИНФОРМАЦИЯ ОБ АВТО

Марка: BMW
Номер: ABC123
[Изменить] button

──────────────────────────
ПРОФИЛЬ

Имя: John Doe
Номер телефона: +79991234567
Telegram: @johndoe
[Редактировать] button

──────────────────────────
НАСТРОЙКИ

Адрес мастерской: autodetail.example.com
[Выбрать другую мастерскую]

Язык: Русский
Темный режим: ☑ Включен

──────────────────────────
ИНФОРМАЦИЯ

Версия: 1.0.1
[Условия использования]
[Политика приватности]
[О приложении]

──────────────────────────
[Выйти из аккаунта]
```

**Edit Profile View (Modal):**
- Name field
- Phone field
- Telegram field
- Car Make field
- Car Plate field
- Photo selection
- Save / Cancel buttons

**Data:**
- GET /api/ios/profile (pre-fill)
- POST /api/ios/profile (on save)

**Logout Actions:**
1. Confirm with alert
2. DELETE from Keychain (API key, user ID)
3. DELETE from UserDefaults (baseUrl)
4. Clear all cached data
5. Return to WelcomeScreen

---

## 🔄 DETAILED BOOKING FLOW (STEP BY STEP)

### Full Booking Process
```
┌──────────────────────────────────┐
│ User taps "Забронировать"        │
└────────┬─────────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│ Show DateSelectionView           │
│ • Calendar (today + 30 days)     │
│ • Fetch availability on date tap │
│ GET /api/client/availability     │
└────────┬─────────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│ Show TimeSlotSelectionView       │
│ • Parse availability response    │
│ • Convert UTC times to local     │
│ • Show capacity "N/M"            │
│ • User selects slot              │
└────────┬─────────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│ Show BookingSummaryView          │
│ • Display all details            │
│ • User confirms                  │
└────────┬─────────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│ POST /api/client/appointments    │
│ Body: {                          │
│   startIso: "2024-01-15T08:00Z", │
│   clientName: "John Doe",        │
│   phone: "+79991234567",         │
│   telegram: "johndoe",           │
│   carMake: "BMW",                │
│   carPlate: "ABC123",            │
│   serviceName: "Полировка авто", │
│   notes: "Новая краска"          │
│ }                                │
└────────┬─────────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│ Response: 201 Created            │
│ {                                │
│   id: "APT-12345",               │
│   status: "new",                 │
│   createdAt: "2024-01-14T10:30Z" │
│ }                                │
└────────┬─────────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│ Show ConfirmationView            │
│ • Appointment ID                 │
│ • All details                    │
│ • [My Bookings] [Home]           │
└──────────────────────────────────┘
```

### Timezone Handling (CRITICAL!)
```swift
// ❌ WRONG: Don't send local time directly
let formatter = DateFormatter()
formatter.dateFormat = "HH:mm"
// This will be interpreted as UTC!

// ✅ CORRECT: Send ISO 8601 UTC time
let iso8601 = ISO8601DateFormatter().string(from: selectedDate)
// "2024-01-15T08:00:00Z"

// When fetching availability:
// ✅ CORRECT: Send timezone offset
let tzOffset = TimeZone.current.secondsFromGMT() / 60
// For UTC+3 (Moscow): -180
// For UTC+0 (GMT): 0
// For UTC-5 (EST): 300

// Response times are UTC (ISO 8601)
// But "startTime" field is already local:
// "startTime": "08:00" (already converted server-side)
```

---

## 📸 PHOTO UPLOAD COMPLETE FLOW

### Step-by-step photo upload
```
1. User opens AppointmentDetailView
2. Taps "Загрузить фото"
   │
   ├─ "Камера" → Open camera
   ├─ "Галерея" → Open photo library
   └─ "Отмена" → Close

3. Image selected/captured
   │
   ├─ Compress to JPEG
   │  └─ Max 2MB
   │
   ├─ POST /api/uploads/presign
   │  ├─ appointmentId: "APT-12345"
   │  ├─ kind: "work" (or "defect")
   │  ├─ filename: "photo_2024_01_15.jpg"
   │  └─ contentType: "image/jpeg"
   │
   ├─ Response: {
   │  ├─ uploadUrl: "https://s3.example.com/...",
   │  ├─ key: "appointments/APT-12345/work/photo.jpg",
   │  └─ ref: "s3:appointments/APT-12345/work/photo.jpg"
   │  }
   │
   ├─ PUT {uploadUrl}
   │  ├─ Content-Type: image/jpeg
   │  ├─ Body: Binary image data
   │  └─ Show progress bar (50%, 80%, 100%)
   │
   ├─ POST /api/client/appointments/APT-12345/photos
   │  ├─ kind: "work"
   │  └─ photoUrls: ["s3:appointments/APT-12345/work/photo.jpg"]
   │
   └─ Reload appointment detail
      └─ Photo appears in gallery
```

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

---

## 🌐 API ERROR HANDLING

### Common Errors and Recovery

#### 401 Unauthorized (Invalid API Key)
```
Scenario: API key expired or invalid
Response: 401 Unauthorized

Recovery:
1. Clear Keychain (delete API key)
2. Clear UserDefaults
3. Show alert: "Сеанс истёк. Переподключитесь."
4. Auto-dismiss and return to WelcomeScreen
```

#### 404 Not Found
```
Scenario: Appointment doesn't exist, service deleted
Response: 404 Not Found

Recovery:
1. Log the error
2. Show user-friendly message: "Данные не найдены"
3. Return to previous screen
```

#### 409 Conflict (Time slot taken)
```
Scenario: Another user booked the same slot
Response: 409 Conflict

Recovery:
1. Refresh availability
2. Show: "Это время только что забронировали"
3. Return to time slot selection
```

#### 500 Server Error
```
Scenario: Backend crashes or database error
Response: 500 Internal Server Error

Recovery:
1. Show: "Ошибка сервера. Повторите позже."
2. Log error details (for debugging)
3. Offer retry button
4. Auto-retry with exponential backoff
```

#### Network Errors (No Internet)
```
Scenario: No WiFi/cellular connection
Error: Network timeout or no connection

Recovery:
1. Show offline indicator at top: "⚠️ Нет интернета"
2. Disable all API calls
3. Queue requests locally
4. Auto-retry when connection restored
5. Show: "Проверьте соединение"
```

#### Request Timeout
```
Scenario: Server takes too long to respond (>30 seconds)
Error: URLSessionError.timedOut

Recovery:
1. Show: "Истекло время ожидания"
2. Offer manual retry
3. Increase timeout for next request (up to 60s)
4. Log for debugging
```

---

## 🧪 TESTING STRATEGY

### Unit Tests (20-30 tests)
- [ ] APIClient request building
- [ ] APIClient response parsing
- [ ] KeychainService store/retrieve/delete
- [ ] ImageCompression utility
- [ ] DateFormatting helpers
- [ ] TimezoneOffset calculation
- [ ] URL validation
- [ ] Form validation (name, phone, etc.)

### Integration Tests (15-20 tests)
- [ ] Full onboarding flow (init → profile → main)
- [ ] Service list fetch + caching
- [ ] Availability fetch with timezone
- [ ] Booking creation end-to-end
- [ ] Photo upload to S3
- [ ] Message retrieval and mark read
- [ ] Profile update
- [ ] Error scenarios (401, 404, 500, timeout)

### UI Tests (10-15 tests)
- [ ] Welcome screen navigation
- [ ] QR code scanner → profile setup
- [ ] Manual URL entry validation
- [ ] Service list display
- [ ] Date picker functionality
- [ ] Time slot selection
- [ ] Booking confirmation
- [ ] Photo upload UI
- [ ] Message list refresh
- [ ] Profile edit

### Manual Testing (Critical)
- [ ] Test on iPhone 12 mini (small screen)
- [ ] Test on iPhone 14 Pro Max (large screen)
- [ ] Test landscape orientation
- [ ] Test dark mode
- [ ] Test with VPN/proxy
- [ ] Test with slow network (network throttling)
- [ ] Test offline → online transition
- [ ] Test app backgrounding (5 min, 1 hour)
- [ ] Test with expired API key
- [ ] Test booking race condition (slot taken)
- [ ] Test large photo upload (>50MB)

---

## 📦 DEPENDENCIES (Minimal, Swift Package Manager)

### Required (built-in)
- Foundation
- SwiftUI
- Combine
- Security (Keychain)
- AVFoundation (Camera)
- PhotosUI (Photo Library)

### Recommended Optional
```swift
// QR Code Scanner (use AVFoundation native instead)
// Image Loading
.package(url: "https://github.com/SDWebImage/SDWebImage.git", from: "5.0.0")

// Optional: Use native URLSession, not Alamofire
// Keep dependencies minimal for app size
```

**Recommendation:** Start without third-party deps, add only if necessary.

---

## 🚀 DEVELOPMENT TIMELINE

### Week 1-2: Setup & Onboarding (2 weeks)
**Goal: User can setup profile and enter main app**

- [ ] Xcode project setup (MVVM structure)
- [ ] Package structure created
- [ ] APIClient basic implementation
- [ ] KeychainService implementation
- [ ] Models defined (User, Service, etc.)
- [ ] WelcomeScreen UI
- [ ] QRCodeScannerView (AVFoundation)
- [ ] ManualURLEntryView
- [ ] ProfileSetupView UI
- [ ] POST /api/ios/init integration
- [ ] POST /api/ios/profile integration
- [ ] Navigation flow (RootView logic)
- [ ] Error handling basics
- [ ] Unit tests for services

**Deliverable:** User can scan QR, enter URL, create profile → reach MainTabView

**Test:** Run on physical iPhone (simulator isn't enough for camera)

---

### Week 3-4: Services & Booking (2 weeks)
**Goal: Complete booking flow working**

- [ ] HomeTab UI and mock data
- [ ] ServicesTab list view
- [ ] ServiceDetailView
- [ ] GET /api/client/services integration
- [ ] Service image loading (AsyncImage)
- [ ] Date picker implementation
- [ ] GET /api/client/availability integration
- [ ] Timezone offset calculation fix
- [ ] TimeSlotSelection UI
- [ ] BookingSummaryView
- [ ] POST /api/client/appointments
- [ ] BookingConfirmationView
- [ ] BookingsTab (upcoming + past)
- [ ] AppointmentDetailView
- [ ] Integration tests
- [ ] Error handling + retry logic

**Deliverable:** User can browse services, select date/time, complete booking

**Test:** End-to-end booking on physical device + test date/time display

---

### Week 5-6: Photos & Messages (2 weeks)
**Goal: Photo upload and messaging working**

- [ ] Photo upload UI (Camera | Library | Preset)
- [ ] Image compression utility
- [ ] POST /api/uploads/presign integration
- [ ] S3 upload with URLSession
- [ ] Upload progress UI
- [ ] POST /api/client/appointments/{id}/photos
- [ ] Photo gallery display
- [ ] MessagesTab UI
- [ ] GET /api/ios/messages integration
- [ ] POST /api/ios/messages/:id/read
- [ ] Auto-refresh messages (timer)
- [ ] Unread badge implementation
- [ ] Integration tests

**Deliverable:** User can upload photos and receive messages

**Test:** Test photo upload with slow network, multiple files

---

### Week 7: Profile & Polish (1 week)
**Goal: All features complete, ready for polish**

- [ ] ProfileTab implementation
- [ ] Edit profile (modal or separate screen)
- [ ] POST /api/ios/profile (update) integration
- [ ] GET /api/ios/profile refresh
- [ ] Settings screen (change URL, logout)
- [ ] Logout with Keychain cleanup
- [ ] Network monitor (offline indicator)
- [ ] Loading states refactor
- [ ] Empty state screens
- [ ] Error messages refinement
- [ ] Dark mode support
- [ ] Accessibility (VoiceOver)
- [ ] Performance optimization

**Deliverable:** All features polished, ready for testing

**Test:** Full app walkthrough, dark mode, accessibility

---

### Week 8: Testing & Submission (1 week)
**Goal: Ready for App Store**

- [ ] Bug fixes from week 7 testing
- [ ] Unit + integration test coverage
- [ ] Code review + refactoring
- [ ] Performance profiling
- [ ] Memory leak detection
- [ ] Security audit (Keychain, HTTPS)
- [ ] App icons + launch screen
- [ ] Privacy policy written
- [ ] App Store metadata
- [ ] Build + code signing
- [ ] Final testing on multiple devices
- [ ] Submit to App Store

**Deliverable:** App submitted to App Store (or ready to submit)

---

## ✅ SUCCESS CRITERIA

### MVP (Must Have)
- ✅ Scan QR code or enter URL manually
- ✅ Create user profile
- ✅ API key stored securely in Keychain
- ✅ Browse services list
- ✅ Check availability and book appointment
- ✅ View booked appointments
- ✅ Upload photos to appointment
- ✅ Receive messages from car wash
- ✅ Handle all network errors gracefully
- ✅ Works on iPhone 12 mini to iPhone 14 Pro Max
- ✅ Dark mode support
- ✅ Ready for App Store submission

### Nice to Have (v1.1+)
- 📱 iPad support
- 📍 Location-based car wash search
- 🔔 Push notifications
- 💳 In-app payment
- ⭐ Ratings & reviews
- 📱 Siri Shortcuts
- 🌍 Multi-language support
- 👥 Referral system

---

## 📋 PRE-SUBMISSION CHECKLIST

### Code Quality
- [ ] No hardcoded API keys
- [ ] No test credentials left
- [ ] No NSLog or print statements (except errors)
- [ ] No TODO comments (all done)
- [ ] Code properly formatted
- [ ] No unused imports
- [ ] Proper error handling everywhere
- [ ] Memory leak free (Instruments check)

### Security
- [ ] API key only in Keychain
- [ ] HTTPS only (no HTTP except localhost)
- [ ] No password storage
- [ ] Certificate pinning (optional, for production)
- [ ] No sensitive data in logs
- [ ] Privacy policy written

### iOS Requirements
- [ ] Minimum iOS 13.0 target
- [ ] All screens support both orientations
- [ ] Safe area handled correctly
- [ ] Notch/Dynamic Island aware
- [ ] Dark mode fully supported
- [ ] App icons all sizes
- [ ] Launch screen included
- [ ] Permissions in Info.plist:
  - [ ] NSCameraUsageDescription
  - [ ] NSPhotoLibraryUsageDescription
  - [ ] NSPhotoLibraryAddOnlyUsageDescription

### App Store
- [ ] App name (30 chars max)
- [ ] Subtitle (30 chars max)
- [ ] Description (4000 chars max)
- [ ] Keywords
- [ ] Support URL
- [ ] Privacy policy URL
- [ ] Screenshots (5-6 per orientation)
- [ ] Preview video (optional)
- [ ] App category selected
- [ ] Content rating completed
- [ ] EULA (if needed)

### Metadata Examples
```
App Name: AutoDetail Hub

Subtitle: Book car detailing in seconds

Description:
AutoDetail Hub — приложение для быстрого бронирования автомойки 
и детейлинга. Выберите время, загрузите фото авто, получайте 
обновления о вашей записи. Более 500 салонов уже используют!

Keywords: автомойка, детейлинг, полировка, бронирование, авто
```

---

## 🤝 API SUPPORT & COMMUNICATION

### Backend is Ready ✅
All endpoints tested and working:
- `POST /api/ios/init` ✅
- `GET /api/ios/profile` ✅
- `POST /api/ios/profile` ✅
- `GET /api/client/services` ✅
- `GET /api/client/availability` ✅
- `POST /api/client/appointments` ✅
- `POST /api/uploads/presign` ✅
- `GET /api/ios/messages` ✅
- All photo upload endpoints ✅

### If You Get 401 Errors
1. Verify API key is stored correctly in Keychain
2. Verify X-API-Key header is sent
3. Check API key format (starts with "ios_")
4. Check if API key still valid (not deleted)

### If You Get 400 Errors
1. Verify request body JSON structure
2. Verify timezone offset calculation
3. Verify date format (YYYY-MM-DD)
4. Check required fields are present

### Common Timezone Issues
```swift
// ❌ WRONG: Sending local time without timezone info
startIso: "2024-01-15 08:00:00" // Server gets confused!

// ✅ CORRECT: ISO 8601 UTC
startIso: "2024-01-15T08:00:00Z"

// For availability query:
// UTC+3 (Moscow): tzOffsetMinutes = -180
// UTC+0 (London): tzOffsetMinutes = 0
// UTC-5 (NYC): tzOffsetMinutes = 300

let offset = TimeZone.current.secondsFromGMT() / 60
```

---

## 📚 CODE EXAMPLES

### APIClient Basic Template
```swift
import Foundation
import Combine

class APIClient {
    static let shared = APIClient()
    
    private let session: URLSession
    private let baseURL: URL
    
    init(baseURL: URL? = nil) {
        self.baseURL = baseURL ?? URL(string: "https://api.example.com")!
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    func request<T: Decodable>(
        _ endpoint: String,
        method: String = "GET",
        body: Encodable? = nil,
        apiKey: String? = nil
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        if let apiKey = apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }
        
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return try JSONDecoder().decode(T.self, from: data)
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        case 500...599:
            throw APIError.serverError
        default:
            throw APIError.unknownError
        }
    }
}
```

### KeychainService Template
```swift
import Security
import Foundation

class KeychainService {
    static let shared = KeychainService()
    
    private let service = "com.autodetail.ios"
    
    func store(apiKey: String) throws {
        let data = apiKey.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "apiKey",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            throw KeychainError.storageFailed
        }
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
        
        if status == errSecSuccess {
            return String(data: result as! Data, encoding: .utf8)
        }
        return nil
    }
    
    func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "apiKey"
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
```

---

## 🎯 FINAL REMINDERS

### Architecture Decisions
- Use MVVM + Combine (modern iOS)
- SwiftUI for UI (not UIKit)
- No external dependencies for MVP
- Async/await for networking
- Combine for reactive state

### Performance
- Cache service list (1 hour TTL)
- Lazy load images
- Don't block main thread
- Implement pagination for long lists
- Profile on iPhone 12 mini (slowest)

### Security
- API key in Keychain (NOT UserDefaults)
- HTTPS only
- No logging of sensitive data
- Validate all URLs (HTTPS)
- Clear data on logout

### Testing
- Unit tests for services
- Integration tests for flows
- Manual test on real device (camera!)
- Test all error scenarios
- Test dark mode

### Submission
- Start review process by Week 7
- Budget 1-2 weeks for App Store review
- Have alternative contact in case rejection
- Have privacy policy ready
- Have screenshots and descriptions ready

---

## 🚀 START HERE

1. **Create Xcode Project**
   - iOS, Single View App
   - Swift language
   - SwiftUI interface

2. **Copy This Entire Prompt to Cursor**
   - Paste in "System Prompt" or "Context"
   - Use as reference throughout development

3. **Follow Week-by-Week Plan**
   - Do week 1-2 checklist first
   - Build incrementally
   - Test as you go

4. **Ask Questions**
   - API issues: Check `/api/docs`
   - Backend questions: Ask dev team
   - Architecture questions: Reference MVVM patterns

5. **Iterate Frequently**
   - Commit to git daily
   - Test on real device weekly
   - Get feedback from backend team early

---

**Document Status:** Complete & Production Ready ✅  
**Last Updated:** January 2024  
**Backend API Version:** 1.0  
**iOS Target:** iOS 13.0+  
**Architecture:** MVVM + Combine + SwiftUI

Good luck! Build something amazing! 🎉
