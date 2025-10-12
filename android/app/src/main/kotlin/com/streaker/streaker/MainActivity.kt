package com.streaker.streaker

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.*
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZonedDateTime
import java.time.temporal.ChronoUnit
import android.content.Context
import androidx.work.WorkManager
import java.io.File
import java.io.FileWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import org.json.JSONObject
import org.json.JSONArray
import android.os.Build
import android.provider.Settings
import android.net.Uri
import android.content.ActivityNotFoundException

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.streaker/health_connect"
    private val TAG = "HealthConnect"
    
    private lateinit var healthConnectClient: HealthConnectClient
    private lateinit var methodChannel: MethodChannel
    
    // Define the permissions we need - including Samsung Health specific data types
    private val permissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
        HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class), // Samsung Health uses total calories
        HealthPermission.getReadPermission(DistanceRecord::class),
        HealthPermission.getReadPermission(SleepSessionRecord::class),
        HealthPermission.getReadPermission(HydrationRecord::class),
        HealthPermission.getReadPermission(WeightRecord::class),
        HealthPermission.getReadPermission(OxygenSaturationRecord::class),
        HealthPermission.getReadPermission(BloodPressureRecord::class),
        HealthPermission.getReadPermission(ExerciseSessionRecord::class),
        HealthPermission.getReadPermission(RestingHeartRateRecord::class) // Samsung Health resting heart rate
    )
    
    // Permission request code
    private val PERMISSION_REQUEST_CODE = 1001
    private val coroutineScope = CoroutineScope(Dispatchers.Main)
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize Health Connect client with availability check
        try {
            val providerPackageName = "com.google.android.apps.healthdata"
            val sdkStatus = HealthConnectClient.getSdkStatus(this, providerPackageName)

            when (sdkStatus) {
                HealthConnectClient.SDK_AVAILABLE -> {
                    healthConnectClient = HealthConnectClient.getOrCreate(this, providerPackageName)
                    Log.d(TAG, "Health Connect client initialized successfully")
                }
                HealthConnectClient.SDK_UNAVAILABLE -> {
                    Log.w(TAG, "Health Connect not installed - app will function with limited health features")
                }
                HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> {
                    Log.w(TAG, "Health Connect update required - app will function with limited health features")
                }
                else -> {
                    Log.w(TAG, "Health Connect status unknown: $sdkStatus - app will function with limited health features")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize Health Connect - app will function with limited health features", e)
            // App continues without Health Connect - graceful degradation
        }
    }

    // Helper method to check if Health Connect client is initialized
    private fun isHealthConnectAvailable(): Boolean {
        return ::healthConnectClient.isInitialized
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkAvailability" -> checkAvailability(result)
                "requestPermissions" -> requestPermissions(result)
                "checkPermissions" -> checkPermissions(result)
                "readSteps" -> readSteps(result)
                "readHeartRate" -> readHeartRate(result)
                "readCalories" -> readCalories(result)
                "readDistance" -> readDistance(result)
                "readAllData" -> readAllHealthData(result)
                "startBackgroundSync" -> startBackgroundSync(result)
                "stopBackgroundSync" -> stopBackgroundSync(result)
                "getLastSyncInfo" -> getLastSyncInfo(result)
                "captureHealthDataLogs" -> captureHealthDataLogs(result)
                "syncUserProfile" -> {
                    val age = call.argument<Int>("age") ?: 30
                    val gender = call.argument<String>("gender") ?: "male"
                    val height = call.argument<Double>("height") ?: 170.0
                    val weight = call.argument<Double>("weight") ?: 70.0
                    syncUserProfile(age, gender, height, weight, result)
                }
                "openHealthConnectSettings" -> openHealthConnectSettings(result)
                "getDeviceInfo" -> getDeviceInfo(result)
                else -> result.notImplemented()
            }
        }
    }
    
    private fun checkAvailability(result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                val availability = HealthConnectClient.getSdkStatus(this@MainActivity, "com.google.android.apps.healthdata")
                Log.d(TAG, "Health Connect SDK status: $availability")
                
                when (availability) {
                    HealthConnectClient.SDK_AVAILABLE -> {
                        result.success(mapOf(
                            "available" to true,
                            "status" to "available"
                        ))
                    }
                    HealthConnectClient.SDK_UNAVAILABLE -> {
                        result.success(mapOf(
                            "available" to false,
                            "status" to "not_installed"
                        ))
                    }
                    HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> {
                        result.success(mapOf(
                            "available" to false,
                            "status" to "update_required"
                        ))
                    }
                    else -> {
                        result.success(mapOf(
                            "available" to false,
                            "status" to "unknown"
                        ))
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error checking availability", e)
                result.error("AVAILABILITY_ERROR", e.message, null)
            }
        }
    }
    
    private fun requestPermissions(result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                if (!isHealthConnectAvailable()) {
                    Log.w(TAG, "Health Connect not available - cannot request permissions")
                    result.error("UNAVAILABLE", "Health Connect is not available on this device", null)
                    return@launch
                }

                Log.d(TAG, "=== REQUESTING HEALTH PERMISSIONS ===")
                Log.d(TAG, "Requesting permissions for ${permissions.size} data types:")
                permissions.forEachIndexed { index, permission ->
                    Log.d(TAG, "  ${index + 1}. $permission")
                }

                // Check which permissions are already granted
                val granted = healthConnectClient.permissionController.getGrantedPermissions()
                Log.d(TAG, "Already granted: ${granted.size} permissions")
                if (granted.isNotEmpty()) {
                    Log.d(TAG, "Granted permissions:")
                    granted.forEach { permission ->
                        Log.d(TAG, "  ✅ $permission")
                    }
                }
                
                val notGranted = permissions - granted
                if (notGranted.isNotEmpty()) {
                    Log.d(TAG, "Need to request ${notGranted.size} additional permissions:")
                    notGranted.forEach { permission ->
                        Log.d(TAG, "  ❌ $permission")
                    }
                    
                    // Request ALL permissions (including already granted ones for completeness)
                    val contract = PermissionController.createRequestPermissionResultContract()
                    val intent = contract.createIntent(this@MainActivity, permissions)
                    startActivityForResult(intent, PERMISSION_REQUEST_CODE)
                    
                    Log.d(TAG, "Permission dialog launched - waiting for user response...")
                } else {
                    Log.d(TAG, "All permissions already granted!")
                    result.success(mapOf(
                        "status" to "already_granted",
                        "granted" to true,
                        "grantedCount" to granted.size,
                        "requiredCount" to permissions.size
                    ))
                    return@launch
                }
                
                // Return immediately, result will be handled in onActivityResult
                result.success(mapOf(
                    "status" to "requesting",
                    "message" to "Permission dialog opened - grant access to: Steps, Heart Rate, Calories, Distance, Sleep, Water, Weight, Blood Oxygen, Blood Pressure, Exercise sessions"
                ))
            } catch (e: Exception) {
                Log.e(TAG, "Error requesting permissions", e)
                result.error("PERMISSION_ERROR", e.message, null)
            }
        }
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == PERMISSION_REQUEST_CODE) {
            Log.d(TAG, "Permission request result: $resultCode")
            coroutineScope.launch {
                checkPermissionsAndRespond()
            }
        }
    }
    
    private fun checkPermissions(result: MethodChannel.Result) {
        coroutineScope.launch {
            checkPermissionsAndRespond(result)
        }
    }
    
    private suspend fun checkPermissionsAndRespond(result: MethodChannel.Result? = null) {
        try {
            if (!isHealthConnectAvailable()) {
                Log.w(TAG, "Health Connect not available - cannot check permissions")
                result?.error("UNAVAILABLE", "Health Connect is not available on this device", null)
                return
            }

            val granted = healthConnectClient.permissionController.getGrantedPermissions()
            Log.d(TAG, "=== PERMISSION STATUS CHECK ===")
            Log.d(TAG, "Granted permissions: ${granted.size} out of ${permissions.size}")
            
            val allGranted = granted.containsAll(permissions)
            val missingPermissions = permissions - granted
            
            // Log granted permissions
            if (granted.isNotEmpty()) {
                Log.d(TAG, "✅ Granted permissions:")
                granted.forEach { permission ->
                    Log.d(TAG, "   $permission")
                }
            }
            
            // Log missing permissions
            if (missingPermissions.isNotEmpty()) {
                Log.w(TAG, "❌ Missing permissions:")
                missingPermissions.forEach { permission ->
                    Log.w(TAG, "   $permission")
                }
                Log.w(TAG, "USER ACTION REQUIRED: Please grant all health permissions in Health Connect")
            } else {
                Log.i(TAG, "🎉 All permissions granted! Health data access is ready.")
            }
            
            val response = mapOf(
                "granted" to allGranted,
                "grantedCount" to granted.size,
                "requiredCount" to permissions.size,
                "grantedPermissions" to granted.map { it.toString() },
                "missingPermissions" to missingPermissions.map { it.toString() },
                "message" to if (allGranted) {
                    "All health permissions granted! Ready to sync health data."
                } else {
                    "Missing ${missingPermissions.size} permissions. Please grant access to: ${missingPermissions.joinToString(", ") { it.toString().substringAfterLast(".") }}"
                }
            )
            
            if (result != null) {
                result.success(response)
            } else {
                // Send update to Flutter via event channel or method channel
                methodChannel.invokeMethod("onPermissionsChecked", response)
            }
            
            Log.d(TAG, "Permission check complete: ${if (allGranted) "SUCCESS" else "INCOMPLETE"}")
        } catch (e: Exception) {
            Log.e(TAG, "Error checking permissions", e)
            result?.error("CHECK_ERROR", e.message, null)
        }
    }
    
    private fun readSteps(result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                val now = Instant.now()
                val startOfDay = ZonedDateTime.now().truncatedTo(ChronoUnit.DAYS).toInstant()
                
                Log.d(TAG, "Reading steps from $startOfDay to $now")
                
                val response = healthConnectClient.readRecords(
                    ReadRecordsRequest(
                        StepsRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(startOfDay, now)
                    )
                )
                
                // Separate steps by source to avoid double-counting
                var samsungSteps = 0L
                var googleFitSteps = 0L
                var otherSteps = 0L
                val stepDetails = mutableListOf<Map<String, Any>>()
                
                response.records.forEach { record ->
                    val source = record.metadata.dataOrigin.packageName
                    Log.d(TAG, "Steps record: ${record.count} steps from ${source}")
                    Log.d(TAG, "  Time: ${record.startTime} to ${record.endTime}")
                    
                    val detail = mapOf(
                        "count" to record.count,
                        "startTime" to record.startTime.toString(),
                        "endTime" to record.endTime.toString(),
                        "source" to source
                    )
                    
                    // Categorize by source
                    when {
                        source.contains("shealth") || 
                        source.contains("com.sec.android") || 
                        source.contains("samsung") || 
                        source.contains("gear") -> {
                            samsungSteps += record.count
                            stepDetails.add(detail)
                        }
                        source.contains("google.android.apps.fitness") -> {
                            googleFitSteps += record.count
                            if (samsungSteps == 0L) stepDetails.add(detail) // Only add if no Samsung data
                        }
                        else -> {
                            otherSteps += record.count
                            if (samsungSteps == 0L && googleFitSteps == 0L) stepDetails.add(detail)
                        }
                    }
                }
                
                // PRIORITY: Use Samsung Health data if available, otherwise fall back to Google Fit
                val finalSteps = when {
                    samsungSteps > 0 -> {
                        Log.d(TAG, "Using Samsung Health data: $samsungSteps steps (ignoring Google Fit: $googleFitSteps)")
                        samsungSteps
                    }
                    googleFitSteps > 0 -> {
                        Log.d(TAG, "No Samsung Health data, using Google Fit: $googleFitSteps steps")
                        googleFitSteps
                    }
                    else -> {
                        Log.d(TAG, "Using other sources: $otherSteps steps")
                        otherSteps
                    }
                }
                
                Log.d(TAG, "FINAL steps (prioritizing Samsung): $finalSteps from ${response.records.size} records")
                
                val resultData = mapOf(
                    "totalSteps" to finalSteps.toInt(),
                    "recordCount" to response.records.size,
                    "details" to stepDetails,
                    "lastSync" to Instant.now().toString(),
                    "dataSource" to when {
                        samsungSteps > 0 -> "Samsung Health"
                        googleFitSteps > 0 -> "Google Fit"
                        else -> "Other"
                    }
                )
                
                result.success(resultData)
            } catch (e: Exception) {
                Log.e(TAG, "Error reading steps", e)
                result.error("READ_ERROR", e.message, null)
            }
        }
    }
    
    private fun readHeartRate(result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                val now = Instant.now()
                val oneHourAgo = now.minus(1, ChronoUnit.HOURS)
                
                val response = healthConnectClient.readRecords(
                    ReadRecordsRequest(
                        HeartRateRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(oneHourAgo, now)
                    )
                )
                
                if (response.records.isNotEmpty()) {
                    // Get the most recent heart rate
                    val latestRecord = response.records.maxByOrNull { it.endTime }
                    val latestHeartRate = latestRecord?.samples?.lastOrNull()?.beatsPerMinute ?: 0
                    
                    Log.d(TAG, "Latest heart rate: $latestHeartRate bpm")
                    result.success(latestHeartRate.toInt())
                } else {
                    result.success(0)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error reading heart rate", e)
                result.error("READ_ERROR", e.message, null)
            }
        }
    }
    
    private fun readCalories(result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                val now = Instant.now()
                val startOfDay = ZonedDateTime.now().truncatedTo(ChronoUnit.DAYS).toInstant()
                
                val response = healthConnectClient.readRecords(
                    ReadRecordsRequest(
                        ActiveCaloriesBurnedRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(startOfDay, now)
                    )
                )
                
                var totalCalories = 0.0
                response.records.forEach { record ->
                    totalCalories += record.energy.inKilocalories
                }
                
                Log.d(TAG, "Total calories burned: $totalCalories kcal")
                result.success(totalCalories.toInt())
            } catch (e: Exception) {
                Log.e(TAG, "Error reading calories", e)
                result.error("READ_ERROR", e.message, null)
            }
        }
    }
    
    private fun readDistance(result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                val now = Instant.now()
                val startOfDay = ZonedDateTime.now().truncatedTo(ChronoUnit.DAYS).toInstant()
                
                val response = healthConnectClient.readRecords(
                    ReadRecordsRequest(
                        DistanceRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(startOfDay, now)
                    )
                )
                
                var totalDistance = 0.0
                response.records.forEach { record ->
                    totalDistance += record.distance.inKilometers
                }
                
                Log.d(TAG, "Total distance: $totalDistance km")
                result.success(totalDistance)
            } catch (e: Exception) {
                Log.e(TAG, "Error reading distance", e)
                result.error("READ_ERROR", e.message, null)
            }
        }
    }
    
    private fun readAllHealthData(result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                if (!isHealthConnectAvailable()) {
                    Log.w(TAG, "Health Connect not available - returning empty health data")
                    result.success(mapOf(
                        "steps" to 0,
                        "calories" to 0,
                        "distance" to 0.0,
                        "heartRate" to 0,
                        "sleep" to 0.0
                    ))
                    return@launch
                }

                val now = Instant.now()
                val startOfDay = ZonedDateTime.now().truncatedTo(ChronoUnit.DAYS).toInstant()

                Log.d(TAG, "=== Fetching all health data ===")
                Log.d(TAG, "Time range: $startOfDay to $now")
                
                val healthData = mutableMapOf<String, Any>()
                val dataSources = mutableSetOf<String>()
                val stepDetails = mutableListOf<Map<String, Any>>()
                
                // Read steps with detailed source tracking
                try {
                    val stepsResponse = healthConnectClient.readRecords(
                        ReadRecordsRequest(
                            StepsRecord::class,
                            timeRangeFilter = TimeRangeFilter.between(startOfDay, now)
                        )
                    )
                    
                    // Separate steps by source to avoid double-counting
                    var samsungSteps = 0L
                    var googleFitSteps = 0L
                    var otherSteps = 0L
                    val samsungRecords = mutableListOf<Map<String, Any>>()
                    val googleFitRecords = mutableListOf<Map<String, Any>>()
                    val otherRecords = mutableListOf<Map<String, Any>>()
                    
                    stepsResponse.records.forEach { record ->
                        val source = record.metadata.dataOrigin.packageName
                        dataSources.add(source)
                        
                        Log.d(TAG, "Steps: ${record.count} from ${source}")
                        Log.d(TAG, "  Time: ${record.startTime} to ${record.endTime}")
                        
                        val recordDetail = mapOf(
                            "count" to record.count,
                            "source" to source,
                            "startTime" to record.startTime.toString(),
                            "endTime" to record.endTime.toString()
                        )
                        
                        // Categorize by source - Samsung Health uses com.sec.android.app.shealth
                        when {
                            source.contains("shealth") || 
                            source.contains("com.sec.android") || 
                            source.contains("samsung") || 
                            source.contains("gear") -> {
                                samsungSteps += record.count
                                samsungRecords.add(recordDetail)
                                Log.d(TAG, "  -> Samsung/Galaxy Watch data detected!")
                            }
                            source.contains("google.android.apps.fitness") -> {
                                googleFitSteps += record.count
                                googleFitRecords.add(recordDetail)
                                Log.d(TAG, "  -> Google Fit data")
                            }
                            else -> {
                                otherSteps += record.count
                                otherRecords.add(recordDetail)
                                Log.d(TAG, "  -> Other source")
                            }
                        }
                    }
                    
                    // PRIORITY: Use Samsung Health data if available, otherwise fall back to Google Fit
                    val finalSteps = when {
                        samsungSteps > 0 -> {
                            Log.d(TAG, "Using Samsung Health data: $samsungSteps steps")
                            stepDetails.addAll(samsungRecords)
                            samsungSteps
                        }
                        googleFitSteps > 0 -> {
                            Log.d(TAG, "Samsung Health not available, using Google Fit: $googleFitSteps steps")
                            stepDetails.addAll(googleFitRecords)
                            googleFitSteps
                        }
                        else -> {
                            Log.d(TAG, "Using other sources: $otherSteps steps")
                            stepDetails.addAll(otherRecords)
                            otherSteps
                        }
                    }
                    
                    Log.d(TAG, "=== Step Data Summary ===")
                    Log.d(TAG, "Samsung Health: $samsungSteps steps")
                    Log.d(TAG, "Google Fit: $googleFitSteps steps")
                    Log.d(TAG, "Other sources: $otherSteps steps")
                    Log.d(TAG, "FINAL STEPS (prioritizing Samsung): $finalSteps")
                    
                    healthData["steps"] = finalSteps.toInt()
                    healthData["stepDetails"] = stepDetails
                    healthData["stepsBySource"] = mapOf(
                        "samsung" to samsungSteps.toInt(),
                        "googleFit" to googleFitSteps.toInt(),
                        "other" to otherSteps.toInt(),
                        "dataSource" to when {
                            samsungSteps > 0 -> "Samsung Health"
                            googleFitSteps > 0 -> "Google Fit"
                            else -> "Other"
                        }
                    )
                } catch (e: Exception) {
                    Log.e(TAG, "Error reading steps", e)
                    healthData["steps"] = 0
                }
                
                // Read heart rate - prioritize resting heart rate, then try regular heart rate
                try {
                    var heartRateValue = 0
                    var heartRateType = "none"
                    
                    // First try to get resting heart rate (Samsung Health priority)
                    try {
                        val restingHRResponse = healthConnectClient.readRecords(
                            ReadRecordsRequest(
                                RestingHeartRateRecord::class,
                                timeRangeFilter = TimeRangeFilter.between(startOfDay, now)
                            )
                        )
                        
                        if (restingHRResponse.records.isNotEmpty()) {
                            var samsungRestingHR = 0L
                            var otherRestingHR = 0L
                            
                            restingHRResponse.records.forEach { record ->
                                val source = record.metadata.dataOrigin.packageName
                                val beatsPerMinute = record.beatsPerMinute
                                
                                Log.d(TAG, "Resting HR: $beatsPerMinute bpm from $source")
                                
                                if (source.contains("shealth") || 
                                    source.contains("com.sec.android") || 
                                    source.contains("samsung")) {
                                    samsungRestingHR = beatsPerMinute
                                } else {
                                    otherRestingHR = beatsPerMinute
                                }
                            }
                            
                            if (samsungRestingHR > 0) {
                                heartRateValue = samsungRestingHR.toInt()
                                heartRateType = "samsung_resting"
                                Log.d(TAG, "Using Samsung resting heart rate: $heartRateValue bpm")
                            } else if (otherRestingHR > 0) {
                                heartRateValue = otherRestingHR.toInt()
                                heartRateType = "other_resting"
                            }
                        }
                    } catch (e: Exception) {
                        Log.d(TAG, "Resting heart rate not available, trying regular heart rate", e)
                    }
                    
                    // If no resting heart rate found, try regular heart rate data
                    if (heartRateValue == 0) {
                        val heartRateResponse = healthConnectClient.readRecords(
                            ReadRecordsRequest(
                                HeartRateRecord::class,
                                timeRangeFilter = TimeRangeFilter.between(startOfDay, now)
                            )
                        )
                        
                        if (heartRateResponse.records.isNotEmpty()) {
                            val samsungHeartRates = mutableListOf<Long>()
                            val otherHeartRates = mutableListOf<Long>()
                            
                            heartRateResponse.records.forEach { record ->
                                val source = record.metadata.dataOrigin.packageName
                                val samples = record.samples.map { it.beatsPerMinute }
                                
                                if (source.contains("shealth") || 
                                    source.contains("com.sec.android") || 
                                    source.contains("samsung")) {
                                    samsungHeartRates.addAll(samples)
                                    Log.d(TAG, "Samsung HR samples: ${samples.size} readings")
                                } else {
                                    otherHeartRates.addAll(samples)
                                }
                            }
                            
                            val heartRatesToUse = if (samsungHeartRates.isNotEmpty()) samsungHeartRates else otherHeartRates
                            
                            if (heartRatesToUse.isNotEmpty()) {
                                // For Samsung Health, calculate resting heart rate (lowest 10% of readings)
                                if (samsungHeartRates.isNotEmpty()) {
                                    val sortedRates = samsungHeartRates.sorted()
                                    val tenPercentCount = (sortedRates.size * 0.1).coerceAtLeast(1.0).toInt()
                                    val restingRates = sortedRates.take(tenPercentCount)
                                    heartRateValue = (restingRates.sum() / restingRates.size).toInt()
                                    heartRateType = "samsung_resting_calculated"
                                    Log.d(TAG, "Calculated resting HR from lowest 10% of ${samsungHeartRates.size} readings")
                                } else {
                                    // For non-Samsung, use latest reading
                                    heartRateValue = heartRatesToUse.last().toInt()
                                    heartRateType = "other_latest"
                                }
                                
                                Log.d(TAG, "Heart rate ($heartRateType): $heartRateValue bpm from ${heartRatesToUse.size} samples")
                            }
                        }
                    }
                    
                    healthData["heartRate"] = heartRateValue
                    healthData["heartRateType"] = heartRateType
                    
                } catch (e: Exception) {
                    Log.e(TAG, "Error reading heart rate data", e)
                    healthData["heartRate"] = 0
                    healthData["heartRateType"] = "error"
                }
                
                // ACCURATE CALORIE CALCULATION - Based on reliable data
                try {
                    Log.d(TAG, "Starting accurate calorie calculation...")

                    // Get steps for base activity calculation
                    val steps = healthData["steps"] as? Int ?: 0

                    // 1. Calculate base active calories from steps (0.04 kcal per step)
                    val baseActiveCalories = steps * 0.04
                    Log.d(TAG, "Base active calories from $steps steps: $baseActiveCalories kcal")

                    // 2. Read exercise sessions for gym/workout calories
                    var exerciseCalories = 0.0
                    try {
                        val exerciseResponse = healthConnectClient.readRecords(
                            ReadRecordsRequest(
                                ExerciseSessionRecord::class,
                                timeRangeFilter = TimeRangeFilter.between(startOfDay, now)
                            )
                        )

                        Log.d(TAG, "Found ${exerciseResponse.records.size} exercise sessions today")

                        exerciseResponse.records.forEach { session ->
                            val duration = java.time.Duration.between(session.startTime, session.endTime).toMinutes()
                            val exerciseType = session.exerciseType

                            // Try to get calories from active calories during this session
                            var sessionCalories = 0.0
                            try {
                                val sessionActiveResponse = healthConnectClient.readRecords(
                                    ReadRecordsRequest(
                                        ActiveCaloriesBurnedRecord::class,
                                        timeRangeFilter = TimeRangeFilter.between(session.startTime, session.endTime)
                                    )
                                )

                                sessionCalories = sessionActiveResponse.records.sumOf { it.energy.inKilocalories }
                            } catch (e: Exception) {
                                Log.d(TAG, "No active calories data for session, estimating...")
                            }

                            // If no calories data, estimate based on exercise type and duration
                            if (sessionCalories == 0.0) {
                                sessionCalories = estimateExerciseCalories(exerciseType, duration.toDouble())
                            }

                            // For running/walking, avoid double counting with steps
                            if (exerciseType == ExerciseSessionRecord.EXERCISE_TYPE_RUNNING ||
                                exerciseType == ExerciseSessionRecord.EXERCISE_TYPE_WALKING) {
                                // Get steps during this session
                                val sessionSteps = try {
                                    val stepsResponse = healthConnectClient.readRecords(
                                        ReadRecordsRequest(
                                            StepsRecord::class,
                                            timeRangeFilter = TimeRangeFilter.between(session.startTime, session.endTime)
                                        )
                                    )
                                    stepsResponse.records.sumOf { it.count.toInt() }
                                } catch (e: Exception) {
                                    0
                                }

                                val sessionStepCalories = sessionSteps * 0.04
                                // Use the higher value to avoid double counting
                                sessionCalories = maxOf(sessionCalories, sessionStepCalories)
                            }

                            Log.d(TAG, "Exercise: ${getExerciseTypeName(exerciseType)}, Duration: $duration min, Calories: $sessionCalories kcal")
                            exerciseCalories += sessionCalories
                        }
                    } catch (e: Exception) {
                        Log.d(TAG, "Error reading exercise sessions", e)
                    }

                    // 3. Calculate total active calories (avoiding double counting)
                    val totalActiveCalories = if (exerciseCalories > 0) {
                        // If we have exercise, use the appropriate combination
                        // For running/walking exercises, they already include the step calories
                        // For other exercises (gym, cycling), add to base activity
                        maxOf(baseActiveCalories, exerciseCalories)
                    } else {
                        baseActiveCalories
                    }

                    // 4. Get user profile and calculate BMR
                    val sharedPrefs = getSharedPreferences("user_profile", Context.MODE_PRIVATE)
                    val userAge = sharedPrefs.getInt("age", 30)
                    val userGender = sharedPrefs.getString("gender", "Male") ?: "Male"
                    val userWeight = sharedPrefs.getFloat("weight", 70f).toDouble()
                    val userHeight = sharedPrefs.getFloat("height", 170f).toDouble()

                    // Calculate BMR using Mifflin-St Jeor equation
                    val dailyBMR = if (userGender.lowercase() == "male") {
                        (10 * userWeight) + (6.25 * userHeight) - (5 * userAge) + 5
                    } else {
                        (10 * userWeight) + (6.25 * userHeight) - (5 * userAge) - 161
                    }

                    // Calculate BMR for elapsed time (more accurate than hourly)
                    val minutesSinceMidnight = java.time.Duration.between(startOfDay, now).toMinutes()
                    val bmrPerMinute = dailyBMR / (24.0 * 60.0)
                    val bmrSoFar = bmrPerMinute * minutesSinceMidnight

                    Log.d(TAG, "BMR Calculation: Daily BMR: ${dailyBMR.toInt()} kcal, Minutes elapsed: $minutesSinceMidnight, BMR so far: ${bmrSoFar.toInt()} kcal")

                    // 5. Calculate total daily calories (TDEE)
                    val totalDailyCalories = bmrSoFar + totalActiveCalories

                    // Store the accurate values
                    healthData["activeCalories"] = totalActiveCalories.toInt()
                    healthData["bmrCalories"] = bmrSoFar.toInt()
                    healthData["totalCalories"] = totalDailyCalories.toInt()
                    healthData["exerciseCalories"] = exerciseCalories.toInt()
                    healthData["stepCalories"] = baseActiveCalories.toInt()

                    // For backward compatibility
                    healthData["calories"] = totalActiveCalories.toInt()

                    Log.d(TAG, "=== ACCURATE CALORIE CALCULATION ===")
                    Log.d(TAG, "Steps: $steps → ${baseActiveCalories.toInt()} kcal")
                    Log.d(TAG, "Exercise: ${exerciseCalories.toInt()} kcal")
                    Log.d(TAG, "Total Active: ${totalActiveCalories.toInt()} kcal")
                    Log.d(TAG, "BMR (${(minutesSinceMidnight/60.0).toInt()} hrs): ${bmrSoFar.toInt()} kcal")
                    Log.d(TAG, "TOTAL DAILY: ${totalDailyCalories.toInt()} kcal")
                    Log.d(TAG, "=====================================")

                } catch (e: Exception) {
                    Log.e(TAG, "Error calculating calories", e)
                    // Fallback to simple calculation
                    val steps = healthData["steps"] as? Int ?: 0
                    val simpleActive = steps * 0.04

                    // Get profile for BMR
                    val sharedPrefs = getSharedPreferences("user_profile", Context.MODE_PRIVATE)
                    val userAge = sharedPrefs.getInt("age", 30)
                    val userGender = sharedPrefs.getString("gender", "Male") ?: "Male"
                    val userWeight = sharedPrefs.getFloat("weight", 70f).toDouble()
                    val userHeight = sharedPrefs.getFloat("height", 170f).toDouble()

                    val dailyBMR = if (userGender.lowercase() == "male") {
                        (10 * userWeight) + (6.25 * userHeight) - (5 * userAge) + 5
                    } else {
                        (10 * userWeight) + (6.25 * userHeight) - (5 * userAge) - 161
                    }

                    val minutesSinceMidnight = java.time.Duration.between(startOfDay, now).toMinutes()
                    val bmrSoFar = (dailyBMR / (24.0 * 60.0)) * minutesSinceMidnight

                    healthData["activeCalories"] = simpleActive.toInt()
                    healthData["bmrCalories"] = bmrSoFar.toInt()
                    healthData["totalCalories"] = (bmrSoFar + simpleActive).toInt()
                    healthData["calories"] = simpleActive.toInt()

                    Log.d(TAG, "Fallback calculation - Steps: $steps, Active: ${simpleActive.toInt()}, BMR: ${bmrSoFar.toInt()}, Total: ${(bmrSoFar + simpleActive).toInt()}")
                }
                
                // Read distance with source prioritization - detailed logging for debugging
                try {
                    val distanceResponse = healthConnectClient.readRecords(
                        ReadRecordsRequest(
                            DistanceRecord::class,
                            timeRangeFilter = TimeRangeFilter.between(startOfDay, now)
                        )
                    )
                    
                    var samsungDistance = 0.0
                    var googleFitDistance = 0.0
                    var otherDistance = 0.0
                    val distanceDetails = mutableListOf<Map<String, Any>>()
                    
                    Log.d(TAG, "Found ${distanceResponse.records.size} distance records")
                    
                    distanceResponse.records.forEach { record ->
                        val source = record.metadata.dataOrigin.packageName
                        val distance = record.distance.inKilometers
                        
                        val detail = mapOf(
                            "distance" to distance,
                            "source" to source,
                            "startTime" to record.startTime.toString(),
                            "endTime" to record.endTime.toString()
                        )
                        
                        Log.d(TAG, "Distance record: $distance km from $source (${record.startTime} to ${record.endTime})")
                        
                        when {
                            source.contains("shealth") || 
                            source.contains("com.sec.android") || 
                            source.contains("samsung") -> {
                                samsungDistance += distance
                                distanceDetails.add(detail)
                                Log.d(TAG, "  -> Samsung Health distance: $distance km (running total: $samsungDistance km)")
                            }
                            source.contains("google.android.apps.fitness") -> {
                                googleFitDistance += distance
                                if (samsungDistance == 0.0) distanceDetails.add(detail)
                                Log.d(TAG, "  -> Google Fit distance: $distance km (running total: $googleFitDistance km)")
                            }
                            else -> {
                                otherDistance += distance
                                if (samsungDistance == 0.0 && googleFitDistance == 0.0) distanceDetails.add(detail)
                                Log.d(TAG, "  -> Other source distance: $distance km (running total: $otherDistance km)")
                            }
                        }
                    }
                    
                    // Prioritize Samsung Health data
                    val finalDistance = when {
                        samsungDistance > 0 -> {
                            Log.d(TAG, "Using Samsung Health distance: $samsungDistance km")
                            samsungDistance
                        }
                        googleFitDistance > 0 -> {
                            Log.d(TAG, "No Samsung data, using Google Fit distance: $googleFitDistance km")
                            googleFitDistance
                        }
                        else -> {
                            Log.d(TAG, "Using other sources distance: $otherDistance km")
                            otherDistance
                        }
                    }
                    
                    healthData["distance"] = finalDistance
                    healthData["distanceDetails"] = distanceDetails
                    Log.d(TAG, "FINAL distance (prioritizing Samsung): $finalDistance km from ${distanceResponse.records.size} records")
                } catch (e: Exception) {
                    Log.e(TAG, "Error reading distance", e)
                    healthData["distance"] = 0.0
                }
                
                // Read sleep data
                try {
                    // Get sleep sessions from last night (last 24 hours)
                    val sleepResponse = healthConnectClient.readRecords(
                        ReadRecordsRequest(
                            SleepSessionRecord::class,
                            timeRangeFilter = TimeRangeFilter.between(
                                now.minus(24, ChronoUnit.HOURS), 
                                now
                            )
                        )
                    )
                    
                    if (sleepResponse.records.isNotEmpty()) {
                        var totalSleepMinutes = 0L
                        val sleepDetails = mutableListOf<Map<String, Any>>()
                        
                        sleepResponse.records.forEach { record ->
                            val source = record.metadata.dataOrigin.packageName
                            val duration = java.time.Duration.between(record.startTime, record.endTime)
                            val minutes = duration.toMinutes()
                            
                            Log.d(TAG, "Sleep session: ${minutes} minutes from ${source}")
                            Log.d(TAG, "  Time: ${record.startTime} to ${record.endTime}")
                            
                            // Accumulate all Samsung Health sleep sessions (not just last one)
                            if (source.contains("shealth") ||
                                source.contains("com.sec.android") ||
                                source.contains("samsung")) {
                                totalSleepMinutes += minutes // FIX: Accumulate all Samsung sessions
                                sleepDetails.add(mapOf(
                                    "duration" to minutes,
                                    "startTime" to record.startTime.toString(),
                                    "endTime" to record.endTime.toString(),
                                    "source" to source,
                                    "title" to (record.title ?: "Sleep"),
                                    "notes" to (record.notes ?: "")
                                ))
                                Log.d(TAG, "  -> Adding Samsung sleep session: $minutes minutes")
                            } else if (sleepDetails.none { (it["source"] as String).contains("samsung") || (it["source"] as String).contains("shealth") }) {
                                // Only use non-Samsung data if no Samsung data exists
                                totalSleepMinutes += minutes
                                sleepDetails.add(mapOf(
                                    "duration" to minutes,
                                    "startTime" to record.startTime.toString(),
                                    "endTime" to record.endTime.toString(),
                                    "source" to source,
                                    "title" to (record.title ?: "Sleep"),
                                    "notes" to (record.notes ?: "")
                                ))
                            }
                        }
                        
                        // Convert minutes to hours
                        val sleepHours = totalSleepMinutes / 60.0
                        healthData["sleep"] = sleepHours
                        healthData["sleepMinutes"] = totalSleepMinutes
                        healthData["sleepDetails"] = sleepDetails
                        
                        Log.d(TAG, "Total sleep: $sleepHours hours ($totalSleepMinutes minutes)")
                        
                        // Note: Sleep stages would require SleepStageRecord which may not be available in all SDK versions
                    } else {
                        healthData["sleep"] = 0.0
                        healthData["sleepMinutes"] = 0
                        Log.d(TAG, "No sleep data found")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error reading sleep data", e)
                    healthData["sleep"] = 0.0
                    healthData["sleepMinutes"] = 0
                }
                
                // Read water/hydration data with source prioritization
                try {
                    val hydrationResponse = healthConnectClient.readRecords(
                        ReadRecordsRequest(
                            HydrationRecord::class,
                            timeRangeFilter = TimeRangeFilter.between(startOfDay, now)
                        )
                    )
                    
                    var samsungWater = 0.0
                    var googleFitWater = 0.0
                    var otherWater = 0.0
                    
                    hydrationResponse.records.forEach { record ->
                        val source = record.metadata.dataOrigin.packageName
                        val volume = record.volume.inLiters * 1000 // Convert to ml
                        
                        when {
                            source.contains("shealth") || 
                            source.contains("com.sec.android") || 
                            source.contains("samsung") -> {
                                samsungWater += volume
                                Log.d(TAG, "Samsung water: $volume ml")
                            }
                            source.contains("google.android.apps.fitness") -> {
                                googleFitWater += volume
                            }
                            else -> {
                                otherWater += volume
                            }
                        }
                    }
                    
                    // Prioritize Samsung Health data
                    val finalWater = when {
                        samsungWater > 0 -> samsungWater
                        googleFitWater > 0 -> googleFitWater
                        else -> otherWater
                    }
                    
                    healthData["water"] = finalWater.toInt()
                    Log.d(TAG, "Total water (prioritizing Samsung): $finalWater ml")
                } catch (e: Exception) {
                    Log.e(TAG, "Error reading water data", e)
                    healthData["water"] = 0
                }
                
                // Read weight data with source prioritization
                try {
                    val weightResponse = healthConnectClient.readRecords(
                        ReadRecordsRequest(
                            WeightRecord::class,
                            timeRangeFilter = TimeRangeFilter.between(
                                startOfDay.minus(7, ChronoUnit.DAYS), // Last week for weight
                                now
                            )
                        )
                    )
                    
                    var samsungWeight = 0.0
                    var googleFitWeight = 0.0
                    var otherWeight = 0.0
                    var samsungWeightTime: Instant? = null
                    var otherWeightTime: Instant? = null
                    
                    weightResponse.records.forEach { record ->
                        val source = record.metadata.dataOrigin.packageName
                        val weight = record.weight.inKilograms
                        
                        when {
                            source.contains("shealth") || 
                            source.contains("com.sec.android") || 
                            source.contains("samsung") -> {
                                // Get the most recent Samsung weight
                                if (samsungWeightTime == null || record.time.isAfter(samsungWeightTime)) {
                                    samsungWeight = weight
                                    samsungWeightTime = record.time
                                }
                                Log.d(TAG, "Samsung weight: $weight kg at ${record.time}")
                            }
                            source.contains("google.android.apps.fitness") -> {
                                googleFitWeight = weight // Just use latest
                            }
                            else -> {
                                // Get the most recent other weight
                                if (otherWeightTime == null || record.time.isAfter(otherWeightTime)) {
                                    otherWeight = weight
                                    otherWeightTime = record.time
                                }
                            }
                        }
                    }
                    
                    // Prioritize Samsung Health data
                    val finalWeight = when {
                        samsungWeight > 0 -> samsungWeight
                        googleFitWeight > 0 -> googleFitWeight
                        else -> otherWeight
                    }
                    
                    healthData["weight"] = finalWeight
                    Log.d(TAG, "Latest weight (prioritizing Samsung): $finalWeight kg")
                } catch (e: Exception) {
                    Log.e(TAG, "Error reading weight data", e)
                    healthData["weight"] = 0.0
                }
                
                // Read blood oxygen data with source prioritization
                try {
                    val oxygenResponse = healthConnectClient.readRecords(
                        ReadRecordsRequest(
                            OxygenSaturationRecord::class,
                            timeRangeFilter = TimeRangeFilter.between(startOfDay, now)
                        )
                    )
                    
                    var samsungOxygen = 0.0
                    var googleFitOxygen = 0.0
                    var otherOxygen = 0.0
                    var samsungOxygenTime: Instant? = null
                    var otherOxygenTime: Instant? = null
                    
                    oxygenResponse.records.forEach { record ->
                        val source = record.metadata.dataOrigin.packageName
                        val percentage = record.percentage.value
                        
                        when {
                            source.contains("shealth") || 
                            source.contains("com.sec.android") || 
                            source.contains("samsung") -> {
                                // Get the most recent Samsung reading
                                if (samsungOxygenTime == null || record.time.isAfter(samsungOxygenTime)) {
                                    samsungOxygen = percentage
                                    samsungOxygenTime = record.time
                                }
                                Log.d(TAG, "Samsung blood oxygen: $percentage% at ${record.time}")
                            }
                            source.contains("google.android.apps.fitness") -> {
                                googleFitOxygen = percentage
                            }
                            else -> {
                                if (otherOxygenTime == null || record.time.isAfter(otherOxygenTime)) {
                                    otherOxygen = percentage
                                    otherOxygenTime = record.time
                                }
                            }
                        }
                    }
                    
                    // Prioritize Samsung Health data
                    val finalOxygen = when {
                        samsungOxygen > 0 -> samsungOxygen
                        googleFitOxygen > 0 -> googleFitOxygen
                        else -> otherOxygen
                    }
                    
                    healthData["bloodOxygen"] = finalOxygen.toInt()
                    Log.d(TAG, "Latest blood oxygen (prioritizing Samsung): $finalOxygen%")
                } catch (e: Exception) {
                    Log.e(TAG, "Error reading blood oxygen data", e)
                    healthData["bloodOxygen"] = 0
                }
                
                // Read blood pressure data with source prioritization
                try {
                    val bpResponse = healthConnectClient.readRecords(
                        ReadRecordsRequest(
                            BloodPressureRecord::class,
                            timeRangeFilter = TimeRangeFilter.between(startOfDay, now)
                        )
                    )
                    
                    var samsungSystolic = 0.0
                    var samsungDiastolic = 0.0
                    var otherSystolic = 0.0
                    var otherDiastolic = 0.0
                    var samsungBpTime: Instant? = null
                    var otherBpTime: Instant? = null
                    
                    bpResponse.records.forEach { record ->
                        val source = record.metadata.dataOrigin.packageName
                        val systolic = record.systolic.inMillimetersOfMercury
                        val diastolic = record.diastolic.inMillimetersOfMercury
                        
                        when {
                            source.contains("shealth") || 
                            source.contains("com.sec.android") || 
                            source.contains("samsung") -> {
                                // Get the most recent Samsung reading
                                if (samsungBpTime == null || record.time.isAfter(samsungBpTime)) {
                                    samsungSystolic = systolic
                                    samsungDiastolic = diastolic
                                    samsungBpTime = record.time
                                }
                                Log.d(TAG, "Samsung blood pressure: $systolic/$diastolic mmHg at ${record.time}")
                            }
                            else -> {
                                if (otherBpTime == null || record.time.isAfter(otherBpTime)) {
                                    otherSystolic = systolic
                                    otherDiastolic = diastolic
                                    otherBpTime = record.time
                                }
                            }
                        }
                    }
                    
                    // Prioritize Samsung Health data
                    val finalSystolic = if (samsungSystolic > 0) samsungSystolic else otherSystolic
                    val finalDiastolic = if (samsungDiastolic > 0) samsungDiastolic else otherDiastolic
                    
                    healthData["bloodPressure"] = mapOf(
                        "systolic" to finalSystolic.toInt(),
                        "diastolic" to finalDiastolic.toInt()
                    )
                    Log.d(TAG, "Latest blood pressure (prioritizing Samsung): $finalSystolic/$finalDiastolic mmHg")
                } catch (e: Exception) {
                    Log.e(TAG, "Error reading blood pressure data", e)
                    healthData["bloodPressure"] = mapOf("systolic" to 0, "diastolic" to 0)
                }
                
                // Read exercise/workout data with source prioritization
                try {
                    val exerciseResponse = healthConnectClient.readRecords(
                        ReadRecordsRequest(
                            ExerciseSessionRecord::class,
                            timeRangeFilter = TimeRangeFilter.between(startOfDay, now)
                        )
                    )
                    
                    var samsungWorkouts = 0
                    var samsungExerciseMinutes = 0L
                    var otherWorkouts = 0
                    var otherExerciseMinutes = 0L
                    val workoutDetails = mutableListOf<Map<String, Any>>()
                    
                    exerciseResponse.records.forEach { record ->
                        val source = record.metadata.dataOrigin.packageName
                        val duration = java.time.Duration.between(record.startTime, record.endTime)
                        val minutes = duration.toMinutes()
                        
                        val workoutDetail = mapOf(
                            "exerciseType" to (record.exerciseType.toString()),
                            "duration" to minutes,
                            "startTime" to record.startTime.toString(),
                            "endTime" to record.endTime.toString(),
                            "source" to source,
                            "title" to (record.title ?: "Workout")
                        )
                        
                        when {
                            source.contains("shealth") || 
                            source.contains("com.sec.android") || 
                            source.contains("samsung") -> {
                                samsungWorkouts++
                                samsungExerciseMinutes += minutes
                                workoutDetails.clear() // Clear other workouts, use Samsung only
                                workoutDetails.add(workoutDetail)
                                Log.d(TAG, "Samsung workout: ${record.exerciseType} for $minutes min")
                            }
                            else -> {
                                // Only add non-Samsung workouts if no Samsung data exists
                                if (samsungWorkouts == 0) {
                                    otherWorkouts++
                                    otherExerciseMinutes += minutes
                                    workoutDetails.add(workoutDetail)
                                }
                            }
                        }
                    }
                    
                    // Prioritize Samsung Health data
                    val finalWorkouts = if (samsungWorkouts > 0) samsungWorkouts else otherWorkouts
                    val finalExerciseMinutes = if (samsungExerciseMinutes > 0) samsungExerciseMinutes else otherExerciseMinutes
                    
                    healthData["workouts"] = finalWorkouts
                    healthData["exerciseMinutes"] = finalExerciseMinutes
                    healthData["workoutDetails"] = workoutDetails
                    Log.d(TAG, "Total workouts (prioritizing Samsung): $finalWorkouts ($finalExerciseMinutes min)")
                } catch (e: Exception) {
                    Log.e(TAG, "Error reading exercise data", e)
                    healthData["workouts"] = 0
                    healthData["exerciseMinutes"] = 0
                }
                
                // Add metadata
                healthData["dataSources"] = dataSources.toList()
                healthData["lastSync"] = Instant.now().toString()
                healthData["syncTime"] = System.currentTimeMillis()
                
                // Check if Samsung Health data is actually present
                val hasSamsungData = dataSources.any { 
                    it.contains("samsung") || 
                    it.contains("shealth") || 
                    it.contains("com.sec.android") || 
                    it.contains("gear") 
                }
                healthData["hasSamsungHealthData"] = hasSamsungData
                
                Log.d(TAG, "=== Health Data Summary ===")
                Log.d(TAG, "Data sources found: ${dataSources.joinToString(", ")}")
                Log.d(TAG, "Samsung Health detected: $hasSamsungData")
                Log.d(TAG, "Steps: ${healthData["steps"]} (${healthData["stepsBySource"]?.let { (it as Map<*, *>)["dataSource"] } ?: "Unknown"})")
                Log.d(TAG, "Heart Rate: ${healthData["heartRate"]} bpm (${healthData["heartRateType"]})")
                Log.d(TAG, "Calories: ${healthData["calories"]} kcal")
                Log.d(TAG, "Distance: ${healthData["distance"]} km")
                Log.d(TAG, "Sleep: ${healthData["sleep"]} hours (${healthData["sleepMinutes"]} minutes)")
                Log.d(TAG, "Water: ${healthData["water"]} ml")
                Log.d(TAG, "Weight: ${healthData["weight"]} kg")
                Log.d(TAG, "Blood Oxygen: ${healthData["bloodOxygen"]}%")
                val bloodPressure = healthData["bloodPressure"] as? Map<*, *>
                Log.d(TAG, "Blood Pressure: ${bloodPressure?.get("systolic")}/${bloodPressure?.get("diastolic")} mmHg")
                Log.d(TAG, "Workouts: ${healthData["workouts"]} (${healthData["exerciseMinutes"]} min)")
                
                if (!hasSamsungData) {
                    Log.w(TAG, "⚠️  WARNING: No Samsung Health data found! Check if Samsung Health is installed and has data.")
                    Log.w(TAG, "⚠️  Available sources: ${dataSources.joinToString(", ")}")
                } else {
                    Log.i(TAG, "✅ Samsung Health data successfully detected")
                }
                Log.d(TAG, "=========================")
                
                result.success(healthData)
            } catch (e: Exception) {
                Log.e(TAG, "Error reading all health data", e)
                result.error("READ_ERROR", e.message, null)
            }
        }
    }
    
    private fun startBackgroundSync(result: MethodChannel.Result) {
        try {
            Log.d(TAG, "Starting background health sync...")
            HealthSyncWorker.schedulePeriodicSync(this)
            
            result.success(mapOf(
                "success" to true,
                "message" to "Background sync scheduled for every hour"
            ))
        } catch (e: Exception) {
            Log.e(TAG, "Error starting background sync", e)
            result.error("SYNC_ERROR", e.message, null)
        }
    }
    
    private fun stopBackgroundSync(result: MethodChannel.Result) {
        try {
            Log.d(TAG, "Stopping background health sync...")
            HealthSyncWorker.cancelSync(this)
            
            result.success(mapOf(
                "success" to true,
                "message" to "Background sync cancelled"
            ))
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping background sync", e)
            result.error("SYNC_ERROR", e.message, null)
        }
    }
    
    private fun getLastSyncInfo(result: MethodChannel.Result) {
        try {
            val sharedPrefs = getSharedPreferences("health_sync", Context.MODE_PRIVATE)
            val lastSyncTime = sharedPrefs.getLong("last_sync_time", 0)
            val lastSyncSteps = sharedPrefs.getInt("last_sync_steps", 0)
            val lastSyncHeartRate = sharedPrefs.getInt("last_sync_heart_rate", 0)
            val lastSyncCalories = sharedPrefs.getFloat("last_sync_calories", 0f)
            val dataSources = sharedPrefs.getStringSet("data_sources", emptySet()) ?: emptySet()

            val syncInfo = mapOf(
                "lastSyncTime" to lastSyncTime,
                "lastSyncTimeString" to if (lastSyncTime > 0) Instant.ofEpochMilli(lastSyncTime).toString() else "Never",
                "lastSyncSteps" to lastSyncSteps,
                "lastSyncHeartRate" to lastSyncHeartRate,
                "lastSyncCalories" to lastSyncCalories,
                "dataSources" to dataSources.toList(),
                "hasSamsungData" to dataSources.any {
                    it.contains("samsung") ||
                    it.contains("shealth") ||
                    it.contains("com.sec.android") ||
                    it.contains("gear")
                }
            )

            Log.d(TAG, "Last sync info: $syncInfo")
            result.success(syncInfo)
        } catch (e: Exception) {
            Log.e(TAG, "Error getting last sync info", e)
            result.error("SYNC_ERROR", e.message, null)
        }
    }

    private fun captureHealthDataLogs(result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                val now = Instant.now()
                val startOfDay = ZonedDateTime.now().truncatedTo(ChronoUnit.DAYS).toInstant()
                val yesterday = startOfDay.minus(1, ChronoUnit.DAYS)

                val logData = JSONObject()
                val dateFormatter = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())

                // Add metadata
                logData.put("captureTime", now.toString())
                logData.put("captureTimeFormatted", dateFormatter.format(Date()))
                logData.put("timeRange", JSONObject().apply {
                    put("startOfDay", startOfDay.toString())
                    put("now", now.toString())
                    put("yesterday", yesterday.toString())
                })

                // LOG ALL AVAILABLE HEALTH CONNECT DATA TYPES
                val allHealthData = JSONObject()

                // Check Health Connect availability and permissions
                val availabilityInfo = JSONObject()
                try {
                    val availability = HealthConnectClient.getSdkStatus(this@MainActivity, "com.google.android.apps.healthdata")
                    availabilityInfo.put("status", availability.toString())
                    availabilityInfo.put("statusCode", availability)

                    // Get granted permissions
                    val granted = healthConnectClient.permissionController.getGrantedPermissions()
                    val grantedArray = JSONArray()
                    granted.forEach { permission ->
                        grantedArray.put(permission.toString())
                    }
                    availabilityInfo.put("grantedPermissions", grantedArray)
                    availabilityInfo.put("grantedCount", granted.size)

                    // List requested permissions
                    val requestedArray = JSONArray()
                    permissions.forEach { permission ->
                        requestedArray.put(permission.toString())
                    }
                    availabilityInfo.put("requestedPermissions", requestedArray)
                    availabilityInfo.put("requestedCount", permissions.size)

                } catch (e: Exception) {
                    availabilityInfo.put("error", e.toString())
                }
                allHealthData.put("healthConnectInfo", availabilityInfo)

                // COMPREHENSIVE CALORIE DATA CAPTURE
                val calorieData = JSONObject()

                // 1. Active Calories Burned (Exercise calories)
                try {
                    val activeCaloriesArray = JSONArray()
                    val activeCaloriesResponse = healthConnectClient.readRecords(
                        ReadRecordsRequest(
                            ActiveCaloriesBurnedRecord::class,
                            timeRangeFilter = TimeRangeFilter.between(yesterday, now)
                        )
                    )

                    activeCaloriesResponse.records.forEach { record ->
                        val recordJson = JSONObject().apply {
                            put("recordType", "ActiveCaloriesBurned")
                            put("energyKcal", record.energy.inKilocalories)
                            put("energyJoules", record.energy.inJoules)
                            put("energyKilojoules", record.energy.inKilojoules)
                            put("energyCalories", record.energy.inCalories)
                            put("startTime", record.startTime.toString())
                            put("endTime", record.endTime.toString())
                            put("startZoneOffset", record.startZoneOffset?.toString() ?: "null")
                            put("endZoneOffset", record.endZoneOffset?.toString() ?: "null")

                            // Metadata
                            val metadata = JSONObject().apply {
                                put("id", record.metadata.id)
                                put("dataOrigin", record.metadata.dataOrigin.packageName)
                                put("lastModifiedTime", record.metadata.lastModifiedTime.toString())
                                put("clientRecordId", record.metadata.clientRecordId ?: "null")
                                put("clientRecordVersion", record.metadata.clientRecordVersion)
                                put("device", record.metadata.device?.let { device ->
                                    JSONObject().apply {
                                        put("manufacturer", device.manufacturer ?: "unknown")
                                        put("model", device.model ?: "unknown")
                                        put("type", device.type.toString())
                                    }
                                } ?: "null")
                            }
                            put("metadata", metadata)
                        }
                        activeCaloriesArray.put(recordJson)
                    }

                    calorieData.put("activeCaloriesRecords", activeCaloriesArray)
                    calorieData.put("activeCaloriesCount", activeCaloriesArray.length())

                    // Calculate totals by source
                    val activeBySource = mutableMapOf<String, Double>()
                    for (i in 0 until activeCaloriesArray.length()) {
                        val record = activeCaloriesArray.getJSONObject(i)
                        val source = record.getJSONObject("metadata").getString("dataOrigin")
                        val calories = record.getDouble("energyKcal")
                        activeBySource[source] = (activeBySource[source] ?: 0.0) + calories
                    }
                    calorieData.put("activeCaloriesBySource", JSONObject(activeBySource as Map<*, *>))

                } catch (e: Exception) {
                    calorieData.put("activeCaloriesError", e.toString())
                    Log.e(TAG, "Error reading active calories for log", e)
                }

                // 2. Total Calories Burned (includes BMR + active)
                try {
                    val totalCaloriesArray = JSONArray()
                    val totalCaloriesResponse = healthConnectClient.readRecords(
                        ReadRecordsRequest(
                            TotalCaloriesBurnedRecord::class,
                            timeRangeFilter = TimeRangeFilter.between(yesterday, now)
                        )
                    )

                    totalCaloriesResponse.records.forEach { record ->
                        val recordJson = JSONObject().apply {
                            put("recordType", "TotalCaloriesBurned")
                            put("energyKcal", record.energy.inKilocalories)
                            put("energyJoules", record.energy.inJoules)
                            put("energyKilojoules", record.energy.inKilojoules)
                            put("energyCalories", record.energy.inCalories)
                            put("startTime", record.startTime.toString())
                            put("endTime", record.endTime.toString())
                            put("startZoneOffset", record.startZoneOffset?.toString() ?: "null")
                            put("endZoneOffset", record.endZoneOffset?.toString() ?: "null")

                            // Metadata
                            val metadata = JSONObject().apply {
                                put("id", record.metadata.id)
                                put("dataOrigin", record.metadata.dataOrigin.packageName)
                                put("lastModifiedTime", record.metadata.lastModifiedTime.toString())
                                put("clientRecordId", record.metadata.clientRecordId ?: "null")
                                put("clientRecordVersion", record.metadata.clientRecordVersion)
                                put("device", record.metadata.device?.let { device ->
                                    JSONObject().apply {
                                        put("manufacturer", device.manufacturer ?: "unknown")
                                        put("model", device.model ?: "unknown")
                                        put("type", device.type.toString())
                                    }
                                } ?: "null")
                            }
                            put("metadata", metadata)
                        }
                        totalCaloriesArray.put(recordJson)
                    }

                    calorieData.put("totalCaloriesRecords", totalCaloriesArray)
                    calorieData.put("totalCaloriesCount", totalCaloriesArray.length())

                    // Calculate totals by source
                    val totalBySource = mutableMapOf<String, Double>()
                    for (i in 0 until totalCaloriesArray.length()) {
                        val record = totalCaloriesArray.getJSONObject(i)
                        val source = record.getJSONObject("metadata").getString("dataOrigin")
                        val calories = record.getDouble("energyKcal")
                        totalBySource[source] = (totalBySource[source] ?: 0.0) + calories
                    }
                    calorieData.put("totalCaloriesBySource", JSONObject(totalBySource as Map<*, *>))

                } catch (e: Exception) {
                    calorieData.put("totalCaloriesError", e.toString())
                    Log.e(TAG, "Error reading total calories for log", e)
                }

                // 3. Basal Metabolic Rate (if available)
                try {
                    val bmrArray = JSONArray()
                    val bmrResponse = healthConnectClient.readRecords(
                        ReadRecordsRequest(
                            BasalMetabolicRateRecord::class,
                            timeRangeFilter = TimeRangeFilter.between(yesterday, now)
                        )
                    )

                    bmrResponse.records.forEach { record ->
                        val recordJson = JSONObject().apply {
                            put("recordType", "BasalMetabolicRate")
                            put("basalMetabolicRateKcalPerDay", record.basalMetabolicRate.inKilocaloriesPerDay)
                            put("time", record.time.toString())
                            put("zoneOffset", record.zoneOffset?.toString() ?: "null")

                            // Metadata
                            val metadata = JSONObject().apply {
                                put("id", record.metadata.id)
                                put("dataOrigin", record.metadata.dataOrigin.packageName)
                                put("lastModifiedTime", record.metadata.lastModifiedTime.toString())
                            }
                            put("metadata", metadata)
                        }
                        bmrArray.put(recordJson)
                    }

                    calorieData.put("basalMetabolicRateRecords", bmrArray)
                    calorieData.put("basalMetabolicRateCount", bmrArray.length())

                } catch (e: Exception) {
                    calorieData.put("basalMetabolicRateError", e.toString())
                    Log.e(TAG, "Error reading BMR for log", e)
                }

                // 4. Exercise Sessions with calorie data
                try {
                    val exerciseArray = JSONArray()
                    val exerciseResponse = healthConnectClient.readRecords(
                        ReadRecordsRequest(
                            ExerciseSessionRecord::class,
                            timeRangeFilter = TimeRangeFilter.between(yesterday, now)
                        )
                    )

                    exerciseResponse.records.forEach { record ->
                        val recordJson = JSONObject().apply {
                            put("recordType", "ExerciseSession")
                            put("exerciseType", record.exerciseType.toString())
                            put("title", record.title ?: "No title")
                            put("notes", record.notes ?: "No notes")
                            put("startTime", record.startTime.toString())
                            put("endTime", record.endTime.toString())
                            put("durationMinutes", java.time.Duration.between(record.startTime, record.endTime).toMinutes())

                            // Metadata
                            val metadata = JSONObject().apply {
                                put("id", record.metadata.id)
                                put("dataOrigin", record.metadata.dataOrigin.packageName)
                                put("lastModifiedTime", record.metadata.lastModifiedTime.toString())
                                put("device", record.metadata.device?.let { device ->
                                    JSONObject().apply {
                                        put("manufacturer", device.manufacturer ?: "unknown")
                                        put("model", device.model ?: "unknown")
                                        put("type", device.type.toString())
                                    }
                                } ?: "null")
                            }
                            put("metadata", metadata)
                        }
                        exerciseArray.put(recordJson)
                    }

                    calorieData.put("exerciseSessionRecords", exerciseArray)
                    calorieData.put("exerciseSessionCount", exerciseArray.length())

                } catch (e: Exception) {
                    calorieData.put("exerciseSessionError", e.toString())
                    Log.e(TAG, "Error reading exercise sessions for log", e)
                }

                logData.put("calorieData", calorieData)

                // CAPTURE ALL RAW HEALTH CONNECT RESPONSES
                val rawResponses = JSONObject()

                // 1. RAW STEPS DATA
                try {
                    val stepsRequest = ReadRecordsRequest(
                        StepsRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(yesterday, now)
                    )
                    rawResponses.put("stepsRequest", JSONObject().apply {
                        put("recordType", "StepsRecord")
                        put("timeRangeStart", yesterday.toString())
                        put("timeRangeEnd", now.toString())
                    })

                    val stepsResponse = healthConnectClient.readRecords(stepsRequest)
                    val stepsArray = JSONArray()
                    stepsResponse.records.forEach { record ->
                        stepsArray.put(JSONObject().apply {
                            put("count", record.count)
                            put("startTime", record.startTime.toString())
                            put("endTime", record.endTime.toString())
                            put("startZoneOffset", record.startZoneOffset?.toString())
                            put("endZoneOffset", record.endZoneOffset?.toString())
                            put("dataOrigin", record.metadata.dataOrigin.packageName)
                            put("id", record.metadata.id)
                            put("lastModifiedTime", record.metadata.lastModifiedTime.toString())
                            put("clientRecordId", record.metadata.clientRecordId)
                            put("clientRecordVersion", record.metadata.clientRecordVersion)
                            put("device", record.metadata.device?.let { device ->
                                JSONObject().apply {
                                    put("manufacturer", device.manufacturer)
                                    put("model", device.model)
                                    put("type", device.type.toString())
                                }
                            })
                        })
                    }
                    rawResponses.put("stepsResponse", stepsArray)
                    rawResponses.put("stepsRecordCount", stepsResponse.records.size)
                    rawResponses.put("stepsPageToken", stepsResponse.pageToken ?: "null")
                } catch (e: Exception) {
                    rawResponses.put("stepsError", e.toString())
                    rawResponses.put("stepsErrorMessage", e.message)
                    rawResponses.put("stepsErrorStackTrace", e.stackTrace.take(5).joinToString("\n"))
                }

                // 2. RAW HEART RATE DATA
                try {
                    val heartRateRequest = ReadRecordsRequest(
                        HeartRateRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(yesterday, now)
                    )
                    rawResponses.put("heartRateRequest", JSONObject().apply {
                        put("recordType", "HeartRateRecord")
                        put("timeRangeStart", yesterday.toString())
                        put("timeRangeEnd", now.toString())
                    })

                    val heartRateResponse = healthConnectClient.readRecords(heartRateRequest)
                    val heartRateArray = JSONArray()
                    heartRateResponse.records.forEach { record ->
                        val samplesArray = JSONArray()
                        record.samples.forEach { sample ->
                            samplesArray.put(JSONObject().apply {
                                put("beatsPerMinute", sample.beatsPerMinute)
                                put("time", sample.time.toString())
                            })
                        }
                        heartRateArray.put(JSONObject().apply {
                            put("startTime", record.startTime.toString())
                            put("endTime", record.endTime.toString())
                            put("samples", samplesArray)
                            put("sampleCount", record.samples.size)
                            put("dataOrigin", record.metadata.dataOrigin.packageName)
                            put("id", record.metadata.id)
                        })
                    }
                    rawResponses.put("heartRateResponse", heartRateArray)
                    rawResponses.put("heartRateRecordCount", heartRateResponse.records.size)
                } catch (e: Exception) {
                    rawResponses.put("heartRateError", e.toString())
                }

                // 3. RAW DISTANCE DATA
                try {
                    val distanceRequest = ReadRecordsRequest(
                        DistanceRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(yesterday, now)
                    )
                    val distanceResponse = healthConnectClient.readRecords(distanceRequest)
                    val distanceArray = JSONArray()
                    distanceResponse.records.forEach { record ->
                        distanceArray.put(JSONObject().apply {
                            put("distanceMeters", record.distance.inMeters)
                            put("distanceKilometers", record.distance.inKilometers)
                            put("distanceMiles", record.distance.inMiles)
                            put("distanceFeet", record.distance.inFeet)
                            put("startTime", record.startTime.toString())
                            put("endTime", record.endTime.toString())
                            put("dataOrigin", record.metadata.dataOrigin.packageName)
                        })
                    }
                    rawResponses.put("distanceResponse", distanceArray)
                    rawResponses.put("distanceRecordCount", distanceResponse.records.size)
                } catch (e: Exception) {
                    rawResponses.put("distanceError", e.toString())
                }

                allHealthData.put("rawApiResponses", rawResponses)
                logData.put("allHealthData", allHealthData)

                // Also capture other metrics for context
                val otherMetrics = JSONObject()

                // Steps
                try {
                    val stepsResponse = healthConnectClient.readRecords(
                        ReadRecordsRequest(
                            StepsRecord::class,
                            timeRangeFilter = TimeRangeFilter.between(startOfDay, now)
                        )
                    )

                    val stepsBySource = mutableMapOf<String, Long>()
                    stepsResponse.records.forEach { record ->
                        val source = record.metadata.dataOrigin.packageName
                        stepsBySource[source] = (stepsBySource[source] ?: 0L) + record.count
                    }
                    otherMetrics.put("stepsBySource", JSONObject(stepsBySource as Map<*, *>))
                    otherMetrics.put("totalStepRecords", stepsResponse.records.size)
                } catch (e: Exception) {
                    otherMetrics.put("stepsError", e.toString())
                }

                // Distance
                try {
                    val distanceResponse = healthConnectClient.readRecords(
                        ReadRecordsRequest(
                            DistanceRecord::class,
                            timeRangeFilter = TimeRangeFilter.between(startOfDay, now)
                        )
                    )

                    val distanceBySource = mutableMapOf<String, Double>()
                    distanceResponse.records.forEach { record ->
                        val source = record.metadata.dataOrigin.packageName
                        distanceBySource[source] = (distanceBySource[source] ?: 0.0) + record.distance.inKilometers
                    }
                    otherMetrics.put("distanceBySource", JSONObject(distanceBySource as Map<*, *>))
                    otherMetrics.put("totalDistanceRecords", distanceResponse.records.size)
                } catch (e: Exception) {
                    otherMetrics.put("distanceError", e.toString())
                }

                logData.put("otherMetrics", otherMetrics)

                // Analysis and recommendations
                val analysis = JSONObject()
                analysis.put("notes", "Check the following fields for accurate active calorie burn:")
                analysis.put("recommendation1", "ActiveCaloriesBurnedRecord.energy.inKilocalories - This is exercise/activity calories only")
                analysis.put("recommendation2", "TotalCaloriesBurnedRecord.energy.inKilocalories - This includes BMR + active calories")
                analysis.put("recommendation3", "To get active calories from total: Total - BMR (if BMR available) or Total - estimated BMR")
                analysis.put("recommendation4", "Samsung Health may provide both or only one type - check 'dataOrigin' field")

                logData.put("analysis", analysis)

                // Convert to pretty JSON string
                val jsonString = logData.toString(4)

                // Return the JSON string to Flutter
                result.success(mapOf(
                    "logData" to jsonString,
                    "summary" to "Captured ${calorieData.optInt("activeCaloriesCount", 0)} active calorie records and ${calorieData.optInt("totalCaloriesCount", 0)} total calorie records"
                ))

            } catch (e: Exception) {
                Log.e(TAG, "Error capturing health data logs", e)
                result.error("LOG_ERROR", e.message, null)
            }
        }
    }

    private fun syncUserProfile(age: Int, gender: String, height: Double, weight: Double, result: MethodChannel.Result) {
        try {
            Log.d(TAG, "=== SYNCING USER PROFILE ===")
            Log.d(TAG, "Age: $age, Gender: $gender, Height: $height, Weight: $weight")

            // Save to SharedPreferences
            val sharedPrefs = getSharedPreferences("user_profile", Context.MODE_PRIVATE)
            val editor = sharedPrefs.edit()

            editor.putInt("age", age)
            editor.putString("gender", gender)
            editor.putFloat("height", height.toFloat())
            editor.putFloat("weight", weight.toFloat())
            editor.putLong("lastSynced", System.currentTimeMillis())

            val success = editor.commit()

            if (success) {
                Log.d(TAG, "✅ Profile successfully saved to SharedPreferences")

                // Verify the data was saved
                val savedAge = sharedPrefs.getInt("age", 0)
                val savedGender = sharedPrefs.getString("gender", "unknown")
                val savedHeight = sharedPrefs.getFloat("height", 0f)
                val savedWeight = sharedPrefs.getFloat("weight", 0f)

                Log.d(TAG, "Verification - Age: $savedAge, Gender: $savedGender, Height: $savedHeight, Weight: $savedWeight")

                result.success(true)
            } else {
                Log.e(TAG, "Failed to save profile to SharedPreferences")
                result.success(false)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error syncing user profile", e)
            result.error("SYNC_ERROR", e.message, null)
        }
    }

    private fun getDeviceInfo(result: MethodChannel.Result) {
        try {
            val manufacturer = Build.MANUFACTURER.lowercase(Locale.getDefault())
            val model = Build.MODEL
            val androidVersion = Build.VERSION.SDK_INT
            val isSamsung = manufacturer.contains("samsung")

            val deviceInfo = mapOf(
                "manufacturer" to manufacturer,
                "model" to model,
                "androidVersion" to androidVersion,
                "androidVersionName" to Build.VERSION.RELEASE,
                "isSamsung" to isSamsung
            )

            Log.d(TAG, "Device info: $deviceInfo")
            result.success(deviceInfo)
        } catch (e: Exception) {
            Log.e(TAG, "Error getting device info", e)
            result.error("DEVICE_INFO_ERROR", e.message, null)
        }
    }

    private fun openHealthConnectSettings(result: MethodChannel.Result) {
        try {
            Log.d(TAG, "=== OPENING HEALTH CONNECT SETTINGS ===")

            // Get device info for logging
            val manufacturer = Build.MANUFACTURER.lowercase(Locale.getDefault())
            val model = Build.MODEL
            val androidVersion = Build.VERSION.SDK_INT
            val isSamsung = manufacturer.contains("samsung")

            Log.d(TAG, "Device: $manufacturer $model")
            Log.d(TAG, "Android Version: $androidVersion (${Build.VERSION.RELEASE})")
            Log.d(TAG, "Is Samsung: $isSamsung")

            var settingsOpened = false
            var openMethod = ""

            // Try different approaches based on Android version and manufacturer
            when {
                // Samsung devices need special handling
                isSamsung -> {
                    Log.d(TAG, "Samsung device detected - Using Samsung-specific approach")

                    // Try Samsung Health first
                    try {
                        val intent = Intent().apply {
                            setClassName(
                                "com.samsung.android.shealthpermissionmanager",
                                "com.samsung.android.shealthpermissionmanager.PermissionActivity"
                            )
                            putExtra("packageName", packageName)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        settingsOpened = true
                        openMethod = "samsung_health_permissions"
                        Log.d(TAG, "✅ Opened Samsung Health permissions")
                    } catch (e: Exception) {
                        Log.e(TAG, "Samsung Health permission manager not found, trying standard approach", e)

                        // Fallback to standard Health Connect for Samsung
                        try {
                            val intent = Intent("androidx.health.ACTION_HEALTH_CONNECT_SETTINGS").apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            settingsOpened = true
                            openMethod = "health_connect_settings_samsung"
                            Log.d(TAG, "✅ Opened Health Connect settings on Samsung")
                        } catch (e2: Exception) {
                            Log.e(TAG, "Standard Health Connect also failed on Samsung", e2)
                        }
                    }
                }

                // Android 14+ (API 34+) - Health Connect is integrated into system settings
                androidVersion >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE -> {
                    Log.d(TAG, "Android 14+ detected - Using ACTION_MANAGE_HEALTH_PERMISSIONS")

                    try {
                        // Try the new Health Connect manager intent for Android 14+
                        val intent = Intent("android.health.connect.action.MANAGE_HEALTH_PERMISSIONS").apply {
                            putExtra(Intent.EXTRA_PACKAGE_NAME, packageName)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        settingsOpened = true
                        openMethod = "health_permissions_manager"
                        Log.d(TAG, "✅ Opened Health Connect permissions for app")
                    } catch (e: ActivityNotFoundException) {
                        Log.e(TAG, "ACTION_MANAGE_HEALTH_PERMISSIONS not found, trying alternative", e)

                        // Fallback: Try direct Health Connect settings
                        try {
                            val intent = Intent("androidx.health.ACTION_HEALTH_CONNECT_SETTINGS").apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            settingsOpened = true
                            openMethod = "health_connect_settings"
                            Log.d(TAG, "✅ Opened Health Connect settings (fallback)")
                        } catch (e2: Exception) {
                            Log.e(TAG, "Health Connect settings intent failed", e2)
                        }
                    }
                }

                // Android 13 and below - Health Connect is a separate app
                else -> {
                    Log.d(TAG, "Android 13 or below - Using legacy Health Connect intents")

                    try {
                        // Try the standard Health Connect settings intent
                        val intent = Intent("androidx.health.ACTION_HEALTH_CONNECT_SETTINGS").apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        settingsOpened = true
                        openMethod = "health_connect_app"
                        Log.d(TAG, "✅ Opened Health Connect app")
                    } catch (e: ActivityNotFoundException) {
                        Log.e(TAG, "Health Connect app not found, trying Play Store", e)

                        // Try to open Health Connect in Play Store
                        try {
                            val playStoreIntent = Intent(Intent.ACTION_VIEW).apply {
                                data = Uri.parse("market://details?id=com.google.android.apps.healthdata")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(playStoreIntent)
                            settingsOpened = true
                            openMethod = "play_store"
                            Log.d(TAG, "✅ Opened Health Connect in Play Store")
                        } catch (e2: Exception) {
                            Log.e(TAG, "Could not open Play Store", e2)
                        }
                    }
                }
            }

            // If nothing worked, try generic app settings as last resort
            if (!settingsOpened) {
                Log.d(TAG, "All Health Connect intents failed, opening app settings")
                try {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = Uri.parse("package:$packageName")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    settingsOpened = true
                    openMethod = "app_settings"
                    Log.d(TAG, "✅ Opened app settings page")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to open app settings", e)
                    openMethod = "failed"
                }
            }

            // Return result to Flutter - indicate actual status
            val response = mapOf(
                "status" to if (settingsOpened) "settings_opened" else "failed",
                "settingsOpened" to settingsOpened,
                "openMethod" to openMethod,
                "androidVersion" to androidVersion,
                "isSamsung" to isSamsung,
                "manufacturer" to manufacturer,
                "message" to when (openMethod) {
                    "samsung_health_permissions" -> "Opening Samsung Health permissions. Please grant all permissions and return to the app."
                    "health_connect_settings_samsung" -> "Opening Health Connect on Samsung. Please grant all permissions and return to the app."
                    "health_permissions_manager" -> "Opening Health Connect permissions. Please grant all permissions and return to the app."
                    "health_connect_settings" -> "Opening Health Connect settings. Please grant all permissions and return to the app."
                    "health_connect_app" -> "Opening Health Connect. Please grant all permissions and return to the app."
                    "play_store" -> "Please install Health Connect from Play Store, then return to the app."
                    "app_settings" -> "Please grant health permissions in app settings, then return to the app."
                    else -> "Could not open Health Connect settings. Please open Settings > Apps > Streaker > Permissions manually."
                }
            )

            result.success(response)
            Log.d(TAG, "Settings navigation completed: $response")

        } catch (e: Exception) {
            Log.e(TAG, "Error opening Health Connect settings", e)
            result.error("SETTINGS_ERROR", e.message, null)
        }
    }

    // Helper function to calculate BMR using Mifflin-St Jeor equation
    private fun calculateBMR(age: Int, gender: String, height: Double, weight: Double): Double {
        return if (gender.lowercase() == "male") {
            (10 * weight) + (6.25 * height) - (5 * age) + 5
        } else {
            (10 * weight) + (6.25 * height) - (5 * age) - 161
        }
    }

    // Helper function to estimate exercise calories based on type and duration
    private fun estimateExerciseCalories(exerciseType: Int, durationMinutes: Double): Double {
        // Average calories burned per minute for different exercise types
        // These are conservative estimates for a 70kg person
        val caloriesPerMinute = when (exerciseType) {
            ExerciseSessionRecord.EXERCISE_TYPE_RUNNING -> 10.0
            ExerciseSessionRecord.EXERCISE_TYPE_WALKING -> 4.0
            ExerciseSessionRecord.EXERCISE_TYPE_BIKING -> 8.0  // Cycling
            ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_POOL -> 11.0  // Swimming
            ExerciseSessionRecord.EXERCISE_TYPE_STRENGTH_TRAINING -> 6.0
            ExerciseSessionRecord.EXERCISE_TYPE_WEIGHTLIFTING -> 6.0
            ExerciseSessionRecord.EXERCISE_TYPE_YOGA -> 3.0
            ExerciseSessionRecord.EXERCISE_TYPE_PILATES -> 4.0
            ExerciseSessionRecord.EXERCISE_TYPE_DANCING -> 7.0
            ExerciseSessionRecord.EXERCISE_TYPE_HIKING -> 7.0
            ExerciseSessionRecord.EXERCISE_TYPE_BASKETBALL -> 8.0
            ExerciseSessionRecord.EXERCISE_TYPE_FOOTBALL_AMERICAN -> 9.0  // Football
            ExerciseSessionRecord.EXERCISE_TYPE_TENNIS -> 8.0
            ExerciseSessionRecord.EXERCISE_TYPE_BADMINTON -> 7.0
            ExerciseSessionRecord.EXERCISE_TYPE_ROWING_MACHINE -> 9.0  // Rowing
            ExerciseSessionRecord.EXERCISE_TYPE_ELLIPTICAL -> 8.0
            ExerciseSessionRecord.EXERCISE_TYPE_STAIR_CLIMBING -> 9.0
            else -> 5.0 // Default for unknown exercise types
        }

        return caloriesPerMinute * durationMinutes
    }

    // Helper function to get exercise type name for logging
    private fun getExerciseTypeName(exerciseType: Int): String {
        return when (exerciseType) {
            ExerciseSessionRecord.EXERCISE_TYPE_RUNNING -> "Running"
            ExerciseSessionRecord.EXERCISE_TYPE_WALKING -> "Walking"
            ExerciseSessionRecord.EXERCISE_TYPE_BIKING -> "Cycling"
            ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_POOL -> "Swimming"
            ExerciseSessionRecord.EXERCISE_TYPE_STRENGTH_TRAINING -> "Strength Training"
            ExerciseSessionRecord.EXERCISE_TYPE_WEIGHTLIFTING -> "Weightlifting"
            ExerciseSessionRecord.EXERCISE_TYPE_YOGA -> "Yoga"
            ExerciseSessionRecord.EXERCISE_TYPE_PILATES -> "Pilates"
            ExerciseSessionRecord.EXERCISE_TYPE_DANCING -> "Dancing"
            ExerciseSessionRecord.EXERCISE_TYPE_HIKING -> "Hiking"
            ExerciseSessionRecord.EXERCISE_TYPE_BASKETBALL -> "Basketball"
            ExerciseSessionRecord.EXERCISE_TYPE_FOOTBALL_AMERICAN -> "Football"
            ExerciseSessionRecord.EXERCISE_TYPE_TENNIS -> "Tennis"
            ExerciseSessionRecord.EXERCISE_TYPE_BADMINTON -> "Badminton"
            ExerciseSessionRecord.EXERCISE_TYPE_ROWING_MACHINE -> "Rowing"
            ExerciseSessionRecord.EXERCISE_TYPE_ELLIPTICAL -> "Elliptical"
            ExerciseSessionRecord.EXERCISE_TYPE_STAIR_CLIMBING -> "Stair Climbing"
            else -> "Other Exercise"
        }
    }

    // Helper function to get data source name for logging
    private fun getDataSourceName(packageName: String): String {
        return when {
            packageName.contains("shealth") ||
            packageName.contains("samsung") -> "Samsung Health"
            packageName.contains("google.android.apps.fitness") -> "Google Fit"
            packageName.contains("fitbit") -> "Fitbit"
            packageName.contains("garmin") -> "Garmin"
            packageName.contains("xiaomi") ||
            packageName.contains("miui") -> "Mi Fitness"
            else -> "Unknown Source"
        }
    }
}