<div align="center">

![runner-banner](https://github.com/pl-strflt/tf-aws-gh-runner/assets/6688074/ef8ede5b-a2fe-45c1-8564-66eeb8ba0fdb)

# Customizable Self-hosted GitHub Runners

Leveraging the power of [terraform-aws-github-runner](https://github.com/philips-labs/terraform-aws-github-runner), this project introduces an innovative way to manage self-hosted GitHub runners. It features a dynamic routing layer, enabling configuration for up to 100 different types of runners within a single GitHub App.

</div>

## Table of Runner Types

We provide a variety of self-hosted runner configurations. Choose the one that best suits your project's needs (each runner is labelled with `size`, `OS` and `architecture`):

| Size | OS | Architecture | Instance Type | AMI |
| --- | --- | --- | --- | --- |
| 4xlarge | linux | x64 | [c5.4xlarge](https://instances.vantage.sh/?selected=c5.4xlarge) | `github-runner-ubuntu-jammy-amd64-202307110949-default` built with [default.pkrvars](images/ubuntu-jammy/default.pkrvars.hcl) |
| 2xlarge | linux | x64 | [c5.2xlarge](https://instances.vantage.sh/?selected=c5.2xlarge) | `github-runner-ubuntu-jammy-amd64-202307110949-default` built with [default.pkrvars](images/ubuntu-jammy/default.pkrvars.hcl) |
| xlarge | linux | x64 | [c5.xlarge](https://instances.vantage.sh/?selected=c5.xlarge) or [m5.xlarge](https://instances.vantage.sh/?selected=m5.xlarge) | `github-runner-ubuntu-jammy-amd64-202307110949-default` built with [default.pkrvars](images/ubuntu-jammy/default.pkrvars.hcl) |
| large | linux | x64 | [c5.large](https://instances.vantage.sh/?selected=c5.large) or [m5.large](https://instances.vantage.sh/?selected=m5.large) | `github-runner-ubuntu-jammy-amd64-202307110949-default` built with [default.pkrvars](images/ubuntu-jammy/default.pkrvars.hcl) |
| 2xlarge | windows | x64 | [c5.2xlarge](https://instances.vantage.sh/?selected=c5.2xlarge) | `github-runner-windows-core-2022-202310200742-default` built with [default.pkrvars](images/windows-server-2022/default.pkrvars.hcl) |
| xlarge | windows | x64 | [c5.xlarge](https://instances.vantage.sh/?selected=c5.xlarge) or [m5.xlarge](https://instances.vantage.sh/?selected=m5.xlarge) | `github-runner-windows-core-2022-202310200742-default` built with [default.pkrvars](images/windows-server-2022/default.pkrvars.hcl) |

## Getting Started

### Utilizing an Existing Self-hosted Runner Type

Follow these simple steps to integrate our runners into your repository:

1. Insert the full repository name where you plan to utilize the self-hosted runners into the `repository_allowlist` of the desired runner type within the [runners.tf](runners.tf) file. Proceed with creating a PR and await for your changes to be merged and applied.
    <details>
      <summary>Environmental variables required for apply (available via IPDX 1Password Vault)</summary>

      ```
      export AWS_ACCESS_KEY_ID
      export AWS_SECRET_ACCESS_KEY
      export AWS_REGION
      export TF_VAR_github_app_id
      export TF_VAR_email # An email address to which alerts are sent
      export TF_VAR_github_webhook_secret
      export TF_VAR_github_app_key_base64
      ```
    </details>
2. Make sure to have the [pl-strflt/tf-aws-gh-runner](https://github.com/apps/pl-strflt-tf-aws-gh-runner) GitHub App installed within your organization.
3. Make sure the repository has access to the [`Default` runner group](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/using-self-hosted-runners-in-a-workflow#about-self-hosted-runner-groups) in your organization.
4. Specify the self-hosted runner in your workflow by setting the `job.runs-on` parameter. For instance, `runs-on: [self-hosted, linux, x64, linux-x64-default]`, `runs-on: [self-hosted, windows, x64, windows-x64-default]`.

#### Concerned about Security?

If you're wondering about the security implications of using self-hosted runners in public repositories, consider these pointers:

- We suggest familiarizing yourself with GitHub's official guidelines on [security implications of using self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners/about-self-hosted-runners#self-hosted-runner-security).
- To combat the risk of retaining unwanted or dangerous data, our project only supports ephemeral runners, which are discarded after running a single workflow.
- For an extra layer of protection against untrusted code execution, you might consider these strategies:
  - [Require approval for workflow execution from all outside collaborators](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository#controlling-changes-from-forks-to-workflows-in-public-repositories), providing you with an opportunity to review the code before execution.
  - [Restrict workflows that can use self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners/managing-access-to-self-hosted-runners-using-groups#changing-the-access-policy-of-a-self-hosted-runner-group). This will prevent the use of self-hosted runners for workflows triggered on [pull_request](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#pull_request) as it requires providing the exact git ref.

### Adding a New Runner Type

To expand our catalog with a new runner type, simply add a new runner type definition object to the `for_each` object in [runners.tf](runners.tf). Note that the name (key in `for_each` object) must be unique. Certain names are disallowed (e.g., `linux`, `windows`, `x64`, `arm64`, etc.). Please refer to the following subset of [runners module inputs](https://github.com/philips-labs/terraform-aws-github-runner#inputs) for the supported object inputs.

## Routing Layer Explanation

In the initial design, webhook calls were managed by an API Gateway which directed the traffic to the corresponding webhook lambda. Each runner type had a unique API Gateway and webhook lambda.

However, GitHub Apps permit only one webhook endpoint, which with the original setup meant we'd need as many GitHub Apps as runner types.

Our solution to this issue is to replace the multiple API Gateways with a single API Gateway and an Application ELB. This new setup ensures that the public-facing API Gateway receives webhook calls, retrieves `workflow_job.labels` from the request body, adds it into the `X-GitHub-Workflow_Job-Labels` header, and forwards the modified request to the ALB. The ALB scans for a webhook lambda capable of handling events that match the labels from `X-GitHub-Workflow_Job-Labels`. If it finds one, it forwards the request to that lambda. If it doesn't, it responds with a 404.

**IMPORTANT**: This revised setup requires all runner types to possess unique `extra_labels` and to have `runner_enable_workflow_job_labels_check` set to `true`.
