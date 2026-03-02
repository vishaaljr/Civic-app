# Civic Connect - Backend Service

Civic Connect is a smart civic grievance reporting and management platform designed to bridge the gap between citizens and authorities. It enables citizens to easily report local issues (like potholes, garbage, broken streetlights) with geographic and image data, while providing civic authorities with a dashboard to prioritize and resolve them efficiently based on severity, upvotes, and duplicate clustering.

## Features

### For Citizens
*   **User Registration & Authentication**: Secure sign-up and login with JWT.
*   **Report Complaints**: Submit complaints with an image, geographical coordinates (latitude and longitude), issue type, description, and severity.
*   **Smart Duplicate Detection**: If a similar complaint is reported nearby with similar images, the system automatically detects it as a duplicate, boosting the original complaint's priority instead of creating spam.
*   **Upvote System**: Upvote existing complaints to increase their severity score and priority.
*   **Track Complaints**: View a history of reported complaints and track their live status.
*   **Gamification**: Earn "Civic Points" for submitting verified reports, incentivizing active civic participation.

### For Authorities
*   **Authority Dashboard**: A bird's-eye view of all issues across the city.
*   **Complaint Management**: View, track, and update the status of complaints ( Submitted -> In Progress -> Resolved ).
*   **Data Analytics & Heatmap**: Analyze complaints to identify hotspots based on issue type and severity scores.
*   **Priority Queue**: Access issues sorted dynamically based on user upvotes, emergency status, and base severity.

## Installation & Setup

### Prerequisites
1.  Python 3.8+
2.  PostgreSQL installed and running locally.

### Step-by-Step Guide

1.  **Clone the Repository** and navigate to the backend directory:
    ```bash
    cd civic_demo
    ```

2.  **Create and Activate a Virtual Environment**:
    ```bash
    python -m venv venv
    
    # On Windows:
    venv\Scripts\activate
    
    # On macOS/Linux:
    source venv/bin/activate
    ```

3.  **Install Dependencies**:
    ```bash
    pip install -r requirements.txt
    ```
    *(Note: Ensure requirements like django, djangorestframework, djangorestframework-simplejwt, psycopg2-binary, Pillow, imagehash, corsheaders are installed.)*

4.  **Database Configuration**:
    Open `civic_demo/settings.py` and ensure the `DATABASES` setting matches your local PostgreSQL credentials:
    ```python
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.postgresql',
            'NAME': 'civic',
            'USER': 'postgres',      # Replace with your postgres user
            'PASSWORD': 'root',      # Replace with your postgres password
            'HOST': 'localhost',
            'PORT': '5432',
        }
    }
    ```
    Create the database in PostgreSQL:
    ```sql
    CREATE DATABASE civic;
    ```

5.  **Run Migrations**:
    ```bash
    python manage.py makemigrations
    python manage.py migrate
    ```

6.  **Create a Superuser (Admin or Authority)**:
    ```bash
    python manage.py createsuperuser
    ```

7.  **Run the Development Server**:
    ```bash
    python manage.py runserver
    ```
    The server will start at `http://127.0.0.1:8000/`.

## How to Test

### 1. Automated Testing
Django comes with a built-in test framework. You can run tests (if implemented in `tests.py`) by running:
```bash
python manage.py test
```

### 2. Manual API Testing using Postman or cURL
You can use tools like Postman, Insomnia, or cURL to manually test the API endpoints.
1.  **Start the server:** `python manage.py runserver`
2.  **Register a user:** Send a POST request to `/api/auth/register/` to create a citizen account.
3.  **Login:** Send a POST to `/api/auth/login/` with your credentials to receive an `access` and `refresh` token.
4.  **Authorized Requests:** For any protected endpoint (like `/api/complaints/`), add an Authorization header:
    `Authorization: Bearer <your_access_token>`

## Database Schema (Models)

The application uses a PostgreSQL database. Below are the primary tables (Models) and their purposes.

### 1. User Model (`users.User`)
Extends standard Django `AbstractUser` to support role-based access control and gamification.
*   **username**: Unique identifier.
*   **password**: Hashed password.
*   **email**: User's email address.
*   **phone**: Optional contact number.
*   **role**: Role of the user (`citizen`, `authority`, `admin`). Defaults to `citizen`.
*   **civic_points**: Gamification points awarded for submitting complaints.

### 2. Complaint Model (`complaints.Complaint`)
The core model storing grievance details.
*   **id**: UUID (Primary Key).
*   **complaint_number**: Unique string identifier (e.g., `CMP-00001`).
*   **user**: ForeignKey mapping to the user who reported it.
*   **latitude & longitude**: Geographical coordinates.
*   **address**: Reverse-geocoded or manually entered address string.
*   **issue_type**: Type of issue (`pothole`, `garbage`, `streetlight`, `water_leak`, `drain`, `other`).
*   **description**: Detailed description of the issue.
*   **severity**: Base severity set by user (`low`, `moderate`, `critical`).
*   **severity_score**: A generated dynamic float score influenced by base severity, upvotes, and emergency status. Used by authorities for sorting.
*   **image_hash**: Perceptual hash of the image used for detecting duplicate complaints.
*   **is_duplicate**: Boolean flag.
*   **parent_complaint**: Self-referential ForeignKey linking duplicates to a main original complaint.
*   **status**: Current status (`submitted`, `in_progress`, `resolved`, `rejected`).
*   **upvote_count**: Total number of unique citizen upvotes.
*   **is_emergency**: Boolean flag for urgent issues.
*   **submitted_at / resolved_at**: Timestamps.

### 3. ComplaintImage Model (`complaints.ComplaintImage`)
Stores multiple images for a single complaint.
*   **complaint**: ForeignKey to the Complaint.
*   **image**: The image file path.
*   **is_primary**: Boolean indicating if this is the main image used for hashing.

### 4. ComplaintUpvote Model (`complaints.ComplaintUpvote`)
Tracks votes to prevent multiple votes from the same user.
*   **complaint**: ForeignKey to Complaint.
*   **user**: ForeignKey to User.
* *(Enforces unique constraint on `complaint` and `user` combo)*

### 5. Notification Model (`complaints.Notification`)
Alerts logic for users.
*   **user**: ForeignKey to the receiving User.
*   **complaint**: Related complaint (optional).
*   **message**: The notification text (e.g. "Your complaint CMP-00001 is now resolved").
*   **is_read**: Boolean tracking read status.
*   **created_at**: Timestamp.

---

## Detailed API Documentation

The base URL for all endpoints is usually `http://127.0.0.1:8000/`.

### Authentication Endpoints

#### 1. Register User
*   **URL:** `/api/auth/register/`
*   **Method:** `POST`
*   **Permission:** Open (AllowAny)
*   **Purpose:** To create a new user account. Used on the Sign-Up page.
*   **Payload structure:**
    ```json
    {
      "username": "johndoe",
      "password": "securepassword123",
      "email": "johndoe@example.com",
      "phone": "1234567890",
      "role": "citizen" 
    }
    ```
*   **Response:** `201 Created` with a success message and user details.

#### 2. User Login (Obtain Token)
*   **URL:** `/api/auth/login/`
*   **Method:** `POST`
*   **Permission:** Open
*   **Purpose:** Authenticates the user and returns JWT access & refresh tokens. Used on the Login page.
*   **Payload structure:**
    ```json
    {
      "username": "johndoe",
      "password": "securepassword123"
    }
    ```
*   **Response:** Returns `refresh` and `access` tokens.

#### 3. Refresh Token
*   **URL:** `/api/auth/refresh/`
*   **Method:** `POST`
*   **Purpose:** Obtains a new access token when the old one expires using the refresh token.

#### 4. Get Current User (Me)
*   **URL:** `/api/auth/me/`
*   **Method:** `GET`
*   **Permission:** IsAuthenticated (Header: `Authorization: Bearer <token>`)
*   **Purpose:** Retrieves context about the currently logged-in user, including their role and civic points. Used by the frontend to protect routes or display user profile info.

---

### Complaint Management Endpoints

#### 5. Submit a Complaint
*   **URL:** `/api/complaints/submit/`
*   **Method:** `POST`
*   **Permission:** IsAuthenticated
*   **Content-Type:** `multipart/form-data`
*   **Purpose:** Used by citizens to report an issue. Also handles image hashing to detect if a "duplicate" issue exists nearby. If a duplicate exists, it boosts the priority of the existing one instead of creating a new entry.
*   **Payload structure (Form Data):**
    *   `images`: [File] (At least one image)
    *   `latitude`: "12.9716"
    *   `longitude`: "77.5946"
    *   `address`: "MG Road, Bangalore"
    *   `issue_type`: "pothole"
    *   `description`: "Huge pothole causing traffic"
    *   `severity`: "critical" (low/moderate/critical)
    *   `is_emergency`: "true" / "false"
*   **Response:** `201 Created` if a new complaint is made, or `200 OK` if duplicate is found and upvoted.

#### 6. List All Complaints
*   **URL:** `/api/complaints/`
*   **Method:** `GET`
*   **Permission:** IsAuthenticated
*   **Purpose:** Used primarily by the Authority dashboard or public map to fetch a list of complaints.
*   **Query Parameters (Optional):**
    *   `?status=submitted` (Filter by status)
    *   `?issue_type=garbage` (Filter by issue type)
*   **Response:** `200 OK` Returns an array of serialized complaints.

#### 7. List My Complaints
*   **URL:** `/api/complaints/mine/`
*   **Method:** `GET`
*   **Permission:** IsAuthenticated (Citizen)
*   **Purpose:** Fetches history of complaints exclusively submitted by the logged-in user. Used on the citizen's Profile or "My Reports" page.

#### 8. Get Complaint Detail
*   **URL:** `/api/complaints/<uuid:pk>/`
*   **Method:** `GET`
*   **Permission:** IsAuthenticated
*   **Purpose:** Fetch full details (including all images and history) of a specific complaint. Used when clicking on a singular issue card/pin to open its detail view.

#### 9. Update Complaint Status (Authorities Only)
*   **URL:** `/api/complaints/<uuid:pk>/status/`
*   **Method:** `PATCH`
*   **Permission:** IsAuthenticated (Role must be `authority` or `admin`)
*   **Purpose:** Allows authorities to move a complaint along its lifecycle (`submitted` -> `in_progress` -> `resolved`). Automatically triggers a notification to the user upon update.
*   **Payload Structure:**
    ```json
    {
      "status": "in_progress"
    }
    ```
*   **Response:** `200 OK`

#### 10. Upvote a Complaint
*   **URL:** `/api/complaints/<uuid:pk>/upvote/`
*   **Method:** `POST`
*   **Permission:** IsAuthenticated
*   **Purpose:** Citizens can upvote an existing public issue they also care about. Increases the `severity_score` to alert authorities faster.
*   **Response:** `200 OK` with the new upvote count. Prevents double-voting.

---

### Dashboard and Notifications

#### 11. Dashboard Analytics
*   **URL:** `/api/dashboard/`
*   **Method:** `GET`
*   **Permission:** IsAuthenticated
*   **Purpose:** Dynamically serves stats based on User Role.
    *   **If role is Authority/Admin:** Returns massive metrics - total complaints, resolution rates, pending issues, count grouped by issue types, and a formatted array for rendering the interactive Heatmap.
    *   **If role is Citizen:** Returns their personal performance - Total civic points, total submitted reports, resolved reports, etc.
*   **Response:** `200 OK` with analytics JSON payload.

#### 12. List Notifications
*   **URL:** `/api/notifications/`
*   **Method:** `GET`
*   **Permission:** IsAuthenticated
*   **Purpose:** Fetches the inbox alerts for a user (e.g., "Your complaint is resolved"). Max 20 results.

#### 13. Mark Notifications as Read
*   **URL:** `/api/notifications/`
*   **Method:** `PATCH`
*   **Permission:** IsAuthenticated
*   **Purpose:** Sets all floating unread notifications to "read" so the bell-icon badge clears in the UI.

---
End of Document.
