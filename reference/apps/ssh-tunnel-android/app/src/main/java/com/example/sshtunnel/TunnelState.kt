package com.example.sshtunnel

import java.util.Collections

/**
 * Shared state between TunnelService and UI: log lines and per-port tunnel status.
 */
object TunnelState {
    private val logLines = Collections.synchronizedList(mutableListOf<String>())
    private val tunnelStatus = Collections.synchronizedMap(mutableMapOf<Int, Boolean>())
    @Volatile var listener: (() -> Unit)? = null
    @Volatile var debugEnabled: Boolean = false

    fun addLog(line: String) {
        logLines.add(line)
        if (logLines.size > 500) logLines.removeAt(0)
        listener?.let { runOnMain { it() } }
    }

    fun setTunnelStatus(port: Int, up: Boolean) {
        tunnelStatus[port] = up
        listener?.let { runOnMain { it() } }
    }

    fun getLogLines(): List<String> = logLines.toList()
    fun getTunnelStatus(): Map<Int, Boolean> = tunnelStatus.toMap()

    /** Clears only the log (used by Refresh in UI). Port status is kept. */
    fun clearLog() {
        logLines.clear()
        listener?.let { runOnMain { it() } }
    }

    fun clear() {
        logLines.clear()
        tunnelStatus.clear()
        listener?.let { runOnMain { it() } }
    }

    private fun runOnMain(block: () -> Unit) {
        android.os.Handler(android.os.Looper.getMainLooper()).post(block)
    }
}
