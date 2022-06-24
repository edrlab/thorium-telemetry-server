
#################
# db local test #
#################

docker run --name mysql -e MYSQL_ROOT_PASSWORD=hello -d -p 3306:3306 mariadb

#docker stop mysql && docker rm mysql

# docker exec -it mysql mysql -h localhost -u root -p

# docker run -it --rm  mariadb mysql --host=host.docker.internal --port=3306 -u root --password=hello

####################
# db gcp mysql-dev #
####################

# connection from setup-db vm in default vpc
# mysql -u telemetry --password=telemetry-pass -h 172.21.16.3
