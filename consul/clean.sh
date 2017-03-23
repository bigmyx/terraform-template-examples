for s in $(curl -s localhost:8500/v1/agent/services | jq '.[].ID' | tr -d [\"]); do
  echo "deregistering $s"
  curl -s localhost:8500/v1/agent/service/deregister/$s
done
