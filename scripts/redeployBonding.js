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

    // const Bacarrat = await deployContract('Bacarrat', 'contracts/Baccarat/Baccarat.sol:Baccarat', BaccaratArgs);
    // await sleep(10000);
    // await verify(Bacarrat.address, BaccaratArgs, 'contracts/Baccarat/Baccarat.sol:Baccarat');

    // const LunarDatabase = await deployContract('LunarDatabase', 'contracts/LunarDatabase.sol:LunarDatabase', []);
    const LunarDatabase = await fetchContract('contracts/LunarDatabase.sol:LunarDatabase', '0x5d828b744A26dF3f300cbe4Dd8B08b2AF684a1CE');
    await sleep(5_000);

    const BondingCurve = await deployContract('BondingCurve', 'contracts/BondingCurve.sol:BondingCurve', []);
    await sleep(10_000);

    await verify(BondingCurve.address, [], 'contracts/BondingCurve.sol:BondingCurve');

    // set master copies
    await LunarDatabase.setLunarPumpBondingCurveMasterCopy(BondingCurve.address, { nonce: getNonce() });
    await sleep(5000);
    console.log('Set Bonding Curve Master Copy');

}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
