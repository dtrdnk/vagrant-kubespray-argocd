package test

import (
	"path/filepath"
	"testing"
	"vagrant-kubespray-argocd/test/utils"

	"github.com/stretchr/testify/require"
	"github.com/stretchr/testify/suite"
)

func TestApplicationCommonTemplate(t *testing.T) {
	t.Parallel()

	helmChartPah, err := filepath.Abs("../infra")
	require.NoError(t, err)

	suite.Run(t, &utils.TemplateGoldenTest{
		ChartPath:      helmChartPah,
		Release:        "applications",
		GoldenFileName: "application-advanced",
		Templates:      []string{"templates/application.yaml"},

		SetValues: map[string]string{
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
	})
}

func TestApplicationAdvancedTemplate(t *testing.T) {
	t.Parallel()

	helmChartPah, err := filepath.Abs("../infra")
	require.NoError(t, err)

	suite.Run(t, &utils.TemplateGoldenTest{
		ChartPath:      helmChartPah,
		Release:        "applications",
		GoldenFileName: "application-helmInlineAVPValue",
		Templates:      []string{"templates/application.yaml"},

		SetValues: map[string]string{
			"applications[0].name":               "cert-manager",
			"applications[0].namespace":          "cert-manager",
			"applications[0].chart":              "cert-manager",
			"applications[0].repoURL":            "https://charts.jetstack.io",
			"applications[0].targetRevision":     "v1.14.3",
			"applications[0].helmInlineAVPValue": "true",
		},
	})
}
