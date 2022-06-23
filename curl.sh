
#curl -v http://localhost:8080
#curl -H "Authorization: EDRLAB " -v http://localhost:8080
#curl -H "Authorization: EDRLAB rocks" -v http://localhost:8080

res=`node hmac.js`
hmac=`echo $res | cut -d ' ' -f1`
data=`echo $res | cut -d ' ' -f2-`
echo "curl -H \"Authorization: EDRLAB $hmac\" -d '$data' -v http://localhost:8080"
