# RHDHPAI Rolling Demo GitOps

**Rolling Demo Last Update:** 10 April 2025

The repository contains the gitops resources required to deploy an instance of the RHDHPAI rolling demo. The project is currently live at [rolling-demo-backstage-rolling-demo-ns.apps.rosa.redhat-ai-dev.m6no.p3.openshiftapps.com](https://rolling-demo-backstage-rolling-demo-ns.apps.rosa.redhat-ai-dev.m6no.p3.openshiftapps.com).

## Contents

The rolling demo combines the following components so far:

- The redhat developer hub chart ([rhdh-chart](https://github.com/redhat-developer/rhdh-chart)), in an attempt to keep the demo up-to-date with the latest changes of RHDH.
- The [AI software templates](https://github.com/redhat-ai-dev/ai-lab-template), a collection of Software Templates based on AI applications.
- The [AI homepage](https://github.com/redhat-developer/rhdh-plugins/tree/main/workspaces/ai-integrations/plugins/ai-experience), provides users with better visibility into the AI-related assets, tools and resources.

## Capabilities & Limitations

### Access

- Access to the rolling demo is provided through Red Hat SSO.
- Every authenticated user has access to the AI software templates from the catalog. That said, you are able to choose the template you prefer and give it a try.

### AI Software Templates

- Currently our demo doesn't support deployment which require GPU.
- The rolling demo, currently supports only Github deployments. That said, you cannot use `Gitlab` as `Host Type` when creating
- The github organization set to serve the demo is `ai-rolling-demo`, that said you need to keep it as the `Repository Owner`.
- Same applies for the `Image Organization` value. The `quay.io` repository corresponding to the demo is `rhdhpai-rolling-demo`.

### Limited Application Lifecycle

- In order to avoid overprovisioning of resources, the rolling demo uses a `pruner` cronjob that deletes all Software Template applications that are older than 24 hours. That means that all the openshift **and** github resources (deployments, repositories, argocd applications, etc.) are removed.

## Rolling demo setup

Some instructions on how to setup an instance of the rolling demo on your own can be found in [docs/SETUP_GUIDE.md](./docs/SETUP_GUIDE.md)

## Troubleshooting

### I cannot login to the rolling demo

If it is your first time accessing our cluster, keep in mind that we have an automation in place to register new users, so you might have to wait a few minutes for this process to be completed. If, after your second attempt you still have a problem accessing the rolling demo instance you please ping `team-rhdhpai` in the `#forum-rhdh-plugins-and-ai` slack channel.
