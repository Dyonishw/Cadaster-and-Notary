// Allows us to use ES6 in our migrations and tests.
require('babel-register');
require('babel-polyfill');

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "*",
      gas: 6712388,
      gasPrice: 65000000000
    },
	
	coverage: {
      host: "localhost",
      network_id: "*",
      port: 8545,
      gas: 0xfffffffffff,
      gasPrice: 0x01
    }
  },
  
    mocha: {
      useColors: true
    },

    solc: {
  optimizer: {
    enabled: false,
    runs: 200
  }
}


};
