package test

import (
	"github.com/stretchr/testify/require"
	"github.com/stretchr/testify/suite"
	"path/filepath"
	"testing"
	"vagrant-kubespray-argocd/infra/test/utils"
)

func TestAdvancedApplicationTemplate(t *testing.T) {
	t.Parallel()

	helmChartPah, err := filepath.Abs("../infra")
	require.NoError(t, err)

	applicationProperties := map[string]map[string]string{
		"helm-values": {
			"applications[0].name":           "cert-manager",
			"applications[0].namespace":      "cert-manager",
			"applications[0].chart":          "cert-manager",
			"applications[0].repoURL":        "https://charts.jetstack.io",
			"applications[0].targetRevision": "v1.14.3",
		},
		"helmInlineAVPValue": {
			"applications[0].name":               "cert-manager",
			"applications[0].namespace":          "cert-manager",
			"applications[0].chart":              "cert-manager",
			"applications[0].repoURL":            "https://charts.jetstack.io",
			"applications[0].targetRevision":     "v1.14.3",
			"applications[0].helmInlineAVPValue": "true",
		},
		"ignoreDifferences": {
			"applications[0].name":                                 "my-app",
			"applications[0].namespace":                            "my-app-ns",
			"applications[0].chart":                                "my-app-chart",
			"applications[0].repoURL":                              "https://exmplae.com",
			"applications[0].targetRevision":                       "7.7.7",
			"applications[0].ignoreDifferences[0].group":           "admissionregistration.k8s.io",
			"applications[0].ignoreDifferences[0].kind":            "ValidatingWebhookConfiguration",
			"applications[0].ignoreDifferences[0].name":            "istiod-default-validator",
			"applications[0].ignoreDifferences[0].jsonPointers[0]": "/webhooks/0/failurePolicy",
		},
	}

	for goldenFileName, applicationValues := range applicationProperties {
		suite.Run(t, &utils.TemplateGoldenTest{
			ChartPath:      helmChartPah,
			Release:        "test-applications",
			GoldenFileName: "application-" + goldenFileName,
			Templates:      []string{"templates/application.yaml"},
			SetValues:      applicationValues,
		})
	}
}
