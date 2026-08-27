## About Selenium Node Chromium

Selenium Node Chromium is a worker component of a Selenium Grid. A Node registers with a Selenium Hub and runs real
browser sessions on behalf of test clients that arrive at the Hub through the W3C WebDriver protocol. This image ships
the open-source Chromium browser and chromedriver, making it the canonical browser node for arm64 Selenium Grids (where
Google Chrome is not distributed) and a drop-in alternative to `selenium/node-chrome` on amd64.

Each Grid Node runs a single `selenium-server` JVM that accepts session requests routed from the Hub, spawns a
chromedriver subprocess per session, and drives Chromium for the lifetime of that session. Sessions are isolated per
WebDriver request; the JVM and chromedriver supervise their own lifecycle.

Run the Node on the same `selenium-server` version as its Hub; Selenium Grid 4.x does not reliably tolerate a Hub/Node
version mismatch. See the usage guide for version-pinning guidance.

For more details, visit https://www.selenium.dev/documentation/grid/.

## A note on headless and VNC

The upstream `selenium/node-chromium` image runs a multi-process container under `supervisord` that includes Xvfb
(virtual framebuffer), x11vnc (VNC server), noVNC (web VNC client), fluxbox (window manager), and a chrome-cleanup
helper. The Docker Hardened image ships **`tini` as PID 1 supervising a single JVM** with no X server, so WebDriver
clients request headless Chromium (for example `--headless=new`). The VNC / Xvfb / fluxbox stack is intentionally
omitted because each component is a separate CVE surface and adds binaries that are not useful for the unattended-CI use
case that drives the majority of Selenium Grid deployments. If a deployment specifically needs in-container visual
debugging via VNC, a future flavor can layer the upstream stack on top; the request can be filed in the Docker Hardened
Images repository.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Selenium is a trademark of the Software Freedom Conservancy. Chromium is a trademark of Google LLC. All rights in those
marks are reserved to their respective holders. Any use by Docker is for referential purposes only and does not indicate
sponsorship, endorsement, or affiliation. All other third-party product names, logos, and trademarks are the property of
their respective owners and are used solely for identification. Docker claims no interest in those marks, and no
affiliation, sponsorship, or endorsement is implied.
