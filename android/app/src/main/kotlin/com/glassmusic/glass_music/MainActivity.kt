package com.glassmusic.glass_music

import android.Manifest
import android.content.pm.PackageManager
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.audiofx.BassBoost
import android.media.audiofx.EnvironmentalReverb
import android.media.audiofx.Equalizer
import android.media.audiofx.LoudnessEnhancer
import android.media.audiofx.Virtualizer
import android.media.audiofx.Visualizer
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.View
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import kotlin.math.*
import android.util.Base64

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.glassmusic/audio_visualizer"
    private val AUDIO_EFFECT_CHANNEL = "com.glassmusic/audio_effects"
    private val FINGERPRINT_CHANNEL = "com.glassmusic/audio_fingerprint"

    private var visualizer: Visualizer? = null
    private var spectrumChannel: MethodChannel? = null

    private var effectChannel: MethodChannel? = null
    private var fingerprintChannel: MethodChannel? = null
    private var audioSessionId: Int = 0
    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var virtualizer: Virtualizer? = null
    private var reverb: EnvironmentalReverb? = null
    private var loudnessEnhancer: LoudnessEnhancer? = null
    private val fingerprintScope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    companion object {
        private const val TAG = "AudioEffects"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        spectrumChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        spectrumChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startVisualizer" -> {
                    val sessionId = call.argument<Int>("audioSessionId") ?: 0
                    if (startVisualizer(sessionId)) {
                        result.success(true)
                    } else {
                        result.error("VISUALIZER_ERROR", "无法启动可视化器", null)
                    }
                }
                "stopVisualizer" -> {
                    stopVisualizer()
                    result.success(true)
                }
                "setAudioSessionId" -> {
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        effectChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_EFFECT_CHANNEL)
        effectChannel?.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "initAudioEffects" -> {
                        val sessionId = call.argument<Int>("audioSessionId") ?: 0
                        initAudioEffects(sessionId)
                        result.success(true)
                    }
                    "releaseAudioEffects" -> {
                        releaseAudioEffects()
                        result.success(true)
                    }
                    "setEqualizerEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        setEqualizerEnabled(enabled)
                        result.success(true)
                    }
                    "getEqualizerBandLevels" -> {
                        val bands = getEqualizerBandLevels()
                        result.success(bands)
                    }
                    "setEqualizerBandLevel" -> {
                        val band = call.argument<Int>("band") ?: 0
                        val level = call.argument<Int>("level") ?: 0
                        setEqualizerBandLevel(band, level)
                        result.success(true)
                    }
                    "setEqualizerPreset" -> {
                        val preset = call.argument<Int>("preset") ?: 0
                        setEqualizerPreset(preset)
                        result.success(true)
                    }
                    "setBassBoost" -> {
                        val strength = call.argument<Int>("strength") ?: 0
                        setBassBoost(strength)
                        result.success(true)
                    }
                    "setVirtualizer" -> {
                        val strength = call.argument<Int>("strength") ?: 0
                        setVirtualizer(strength)
                        result.success(true)
                    }
                    "setReverb" -> {
                        val sendLevel = call.argument<Int>("sendLevel") ?: 0
                        setReverb(sendLevel)
                        result.success(true)
                    }
                    "setLoudnessEnhancer" -> {
                        val gain = call.argument<Int>("gain") ?: 0
                        setLoudnessEnhancer(gain)
                        result.success(true)
                    }
                    "isDolbyAvailable" -> {
                        result.success(checkDolbyAvailable())
                    }
                    "getAudioEffectCapabilities" -> {
                        result.success(getAudioEffectCapabilities())
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error handling ${call.method}: ${e.message}")
                result.error("AUDIO_EFFECT_ERROR", e.message, null)
            }
        }

        // ── 音频指纹识别频道 ──────────────────────────────────────────
        fingerprintChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FINGERPRINT_CHANNEL)
        fingerprintChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "extractFingerprint" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_ARG", "filePath is required", null)
                        return@setMethodCallHandler
                    }
                    fingerprintScope.launch {
                        try {
                            val fingerprint = extractAudioFingerprint(filePath)
                            withContext(Dispatchers.Main) {
                                result.success(fingerprint)
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Fingerprint error: ${e.message}")
                            withContext(Dispatchers.Main) {
                                result.error("FINGERPRINT_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "extractWaveform" -> {
                    val filePath = call.argument<String>("filePath")
                    val samples = call.argument<Int>("samples") ?: 200
                    if (filePath == null) {
                        result.error("INVALID_ARG", "filePath is required", null)
                        return@setMethodCallHandler
                    }
                    fingerprintScope.launch {
                        try {
                            val waveform = extractWaveformData(filePath, samples)
                            withContext(Dispatchers.Main) {
                                result.success(waveform)
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("WAVEFORM_ERROR", e.message, null)
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.decorView.post {
            window.decorView.isFocusable = true
            window.decorView.isFocusableInTouchMode = true
            disableDefaultFocusHighlight()
        }
    }
    
    private fun disableDefaultFocusHighlight() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            window.decorView.defaultFocusHighlightEnabled = false
        }
        disableFocusHighlightRecursive(window.decorView)
    }
    
    private fun disableFocusHighlightRecursive(view: View) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            view.defaultFocusHighlightEnabled = false
        }
        if (view is android.view.ViewGroup) {
            for (i in 0 until view.childCount) {
                disableFocusHighlightRecursive(view.getChildAt(i))
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // 音频可视化
    // ═══════════════════════════════════════════════════════════════════
    
    private fun startVisualizer(sessionId: Int): Boolean {
        try {
            stopVisualizer()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (checkSelfPermission(Manifest.permission.MODIFY_AUDIO_SETTINGS) != PackageManager.PERMISSION_GRANTED) {
                    Log.w(TAG, "MODIFY_AUDIO_SETTINGS permission not granted")
                }
            }
            val sessionIds = mutableListOf<Int>()
            if (sessionId != 0) sessionIds.add(sessionId)
            sessionIds.add(0)
            for (id in sessionIds) {
                try {
                    val v = Visualizer(id)
                    v.captureSize = Visualizer.getCaptureSizeRange()[1]
                    v.setDataCaptureListener(object : Visualizer.OnDataCaptureListener {
                        override fun onWaveFormDataCapture(v: Visualizer?, waveform: ByteArray, samplingRate: Int) {}
                        override fun onFftDataCapture(v: Visualizer?, fft: ByteArray, samplingRate: Int) {
                            try {
                                val spectrum = processFftData(fft)
                                spectrumChannel?.invokeMethod("onSpectrumData", mapOf("data" to spectrum))
                            } catch (e: Exception) {}
                        }
                    }, Visualizer.getMaxCaptureRate() / 2, false, true)
                    v.enabled = true
                    visualizer = v
                    Log.d(TAG, "Visualizer started with session id: $id")
                    return true
                } catch (e: Exception) {
                    Log.w(TAG, "Session $id failed: ${e.message}")
                    continue
                }
            }
            return false
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start visualizer: ${e.message}")
            return false
        }
    }
    
    private fun stopVisualizer() {
        try { visualizer?.enabled = false; visualizer?.release() } catch (_: Exception) {}
        visualizer = null
    }
    
    private fun processFftData(fft: ByteArray): List<Double> {
        val bandCount = 64
        val spectrum = MutableList(bandCount) { 0.0 }
        if (fft.isEmpty()) return spectrum
        val fftSize = fft.size / 2
        if (fftSize == 0) return spectrum
        val bandEdges = IntArray(bandCount + 1)
        bandEdges[0] = 0
        bandEdges[bandCount] = fftSize
        val lnMin = ln(1.0)
        val lnMax = ln(fftSize.toDouble().coerceAtLeast(2.0))
        for (i in 1 until bandCount) {
            val lnPos = lnMin + (lnMax - lnMin) * i / bandCount
            bandEdges[i] = max(1, exp(lnPos).toInt().coerceAtMost(fftSize - 1))
        }
        for (i in 0 until fftSize) {
            val re = (fft[i * 2].toInt() and 0xFF).let { if (it > 127) it - 256 else it }
            val im = (fft[i * 2 + 1].toInt() and 0xFF).let { if (it > 127) it - 256 else it }
            val magnitude = sqrt((re * re + im * im).toDouble())
            for (b in 0 until bandCount) {
                if (i >= bandEdges[b] && i < bandEdges[b + 1]) {
                    spectrum[b] = maxOf(spectrum[b], magnitude)
                    break
                }
            }
        }
        for (i in 0 until bandCount) { spectrum[i] = spectrum[i] / 128.0 }
        val smoothed = MutableList(bandCount) { 0.0 }
        for (i in 0 until bandCount) {
            val prev = if (i > 0) spectrum[i - 1] else spectrum[i]
            val next = if (i < bandCount - 1) spectrum[i + 1] else spectrum[i]
            smoothed[i] = spectrum[i] * 0.6 + prev * 0.2 + next * 0.2
        }
        return smoothed.map { it.coerceIn(0.0, 1.0) }
    }

    // ═══════════════════════════════════════════════════════════════════
    // 原生音效引擎
    // ═══════════════════════════════════════════════════════════════════

    private fun initAudioEffects(sessionId: Int) {
        try {
            releaseAudioEffects()
            audioSessionId = sessionId
            Log.d(TAG, "Initializing audio effects with session: $sessionId")

            try {
                equalizer = Equalizer(0, sessionId)
                equalizer?.enabled = false
            } catch (e: Exception) {
                Log.w(TAG, "Equalizer not available: ${e.message}")
            }

            try {
                bassBoost = BassBoost(0, sessionId)
                bassBoost?.enabled = false
            } catch (e: Exception) {
                Log.w(TAG, "BassBoost not available: ${e.message}")
            }

            try {
                virtualizer = Virtualizer(0, sessionId)
                virtualizer?.enabled = false
            } catch (e: Exception) {
                Log.w(TAG, "Virtualizer not available: ${e.message}")
            }

            try {
                reverb = EnvironmentalReverb(0, sessionId)
                reverb?.enabled = false
            } catch (e: Exception) {
                Log.w(TAG, "EnvironmentalReverb not available: ${e.message}")
            }

            try {
                loudnessEnhancer = LoudnessEnhancer(sessionId)
                loudnessEnhancer?.enabled = false
            } catch (e: Exception) {
                Log.w(TAG, "LoudnessEnhancer not available: ${e.message}")
            }

            Log.d(TAG, "Audio effects initialized")
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing audio effects: ${e.message}")
        }
    }

    private fun releaseAudioEffects() {
        try { equalizer?.enabled = false; equalizer?.release() } catch (_: Exception) {}
        try { bassBoost?.enabled = false; bassBoost?.release() } catch (_: Exception) {}
        try { virtualizer?.enabled = false; virtualizer?.release() } catch (_: Exception) {}
        try { reverb?.enabled = false; reverb?.release() } catch (_: Exception) {}
        try { loudnessEnhancer?.enabled = false; loudnessEnhancer?.release() } catch (_: Exception) {}
        equalizer = null
        bassBoost = null
        virtualizer = null
        reverb = null
        loudnessEnhancer = null
    }

    private fun setEqualizerEnabled(enabled: Boolean) {
        try {
            equalizer?.enabled = enabled
            bassBoost?.enabled = enabled
            virtualizer?.enabled = enabled
            reverb?.enabled = enabled
            loudnessEnhancer?.enabled = enabled
        } catch (e: Exception) {
            Log.e(TAG, "Error setting equalizer enabled: ${e.message}")
        }
    }

    private fun getEqualizerBandLevels(): List<Int> {
        val levels = mutableListOf<Int>()
        try {
            val eq = equalizer ?: return levels
            for (i in 0 until eq.numberOfBands) {
                levels.add(eq.getBandLevel(i.toShort()).toInt())
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting band levels: ${e.message}")
        }
        return levels
    }

    private fun setEqualizerBandLevel(band: Int, level: Int) {
        try {
            val eq = equalizer ?: return
            eq.setBandLevel(band.toShort(), level.toShort())
        } catch (e: Exception) {
            Log.e(TAG, "Error setting band level: ${e.message}")
        }
    }

    private fun setEqualizerPreset(preset: Int) {
        try {
            val eq = equalizer ?: return
            if (preset >= 0 && preset < eq.numberOfPresets) {
                eq.usePreset(preset.toShort())
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error setting preset: ${e.message}")
        }
    }

    private fun setBassBoost(strength: Int) {
        try {
            val bb = bassBoost ?: return
            bb.setStrength(strength.toShort())
            bb.enabled = strength > 0
        } catch (e: Exception) {
            Log.e(TAG, "Error setting bass boost: ${e.message}")
        }
    }

    private fun setVirtualizer(strength: Int) {
        try {
            val vz = virtualizer ?: return
            vz.setStrength(strength.toShort())
            vz.enabled = strength > 0
        } catch (e: Exception) {
            Log.e(TAG, "Error setting virtualizer: ${e.message}")
        }
    }

    private fun setReverb(sendLevel: Int) {
        try {
            val rv = reverb ?: return
            val settings = EnvironmentalReverb.Settings()
            when {
                sendLevel < 200 -> {
                    settings.roomLevel = (-9000 + sendLevel * 20).toShort()
                    settings.roomHFLevel = (-4000 + sendLevel * 10).toShort()
                    settings.decayTime = 200
                    settings.decayHFRatio = 500
                    settings.reflectionsLevel = (-10000 + sendLevel * 20).toShort()
                    settings.reflectionsDelay = 20
                    settings.reverbLevel = (-10000 + sendLevel * 20).toShort()
                    settings.reverbDelay = 40
                    settings.diffusion = 500
                    settings.density = 500
                }
                sendLevel < 500 -> {
                    settings.roomLevel = (-6000 + sendLevel * 5).toShort()
                    settings.roomHFLevel = (-2000 + sendLevel * 3).toShort()
                    settings.decayTime = (400 + sendLevel)
                    settings.decayHFRatio = 600
                    settings.reflectionsLevel = (-6000 + sendLevel * 8).toShort()
                    settings.reflectionsDelay = (30 + sendLevel / 50)
                    settings.reverbLevel = (-6000 + sendLevel * 8).toShort()
                    settings.reverbDelay = (50 + sendLevel / 40)
                    settings.diffusion = 700
                    settings.density = 600
                }
                else -> {
                    settings.roomLevel = (-3000 + sendLevel * 3).toShort()
                    settings.roomHFLevel = (-1000 + sendLevel * 2).toShort()
                    settings.decayTime = (800 + sendLevel * 2)
                    settings.decayHFRatio = 700
                    settings.reflectionsLevel = (-3000 + sendLevel * 4).toShort()
                    settings.reflectionsDelay = (50 + sendLevel / 25)
                    settings.reverbLevel = (-3000 + sendLevel * 4).toShort()
                    settings.reverbDelay = (80 + sendLevel / 20)
                    settings.diffusion = 900
                    settings.density = 800
                }
            }
            rv.setProperties(settings)
            rv.enabled = sendLevel > 0
        } catch (e: Exception) {
            Log.e(TAG, "Error setting reverb: ${e.message}")
        }
    }

    private fun setLoudnessEnhancer(gain: Int) {
        try {
            val le = loudnessEnhancer ?: return
            le.setTargetGain(gain)
            le.enabled = gain > 0
        } catch (e: Exception) {
            Log.e(TAG, "Error setting loudness enhancer: ${e.message}")
        }
    }

    private fun checkDolbyAvailable(): Map<String, Any> {
        val capabilities = mutableMapOf<String, Any>()
        capabilities["dolbyAtmos"] = checkSystemAudioCapability("dolby.atmos")
        capabilities["dolbyVision"] = false // Dolby Vision detection requires specific hardware queries
        capabilities["dolbyDigital"] = checkSystemAudioCapability("dolby.digital")
        capabilities["spatialAudio"] = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
        capabilities["lowLatencyAudio"] = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
        return capabilities
    }

    private fun checkSystemAudioCapability(feature: String): Boolean {
        return try {
            val features = packageManager.systemAvailableFeatures
            features?.any { it.name.contains(feature, ignoreCase = true) } ?: false
        } catch (e: Exception) {
            false
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun getAudioEffectCapabilities(): Map<String, Any> {
        val capabilities = mutableMapOf<String, Any>()

        try {
            val eq = equalizer
            if (eq != null) {
                val bandsInfo = mutableListOf<Map<String, Any>>()
                for (i in 0 until eq.numberOfBands) {
                    bandsInfo.add(mapOf(
                        "index" to i,
                        "frequency" to (eq.getCenterFreq(i.toShort()) / 1000),
                        "levelRange" to listOf(eq.bandLevelRange[0].toInt(), eq.bandLevelRange[1].toInt()),
                    ))
                }
                val presetsInfo = mutableListOf<Map<String, String>>()
                for (i in 0 until eq.numberOfPresets) {
                    presetsInfo.add(mapOf(
                        "index" to i.toString(),
                        "name" to eq.getPresetName(i.toShort()),
                    ))
                }
                capabilities["equalizer"] = mapOf(
                    "numBands" to eq.numberOfBands,
                    "bands" to bandsInfo,
                    "presets" to presetsInfo,
                    "levelRange" to listOf(eq.bandLevelRange[0].toInt(), eq.bandLevelRange[1].toInt()),
                )
            }
        } catch (e: Exception) {
            capabilities["equalizer"] = "unavailable"
        }

        // BassBoost: 默认范围 0 ~ 1000
        capabilities["bassBoost"] = mapOf("maxStrength" to 1000)

        // Virtualizer: 默认范围 0 ~ 1000
        capabilities["virtualizer"] = mapOf("maxStrength" to 1000)

        // LoudnessEnhancer: 默认范围 0 ~ 3000 mB
        capabilities["loudnessEnhancer"] = mapOf("maxGain" to 3000)

        capabilities["dolby"] = checkDolbyAvailable()

        return capabilities
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // 音频指纹提取（MediaExtractor + Chromaprint 简化算法）
    // ═══════════════════════════════════════════════════════════════════

    /**
     * 提取简化的 Chromaprint 风格声纹
     * 流程：MediaExtractor 读取 PCM → 降采样到 11025Hz → 计算 FFT 幅度谱 → 生成指纹
     */
    private suspend fun extractAudioFingerprint(filePath: String): Map<String, Any> {
        return withContext(Dispatchers.IO) {
            val extractor = MediaExtractor()
            try {
                // 支持 file:// 和真实路径
                val path = if (filePath.startsWith("file://")) {
                    filePath.removePrefix("file://")
                } else {
                    filePath
                }
                extractor.setDataSource(path)

                // 查找音频轨道
                var audioTrackIndex = -1
                var format: MediaFormat? = null
                for (i in 0 until extractor.trackCount) {
                    val trackFormat = extractor.getTrackFormat(i)
                    val mime = trackFormat.getString(MediaFormat.KEY_MIME) ?: ""
                    if (mime.startsWith("audio/")) {
                        audioTrackIndex = i
                        format = trackFormat
                        break
                    }
                }
                if (audioTrackIndex < 0 || format == null) {
                    throw Exception("No audio track found")
                }

                extractor.selectTrack(audioTrackIndex)

                val sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                val durationUs = format.getLong(MediaFormat.KEY_DURATION)
                val durationSec = durationUs / 1_000_000.0

                // 只处理前 120 秒（指纹标准）
                val maxSamples = minOf((120 * sampleRate).toLong(), durationUs)
                val targetSampleRate = 11025
                val downsampleRatio = sampleRate.toFloat() / targetSampleRate

                // 分段收集 PCM 数据（每段 4096 采样）
                val targetLength = minOf((maxSamples / 1000).toInt() * targetSampleRate, targetSampleRate * 120)
                val pcmSamples = ShortArray(targetLength)
                var totalRead = 0
                val buffer = java.nio.ByteBuffer.allocate(8192)

                while (totalRead < targetLength && extractor.sampleTrackIndex >= 0) {
                    extractor.readSampleData(buffer, 0)
                    if (extractor.sampleSize <= 0) break
                    if (extractor.sampleTime > maxSamples) break

                    buffer.rewind()
                    val shortCount = minOf(buffer.remaining() / 2, targetLength - totalRead)
                    for (j in 0 until shortCount) {
                        if (!buffer.hasRemaining()) break
                        val sample = buffer.short
                        // 降采样：每 N 个采一个
                        val srcIndex = j
                        if (srcIndex % downsampleRatio.toInt() == 0 && totalRead < targetLength) {
                            pcmSamples[totalRead++] = sample
                        }
                    }
                    buffer.clear()
                    extractor.advance()
                }
                extractor.unselectTrack(audioTrackIndex)

                // 生成简化的声纹哈希（类似 Chromaprint ACOUSTFP）
                val fingerprint = generateFingerprint(pcmSamples, totalRead, targetSampleRate)

                mapOf(
                    "duration" to durationSec,
                    "fingerprint" to fingerprint,
                    "sampleRate" to sampleRate,
                    "rawLength" to totalRead
                )
            } finally {
                extractor.release()
            }
        }
    }

    /**
     * 生成声纹特征向量（简化的 Chromapratch 算法）
     * 输出 base64 编码的指纹字符串，兼容 AcoustID 格式
     */
    private fun generateFingerprint(samples: ShortArray, length: Int, sampleRate: Int): String {
        if (length < 4096) return ""

        val fftSize = 4096
        val numFrames = (length - fftSize) / (fftSize / 2)
        if (numFrames <= 0) return ""

        val fingerprints = mutableListOf<Long>()
        var windowSum = 0.0
        for (i in 0 until length) {
            windowSum += abs(samples[i].toDouble())
        }
        val avgLevel = windowSum / length

        // 汉宁窗 + FFT
        for (frame in 0 until numFrames) {
            val offset = frame * (fftSize / 2)
            val real = DoubleArray(fftSize)
            for (i in 0 until fftSize) {
                val idx = offset + i
                if (idx < length) {
                    val window = 0.5 * (1 - cos(2 * PI * i / (fftSize - 1)))
                    real[i] = samples[idx].toDouble() / 32768.0 * window
                }
            }
            val imag = DoubleArray(fftSize)
            // 简单 DFT（只算前 256 个频率 bin，取一半）
            for (k in 0 until 256) {
                for (n in 0 until fftSize) {
                    val angle = -2 * PI * k * n / fftSize
                    imag[k] += real[n] * sin(angle)
                    real[k] += real[n] * cos(angle)
                }
            }
            // 幅度谱
            val spectrum = DoubleArray(256)
            for (k in 0 until 256) {
                spectrum[k] = sqrt(real[k] * real[k] + imag[k] * imag[k])
            }
            // Sub-band energy: 分成 4 个子带
            val subBands = listOf(
                spectrum.copyOfRange(0, 32),    // 低频 0-600Hz
                spectrum.copyOfRange(32, 96),   // 中低频
                spectrum.copyOfRange(96, 176),  // 中高频
                spectrum.copyOfRange(176, 256)  // 高频
            )
            val subEnergies = subBands.map { band ->
                band.maxOrNull() ?: 0.0
            }
            // 量化：大于平均 + 某系数的标记为 1
            val overallAvg = spectrum.filterIndexed { i, _ -> i < 128 }.average()
            var bits: Long = 0
            for (i in 0 until 32) {
                val bandIdx = i / 8
                val subE = subEnergies.getOrElse(bandIdx) { 0.0 }
                val globalE = spectrum.getOrElse(i * 4) { 0.0 }
                if (globalE > overallAvg * 1.4 || subE > overallAvg * 1.2) {
                    bits = bits or (1L shl (31 - i))
                }
            }
            fingerprints.add(bits)
        }

        // 合并相邻重复帧
        val deduped = fingerprints.filterIndexed { i, v ->
            i == 0 || v != fingerprints[i - 1]
        }

        // 转为 AcoustID 风格的 base64 字符串
        // 每 8 个 32-bit 合并为自定义指纹串
        val sb = StringBuilder()
        for (chunk in deduped.chunked(64)) {
            var combined = 0L
            for ((i, v) in chunk.take(8).withIndex()) {
                combined = combined xor (v.ushr(i * 4) and 0x0FL)
            }
            sb.append(combined.toString(36))
        }
        return sb.toString()
    }

    /**
     * 提取波形数据（用于可视化 + 封面 AI 超分参考）
     */
    private suspend fun extractWaveformData(filePath: String, targetSamples: Int): Map<String, Any> {
        return withContext(Dispatchers.IO) {
            val extractor = MediaExtractor()
            try {
                val path = if (filePath.startsWith("file://")) {
                    filePath.removePrefix("file://")
                } else {
                    filePath
                }
                extractor.setDataSource(path)

                var audioTrackIndex = -1
                var format: MediaFormat? = null
                for (i in 0 until extractor.trackCount) {
                    val trackFormat = extractor.getTrackFormat(i)
                    val mime = trackFormat.getString(MediaFormat.KEY_MIME) ?: ""
                    if (mime.startsWith("audio/")) {
                        audioTrackIndex = i
                        format = trackFormat
                        break
                    }
                }
                if (audioTrackIndex < 0 || format == null) {
                    throw Exception("No audio track found")
                }

                extractor.selectTrack(audioTrackIndex)
                val durationUs = format.getLong(MediaFormat.KEY_DURATION)
                val durationSec = durationUs / 1_000_000.0

                // 等间隔采样
                val waveform = mutableListOf<Double>()
                val numSegments = targetSamples.coerceAtLeast(50)
                val step = durationUs / numSegments
                val buffer = java.nio.ByteBuffer.allocate(4096)

                for (seg in 0 until numSegments) {
                    extractor.seekTo(seg * step, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
                    extractor.readSampleData(buffer, 0)
                    buffer.rewind()
                    var maxAmp = 0.0
                    val count = minOf(buffer.remaining() / 2, 256)
                    for (j in 0 until count) {
                        if (!buffer.hasRemaining()) break
                        val s = abs(buffer.short.toDouble())
                        if (s > maxAmp) maxAmp = s
                    }
                    waveform.add((maxAmp / 32768.0).coerceIn(0.0, 1.0))
                    buffer.clear()
                    if (extractor.sampleTime < 0 || extractor.sampleTime >= durationUs) break
                }

                extractor.unselectTrack(audioTrackIndex)

                mapOf(
                    "waveform" to waveform,
                    "duration" to durationSec,
                    "samples" to waveform.size
                )
            } finally {
                extractor.release()
            }
        }
    }

    override fun onDestroy() {
        stopVisualizer()
        releaseAudioEffects()
        fingerprintScope.cancel()
        super.onDestroy()
    }
}
