## Running Envoy AI Gateway ExtProc

The external processor is injected into the Envoy data-plane pods by the Envoy AI Gateway controller; it is not run
directly. It is deployed as part of the `envoy-ai-gateway-chart` Helm chart.

### Docker Run Example

```bash
docker run --rm dhi.io/envoy-ai-gateway-extproc:0.7.0 --help
```

For more details, visit the upstream documentation:
https://aigateway.envoyproxy.io/docs/
