const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("EqualizerHandlerModule", (m) => {
  const sonicPad = m.getParameter(
    "_sonicPad",
    "0x1d624C56Cf0c108350e1BC1d62912ACF4d800fef"
  );
  
  const EqualizerHandler = m.contract("EqualizerHandler", [sonicPad]);

  return { EqualizerHandler };
});
