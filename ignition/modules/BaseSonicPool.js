const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("BaseSonicPoolModule", (m) => {
  const sonic = m.contract("BaseSonicPool");

  return { sonic };
});
