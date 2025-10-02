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

    const TokenAddress = "0x759a736ec07eA1A4aF66852dBcCF9aD0E61570Dc";

    // const Staking = await deployContract('Staking', 'contracts/PlasmaStaking.sol:PlasmaStaking', [TokenAddress]);
    // await sleep(5_000);

    const FeeReceiver = await fetchContract('contracts/FeeReceiver.sol:FeeReceiver', '0xe60A988e1D606303B628909029dF0D114999bA91');
    await sleep(5_000);

    await FeeReceiver.setStakingRecipient("0xdB0552d5D4bC959b23a4476227147296Df8128de", { nonce: getNonce() });
    await sleep(5_000);
    console.log('Set Staking Recipient');

    // const Staking = await fetchContract('contracts/PlasmaStaking.sol:PlasmaStaking', '0xdB0552d5D4bC959b23a4476227147296Df8128de');
    // await sleep(5_000);

    // await verify(Staking.address, [TokenAddress], 'contracts/PlasmaStaking.sol:PlasmaStaking');
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
