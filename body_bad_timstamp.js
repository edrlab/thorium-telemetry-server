
const info = {
	os_version: 'my os version',
	locale: 'fr',
	timestamp: new Date().toISOString(),
	fresh: true,
	type: "poll", // poll or error emun
	current_version: '1.2.3',
	prev_version: '0.1.2',
};

const data = {timestamp: "2022-06-20T09:54:15.443Z", data: [info, info, info]};

process.stdout.write(JSON.stringify(data));

