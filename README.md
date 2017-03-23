
Disclaimer
---------

The code here was highly anonymized, please excuse the missing info and
do not expect this to work AS-IS.


Running Terraform
-----------------

 1. Install [Terraform](https://www.terraform.io/intro/getting-started/install.html). The Current template supports `v0.8.4`
 2. In the current directory execute `terraform plan` command. This command should out put the infrastructure deployment plan. If you want it in a graphical form, execute `terraform graph | dot -Tpng > graph.png` - this will generate diagram PNG file. (You should install `graphviz` app to have `dot` command)
 3. Careful examine the plan and make sure Terraform will not destroy an existing resources!!!
 4. Once confident with the plan, run `terraform apply` command, this will actually apply the plan. Wait until the command is complete and examine its output.  Terraform will use your globally configured (`~/.aws/credentials` or ENV variables) by default.


Deploying to production
-----------------------

For the production deploy `terragrunt` command should be used instead of `terraform`.
**Terragrunt** is a thin wrapper for Terraform that supports locking and enforces best practices for Terraform state.
Terragrunt can use Amazon's DynamoDB as a distributed locking mechanism to ensure that two team members working on the same Terraform state files do not overwrite each other's changes.
To install Terragrunt you can download the binary from the [Github page](https://github.com/gruntwork-io/terragrunt/releases) , rename it to `terragrunt`, and add it to your PATH. OS X users can install it via Homebrew.

Terragrunt forwards almost all commands, arguments, and options directly to Terraform, however, before running Terraform, Terragrunt will ensure your remote state is configured according to the settings in the `terraform.tfvars` file. Moreover, for the `apply`, `refresh`, and `destroy` commands, Terragrunt will first try to acquire a lock using DynamoDB:
```
terragrunt apply
[terragrunt] 2016/05/30 16:55:28 Configuring remote state for the s3 backend
[terragrunt] 2016/05/30 16:55:28 Running command: terraform remote config -backend s3 -backend-config=key=terraform.tfstate -backend-config=region=us-east-1 -backend-config=encrypt=true -backend-config=bucket=my-bucket
Initialized blank state with remote state enabled!
[terragrunt] 2016/05/30 16:55:29 Attempting to acquire lock for state file my-app in DynamoDB
[terragrunt] 2016/05/30 16:55:30 Attempting to create lock item for state file my-app in DynamoDB table terragrunt_locks
[terragrunt] 2016/05/30 16:55:30 Lock acquired!
[terragrunt] 2016/05/30 16:55:30 Running command: terraform apply
terraform apply

aws_instance.example: Creating...
  ami:                      "" => "ami-0d729a60"
  instance_type:            "" => "t2.micro"

[...]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

[terragrunt] 2016/05/27 00:39:19 Attempting to release lock for state file my-app in DynamoDB
[terragrunt] 2016/05/27 00:39:19 Lock released!
```

For more information about Terragrunt, please refer to it's [Github page](https://github.com/gruntwork-io/terragrunt).


Specific Deployment Instructions
--------------------------------

- Monitoring

```
terragrunt plan
terragrunt apply
```

Troubleshooting
---------------

NOTE: If previous `terraform apply` command was interrupted for some reason, it is Ok to run the
   command again - Terraform should refresh the state file and apply the
changes incrementally.

1. Stuck on `aws_autoscaling_group.arango: Still creating... (30s elapsed)` - examine AWS auto-scale group events in the AWS console. You may get limits exceeded message, in this case address the issue and run `terraform apply` command again.

Project-specific troubleshooting procedures will be described in each Terraform project sub-directory's `README` file. 

