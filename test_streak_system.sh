#!/bin/bash

# Comprehensive Streak System Test Suite
# Run this after deploying the migration

SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6d3Zja3ppYXZoem1naGl6eXF4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1ODA5OTQ2MiwiZXhwIjoyMDczNjc1NDYyfQ.jXjRDeSc1e3RLQVIxZwNRgYwF-nXmHf4icvnjllW-ao"
API_URL="https://xzwvckziavhzmghizyqx.supabase.co/rest/v1"
USER_ID="5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9"

echo "🧪 COMPREHENSIVE STREAK SYSTEM TEST"
echo "===================================="
echo ""

# Test 1: Check current streak status
echo "Test 1: Current Streak Status"
echo "------------------------------"
curl -s -X GET "$API_URL/streaks?user_id=eq.$USER_ID&streak_type=eq.daily" \
  -H "apikey: $SERVICE_KEY" \
  -H "Authorization: Bearer $SERVICE_KEY" | python3 -m json.tool | grep -E "current_streak|grace_days|last_completed_date"

echo ""

# Test 2: Check today's health metrics
echo "Test 2: Today's Health Metrics"
echo "-------------------------------"
TODAY=$(date +%Y-%m-%d)
curl -s -X GET "$API_URL/health_metrics?user_id=eq.$USER_ID&date=eq.$TODAY" \
  -H "apikey: $SERVICE_KEY" \
  -H "Authorization: Bearer $SERVICE_KEY" | python3 -m json.tool | grep -E "all_goals_achieved|steps_achieved|calories_achieved"

echo ""

# Test 3: Run sync for today
echo "Test 3: Running Sync for Today"
echo "-------------------------------"
curl -s -X POST "$API_URL/rpc/sync_user_daily_data" \
  -H "apikey: $SERVICE_KEY" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"p_user_id\":\"$USER_ID\",\"p_date\":\"$TODAY\"}" | python3 -m json.tool | grep -E "current_streak|all_goals_achieved"

echo ""

# Test 4: Check streak history
echo "Test 4: Recent Streak History"
echo "------------------------------"
curl -s -X GET "$API_URL/streak_history?user_id=eq.$USER_ID&order=date.desc&limit=5" \
  -H "apikey: $SERVICE_KEY" \
  -H "Authorization: Bearer $SERVICE_KEY" | python3 -m json.tool

echo ""

# Test 5: Test grace period (simulate missed day)
echo "Test 5: Testing Grace Period Logic"
echo "-----------------------------------"
echo "Simulating a day with missed goals..."

# Create a test entry for yesterday with failed goals
YESTERDAY=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "yesterday" +%Y-%m-%d)
curl -s -X POST "$API_URL/health_metrics" \
  -H "apikey: $SERVICE_KEY" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "{
    \"user_id\":\"$USER_ID\",
    \"date\":\"$YESTERDAY\",
    \"steps\":5000,
    \"steps_goal\":10000,
    \"calories_consumed\":1500,
    \"calories_goal\":2000,
    \"sleep_hours\":6,
    \"sleep_goal\":8,
    \"all_goals_achieved\":false
  }" | python3 -m json.tool | grep -E "all_goals_achieved"

# Trigger streak update
curl -s -X POST "$API_URL/rpc/update_user_streak" \
  -H "apikey: $SERVICE_KEY" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"p_user_id\":\"$USER_ID\",\"p_date\":\"$YESTERDAY\"}" 2>/dev/null

# Check if grace period was used
echo "Checking if grace period was applied..."
curl -s -X GET "$API_URL/streaks?user_id=eq.$USER_ID&streak_type=eq.daily" \
  -H "apikey: $SERVICE_KEY" \
  -H "Authorization: Bearer $SERVICE_KEY" | python3 -m json.tool | grep -E "current_streak|grace_days_used"

echo ""

# Test 6: Check calorie threshold (150%)
echo "Test 6: Testing New Calorie Threshold"
echo "--------------------------------------"
echo "Setting calories to 2900 (145% of 2000 goal - should PASS)..."

TEST_DATE=$(date +%Y-%m-%d)
curl -s -X PATCH "$API_URL/health_metrics?user_id=eq.$USER_ID&date=eq.$TEST_DATE" \
  -H "apikey: $SERVICE_KEY" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "{
    \"calories_consumed\":2900,
    \"calories_goal\":2000
  }" | python3 -m json.tool | grep -E "calories_achieved"

echo ""

# Test 7: Test 4/5 goals requirement
echo "Test 7: Testing 4/5 Goals Requirement"
echo "--------------------------------------"
echo "Setting 4 goals achieved (missing water)..."

curl -s -X PATCH "$API_URL/health_metrics?user_id=eq.$USER_ID&date=eq.$TEST_DATE" \
  -H "apikey: $SERVICE_KEY" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "{
    \"steps\":10000,
    \"calories_consumed\":2000,
    \"sleep_hours\":8,
    \"water_glasses\":0,
    \"water_goal\":8
  }" | python3 -m json.tool | grep -E "all_goals_achieved|water_achieved"

echo ""

# Test 8: Run daily check function
echo "Test 8: Testing Daily Check Function"
echo "-------------------------------------"
curl -s -X POST "$API_URL/rpc/check_all_user_streaks" \
  -H "apikey: $SERVICE_KEY" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d "{}" 2>/dev/null && echo "Daily check completed"

echo ""

echo "✅ All tests completed!"
echo ""
echo "📊 Final Status:"
echo "----------------"
curl -s -X GET "$API_URL/streak_status?user_id=eq.$USER_ID" \
  -H "apikey: $SERVICE_KEY" \
  -H "Authorization: Bearer $SERVICE_KEY" | python3 -m json.tool

echo ""
echo "🎉 Test suite finished!"