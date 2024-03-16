package test

import (
	"path/filepath"
	"testing"
	"vagrant-kubespray-argocd/test/utils"

	"github.com/stretchr/testify/require"
	"github.com/stretchr/testify/suite"
)

func TestGoldenDefaultsTemplate(t *testing.T) {
	t.Parallel()

	helmChartPah, err := filepath.Abs("../infra")
	require.NoError(t, err)

	templateNames := []string{"application", "namespace", "extra-manifests"}

	for _, name := range templateNames {
		suite.Run(t, &utils.TemplateGoldenTest{
			ChartPath:      helmChartPah,
			Release:        "applications",
			GoldenFileName: name,
			Templates:      []string{"templates/" + name + ".yaml"},
			SetValues: map[string]string{
				"applications[0].name":                 "my-app",
				"applications[0].namespace":            "my-app-ns",
				"applications[0].chart":                "my-app-chart",
				"applications[0].repoURL":              "https://exmplae.com",
				"applications[0].targetRevision":       "7.7.7",
				"namespaces[0]":                        "test-ns",
				"extraManifests[0].apiVersion":         "metallb.io/v1beta1",
				"extraManifests[0].kind":               "IPAddressPool",
				"extraManifests[0].metadata.name":      "primary",
				"extraManifests[0].metadata.namespace": "metallb-system",
				"extraManifests[0].spec.addresses[0]":  "192.168.121.248/30",
			},
		})
	}
}
