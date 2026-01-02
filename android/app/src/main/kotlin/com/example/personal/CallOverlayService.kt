package com.example.personal

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.media.MediaRecorder
import android.os.Build
import android.os.Environment
import android.os.IBinder
import android.provider.Settings
import android.text.InputType
import android.util.Log
import android.view.*
import android.widget.*
import androidx.core.app.NotificationCompat
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

/**
 * Foreground service that displays risk overlay during calls.
 * Uses SYSTEM_ALERT_WINDOW permission to show overlay on top of other apps.
 * Records call audio for AI analysis when call is active.
 */
class CallOverlayService : Service() {
    
    companion object {
        private const val TAG = "CallOverlayService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "riskguard_call_service"
        
        const val ACTION_SHOW_OVERLAY = "com.example.personal.SHOW_OVERLAY"
        const val ACTION_HIDE_OVERLAY = "com.example.personal.HIDE_OVERLAY"
        const val ACTION_UPDATE_OVERLAY = "com.example.personal.UPDATE_OVERLAY"
        const val ACTION_UPDATE_RISK = "com.example.personal.UPDATE_RISK"
        const val ACTION_START_RECORDING = "com.example.personal.START_RECORDING"
        const val ACTION_STOP_RECORDING = "com.example.personal.STOP_RECORDING"
        const val ACTION_UPDATE_AI_RESULT = "com.example.personal.UPDATE_AI_RESULT"
        const val ACTION_SHOW_POST_CALL_DETAILS = "com.example.personal.SHOW_POST_CALL_DETAILS"
        
        const val EXTRA_PHONE_NUMBER = "phone_number"
        const val EXTRA_IS_INCOMING = "is_incoming"
        const val EXTRA_RISK_SCORE = "risk_score"
        const val EXTRA_RISK_LEVEL = "risk_level"
        const val EXTRA_EXPLANATION = "explanation"
        const val EXTRA_AI_PROBABILITY = "ai_probability"
        const val EXTRA_AI_IS_SYNTHETIC = "ai_is_synthetic"
        
        var currentRecordingPath: String? = null
            private set
    }
    
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var floatingIconView: View? = null
    private var isOverlayVisible = false
    private var currentPhoneNumber: String = ""
    private var isIncomingCall = true
    
    // Contact database
    private lateinit var contactsDb: ContactsDatabase
    private var isKnownNumber = false
    
    // Audio recording
    private var mediaRecorder: MediaRecorder? = null
    private var isRecording = false
    private var recordingStartTime: Long = 0
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service created")
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        contactsDb = ContactsDatabase(this)
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service start command: ${intent?.action}")
        
        startForeground(NOTIFICATION_ID, createNotification())
        
        when (intent?.action) {
            ACTION_SHOW_OVERLAY -> {
                currentPhoneNumber = intent.getStringExtra(EXTRA_PHONE_NUMBER) ?: ""
                isIncomingCall = intent.getBooleanExtra(EXTRA_IS_INCOMING, true)
                showOverlay()
            }
            ACTION_HIDE_OVERLAY -> {
                stopRecording()
                hideOverlay()
                stopSelf()
            }
            ACTION_UPDATE_OVERLAY -> {
                currentPhoneNumber = intent.getStringExtra(EXTRA_PHONE_NUMBER) ?: currentPhoneNumber
                isIncomingCall = intent.getBooleanExtra(EXTRA_IS_INCOMING, isIncomingCall)
                updateOverlayContent()
            }
            ACTION_UPDATE_RISK -> {
                val score = intent.getIntExtra(EXTRA_RISK_SCORE, 0)
                val level = intent.getStringExtra(EXTRA_RISK_LEVEL) ?: "Unknown"
                val explanation = intent.getStringExtra(EXTRA_EXPLANATION) ?: ""
                updateRiskDisplay(score, level, explanation)
            }
            ACTION_START_RECORDING -> {
                startRecording()
            }
            ACTION_STOP_RECORDING -> {
                stopRecording()
            }
            ACTION_UPDATE_AI_RESULT -> {
                val probability = intent.getFloatExtra(EXTRA_AI_PROBABILITY, 0f)
                val isSynthetic = intent.getBooleanExtra(EXTRA_AI_IS_SYNTHETIC, false)
                updateAIResult(probability, isSynthetic)
            }
            ACTION_SHOW_POST_CALL_DETAILS -> {
                showPostCallDetails()
            }
        }
        
        return START_STICKY
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Service destroyed")
        stopRecording()
        hideOverlay()
    }
    
    // ========== Audio Recording ==========
    
    private fun startRecording() {
        if (isRecording) {
            Log.d(TAG, "Already recording")
            return
        }
        
        try {
            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
            val fileName = "call_recording_$timestamp.m4a"
            val recordingsDir = File(getExternalFilesDir(Environment.DIRECTORY_MUSIC), "recordings")
            if (!recordingsDir.exists()) {
                recordingsDir.mkdirs()
            }
            currentRecordingPath = File(recordingsDir, fileName).absolutePath
            
            mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }
            
            mediaRecorder?.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioSamplingRate(44100)
                setAudioEncodingBitRate(128000)
                setOutputFile(currentRecordingPath)
                prepare()
                start()
            }
            
            isRecording = true
            recordingStartTime = System.currentTimeMillis()
            updateRecordingStatus(true)
            
            Log.d(TAG, "Recording started: $currentRecordingPath")
            
            // Notify Flutter that recording started
            MethodChannelHandler.sendRecordingStarted(currentRecordingPath!!)
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start recording", e)
            isRecording = false
            currentRecordingPath = null
        }
    }
    
    private fun stopRecording() {
        if (!isRecording) {
            return
        }
        
        try {
            mediaRecorder?.apply {
                stop()
                release()
            }
            mediaRecorder = null
            isRecording = false
            
            val recordingPath = currentRecordingPath
            updateRecordingStatus(false)
            
            Log.d(TAG, "Recording stopped: $recordingPath")
            
            // Notify Flutter with the recording path for AI analysis
            recordingPath?.let {
                MethodChannelHandler.sendRecordingStopped(it)
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop recording", e)
            mediaRecorder?.release()
            mediaRecorder = null
            isRecording = false
        }
    }
    
    private fun updateRecordingStatus(recording: Boolean) {
        overlayView?.let { view ->
            view.findViewWithTag<LinearLayout>("recording_indicator")?.visibility = 
                if (recording) View.VISIBLE else View.GONE
        }
    }
    
    private fun updateAIResult(probability: Float, isSynthetic: Boolean) {
        val percentText = "${(probability * 100).toInt()}%"
        val statusText = if (isSynthetic) "⚠️ AI Voice Detected" else "✓ Human Voice"
        val color = if (isSynthetic) Color.parseColor("#EF4444") else Color.parseColor("#10B981") // Modern theme colors
        
        overlayView?.let { view ->
            view.findViewWithTag<TextView>("ai_probability")?.apply {
                text = percentText
                setTextColor(color)
            }
            view.findViewWithTag<TextView>("ai_status")?.apply {
                text = statusText
                setTextColor(color)
            }
            view.findViewWithTag<LinearLayout>("ai_result_section")?.apply {
                visibility = View.VISIBLE
                setBackgroundColor(if (isSynthetic) Color.parseColor("#1AEF4444") else Color.parseColor("#1A10B981"))
            }
        }
    }
    
    // ========== Notification ==========
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "RiskGuard Call Protection",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows when RiskGuard is protecting your calls"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )
        
        val recordingText = if (isRecording) " • Recording" else ""
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("RiskGuard Active")
            .setContentText("Protecting your call$recordingText")
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
    
    // ========== Overlay ==========
    
    private fun canDrawOverlay(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }
    
    private fun showOverlay() {
        if (!canDrawOverlay()) {
            Log.w(TAG, "Cannot draw overlay - permission not granted")
            return
        }
        
        if (isOverlayVisible) {
            updateOverlayContent()
            return
        }
        
        try {
            createFloatingIcon()
            createMainOverlay()
            isOverlayVisible = true
            
            // Check if number is known
            isKnownNumber = contactsDb.isKnownNumber(currentPhoneNumber)
            Log.d(TAG, "Overlay shown for: $currentPhoneNumber (known: $isKnownNumber)")
            
            // Auto-start recording when overlay is shown (call detected)
            startRecording()
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show overlay", e)
        }
    }
    
    private fun createFloatingIcon() {
        if (floatingIconView != null) return
        
        // Create a modern circular floating action button
        val iconSize = (56 * resources.displayMetrics.density).toInt() // 56dp FAB size
        
        floatingIconView = FrameLayout(this).apply {
            layoutParams = FrameLayout.LayoutParams(iconSize, iconSize)
            
            // Create gradient background
            val gradientDrawable = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                colors = intArrayOf(
                    Color.parseColor("#8B5CF6"), // Purple
                    Color.parseColor("#6366F1")  // Indigo
                )
                gradientType = GradientDrawable.LINEAR_GRADIENT
            }
            background = gradientDrawable
            elevation = 8f
            
            // Add shield icon
            addView(ImageView(context).apply {
                setImageResource(android.R.drawable.ic_menu_info_details)
                setColorFilter(Color.WHITE)
                layoutParams = FrameLayout.LayoutParams(
                    (32 * resources.displayMetrics.density).toInt(),
                    (32 * resources.displayMetrics.density).toInt(),
                    Gravity.CENTER
                )
            })
            
            // Add saved indicator badge if contact is known
            if (isKnownNumber) {
                addView(View(context).apply {
                    val badgeSize = (12 * resources.displayMetrics.density).toInt()
                    layoutParams = FrameLayout.LayoutParams(badgeSize, badgeSize).apply {
                        gravity = Gravity.TOP or Gravity.END
                        topMargin = (4 * resources.displayMetrics.density).toInt()
                        marginEnd = (4 * resources.displayMetrics.density).toInt()
                    }
                    val badgeDrawable = GradientDrawable().apply {
                        shape = GradientDrawable.OVAL
                        setColor(Color.parseColor("#10B981")) // Green
                    }
                    background = badgeDrawable
                })
            }
        }
        
        val params = WindowManager.LayoutParams().apply {
            width = iconSize
            height = iconSize
            type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
            flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
            format = PixelFormat.TRANSLUCENT
            gravity = Gravity.TOP or Gravity.END
            x = (16 * resources.displayMetrics.density).toInt()
            y = (200 * resources.displayMetrics.density).toInt()
        }
        
        // Make icon draggable
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        
        floatingIconView?.setOnTouchListener { v, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    params.x = initialX + (initialTouchX - event.rawX).toInt()
                    params.y = initialY + (event.rawY - initialTouchY).toInt()
                    windowManager?.updateViewLayout(floatingIconView, params)
                    true
                }
                MotionEvent.ACTION_UP -> {
                    // If movement was minimal, treat as click
                    val deltaX = Math.abs(initialTouchX - event.rawX)
                    val deltaY = Math.abs(initialTouchY - event.rawY)
                    if (deltaX < 10 && deltaY < 10) {
                        showContactFormPopup()
                    }
                    true
                }
                else -> false
            }
        }
        
        try {
            windowManager?.addView(floatingIconView, params)
            Log.d(TAG, "Floating icon added to window")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to add floating icon", e)
        }
    }
    
    private fun createMainOverlay() {
        if (overlayView != null) return
        
        overlayView = createOverlayLayout()
        
        val params = WindowManager.LayoutParams().apply {
            width = WindowManager.LayoutParams.MATCH_PARENT
            height = WindowManager.LayoutParams.WRAP_CONTENT
            type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
            flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
            format = PixelFormat.TRANSLUCENT
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = 100
        }
        
        try {
            windowManager?.addView(overlayView, params)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to add main overlay", e)
        }
    }
    
    private fun createOverlayLayout(): View {
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#E62D2A3E")) // Modern purple from theme
            setPadding(48, 32, 48, 32)
            
            // Header
            addView(LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                
                addView(ImageView(context).apply {
                    setImageResource(android.R.drawable.ic_menu_call)
                    layoutParams = LinearLayout.LayoutParams(64, 64).apply {
                        marginEnd = 24
                    }
                })
                
                addView(LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL
                    
                    addView(TextView(context).apply {
                        tag = "title"
                        text = if (isIncomingCall) "Incoming Call" else "Outgoing Call"
                        setTextColor(Color.WHITE)
                        textSize = 18f
                    })
                    
                    addView(TextView(context).apply {
                        tag = "phone_number"
                        text = formatPhoneNumber(currentPhoneNumber)
                        setTextColor(Color.parseColor("#B4B4C7"))
                        textSize = 14f
                    })
                })
            })
            
            // Recording Indicator
            addView(LinearLayout(context).apply {
                tag = "recording_indicator"
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                visibility = View.GONE
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    topMargin = 16
                }
                
                addView(View(context).apply {
                    setBackgroundColor(Color.parseColor("#FF3D71"))
                    layoutParams = LinearLayout.LayoutParams(16, 16).apply {
                        marginEnd = 12
                    }
                })
                
                addView(TextView(context).apply {
                    text = "🎙️ Recording for AI Analysis..."
                    setTextColor(Color.parseColor("#FF3D71"))
                    textSize = 12f
                })
            })
            
            // Divider
            addView(View(context).apply {
                setBackgroundColor(Color.parseColor("#33FFFFFF"))
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    2
                ).apply {
                    topMargin = 24
                    bottomMargin = 24
                }
            })
            
            // Risk Score Section
            addView(LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                
                addView(TextView(context).apply {
                    tag = "risk_score"
                    text = "..."
                    setTextColor(Color.parseColor("#00D68F"))
                    textSize = 48f
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        marginEnd = 24
                    }
                })
                
                addView(LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL
                    
                    addView(TextView(context).apply {
                        tag = "risk_level"
                        text = "ANALYZING..."
                        setTextColor(Color.parseColor("#00D68F"))
                        textSize = 14f
                    })
                    
                    addView(TextView(context).apply {
                        tag = "explanation"
                        text = "Checking call risk..."
                        setTextColor(Color.parseColor("#B4B4C7"))
                        textSize = 12f
                    })
                })
            })
            
            // AI Voice Detection Section (ALWAYS VISIBLE - shows progress)
            addView(LinearLayout(context).apply {
                tag = "ai_result_section"
                orientation = LinearLayout.VERTICAL
                setBackgroundColor(Color.parseColor("#1A8B5CF6")) // Purple tint
                setPadding(24, 20, 24, 20)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    topMargin = 20
                }
                
                // Header
                addView(LinearLayout(context).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                    
                    addView(TextView(context).apply {
                        text = "🤖 AI Voice Analysis"
                        setTextColor(Color.parseColor("#8B5CF6")) // Purple
                        textSize = 16f
                        layoutParams = LinearLayout.LayoutParams(
                            0,
                            LinearLayout.LayoutParams.WRAP_CONTENT,
                            1f
                        )
                    })
                })
                
                // Status and Probability
                addView(LinearLayout(context).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        topMargin = 12
                    }
                    
                    addView(TextView(context).apply {
                        tag = "ai_status"
                        text = "🔄 Analyzing..."
                        setTextColor(Color.parseColor("#06B6D4")) // Cyan
                        textSize = 18f
                        layoutParams = LinearLayout.LayoutParams(
                            0,
                            LinearLayout.LayoutParams.WRAP_CONTENT,
                            1f
                        )
                    })
                    
                    addView(TextView(context).apply {
                        tag = "ai_probability"
                        text = "---"
                        setTextColor(Color.parseColor("#F9FAFB"))
                        textSize = 24f
                    })
                })
            })
            
            // Close button
            addView(TextView(context).apply {
                text = "✕ Dismiss"
                setTextColor(Color.parseColor("#8F9BB3"))
                textSize = 12f
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    topMargin = 24
                }
                setOnClickListener {
                    overlayView?.visibility = View.GONE
                }
            })
        }
    }
    
    private fun toggleOverlayExpanded() {
        overlayView?.let { view ->
            view.visibility = if (view.visibility == View.VISIBLE) View.GONE else View.VISIBLE
        }
    }
    
    private fun updateOverlayContent() {
        overlayView?.let { view ->
            view.findViewWithTag<TextView>("title")?.text = 
                if (isIncomingCall) "Incoming Call" else "Outgoing Call"
            view.findViewWithTag<TextView>("phone_number")?.text = 
                formatPhoneNumber(currentPhoneNumber)
        }
    }
    
    private fun updateRiskDisplay(score: Int, level: String, explanation: String) {
        val color = when {
            score <= 30 -> Color.parseColor("#00D68F")  // Green
            score <= 70 -> Color.parseColor("#FFAA00")  // Amber
            else -> Color.parseColor("#FF3D71")         // Red
        }
        
        overlayView?.let { view ->
            view.findViewWithTag<TextView>("risk_score")?.apply {
                text = score.toString()
                setTextColor(color)
            }
            view.findViewWithTag<TextView>("risk_level")?.apply {
                text = level.uppercase()
                setTextColor(color)
            }
            view.findViewWithTag<TextView>("explanation")?.text = explanation
        }
    }
    
    private fun hideOverlay() {
        try {
            overlayView?.let { 
                windowManager?.removeView(it)
                overlayView = null
            }
            floatingIconView?.let {
                windowManager?.removeView(it)
                floatingIconView = null
            }
            isOverlayVisible = false
            Log.d(TAG, "Overlay hidden")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to hide overlay", e)
        }
    }
    
    private fun formatPhoneNumber(number: String): String {
        return if (number.length >= 10) {
            val cleaned = number.replace(Regex("[^0-9+]"), "")
            if (cleaned.startsWith("+")) {
                "${cleaned.substring(0, 3)} ${cleaned.substring(3, 8)} ${cleaned.substring(8)}"
            } else {
                "${cleaned.substring(0, 5)} ${cleaned.substring(5)}"
            }
        } else {
            number
        }
    }
    
    /**
     * Update risk score from external source (called via MethodChannel)
     */
    fun updateRisk(score: Int, level: String, explanation: String) {
        updateRiskDisplay(score, level, explanation)
    }
    
    /**
     * Show contact form popup when floating icon is clicked
     */
    private fun showContactFormPopup() {
        // Check if contact already exists
        val existingContact = contactsDb.getContactByPhone(currentPhoneNumber)
        
        if (existingContact != null) {
            // Show existing contact details with edit option
            showSavedContactDetails(existingContact)
            return
        }
        
        // Create dialog layout
        val dialogView = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(60, 40, 60, 40)
            setBackgroundColor(Color.WHITE)
            
            // Title
            addView(TextView(context).apply {
                text = "Save Caller Information"
                textSize = 20f
                setTextColor(Color.parseColor("#2D2A3E"))
                setPadding(0, 0, 0, 32)
            })
            
            // Name field
            addView(TextView(context).apply {
                text = "Name"
                textSize = 14f
                setTextColor(Color.parseColor("#6B7280"))
                setPadding(0, 16, 0, 8)
            })
            val nameInput = EditText(context).apply {
                hint = "Enter name"
                tag = "name_input"
                setBackgroundResource(android.R.drawable.edit_text)
                setPadding(24, 24, 24, 24)
            }
            addView(nameInput)
            
            // Email field
            addView(TextView(context).apply {
                text = "Email"
                textSize = 14f
                setTextColor(Color.parseColor("#6B7280"))
                setPadding(0, 16, 0, 8)
            })
            val emailInput = EditText(context).apply {
                hint = "Enter email"
                tag = "email_input"
                inputType = InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS
                setBackgroundResource(android.R.drawable.edit_text)
                setPadding(24, 24, 24, 24)
            }
            addView(emailInput)
            
            // Category field
            addView(TextView(context).apply {
                text = "Category"
                textSize = 14f
                setTextColor(Color.parseColor("#6B7280"))
                setPadding(0, 16, 0, 8)
            })
            val categories = arrayOf(
                "Unknown Caller",
                "Business Contact",
                "Personal Contact",
                "Potential Spam",
                "Verified Safe"
            )
            val categorySpinner = Spinner(context).apply {
                tag = "category_spinner"
                adapter = ArrayAdapter(context, android.R.layout.simple_spinner_item, categories).apply {
                    setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
                }
                setBackgroundResource(android.R.drawable.edit_text)
                setPadding(16, 16, 16, 16)
            }
            addView(categorySpinner)
            
            // Buttons
            addView(LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.END
                setPadding(0, 32, 0, 0)
                
                // Cancel button
                addView(Button(context).apply {
                    text = "Cancel"
                    setTextColor(Color.parseColor("#6B7280"))
                    setBackgroundColor(Color.TRANSPARENT)
                    setOnClickListener {
                        // Dialog will be dismissed
                    }
                })
                
                // Save button
                addView(Button(context).apply {
                    text = "Save"
                    setTextColor(Color.WHITE)
                    setBackgroundColor(Color.parseColor("#8B5CF6"))
                    setPadding(48, 24, 48, 24)
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        marginStart = 16
                    }
                    setOnClickListener {
                        val name = nameInput.text.toString().trim()
                        val email = emailInput.text.toString().trim()
                        val category = categorySpinner.selectedItem.toString()
                        
                        if (name.isNotEmpty()) {
                            // Save to database
                            val saved = contactsDb.saveContact(
                                phoneNumber = currentPhoneNumber,
                                name = name,
                                email = if (email.isNotEmpty()) email else null,
                                category = category,
                                company = null,
                                notes = null,
                                tags = null
                            )
                            
                            if (saved) {
                                isKnownNumber = true
                                Log.d(TAG, "Contact saved successfully")
                                
                                // Notify Flutter about the saved contact
                                MethodChannelHandler.sendContactSaved(currentPhoneNumber, name, email, category)
                                
                                // Show toast
                                Toast.makeText(
                                    this@CallOverlayService,
                                    "Contact saved: $name",
                                    Toast.LENGTH_SHORT
                                ).show()
                                
                                // Update floating icon to show saved badge
                                recreateFloatingIcon()
                            }
                        } else {
                            Toast.makeText(
                                this@CallOverlayService,
                                "Please enter a name",
                                Toast.LENGTH_SHORT
                            ).show()
                        }
                    }
                })
            })
        }
        
        // Create dialog
        val dialog = AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog)
            .setView(dialogView)
            .create()
        
        // Make it system overlay
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            dialog.window?.setType(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY)
        } else {
            @Suppress("DEPRECATION")
            dialog.window?.setType(WindowManager.LayoutParams.TYPE_SYSTEM_ALERT)
        }
        
        dialog.show()
    }
    
    /**
     * Show saved contact details with edit option
     */
    private fun showSavedContactDetails(contact: SavedContact) {
        val dialogView = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(60, 40, 60, 40)
            setBackgroundColor(Color.WHITE)
            
            // Title
            addView(TextView(context).apply {
                text = contact.name ?: "Unknown"
                textSize = 24f
                setTextColor(Color.parseColor("#2D2A3E"))
                setPadding(0, 0, 0, 16)
            })
            
            // Phone number
            addView(TextView(context).apply {
                text = formatPhoneNumber(contact.phoneNumber)
                textSize = 16f
                setTextColor(Color.parseColor("#6B7280"))
                setPadding(0, 0, 0, 8)
            })
            
            // Email
            contact.email?.let { email ->
                addView(TextView(context).apply {
                    text = "📧 $email"
                    textSize = 14f
                    setTextColor(Color.parseColor("#6B7280"))
                    setPadding(0, 8, 0, 8)
                })
            }
            
            // Category badge
            contact.category?.let { category ->
                addView(TextView(context).apply {
                    text = category
                    textSize = 12f
                    setTextColor(Color.WHITE)
                    setBackgroundColor(Color.parseColor("#8B5CF6"))
                    setPadding(20, 8, 20, 8)
                    gravity = Gravity.CENTER
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        topMargin = 16
                    }
                })
            }
            
            // Buttons row
            addView(LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.END
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    topMargin = 24
                }
                
                // Edit button
                addView(Button(context).apply {
                    text = "Edit"
                    setTextColor(Color.parseColor("#8B5CF6"))
                    setBackgroundColor(Color.TRANSPARENT)
                    setOnClickListener { view ->
                        // Find and dismiss the dialog
                        var parent = view.parent
                        while (parent != null) {
                            if (parent is android.app.Dialog) {
                                parent.dismiss()
                                break
                            }
                            parent = (parent as? android.view.View)?.parent
                        }
                        showEditContactDialog(contact)
                    }
                })
                
                // Close button
                addView(Button(context).apply {
                    text = "Close"
                    setTextColor(Color.WHITE)
                    setBackgroundColor(Color.parseColor("#8B5CF6"))
                    setPadding(48, 24, 48, 24)
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        marginStart = 16
                    }
                    setOnClickListener { view ->
                        var parent = view.parent
                        while (parent != null) {
                            if (parent is android.app.Dialog) {
                                parent.dismiss()
                                break
                            }
                            parent = (parent as? android.view.View)?.parent
                        }
                    }
                })
            })
        }
        
        val dialog = AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog)
            .setView(dialogView)
            .create()
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            dialog.window?.setType(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY)
        } else {
            @Suppress("DEPRECATION")
            dialog.window?.setType(WindowManager.LayoutParams.TYPE_SYSTEM_ALERT)
        }
        
        dialog.show()
    }
    
    /**
     * Show edit contact dialog with pre-filled data
     */
    private fun showEditContactDialog(contact: SavedContact) {
        // Create dialog layout
        val dialogView = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(60, 40, 60, 40)
            setBackgroundColor(Color.WHITE)
            
            // Title
            addView(TextView(context).apply {
                text = "Edit Contact Information"
                textSize = 20f
                setTextColor(Color.parseColor("#2D2A3E"))
                setPadding(0, 0, 0, 32)
            })
            
            // Name field
            addView(TextView(context).apply {
                text = "Name"
                textSize = 14f
                setTextColor(Color.parseColor("#6B7280"))
                setPadding(0, 16, 0, 8)
            })
            val nameInput = EditText(context).apply {
                hint = "Enter name"
                setText(contact.name ?: "")
                tag = "name_input"
                setBackgroundResource(android.R.drawable.edit_text)
                setPadding(24, 24, 24, 24)
            }
            addView(nameInput)
            
            // Email field
            addView(TextView(context).apply {
                text = "Email"
                textSize = 14f
                setTextColor(Color.parseColor("#6B7280"))
                setPadding(0, 16, 0, 8)
            })
            val emailInput = EditText(context).apply {
                hint = "Enter email"
                setText(contact.email ?: "")
                tag = "email_input"
                inputType = InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS
                setBackgroundResource(android.R.drawable.edit_text)
                setPadding(24, 24, 24, 24)
            }
            addView(emailInput)
            
            // Category field
            addView(TextView(context).apply {
                text = "Category"
                textSize = 14f
                setTextColor(Color.parseColor("#6B7280"))
                setPadding(0, 16, 0, 8)
            })
            val categories = arrayOf(
                "Unknown Caller",
                "Business Contact",
                "Personal Contact",
                "Potential Spam",
                "Verified Safe"
            )
            val categorySpinner = Spinner(context).apply {
                tag = "category_spinner"
                adapter = ArrayAdapter(context, android.R.layout.simple_spinner_item, categories).apply {
                    setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
                }
                // Set current selection
                val currentCategory = contact.category ?: "Unknown Caller"
                val position = categories.indexOf(currentCategory)
                if (position >= 0) {
                    setSelection(position)
                }
                setBackgroundResource(android.R.drawable.edit_text)
                setPadding(16, 16, 16, 16)
            }
            addView(categorySpinner)
            
            // Buttons
            addView(LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.END
                setPadding(0, 32, 0, 0)
                
                // Cancel button
                addView(Button(context).apply {
                    text = "Cancel"
                    setTextColor(Color.parseColor("#6B7280"))
                    setBackgroundColor(Color.TRANSPARENT)
                    setOnClickListener { view ->
                        var parent = view.parent
                        while (parent != null) {
                            if (parent is android.app.Dialog) {
                                parent.dismiss()
                                break
                            }
                            parent = (parent as? android.view.View)?.parent
                        }
                    }
                })
                
                // Save button
                addView(Button(context).apply {
                    text = "Save Changes"
                    setTextColor(Color.WHITE)
                    setBackgroundColor(Color.parseColor("#8B5CF6"))
                    setPadding(48, 24, 48, 24)
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        marginStart = 16
                    }
                    setOnClickListener { view ->
                        val name = nameInput.text.toString().trim()
                        val email = emailInput.text.toString().trim()
                        val category = categorySpinner.selectedItem.toString()
                        
                        if (name.isNotEmpty()) {
                            // Update in database
                            val updated = contactsDb.updateContact(
                                phoneNumber = contact.phoneNumber,
                                name = name,
                                email = if (email.isNotEmpty()) email else null,
                                category = category,
                                company = contact.company,
                                notes = contact.notes,
                                tags = contact.tags
                            )
                            
                            if (updated) {
                                Log.d(TAG, "Contact updated successfully")
                                
                                // Notify Flutter about the update
                                MethodChannelHandler.sendContactUpdated(
                                    contact.phoneNumber,
                                    name,
                                    if (email.isNotEmpty()) email else null,
                                    category
                                )
                                
                                // Show toast
                                Toast.makeText(
                                    this@CallOverlayService,
                                    "Contact updated successfully",
                                    Toast.LENGTH_SHORT
                                ).show()
                                
                                // Update floating icon if needed
                                recreateFloatingIcon()
                                
                                // Dismiss dialog
                                var parent = view.parent
                                while (parent != null) {
                                    if (parent is android.app.Dialog) {
                                        parent.dismiss()
                                        break
                                    }
                                    parent = (parent as? android.view.View)?.parent
                                }
                            }
                        } else {
                            Toast.makeText(
                                this@CallOverlayService,
                                "Please enter a name",
                                Toast.LENGTH_SHORT
                            ).show()
                        }
                    }
                })
            })
        }
        
        // Create dialog
        val dialog = AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog)
            .setView(dialogView)
            .create()
        
        // Make it system overlay
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            dialog.window?.setType(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY)
        } else {
            @Suppress("DEPRECATION")
            dialog.window?.setType(WindowManager.LayoutParams.TYPE_SYSTEM_ALERT)
        }
        
        dialog.show()
    }
    
    /**
     * Show post-call details after call ends
     */
    private fun showPostCallDetails() {
        val contact = contactsDb.getContactByPhone(currentPhoneNumber)
        if (contact != null) {
            showSavedContactDetails(contact)
        }
    }
    
    /**
     * Recreate floating icon to update badge
     */
    private fun recreateFloatingIcon() {
        floatingIconView?.let {
            windowManager?.removeView(it)
            floatingIconView = null
        }
        createFloatingIcon()
    }
}
