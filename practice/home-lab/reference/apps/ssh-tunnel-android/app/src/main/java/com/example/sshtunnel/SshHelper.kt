package com.example.sshtunnel

import net.schmizz.sshj.DefaultConfig
import net.schmizz.sshj.SSHClient

/**
 * Creates an SSHClient configured for Android: Curve25519/X25519 key exchange is disabled
 * because Bouncy Castle on Android does not provide "X25519 for provider BC", which causes
 * "no such algorithm: X25519 for provider BC". Server will negotiate ECDH or DH instead.
 */
object SshHelper {
    fun createClient(): SSHClient {
        val config = DefaultConfig()
        val kex = config.keyExchangeFactories.filter { named ->
            val name = named.name.lowercase()
            !name.contains("curve25519") && !name.contains("25519")
        }
        config.setKeyExchangeFactories(kex)
        return SSHClient(config)
    }
}
