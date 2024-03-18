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
				"applications[0].name":                 "test-bitnami-nginx",
				"applications[0].namespace":            "test-bitnami-nginx",
				"applications[0].chart":                "nginx",
				"applications[0].repoURL":              "https://charts.bitnami.com/bitnami",
				"applications[0].targetRevision":       "15.14.0",
				"namespaces[0]":                        "test-bitnami-nginx",
				"extraManifests[0].apiVersion":         "metallb.io/v1beta1",
				"extraManifests[0].kind":               "IPAddressPool",
				"extraManifests[0].metadata.name":      "primary",
				"extraManifests[0].metadata.namespace": "metallb-system",
				"extraManifests[0].spec.addresses[0]":  "192.168.121.248/30",
			},
		})
	}
}
