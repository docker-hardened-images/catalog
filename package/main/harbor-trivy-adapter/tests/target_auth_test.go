package trivy

import (
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/aquasecurity/harbor-scanner-trivy/pkg/etc"
	"github.com/aquasecurity/harbor-scanner-trivy/pkg/ext"
	"github.com/stretchr/testify/require"
)

func TestNewTargetRegistryAuth(t *testing.T) {
	const manifest = `{
		"schemaVersion": 2,
		"mediaType": "application/vnd.oci.image.manifest.v1+json",
		"config": {
			"mediaType": "application/vnd.oci.image.config.v1+json",
			"digest": "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
			"size": 0
		},
		"layers": []
	}`

	tests := []struct {
		name     string
		auth     RegistryAuth
		wantAuth string
	}{
		{
			name: "anonymous",
			auth: NoAuth{},
		},
		{
			name:     "basic",
			auth:     BasicAuth{Username: "scanner", Password: "secret"},
			wantAuth: "Basic " + base64.StdEncoding.EncodeToString([]byte("scanner:secret")),
		},
		{
			name:     "bearer",
			auth:     BearerAuth{Token: "registry-token"},
			wantAuth: "Bearer registry-token",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			gotAuth := make(chan string, 1)
			sum := sha256.Sum256([]byte(manifest))
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				switch {
				case r.URL.Path == "/v2/":
					w.WriteHeader(http.StatusOK)
				case strings.HasSuffix(r.URL.Path, "/manifests/latest"):
					gotAuth <- r.Header.Get("Authorization")
					w.Header().Set("Content-Type", "application/vnd.oci.image.manifest.v1+json")
					w.Header().Set("Docker-Content-Digest", fmt.Sprintf("sha256:%x", sum))
					if _, err := w.Write([]byte(manifest)); err != nil {
						t.Errorf("write manifest: %v", err)
					}
				default:
					http.NotFound(w, r)
				}
			}))
			defer server.Close()

			target, err := newTarget(ImageRef{
				Name:   strings.TrimPrefix(server.URL, "http://") + "/test/image:latest",
				Auth:   tt.auth,
				NonSSL: true,
			}, etc.Trivy{}, ext.DefaultAmbassador)

			require.NoError(t, err)
			require.Equal(t, TargetImage, target.kind)
			require.Equal(t, tt.wantAuth, <-gotAuth)
		})
	}
}
