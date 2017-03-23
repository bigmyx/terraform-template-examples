[
  {
    "name": "${service}",
    "image": "hub.example.net:5000/${service}:${version}",
    "cpu": 0,
    "memoryReservation": 128,
    "essential": true,
    "environment" : [
      { "name" : "ENV", "value" : "${env}" },
      { "name" : "CONFIG_DB_NAME", "value" : "${config_db_name}" }
    ]
  }
]
