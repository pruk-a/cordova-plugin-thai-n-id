var exec = require('cordova/exec');

var Reader = function() {};

Reader.connectReader = function(success, error) {
	exec(success, error, 'ThaiNID', 'connectReader', []);
};

Reader.getCardData = function(success, error) {
	exec(success, error, 'ThaiNID', 'getCardData', []);
};

Reader.disconnectReader = function(success, error) {
	exec(success, error, 'ThaiNID', 'disconnectReader', []);
};

module.exports = Reader;
