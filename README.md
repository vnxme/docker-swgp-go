# docker-swgp-go
A set of [Docker images](https://hub.docker.com/r/vnxme/swgp-go) of Simple WireGuard Proxy for various platforms: 
- x86 64-bit (linux/amd64)
- x86 32-bit (linux/386)
- ARMv8 64-bit (linux/arm64/v8)
- ARMv7 32-bit (linux/arm/v7)
- ARMv6 32-bit (linux/arm/v6)
- IBM POWER8 (linux/ppc64le)
- IBM z Systems (linux/s390x)
- RISC-V 64-bit (linux/riscv64)

### Description
Simple WireGuard Proxy (**SWGP**) is a universal and effective solution for WireGuard (**WG**) traffic obfuscation. The original implementation is written in Go by [@database64128](https://github.com/database64128) and published as [swgp-go](https://github.com/database64128/swgp-go).

### Purpose
It is a [known limitation](https://www.wireguard.com/known-limitations/) that WG implements no obfuscation. The WG [protocol](https://www.wireguard.com/protocol/) uses UDP transport with the first 4 bytes representing a message type (unsigned 32-bit integer, little endian) and predefined handshake packet lengths (refer to the [technical whitepaper](https://www.wireguard.com/papers/wireguard.pdf) for details). As a result, pure WG traffic could easily be filtered based on some simple rules (e.g. [nDPI](https://github.com/ntop/nDPI/blob/dev/src/lib/protocols/wireguard.c)). According to public reports, some countries like China, Egypt, Iran and Russia imposed a full ban on WG protocol, at least for the packets crossing the digital borders of these countries.

SWGP modifies WG packets in a way that they look like an unknown UDP traffic to DPI software, and the firewalls successfully pass them through. While there might still be a possibility to identify WG flows obfuscated with SWGP based on statistical analysis or other factors, no reports have been published about it yet.

Further discussions on WG censorship circumvention:
- [WireGuard with obfuscation support #88](https://github.com/net4people/bbs/issues/88)
- [swgp-go: Userspace WireGuard Proxy with Minimal Overhead #117](https://github.com/net4people/bbs/issues/117)
- [Iran's regime seems to have fully blocked WireGuard #140](https://github.com/net4people/bbs/issues/140)

### Terminology
Unlike WG that uses the concept of *peers*, SWGP is a typical *client-server* application. For the purposes of SVGP:
- *server* means a WG peer with a predefined endpoint and a listening proxy peer - it receives SWGP traffic from one or more undefined SWGP clients, processes packets and sends pure WG traffic to a predefined WG server;
- *client* means a WG peer with no endpoint defined and a sending proxy peer - it receives WG traffic from one or more undefined WG peers, processes packets and sends SWGP traffic to a predefined SWGP server.

As such, a SWGP server cannot initiate connections to SWGP clients, and a SWGP client cannot initiate connections to WG peers. For a peer-to-peer setup with two equal WG peers each having a fixed IP address, it woudn't really matter where to deploy a SWGP server. Otherwise, for a peer-to-multiple-peers setup with one static WG peer and one or more dynamic WG peers, it would be desirable to deploy a SWGP server on (in front of) the static peer. Do not try to run two SWGP servers or two SWGP clients pointing to each other, it wouldn't work (at least, it is not implemented now).

Each SWGP *instance* (container, if you use Docker deployment, or process, if you install it directly on your machine) can handle multiple servers and clients at once. Be careful with `proxyListen` and `wgListen` fields, as no overlapping address-port combinations are allowed within one instance.

### Configuration
Below is diagram illustrating three most common configuration scenarios. Case 0 is more or less what most WG users have: pure WG traffic between static and dynamic WG peers. Cases 1 and 2 provide for SWGP usage. The difference is whether SWGP server and client are deployed externally (dedicated hardware, virtual machines or bridged Docker containers, i.e. different IP addresses) or internally (same hardware, same machines or hosted Docker containers, i.e. identical IP addresses). The sample configurations below correspond to case 1.

![SWGP Configuration Diagram](https://github.com/vnxme/docker-swgp-go/assets/46669194/bb3a93a6-bd46-4ca6-bf80-86e24461dca1)

<details>
  <summary>WG. Static peer instance settings before/after SWGP deployment (server.conf)</summary>

  #### Critical fields for a static peer (e.g. reachable at 2001:db8::1):
  - `ListenPort`: *PORT* where dynamic peers will send WG traffic to (usually in 10000-65535 range, default is 51820)
  - `*Key`: random 44 alphanumeric characters long Base64 strings (e.g. from [wireguardconfig](https://www.wireguardconfig.com))

  ```ini
[Interface]
Address = 192.0.2.1/24
ListenPort = 20221
PrivateKey = 2O0/Uc8q2MrcBMUbYClu3MkgZOCqqeBffJwj17dzvU4=

[Peer]
PublicKey = UcT0x33H7aTXKMtZLi+S5LDgDio0jQTeTCbpIlf2ACI=
PresharedKey = OnWohs7BrG+1Os1zBRvJXZC9aU76JDTS5Wzpkcfhn1o=
AllowedIPs = 192.0.2.2/32
  ```
</details>

<details>
  <summary>WG. Dynamic peer instance settings before SWGP deployment (client.pure.conf)</summary>

  #### Critical fields for a dynamic peer (e.g. reachable at 2001:db8::4):
  - `Endpoint`: *IPv4:PORT* or *[IPv6]:PORT* or *HOST:PORT* where it will send WG traffic to (e.g. your static WG peer)
  - `*Key`: random 44 alphanumeric characters long Base64 strings (e.g. from [wireguardconfig](https://www.wireguardconfig.com))

  ```ini
[Interface]
Address = 192.0.2.2/24
PrivateKey = EMzBeCTUpM2EwFz19ArhiXYf1vjS1T/e5f9LF5LFRGY=

[Peer]
PublicKey = Bj+VYMZ3Xt1ROgDuJ9fOm88Iw6s23hq+tyrsLrEOmGA=
PresharedKey = OnWohs7BrG+1Os1zBRvJXZC9aU76JDTS5Wzpkcfhn1o=
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = [2001:db8::1]:20221
  ```
</details>

<details>
  <summary>SWGP. Server instance config.json (server.json)</summary>

  #### Critical fields for a server (e.g. reachable at 2001:db8::2):
  - `proxyListen`: *IPv4:PORT* or *[IPv6]:PORT* or *:PORT* where clients will send SWGP traffic to
  - `proxyMode`: *zero-overhead* or *paranoid* (refer to the [official readme](https://github.com/database64128/swgp-go/blob/main/README.md) for details)
  - `proxyPSK`: secret random 44 alphanumeric characters long Base64 string (e.g. from [WGKeygen](https://wg.orz.tools))
  - `wgEndpoint`: *IPv4:PORT* or *[IPv6]:PORT* where it will send WG traffic to (e.g. your static WG peer)

  ```json
{
    "servers": [
        {
            "proxyListen": ":20220",
            "proxyMode": "zero-overhead",
            "proxyPSK": "sAe5RvzLJ3Q0Ll88QRM1N01dYk83Q4y0rXMP1i4rDmI=",
            "wgEndpoint": "[2001:db8::1]:20221"
        }
    ]
}
  ```
</details>

<details>
  <summary>SWGP. Client instance config.json (client.json)</summary>

  #### Critical fields for a client (e.g. reachable at 2001:db8::3):
  - `wgListen`: *IPv4:PORT* or *[IPv6]:PORT* or *:PORT* where peers will send WG traffic to
  - `proxyEndpoint`: *IPv4:PORT* or *[IPv6]:PORT* where it will send SWGP traffic to (e.g. your SWGP server)
  - `proxyMode`: *zero-overhead* or *paranoid* (copy from your SWGP server)
  - `proxyPSK`: secret random 44 alphanumeric characters long Base64 string (copy from your SWGP server)

  ```json
{
    "clients": [
        {
            "wgListen": ":20222",
            "proxyEndpoint": "[2001:db8::2]:20220",
            "proxyMode": "zero-overhead",
            "proxyPSK": "sAe5RvzLJ3Q0Ll88QRM1N01dYk83Q4y0rXMP1i4rDmI="
        }
    ]
}
  ```
</details>

<details>
  <summary>WG. Dynamic peer instance settings after SWGP deployment (client.obfs.conf)</summary>

  #### Modifications required for a dynamic peer (e.g. reachable at 2001:db8::4):
  - `Endpoint`: *IPv4:PORT* or *[IPv6]:PORT* or *HOST:PORT* where it will send WG traffic to (e.g. your SWGP client)

  ```ini
...
Endpoint = [2001:db8::3]:20222
  ```
</details>

### Deployment
There are 3 approaches to SWGP deployment if you don't use Docker:
1. Download [prebuilt binaries](https://github.com/database64128/swgp-go/releases) available for linux/amd64, linux/arm64 and windows/amd64 platforms
2. Compile a binary from [source code](https://github.com/database64128/swgp-go) for any compatible platform (there might be some platforms where golang and/or other dependencies are unavailable)
3. Use SWGP code written in Go in your own project (for developers)

Alternatively, Docker images may be used, which is often a more convenient way for most users. The following samples provide for a hosted deployment. For a bridged option adjust the `network` argument. Remember you will need server.json and client.json files so as to be mounted in containers.
- command line interface commands
```bash
docker run --name swgp-server -d --network host --restart unless-stopped \
  -v ./server.json:/etc/swgp-go/config.json:ro vnxme/swgp-go:latest
docker run --name swgp-client -d --network host --restart unless-stopped \
  -v ./client.json:/etc/swgp-go/config.json:ro vnxme/swgp-go:latest
```
- docker-compose.yml instructions
```yaml
version: "3.8"
services:
  swgp-server:
    container_name: swgp-server
    image: vnxme/swgp-go:latest
    network: host
    restart: unless-stopped
    volumes:
      - ./server.json:/etc/swgp-go/config.json:ro
  swgp-client:
    container_name: swgp-client
    image: vnxme/swgp-go:latest
    network: host
    restart: unless-stopped
    volumes:
      - ./client.json:/etc/swgp-go/config.json:ro
```
