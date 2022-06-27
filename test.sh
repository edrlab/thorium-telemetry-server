#!/bin/bash


URL="http://localhost:8080"


CMD="curl -s $URL"
echo $CMD
eval $CMD >test-1.txt

echo "RESULT: "
cat test-1.txt
echo "###"

if [[ `cat test-1.txt` == "ERROR: No Authorization header" ]]
then
  echo "TEST1 PASS"
else
  echo "TEST$NUM FAIL"
  exit 1
fi


NUM=2
CMD="curl -s -H \"Authorization: EDRLAB \" $URL"
echo $CMD
eval $CMD >test-$NUM.txt

echo "RESULT: "
cat test-$NUM.txt
echo "###"

if [[ `cat test-$NUM.txt` == "ERROR: not a valid authorization key" ]]
then
  echo "TEST$NUM PASS"
else
  echo "TEST$NUM FAIL"
  exit 1
fi


NUM=3
CMD="curl -s -H \"Authorization: EDRLAB rocks\" $URL"
echo $CMD
eval $CMD >test-$NUM.txt

echo "RESULT: "
cat test-$NUM.txt
echo "###"

if [[ `cat test-$NUM.txt` == "ERROR: No body available" ]]
then
  echo "TEST$NUM PASS"
else
  echo "TEST$NUM FAIL"
  exit 1
fi


NUM=3
CMD="curl -s -H \"Authorization: EDRLAB rocks\" $URL"
echo $CMD
eval $CMD >test-$NUM.txt

echo "RESULT: "
cat test-$NUM.txt
echo "###"

if [[ `cat test-$NUM.txt` == "ERROR: No body available" ]]
then
  echo "TEST$NUM PASS"
else
  echo "TEST$NUM FAIL"
  exit 1
fi


# good test
res=`node hmac.js`
hmac=`echo $res | cut -d ' ' -f1`
data=`echo $res | cut -d ' ' -f2-`
CMD="curl -H \"Authorization: EDRLAB $hmac\" -d '$data' -s -w \"%{http_code}\n\" http://localhost:8080"
NUM=4
echo $CMD
eval $CMD >test-$NUM.txt

echo "RESULT: "
cat test-$NUM.txt
echo "###"

if [[ `cat test-$NUM.txt` == "200" ]]
then
  echo "TEST$NUM PASS"
else
  echo "TEST$NUM FAIL"
  exit 1
fi


res=`node hmac.js body_bad_timstamp.js`
hmac=`echo $res | cut -d ' ' -f1`
data=`echo $res | cut -d ' ' -f2-`
CMD="curl -H \"Authorization: EDRLAB $hmac\" -d '$data' -s -w \"%{http_code}\n\" http://localhost:8080"
NUM=5
echo $CMD
eval $CMD >test-$NUM.txt

echo "RESULT: "
cat test-$NUM.txt
echo "###"

if [[ `cat test-$NUM.txt` == `echo -e "ERROR: timestamp timeout\n400"` ]]
then
  echo "TEST$NUM PASS"
else
  echo "TEST$NUM FAIL"
  exit 1
fi


res=`node hmac.js body_bad_data_array.js`
hmac=`echo $res | cut -d ' ' -f1`
data=`echo $res | cut -d ' ' -f2-`
CMD="curl -H \"Authorization: EDRLAB $hmac\" -d '$data' -s -w \"%{http_code}\n\" http://localhost:8080"
NUM=6
echo $CMD
eval $CMD >test-$NUM.txt
echo "RESULT: "
cat test-$NUM.txt
echo "###"

if [[ `cat test-$NUM.txt` == `echo -e "ERROR: no data array in body\n400"` ]]
then
  echo "TEST$NUM PASS"
else
  echo "TEST$NUM FAIL"
  exit 1
fi


res=`node hmac.js body_bad_info.js`
hmac=`echo $res | cut -d ' ' -f1`
data=`echo $res | cut -d ' ' -f2-`
CMD="curl -H \"Authorization: EDRLAB $hmac\" -d '$data' -s -w \"%{http_code}\n\" http://localhost:8080"
NUM=7
echo $CMD
eval $CMD >test-$NUM.txt
echo "RESULT: "
cat test-$NUM.txt
echo "###"

if [[ `cat test-$NUM.txt` == `echo -e "ERROR: body dataValue 1\n400"` ]]
then
  echo "TEST$NUM PASS"
else
  echo "TEST$NUM FAIL"
  exit 1
fi


echo "########################"
echo "########################"
echo "ALL TESTS PASS"

echo "########################"
echo "########################"
