const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("BaseSonicTokenModule", (m) => {
  const sonicToken = m.contract("BaseSonicToken");

  return { sonicToken };
});
