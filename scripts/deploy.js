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

    // Deploy Database first (no constructor parameters)
    // const HigherDatabase = await deployContract('HigherDatabase', 'contracts/Database.sol:HigherDatabase', []);
    // await sleep(10_000);

    const HigherDatabase = await fetchContract('contracts/Database.sol:HigherDatabase', '0x5ad45DCFC2049362eB62321265248e6D6053b5D9');
    await sleep(5_000);

    // Deploy Volume Tracker (requires database address)
    const HigherVolumeTracker = await deployContract('HigherVolumeTracker', 'contracts/HigherVolumeTracker.sol:HigherVolumeTracker', [HigherDatabase.address]);
    await sleep(5_000);
    
    // Deploy Factory (requires database address)
    const HigherFactory = await deployContract('HigherFactory', 'contracts/Factory.sol:HigherFactory', [HigherDatabase.address]);
    await sleep(10_000);

    // get INIT_CODE_PAIR_HASH from factory
    const INIT_CODE_PAIR_HASH = await HigherFactory.INIT_CODE_PAIR_HASH();
    await sleep(5000);
    console.log('INIT_CODE_PAIR_HASH: ', INIT_CODE_PAIR_HASH);

    // Deploy Router (requires factory and database addresses)
    const HigherRouter = await deployContract('HigherRouter', 'contracts/Router.sol:HigherRouter', [HigherFactory.address, HigherDatabase.address]);
    await sleep(5_000);

    // Deploy Higher Generator (requires database)
    const HigherGenerator = await deployContract('HigherGenerator', 'contracts/HigherGenerator.sol:HigherGenerator', [HigherDatabase.address]);
    await sleep(5_000);

    // Deploy Higher Token Master Copy (no constructor parameters)
    const HigherTokenImp = await deployContract('HigherTokenImp', 'contracts/HigherTokenImp.sol:HigherPumpToken', []);
    await sleep(5_000);

    // Deploy Bonding Curve Master Copy (no constructor parameters)
    const BondingCurve = await deployContract('BondingCurve', 'contracts/BondingCurve.sol:BondingCurve', []);
    await sleep(5_000);

    // Deploy Liquidity Adder (requires database, router, factory, and INIT_CODE_PAIR_HASH)
    const LiquidityAdder = await deployContract('LiquidityAdder', 'contracts/LiquidityAdder.sol:LiquidityAdder', [HigherDatabase.address, HigherRouter.address, HigherFactory.address, INIT_CODE_PAIR_HASH]);
    await sleep(5_000);

    // Deploy Fee Receiver (requires platform recipient, buy burn recipient, staking recipient, and database addresses)
    const FeeReceiver = await deployContract('FeeReceiver', 'contracts/FeeReceiver.sol:FeeReceiver', [owner.address, owner.address, owner.address, HigherDatabase.address]);
    await sleep(5_000);

    // Deploy Supply Fetcher (no constructor parameters)
    const SupplyFetcher = await deployContract('SupplyFetcher', 'contracts/SupplyFetcher.sol:SupplyFetcher', []);
    await sleep(5_000);

    // Verify all deployed contracts
    // await verify(HigherDatabase.address, [], 'contracts/Database.sol:HigherDatabase');
    await verify(SupplyFetcher.address, [], 'contracts/SupplyFetcher.sol:SupplyFetcher');
    await verify(FeeReceiver.address, [owner.address, owner.address, owner.address, HigherDatabase.address], 'contracts/FeeReceiver.sol:FeeReceiver');
    await verify(HigherDatabase.address, [], 'contracts/Database.sol:HigherDatabase');
    await verify(LiquidityAdder.address, [HigherDatabase.address, HigherRouter.address, HigherFactory.address, INIT_CODE_PAIR_HASH], 'contracts/LiquidityAdder.sol:LiquidityAdder');
    await verify(HigherGenerator.address, [HigherDatabase.address], 'contracts/HigherGenerator.sol:HigherGenerator');
    await verify(HigherTokenImp.address, [], 'contracts/HigherTokenImp.sol:HigherPumpToken');
    await verify(HigherVolumeTracker.address, [HigherDatabase.address], 'contracts/HigherVolumeTracker.sol:HigherVolumeTracker');
    await verify(BondingCurve.address, [], 'contracts/BondingCurve.sol:BondingCurve');
    await verify(HigherRouter.address, [HigherFactory.address, HigherDatabase.address], 'contracts/Router.sol:HigherRouter');
    await verify(HigherFactory.address, [HigherDatabase.address], 'contracts/Factory.sol:HigherFactory');

    // Set master copies and configure database
    await HigherDatabase.setHigherPumpBondingCurveMasterCopy(BondingCurve.address, { nonce: getNonce() });
    await sleep(5000);
    console.log('Set Bonding Curve Master Copy');

    await HigherDatabase.setHigherPumpTokenMasterCopy(HigherTokenImp.address, { nonce: getNonce() });
    await sleep(5000);
    console.log('Set HigherPumpToken Master Copy');

    // Set generator
    await HigherDatabase.setHigherPumpGenerator(HigherGenerator.address, { nonce: getNonce() });
    await sleep(5000);
    console.log('Set HigherGenerator');

    // Set LiquidityAdder
    await HigherDatabase.setLiquidityAdder(LiquidityAdder.address, { nonce: getNonce() });
    await sleep(5000);
    console.log('Set LiquidityAdder');

    // Set HigherVolumeTracker
    await HigherDatabase.setHigherVolumeTracker(HigherVolumeTracker.address, { nonce: getNonce() });
    await sleep(5000);
    console.log('Set HigherVolumeTracker');

    // Set fee recipient
    await HigherDatabase.setFeeRecipient(FeeReceiver.address, { nonce: getNonce() });
    await sleep(5000);
    console.log('Set Fee receiver');

    // Set router in database
    await HigherDatabase.setRouter(HigherRouter.address, { nonce: getNonce() });
    await sleep(5000);
    console.log('Set Router');

    // white list router and factory for canRegisterVolume in database
    await HigherDatabase.setCanRegisterVolume(HigherRouter.address, { nonce: getNonce() });
    await sleep(5000);
    console.log('White list Router for canRegisterVolume');

    await HigherDatabase.setCanRegisterVolume(HigherFactory.address, { nonce: getNonce() });
    await sleep(5000);
    console.log('White list Factory for canRegisterVolume');

    // set can create pair in factory for router
    await HigherFactory.setCanCreatePair(HigherRouter.address, { nonce: getNonce() });
    await sleep(5000);
    console.log('White list Router for canCreatePair');

    // set can create pair in factory for liquidity adder
    await HigherFactory.setCanCreatePair(LiquidityAdder.address, { nonce: getNonce() });
    await sleep(5000);
    console.log('White list Liquidity Adder for canCreatePair');
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
