

docker stop resty && docker rm resty
docker build -f Dockerfile -t resty:latest .

docker image inspect resty:latest | head

docker run \
  --env SECRET_KEY="hello world" \
  --env DB_HOST="192.168.65.2" \
  --env DB_NAME="telemetry" \
  --env DB_USER="root" \
  --env DB_PASS="hello" \
  --name resty \
  --publish 8080:80 \
  resty:latest
