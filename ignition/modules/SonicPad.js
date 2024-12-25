const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("SonicPadModule", (m) => {
  // const unlockTime = m.getParameter("unlockTime", JAN_1ST_2030);
  // const lockedAmount = m.getParameter("lockedAmount", ONE_GWEI);

  const sonic = m.contract("SonicPad");

  return { sonic };
});
