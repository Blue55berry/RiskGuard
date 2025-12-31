package com.example.personal

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.media.MediaRecorder
import android.os.Build
import android.os.Environment
import android.os.IBinder
import android.provider.Settings
import android.util.Log
import android.view.*
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
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
    
    // Audio recording
    private var mediaRecorder: MediaRecorder? = null
    private var isRecording = false
    private var recordingStartTime: Long = 0
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service created")
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
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
        val color = if (isSynthetic) Color.parseColor("#FF3D71") else Color.parseColor("#00D68F")
        
        overlayView?.let { view ->
            view.findViewWithTag<TextView>("ai_probability")?.apply {
                text = percentText
                setTextColor(color)
            }
            view.findViewWithTag<TextView>("ai_status")?.apply {
                text = statusText
                setTextColor(color)
            }
            view.findViewWithTag<LinearLayout>("ai_result_section")?.visibility = View.VISIBLE
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
            Log.d(TAG, "Overlay shown for: $currentPhoneNumber")
            
            // Auto-start recording when overlay is shown (call detected)
            startRecording()
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show overlay", e)
        }
    }
    
    private fun createFloatingIcon() {
        if (floatingIconView != null) return
        
        floatingIconView = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundResource(android.R.drawable.dialog_holo_dark_frame)
            setPadding(24, 24, 24, 24)
            
            addView(ImageView(context).apply {
                setImageResource(android.R.drawable.ic_menu_info_details)
                layoutParams = LinearLayout.LayoutParams(80, 80)
            })
        }
        
        val params = WindowManager.LayoutParams().apply {
            width = WindowManager.LayoutParams.WRAP_CONTENT
            height = WindowManager.LayoutParams.WRAP_CONTENT
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
            x = 16
            y = 200
        }
        
        floatingIconView?.setOnClickListener {
            toggleOverlayExpanded()
        }
        
        try {
            windowManager?.addView(floatingIconView, params)
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
            setBackgroundColor(Color.parseColor("#E61A1A2E"))
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
            
            // AI Result Section (hidden initially)
            addView(LinearLayout(context).apply {
                tag = "ai_result_section"
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                visibility = View.GONE
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    topMargin = 16
                }
                setBackgroundColor(Color.parseColor("#1A00D68F"))
                setPadding(16, 12, 16, 12)
                
                addView(TextView(context).apply {
                    text = "🤖 AI Voice:"
                    setTextColor(Color.parseColor("#B4B4C7"))
                    textSize = 14f
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        marginEnd = 12
                    }
                })
                
                addView(TextView(context).apply {
                    tag = "ai_probability"
                    text = "..."
                    setTextColor(Color.parseColor("#00D68F"))
                    textSize = 20f
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        marginEnd = 12
                    }
                })
                
                addView(TextView(context).apply {
                    tag = "ai_status"
                    text = "Analyzing..."
                    setTextColor(Color.parseColor("#B4B4C7"))
                    textSize = 12f
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
}
