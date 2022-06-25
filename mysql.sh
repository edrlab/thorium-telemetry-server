
#################
# db local test #
#################

docker stop mysql && docker rm mysql

docker run --name mysql -e MYSQL_ROOT_PASSWORD=hello -d -p 3306:3306 mariadb

# docker exec -it mysql mysql -h localhost -u root -p

# docker run -it --rm  mariadb mysql --host=host.docker.internal --port=3306 -u root --password=hello

####################
# db gcp mysql-dev #
####################

# connection from setup-db vm in default vpc
# mysql -u telemetry --password=telemetry-pass -h 172.21.16.3

#####################
# db gcp mysql-prod #
#####################

# connection from setup-db vm in default vpc
# mysql -u telemetry-prod -h 172.21.16.5
