Creating ArangoDB Cluster
==========


Pre-requisites
-------------

1. Install [Terraform](https://www.terraform.io/intro/getting-started/install.html). The Current template supports `v0.8.4`
2. Make sure you can use AWS CLI and have an admin AWS permissions.


Creating Cluster Resources
-------------

ArangoDB Architecture consists of three tiers: **Agency**,  **PrimaryDB** and **Coordinator**. Each of those should be created as a separate AWS ECS cluster.

> If you are making changes to an existing cluster, using `.tfstate`, make sure you run this command before
>
> ```
> $ terraform plan -var 'az=a' -refresh=true
> ```
> and check there there are no plans to destroy an existing production resources!

To create an Agency ESC cluster, run the following:

```
$ terraform apply -var 'az=a'
```

This is an actual command that creates AWS resources.

*** Wait at least 5 minutes after the Terraform is finished.

Once ArangoDB cluster is created, check it's health by running `check_cluster.sh` script. The script should repotr the healthy instances for each ELB (Agency, PrimaryDB and Coordinator)

At this point the cluster should be up and running.
You can access the ArangoDB Web UI now:
```
$ ssh -L 8531:localhost:8531 <coordinator_instance_ip>
$ open http://localhost:8531 # should open a browser (tested on OSX)
```

When examining the UI, make sure the Arango is set up as a Cluster, i.e. there is a "Cluster" and "Node" UI tabs available.
Make sure there are no warning or errors.


Adding DB Capacity
-------------

Adding capacity is made easy with Terraform.
To add DB capacity we just add more DB servers to the cluster (i.e. scaling horizontally)

To add capacity to an existing cluster, first checkout the latest `.tfstate` file(s) from the repo.  These will reflect the current infrastructure state.
Then change the number of the desired instances for `primarydb` in `variables.tf` , for example from `3` to `4` :
```
variable "num_instances" {
  type = "map"
  default = {
    agency = 3,
    primarydb = 4,
    coordinator = 1
  }
}
```

Then run the `apply` command again:

```
terraform apply -var 'az=a' -refresh=true
```

The relevant snippet of the command's out should be like following:
```
aws_ecs_service.arango: Modifying...
  desired_count: "3" => "4"
aws_autoscaling_group.ecs_cluster: Modifying...
  desired_capacity: "3" => "4"
  max_size:         "3" => "4"
  min_size:         "3" => "4"
aws_ecs_service.arango: Modifications complete
aws_autoscaling_group.ecs_cluster: Still modifying...
...
aws_autoscaling_group.ecs_cluster: Modifications complete
```

At this point you should have one more DB server joined the cluster.
You can verify the number of DB servers from the ArangoDB web UI.


Replication
-----------

In order to have a replication, we need to create two distinct ArangoDB clusters

Cluster A:

```
terraform apply -var 'az=a' -state=terraform.tfstate.a  -state-out=terraform.tfstate.a
```

Cluster B:

```
terraform apply -var 'az=b' -state=terraform.tfstate.b  -state-out=terraform.tfstate.b
```

Then start start the replication
TODO: coplete this


Troubleshooting
-------------

1. If you see it stuck at some point, for example:
 ```aws_autoscaling_group.arango: Still creating...```
Interrupt the process (`^C` two times), login to AWS console and examine the reason for the resource could not be created. One of the common reasons can be the AWS limits, like number of Volumes or Instances.
Once fixed, run the `apply` command again, it should start from the point it was interrupted.

2. Error: `aws_ecs_service.arango: ClusterNotFoundException: The referenced cluster was inactive`
In this case, running the same `apply` command again should fix the
issue.

3. DB Container fails with the following error `FATAL database is locked, please check the lock file '/data/LOCK'`
Assuming this is a new DB server, remove the contents of `/data` on the host. The next container should initialize the empty data directory structure again
