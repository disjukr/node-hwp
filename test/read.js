var assert = require('assert');
var hwp = require('../');

var test = function(ok){
	hwp.open('./test/files/1.hwp', function(err, doc){
		assert.ifError(err);
		ok();
	});
};

module.exports = {
	'description': "Open an HWP file",
	'run': test
};
