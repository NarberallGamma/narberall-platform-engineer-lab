# Diagram: Android SSH + Docker balancer

```mermaid
flowchart LR
  subgraph clients [Local listeners]
    B[127.0.0.1:10808 balancer]
    T1[10809]
    T2[10810]
    T6[10814]
  end
  B --> T1
  B --> T2
  B --> T6
  T1 -->|SSH -L one session each| Jump[jump socat :10443]
  T2 --> Jump
  T6 --> Jump
  Jump --> Main[main :443]
```

Practice: [`../../../practice/home-lab/android-ssh.md`](../../../practice/home-lab/android-ssh.md).  
Code: [`../../../practice/home-lab/reference/apps/ssh-tunnel-android/`](../../../practice/home-lab/reference/apps/ssh-tunnel-android/), [`../../../practice/home-lab/reference/apps/ssh-tunnel-docker/`](../../../practice/home-lab/reference/apps/ssh-tunnel-docker/).
