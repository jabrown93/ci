const assert = require('node:assert/strict');
const test = require('node:test');

const answer = require('./index');

test('answer', () => {
  assert.equal(answer(), 42);
});
