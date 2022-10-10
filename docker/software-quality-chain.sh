#!/bin/bash

echo "Removing old output"
rm -f ../output/detekt.xml
rm -f ../output/result.json

echo "Increasing heap count for SonarQube"
sysctl -w vm.max_map_count=262144

echo "Starting SonarQube, mobsfscan"
DOCKER_BUILDKIT=1 docker-compose -f docker-compose.sq.yml up -d

echo "SonarQube is started, running mobsfscan"

echo "Waiting until scan is succesfully finished"
until [ -f ../app/src/result.json ]
do
     sleep 5
done

mv ../app/src/result.json ../output/result.json

echo "finished mobsfscan"

echo "running gradle detekt"
cd ..
sed -i 's/baseline = file("..\/detekt\/baseline.xml")/\/\/baseline = file("..\/detekt\/baseline.xml")/g' app/build.gradle
./gradlew detekt
sed -i 's/\/\/baseline = file("..\/detekt\/baseline.xml")/baseline = file("..\/detekt\/baseline.xml")/g' app/build.gradle
cd docker
cp ../app/build/reports/detekt.xml ../output/detekt.xml
echo "finished gradle detekt"

echo "preparing files to import into SonarQube"
sed -i 's/\/src\/main\//app\/src\/main\//g' ../output/result.json
sed -i 's/"filePath": null/"filePath": "app\/src\/main\/AndroidManifest.xml"/g' ../output/result.json

echo "Restoring SonarQube database with default user"
docker exec -i docker-sonarqube_db-1 //bin//bash -c "PGPASSWORD=sonar psql --username sonar sonar" < dump.sql

echo "Starting SonarScanner"
DOCKER_BUILDKIT=1  docker-compose -f docker-compose.scan.yml up -d

echo "SonarScanner started, will scan code now and upload data"
docker logs -f docker-sonarscanner-1
