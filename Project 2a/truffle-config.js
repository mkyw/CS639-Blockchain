module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 9545,
      network_id: "*",
    },
  },
  compilers: {
    vyper: {
      version: "^0.3.0",
    },
  },
  contracts_directory: ".",
};
