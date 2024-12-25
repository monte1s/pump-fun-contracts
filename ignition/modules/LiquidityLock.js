const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("LiquidityLockModule", (m) => {
  
  const LiquidityLock = m.contract("LiquidityLock");

  return { LiquidityLock };
});
