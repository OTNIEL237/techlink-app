const https = require('https');
https.get('https://pin.it/6895eqBRC', (res) => {
  console.log('Location:', res.headers.location);
}).on('error', (e) => {
  console.error(e);
});
