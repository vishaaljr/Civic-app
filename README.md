# Implemented Features

## 1. Intelligent Issue Reporting with Auto Geolocation
Our app simplifies the complaint submission process with an advanced water tank reporting feature that captures precise GPS coordinates automatically. Users can easily specify the nature of their complaint, ensuring that every issue is accurately categorized. This level of granularity empowers local authorities to respond swiftly and effectively.

![App Screenshot](Working_images/im5.jpeg)
![App Screenshot](Working_images/im4.jpeg)

## 2. Multi-Step Smart Capture Workflow
Experience a seamless 4-step stepper flow that guides users through the complaint submission process. Our innovative multi-step workflow incorporates a camera capture feature, enabling users to document issues visually. Each photo taken is automatically geo-tagged, making it easier for response teams to locate the problem areas without ambiguity.
![App Screenshot](Working_images/im6.jpeg)
![App Screenshot](Working_images/im7.jpeg)

## 3. Real-Time Submission Confirmation
Instant feedback is crucial in user experience. Upon submitting a complaint, users receive immediate confirmation of their submission's success. This feature not only fosters user confidence but also enhances the overall interaction with the app, making them feel valued and heard.
![App Screenshot](Working_images/im2.jpeg)
![App Screenshot](Working_images/im1.jpeg)

## 4. Interactive Geospatial Issue Mapping
Our dynamic maps visualize complaints in real-time, clustering similar issues together for efficient assessment. Users can track the status of their reports interactively, allowing for transparent communication and fostering trust in the system. This geospatial mapping feature employs cutting-edge technology to bring clarity and insight into local issues, enabling informed decisions by civic authorities.

In summary, these features represent our commitment to leveraging technology for intelligent civic engagement, ensuring that user needs are met promptly and efficiently.

![App Screenshot](Working_images/im1.jpeg)
## 📌 Overview

Civic App is a tri-module smart platform designed to bridge the gap between citizens and municipal authorities:

- **Backend (Django REST API)** – Complaint management, authentication, duplicate detection, analytics
- **Frontend (Flutter)** – Cross-platform mobile app for reporting and tracking issues
- **AI Module (TensorFlow)** – Pothole detection and 1280-dimensional image embeddings for similarity search

The system uses AI embeddings + geospatial clustering to detect duplicate complaints, preventing spam while amplifying community issues.

---

## ✨ Features

### For Citizens
- **Secure Authentication** – JWT-based user registration and login
- **Issue Reporting** – Submit complaints with images, GPS coordinates, description, and severity level
- **Smart Duplicate Detection** – AI detects visually and geographically similar issues; merges reports instead of creating duplicates
- **Upvote System** – Community can amplify urgent issues to accelerate authority response
- **Complaint Tracking** – View full lifecycle of reported issues with real-time status updates
- **Gamification** – Earn "Civic Points" for verified reports, incentivizing civic participation

### For Authorities
- **Centralized Dashboard** – Overview of all city issues with KPI cards (total, open, in progress, resolved)
- **Complaint Management** – View, filter, search, and update issue status (Submitted → In Progress → Resolved)
- **Priority Queue** – Issues sorted by severity score (upvotes, emergency flag, base severity)
- **Heatmap & Analytics** – Identify hotspots and trends by issue type, category, and ward
- **Export & Reporting** – Generate reports for governance and budget allocation

### Technical Highlights
- **pgvector Integration** – PostgreSQL with vector extension for fast cosine similarity search
- **Transfer Learning** – MobileNetV2-based pothole detector with 98% test accuracy
- **Responsive UI** – Flutter Material 3 with light/dark theme support, Instagram-style swipe navigation
- **Role-Based Access** – Three roles (citizen, authority, admin) with permission-based endpoints
- **Production Ready** – CORS headers, secure token handling, multipart image uploads

---

## 🏗 Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Frontend (Flutter)                       │
│  - Citizen & Admin Shells   - Issue Reporting   - Dashboard      │
│  - Real-time Status Updates - Map View          - Analytics      │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                      (HTTP REST)
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                   Backend (Django + DRF)                         │
│  - User Management (JWT)      - Complaint CRUD                   │
│  - Role-Based Permissions     - Upvote System                    │
│  - Dashboard Analytics        - Notification System              │
└──────────────────────────┬──────────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
   (PostgreSQL)     (pgvector)          (File Storage)
        │                  │                  │
┌───────▼─────────┐ ┌─────▼──────┐ ┌────────▼──────┐
│  User Models    │ │  Embeddings│ │  Image Files  │
│  Complaints     │ │  Cosine    │ │  (Pillow)     │
│  Upvotes        │ │  Distance  │ │               │
└─────────────────┘ └────────────┘ └───────────────┘
                           ▲
                           │
                      (REST Calls)
                           │
┌───────────────────────────────────────────────────────────────���──┐
│                     AI Module (TensorFlow)                        │
│  - Image Preprocessing (224×224)                                 │
│  - MobileNetV2 Binary Classifier                                 │
│  - 1280-Dimensional Embedding Extraction                         │
│  - Inference API (train.py, predict.py)                          │
└──────────────────────────────────────────────────────────────────┘
```

---

## 📦 Installation

### Prerequisites
- **Python 3.8+**
- **PostgreSQL 12+** (with pgvector extension)
- **Flutter 3.24+** & **Dart 3.5+**
- **Node.js** (optional, for frontend build tools)
- **Git**

### Backend Setup

1. **Clone and navigate:**
   ```bash
   git clone https://github.com/vishaaljr/Civic-app.git
   cd Civic-app/Backend
   ```

2. **Create a virtual environment:**
   ```bash
   python -m venv venv
   
   # On Windows:
   venv\Scripts\activate
   
   # On macOS/Linux:
   source venv/bin/activate
   ```

3. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

4. **Set up PostgreSQL:**
   ```bash
   createdb civic
   ```
   Install pgvector extension (if not already installed):
   ```sql
   CREATE EXTENSION IF NOT EXISTS vector;
   ```

5. **Configure environment variables:**
   Create a `.env` file in `Backend/`:
   ```dotenv
   DATABASE_URL=postgresql://postgres:password@localhost:5432/civic
   DEBUG=True
   SECRET_KEY=your-secret-key-here
   ```

6. **Run migrations:**
   ```bash
   python manage.py makemigrations
   python manage.py migrate
   ```

7. **Create a superuser:**
   ```bash
   python manage.py createsuperuser
   ```

8. **Start the development server:**
   ```bash
   python manage.py runserver
   ```
   Server available at `http://127.0.0.1:8000/`

### Frontend Setup (Flutter)

1. **Navigate to frontend:**
   ```bash
   cd ../App\ frontend
   ```

2. **Get dependencies:**
   ```bash
   flutter pub get
   ```

3. **Update API base URL** (in `lib/core/services/api_service.dart`):
   ```dart
   const String kBaseUrl = 'http://YOUR_BACKEND_IP:8000/api';
   ```

4. **Run the app:**
   ```bash
   flutter run
   ```

5. **Build for release:**
   ```bash
   flutter build apk --release      # Android
   flutter build ipa                 # iOS
   ```

### AI Module Setup

1. **Navigate to AI module:**
   ```bash
   cd ../App\ Ai\ Module
   ```

2. **Install dependencies:**
   ```bash
   pip install tensorflow numpy matplotlib
   ```

3. **Prepare dataset structure:**
   ```
   dataset/
   ├── train/
   │   ├── pothole/
   │   └── normal/
   ├── val/
   │   ├── pothole/
   │   └── normal/
   └── test/
       ├── pothole/
       └── normal/
   ```

4. **Train the model:**
   ```bash
   python train.py
   ```
   Outputs `pothole_classifier.h5`

5. **Test inference:**
   ```bash
   python predict.py
   # Then enter image path when prompted
   ```

---

## ⚙️ Configuration

### Backend Settings

Configure in `Backend/civic_demo/settings.py`:

```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'civic',
        'USER': 'postgres',
        'PASSWORD': 'root',
        'HOST': 'localhost',
        'PORT': '5432',
    }
}

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'rest_framework',
    'rest_framework_simplejwt',
    'corsheaders',
    'users',
    'complaints',
]

CORS_ALLOWED_ORIGINS = [
    'http://localhost:3000',
    'http://127.0.0.1:3000',
]
```

### Environment Variables

Create `.env` in `Backend/`:
```dotenv
DATABASE_URL=postgresql://user:password@host:5432/civic
DEBUG=False
SECRET_KEY=your-production-secret-key
ALLOWED_HOSTS=yourdomain.com,www.yourdomain.com
```

### Flutter Configuration

Update `lib/core/services/api_service.dart`:
```dart
const String kBaseUrl = 'http://10.0.2.2:8000/api';  // For Android emulator
// const String kBaseUrl = 'http://127.0.0.1:8000/api';  // For localhost
// const String kBaseUrl = 'http://192.168.x.x:8000/api';  // For real device
```

---

## 🚀 Usage

### Quick Start (Development)

1. **Start Backend:**
   ```bash
   cd Backend
   python manage.py runserver 0.0.0.0:8000
   ```

2. **Start Frontend:**
   ```bash
   cd App\ frontend
   flutter run
   ```

3. **Test API Endpoints:**
   Use Postman, Insomnia, or cURL:
   ```bash
   # Register
   curl -X POST http://localhost:8000/api/auth/register/ \
     -H "Content-Type: application/json" \
     -d '{
       "username": "citizen1",
       "password": "securepassword",
       "email": "citizen@example.com",
       "role": "citizen"
     }'

   # Login
   curl -X POST http://localhost:8000/api/auth/login/ \
     -H "Content-Type: application/json" \
     -d '{
       "username": "citizen1",
       "password": "securepassword"
     }'
   ```

### Example Citizen Workflow

1. **Launch App** → Onboarding → Auth Screen
2. **Login as Citizen** → Navigate to "Report Issue"
3. **Fill Form:**
   - Category: Pothole
   - Description: "Large crater on MG Road"
   - Severity: Critical
   - Take/Select Photo
   - Allow Location Access (auto-fills GPS)
4. **Submit Complaint** → Confirmation with unique complaint number
5. **View in "My Issues"** → Track status in real-time

### Example Authority Workflow

1. **Login as Admin/Authority**
2. **Dashboard View** → See KPI cards and quick stats
3. **Navigate to Issues** → Filter by status, sort by severity
4. **Click Issue** → View photos, reporter info, location
5. **Update Status** → Submitted → In Progress → Resolved
6. **Add Internal Notes** → Timeline updates automatically
7. **Export Report** → (Future feature)

---

## 📡 API Reference

Base URL: `http://127.0.0.1:8000/api`

### Authentication Endpoints

#### Register User
```
POST /auth/register/
Content-Type: application/json

{
  "username": "johndoe",
  "password": "securepassword123",
  "email": "john@example.com",
  "phone": "9876543210",
  "role": "citizen"
}

Response: 201 Created
{
  "id": 1,
  "username": "johndoe",
  "role": "citizen",
  "message": "Registered successfully"
}
```

#### Login
```
POST /auth/login/
Content-Type: application/json

{
  "username": "johndoe",
  "password": "securepassword123"
}

Response: 200 OK
{
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "access": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}
```

#### Get Current User
```
GET /auth/me/
Authorization: Bearer <access_token>

Response: 200 OK
{
  "id": 1,
  "username": "johndoe",
  "role": "citizen",
  "civic_points": 150
}
```

### Complaint Endpoints

#### Submit Complaint
```
POST /complaints/submit/
Authorization: Bearer <access_token>
Content-Type: multipart/form-data

Form Data:
- images: [File]
- latitude: "12.9716"
- longitude: "77.5946"
- address: "MG Road, Bangalore"
- issue_type: "pothole"
- description: "Large pothole causing traffic"
- severity: "critical"
- is_emergency: "true"

Response: 201 Created / 200 OK (if duplicate merged)
{
  "id": "uuid",
  "complaint_number": "CMP-00001",
  "issue_type": "pothole",
  "status": "submitted",
  "severity_score": 95.5,
  "upvote_count": 0,
  "is_duplicate": false
}
```

#### List All Complaints
```
GET /complaints/?status=submitted&issue_type=pothole
Authorization: Bearer <access_token>

Response: 200 OK
[
  {
    "id": "uuid",
    "complaint_number": "CMP-00001",
    "issue_type": "pothole",
    "status": "submitted",
    "severity_score": 95.5,
    ...
  }
]
```

#### Get Complaint Details
```
GET /complaints/<uuid>/
Authorization: Bearer <access_token>

Response: 200 OK
{
  "id": "uuid",
  "complaint_number": "CMP-00001",
  "description": "Large pothole on MG Road",
  "images": ["http://...image1.jpg", "http://...image2.jpg"],
  "history": [
    {"status": "submitted", "timestamp": "2026-03-02T10:00:00Z"},
    {"status": "in_progress", "timestamp": "2026-03-02T11:30:00Z"}
  ],
  ...
}
```

#### Update Complaint Status
```
PATCH /complaints/<uuid>/status/
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "status": "in_progress"
}

Response: 200 OK
```

#### Upvote Complaint
```
POST /complaints/<uuid>/upvote/
Authorization: Bearer <access_token>

Response: 200 OK
{
  "upvote_count": 5
}
```

### Dashboard & Analytics

#### Get Dashboard Stats
```
GET /dashboard/
Authorization: Bearer <access_token>

Response: 200 OK (Authority/Admin)
{
  "total_complaints": 150,
  "open_complaints": 45,
  "in_progress": 30,
  "resolved": 75,
  "by_issue_type": {
    "pothole": 80,
    "garbage": 40,
    "streetlight": 20,
    "other": 10
  }
}

Response: 200 OK (Citizen)
{
  "total_civic_points": 450,
  "total_reports": 5,
  "resolved_reports": 3,
  "pending_reports": 2
}
```

---

## 🧪 Testing

### Backend Tests

```bash
cd Backend

# Run all tests
python manage.py test

# Run specific app tests
python manage.py test users
python manage.py test complaints

# With verbose output
python manage.py test --verbosity=2
```

### API Testing with cURL

```bash
# Test complaint submission
curl -X POST http://localhost:8000/api/complaints/submit/ \
  -H "Authorization: Bearer $TOKEN" \
  -F "images=@/path/to/image.jpg" \
  -F "latitude=12.9716" \
  -F "longitude=77.5946" \
  -F "issue_type=pothole" \
  -F "severity=critical"
```

### Flutter Widget Testing

```bash
cd App\ frontend

# Run all tests
flutter test

# Run specific test file
flutter test test/widgets/issue_card_test.dart

# Generate coverage report
flutter test --coverage
```

### AI Module Testing

```bash
cd App\ Ai\ Module

# Inference test
python predict.py
# Enter image path when prompted
```

---

## 🛠 Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Frontend** | Flutter 3.24+ | Cross-platform mobile app |
| **State Mgmt** | Riverpod 2 | Reactive state management |
| **Navigation** | go_router | Type-safe routing |
| **Backend** | Django 6.0.2 | REST API server |
| **API Framework** | Django REST Framework | Serialization & viewsets |
| **Authentication** | SimpleJWT | JWT token handling |
| **Database** | PostgreSQL + pgvector | Relational + vector search |
| **ORM** | Django ORM | Database abstraction |
| **Image Processing** | Pillow | Image upload & storage |
| **AI/ML** | TensorFlow 2.16.1 | Deep learning inference |
| **Model** | MobileNetV2 | Pothole detection (transfer learning) |
| **Vector Search** | pgvector | Cosine similarity for duplicates |
| **Charts** | fl_chart | Data visualization (Flutter) |
| **HTTP Client** | http package | API requests |
| **Local Storage** | shared_preferences | User preferences |
| **Secure Storage** | flutter_secure_storage | JWT token storage |
| **CORS** | django-cors-headers | Cross-origin requests |

---

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Development Guidelines

- Follow PEP 8 (Python) and Dart style guides
- Write tests for new features
- Update documentation
- Keep commits atomic and descriptive

---

## 📄 License

This project is open source. See the repository for license details.

---

## 📞 Support

For issues, questions, or suggestions:
- Open a [GitHub Issue](https://github.com/vishaaljr/Civic-app/issues)
- Check existing [discussions](https://github.com/vishaaljr/Civic-app/discussions)

---

*Built with ❤️ to empower civic participation and improve city infrastructure.*
