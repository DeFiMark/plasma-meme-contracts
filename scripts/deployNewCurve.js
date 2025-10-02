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

    const Database = "0x6301d3534Fa0be6FA20E17869d52295A71b2f8C5";
    const Router = "0x0B7355eAb26Cbdc1fABc4C7BF1c039C731a523bE";
    const Factory = "0x0b4Ff3Cb5123A7Ddff1862fffe247066cE8B0a41";

    const HigherDatabase = await fetchContract('contracts/Database.sol:HigherDatabase', Database);
    await sleep(5_000);

    const HigherFactory = await fetchContract('contracts/Factory.sol:HigherFactory', Factory);
    await sleep(5_000);

    // get INIT_CODE_PAIR_HASH from factory
    const INIT_CODE_PAIR_HASH = await HigherFactory.INIT_CODE_PAIR_HASH();
    await sleep(5000);
    console.log('INIT_CODE_PAIR_HASH: ', INIT_CODE_PAIR_HASH);

    // Deploy Bonding Curve Master Copy (no constructor parameters)
    const BondingCurve = await deployContract('BondingCurve', 'contracts/BondingCurve.sol:BondingCurve', []);
    await sleep(5_000);

    // Deploy Liquidity Adder (requires database, router, factory, and INIT_CODE_PAIR_HASH)
    const LiquidityAdder = await deployContract('LiquidityAdder', 'contracts/LiquidityAdder.sol:LiquidityAdder', [Database, Router, Factory, INIT_CODE_PAIR_HASH]);
    await sleep(5_000);

    // Verify all deployed contracts
    await verify(LiquidityAdder.address, [Database, Router, Factory, INIT_CODE_PAIR_HASH], 'contracts/LiquidityAdder.sol:LiquidityAdder');
    await verify(BondingCurve.address, [], 'contracts/BondingCurve.sol:BondingCurve');

    // Set master copies and configure database
    await HigherDatabase.setHigherPumpBondingCurveMasterCopy(BondingCurve.address, { nonce: getNonce() });
    await sleep(5000);
    console.log('Set Bonding Curve Master Copy');

    // Set LiquidityAdder
    await HigherDatabase.setLiquidityAdder(LiquidityAdder.address, { nonce: getNonce() });
    await sleep(5000);
    console.log('Set LiquidityAdder');

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
