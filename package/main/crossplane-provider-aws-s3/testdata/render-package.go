//go:build ignore

// render-package renders the provider package metadata template that
// crossplane-contrib/provider-upjet-aws keeps at package/crossplane.yaml.tmpl.
// Upstream renders it with `crossplane xpkg batch`, which needs a Docker
// daemon and so cannot run in a package build. The template syntax is Go
// text/template and the data keys below are the ones the template reads.
//
// A service package depends on the family provider. The template renders that
// dependency from XpkgRegOrg and DepConstraint, which this helper sets to the
// values of upstream's crossplane-contrib release build. It then replaces the
// one dependsOn entry with DEPENDS_ON_PROVIDER and DEPENDS_ON_VERSION. It fails
// when the rendered text does not hold exactly one dependsOn entry of the shape
// upstream renders, so a template change cannot make the replacement a no-op.
//
// usage: go run render-package.go TEMPLATE OUTPUT SERVICE NAME PROVIDER_NAME AUTH_GROUP DEPENDS_ON_PROVIDER DEPENDS_ON_VERSION
package main

import (
	"bytes"
	"fmt"
	"os"
	"regexp"
	"strings"
	"text/template"
)

const (
	// The values of upstream's crossplane-contrib release build
	// (CONFIG_DEPENDENCY_REG_ORG and DEP_CONSTRAINT for a release VERSION).
	upstreamRegOrg        = "xpkg.crossplane.io/crossplane-contrib"
	upstreamDepConstraint = ">= 0.0.0"
)

var (
	// An OCI repository path with no tag and no digest.
	providerRE = regexp.MustCompile(`^[a-z0-9]+([.-][a-z0-9]+)*(:[0-9]+)?(/[a-z0-9]+([._-][a-z0-9]+)*)+$`)
	// A semver constraint or version, with nothing that needs YAML escaping.
	versionRE = regexp.MustCompile(`^[0-9A-Za-z.<>=!~^ ,-]+$`)
)

func fail(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "render-package: "+format+"\n", args...)
	os.Exit(1)
}

func dependsOn(provider, version string) string {
	return "  dependsOn:\n    - provider: " + provider + "\n      version: \"" + version + "\"\n"
}

func main() {
	if len(os.Args) != 9 {
		fmt.Fprintln(os.Stderr, "usage: render-package TEMPLATE OUTPUT SERVICE NAME PROVIDER_NAME AUTH_GROUP DEPENDS_ON_PROVIDER DEPENDS_ON_VERSION")
		os.Exit(2)
	}
	tmplPath, outPath := os.Args[1], os.Args[2]
	providerName := os.Args[5]
	depProvider, depVersion := os.Args[7], os.Args[8]

	if !providerRE.MatchString(depProvider) {
		fail("DEPENDS_ON_PROVIDER %q is not an OCI repository path without a tag or digest", depProvider)
	}
	if !versionRE.MatchString(depVersion) || strings.TrimSpace(depVersion) == "" {
		fail("DEPENDS_ON_VERSION %q is empty or holds characters a constraint does not use", depVersion)
	}

	data := map[string]string{
		"Service":           os.Args[3],
		"Name":              os.Args[4],
		"ProviderName":      providerName,
		"ProviderAuthGroup": os.Args[6],
		"XpkgRegOrg":        upstreamRegOrg,
		"DepConstraint":     upstreamDepConstraint,
	}

	// missingkey=error makes a template that starts reading a new key fail
	// here, instead of rendering "<no value>" into the package metadata.
	tmpl, err := template.New("package").Option("missingkey=error").ParseFiles(tmplPath)
	if err != nil {
		fail("parse template: %v", err)
	}
	var buf bytes.Buffer
	if err := tmpl.ExecuteTemplate(&buf, "crossplane.yaml.tmpl", data); err != nil {
		fail("render template: %v", err)
	}
	out := buf.String()

	upstream := dependsOn(upstreamRegOrg+"/provider-family-"+providerName, upstreamDepConstraint)
	if n := strings.Count(out, upstream); n != 1 {
		fail("want exactly one dependsOn entry of the form\n%s\nin the rendered template, found %d", upstream, n)
	}
	if n := strings.Count(out, "dependsOn:"); n != 1 {
		fail("want exactly one dependsOn key in the rendered template, found %d", n)
	}
	if n := strings.Count(out, "- provider:"); n != 1 {
		fail("want exactly one dependsOn provider entry in the rendered template, found %d", n)
	}
	out = strings.Replace(out, upstream, dependsOn(depProvider, depVersion), 1)

	if err := os.WriteFile(outPath, []byte(out), 0o644); err != nil {
		fail("write output: %v", err)
	}
}
