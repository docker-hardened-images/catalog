package main

import (
	"archive/zip"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"golang.org/x/mod/module"
)

func TestExtractEscapesUppercaseModule(t *testing.T) {
	cases := []ModuleInfo{
		{Path: "github.com/Azure/go-ansiterm", Version: "v0.0.0-20250102033503-faa5f7b0171c"},
		{Path: "example.com/Mod", Version: "v1.2.3-RC1"},
	}
	wantDir := map[string]string{
		"github.com/Azure/go-ansiterm": "github.com/!azure/go-ansiterm@v0.0.0-20250102033503-faa5f7b0171c",
		"example.com/Mod":              "example.com/!mod@v1.2.3-!r!c1",
	}

	gopath := t.TempDir()
	t.Setenv("GOPATH", gopath)

	var urls []DownloadURL
	for _, mod := range cases {
		escapedPath, err := module.EscapePath(mod.Path)
		if err != nil {
			t.Fatalf("EscapePath(%s): %v", mod.Path, err)
		}
		escapedVersion, err := module.EscapeVersion(mod.Version)
		if err != nil {
			t.Fatalf("EscapeVersion(%s): %v", mod.Version, err)
		}
		zipPath := filepath.Join(gopath, "pkg", "mod", "cache", "download", filepath.FromSlash(escapedPath), "@v", escapedVersion+".zip")
		if err := os.MkdirAll(filepath.Dir(zipPath), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := writeModuleZip(zipPath, mod); err != nil {
			t.Fatal(err)
		}

		parsed, err := moduleFromCacheFilePath(filepath.Join(gopath, "pkg", "mod", "cache", "download"), zipPath)
		if err != nil {
			t.Fatalf("moduleFromCacheFilePath: %v", err)
		}
		if parsed.Path != mod.Path || parsed.Version != mod.Version {
			t.Fatalf("parsed %+v, want %+v", parsed, mod)
		}

		urls = append(urls, DownloadURL{
			URL:  "file://" + zipPath,
			Path: zipPath,
			Type: "zip",
		})
	}

	urlsFile := filepath.Join(t.TempDir(), "hermetic-urls.json")
	data, err := json.Marshal(urls)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(urlsFile, data, 0o644); err != nil {
		t.Fatal(err)
	}

	if err := extractCommand([]string{urlsFile}); err != nil {
		t.Fatal(err)
	}

	for _, mod := range cases {
		rel := wantDir[mod.Path]
		marker := filepath.Join(gopath, "pkg", "mod", filepath.FromSlash(rel), "marker.txt")
		if _, err := os.Stat(marker); err != nil {
			t.Fatalf("extracted marker missing at %s: %v", marker, err)
		}
		raw := filepath.Join(gopath, "pkg", "mod", filepath.FromSlash(mod.Path+"@"+mod.Version), "marker.txt")
		if raw != marker {
			if _, err := os.Stat(raw); err == nil {
				t.Fatalf("module extracted at unescaped path %s", raw)
			}
		}
		if strings.Contains(rel, "Azure") || strings.Contains(rel, "Mod@") || strings.Contains(rel, "RC1") {
			t.Fatalf("expected escaped directory, got %s", rel)
		}
	}
}

func writeModuleZip(path string, mod ModuleInfo) error {
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer f.Close()

	zw := zip.NewWriter(f)
	w, err := zw.Create(mod.Path + "@" + mod.Version + "/marker.txt")
	if err != nil {
		return err
	}
	if _, err := w.Write([]byte("ok")); err != nil {
		return err
	}
	return zw.Close()
}
