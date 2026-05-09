# Mobile API Documentation (Updated)

This document provides the updated API specification for the E-Presensi Flutter application following the integration of Multi-Location support and Work Modes.

## 1. Authentication
All endpoints (except login) require a Bearer Token in the `Authorization` header.

## 2. Login
**Endpoint:** `POST /api/login`
**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "password"
}
```
**Response Sample (Updated):**
```json
{
  "user": {
    "id": 1,
    "name": "John Doe",
    "email": "john@example.com",
    "work_mode": "wfo", // wfo, wfh, wfa
    "company_id": 1,
    "image_url": "http://.../storage/avatars/user.jpg"
  },
  "token": "1|abc...",
  "work_mode": "wfo",
  "company": {
    "id": 1,
    "name": "Main Office",
    "latitude": "-6.208763",
    "longitude": "106.845599",
    "radius_km": 0.5
  },
  "default_shift_detail": {
    "id": 1,
    "name": "Shift Pagi",
    "start_time": "08:00:00",
    "end_time": "17:00:00"
  }
}
```

## 3. Check-In
**Endpoint:** `POST /api/checkin`
**Request Body:**
```json
{
  "latitude": "-6.208763",
  "longitude": "106.845599",
  "work_mode": "wfo" // Optional. Defaults to User's default mode if not sent.
}
```
**Logic:**
- If `work_mode` is `wfo`: Validates GPS against the assigned `company` (or all companies if none assigned).
- If `work_mode` is `wfh` or `wfa`: Bypasses radius check, records current location only.

## 4. Check-Out
**Endpoint:** `POST /api/checkout`
**Request Body:**
```json
{
  "latitude": "-6.208763",
  "longitude": "106.845599"
}
```
**Logic:**
- Only validates location if the morning `checkin` was done in `wfo` mode.

## 5. Get Current Profile (Me)
**Endpoint:** `GET /api/me`
**Response Sample:**
(Matches the `login` response structure without the `token` field).

## 6. Work Modes Reference
- `wfo`: Work From Office (Strict GPS validation required).
- `wfh`: Work From Home (GPS recorded but not validated).
- `wfa`: Work From Anywhere (GPS recorded but not validated).

## 7. Location Fallback
If an employee is NOT assigned to a specific location in the Admin Panel (`company_id` is null), the API will attempt to match their GPS against **ANY** registered office/branch in the database.
