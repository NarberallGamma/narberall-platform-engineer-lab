package com.example.sshtunnel

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import net.schmizz.sshj.SSHClient
import net.schmizz.sshj.connection.channel.direct.LocalPortForwarder
import net.schmizz.sshj.connection.channel.direct.Parameters
import net.schmizz.sshj.transport.verification.HostKeyVerifier
import java.io.File
import java.security.PublicKey
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.util.concurrent.atomic.AtomicInteger

/**
 * SSH tunnel service using SSHJ (hierynomus/sshj).
 * One SSHClient per local port; LocalPortForwarder isolates channels so one broken connection
 * does not bring down the whole session (unlike JSch).
 */
class TunnelService : Service() {

    private val binder = LocalBinder()
    /** One SSH client per tunnel port. */
    private val clients = mutableMapOf<Int, SSHClient>()
    /** ServerSocket per port (used by LocalPortForwarder). */
    private val portServerSockets = mutableMapOf<Int, ServerSocket>()
    /** Blocking listen() runs in this job per port. */
    private val portForwarderJobs = mutableMapOf<Int, Job>()
    private var job: Job? = null
    private val scope = CoroutineScope(Dispatchers.IO + Job())
    /** Stagger reconnects so we don't open 6 SSH connections at once (avoids sshd MaxStartups / rate limit). */
    private val reconnectStaggerCounter = AtomicInteger(0)
    /** Only one reconnect at a time (avoids "Server closed connection during identification exchange"). */
    private val reconnectMutex = Mutex()

    inner class LocalBinder : Binder() {
        fun getService(): TunnelService = this@TunnelService
    }

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startTunnels()
            ACTION_STOP -> stopTunnels()
        }
        return START_STICKY
    }

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(CHANNEL_ID, "SSH Tunnel", NotificationManager.IMPORTANCE_DEFAULT).apply {
                setShowBadge(true)
                description = "Shows when SSH tunnels are running"
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(ch)
        }
    }

    private fun startForegroundNotification(running: Boolean) {
        val pending = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notif = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SSH Tunnel")
            .setContentText(if (running) "Tunnels active — tap to open" else "Stopped")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pending)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
        startForeground(NOTIF_ID, notif)
    }

    fun startTunnels() {
        if (job?.isActive == true) {
            TunnelState.addLog("Already running.")
            return
        }
        TunnelState.clear()
        TunnelState.addLog("Starting tunnels (SSHJ)…")
        startForegroundNotification(true)
        job = scope.launch {
            runTunnels()
        }
    }

    fun stopTunnels() {
        job?.cancel()
        job = null
        disconnect()
        TunnelState.addLog("Stopped.")
        startForegroundNotification(false)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun disconnect() {
        portForwarderJobs.values.forEach { it.cancel() }
        portForwarderJobs.clear()
        portServerSockets.values.forEach { sock ->
            try { sock.close() } catch (_: Exception) { }
        }
        portServerSockets.clear()
        clients.values.forEach { client ->
            try { client.disconnect() } catch (_: Exception) { }
        }
        clients.clear()
        stopBalancer()
        TunnelConfig.load(this).effectiveLocalPorts().forEach { TunnelState.setTunnelStatus(it, false) }
    }

    private var balancerJob: kotlinx.coroutines.Job? = null
    @Volatile private var balancerSocket: ServerSocket? = null

    private fun stopBalancer() {
        balancerJob?.cancel()
        balancerJob = null
        try { balancerSocket?.close() } catch (_: Exception) { }
        balancerSocket = null
    }

    private fun ts() = android.os.SystemClock.elapsedRealtime()

    private fun logD(msg: String) {
        if (TunnelState.debugEnabled) TunnelState.addLog("[${ts()}ms] $msg")
    }

    private fun logThrowable(tag: String, e: Throwable) {
        if (TunnelState.debugEnabled) {
            val cls = e.javaClass.simpleName
            TunnelState.addLog("[${ts()}ms] $tag: $cls: ${e.message}")
            var cause: Throwable? = e.cause
            var depth = 0
            while (cause != null && depth < 5) {
                TunnelState.addLog("  cause[$depth]: ${cause.javaClass.simpleName}: ${cause.message}")
                cause = cause.cause
                depth++
            }
            val stack = e.stackTraceToString().lineSequence().take(40).joinToString("\n")
            TunnelState.addLog(stack)
        } else {
            TunnelState.addLog("$tag: ${e.message}")
        }
        Log.e(LOG_TAG, tag, e)
    }

    /**
     * Start one tunnel: connect SSHJ client, bind ServerSocket, run LocalPortForwarder.listen() in a job.
     * @return true if tunnel is up and listening.
     */
    private fun connectPort(port: Int): Boolean {
        val config = TunnelConfig.load(this)
        val keyFile = config.keyPath?.let { File(it) }
        if (keyFile == null || !keyFile.exists()) {
            TunnelState.addLog("ERROR: Key not set or missing.")
            return false
        }
        val effPort = config.effectivePort()
        val effRemote = config.effectiveRemoteHost()
        val remotePort = config.effectiveRemotePort(port)

        // Cleanup existing for this port
        portForwarderJobs[port]?.cancel()
        portForwarderJobs.remove(port)
        try { portServerSockets[port]?.close() } catch (_: Exception) { }
        portServerSockets.remove(port)
        try { clients[port]?.disconnect() } catch (_: Exception) { }
        clients.remove(port)

        return try {
            logD("SSHJ connect port $port: ${config.host}:$effPort -> $effRemote:$remotePort")
            val client = SshHelper.createClient()
            client.addHostKeyVerifier(object : HostKeyVerifier {
                override fun verify(hostname: String?, port: Int, key: PublicKey?): Boolean = true
                override fun findExistingAlgorithms(hostname: String?, port: Int): MutableList<String> = mutableListOf()
            })
            client.connect(config.host, effPort)
            logD("SSHJ port $port: TCP connected, authenticating…")
            val keyProvider = client.loadKeys(keyFile.absolutePath)
            client.authPublickey(config.user, keyProvider)
            logD("SSHJ port $port: authenticated")
            val maxKeepalive = minOf(600, config.rotateIntervalMin * 60)
            client.connection.keepAlive.setKeepAliveInterval(config.keepaliveIntervalSec.coerceIn(5, maxKeepalive))

            val serverSocket = ServerSocket().apply {
                reuseAddress = true
                bind(InetSocketAddress(port))
            }
            portServerSockets[port] = serverSocket
            val params = Parameters("127.0.0.1", port, effRemote, remotePort)
            val forwarder = client.newLocalPortForwarder(params, serverSocket)
            clients[port] = client

            val forwarderJob = scope.launch {
                val portToReconnect = port
                try {
                    logD("SSHJ port $port: LocalPortForwarder.listen() started")
                    forwarder.listen()
                    logD("SSHJ port $port: listen() ended (socket closed)")
                } catch (e: Exception) {
                    if (scope.isActive) logThrowable("SSHJ port $port listen", e)
                } finally {
                    try { serverSocket.close() } catch (_: Exception) { }
                    try { client.disconnect() } catch (_: Exception) { }
                    portServerSockets.remove(port)
                    clients.remove(port)
                    portForwarderJobs.remove(port)
                    TunnelState.setTunnelStatus(port, false)
                    val slot = reconnectStaggerCounter.getAndIncrement() % 6
                    val delaySec = 0.5 + slot * 3
                    TunnelState.addLog("Port $portToReconnect: tunnel down, reconnecting in ${delaySec.toLong()}s…")
                    // Reconnect with stagger + one at a time (avoids "Server closed during identification exchange")
                    if (scope.isActive) {
                        scope.launch {
                            delay(500L + slot * 3000L)
                            if (scope.isActive && clients[portToReconnect] == null) {
                                TunnelState.addLog("Port $portToReconnect: reconnecting…")
                                reconnectMutex.withLock { connectPort(portToReconnect) }
                            }
                        }
                    }
                }
            }
            portForwarderJobs[port] = forwarderJob

            TunnelState.addLog("Tunnel local:$port -> $effRemote:$remotePort OK (SSHJ)")
            TunnelState.setTunnelStatus(port, true)
            true
        } catch (e: Exception) {
            logThrowable("SSHJ port $port connect", e)
            TunnelState.addLog("Tunnel $port failed: ${e.message}")
            TunnelState.setTunnelStatus(port, false)
            false
        }
    }

    private suspend fun runTunnels() {
        val config = TunnelConfig.load(this)
        val keyFile = config.keyPath?.let { File(it) }
        if (keyFile == null || !keyFile.exists()) {
            TunnelState.addLog("ERROR: Key not set or missing. Paste key in Config and Save.")
            return
        }
        val ports = config.effectiveLocalPorts()

        try {
            TunnelState.addLog("SSH connecting (SSHJ, one client per port)…")
            ports.forEach { connectPort(it) }
            if (config.balancerPort > 0 && ports.isNotEmpty()) startBalancer(config.balancerPort, ports)

            val rotateIntervalMs = config.rotateIntervalMin.coerceIn(1, 60) * 60L * 1000L
            var lastRotateAt = System.currentTimeMillis()
            var nextRotateIndex = 0

            while (scope.isActive) {
                delay(5_000)  // check every 5s so we detect dropped tunnels and log reconnect sooner
                val now = System.currentTimeMillis()

                for (port in ports) {
                    val client = clients[port]
                    val up = client != null && client.isConnected
                    if (!up) {
                        TunnelState.addLog("Port $port down, reconnecting…")
                        var reconnected = false
                        for (attempt in 1..8) {
                            if (!scope.isActive) break
                            val backoffMs = minOf(3000L * (1L shl (attempt - 1)), 45_000L)
                            delay(backoffMs)
                            reconnectMutex.withLock {
                                if (connectPort(port)) {
                                    reconnected = true
                                }
                            }
                            if (reconnected) break
                            if (attempt < 8) TunnelState.addLog("Port $port retry $attempt…")
                        }
                        if (!reconnected) {
                            TunnelState.addLog("Port $port: reconnect failed. Try: Stop tunnels, wait ~1 min, Start tunnels.")
                        }
                    }
                }

                if (ports.isNotEmpty() && (now - lastRotateAt) >= rotateIntervalMs) {
                    val portToRotate = ports[nextRotateIndex % ports.size]
                    nextRotateIndex++
                    lastRotateAt = now
                    try {
                        portForwarderJobs[portToRotate]?.cancel()
                        portForwarderJobs.remove(portToRotate)
                        try { portServerSockets[portToRotate]?.close() } catch (_: Exception) { }
                        portServerSockets.remove(portToRotate)
                        try { clients[portToRotate]?.disconnect() } catch (_: Exception) { }
                        clients.remove(portToRotate)
                        TunnelState.addLog("Rotated tunnel port $portToRotate (dropped)")
                        delay(500L)
                        if (connectPort(portToRotate)) {
                            TunnelState.addLog("Rotated tunnel port $portToRotate OK")
                        } else {
                            TunnelState.setTunnelStatus(portToRotate, false)
                        }
                    } catch (e: Exception) {
                        TunnelState.addLog("Rotate port $portToRotate failed: ${e.message}")
                        TunnelState.setTunnelStatus(portToRotate, false)
                    }
                }
            }
        } catch (e: Exception) {
            TunnelState.addLog("ERROR: ${e.message}")
            logThrowable("runTunnels", e)
        } finally {
            disconnect()
        }
    }

    private fun startBalancer(listenPort: Int, backendPorts: List<Int>) {
        stopBalancer()
        val index = AtomicInteger(0)
        balancerJob = scope.launch {
            var server: ServerSocket? = null
            try {
                server = ServerSocket().apply {
                    reuseAddress = true
                    bind(java.net.InetSocketAddress(listenPort))
                }
                balancerSocket = server
                TunnelState.addLog("Balancer 127.0.0.1:$listenPort -> ${backendPorts.joinToString(",")}")
                TunnelState.setTunnelStatus(listenPort, true)
                while (scope.isActive) {
                    val client = server.accept()
                    val port = backendPorts[index.getAndIncrement() % backendPorts.size]
                    launch {
                        var backend: java.net.Socket? = null
                        try {
                            backend = java.net.Socket("127.0.0.1", port)
                            val sock = backend
                            launch {
                                try {
                                    sock.getInputStream().copyTo(client.getOutputStream())
                                } catch (_: Exception) { }
                            }
                            client.getInputStream().copyTo(backend.getOutputStream())
                        } catch (e: Exception) {
                            logD("Balancer client->$port: ${e.message}")
                        } finally {
                            try { client.close() } catch (_: Exception) { }
                            try { backend?.close() } catch (_: Exception) { }
                        }
                    }
                }
            } catch (e: Exception) {
                TunnelState.addLog("Balancer error: ${e.message}")
            } finally {
                try { server?.close() } catch (_: Exception) { }
                if (balancerSocket == server) balancerSocket = null
                TunnelState.setTunnelStatus(listenPort, false)
            }
        }
    }

    companion object {
        private const val LOG_TAG = "SSHTunnel"
        const val CHANNEL_ID = "ssh_tunnel"
        const val NOTIF_ID = 1
        const val ACTION_START = "com.example.sshtunnel.START"
        const val ACTION_STOP = "com.example.sshtunnel.STOP"
    }
}
