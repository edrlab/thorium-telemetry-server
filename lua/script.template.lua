local hmac = require "resty.hmac"
local cjson = require "cjson"
local mysql = require "resty.mysql"

local SECRET_KEY = "${SECRET_KEY}";
local DB_HOST = "${DB_HOST}";
local DB_PORT = "${DB_PORT}";
local DB_NAME = "${DB_NAME}";
local DB_USER = "${DB_USER}";
local DB_PASS = "${DB_PASS}";

-- https://gist.github.com/punkael/107b9fbbce47a09e9d7e

function escapeSqlQuery(text)
  return ngx.quote_sql_str(ngx.unescape_uri(text));
end

local db, err = mysql:new()
if not db then
	ngx.log(ngx.ERR, string.format("failed to instantiate mysql: %s", err));
  ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR;
  return ngx.exit(ngx.OK);
end

local authorizationHeader = ngx.req.get_headers()["Authorization"];
print(string.format("Authorization: %s", authorizationHeader));

if authorizationHeader == nil or authorizationHeader == '' then
  ngx.status = ngx.HTTP_BAD_REQUEST;
  ngx.say("ERROR: No Authorization header");
  return ngx.exit(ngx.OK);
end

local authorizationKey = string.match(authorizationHeader, "EDRLAB (.*)")
-- print(string.format("Authorization key: %s", authorizationKey));

if authorizationKey == nil or authorizationKey == '' then
  ngx.status = ngx.HTTP_BAD_REQUEST;
  ngx.say("ERROR: not a valid authorization key");
  return ngx.exit(ngx.OK);
end

local hmacPrivateKey = SECRET_KEY or "hello world";
local hmacSha1 = hmac:new(hmacPrivateKey, hmac.ALGOS.SHA1);

if not hmacSha1 then
	ngx.log(ngx.ERR, "failed to create the hmacSha1 object");
  ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR;
  return ngx.exit(ngx.OK);
end

ngx.req.read_body();
local data = ngx.req.get_body_data(); -- return lua string instead table
print(string.format("data: '%s'", data));
if data == nil or data == '' then
  ngx.status = ngx.HTTP_BAD_REQUEST;
  ngx.say("ERROR: No body available");
  return ngx.exit(ngx.OK);
end

local hmacKey = hmacSha1:final(data, true);
if not hmacSha1:reset() then
	ngx.log(ngx.ERR, "failed to reset hmac");
end

if hmacKey ~= authorizationKey then
	ngx.log(ngx.ERR, string.format("hmac key (%s) doesn't match with authorization key (%s)", hmacKey, authorizationKey));
  ngx.status = ngx.HTTP_UNAUTHORIZED;
  ngx.say("ERROR: Bad authorization");
  return ngx.exit(ngx.OK);
end

print("Authorization OK");

-- check timestamp

local json = cjson.decode(data);
local ts = json["timestamp"];
if not ts then
	ngx.log(ngx.ERR, "timestamp not found in body");
  ngx.status = ngx.HTTP_BAD_REQUEST;
  return ngx.exit(ngx.OK);
end

print(string.format("timestamp %s", ts));

local y, m, d, h, M, s, n = ts:match("^(.*)-(.*)-(.*)T(.*):(.*):(.*)%.(.*)Z$");
local time = os.time{year=y, month=m, day=d, hour=h, min=M, sec=s};
local currentTime = os.time(os.date("!*t"));
print(string.format("currentTime (%s), time (%s)", currentTime, time));

-- https://mariadb.com/kb/en/timestamp/
local tsDbFormated = string.format("%d-%d-%d %d:%d:%d", y, m, d, h, M, s);
--

if currentTime - time > 60 * 60 then
  ngx.status = ngx.HTTP_BAD_REQUEST;
  ngx.say("ERROR: timestamp timeout");
  return ngx.exit(ngx.OK);
end

print("Timestamp OK");

-- mysql

local ok, err, errcode, sqlstate = db:connect{
	host = DB_HOST,--"192.168.65.2",
	port = tonumber(DB_PORT) or 3306,
	database = DB_NAME or "telemetry",
	user = DB_USER or "root",
	password = DB_PASS or "hello",
	charset = "utf8",
	max_packet_size = 1024 * 1024,
}

if not ok then
	ngx.log(ngx.ERR, string.format("failed to connect: %s, : %s, %s", err, errcode, sqlstate));
  ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR;
  return ngx.exit(ngx.OK);
end

local jsonData = json["data"];
print("JSON DATA TYPE", type(jsonData));
if type(jsonData) ~= "table" or type(jsonData[1]) ~= "table"  then
	-- ngx.log(ngx.ERR, string.format("ERROR: no data array in body"));
  ngx.status = ngx.HTTP_BAD_REQUEST;
  ngx.say("ERROR: no data array in body");
  return ngx.exit(ngx.OK);
end

local queryArgs = {};

for i,dataValue in ipairs(jsonData) do
  if not type(dataValue["os_version"]) == "string" or
    not type(dataValue["locale"]) == "string" or
    not type(dataValue["fresh"]) == "boolean" or
    not (dataValue["type"] == "poll" or dataValue["type"] == "error") or
    not type(dataValue["current_version"]) == "string" or
    not type(dataValue["prev_version"]) == "string"
  then

    ngx.status = ngx.HTTP_BAD_REQUEST;
    ngx.say("ERROR: body dataValue " .. i);
    return ngx.exit(ngx.OK);
  end

  local osVersion = dataValue["os_version"];
  local locale = dataValue["locale"];
  local osTs = tsDbFormated;
  local freshInstall = dataValue["fresh"] and '1' or '0'; -- boolean
  local entryType = dataValue["type"]; -- poll or error
  local currentVersion = dataValue["current_version"];
  local previousVersion = dataValue["prev_version"];
  local newInstall = previousVersion == "null" and '1' or '0';

  local str = string.format("(%s, %s, %s, %s, %s, %s, %s, %s)",
      escapeSqlQuery(osVersion),
      escapeSqlQuery(locale),
      escapeSqlQuery(osTs),
      escapeSqlQuery(freshInstall),
      escapeSqlQuery(entryType),
      escapeSqlQuery(currentVersion),
      escapeSqlQuery(previousVersion),
      escapeSqlQuery(newInstall)
    );
  table.insert(queryArgs, str);

end

local queryValueString = "";
for i,v in ipairs(queryArgs) do
  if queryValueString ~= '' then
    queryValueString = queryValueString .. ", ";
  end;
  queryValueString = queryValueString .. v;
end;

print("connected to mysql");

local query = "INSERT INTO logs (os_version, locale, os_ts, fresh_install, entry_type, current_version, prev_version, new_install) values ";
query = query .. queryValueString;
print("query: ", query);
local res, err, errcode, sqlstate = db:query(query);
if not res then
	ngx.log(ngx.ERR, string.format("bad result: %s : %s : %s", err, errcode, sqlstate));
  ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR;
  return ngx.exit(ngx.OK);
end

print(string.format("mysql insert id: %s", res.insert_id));

