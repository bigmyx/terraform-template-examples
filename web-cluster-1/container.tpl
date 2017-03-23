[
  {
    "name": "${service}-${version}",
    "image": "${docker_image}:${version}",
    "cpu": 0,
    "memoryReservation": 512,
    "essential": true,
    "portMappings": [
      {
        "containerPort": ${container_port},
        "hostPort": 0
      }
    ],
    "environment" : [
        {
          "name": "CONFIG_DB_NAME",
          "value": "${config_db_name}"
        },

    ],
    "dockerLabels": {
        "environment": "${env}",
        "name": "${service}",
        "version": "${version}"
    },
    "mountPoints": [
        {
          "sourceVolume": "logs",
          "containerPath": "/var/log/obs",
          "readOnly": false
        }
    ]
  }
]
