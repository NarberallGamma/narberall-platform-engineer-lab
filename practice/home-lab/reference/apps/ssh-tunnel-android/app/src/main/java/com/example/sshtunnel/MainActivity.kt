package com.example.sshtunnel

import android.animation.AnimatorSet
import android.animation.ObjectAnimator
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Bundle
import android.os.IBinder
import android.view.animation.OvershootInterpolator
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.snackbar.Snackbar
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import com.example.sshtunnel.databinding.ActivityMainBinding
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.Socket

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private var service: TunnelService? = null
    private val conn = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, b: IBinder?) {
            service = (b as? TunnelService.LocalBinder)?.getService()
            updateUiState()
        }
        override fun onServiceDisconnected(name: ComponentName?) { service = null }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)
        setupClickListeners()
        updateAddress()
        updateUiState()
    }

    override fun onResume() {
        super.onResume()
        TunnelState.debugEnabled = TunnelConfig.load(this).debugLog
        TunnelState.listener = { updateUiState() }
        updateAddress()
        bindService(Intent(this, TunnelService::class.java), conn, 0)
        updateUiState()
    }

    override fun onPause() {
        TunnelState.listener = null
        try { unbindService(conn) } catch (_: Exception) { }
        service = null
        super.onPause()
    }

    override fun onDestroy() {
        TunnelState.listener = null
        super.onDestroy()
    }

    private fun setupClickListeners() {
        binding.btnStartStop.setOnClickListener {
            if (service != null) {
                // Stop immediately, no animation — avoid sending the app to the background
                service?.stopTunnels()
                try { unbindService(conn) } catch (_: Exception) { }
                service = null
                updateUiState()
            } else {
                animatePress(binding.btnStartStop) { startAndBindService() }
            }
        }
        binding.btnConfig.setOnClickListener {
            animatePress(it) { startActivity(Intent(this, ConfigActivity::class.java)) }
        }
        binding.btnLog.setOnClickListener {
            animatePress(it) { startActivity(Intent(this, LogActivity::class.java)) }
        }
        binding.btnStatus.setOnClickListener {
            animatePress(it) { startActivity(Intent(this, StatusActivity::class.java)) }
        }
        binding.btnTestTunnel.setOnClickListener {
            animatePress(it) { sendTestHello() }
        }
    }

    private fun animatePress(view: android.view.View, action: () -> Unit) {
        val scaleX = ObjectAnimator.ofFloat(view, "scaleX", 1f, 0.95f, 1f).apply { duration = 150 }
        val scaleY = ObjectAnimator.ofFloat(view, "scaleY", 1f, 0.95f, 1f).apply { duration = 150 }
        AnimatorSet().apply {
            playTogether(scaleX, scaleY)
            interpolator = OvershootInterpolator(1f)
            start()
            doOnEnd { action() }
        }
    }

    private fun AnimatorSet.doOnEnd(block: () -> Unit) {
        addListener(object : android.animation.Animator.AnimatorListener {
            override fun onAnimationEnd(animation: android.animation.Animator) { block() }
            override fun onAnimationStart(a: android.animation.Animator) {}
            override fun onAnimationCancel(a: android.animation.Animator) {}
            override fun onAnimationRepeat(a: android.animation.Animator) {}
        })
    }

    private fun startAndBindService() {
        val intent = Intent(this, TunnelService::class.java).apply { action = TunnelService.ACTION_START }
        ContextCompat.startForegroundService(this, intent)
        bindService(Intent(this, TunnelService::class.java), conn, Context.BIND_AUTO_CREATE)
        updateUiState()
    }

    private fun updateAddress() {
        val config = TunnelConfig.load(this)
        val port = config.balancerPort
        binding.addressLabel.text = if (port > 0) "127.0.0.1:$port" else "127.0.0.1:10808"
    }

    private fun updateUiState() {
        val running = service != null
        binding.statusLabel.text = if (running) getString(R.string.status_connected) else getString(R.string.status_disconnected)
        binding.btnStartStop.setBackgroundResource(if (running) R.drawable.bg_circle_connected else R.drawable.bg_circle_button)
        binding.centerIcon.setImageResource(if (running) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play)
        refreshTestTunnelButton()
    }

    private fun sendTestHello() {
        val config = TunnelConfig.load(this)
        val port = config.balancerPort
        if (port <= 0) return
        binding.btnTestTunnel.isEnabled = false
        lifecycleScope.launch {
            val result = withContext(Dispatchers.IO) {
                try {
                    Socket("127.0.0.1", port).use { s ->
                        s.soTimeout = 5000
                        s.getOutputStream().write("hello\n".toByteArray(Charsets.UTF_8))
                        s.getOutputStream().flush()
                    }
                    "Sent"
                } catch (e: Exception) {
                    "Error: ${e.message}"
                }
            }
            Snackbar.make(binding.root, result, Snackbar.LENGTH_SHORT).show()
            refreshTestTunnelButton()
        }
    }

    private fun refreshTestTunnelButton() {
        val config = TunnelConfig.load(this)
        val status = TunnelState.getTunnelStatus()
        val balancerUp = config.balancerPort > 0 && (status[config.balancerPort] == true)
        binding.btnTestTunnel.isEnabled = (service != null && balancerUp)
    }
}
