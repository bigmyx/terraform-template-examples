[
  {
    "name": "${role}-${zone}",
    "image": "${docker_repo}/${role}:${version}",
    "cpu": 0,
    "memoryReservation": 128,
    "essential": true,
    "command": [
        "python",
        "/arango_init.py",
        "-consul", "${consul}",
        "-role", "${role}",
        "-zone", "${zone}",
        "-graphite", "${graphite}"
    ],
    "portMappings": [
      {
        "containerPort": ${port},
        "hostPort": ${port}
      }
    ],
    "environment" : [
      { "name" : "ARANGO_NO_AUTH", "value" : "true" }
    ],
    "dockerLabels": {
        "zone": "${zone}",
        "environment": "${env}",
        "name": "${role}",
        "description": "arango-${role}"
    },
    "mountPoints": [
        {
          "sourceVolume": "data",
          "containerPath": "/data",
          "readOnly": false
        }
    ]
  }
]
