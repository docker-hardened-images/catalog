package main

import (
	"archive/zip"
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"golang.org/x/mod/modfile"
	"golang.org/x/mod/module"
	"golang.org/x/mod/sumdb/dirhash"
)

var version = "dev"

const DefaultFileName = "hermetic-urls.json"

type ModuleInfo struct {
	Path    string
	Version string
}

type Checksum struct {
	Hash    string
	IsGoMod bool
}

type DownloadURL struct {
	URL        string `json:"url"`
	Path       string `json:"path"`
	Type       string `json:"type"`        // "info", "mod", "zip"
	Checksum   string `json:"checksum"`    // SHA256 checksum with "sha256:" prefix, empty for info files
	GoChecksum string `json:"go_checksum"` // Go checksum with "h1:" prefix, empty for info files
}

func main() {
	if len(os.Args) < 3 {
		fmt.Fprintf(os.Stderr, "usage:\n")
		fmt.Fprintf(os.Stderr, "  %s list <project-dir> [output-file]\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  %s extract <urls-file>\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "\nexamples:\n")
		fmt.Fprintf(os.Stderr, "  %s list . %s\n", os.Args[0], DefaultFileName)
		fmt.Fprintf(os.Stderr, "  %s extract %s\n", os.Args[0], DefaultFileName)
		os.Exit(1)
	}

	command := os.Args[1]

	fmt.Printf("starting go-hermetic %s - %s\n", version, command)

	switch command {
	case "list":
		if err := listCommand(os.Args[2:]); err != nil {
			fmt.Fprintf(os.Stderr, "error: %v\n", err)
			os.Exit(1)
		}
	case "extract":
		if err := extractCommand(os.Args[2:]); err != nil {
			fmt.Fprintf(os.Stderr, "error: %v\n", err)
			os.Exit(1)
		}
	default:
		fmt.Fprintf(os.Stderr, "unknown command: %s\n", command)
		fmt.Fprintf(os.Stderr, "valid commands: list, extract\n")
		os.Exit(1)
	}
}

func listCommand(args []string) error {
	if len(args) < 1 {
		return fmt.Errorf("missing project directory argument")
	}

	projectDir := args[0]
	outputFile := DefaultFileName
	if len(args) > 1 {
		outputFile = args[1]
	}

	// Read modules
	modules, err := parseModules(projectDir)
	if err != nil {
		return fmt.Errorf("parsing modules: %w", err)
	}

	// Read checksums
	checksums, err := parseChecksums(projectDir)
	if err != nil {
		return fmt.Errorf("parsing checksums: %w", err)
	}

	// Get cache directory
	gopath := os.Getenv("GOPATH")
	if gopath == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return fmt.Errorf("getting home directory: %w", err)
		}
		gopath = filepath.Join(home, "go")
	}

	cacheDir := filepath.Join(gopath, "pkg", "mod", "cache", "download")

	proxy := os.Getenv("GOPROXY")
	if proxy == "" || proxy == "direct" {
		proxy = "https://proxy.golang.org"
	} else {
		proxy = strings.Split(proxy, ",")[0]
	}

	fmt.Printf("proxy: %s\n", proxy)
	fmt.Printf("cache directory: %s\n", cacheDir)
	fmt.Printf("found %d modules\n\n", len(modules))

	// Generate download URLs
	var allURLs []DownloadURL
	for _, mod := range modules {
		if !hasChecksum(checksums, mod) {
			continue
		}
		urls, err := generateDownloadURLs(mod, checksums, proxy, cacheDir)
		if err != nil {
			fmt.Printf("error generating URLs for %s@%s: %v\n", mod.Path, mod.Version, err)
			continue
		}
		allURLs = append(allURLs, urls...)
	}

	fmt.Printf("generated %d download URLs\n", len(allURLs))

	// Write to JSON file
	file, err := os.Create(outputFile)
	if err != nil {
		return fmt.Errorf("creating output file: %w", err)
	}
	defer file.Close()

	encoder := json.NewEncoder(file)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(allURLs); err != nil {
		return fmt.Errorf("writing JSON: %w", err)
	}

	fmt.Printf("urls written to %s\n", outputFile)
	return nil
}

func extractCommand(args []string) error {
	if len(args) < 1 {
		return fmt.Errorf("missing urls file argument")
	}

	urlsFile := args[0]

	// Read URLs from JSON file
	file, err := os.Open(urlsFile)
	if err != nil {
		return fmt.Errorf("opening urls file: %w", err)
	}
	defer file.Close()

	var allURLs []DownloadURL
	decoder := json.NewDecoder(file)
	if err := decoder.Decode(&allURLs); err != nil {
		return fmt.Errorf("parsing JSON: %w", err)
	}

	// Get directories
	gopath := os.Getenv("GOPATH")
	if gopath == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return fmt.Errorf("getting home directory: %w", err)
		}
		gopath = filepath.Join(home, "go")
	}

	cacheDir := filepath.Join(gopath, "pkg", "mod", "cache", "download")
	extractDir := filepath.Join(gopath, "pkg", "mod")

	fmt.Printf("cache directory: %s\n", cacheDir)
	fmt.Printf("extract directory: %s\n", extractDir)
	fmt.Printf("processing %d files\n\n", len(allURLs))

	// Group URLs by module
	type ModuleFiles struct {
		mod     ModuleInfo
		modPath string
		zipPath string
		modHash string
		zipHash string
	}

	moduleFiles := make(map[string]*ModuleFiles)

	for _, urlInfo := range allURLs {
		mod, err := moduleFromCacheFilePath(cacheDir, urlInfo.Path)
		if err != nil {
			continue
		}

		key := mod.Path + "@" + mod.Version
		if moduleFiles[key] == nil {
			moduleFiles[key] = &ModuleFiles{
				mod: mod,
			}
		}

		mf := moduleFiles[key]
		switch urlInfo.Type {
		case "mod":
			mf.modPath = urlInfo.Path
			mf.modHash = urlInfo.GoChecksum
		case "zip":
			mf.zipPath = urlInfo.Path
			mf.zipHash = urlInfo.GoChecksum
		}
	}

	// Validate and extract each module
	totalCount := len(moduleFiles)
	i := 0
	for _, mf := range moduleFiles {
		i++
		fmt.Printf("%s@%s [%d/%d]\n", mf.mod.Path, mf.mod.Version, i, totalCount)

		// Validate .mod file
		if mf.modPath != "" && mf.modHash != "" {
			if err := validateFileHash(mf.modPath, mf.modHash); err != nil {
				fmt.Printf("error validating .mod: %v\n", err)
				os.Exit(1)
			}
		}

		// Validate .zip file
		if mf.zipPath != "" && mf.zipHash != "" {
			if err := validateZipHash(mf.zipPath, mf.zipHash); err != nil {
				fmt.Printf("error validating .zip: %v\n", err)
				os.Exit(1)
			}
		}

		// Create .ziphash file
		if mf.zipPath != "" && mf.zipHash != "" {
			ziphashPath := strings.TrimSuffix(mf.zipPath, ".zip") + ".ziphash"
			if err := os.WriteFile(ziphashPath, []byte(mf.zipHash), 0644); err != nil {
				fmt.Printf("error writing .ziphash: %v\n", err)
				os.Exit(1)
			}
		}

		// Extract zip into the escaped directory the go command reads.
		if mf.zipPath != "" {
			modDir, err := moduleExtractDir(extractDir, mf.mod)
			if err != nil {
				fmt.Printf("error escaping module dir: %v\n", err)
				os.Exit(1)
			}
			if err := extractZip(mf.zipPath, modDir); err != nil {
				fmt.Printf("error extracting: %v\n", err)
				os.Exit(1)
			}
		}
	}

	fmt.Printf("\n%d modules extracted\n", totalCount)
	return nil
}

func parseModules(projectDir string) ([]ModuleInfo, error) {
	workPath := filepath.Join(projectDir, "go.work")
	if _, err := os.Stat(workPath); err == nil {
		return parseGoWork(workPath)
	}

	modPath := filepath.Join(projectDir, "go.mod")
	return parseGoMod(modPath)
}

func parseChecksums(projectDir string) (map[string]Checksum, error) {
	workSumPath := filepath.Join(projectDir, "go.work.sum")
	if _, err := os.Stat(workSumPath); err == nil {
		return parseGoSum(workSumPath)
	}

	sumPath := filepath.Join(projectDir, "go.sum")
	return parseGoSum(sumPath)
}

func parseGoWork(filename string) ([]ModuleInfo, error) {
	data, err := os.ReadFile(filename)
	if err != nil {
		return nil, err
	}

	file, err := modfile.ParseWork(filename, data, nil)
	if err != nil {
		return nil, err
	}

	var modules []ModuleInfo

	// Read dependencies from each workspace module
	for _, use := range file.Use {
		modPath := filepath.Join(filepath.Dir(filename), use.Path, "go.mod")
		mods, err := parseGoMod(modPath)
		if err != nil {
			continue
		}
		modules = append(modules, mods...)
	}

	// Add replace directives from go.work (non-local replacements only)
	for _, rep := range file.Replace {
		// Skip local replacements (paths starting with . or /)
		if strings.HasPrefix(rep.New.Path, ".") || strings.HasPrefix(rep.New.Path, "/") {
			continue
		}

		// Add the replacement target if it has a version
		if rep.New.Version != "" {
			modules = append(modules, ModuleInfo{
				Path:    rep.New.Path,
				Version: rep.New.Version,
			})
		}
	}

	return modules, nil
}

func parseGoMod(filename string) ([]ModuleInfo, error) {
	data, err := os.ReadFile(filename)
	if err != nil {
		return nil, err
	}

	file, err := modfile.Parse(filename, data, nil)
	if err != nil {
		return nil, err
	}

	var modules []ModuleInfo

	// Add all require directives
	for _, req := range file.Require {
		modules = append(modules, ModuleInfo{
			Path:    req.Mod.Path,
			Version: req.Mod.Version,
		})
	}

	// Add replace directives (non-local replacements only)
	for _, rep := range file.Replace {
		// Skip local replacements (paths starting with . or /)
		if strings.HasPrefix(rep.New.Path, ".") || strings.HasPrefix(rep.New.Path, "/") {
			continue
		}

		// Add the replacement target if it has a version
		if rep.New.Version != "" {
			modules = append(modules, ModuleInfo{
				Path:    rep.New.Path,
				Version: rep.New.Version,
			})
		}
	}

	return modules, nil
}

func parseGoSum(filename string) (map[string]Checksum, error) {
	file, err := os.Open(filename)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	checksums := make(map[string]Checksum)
	scanner := bufio.NewScanner(file)

	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}

		parts := strings.Fields(line)
		if len(parts) < 3 {
			continue
		}

		path := parts[0]
		version := parts[1]
		hash := parts[2]

		isGoMod := strings.HasSuffix(version, "/go.mod")
		if isGoMod {
			version = strings.TrimSuffix(version, "/go.mod")
		}

		key := path + "@" + version
		if isGoMod {
			key += "/go.mod"
		}

		checksums[key] = Checksum{
			Hash:    hash,
			IsGoMod: isGoMod,
		}
	}

	return checksums, scanner.Err()
}

func hasChecksum(checksums map[string]Checksum, mod ModuleInfo) bool {
	zipKey := mod.Path + "@" + mod.Version
	modKey := mod.Path + "@" + mod.Version + "/go.mod"
	_, hasZip := checksums[zipKey]
	_, hasMod := checksums[modKey]
	return hasZip || hasMod
}

func generateDownloadURLs(mod ModuleInfo, checksums map[string]Checksum, proxy, cacheDir string) ([]DownloadURL, error) {
	escapedPath, err := module.EscapePath(mod.Path)
	if err != nil {
		return nil, fmt.Errorf("escaping path: %w", err)
	}

	escapedVersion, err := module.EscapeVersion(mod.Version)
	if err != nil {
		return nil, fmt.Errorf("escaping version: %w", err)
	}

	var urls []DownloadURL

	// .info file (no checksum)
	urls = append(urls, DownloadURL{
		URL:  fmt.Sprintf("%s/%s/@v/%s.info", proxy, escapedPath, escapedVersion),
		Path: filepath.Join(cacheDir, escapedPath, "@v", escapedVersion+".info"),
		Type: "info",
	})

	// .mod file with SHA256 checksum
	modKey := mod.Path + "@" + mod.Version + "/go.mod"
	goModChecksum := ""
	if cs, ok := checksums[modKey]; ok {
		goModChecksum = cs.Hash
	}
	urls = append(urls, DownloadURL{
		URL:        fmt.Sprintf("%s/%s/@v/%s.mod", proxy, escapedPath, escapedVersion),
		Path:       filepath.Join(cacheDir, escapedPath, "@v", escapedVersion+".mod"),
		Type:       "mod",
		GoChecksum: goModChecksum,
	})

	// .zip file with SHA256 checksum
	zipKey := mod.Path + "@" + mod.Version
	goZipChecksum := ""
	if cs, ok := checksums[zipKey]; ok {
		goZipChecksum = cs.Hash
	}
	urls = append(urls, DownloadURL{
		URL:        fmt.Sprintf("%s/%s/@v/%s.zip", proxy, escapedPath, escapedVersion),
		Path:       filepath.Join(cacheDir, escapedPath, "@v", escapedVersion+".zip"),
		Type:       "zip",
		GoChecksum: goZipChecksum,
	})

	return urls, nil
}

func moduleFromCacheFilePath(cacheDir, cacheFilePath string) (ModuleInfo, error) {
	absCache, err := filepath.Abs(cacheDir)
	if err != nil {
		return ModuleInfo{}, err
	}
	absFile, err := filepath.Abs(cacheFilePath)
	if err != nil {
		return ModuleInfo{}, err
	}

	cachePrefix := absCache + string(os.PathSeparator)
	if !strings.HasPrefix(absFile, cachePrefix) {
		return ModuleInfo{}, fmt.Errorf("cache file outside download directory: %s", cacheFilePath)
	}

	rel, err := filepath.Rel(absCache, absFile)
	if err != nil {
		return ModuleInfo{}, err
	}

	parts := strings.Split(rel, string(os.PathSeparator))
	for i, part := range parts {
		if part != "@v" || i == 0 || i+1 >= len(parts) {
			continue
		}
		escapedMod := strings.Join(parts[:i], string(os.PathSeparator))
		modPath, err := module.UnescapePath(escapedMod)
		if err != nil {
			return ModuleInfo{}, fmt.Errorf("unescaping module path: %w", err)
		}
		versionFile := parts[i+1]
		escapedVersion := strings.TrimSuffix(strings.TrimSuffix(strings.TrimSuffix(versionFile, ".zip"), ".mod"), ".info")
		version, err := module.UnescapeVersion(escapedVersion)
		if err != nil {
			return ModuleInfo{}, fmt.Errorf("unescaping module version: %w", err)
		}
		return ModuleInfo{Path: modPath, Version: version}, nil
	}

	return ModuleInfo{}, fmt.Errorf("invalid module cache path: %s", cacheFilePath)
}

// moduleExtractDir is $GOPATH/pkg/mod/<escaped-path>@<escaped-version>, which is
// where the go command looks up an unpacked module. Cache filenames are escaped;
// ModuleInfo holds the unescaped path and version.
func moduleExtractDir(extractDir string, mod ModuleInfo) (string, error) {
	escapedPath, err := module.EscapePath(mod.Path)
	if err != nil {
		return "", fmt.Errorf("escaping path: %w", err)
	}
	escapedVersion, err := module.EscapeVersion(mod.Version)
	if err != nil {
		return "", fmt.Errorf("escaping version: %w", err)
	}
	return filepath.Join(extractDir, escapedPath+"@"+escapedVersion), nil
}

func validateFileHash(filePath, expectedHash string) error {
	if !strings.HasPrefix(expectedHash, "h1:") {
		return fmt.Errorf("unsupported hash algorithm: %s", expectedHash)
	}

	data, err := os.ReadFile(filePath)
	if err != nil {
		return err
	}

	actualHash, err := dirhash.Hash1([]string{"go.mod"}, func(string) (io.ReadCloser, error) {
		return io.NopCloser(strings.NewReader(string(data))), nil
	})
	if err != nil {
		return fmt.Errorf("computing file hash: %w", err)
	}

	if actualHash != expectedHash {
		return fmt.Errorf("checksum mismatch: expected %s, got %s", expectedHash, actualHash)
	}

	return nil
}

func validateZipHash(zipPath, expectedHash string) error {
	if !strings.HasPrefix(expectedHash, "h1:") {
		return fmt.Errorf("unsupported hash algorithm: %s", expectedHash)
	}

	actualHash, err := dirhash.HashZip(zipPath, dirhash.Hash1)
	if err != nil {
		return fmt.Errorf("computing zip hash: %w", err)
	}

	if actualHash != expectedHash {
		return fmt.Errorf("checksum mismatch: expected %s, got %s", expectedHash, actualHash)
	}

	return nil
}

func extractZip(zipPath, destDir string) error {
	// Check if already extracted
	if _, err := os.Stat(destDir); err == nil {
		entries, err := os.ReadDir(destDir)
		if err == nil && len(entries) > 0 {
			return nil // Already extracted with content
		}
	}

	r, err := zip.OpenReader(zipPath)
	if err != nil {
		return err
	}
	defer r.Close()

	// Find the common prefix - look for directory with @version
	var prefix string
	for _, f := range r.File {
		if !f.FileInfo().IsDir() {
			parts := strings.Split(f.Name, "/")
			for i, part := range parts {
				if strings.Contains(part, "@") {
					prefix = strings.Join(parts[:i+1], "/") + "/"
					break
				}
			}
			if prefix != "" {
				break
			}
		}
	}

	// Fallback to first directory component
	if prefix == "" && len(r.File) > 0 {
		firstPath := r.File[0].Name
		if idx := strings.Index(firstPath, "/"); idx > 0 {
			prefix = firstPath[:idx+1]
		}
	}

	for _, f := range r.File {
		if !strings.HasPrefix(f.Name, prefix) {
			continue
		}

		relativePath := strings.TrimPrefix(f.Name, prefix)
		if relativePath == "" {
			continue
		}

		fpath := filepath.Join(destDir, relativePath)

		// Check for ZipSlip vulnerability
		if !strings.HasPrefix(fpath, filepath.Clean(destDir)+string(os.PathSeparator)) {
			return fmt.Errorf("invalid file path: %s", fpath)
		}

		if f.FileInfo().IsDir() {
			if err := os.MkdirAll(fpath, 0o755); err != nil {
				return err
			}
			continue
		}

		if err := os.MkdirAll(filepath.Dir(fpath), 0o755); err != nil {
			return err
		}

		outFile, err := os.OpenFile(fpath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o444)
		if err != nil {
			return err
		}

		rc, err := f.Open()
		if err != nil {
			outFile.Close()
			return err
		}

		_, err = io.Copy(outFile, rc)
		outFile.Close()
		rc.Close()

		if err != nil {
			return err
		}
	}

	return nil
}
