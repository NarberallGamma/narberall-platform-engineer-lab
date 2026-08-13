package com.example.sshtunnel

import android.os.Bundle
import android.text.method.ScrollingMovementMethod
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import com.example.sshtunnel.databinding.ActivityLogBinding
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class LogActivity : AppCompatActivity() {

    private lateinit var binding: ActivityLogBinding

    private val saveLogLauncher = registerForActivityResult(ActivityResultContracts.CreateDocument("text/plain")) { uri ->
        if (uri != null) {
            try {
                contentResolver.openOutputStream(uri)?.use { out ->
                    out.write(TunnelState.getLogLines().joinToString("\n").toByteArray(Charsets.UTF_8))
                }
                Toast.makeText(this, getString(R.string.save_log) + " ✓", Toast.LENGTH_SHORT).show()
            } catch (e: Exception) {
                Toast.makeText(this, "Error: ${e.message}", Toast.LENGTH_SHORT).show()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityLogBinding.inflate(layoutInflater)
        setContentView(binding.root)
        binding.logText.movementMethod = ScrollingMovementMethod()
        TunnelState.listener = { refreshLog() }
        binding.btnBack.setOnClickListener { finish() }
        binding.btnRefresh.setOnClickListener {
            TunnelState.clearLog()
            refreshLog()
        }
        binding.btnSaveLog.setOnClickListener {
            val name = "ssh-tunnel-${SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date())}.log"
            saveLogLauncher.launch(name)
        }
        refreshLog()
    }

    override fun onDestroy() {
        TunnelState.listener = null
        super.onDestroy()
    }

    private fun refreshLog() {
        val lines = TunnelState.getLogLines()
        binding.logText.text = if (lines.isEmpty()) {
            "Log is empty. Start tunnels from the main screen."
        } else {
            lines.joinToString("\n")
        }
        if (lines.isNotEmpty()) {
            binding.logScroll.post { binding.logScroll.fullScroll(android.view.View.FOCUS_DOWN) }
        }
    }
}
