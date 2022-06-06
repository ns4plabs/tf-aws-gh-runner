# Self-hosted GitHub Runners by pl-strflt

This project uses [terraform-aws-github-runner](https://github.com/philips-labs/terraform-aws-github-runner) to provide self-hosted GitHub runners. It expands on this project by addig a routing layer which allows configuration of up to a 100 different types of runners under a single GitHub App.

## Runner Types

| Name | OS | Architecture | Instance Type | AMI |
| --- | --- | --- | --- | --- |
| linux-x64-default | linux | x64 | [m5.large](https://instances.vantage.sh/?selected=m5.large) | `amzn2-ami-kernel-5.*-hvm-*-x86_64-gp2` by Amazon |
| windows-x64-default | linux | x64 | [m5.large](https://instances.vantage.sh/?selected=m5.large) | `Windows_Server-20H2-English-Core-ContainersLatest-*` by Amazon |
| linux-arm64-default | linux | arm64 | [m6g.large](https://instances.vantage.sh/?selected=m6g.large) | `amzn2-ami-kernel-5.*-hvm-*-arm64-gp2` by Amazon |
| testground | linux | x64 | [m5.2xlarge](https://instances.vantage.sh/?selected=m5.2xlarge) | `github-runner-ubuntu-focal-amd64-202206031118-testground` built with [testground.pkrvars](images/ubuntu-focal/testground.pkrvars.hcl) |

## Usage

### How to use an existing self-hosted runner type in your repository?

1. Add the full repository name where you intend to use the self-hosted runners to `repository_allowlist` of the runner type you're interested in in [runners.tf](runners.tf). Create a PR, wait for your changes to be applied and merged.
1. Ensure [pl-strflt/tf-aws-gh-runner](https://github.com/apps/pl-strflt-tf-aws-gh-runner) GitHub App is installed in your organization.
1. Request the self-hosted runner in your workflow through `job.runs-on` parameter. E.g. `runs-on: [self-hosted, linux, x64, linux-x64-default]`, `runs-on: [self-hosted, windows, x64, windows-x64-default]`.

**IMPORTANT**: Please read what the [security implications of using self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners/about-self-hosted-runners#self-hosted-runner-security) are. If you [enable self-hosted runners in public repositories](https://docs.github.com/en/actions/hosting-your-own-runners/managing-access-to-self-hosted-runners-using-groups), we suggest you also [restrict the workflows allowed to use self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners/managing-access-to-self-hosted-runners-using-groups) and think carefully about implications of executing untrusted code. It might also be a good idea to [require approval for all outside collaborators](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository#configuring-required-approval-for-workflows-from-public-forks).

### How to add a new runner type?

To add a new runner type, add a new runner type definiton object to the `for_each` object in [runners.tf](runners.tf).

The name (key in `for_each` object) of the new runner type has to be unique (disallowed names include: `linux`, `windows`, `x64`, `arm64`, etc.). The runner type definition object supports the following subset of [runners module inputs](https://github.com/philips-labs/terraform-aws-github-runner#inputs):
- `runner_os`
- `runner_architecture`
- `instance_types`
- `repository_white_list`
- `ami_filter`
- `ami_owners`
- `enabled_userdata`
- `runner_run_as`
- `runners_maximum_count`
- `block_device_mappings`

## Routing Layer

In the original design, webhook calls are received by an API Gateway which routes the traffic to the associated webhook lambda. Each runner type has its' own API Gateway and webhook lambda.

GitHub Apps allow specifying at most 1 webhook endpoint. Thus, with the original setup, we'd need as many GitHub Apps as runner types.

Here, we propose to replace all the aforementioned API Gateways with a single API Gateway followed by an Application ELB. In this setup, the public Internet facing API Gateway receives webhook calls, retrieves `workflow_job.labels` from the body of the request, puts it in the `X-GitHub-Workflow_Job-Labels` header and forwards the modified request to the ALB. The ALB looks for a webhook lamda configured to handle events matching the labels from `X-GitHub-Workflow_Job-Labels`. If it finds one, it forwards the request to that lambda. Otherwise, it responds with a 404.

**IMPORTANT**: This setup requires all runner types to have unique `extra_labels` and have `runner_enable_workflow_job_labels_check` set to `true`.
