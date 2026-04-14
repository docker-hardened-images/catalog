## About Network Multitool

Network Multitool is a multi-architecture utility image for container and network testing and troubleshooting. This
Docker Hardened Image is based on Alpine Linux and packages a broad set of networking tools together with a minimal
nginx web server to make it easy to run tests, capture packets, and serve test content.

The container includes tools for DNS inspection, HTTP testing, packet capture, route tracing, and basic system
utilities. nginx runs by default on ports 80 and 443, allowing you to quickly validate HTTP/HTTPS behavior from other
containers or hosts.

## Key Features

- **Comprehensive toolset**: Includes curl, wget, dig, nslookup, ping, traceroute, tcpdump, netstat, and more
- **Web server included**: nginx runs by default on ports 80 and 443 (customizable via environment variables)
- **SSL/TLS support**: Self-signed certificates are generated automatically for convenience
- **Customizable ports**: Use `HTTP_PORT` and `HTTPS_PORT` environment variables to change default ports
- **Multi-architecture**: Supports linux/amd64 and linux/arm64

## Tools Included

- **Package manager**: apk (dev variants only)
- **Web server**: nginx (ports 80, 443)
- **Text processing**: awk, cut, diff, find, grep, sed, vi, wc
- **HTTP clients**: curl, wget
- **DNS tools**: dig, nslookup
- **Network tools**: ip, ifconfig, route
- **Tracing**: traceroute, tracepath, mtr, tcptraceroute
- **Connectivity**: ping, arp, arping
- **Process tools**: ps, netstat
- **Compression**: gzip, cpio, tar
- **Remote access**: telnet client, ssh client
- **Packet capture**: tcpdump
- **JSON processing**: jq
- **Shell**: bash

## Security Features

This Docker Hardened Image includes:

- Runs as non-root user (nginx, UID 65532)
- Minimal attack surface with only necessary packages
- Regular security updates
- No unnecessary services or files
- Proper file permissions and ownership

## Upstream Project

This image is based on the WBITT Network-MultiTool project (https://github.com/wbitt/Network-MultiTool) (formerly
praqma/network-multitool).

## Trademarks

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
