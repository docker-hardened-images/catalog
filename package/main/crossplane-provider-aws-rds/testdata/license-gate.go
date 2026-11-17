//go:build ignore

// license-gate installs the license material for a Go binary and fails the
// build when what ships does not match what the package declares.
//
// The module list comes from the binary's own build info (debug/buildinfo,
// the data behind `go version -m`), never from go.mod, go.sum or a walk of
// the module cache. For every module in that list the gate copies the
// license-like files at the module root, writes MODULES.txt, and checks:
//
//	(a) set equality between the build info and the shipped directories
//	(b) every module has a non-empty license file, or a reasoned exception
//	(c) every LICENSE, LICENCE and COPYING file matches a known text
//	(d) every matched id is on the allow list, and no denied text appears
//	(e) the observed ids plus the main module's id equal the license string
//	(f) the MPL-2.0 count is above zero and the replace target is MPL-2.0
//
// NOTICE and PATENTS files are copied and not classified: they are not
// license texts.
//
// usage: go run license-gate.go -binary BIN -project DIR -out DIR -license EXPR
package main

import (
	"bytes"
	"debug/buildinfo"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

const (
	mainID          = "Apache-2.0"
	mplReplacePath  = "github.com/upbound/terraform-provider-aws"
	licenseFileGlob = `(?i)^(licen[cs]e|copying|notice|patents)`
)

var allowed = map[string]bool{
	"Apache-2.0": true, "MPL-2.0": true, "MIT": true, "BSD-3-Clause": true,
	"BSD-2-Clause": true, "ISC": true, "Unicode-DFS-2016": true,
}

// exceptions lists modules that ship no license file at the module root,
// with the reason each is accepted. It starts empty on purpose: an entry here
// is a decision recorded in the package README.
var exceptions = map[string]string{}

var denied = []string{
	"gnu general public license", "gnu lesser general public license", "gnu affero",
	"server side public license", "business source license", "eclipse public license",
	"common development and distribution license", "common public attribution",
}

type module struct {
	path, version         string // as the build info names them (the replaced identity)
	instPath, instVersion string // what is compiled in (the replace target if any)
	dir                   string
	files                 []string
	ids                   map[string]bool
}

func fatalf(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "license-gate: "+format+"\n", args...)
	os.Exit(1)
}

func main() {
	binary := flag.String("binary", "", "built binary to read build info from")
	project := flag.String("project", "", "checkout holding the project LICENSE and NOTICE")
	out := flag.String("out", "", "package doc directory to fill")
	expr := flag.String("license", "", "license expression the package declares")
	flag.Parse()
	if *binary == "" || *project == "" || *out == "" || *expr == "" {
		flag.Usage()
		os.Exit(2)
	}

	info, err := buildinfo.ReadFile(*binary)
	if err != nil {
		fatalf("read build info of %s: %v", *binary, err)
	}
	if len(info.Deps) == 0 {
		fatalf("build info of %s lists no modules", *binary)
	}

	mods := make([]*module, 0, len(info.Deps))
	for _, d := range info.Deps {
		m := &module{path: d.Path, version: d.Version, instPath: d.Path, instVersion: d.Version, ids: map[string]bool{}}
		if d.Replace != nil {
			m.instPath, m.instVersion = d.Replace.Path, d.Replace.Version
		}
		mods = append(mods, m)
	}
	resolveDirs(mods)

	re := regexp.MustCompile(licenseFileGlob)
	third := filepath.Join(*out, "third-party")
	if err := os.MkdirAll(third, 0o755); err != nil {
		fatalf("%v", err)
	}
	var problems []string
	observed := map[string]bool{}

	for _, m := range mods {
		if m.dir == "" {
			fatalf("no directory for module %s@%s: refusing to skip it", m.path, m.version)
		}
		entries, err := os.ReadDir(m.dir)
		if err != nil {
			fatalf("read %s: %v", m.dir, err)
		}
		dst := filepath.Join(third, m.instPath+"@"+m.instVersion)
		for _, e := range entries {
			if !e.Type().IsRegular() || !re.MatchString(e.Name()) {
				continue
			}
			data, err := os.ReadFile(filepath.Join(m.dir, e.Name()))
			if err != nil {
				fatalf("read %s: %v", filepath.Join(m.dir, e.Name()), err)
			}
			if len(bytes.TrimSpace(data)) == 0 {
				continue
			}
			if err := os.MkdirAll(dst, 0o755); err != nil {
				fatalf("%v", err)
			}
			if err := os.WriteFile(filepath.Join(dst, e.Name()), data, 0o644); err != nil {
				fatalf("%v", err)
			}
			m.files = append(m.files, e.Name())
			base := strings.ToLower(e.Name())
			if strings.HasPrefix(base, "notice") || strings.HasPrefix(base, "patents") {
				continue
			}
			ids, bad := Classify(data)
			for _, b := range bad {
				problems = append(problems, fmt.Sprintf("%s@%s %s: denied text %q", m.instPath, m.instVersion, e.Name(), b))
			}
			if len(ids) == 0 {
				problems = append(problems, fmt.Sprintf("%s@%s %s: matches no known license text", m.instPath, m.instVersion, e.Name()))
			}
			for _, id := range ids {
				if !allowed[id] {
					problems = append(problems, fmt.Sprintf("%s@%s %s: id %s is not on the allow list", m.instPath, m.instVersion, e.Name(), id))
				}
				m.ids[id] = true
				observed[id] = true
			}
		}
		if !hasLicenseText(m) {
			if reason, ok := exceptions[m.instPath]; ok {
				fmt.Printf("license-gate: exception for %s: %s\n", m.instPath, reason)
			} else {
				problems = append(problems, fmt.Sprintf("%s@%s: no non-empty license file at the module root", m.instPath, m.instVersion))
			}
		}
	}

	// Project files, copied byte for byte from the pinned checkout.
	for _, name := range []string{"LICENSE", "NOTICE"} {
		data, err := os.ReadFile(filepath.Join(*project, name))
		if err != nil {
			fatalf("read project %s: %v", name, err)
		}
		if len(bytes.TrimSpace(data)) == 0 {
			fatalf("project %s is empty", name)
		}
		if name == "LICENSE" {
			ids, _ := Classify(data)
			if len(ids) != 1 || ids[0] != mainID {
				fatalf("project LICENSE classifies as %v, want [%s]", ids, mainID)
			}
		}
		if err := os.WriteFile(filepath.Join(*out, name), data, 0o644); err != nil {
			fatalf("%v", err)
		}
	}

	// MODULES.txt, sorted so the file does not depend on build info order.
	sort.Slice(mods, func(i, j int) bool { return mods[i].instPath < mods[j].instPath })
	var b strings.Builder
	mpl := 0
	replaceOK := false
	for _, m := range mods {
		ids := keys(m.ids)
		sort.Strings(ids)
		sort.Strings(m.files)
		repl := "-"
		if m.instPath != m.path || m.instVersion != m.version {
			repl = m.path + "@" + m.version
		}
		fmt.Fprintf(&b, "%s@%s\treplaces=%s\tlicenses=%s\tfiles=%s\n", m.instPath, m.instVersion, repl, strings.Join(ids, ","), strings.Join(m.files, ","))
		if m.ids["MPL-2.0"] {
			mpl++
		}
		if m.instPath == mplReplacePath && m.instVersion != "" && m.ids["MPL-2.0"] {
			replaceOK = true
		}
	}
	if err := os.WriteFile(filepath.Join(*out, "MODULES.txt"), []byte(b.String()), 0o644); err != nil {
		fatalf("%v", err)
	}

	// (a) shipped directories equal build info modules.
	want := map[string]bool{}
	for _, m := range mods {
		if len(m.files) > 0 {
			want[m.instPath+"@"+m.instVersion] = true
		}
	}
	have := shippedDirs(third)
	for k := range have {
		if !want[k] {
			problems = append(problems, "shipped directory without a build info module: "+k)
		}
	}
	for k := range want {
		if !have[k] {
			problems = append(problems, "build info module without a shipped directory: "+k)
		}
	}

	// (e) observed ids plus the main module's id equal the license string.
	observed[mainID] = true
	terms := map[string]bool{}
	for _, t := range strings.Split(*expr, " AND ") {
		terms[strings.TrimSpace(t)] = true
	}
	for id := range observed {
		if !terms[id] {
			problems = append(problems, fmt.Sprintf("license string understates the payload: %s is shipped but is not in %q", id, *expr))
		}
	}
	for t := range terms {
		if !observed[t] {
			problems = append(problems, fmt.Sprintf("license string overstates the payload: %s has no module behind it", t))
		}
	}
	// (f)
	if mpl == 0 {
		problems = append(problems, "no MPL-2.0 module in the build info")
	}
	if !replaceOK {
		problems = append(problems, mplReplacePath+" is missing from the build info or is not MPL-2.0")
	}

	sort.Strings(problems)
	if len(problems) > 0 {
		fmt.Fprintf(os.Stderr, "license-gate: %d problem(s):\n", len(problems))
		for _, p := range problems {
			fmt.Fprintln(os.Stderr, "  - "+p)
		}
		os.Exit(1)
	}
	ids := keys(observed)
	sort.Strings(ids)
	fmt.Printf("license-gate: %d modules, %d MPL-2.0, ids %s\n", len(mods), mpl, strings.Join(ids, ", "))
}

// resolveDirs asks the go command for the directory of each module in the
// build list. Using the build list (no versions in the query) makes go apply
// go.mod's replace directives, so a replaced module reports the replace
// target's directory.
func resolveDirs(mods []*module) {
	args := []string{"list", "-m", "-f", "{{.Path}}\t{{.Version}}\t{{.Dir}}\t{{if .Replace}}{{.Replace.Path}}\t{{.Replace.Version}}\t{{.Replace.Dir}}{{end}}"}
	for _, m := range mods {
		args = append(args, m.path)
	}
	cmd := exec.Command("go", args...)
	var stdout, stderr bytes.Buffer
	cmd.Stdout, cmd.Stderr = &stdout, &stderr
	if err := cmd.Run(); err != nil {
		fatalf("go list -m: %v\n%s", err, stderr.String())
	}
	byPath := map[string]*module{}
	for _, m := range mods {
		byPath[m.path] = m
	}
	seen := 0
	for _, line := range strings.Split(strings.TrimRight(stdout.String(), "\n"), "\n") {
		f := strings.Split(line, "\t")
		if len(f) < 3 {
			fatalf("unexpected go list output %q", line)
		}
		m, ok := byPath[f[0]]
		if !ok {
			fatalf("go list returned a module the build info does not have: %s", f[0])
		}
		dir := f[2]
		if len(f) >= 6 && f[3] != "" {
			if f[3] != m.instPath || f[4] != m.instVersion {
				fatalf("replace of %s differs between the build info (%s@%s) and the build list (%s@%s)", m.path, m.instPath, m.instVersion, f[3], f[4])
			}
			dir = f[5]
		} else if f[1] != m.version {
			fatalf("module %s is %s in the build list and %s in the build info", m.path, f[1], m.version)
		}
		m.dir = dir
		seen++
	}
	if seen != len(mods) {
		fatalf("go list returned %d modules for %d build info modules", seen, len(mods))
	}
}

func hasLicenseText(m *module) bool { return len(m.files) > 0 }

func shippedDirs(third string) map[string]bool {
	have := map[string]bool{}
	_ = filepath.WalkDir(third, func(p string, d os.DirEntry, err error) error {
		if err != nil {
			fatalf("walk %s: %v", p, err)
		}
		if d.IsDir() {
			return nil
		}
		rel, _ := filepath.Rel(third, filepath.Dir(p))
		have[filepath.ToSlash(rel)] = true
		return nil
	})
	return have
}

func keys(m map[string]bool) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	return out
}

var ws = regexp.MustCompile(`\s+`)

func norm(data []byte) string {
	return strings.ToLower(ws.ReplaceAllString(string(data), " "))
}

// mplSecondary is the one place the MPL-2.0 text names the GNU licenses: its
// definition of "Secondary License". The denied-text check must not read it as
// a GPL license.
var mplSecondary = regexp.MustCompile(`["“”]?secondary license["“”]? means either the gnu general public license, version 2\.0, the gnu lesser general public license, version 2\.1, the gnu affero general public license, version 3\.0, or any later versions of those licenses\.`)

// Classify returns the license ids found in a license text, and any denied
// text it contains.
func Classify(data []byte) (ids []string, bad []string) {
	t := norm(data)
	for _, d := range denied {
		if strings.Contains(mplSecondary.ReplaceAllString(t, ""), d) {
			bad = append(bad, d)
		}
	}
	has := func(s string) bool { return strings.Contains(t, s) }
	if (has("apache license") && has("version 2.0, january 2004")) || has("licensed under the apache license, version 2.0") {
		ids = append(ids, "Apache-2.0")
	}
	if has("mozilla public license version 2.0") || has("mozilla public license, version 2.0") {
		ids = append(ids, "MPL-2.0")
	}
	if has("permission is hereby granted, free of charge, to any person obtaining a copy") {
		ids = append(ids, "MIT")
	}
	if has("redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met") {
		if has("neither the name of") && (has("endorse or promote") || has("endorse or promote products")) {
			ids = append(ids, "BSD-3-Clause")
		} else {
			ids = append(ids, "BSD-2-Clause")
		}
	}
	if has("permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted") {
		ids = append(ids, "ISC")
	}
	if has("unicode data files include all data files under the directories") {
		ids = append(ids, "Unicode-DFS-2016")
	}
	return ids, bad
}
