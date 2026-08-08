# Terraform Workflow

How to perform Terraform operations alongside containerized Node.js development.

## Architecture

```
Mac (trusted)                    Container (untrusted code)
├── terraform CLI                ├── Node.js / npm
├── gcloud CLI                   ├── terraform-ls (syntax only)
├── GCP credentials              ├── Source code (bind mount)
└── Terraform state              └── NO cloud credentials
```

Terraform runs on the Mac. The container only has the language server for editing `.tf` files.

## Editing .tf Files

When working in VS Code with the container open:
- The HashiCorp Terraform extension runs inside the container
- `terraform-ls` provides syntax highlighting, formatting, and basic validation
- You do NOT need the `terraform` binary for editing support
- Full provider-aware validation requires running `terraform validate` from Mac

## Running Terraform Commands

Always from a **Mac terminal** (not the container terminal):

```bash
cd ~/projects/my-monorepo/infrastructure

# Initialize (downloads providers)
terraform init

# Plan changes
terraform plan

# Apply changes
terraform apply

# Validate configuration
terraform validate
```

## Typical Workflow

1. Edit `.tf` files in VS Code (container provides syntax support)
2. Switch to Mac terminal for terraform operations
3. Run `terraform plan` to see what would change
4. Run `terraform apply` if the plan looks good
5. Commit the changes: `git add infrastructure/ && git commit` (either terminal)
6. Push: `git push` (Mac terminal)

## Why Terraform Stays on Mac

- Terraform providers execute arbitrary code (like npm packages)
- The risk is lower (smaller ecosystem, signed binaries) but non-zero
- Terraform needs GCP credentials that must NOT enter the container
- Keeping Terraform on Mac is an accepted trade-off for now

## GCP Authentication

Terraform uses your GCP credentials on the Mac:

```bash
# Authenticate (one-time)
gcloud auth application-default login

# Verify
gcloud auth list
```

These credentials are never passed to the container.

## Troubleshooting

### "terraform: command not found" in container

Expected. Terraform doesn't run in the container. Use the Mac terminal.

### Language server shows errors about missing providers

`terraform-ls` can't download providers without the terraform binary. This is cosmetic — it won't affect syntax highlighting or formatting. For full validation, run `terraform validate` from Mac.

### Terraform state conflicts

If Terraform state is stored remotely (GCS bucket, Terraform Cloud), no conflict is possible — you're the only one running terraform locally. If state is local, it lives in the bind-mounted project directory and is accessible from both Mac and container (but only terraform on Mac can use it).
