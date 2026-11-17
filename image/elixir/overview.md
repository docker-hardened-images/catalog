## About Elixir

Elixir is a dynamic, functional programming language that runs on the Erlang Virtual Machine (BEAM). It was designed to
build scalable, maintainable, and fault-tolerant applications, combining Erlang's proven concurrency and distribution
model with a modern, approachable syntax. Elixir applications are composed of lightweight processes that communicate
through message passing, making it straightforward to write programs that take full advantage of multi-core hardware.

Elixir's standard library and tooling — including the `mix` build tool and the `iex` interactive shell — provide a
productive development experience for projects ranging from simple scripts to large distributed systems. The language is
widely used for web development (via the Phoenix framework), real-time data pipelines, embedded systems (Nerves), and
any domain that benefits from Erlang/OTP's reliability guarantees. Elixir code runs on the Erlang/OTP BEAM runtime
shipped in this image — Debian tags use the `dhi/erlang-otp` artifact; Alpine tags use the `erlang28` package — so all
BEAM semantics, OTP behaviours, and standard Erlang libraries are available natively.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Elixir is a trademark of The Elixir Team. All rights in the mark are reserved to The Elixir Team. Any use by Docker is
for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
