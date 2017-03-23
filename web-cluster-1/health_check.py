import sys
import time
import boto3
import botocore
from termcolor import colored

elb = boto3.client('elbv2')
ecs = boto3.client('ecs')

cluster, service, target_group = sys.argv[1:4]

def _out(group_name, data):
    print colored(data['Target']['Id'], 'cyan', attrs=['bold']),
    print colored(data['Target']['Port'], 'white', attrs=['bold']),
    print colored(group_name, 'white', attrs=['bold']),
    print colored(data['TargetHealth']['State'], 'green', attrs=['bold'])

def _error(msg):
    sys.stderr.write(colored(msg, 'yellow'))

def main():
    while True:
        try:
            task_arns = ecs.list_tasks(
                cluster=cluster,
                family=service
            )['taskArns']
            containers = ecs.describe_tasks(
                cluster=cluster,
                tasks=task_arns)['tasks'][0]['containers']
            for c in containers:
                if c['name'] == service:
                    service_port = c['networkBindings'][0]['hostPort']
            group_name = elb.describe_target_groups(
                TargetGroupArns=[target_group])['TargetGroups'][0]['TargetGroupName']

            health = elb.describe_target_health(
                TargetGroupArn=target_group
            )
        except (botocore.exceptions.ClientError, KeyError) as e:
            _error(e.message)
            time. sleep(20)
            continue

        for h in health['TargetHealthDescriptions']:
            if h['Target']['Port'] == service_port and h['TargetHealth']['State'] == 'healthy':
                _out(group_name, h)
                return 0
            else:
                _error("instance unhealthy")
                time.sleep(10)

if __name__ == "__main__":
    exit(main())
