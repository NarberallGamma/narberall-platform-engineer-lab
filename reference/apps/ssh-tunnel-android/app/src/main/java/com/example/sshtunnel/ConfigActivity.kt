package com.example.sshtunnel

import android.os.Bundle
import android.view.View
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.snackbar.Snackbar
import androidx.lifecycle.lifecycleScope
import com.example.sshtunnel.databinding.ActivityConfigBinding
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import net.schmizz.sshj.SSHClient
import net.schmizz.sshj.transport.verification.HostKeyVerifier
import java.io.File
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.security.PublicKey

class ConfigActivity : AppCompatActivity() {

    private lateinit var binding: ActivityConfigBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityConfigBinding.inflate(layoutInflater)
        setContentView(binding.root)
        loadConfig()
        binding.btnBack.setOnClickListener { finish() }
        binding.btnSave.setOnClickListener { save() }
        binding.btnPing.setOnClickListener { pingServer() }
        binding.btnTestSsh.setOnClickListener { testSsh() }
        binding.btnCheckPorts.setOnClickListener { checkPorts() }
    }

    private fun loadConfig() {
        val config = TunnelConfig.load(this)
        binding.host.setText(config.host)
        binding.port.setText(if (config.port > 0) config.port.toString() else "22")
        binding.user.setText(config.user)
        binding.localPorts.setText(
            if (config.localPorts.isEmpty()) "10809,10810,10811,10812,10813,10814"
            else config.localPorts.joinToString(",")
        )
        binding.remoteHost.setText(config.remoteHost.ifEmpty { "127.0.0.1" })
        binding.remotePort.setText(if (config.remotePort > 0) config.remotePort.toString() else "0")
        binding.balancerPort.setText(if (config.balancerPort > 0) config.balancerPort.toString() else "10808")
        binding.keepaliveInterval.setText(config.keepaliveIntervalSec.toString())
        binding.rotateInterval.setText(config.rotateIntervalMin.toString())
        binding.debugLog.isChecked = config.debugLog
        val keyFile = config.keyPath?.let { File(it) }
        if (keyFile != null && keyFile.exists() && keyFile.canRead()) {
            try {
                binding.keyContent.setText(keyFile.readText())
            } catch (_: Exception) {
                binding.keyContent.setText("")
            }
        } else {
            binding.keyContent.setText("")
        }
    }

    private fun save() {
        val host = binding.host.text.toString().trim()
        val portStr = binding.port.text.toString().trim()
        val port = portStr.toIntOrNull() ?: 0
        val user = binding.user.text.toString().trim()
        val keyContent = binding.keyContent.text.toString().trim()
        val portsStr = binding.localPorts.text.toString().trim()
        val localPorts = portsStr.split(",").mapNotNull { it.trim().toIntOrNull() }
        val remoteHost = binding.remoteHost.text.toString().trim()
        val remotePortStr = binding.remotePort.text.toString().trim()
        val remotePort = remotePortStr.toIntOrNull() ?: 0
        val balancerPortStr = binding.balancerPort.text.toString().trim()
        val balancerPort = balancerPortStr.toIntOrNull() ?: 0
        val rotateMin = binding.rotateInterval.text.toString().trim().toIntOrNull()?.coerceIn(1, 60) ?: 10
        val maxKeepaliveSec = minOf(600, rotateMin * 60)  // 10 min max; not longer than rotation
        val keepaliveSec = binding.keepaliveInterval.text.toString().trim().toIntOrNull()?.coerceIn(5, maxKeepaliveSec) ?: 20.coerceIn(5, maxKeepaliveSec)
        val debugLog = binding.debugLog.isChecked

        if (host.isEmpty() || user.isEmpty()) {
            Toast.makeText(this, "Host and User required", Toast.LENGTH_SHORT).show()
            return
        }
        if (keyContent.isEmpty()) {
            Toast.makeText(this, "Private key content required", Toast.LENGTH_SHORT).show()
            return
        }

        val keyFile = File(filesDir, "key")
        try {
            if (keyFile.exists() && !keyFile.canWrite()) keyFile.setWritable(true, true)
            keyFile.writeText(keyContent)
            keyFile.setReadable(true, true)
        } catch (e: Exception) {
            Toast.makeText(this, "Failed to save key: ${e.message}", Toast.LENGTH_SHORT).show()
            return
        }

        val config = TunnelConfig(
            host = host,
            port = port,
            user = user,
            keyPath = keyFile.absolutePath,
            password = null,
            localPorts = localPorts,
            remoteHost = remoteHost,
            remotePort = remotePort,
            balancerPort = balancerPort,
            debugLog = debugLog,
            keepaliveIntervalSec = keepaliveSec,
            rotateIntervalMin = rotateMin
        )
        TunnelConfig.save(this, config)
        Toast.makeText(this, "Saved", Toast.LENGTH_SHORT).show()
        finish()
    }

    private fun pingServer() {
        val host = binding.host.text.toString().trim()
        val portStr = binding.port.text.toString().trim()
        val port = portStr.toIntOrNull() ?: 22
        if (host.isEmpty()) {
            Toast.makeText(this, "Enter host first", Toast.LENGTH_SHORT).show()
            return
        }
        binding.btnPing.isEnabled = false
        lifecycleScope.launch {
            val result = withContext(Dispatchers.IO) {
                try {
                    Socket().use { s ->
                        s.connect(InetSocketAddress(host, port), 5000)
                    }
                    "Reachable"
                } catch (e: Exception) {
                    "Unreachable: ${e.message}"
                }
            }
            Snackbar.make(binding.root, result, Snackbar.LENGTH_LONG).show()
            binding.btnPing.isEnabled = true
        }
    }

    private fun checkPorts() {
        val portsStr = binding.localPorts.text.toString().trim()
        val ports = portsStr.split(",").mapNotNull { it.trim().toIntOrNull() }
        if (ports.isEmpty()) {
            binding.portsStatus.visibility = View.GONE
            Toast.makeText(this, "Enter ports first", Toast.LENGTH_SHORT).show()
            return
        }
        binding.btnCheckPorts.isEnabled = false
        binding.portsStatus.visibility = View.VISIBLE
        binding.portsStatus.text = "Checking…"
        lifecycleScope.launch {
            val results = withContext(Dispatchers.IO) {
                ports.map { port ->
                    port to try {
                        ServerSocket(port).use { }
                        true
                    } catch (e: Exception) {
                        false
                    }
                }
            }
            val lines = results.map { (p, free) ->
                "Port $p: ${if (free) "free" else "in use"}"
            }
            binding.portsStatus.text = lines.joinToString("\n")
            binding.btnCheckPorts.isEnabled = true
        }
    }

    private fun testSsh() {
        val host = binding.host.text.toString().trim()
        val portStr = binding.port.text.toString().trim()
        val port = portStr.toIntOrNull() ?: 22
        val user = binding.user.text.toString().trim()
        val keyContent = binding.keyContent.text.toString().trim()
        if (host.isEmpty() || user.isEmpty()) {
            Toast.makeText(this, "Host and User required", Toast.LENGTH_SHORT).show()
            return
        }
        if (keyContent.isEmpty()) {
            Toast.makeText(this, "Paste private key first", Toast.LENGTH_SHORT).show()
            return
        }
        if (!keyContent.contains("PRIVATE KEY") || !keyContent.contains("-----BEGIN") || !keyContent.contains("-----END")) {
            Toast.makeText(this, "Invalid key format: must contain -----BEGIN ... PRIVATE KEY----- and -----END ... PRIVATE KEY-----", Toast.LENGTH_LONG).show()
            return
        }
        binding.btnTestSsh.isEnabled = false
        lifecycleScope.launch {
            val result = withContext(Dispatchers.IO) {
                var keyFile: File? = null
                try {
                    keyFile = File.createTempFile("ssh_key_", "", cacheDir).apply {
                        writeText(keyContent)
                        setReadable(true, true)
                    }
                    val client = SshHelper.createClient()
                    client.addHostKeyVerifier(object : HostKeyVerifier {
                        override fun verify(hostname: String?, port: Int, key: PublicKey?): Boolean = true
                        override fun findExistingAlgorithms(hostname: String?, port: Int): MutableList<String> = mutableListOf()
                    })
                    client.connect(host, port)
                    client.authPublickey(user, client.loadKeys(keyFile.absolutePath))
                    client.disconnect()
                    "SSH OK"
                } catch (e: Exception) {
                    val msg = e.message?.toString() ?: "unknown"
                    val cleanMsg = msg.replace(Regex(" \\[B@[a-f0-9]+$"), "")
                    "SSH failed: $cleanMsg"
                } finally {
                    keyFile?.delete()
                }
            }
            Snackbar.make(binding.root, result, Snackbar.LENGTH_LONG).show()
            binding.btnTestSsh.isEnabled = true
        }
    }
}
