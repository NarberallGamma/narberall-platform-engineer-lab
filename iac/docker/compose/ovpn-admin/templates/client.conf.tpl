{{- range $server := .Hosts }}
remote {{ $server.Host }} {{ $server.Port }} {{ $server.Protocol }}
{{- end }}

auth-nocache
float
dev tun
#proto udp
auth SHA256
cipher AES-128-CBC
client
mssfix
nobind
persist-key
persist-tun
resolv-retry infinite
remote-cert-tls server
key-direction 1
keepalive 10 120
#redirect-gateway def1
#ignore-unknown-option block-outside-dns block-ipv6
verb 4

# for Linux, uncomment the lines below
#script-security 2
# when using resolvconf
#up /etc/openvpn/update-resolv-conf
#down /etc/openvpn/update-resolv-conf
# when using systemd-resolved, install the openvpn-systemd-resolved package first
#up /etc/openvpn/update-systemd-resolved
#down /etc/openvpn/update-systemd-resolved

{{- if .PasswdAuth }}
auth-user-pass
{{- end }}

<cert>
{{ .Cert -}}
</cert>
<key>
{{ .Key -}}
</key>
<ca>
{{ .CA -}}
</ca>
<tls-auth>
{{ .TLS -}}
</tls-auth>
