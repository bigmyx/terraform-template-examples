Creating Consul Cluster
==========


Pre-requisites
-------------

1. Install [Terraform](https://www.terraform.io/intro/getting-started/install.html). The Current template supports `v0.8.4`
2. Make sure you have an admin AWS permissions.

Creating Cluster Resources
-------------

Consul cluster consists of 3 or 5 nodes. The number of the nodes should
be odd, hence the RAFT algorithm is used for a leader election.
This number can be set in `variables.tf` file (`num_instances`)
Default: 3

> If you are making changes to an existing cluster, using `.tfstate`, make sure you run this command before
> ```
> $ terraform plan
> ```
> and check there there are no plans to destroy an existing production resources!

To create new Consul cluster, run the following:

```
$ terraform apply
```

> This is an actual command that creates AWS resources.
> If you see it stuck at some point, for example:
> ```aws_autoscaling_group.consul_asg_tf: Still creating...```
> Interrupt the process (`^C` two times), login to AWS console and examine the reason for the resource could not be created. One of the common reasons can be the AWS limits, like number of Volumes or Instances.
> Once fixed, run the same command again, it should start from the point it was interrupted.

Once Consul cluster is created, check it's health by creating a tunnel:

```
ssh -L 8500:consul-tf.staging.example.net:8500 <ANY_CONSUL_NODE_IP>  -N
```

and opening the UI, by opening http://localhost:8500 in the browser.


Adding Nodes Capacity
-------------

Adding capacity is made easy with Terraform.
To add nodes capacity we just add more DB servers to the cluster (i.e. scaling horizontally)

To add capacity to an existing cluster, first checkout the latest `.tfstate` file(s) from the repo.  These will reflect the current infrastructure state.
Then change the number of the desired instances for `num_instances` in `variables.tf` , for example from `3` to `5` :

```
variable "num_instances" {
  default = 5
}
```

Then run the `apply` command again:

```
terraform apply
```

The relevant snippet of the command's out should be like following:

```
aws_autoscaling_group.ecs_cluster: Modifying...
  desired_capacity: "3" => "5"
  max_size:         "3" => "5"
  min_size:         "3" => "5"
aws_autoscaling_group.ecs_cluster: Modifications complete
```

At this point you should have 2 more Consul nodes joined the cluster.
You can verify the number of Consul nodes from the web UI.

