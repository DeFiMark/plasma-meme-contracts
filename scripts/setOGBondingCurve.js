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

    const HigherDatabase = await fetchContract('contracts/Database.sol:HigherDatabase', '0x04E137dfdA310805B2905F6dE6A12Aa185Eee457');
    await sleep(5_000);

    const OGBondingCurve = "0x2684aa05c0DB2A431aaf6F5C694b715C4183c577";

    await HigherDatabase.setHigherPumpBondingCurveMasterCopy(OGBondingCurve, { nonce: getNonce() });
    await sleep(5000);
    console.log('Set Bonding Curve Master Copy');
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
