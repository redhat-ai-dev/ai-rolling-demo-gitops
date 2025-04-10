## Rolling demo setup

Here are the steps required to setup an instance of the rolling demo on your own:

### Pre-requisites

In order to install the demo your cluster shoud have already installed:

- [Openshift Gitops](https://www.redhat.com/en/technologies/cloud-computing/openshift/gitops)
- [Openshift Pipelines](https://www.redhat.com/en/technologies/cloud-computing/openshift/pipelines)

Next, you will need to do two minor configuration steps on your `ArgoCD` instance:

#### Create the argocd token

- If your argo cd admin does not have the `apiKey` capability, run:

```bash
# Get the argocd CRD from the openshift gitops namespace
kubectl get argocd openshift-gitops -n openshift-gitops -o yaml > argocd.yaml
```

```yaml
# add this section under .spec.
extraConfig:
  accounts.admin: apiKey
```

```bash
# finally apply the updated resource to the openshift-gitops namespace
kubectl apply -f argocd.yaml -n openshift-gitops
```

- Once your CRD is updated you will be able to see the `apiKey` capability in your admin user.

- You can create the token either [via the CLI](https://argo-cd.readthedocs.io/en/latest/user-guide/commands/argocd_account_generate-token/), or, by going to argocd on your cluster > `settings` > `accounts` > `admin` > `Generate New` (token) and generate a token for admin. This token should be given to the `ARGOCD_API_TOKEN` variable.

- Note, if you need to register and authenticate this github repo in your argoCD instance by going to > `settings` > `repositories` > `Connect Repo`.

#### Create the `private-env` file

- Create a file called `private-env` inside the [scripts/](./scripts/) directory and copy all the contents of the [scripts/env](./scripts/env) file there.
- Populate all the variables mentioned in the file with your secrets.

### Installation

After the required steps above you can simply use the [prepare-rolling-demo.sh](./scripts/prepare-rolling-demo.sh) script to prepare everything you need for the installation.

Finally you have to create your argocd application in the `openshift-gitops` namespace:

```bash
kubectl apply -f gitops/application.yaml -n openshift-gitops
```
