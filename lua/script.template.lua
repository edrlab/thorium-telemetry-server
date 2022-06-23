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
function bind(sql, ... )
  local clean = {}
  local arg={...} 
  sql = string.gsub(sql, "?", "%%s", 20) 
  for i,v in ipairs(arg) do
    clean[i] = ngx.quote_sql_str(ngx.unescape_uri(v)) 
  end
  sql = string.format(sql, unpack(clean))
    return sql
end
--

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
	port = DB_PORT or 3306,
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

-- add a keys check
if not type(json["os_version"]) == "string" and
  not type(json["locale"]) == "string" and
  not type(json["fresh"]) == "boolean" and
  not (json["type"] == "poll" or json["type"] == "error") and
  not type(json["current_version"]) == "string" and
  not type(json["prev_version"]) == "string" then

  ngx.status = ngx.HTTP_BAD_REQUEST;
  ngx.say("ERROR: body json");
  return ngx.exit(ngx.OK);
end

print("connected to mysql");

local osVersion = json["os_version"];
local locale = json["locale"];
local osTs = tsDbFormated;
local freshInstall = json["fresh"] and '1' or '0'; -- boolean
local entryType = json["type"]; -- poll or error
local currentVersion = json["current_version"];
local previousVersion = json["prev_version"];
local newInstall = previousVersion == "null" and '1' or '0';

local query = bind("INSERT INTO logs (os_version, locale, os_ts, fresh_install, entry_type, current_version, prev_version, new_install) values (?, ?, ?, ?, ?, ?, ?, ?)", osVersion, locale, osTs, freshInstall, entryType, currentVersion, previousVersion, newInstall);
local res, err, errcode, sqlstate = db:query(query);
if not res then
	ngx.log(ngx.ERR, string.format("bad result: %s : %s : %s", err, errcode, sqlstate))
  ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR;
  return ngx.exit(ngx.OK);
end

print(string.format("mysql insert id: %s", res.insert_id));

