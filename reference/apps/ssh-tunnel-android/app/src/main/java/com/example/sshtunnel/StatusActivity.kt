package com.example.sshtunnel

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.BaseAdapter
import androidx.appcompat.app.AppCompatActivity
import com.example.sshtunnel.databinding.ActivityStatusBinding
import com.example.sshtunnel.databinding.ItemStatusOvalBinding

class StatusActivity : AppCompatActivity() {

    private lateinit var binding: ActivityStatusBinding
    private var statusAdapter: StatusAdapter? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityStatusBinding.inflate(layoutInflater)
        setContentView(binding.root)
        binding.btnBack.setOnClickListener { finish() }
        TunnelState.listener = { refreshStatus() }
        refreshStatus()
    }

    override fun onDestroy() {
        TunnelState.listener = null
        super.onDestroy()
    }

    override fun onResume() {
        super.onResume()
        refreshStatus()
    }

    private fun refreshStatus() {
        val config = TunnelConfig.load(this)
        val status = TunnelState.getTunnelStatus()
        val ports = if (status.isEmpty()) {
            val list = config.effectiveLocalPorts().toMutableList()
            if (config.balancerPort > 0) list.add(0, config.balancerPort)
            list.distinct().sorted()
        } else {
            status.keys.sorted()
        }
        val items = ports.map { port ->
            val up = status[port] ?: false
            val label = if (config.balancerPort > 0 && port == config.balancerPort) "Balancer $port" else "Port $port"
            StatusItem(label, up)
        }
        if (statusAdapter == null) {
            statusAdapter = StatusAdapter(items)
            binding.statusList.adapter = statusAdapter
        } else {
            statusAdapter!!.update(items)
        }
    }

    private data class StatusItem(val label: String, val up: Boolean)

    private inner class StatusAdapter(private var items: List<StatusItem>) : BaseAdapter() {

        fun update(newItems: List<StatusItem>) {
            items = newItems
            notifyDataSetChanged()
        }

        override fun getCount() = items.size
        override fun getItem(position: Int) = items[position]
        override fun getItemId(position: Int) = position.toLong()

        override fun getView(position: Int, convertView: View?, parent: ViewGroup): View {
            val item = items[position]
            val itemBinding = when {
                convertView?.tag is ItemStatusOvalBinding -> convertView.tag as ItemStatusOvalBinding
                else -> ItemStatusOvalBinding.inflate(LayoutInflater.from(this@StatusActivity), parent, false).also {
                    it.root.tag = it
                }
            }
            itemBinding.label.text = item.label
            itemBinding.statusText.text = if (item.up) getString(R.string.status_up) else getString(R.string.status_down)
            itemBinding.ovalContainer.setBackgroundResource(
                if (item.up) R.drawable.bg_status_oval_up else R.drawable.bg_status_oval_down
            )
            return itemBinding.root
        }
    }
}
