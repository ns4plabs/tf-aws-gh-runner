# Self-hosted GitHub Runners by pl-strflt

This project uses [terraform-aws-github-runner](https://github.com/philips-labs/terraform-aws-github-runner) to provide self-hosted GitHub runners. It expands on this project by addig a routing layer which allows configuration of up to a 100 different types of runners under a single GitHub App.

## Usage

1. Add the full repository name where you intend to use the self-hosted runners to `repository_allowlist` of the runner type you're interested in in [runners.tf](runners.tf). Create a PR, wait for your changes to be applied and merged.
1. Ensure [pl-strflt/tf-aws-gh-runner](https://github.com/apps/pl-strflt-tf-aws-gh-runner) GitHub App is installed in your organization.
1. Request the self-hosted runner in your workflow through `job.runs-on` parameter. E.g. `runs-on: [self-hosted, linux, x64, large-linux-runner]`, `runs-on: [self-hosted, windows, x64, large-windows-runner]`.

**IMPORTANT**: Please read what the [security implications of using self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners/about-self-hosted-runners#self-hosted-runner-security) are. If you [enable self-hosted runners in public repositories](https://docs.github.com/en/actions/hosting-your-own-runners/managing-access-to-self-hosted-runners-using-groups), we suggest you also [restrict the workflows allowed to use self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners/managing-access-to-self-hosted-runners-using-groups) and think carefully about implications of executing untrusted code. It might also be a good idea to [require approval for all outside collaborators](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository#configuring-required-approval-for-workflows-from-public-forks).

## Routing Layer

In the original design, webhook calls are received by an API Gateway which routes the traffic to the associated webhook lambda. Each runner type has its' own API Gateway and webhook lambda.

GitHub Apps allow specifying at most 1 webhook endpoint. Thus, with the original setup, we'd need as many GitHub Apps as runner types.

Here, we propose to replace all the aforementioned API Gateways with a single API Gateway followed by an Application ELB. In this setup, the public Internet facing API Gateway receives webhook calls, retrieves `workflow_job.labels` from the body of the request, puts it in the `X-GitHub-Workflow_Job-Labels` header and forwards the modified request to the ALB. The ALB looks for a webhook lamda configured to handle events matching the labels from `X-GitHub-Workflow_Job-Labels`. If it finds one, it forwards the request to that lambda. Otherwise, it responds with a 404.

**IMPORTANT**: This setup requires all runner types to have unique `extra_labels` and have `runner_enable_workflow_job_labels_check` set to `true`.
