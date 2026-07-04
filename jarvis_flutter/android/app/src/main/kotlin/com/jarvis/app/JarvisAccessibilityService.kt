package com.jarvis.app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Path
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Toast
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class JarvisAccessibilityService : AccessibilityService() {

    companion object {
        private const val CHANNEL = "com.jarvis.app/accessibility"
        var instance: JarvisAccessibilityService? = null
            private set
        
        // Pending clipboard action
        private var pendingClipResponse: String? = null
    }

    private var methodChannel: MethodChannel? = null
    private var clipboardManager: ClipboardManager? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        clipboardManager = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    /**
     * Called by Flutter to bind the MethodChannel AFTER the engine is ready.
     */
    fun bindMethodChannel(engine: FlutterEngine) {
        methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            handleMethodCall(call, result)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        Toast.makeText(this, "JARVIS Accessibility Service aktiviert", Toast.LENGTH_SHORT).show()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Handle events if needed (e.g., detect app changes)
    }

    override fun onInterrupt() {
        // Service interrupted
    }

    // ─── Handle Flutter Method Calls ──────────────────────────────────

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "openAccessibilitySettings" -> openAccessibilitySettings()
            "isServiceEnabled" -> result.success(isAccessibilityServiceEnabled())
            "clickByText" -> {
                val text = call.argument<String>("text") ?: ""
                result.success(clickByText(text))
            }
            "clickById" -> {
                val id = call.argument<String>("id") ?: ""
                result.success(clickById(id))
            }
            "clickByContentDescription" -> {
                val desc = call.argument<String>("description") ?: ""
                result.success(clickByContentDescription(desc))
            }
            "typeText" -> {
                val text = call.argument<String>("text") ?: ""
                result.success(typeTextOnFocused(text))
            }
            "pasteText" -> {
                val text = call.argument<String>("text") ?: ""
                result.success(pasteTextToFocused(text))
            }
            "performGlobalAction" -> {
                val action = call.argument<String>("action") ?: ""
                result.success(performGlobalAction(action))
            }
            "getScreenContent" -> {
                result.success(getScreenContent())
            }
            "getFocusedText" -> {
                result.success(getFocusedText())
            }
            "scrollForward" -> result.success(scrollForward())
            "scrollBackward" -> result.success(scrollBackward())
            "tapAt" -> {
                val x = call.argument<Float>("x") ?: 0f
                val y = call.argument<Float>("y") ?: 0f
                result.success(tapAt(x, y))
            }
            "swipe" -> {
                val x1 = call.argument<Float>("x1") ?: 0f
                val y1 = call.argument<Float>("y1") ?: 0f
                val x2 = call.argument<Float>("x2") ?: 0f
                val y2 = call.argument<Float>("y2") ?: 0f
                result.success(performSwipe(x1, y1, x2, y2))
            }
            "openApp" -> {
                val packageName = call.argument<String>("packageName") ?: ""
                result.success(openApp(packageName))
            }
            "sendIntent" -> {
                val action = call.argument<String>("action") ?: ""
                val data = call.argument<String>("data") ?: ""
                result.success(sendIntent(action, data))
            }
            "setClipboard" -> {
                val text = call.argument<String>("text") ?: ""
                setClipboard(text)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    // ─── Core Actions ─────────────────────────────────────────────────

    private fun isAccessibilityServiceEnabled(): Boolean {
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabledServices.contains(packageName)
    }

    private fun openAccessibilitySettings() {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    /**
     * Find and click a UI element by its visible text.
     */
    private fun clickByText(text: String): Map<String, Any> {
        val root = rootInActiveWindow ?: return mapOf("success" to false, "error" to "No active window")
        val nodes = root.findAccessibilityNodeInfosByText(text)
        for (node in nodes) {
            if (node.isClickable) {
                node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                node.recycle()
                root.recycle()
                return mapOf("success" to true)
            }
            // Try parent if not clickable
            var parent = node.parent
            while (parent != null) {
                if (parent.isClickable) {
                    parent.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    parent.recycle()
                    node.recycle()
                    root.recycle()
                    return mapOf("success" to true)
                }
                val grandParent = parent.parent
                if (grandParent != null) {
                    parent.recycle()
                }
                parent = grandParent
            }
        }
        root.recycle()
        return mapOf("success" to false, "error" to "Element '$text' not found")
    }

    /**
     * Click an element by its view ID resource name.
     */
    private fun clickById(id: String): Map<String, Any> {
        val root = rootInActiveWindow ?: return mapOf("success" to false, "error" to "No active window")
        val nodes = findNodesById(root, id)
        for (node in nodes) {
            if (node.isClickable) {
                node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                node.recycle()
                root.recycle()
                return mapOf("success" to true)
            }
        }
        root.recycle()
        return mapOf("success" to false, "error" to "Element with id '$id' not found")
    }

    private fun findNodesById(node: AccessibilityNodeInfo, id: String): List<AccessibilityNodeInfo> {
        val result = mutableListOf<AccessibilityNodeInfo>()
        if (node.viewIdResourceName?.contains(id, ignoreCase = true) == true) {
            result.add(node)
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            result.addAll(findNodesById(child, id))
            child.recycle()
        }
        return result
    }

    /**
     * Click an element by its content description.
     */
    private fun clickByContentDescription(description: String): Map<String, Any> {
        val root = rootInActiveWindow ?: return mapOf("success" to false, "error" to "No active window")
        val nodes = findNodesByContentDescription(root, description)
        for (node in nodes) {
            if (node.isClickable) {
                node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                node.recycle()
                root.recycle()
                return mapOf("success" to true)
            }
        }
        root.recycle()
        return mapOf("success" to false, "error" to "Element with description '$description' not found")
    }

    private fun findNodesByContentDescription(node: AccessibilityNodeInfo, desc: String): List<AccessibilityNodeInfo> {
        val result = mutableListOf<AccessibilityNodeInfo>()
        if (node.contentDescription?.toString()?.contains(desc, ignoreCase = true) == true) {
            result.add(node)
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            result.addAll(findNodesByContentDescription(child, desc))
            child.recycle()
        }
        return result
    }

    /**
     * Type text into the currently focused element using ACTION_SET_TEXT.
     */
    private fun typeTextOnFocused(text: String): Map<String, Any> {
        val root = rootInActiveWindow ?: return mapOf("success" to false, "error" to "No active window")
        val focused = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT) ?: run {
            root.recycle()
            return mapOf("success" to false, "error" to "No focused input field")
        }
        
        val args = Bundle()
        args.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
        val success = focused.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
        focused.recycle()
        root.recycle()
        return mapOf("success" to success)
    }

    /**
     * Paste text to the focused element using clipboard.
     */
    private fun pasteTextToFocused(text: String): Map<String, Any> {
        // First copy to clipboard
        setClipboard(text)
        
        val root = rootInActiveWindow ?: return mapOf("success" to false, "error" to "No active window")
        val focused = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT) ?: run {
            root.recycle()
            return mapOf("success" to false, "error" to "No focused input field")
        }
        
        // Try ACTION_PASTE
        val success = focused.performAction(AccessibilityNodeInfo.ACTION_PASTE)
        focused.recycle()
        root.recycle()
        return mapOf("success" to success)
    }

    private fun setClipboard(text: String) {
        val clip = ClipData.newPlainText("JARVIS", text)
        clipboardManager?.setPrimaryClip(clip)
    }

    /**
     * Perform a global action (back, home, recents, notifications, quick settings).
     */
    private fun performGlobalAction(action: String): Map<String, Any> {
        val actionId = when (action.lowercase()) {
            "back" -> GLOBAL_ACTION_BACK
            "home" -> GLOBAL_ACTION_HOME
            "recents" -> GLOBAL_ACTION_RECENTS
            "notifications" -> GLOBAL_ACTION_NOTIFICATIONS
            "quick_settings" -> GLOBAL_ACTION_QUICK_SETTINGS
            "split_screen" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    GLOBAL_ACTION_TOGGLE_SPLIT_SCREEN
                } else null
            }
            else -> null
        }
        if (actionId == null) return mapOf("success" to false, "error" to "Unknown global action: $action")
        val success = performGlobalAction(actionId)
        return mapOf("success" to success)
    }

    /**
     * Get text content from the current screen.
     */
    private fun getScreenContent(): Map<String, Any> {
        val root = rootInActiveWindow ?: return mapOf("success" to false, "error" to "No active window", "text" to "")
        val textBuilder = StringBuilder()
        extractText(root, textBuilder)
        root.recycle()
        return mapOf("success" to true, "text" to textBuilder.toString())
    }

    private fun extractText(node: AccessibilityNodeInfo, builder: StringBuilder) {
        if (node.text != null) {
            builder.appendLine(node.text.toString())
        }
        if (node.contentDescription != null) {
            builder.appendLine("[${node.contentDescription}]")
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            extractText(child, builder)
            child.recycle()
        }
    }

    /**
     * Get text from the currently focused input field.
     */
    private fun getFocusedText(): Map<String, Any> {
        val root = rootInActiveWindow ?: return mapOf("success" to false, "error" to "No active window")
        val focused = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT) ?: run {
            root.recycle()
            return mapOf("success" to false, "error" to "No focused input", "text" to "")
        }
        val text = focused.text?.toString() ?: ""
        focused.recycle()
        root.recycle()
        return mapOf("success" to true, "text" to text)
    }

    /**
     * Scroll forward/next page.
     */
    private fun scrollForward(): Map<String, Any> {
        val root = rootInActiveWindow ?: return mapOf("success" to false, "error" to "No active window")
        val success = performActionOnScrollable(root, AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_FORWARD)
        root.recycle()
        return mapOf("success" to success)
    }

    private fun scrollBackward(): Map<String, Any> {
        val root = rootInActiveWindow ?: return mapOf("success" to false, "error" to "No active window")
        val success = performActionOnScrollable(root, AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_BACKWARD)
        root.recycle()
        return mapOf("success" to success)
    }

    private fun performActionOnScrollable(node: AccessibilityNodeInfo, action: AccessibilityNodeInfo.AccessibilityAction): Boolean {
        if (node.actionList.contains(action)) {
            return node.performAction(action.id)
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val success = performActionOnScrollable(child, action)
            child.recycle()
            if (success) return true
        }
        return false
    }

    /**
     * Simulate a tap at screen coordinates.
     */
    private fun tapAt(x: Float, y: Float): Map<String, Any> {
        val path = Path()
        path.moveTo(x, y)
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 50))
            .build()
        val success = dispatchGesture(gesture, null, null)
        return mapOf("success" to success)
    }

    /**
     * Simulate a swipe gesture.
     */
    private fun performSwipe(x1: Float, y1: Float, x2: Float, y2: Float): Map<String, Any> {
        val path = Path()
        path.moveTo(x1, y1)
        path.lineTo(x2, y2)
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 300))
            .build()
        val success = dispatchGesture(gesture, null, null)
        return mapOf("success" to success)
    }

    /**
     * Open an app by package name.
     */
    private fun openApp(packageName: String): Map<String, Any> {
        return try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                mapOf("success" to true)
            } else {
                mapOf("success" to false, "error" to "App $packageName not installed")
            }
        } catch (e: Exception) {
            mapOf("success" to false, "error" to e.message ?: "Unknown error")
        }
    }

    /**
     * Send an Android Intent.
     */
    private fun sendIntent(action: String, data: String): Map<String, Any> {
        return try {
            val intent = Intent(action).apply {
                this.data = android.net.Uri.parse(data)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            mapOf("success" to true)
        } catch (e: Exception) {
            mapOf("success" to false, "error" to e.message ?: "Unknown error")
        }
    }
}
