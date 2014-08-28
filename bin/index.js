#!/usr/bin/env node
try {
  require('coffee-script/register');
  // in production, this will fail if coffeescript isn't installed, but the
  // coffee is compiled anyway, so it doesn't matter
} catch(e){}

tidyMarkdown = require('../lib');

process.stdin.setEncoding('utf8');
process.stdin.on('readable', function() {
  var buffer = '';
  while (null !== (chunk = process.stdin.read())) {
    buffer += chunk
  }
  process.stdout.write(tidyMarkdown(buffer));
});
