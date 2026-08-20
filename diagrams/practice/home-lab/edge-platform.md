# Diagram: Edge platform

```mermaid
flowchart TB
  Op[Operator ansible-runner]
  Op --> Prep[prepare_servers]
  Op --> Main[xui_docker main]
  Op --> Jump[xui_docker proxy]
  Main --> Art[inbound-summary artifacts]
  Art --> Jump
  Clients[Clients] --> Jump
  Clients --> Main
  Jump -->|TLS inbound| Main
  Jump -->|SSH + socat failover| Main
  And[Android / Docker SSH balancer] --> Jump
```

Practice: [`../../../practice/home-lab/edge-platform.md`](../../../practice/home-lab/edge-platform.md).  
Code: [`../../../iac/ansible/reference/ansible-edge/`](../../../iac/ansible/reference/ansible-edge/), [`../../../iac/ansible/`](../../../iac/ansible/).
