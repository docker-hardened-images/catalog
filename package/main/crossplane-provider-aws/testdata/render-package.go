//go:build ignore

// render-package renders the provider package metadata template that
// crossplane-contrib/provider-upjet-aws keeps at package/crossplane.yaml.tmpl.
// Upstream renders it with `crossplane xpkg batch`, which needs a Docker
// daemon and so cannot run in a package build. The template syntax is Go
// text/template and the data keys below are the ones the template reads.
//
// usage: go run render-package.go TEMPLATE OUTPUT SERVICE NAME PROVIDER_NAME AUTH_GROUP
package main

import (
	"fmt"
	"os"
	"text/template"
)

func main() {
	if len(os.Args) != 7 {
		fmt.Fprintln(os.Stderr, "usage: render-package TEMPLATE OUTPUT SERVICE NAME PROVIDER_NAME AUTH_GROUP")
		os.Exit(2)
	}
	tmplPath, outPath := os.Args[1], os.Args[2]
	data := map[string]string{
		"Service":           os.Args[3],
		"Name":              os.Args[4],
		"ProviderName":      os.Args[5],
		"ProviderAuthGroup": os.Args[6],
	}

	// missingkey=error makes a template that starts reading a new key fail
	// here, instead of rendering "<no value>" into the package metadata.
	tmpl, err := template.New("package").Option("missingkey=error").ParseFiles(tmplPath)
	if err != nil {
		fmt.Fprintln(os.Stderr, "parse template:", err)
		os.Exit(1)
	}
	out, err := os.Create(outPath)
	if err != nil {
		fmt.Fprintln(os.Stderr, "create output:", err)
		os.Exit(1)
	}
	defer out.Close()
	if err := tmpl.ExecuteTemplate(out, "crossplane.yaml.tmpl", data); err != nil {
		fmt.Fprintln(os.Stderr, "render template:", err)
		os.Exit(1)
	}
}
