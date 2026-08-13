package com.example.sshtunnel

import android.app.Application
import org.bouncycastle.jce.provider.BouncyCastleProvider
import java.security.Security

class App : Application() {
    override fun onCreate() {
        super.onCreate()
        // SSHJ needs BC for Ed25519, SHA-256 in key exchange, etc. On Android a stub "BC" may exist
        // without SHA-256; ensure our full Bouncy Castle is used.
        Security.removeProvider(BouncyCastleProvider.PROVIDER_NAME)
        Security.addProvider(BouncyCastleProvider())
    }
}
