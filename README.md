# RHDHPAI Rolling Demo GitOps

**Rolling Demo Last Update:** 10 April 2025

The repository contains the gitops resources required to deploy an instance of the RHDHPAI rolling demo. The project is currently live at [rolling-demo-backstage-rolling-demo-ns.apps.rosa.redhat-ai-dev.m6no.p3.openshiftapps.com](https://rolling-demo-backstage-rolling-demo-ns.apps.rosa.redhat-ai-dev.m6no.p3.openshiftapps.com).

## Contents

The rolling demo combines the following components so far:

- The redhat developer hub chart ([rhdh-chart](https://github.com/redhat-developer/rhdh-chart)), in an attempt to keep the demo up-to-date with the latest changes of RHDH.
- The [AI software templates](https://github.com/redhat-ai-dev/ai-lab-template), a collection of Software Templates based on AI applications.
- The [AI homepage](https://github.com/redhat-developer/rhdh-plugins/tree/main/workspaces/ai-integrations/plugins/ai-experience), provides users with better visibility into the AI-related assets, tools and resources.

## Capabilities & Limitations

- Access to the rolling demo is provided through Red Hat SSO. If you have a problem accessing the rolling demo instance you please ping `team-rhdhpai` in the `#forum-rhdh-plugins-and-ai` slack channel.
- Every authenticated user has access to the AI software templates from the catalog. That said, you are able to choose the template you prefer and give it a try.
- Currently our demo doesn't support deployment which require GPU.
- In order to avoid overprovisioning of resources, the rolling demo uses a `pruner` cronjob that deletes all Software Template applications that are older than 24 hours. That means that all the openshift **and** github resources (deployments, repositories, argocd applications, etc.) are removed.

## Rolling demo setup

Some instructions on how to setup an instance of the rolling demo on your own can be found in [docs/SETUP_GUIDE.md](./docs/SETUP_GUIDE.md)
