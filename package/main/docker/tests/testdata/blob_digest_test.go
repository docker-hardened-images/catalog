package distributionblob

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/distribution/reference"
	"github.com/docker/distribution"
	"github.com/docker/distribution/manifest/schema2"
	"github.com/docker/distribution/registry/client"
	"github.com/opencontainers/go-digest"
)

// TestBlobGetRejectsMismatchedDigest checks that registry client Get refuses
// bytes that do not hash to the requested digest. The upstream regression
// tests live in internal/client, which Moby does not vendor.
func TestBlobGetRejectsMismatchedDigest(t *testing.T) {
	pinned := []byte("pinned-blob")
	evil := []byte("substituted-blob")
	dgst := digest.SHA256.FromBytes(pinned)

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/octet-stream")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write(evil)
	}))
	t.Cleanup(srv.Close)

	named, err := reference.WithName("example.com/repo")
	if err != nil {
		t.Fatal(err)
	}
	repo, err := client.NewRepository(named, srv.URL, srv.Client().Transport)
	if err != nil {
		t.Fatal(err)
	}

	_, err = repo.Blobs(context.Background()).Get(context.Background(), dgst)
	if err == nil {
		t.Fatal("Get accepted blob content that does not match the requested digest")
	}
	if !strings.Contains(err.Error(), "blob digest mismatch") {
		t.Fatalf("Get error = %v, want blob digest mismatch", err)
	}
}

// TestBlobGetRejectsUnsupportedDigestAlgorithm checks that Get fails closed
// on a digest algorithm this module cannot verify, instead of calling Verifier.
func TestBlobGetRejectsUnsupportedDigestAlgorithm(t *testing.T) {
	named, err := reference.WithName("example.com/repo")
	if err != nil {
		t.Fatal(err)
	}
	repo, err := client.NewRepository(named, "http://127.0.0.1:1", http.DefaultTransport)
	if err != nil {
		t.Fatal(err)
	}

	bad := digest.Digest("md5:0123456789abcdef0123456789abcdef")
	if _, err := repo.Blobs(context.Background()).Get(context.Background(), bad); err == nil {
		t.Fatal("Get accepted a digest with an unsupported algorithm")
	}
}

// substitutedManifest is a well-formed schema2 manifest that differs from the
// pinned one, so an unpatched client would unmarshal and return it.
const substitutedManifest = `{"schemaVersion":2,"mediaType":"application/vnd.docker.distribution.manifest.v2+json","config":{"mediaType":"application/vnd.docker.container.image.v1+json","size":2,"digest":"sha256:44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a"},"layers":[]}`

func manifestServer(t *testing.T, forged digest.Digest) *httptest.Server {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", schema2.MediaTypeManifest)
		if forged != "" {
			w.Header().Set("Docker-Content-Digest", forged.String())
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(substitutedManifest))
	}))
	t.Cleanup(srv.Close)
	return srv
}

func manifestService(t *testing.T, url string, rt http.RoundTripper) distribution.ManifestService {
	t.Helper()
	named, err := reference.WithName("example.com/repo")
	if err != nil {
		t.Fatal(err)
	}
	repo, err := client.NewRepository(named, url, rt)
	if err != nil {
		t.Fatal(err)
	}
	ms, err := repo.Manifests(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	return ms
}

// TestManifestGetRejectsMismatchedDigest is the CVE-2026-85747 case: a
// registry forges Docker-Content-Digest and serves a different manifest for a
// digest-pinned request.
func TestManifestGetRejectsMismatchedDigest(t *testing.T) {
	pinned := digest.SHA256.FromBytes([]byte("pinned-manifest"))
	srv := manifestServer(t, pinned)

	_, err := manifestService(t, srv.URL, srv.Client().Transport).Get(context.Background(), pinned)
	if err == nil {
		t.Fatal("Get accepted manifest content that does not match the requested digest")
	}
	if !strings.Contains(err.Error(), "manifest digest mismatch") {
		t.Fatalf("Get error = %v, want manifest digest mismatch", err)
	}
}

// TestManifestGetAcceptsMatchingDigest guards against the check rejecting
// genuine content.
func TestManifestGetAcceptsMatchingDigest(t *testing.T) {
	pinned := digest.SHA256.FromBytes([]byte(substitutedManifest))
	srv := manifestServer(t, pinned)

	if _, err := manifestService(t, srv.URL, srv.Client().Transport).Get(context.Background(), pinned); err != nil {
		t.Fatalf("Get rejected manifest content that matches the requested digest: %v", err)
	}
}

// TestManifestGetByTagIsNotDigestChecked matches upstream: a tag fetch has no
// requested digest to verify against.
func TestManifestGetByTagIsNotDigestChecked(t *testing.T) {
	srv := manifestServer(t, "")

	if _, err := manifestService(t, srv.URL, srv.Client().Transport).Get(context.Background(), "", distribution.WithTag("latest")); err != nil {
		t.Fatalf("Get by tag failed: %v", err)
	}
}

// TestManifestGetRejectsUnsupportedDigestAlgorithm checks the manifest path
// fails closed instead of calling Verifier on an unverifiable digest.
func TestManifestGetRejectsUnsupportedDigestAlgorithm(t *testing.T) {
	srv := manifestServer(t, "")

	bad := digest.Digest("md5:0123456789abcdef0123456789abcdef")
	if _, err := manifestService(t, srv.URL, srv.Client().Transport).Get(context.Background(), bad); err == nil {
		t.Fatal("Get accepted a digest with an unsupported algorithm")
	}
}
