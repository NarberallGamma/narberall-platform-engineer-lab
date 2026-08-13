package com.example.sshtunnel

import android.content.Context
import android.content.SharedPreferences

/**
 * SSH and tunnel config. Ports default to 10809–10814 if not set.
 */
data class TunnelConfig(
    val host: String,
    val port: Int,
    val user: String,
    val keyPath: String?,
    val password: String?,
    val localPorts: List<Int>,
    val remoteHost: String,
    /** Port on the server (socat / core listen). 0 = same as local port. */
    val remotePort: Int,
    val balancerPort: Int,
    /** When true, debug log (SSHJ/tunnel steps and exceptions) is shown in app log. */
    val debugLog: Boolean,
    /** SSH keepalive interval in seconds (e.g. 20). Keeps NAT/sessions alive. */
    val keepaliveIntervalSec: Int,
    /** Rotate one tunnel every N minutes (e.g. 10). */
    val rotateIntervalMin: Int
) {
    fun effectivePort(): Int = if (port > 0) port else 22
    fun effectiveRemoteHost(): String = remoteHost.ifEmpty { "127.0.0.1" }
    /** Remote port on the server for a given local port. If remotePort > 0, all tunnels use it (e.g. 10443). */
    fun effectiveRemotePort(localPort: Int): Int = if (remotePort > 0) remotePort else localPort
    fun effectiveLocalPorts(): List<Int> = if (localPorts.isEmpty()) listOf(10809, 10810, 10811, 10812, 10813, 10814) else localPorts

    companion object {
        private const val PREFS = "tunnel_config"
        private const val DEFAULT_BALANCER_PORT = 10808
        private const val K_HOST = "host"
        private const val K_PORT = "port"
        private const val K_USER = "user"
        private const val K_KEY_PATH = "key_path"
        private const val K_LOCAL_PORTS = "local_ports"
        private const val K_REMOTE_HOST = "remote_host"
        private const val K_REMOTE_PORT = "remote_port"
        private const val K_BALANCER_PORT = "balancer_port"
        private const val K_DEBUG_LOG = "debug_log"
        private const val K_KEEPALIVE_INTERVAL = "keepalive_interval_sec"
        private const val K_ROTATE_INTERVAL = "rotate_interval_min"

        fun load(ctx: Context): TunnelConfig {
            val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val host = prefs.getString(K_HOST, null) ?: ""
            val port = prefs.getInt(K_PORT, 0)
            val user = prefs.getString(K_USER, null) ?: ""
            val keyPath = prefs.getString(K_KEY_PATH, null)
            val portsStr = prefs.getString(K_LOCAL_PORTS, null) ?: ""
            val localPorts = portsStr.split(",").mapNotNull { it.trim().toIntOrNull() }
            val remoteHost = prefs.getString(K_REMOTE_HOST, null) ?: ""
            val remotePort = prefs.getInt(K_REMOTE_PORT, 0)
            val balancerPort = prefs.getInt(K_BALANCER_PORT, -1)
            val debugLog = prefs.getBoolean(K_DEBUG_LOG, false)
            val rotateIntervalMin = prefs.getInt(K_ROTATE_INTERVAL, 10).coerceIn(1, 60)
            val maxKeepaliveSec = rotateIntervalMin * 60
            val keepaliveIntervalSec = prefs.getInt(K_KEEPALIVE_INTERVAL, 20).coerceIn(5, minOf(600, maxKeepaliveSec))
            return TunnelConfig(
                host = host,
                port = port,
                user = user,
                keyPath = keyPath,
                password = null,
                localPorts = localPorts,
                remoteHost = remoteHost,
                remotePort = remotePort,
                balancerPort = if (balancerPort < 0) DEFAULT_BALANCER_PORT else balancerPort,
                debugLog = debugLog,
                keepaliveIntervalSec = keepaliveIntervalSec,
                rotateIntervalMin = rotateIntervalMin
            )
        }

        fun save(ctx: Context, config: TunnelConfig) {
            ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString(K_HOST, config.host)
                .putInt(K_PORT, config.port)
                .putString(K_USER, config.user)
                .putString(K_KEY_PATH, config.keyPath)
                .putString(K_LOCAL_PORTS, config.localPorts.joinToString(","))
                .putString(K_REMOTE_HOST, config.remoteHost)
                .putInt(K_REMOTE_PORT, config.remotePort)
                .putInt(K_BALANCER_PORT, config.balancerPort)
                .putBoolean(K_DEBUG_LOG, config.debugLog)
                .putInt(K_KEEPALIVE_INTERVAL, config.keepaliveIntervalSec.coerceIn(5, minOf(600, config.rotateIntervalMin * 60)))
                .putInt(K_ROTATE_INTERVAL, config.rotateIntervalMin.coerceIn(1, 60))
                .apply()
        }
    }
}
