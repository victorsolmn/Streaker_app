# Streaks Flutter - Complete API Documentation

**Documentation Version**: 1.0
**Last Updated**: 2025-09-16
**Base URL**: `https://your-project.supabase.co`
**Authentication**: JWT Bearer Token
**Content-Type**: `application/json`

## 📋 Table of Contents

1. [Authentication APIs](#authentication-apis)
2. [User Profile APIs](#user-profile-apis)
3. [Nutrition APIs](#nutrition-apis)
4. [Health Metrics APIs](#health-metrics-apis)
5. [Streaks APIs](#streaks-apis)
6. [Goals APIs](#goals-apis)
7. [Dashboard APIs](#dashboard-apis)
8. [Data Models](#data-models)
9. [Error Handling](#error-handling)

---

## 🔐 Authentication APIs

### 1. User Sign Up

| Field | Value |
|-------|-------|
| **URL** | `POST /auth/v1/signup` |
| **Method** | POST |
| **Authentication** | None (Public) |
| **Rate Limit** | 10 requests/minute |

#### Request Parameters

| Field Name | Data Type | Size | Mandatory | Description |
|------------|-----------|------|-----------|-------------|
| `email` | string | 320 chars max | ✅ Yes | Valid email address |
| `password` | string | 6-128 chars | ✅ Yes | User password |
| `data.name` | string | 100 chars max | ✅ Yes | User's full name |

#### Sample Request
```json
{
  "email": "john.doe@example.com",
  "password": "securePassword123",
  "data": {
    "name": "John Doe"
  }
}
```

#### Sample Response (Success - 200)
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 3600,
  "refresh_token": "v1.MR5_BRbIcIFE6...",
  "user": {
    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "email": "john.doe@example.com",
    "email_confirmed_at": "2025-09-16T10:30:00.000Z",
    "user_metadata": {
      "name": "John Doe"
    },
    "created_at": "2025-09-16T10:30:00.000Z"
  }
}
```

#### Sample Response (Error - 400)
```json
{
  "error": {
    "message": "User already registered",
    "code": "signup_disabled"
  }
}
```

---

### 2. User Sign In

| Field | Value |
|-------|-------|
| **URL** | `POST /auth/v1/token?grant_type=password` |
| **Method** | POST |
| **Authentication** | None (Public) |
| **Rate Limit** | 20 requests/minute |

#### Request Parameters

| Field Name | Data Type | Size | Mandatory | Description |
|------------|-----------|------|-----------|-------------|
| `email` | string | 320 chars max | ✅ Yes | User email address |
| `password` | string | 6-128 chars | ✅ Yes | User password |

#### Sample Request
```json
{
  "email": "john.doe@example.com",
  "password": "securePassword123"
}
```

#### Sample Response (Success - 200)
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 3600,
  "refresh_token": "v1.MR5_BRbIcIFE6...",
  "user": {
    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "email": "john.doe@example.com",
    "last_sign_in_at": "2025-09-16T10:30:00.000Z"
  }
}
```

---

### 3. Google OAuth Sign In

| Field | Value |
|-------|-------|
| **URL** | `POST /auth/v1/token?grant_type=oauth` |
| **Method** | POST |
| **Authentication** | None (Public) |
| **Rate Limit** | 15 requests/minute |

#### Request Parameters

| Field Name | Data Type | Size | Mandatory | Description |
|------------|-----------|------|-----------|-------------|
| `provider` | string | 20 chars | ✅ Yes | OAuth provider ("google") |
| `redirect_to` | string | 500 chars | ❌ No | Custom redirect URL |
| `scopes` | string | 200 chars | ❌ No | OAuth scopes |

#### Sample Request
```json
{
  "provider": "google",
  "redirect_to": "com.streaker.streaker://callback",
  "scopes": "email profile"
}
```

---

## 👤 User Profile APIs

### 4. Get User Profile

| Field | Value |
|-------|-------|
| **URL** | `GET /rest/v1/profiles?id=eq.{user_id}&select=*` |
| **Method** | GET |
| **Authentication** | Bearer Token Required |
| **Rate Limit** | 100 requests/minute |

#### Request Parameters

| Field Name | Data Type | Size | Mandatory | Description |
|------------|-----------|------|-----------|-------------|
| `user_id` | UUID | 36 chars | ✅ Yes | User's unique identifier |

#### Sample Response (Success - 200)
```json
{
  "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "email": "john.doe@example.com",
  "name": "John Doe",
  "age": 28,
  "height": 175.5,
  "weight": 70.2,
  "activity_level": "moderately_active",
  "fitness_goal": "build_muscle",
  "daily_calories_target": 2500,
  "created_at": "2025-09-16T10:30:00.000Z",
  "updated_at": "2025-09-16T10:35:00.000Z"
}
```

---

### 5. Update User Profile

| Field | Value |
|-------|-------|
| **URL** | `PATCH /rest/v1/profiles?id=eq.{user_id}` |
| **Method** | PATCH |
| **Authentication** | Bearer Token Required |
| **Rate Limit** | 50 requests/minute |

#### Request Parameters

| Field Name | Data Type | Size | Mandatory | Description |
|------------|-----------|------|-----------|-------------|
| `age` | integer | 3 digits | ❌ No | User age (13-120) |
| `height` | float | 3.1 format | ❌ No | Height in cm (100.0-300.0) |
| `weight` | float | 3.1 format | ❌ No | Weight in kg (30.0-300.0) |
| `activity_level` | string | 20 chars | ❌ No | sedentary, lightly_active, moderately_active, very_active |
| `fitness_goal` | string | 20 chars | ❌ No | lose_weight, maintain_weight, build_muscle, improve_fitness |
| `daily_calories_target` | integer | 4 digits | ❌ No | Daily calorie target (1000-5000) |

#### Sample Request
```json
{
  "age": 28,
  "height": 175.5,
  "weight": 70.2,
  "activity_level": "moderately_active",
  "fitness_goal": "build_muscle",
  "daily_calories_target": 2500
}
```

---

## 🍎 Nutrition APIs

### 6. Add Nutrition Entry

| Field | Value |
|-------|-------|
| **URL** | `POST /rest/v1/nutrition_entries` |
| **Method** | POST |
| **Authentication** | Bearer Token Required |
| **Rate Limit** | 200 requests/minute |

#### Request Parameters

| Field Name | Data Type | Size | Mandatory | Description |
|------------|-----------|------|-----------|-------------|
| `user_id` | UUID | 36 chars | ✅ Yes | User's unique identifier |
| `food_name` | string | 200 chars | ✅ Yes | Name of the food item |
| `calories` | integer | 4 digits | ✅ Yes | Calories per serving (1-9999) |
| `protein` | float | 5.2 format | ✅ Yes | Protein in grams (0.00-999.99) |
| `carbs` | float | 5.2 format | ✅ Yes | Carbohydrates in grams |
| `fat` | float | 5.2 format | ✅ Yes | Fat in grams |
| `fiber` | float | 5.2 format | ❌ No | Fiber in grams |
| `meal_type` | string | 20 chars | ✅ Yes | breakfast, lunch, dinner, snack |
| `food_source` | string | 50 chars | ❌ No | Source of food data |
| `serving_size` | float | 5.2 format | ❌ No | Serving size in grams |

#### Sample Request
```json
{
  "user_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "food_name": "Grilled Chicken Breast",
  "calories": 165,
  "protein": 31.0,
  "carbs": 0.0,
  "fat": 3.6,
  "fiber": 0.0,
  "meal_type": "lunch",
  "food_source": "manual_entry",
  "serving_size": 100.0
}
```

#### Sample Response (Success - 201)
```json
{
  "id": "b2c3d4e5-f6g7-8901-bcde-f23456789012",
  "user_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "food_name": "Grilled Chicken Breast",
  "calories": 165,
  "protein": 31.0,
  "carbs": 0.0,
  "fat": 3.6,
  "fiber": 0.0,
  "meal_type": "lunch",
  "food_source": "manual_entry",
  "serving_size": 100.0,
  "created_at": "2025-09-16T12:30:00.000Z"
}
```

---

### 7. Get Nutrition Entries

| Field | Value |
|-------|-------|
| **URL** | `GET /rest/v1/nutrition_entries?user_id=eq.{user_id}&order=created_at.desc&limit={limit}` |
| **Method** | GET |
| **Authentication** | Bearer Token Required |
| **Rate Limit** | 100 requests/minute |

#### Request Parameters

| Field Name | Data Type | Size | Mandatory | Description |
|------------|-----------|------|-----------|-------------|
| `user_id` | UUID | 36 chars | ✅ Yes | User's unique identifier |
| `limit` | integer | 3 digits | ❌ No | Number of entries to return (1-100) |
| `date` | date | YYYY-MM-DD | ❌ No | Filter by specific date |
| `meal_type` | string | 20 chars | ❌ No | Filter by meal type |

#### Sample Response (Success - 200)
```json
[
  {
    "id": "b2c3d4e5-f6g7-8901-bcde-f23456789012",
    "food_name": "Grilled Chicken Breast",
    "calories": 165,
    "protein": 31.0,
    "carbs": 0.0,
    "fat": 3.6,
    "fiber": 0.0,
    "meal_type": "lunch",
    "created_at": "2025-09-16T12:30:00.000Z"
  },
  {
    "id": "c3d4e5f6-g7h8-9012-cdef-345678901234",
    "food_name": "Brown Rice",
    "calories": 112,
    "protein": 2.6,
    "carbs": 22.0,
    "fat": 0.9,
    "fiber": 1.8,
    "meal_type": "lunch",
    "created_at": "2025-09-16T12:25:00.000Z"
  }
]
```

---

### 8. Get Daily Nutrition Summary

| Field | Value |
|-------|-------|
| **URL** | `GET /rest/v1/rpc/get_daily_nutrition_summary` |
| **Method** | GET |
| **Authentication** | Bearer Token Required |
| **Rate Limit** | 50 requests/minute |

#### Request Parameters

| Field Name | Data Type | Size | Mandatory | Description |
|------------|-----------|------|-----------|-------------|
| `user_id` | UUID | 36 chars | ✅ Yes | User's unique identifier |
| `date` | date | YYYY-MM-DD | ❌ No | Date for summary (defaults to today) |

#### Sample Response (Success - 200)
```json
{
  "date": "2025-09-16",
  "total_calories": 1850,
  "total_protein": 125.5,
  "total_carbs": 180.2,
  "total_fat": 65.8,
  "total_fiber": 28.5,
  "meals": {
    "breakfast": {
      "calories": 450,
      "entries_count": 3
    },
    "lunch": {
      "calories": 650,
      "entries_count": 4
    },
    "dinner": {
      "calories": 600,
      "entries_count": 3
    },
    "snack": {
      "calories": 150,
      "entries_count": 2
    }
  }
}
```

---

## 💓 Health Metrics APIs

### 9. Save Health Metrics

| Field | Value |
|-------|-------|
| **URL** | `POST /rest/v1/health_metrics` |
| **Method** | POST |
| **Authentication** | Bearer Token Required |
| **Rate Limit** | 100 requests/minute |

#### Request Parameters

| Field Name | Data Type | Size | Mandatory | Description |
|------------|-----------|------|-----------|-------------|
| `user_id` | UUID | 36 chars | ✅ Yes | User's unique identifier |
| `steps` | integer | 6 digits | ❌ No | Daily step count (0-100000) |
| `heart_rate` | integer | 3 digits | ❌ No | Heart rate in BPM (40-200) |
| `sleep_hours` | float | 4.2 format | ❌ No | Sleep duration (0.00-24.00) |
| `calories_burned` | integer | 5 digits | ❌ No | Calories burned (0-10000) |
| `distance` | float | 6.2 format | ❌ No | Distance in km (0.00-1000.00) |
| `active_minutes` | integer | 4 digits | ❌ No | Active minutes (0-1440) |
| `water_intake` | integer | 5 digits | ❌ No | Water intake in ml (0-10000) |
| `date` | date | YYYY-MM-DD | ❌ No | Metric date (defaults to today) |

#### Sample Request
```json
{
  "user_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "steps": 8500,
  "heart_rate": 72,
  "sleep_hours": 7.5,
  "calories_burned": 2200,
  "distance": 6.5,
  "active_minutes": 45,
  "water_intake": 2500,
  "date": "2025-09-16"
}
```

#### Sample Response (Success - 201)
```json
{
  "id": "d4e5f6g7-h8i9-0123-defg-456789012345",
  "user_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "steps": 8500,
  "heart_rate": 72,
  "sleep_hours": 7.5,
  "calories_burned": 2200,
  "distance": 6.5,
  "active_minutes": 45,
  "water_intake": 2500,
  "date": "2025-09-16",
  "created_at": "2025-09-16T14:30:00.000Z"
}
```

---

### 10. Get Health Metrics

| Field | Value |
|-------|-------|
| **URL** | `GET /rest/v1/health_metrics?user_id=eq.{user_id}&order=date.desc&limit=1` |
| **Method** | GET |
| **Authentication** | Bearer Token Required |
| **Rate Limit** | 100 requests/minute |

#### Request Parameters

| Field Name | Data Type | Size | Mandatory | Description |
|------------|-----------|------|-----------|-------------|
| `user_id` | UUID | 36 chars | ✅ Yes | User's unique identifier |
| `date` | date | YYYY-MM-DD | ❌ No | Specific date filter |

#### Sample Response (Success - 200)
```json
{
  "id": "d4e5f6g7-h8i9-0123-defg-456789012345",
  "steps": 8500,
  "heart_rate": 72,
  "sleep_hours": 7.5,
  "calories_burned": 2200,
  "distance": 6.5,
  "active_minutes": 45,
  "water_intake": 2500,
  "date": "2025-09-16",
  "created_at": "2025-09-16T14:30:00.000Z"
}
```

---

### 11. Get Health Metrics History

| Field | Value |
|-------|-------|
| **URL** | `GET /rest/v1/health_metrics?user_id=eq.{user_id}&date=gte.{start_date}&order=date.desc` |
| **Method** | GET |
| **Authentication** | Bearer Token Required |
| **Rate Limit** | 50 requests/minute |

#### Request Parameters

| Field Name | Data Type | Size | Mandatory | Description |
|------------|-----------|------|-----------|-------------|
| `user_id` | UUID | 36 chars | ✅ Yes | User's unique identifier |
| `days` | integer | 3 digits | ❌ No | Number of days to retrieve (1-365) |
| `start_date` | date | YYYY-MM-DD | ❌ No | Start date for history |
| `end_date` | date | YYYY-MM-DD | ❌ No | End date for history |

#### Sample Response (Success - 200)
```json
[
  {
    "date": "2025-09-16",
    "steps": 8500,
    "heart_rate": 72,
    "sleep_hours": 7.5,
    "calories_burned": 2200,
    "distance": 6.5,
    "active_minutes": 45,
    "water_intake": 2500
  },
  {
    "date": "2025-09-15",
    "steps": 9200,
    "heart_rate": 75,
    "sleep_hours": 8.0,
    "calories_burned": 2350,
    "distance": 7.2,
    "active_minutes": 52,
    "water_intake": 2800
  }
]
```

---

## 🔥 Streaks APIs

### 12. Update Streak

| Field | Value |
|-------|-------|
| **URL** | `POST /rest/v1/streaks` |
| **Method** | POST |
| **Authentication** | Bearer Token Required |
| **Rate Limit** | 50 requests/minute |

#### Request Parameters

| Field Name | Data Type | Size | Mandatory | Description |
|------------|-----------|------|-----------|-------------|
| `user_id` | UUID | 36 chars | ✅ Yes | User's unique identifier |
| `current_streak` | integer | 4 digits | ✅ Yes | Current active streak (0-9999) |
| `longest_streak` | integer | 4 digits | ✅ Yes | Longest streak achieved |
| `last_activity_date` | timestamp | ISO 8601 | ✅ Yes | Last activity timestamp |
| `target_achieved` | boolean | 1 bit | ✅ Yes | Whether today's target was achieved |
| `streak_type` | string | 20 chars | ❌ No | Type of streak (daily_goals, nutrition, exercise) |

#### Sample Request
```json
{
  "user_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "current_streak": 15,
  "longest_streak": 45,
  "last_activity_date": "2025-09-16T14:30:00.000Z",
  "target_achieved": true,
  "streak_type": "daily_goals"
}
```

#### Sample Response (Success - 201)
```json
{
  "id": "e5f6g7h8-i9j0-1234-efgh-567890123456",
  "user_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "current_streak": 15,
  "longest_streak": 45,
  "last_activity_date": "2025-09-16T14:30:00.000Z",
  "target_achieved": true,
  "streak_type": "daily_goals",
  "created_at": "2025-09-16T14:30:00.000Z",
  "updated_at": "2025-09-16T14:30:00.000Z"
}
```

---

### 13. Get Streak

| Field | Value |
|-------|-------|
| **URL** | `GET /rest/v1/streaks?user_id=eq.{user_id}&select=*` |
| **Method** | GET |
| **Authentication** | Bearer Token Required |
| **Rate Limit** | 100 requests/minute |

#### Request Parameters

| Field Name | Data Type | Size | Mandatory | Description |
|------------|-----------|------|-----------|-------------|
| `user_id` | UUID | 36 chars | ✅ Yes | User's unique identifier |
| `streak_type` | string | 20 chars | ❌ No | Filter by streak type |

#### Sample Response (Success - 200)
```json
{
  "id": "e5f6g7h8-i9j0-1234-efgh-567890123456",
  "current_streak": 15,
  "longest_streak": 45,
  "last_activity_date": "2025-09-16T14:30:00.000Z",
  "target_achieved": true,
  "streak_type": "daily_goals",
  "created_at": "2025-09-10T10:00:00.000Z",
  "updated_at": "2025-09-16T14:30:00.000Z"
}
```

---

## 🎯 Goals APIs

### 14. Set User Goal

| Field | Value |
|-------|-------|
| **URL** | `POST /rest/v1/user_goals` |
| **Method** | POST |
| **Authentication** | Bearer Token Required |
| **Rate Limit** | 50 requests/minute |

#### Request Parameters

| Field Name | Data Type | Size | Mandatory | Description |
|------------|-----------|------|-----------|-------------|
| `user_id` | UUID | 36 chars | ✅ Yes | User's unique identifier |
| `goal_type` | string | 50 chars | ✅ Yes | Type of goal (daily_steps, daily_calories, etc.) |
| `target_value` | integer | 6 digits | ✅ Yes | Target value for the goal |
| `unit` | string | 20 chars | ✅ Yes | Unit of measurement |
| `is_active` | boolean | 1 bit | ❌ No | Whether goal is active (default: true) |
| `start_date` | date | YYYY-MM-DD | ❌ No | Goal start date |
| `end_date` | date | YYYY-MM-DD | ❌ No | Goal end date |

#### Sample Request
```json
{
  "user_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "goal_type": "daily_steps",
  "target_value": 10000,
  "unit": "steps",
  "is_active": true,
  "start_date": "2025-09-16"
}
```

#### Sample Response (Success - 201)
```json
{
  "id": "f6g7h8i9-j0k1-2345-fghi-678901234567",
  "user_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "goal_type": "daily_steps",
  "target_value": 10000,
  "current_value": 0,
  "unit": "steps",
  "is_active": true,
  "start_date": "2025-09-16",
  "created_at": "2025-09-16T15:00:00.000Z"
}
```

---

### 15. Update Goal Progress

| Field | Value |
|-------|-------|
| **URL** | `PATCH /rest/v1/user_goals?user_id=eq.{user_id}&goal_type=eq.{goal_type}` |
| **Method** | PATCH |
| **Authentication** | Bearer Token Required |
| **Rate Limit** | 100 requests/minute |

#### Request Parameters

| Field Name | Data Type | Size | Mandatory | Description |
|------------|-----------|------|-----------|-------------|
| `current_value` | integer | 6 digits | ✅ Yes | Current progress value |
| `last_updated` | timestamp | ISO 8601 | ❌ No | Last update timestamp |

#### Sample Request
```json
{
  "current_value": 7500,
  "last_updated": "2025-09-16T15:30:00.000Z"
}
```

#### Sample Response (Success - 200)
```json
{
  "id": "f6g7h8i9-j0k1-2345-fghi-678901234567",
  "goal_type": "daily_steps",
  "target_value": 10000,
  "current_value": 7500,
  "unit": "steps",
  "progress_percentage": 75.0,
  "is_achieved": false,
  "updated_at": "2025-09-16T15:30:00.000Z"
}
```

---

### 16. Get User Goals

| Field | Value |
|-------|-------|
| **URL** | `GET /rest/v1/user_goals?user_id=eq.{user_id}&is_active=eq.true&select=*` |
| **Method** | GET |
| **Authentication** | Bearer Token Required |
| **Rate Limit** | 100 requests/minute |

#### Request Parameters

| Field Name | Data Type | Size | Mandatory | Description |
|------------|-----------|------|-----------|-------------|
| `user_id` | UUID | 36 chars | ✅ Yes | User's unique identifier |
| `is_active` | boolean | 1 bit | ❌ No | Filter by active status |
| `goal_type` | string | 50 chars | ❌ No | Filter by goal type |

#### Sample Response (Success - 200)
```json
[
  {
    "id": "f6g7h8i9-j0k1-2345-fghi-678901234567",
    "goal_type": "daily_steps",
    "target_value": 10000,
    "current_value": 7500,
    "unit": "steps",
    "progress_percentage": 75.0,
    "is_achieved": false,
    "is_active": true,
    "created_at": "2025-09-16T15:00:00.000Z",
    "updated_at": "2025-09-16T15:30:00.000Z"
  },
  {
    "id": "g7h8i9j0-k1l2-3456-ghij-789012345678",
    "goal_type": "daily_calories",
    "target_value": 2000,
    "current_value": 1850,
    "unit": "calories",
    "progress_percentage": 92.5,
    "is_achieved": false,
    "is_active": true,
    "created_at": "2025-09-16T15:00:00.000Z",
    "updated_at": "2025-09-16T16:00:00.000Z"
  }
]
```

---

## 📊 Dashboard APIs

### 17. Get User Dashboard

| Field | Value |
|-------|-------|
| **URL** | `GET /rest/v1/rpc/get_user_dashboard` |
| **Method** | GET |
| **Authentication** | Bearer Token Required |
| **Rate Limit** | 20 requests/minute |

#### Request Parameters

| Field Name | Data Type | Size | Mandatory | Description |
|------------|-----------|------|-----------|-------------|
| `user_id` | UUID | 36 chars | ✅ Yes | User's unique identifier |
| `date` | date | YYYY-MM-DD | ❌ No | Date for dashboard data |

#### Sample Response (Success - 200)
```json
{
  "user_profile": {
    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "name": "John Doe",
    "age": 28,
    "fitness_goal": "build_muscle"
  },
  "today_metrics": {
    "steps": 7500,
    "calories_consumed": 1850,
    "calories_burned": 2200,
    "water_intake": 2500,
    "active_minutes": 45,
    "sleep_hours": 7.5
  },
  "nutrition_summary": {
    "total_calories": 1850,
    "total_protein": 125.5,
    "total_carbs": 180.2,
    "total_fat": 65.8,
    "meals_logged": 4
  },
  "goals_progress": [
    {
      "goal_type": "daily_steps",
      "target_value": 10000,
      "current_value": 7500,
      "progress_percentage": 75.0,
      "is_achieved": false
    },
    {
      "goal_type": "daily_calories",
      "target_value": 2000,
      "current_value": 1850,
      "progress_percentage": 92.5,
      "is_achieved": false
    }
  ],
  "streaks": {
    "current_streak": 15,
    "longest_streak": 45,
    "target_achieved": true
  },
  "weekly_trends": {
    "avg_steps": 8200,
    "avg_calories": 1950,
    "workout_days": 5,
    "streak_consistency": 85.7
  }
}
```

---

## 📋 Data Models

### User Profile Model
```json
{
  "id": "UUID (Primary Key)",
  "email": "string (320 chars, unique)",
  "name": "string (100 chars)",
  "age": "integer (13-120)",
  "height": "float (100.0-300.0)",
  "weight": "float (30.0-300.0)",
  "activity_level": "enum (sedentary, lightly_active, moderately_active, very_active)",
  "fitness_goal": "enum (lose_weight, maintain_weight, build_muscle, improve_fitness)",
  "daily_calories_target": "integer (1000-5000)",
  "created_at": "timestamp",
  "updated_at": "timestamp"
}
```

### Nutrition Entry Model
```json
{
  "id": "UUID (Primary Key)",
  "user_id": "UUID (Foreign Key)",
  "food_name": "string (200 chars)",
  "calories": "integer (1-9999)",
  "protein": "float (0.00-999.99)",
  "carbs": "float (0.00-999.99)",
  "fat": "float (0.00-999.99)",
  "fiber": "float (0.00-999.99)",
  "meal_type": "enum (breakfast, lunch, dinner, snack)",
  "food_source": "string (50 chars)",
  "serving_size": "float (0.00-9999.99)",
  "created_at": "timestamp"
}
```

### Health Metrics Model
```json
{
  "id": "UUID (Primary Key)",
  "user_id": "UUID (Foreign Key)",
  "steps": "integer (0-100000)",
  "heart_rate": "integer (40-200)",
  "sleep_hours": "float (0.00-24.00)",
  "calories_burned": "integer (0-10000)",
  "distance": "float (0.00-1000.00)",
  "active_minutes": "integer (0-1440)",
  "water_intake": "integer (0-10000)",
  "date": "date",
  "created_at": "timestamp"
}
```

### Streaks Model
```json
{
  "id": "UUID (Primary Key)",
  "user_id": "UUID (Foreign Key)",
  "current_streak": "integer (0-9999)",
  "longest_streak": "integer (0-9999)",
  "last_activity_date": "timestamp",
  "target_achieved": "boolean",
  "streak_type": "string (20 chars)",
  "created_at": "timestamp",
  "updated_at": "timestamp"
}
```

### User Goals Model
```json
{
  "id": "UUID (Primary Key)",
  "user_id": "UUID (Foreign Key)",
  "goal_type": "string (50 chars)",
  "target_value": "integer (0-999999)",
  "current_value": "integer (0-999999)",
  "unit": "string (20 chars)",
  "is_active": "boolean",
  "is_achieved": "boolean",
  "start_date": "date",
  "end_date": "date",
  "created_at": "timestamp",
  "updated_at": "timestamp"
}
```

---

## ⚠️ Error Handling

### HTTP Status Codes

| Status Code | Description | Common Causes |
|-------------|-------------|---------------|
| **200** | Success | Request completed successfully |
| **201** | Created | Resource created successfully |
| **400** | Bad Request | Invalid request parameters |
| **401** | Unauthorized | Missing or invalid authentication |
| **403** | Forbidden | Insufficient permissions |
| **404** | Not Found | Resource doesn't exist |
| **422** | Unprocessable Entity | Validation errors |
| **429** | Too Many Requests | Rate limit exceeded |
| **500** | Internal Server Error | Server-side errors |

### Error Response Format
```json
{
  "error": {
    "message": "Descriptive error message",
    "code": "ERROR_CODE",
    "details": "Additional error details",
    "hint": "Suggestion for resolution"
  }
}
```

### Common Error Examples

#### Authentication Error (401)
```json
{
  "error": {
    "message": "Invalid JWT token",
    "code": "invalid_token",
    "details": "Token has expired",
    "hint": "Please refresh your authentication token"
  }
}
```

#### Validation Error (422)
```json
{
  "error": {
    "message": "Validation failed",
    "code": "validation_error",
    "details": "Heart rate must be between 40 and 200 BPM",
    "hint": "Check the heart_rate field value"
  }
}
```

#### Rate Limit Error (429)
```json
{
  "error": {
    "message": "Too many requests",
    "code": "rate_limit_exceeded",
    "details": "Maximum 100 requests per minute exceeded",
    "hint": "Please wait before making additional requests"
  }
}
```

---

## 🔧 Testing & Development

### Testing Endpoints
- **Base URL**: `https://your-project.supabase.co`
- **Test User Credentials**: Available through app registration
- **API Key**: Available in Supabase dashboard

### Rate Limits
- **Authentication**: 20 requests/minute
- **Profile Operations**: 50 requests/minute
- **Nutrition Operations**: 200 requests/minute
- **Health Metrics**: 100 requests/minute
- **Goals & Streaks**: 50 requests/minute
- **Dashboard**: 20 requests/minute

### SDKs & Libraries
- **Flutter/Dart**: `supabase_flutter`
- **JavaScript**: `@supabase/supabase-js`
- **Python**: `supabase-py`
- **Go**: `supabase-go`

---

*API Documentation v1.0 - Last Updated: 2025-09-16*