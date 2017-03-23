#!/usr/bin/env python
import sys
import os
import json
import boto3

env = sys.argv[1]
bucket = 'cc-tf-cluster-deploy'
tf_config = 'web-cluster-1.tfvars'
cwd = os.path.dirname(os.path.realpath(__file__))
config = json.loads(open(os.path.join(cwd, 'versions.json')).read())
services = config[env]

def _get_defs():
    s3 = boto3.resource('s3')
    cdef_files = []
    for service, version in services.items():
        fname = '-'.join([service, version, env]) + '.json'
        obj = s3.Object(bucket, fname)
        container_defs = json.loads(obj.get()['Body'].read())['containerDefinitions']
        # Set hostPort to 0
        for c_def in container_defs:
            try:
                c_def['portMappings'][0]['hostPort'] = 0
            except KeyError:
                continue

            with open(os.path.join(cwd, fname), 'w') as f:
                json.dump(c_def, f, indent=4)
            cdef_files.append(fname)
        return cdef_files

def main():
    _get_defs()
    return 0

if __name__ == '__main__':
    sys.exit(main())
