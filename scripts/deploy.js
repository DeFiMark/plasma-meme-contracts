/* eslint-disable */
const {ethers} = require('hardhat');

async function verify(address, args, contractPath) {
  try {
    // verify the token contract code
    await hre.run('verify:verify', {
      address: address,
      constructorArguments: args,
      contract: contractPath
    });
  } catch (e) {
    console.log('error verifying contract', e);
  }
  await sleep(1000);
}

function getNonce() {
  return baseNonce + nonceOffset++;
}

async function deployContract(name = 'Contract', path, args) {
  const Contract = await ethers.getContractFactory(path);

  const Deployed = await Contract.deploy(...args, {nonce: getNonce()});
  console.log(name, ': ', Deployed.address);
  await sleep(5000);

  return Deployed;
}

async function fetchContract(path, address) {
  // Fetch Deployed Factory
  const Contract = await ethers.getContractAt(path, address);
  console.log('Fetched ', path, ': ', Contract.address, '  Verify Against: ', address, '\n');
  await sleep(100)
  return Contract;
}

async function sleep(ms) {
  return new Promise(resolve => {
    setTimeout(() => {
      return resolve();
    }, ms);
  });
}

async function main() {
    console.log('Starting Deploy');

    // addresses
    [owner] = await ethers.getSigners();

    // fetch data on deployer
    console.log('Deploying contracts with the account:', owner.address);
    console.log('Account balance:', (await owner.getBalance()).toString());

    // manage nonce
    baseNonce = await ethers.provider.getTransactionCount(owner.address);
    nonceOffset = 0;
    console.log('Account nonce: ', baseNonce);

    // VARIABLES TO MANUALLY SET BEFORE REDEPLOYING ON EACH CHAIN:
    // Database.launchFee
    // BondingCurve.A and BondingCurve.B
    // LiquidityAdder -- DEX INFO
    // update hardhat config
    
    const INFFeeReceiver = await deployContract('INFFeeReceiver', 'contracts/INFFeeReceiver.sol:INFFeeReceiver', []);
    await sleep(10_000);

    const LunarDatabase = await deployContract('LunarDatabase', 'contracts/LunarDatabase.sol:LunarDatabase', []);
    await sleep(10_000);

    const LunarVolumeTracker = await deployContract('VolumeTracker', 'contracts/LunarVolumeTracker.sol:LunarVolumeTracker', [LunarDatabase.address])
    await sleep(5_000);
    
    const LiquidityAdder = await deployContract('LiquidityAdder', 'contracts/LiquidityAdder.sol:LiquidityAdder', [LunarDatabase.address]);
    await sleep(5_000);

    const LunarGenerator = await deployContract('LunarGenerator', 'contracts/LunarGenerator.sol:LunarGenerator', [LunarDatabase.address]);
    await sleep(5_000);

    const LunarPumpToken = await deployContract('LunarPumpToken', 'contracts/LunarPumpToken.sol:LunarPumpToken', []);
    await sleep(5_000);

    const BondingCurve = await deployContract('BondingCurve', 'contracts/BondingCurve.sol:BondingCurve', []);
    await sleep(10_000);

    const FeeReceiver = await deployContract('FeeReceiver', 'contracts/FeeReceiver.sol:FeeReceiver', [INFFeeReceiver.address, LunarDatabase.address]);
    await sleep(10_000);

    const SupplyFetcher = await deployContract('SupplyFetcher', 'contracts/SupplyFetcher.sol:SupplyFetcher', []);
    await sleep(20_000);

    // const INFFeeReceiver = await fetchContract('contracts/INFFeeReceiver.sol:INFFeeReceiver', '0x7a190a6E591589A59fD3dF92C14cc5c6b0903AAC');
    // await sleep(5_000);

    // const LunarDatabase = await fetchContract('contracts/LunarDatabase.sol:LunarDatabase', '0x0c073F76B8e4a8FF8D338258e22De4Af8E0c194F');
    // await sleep(5_000);

    // const LunarVolumeTracker = await fetchContract('contracts/LunarVolumeTracker.sol:LunarVolumeTracker', '0xA7D6835D93CFAeC8337081966D98b5870Da0627D')
    // await sleep(5_000);
    
    // const LiquidityAdder = await fetchContract('contracts/LiquidityAdder.sol:LiquidityAdder', '0x8aC6cB102C3A1cc3F88E5dFf4eCb9D461519cC13');
    // await sleep(5_000);

    // const LunarGenerator = await fetchContract('contracts/LunarGenerator.sol:LunarGenerator', '0xE41A5f1bf3691b30262b2F2320df753D61847101');
    // await sleep(5_000);

    // const LunarPumpToken = await fetchContract('contracts/LunarPumpToken.sol:LunarPumpToken', '0x783a964cd3dDd91300B22620858c37480E9e5E02');
    // await sleep(5_000);

    // const BondingCurve = await fetchContract('contracts/BondingCurve.sol:BondingCurve', '0xe42F2Db6d3A871Eb57E119B601c4C047086fc971');
    // await sleep(5_000);

    // const FeeReceiver = await fetchContract('contracts/FeeReceiver.sol:FeeReceiver', '0x65Cbe0ac52F146F23dDC616f8f980dcF01a57D8F');
    // await sleep(5_000);

    // const SupplyFetcher = await fetchContract('contracts/SupplyFetcher.sol:SupplyFetcher', '0xfb3a80bb388aabdBeeAB21420FbD558405396822');
    // await sleep(5_000);

    await verify(SupplyFetcher.address, [], 'contracts/SupplyFetcher.sol:SupplyFetcher');
    await verify(FeeReceiver.address, [INFFeeReceiver.address, LunarDatabase.address], 'contracts/FeeReceiver.sol:FeeReceiver');
    await verify(LunarDatabase.address, [], 'contracts/LunarDatabase.sol:LunarDatabase');
    await verify(LiquidityAdder.address, [LunarDatabase.address], 'contracts/LiquidityAdder.sol:LiquidityAdder')
    await verify(LunarGenerator.address, [LunarDatabase.address], 'contracts/LunarGenerator.sol:LunarGenerator')
    await verify(LunarPumpToken.address, [], 'contracts/LunarPumpToken.sol:LunarPumpToken')
    await verify(LunarVolumeTracker.address, [LunarDatabase.address], 'contracts/LunarVolumeTracker.sol:LunarVolumeTracker')
    await verify(BondingCurve.address, [], 'contracts/BondingCurve.sol:BondingCurve')
    await verify(INFFeeReceiver.address, [], 'contracts/INFFeeReceiver.sol:INFFeeReceiver');

    // set master copies
    await LunarDatabase.setLunarPumpBondingCurveMasterCopy(BondingCurve.address, { nonce: getNonce() });
    await sleep(5000);
    console.log('Set Bonding Curve Master Copy');

    await LunarDatabase.setLunarPumpTokenMasterCopy(LunarPumpToken.address, { nonce: getNonce() });
    await sleep(5000);
    console.log('Set LunarPumpToken Master Copy');

    // set generator
    await LunarDatabase.setLunarPumpGenerator(LunarGenerator.address, { nonce: getNonce() });
    await sleep(5000);
    console.log('Set LunarGenerator');

    // set LiquidityAdder
    await LunarDatabase.setLiquidityAdder(LiquidityAdder.address, { nonce: getNonce() });
    await sleep(5000);
    console.log('Set LiquidityAdder');

    // set setLunarVolumeTracker
    await LunarDatabase.setLunarVolumeTracker(LunarVolumeTracker.address, { nonce: getNonce() });
    await sleep(5000);
    console.log('Set LunarVolumeTracker');

    await LunarDatabase.setFeeRecipient(FeeReceiver.address, { nonce: getNonce() });
    await sleep(5000);
    console.log('Set Fee receiver');
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
