const { createHmac } =require("crypto");
const { spawn } = require('node:child_process');


const bat = spawn('node', ['body.js']);

bat.stdout.on('data', (data) => {
  process.stdout.write(`${telemetryHmac(data.toString())} ${data.toString()}`);
});

const telemetryHmac = (body) => {

    const key = "hello world";
    // find the key from fs or env-var // cf Daniel to hide it

    const hmac = createHmac("sha1", key);
    hmac.update(body, "utf8");
    return hmac.digest("hex"); // length always 40
};
