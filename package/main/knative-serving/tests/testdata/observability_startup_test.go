package otel_test

import (
	"context"
	"testing"
	"time"

	"go.uber.org/zap"
	k8sruntime "knative.dev/pkg/observability/runtime/k8s"
	"knative.dev/serving/pkg/observability"
	"knative.dev/serving/pkg/observability/otel"
)

// TestDHIObservabilityStartup runs Serving's initializer against the final vendor
// tree. Its resource.Default path is also used by controller/webhook sharedmain.
// Upstream unit tests do not call it, so incompatible resource schemas can
// otherwise pass those tests and panic only when a shipped binary starts.
func TestDHIObservabilityStartup(t *testing.T) {
	t.Setenv("SYSTEM_NAMESPACE", "knative-serving")
	t.Setenv("POD_NAME", "controller")
	ctx, cancel := context.WithTimeout(t.Context(), 30*time.Second)
	defer cancel()
	ctx = observability.WithConfig(ctx, observability.DefaultConfig())
	logger := zap.NewExample().Sugar()
	pprof := k8sruntime.NewProfilingServer(logger)

	meter, tracer := otel.SetupObservabilityOrDie(ctx, "controller", logger, pprof)
	if meter == nil || tracer == nil {
		t.Fatal("observability initialization returned a nil provider")
	}
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer shutdownCancel()
	if err := tracer.Shutdown(shutdownCtx); err != nil {
		t.Errorf("shut down tracer: %v", err)
	}
	if err := meter.Shutdown(shutdownCtx); err != nil {
		t.Errorf("shut down meter: %v", err)
	}
}
