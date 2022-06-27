
const info = {
	os_version: 'my os version',
	locale: 'fr',
	timestamp: new Date().toISOString(),
	fresh: 0,
	type: 0, // poll or error emun
	current_version: '1.2.3',
	prev_version: 0,
};

const data = {timestamp: new Date().toISOString(), data: [info, info, info]};

process.stdout.write(JSON.stringify(data));

