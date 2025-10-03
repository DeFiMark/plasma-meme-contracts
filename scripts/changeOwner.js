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

    const newOwner = "0x46016fd8BD1e32eF26bdfc6dDbBd9D854722430e";

    const HigherVolumeTracker = await fetchContract('contracts/HigherVolumeTracker.sol:HigherVolumeTracker', '0xe2E47Bc79d6BaDCD014B26bD1C25250DA10f4D8E');
    await sleep(1_000);
    await HigherVolumeTracker.changeOwner(newOwner, { nonce: getNonce() });
    await sleep(5_000);
    console.log('Set Owner HigherVolumeTracker');

    const FeeReceiver = await fetchContract('contracts/FeeReceiver.sol:FeeReceiver', '0xe60A988e1D606303B628909029dF0D114999bA91');
    await sleep(1_000);
    await FeeReceiver.changeOwner(newOwner, { nonce: getNonce() });
    await sleep(5_000);
    console.log('Set Owner FeeReceiver');

    const Database = await fetchContract('contracts/Database.sol:HigherDatabase', '0x6301d3534Fa0be6FA20E17869d52295A71b2f8C5');
    await sleep(1_000);
    await Database.changeOwner(newOwner, { nonce: getNonce() });
    await sleep(5_000);
    console.log('Set Owner Database');

    const LiquidityAdder = await fetchContract('contracts/LiquidityAdder.sol:LiquidityAdder', '0x86049151210dED398E4A4e50a32A43e4C95D2445');
    await sleep(1_000);
    await LiquidityAdder.changeOwner(newOwner, { nonce: getNonce() });
    await sleep(5_000);
    console.log('Set Owner LiquidityAdder');

}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
