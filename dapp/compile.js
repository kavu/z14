const fs = require('fs');
const Web3 = require('web3');
const solc = require('solc');

const provider = new Web3.providers.HttpProvider("http://localhost:8545");
const client = new Web3(provider);

const primaryAddress = client.eth.accounts[0];
client.eth.defaultAccount = primaryAddress;
client.personal.unlockAccount(primaryAddress);

const source = fs.readFileSync('contracts/voted_admins.sol').toString();
const contract = solc.compile(source, 1).contracts[':VotedAdmins'];
const bytecode = '0x' + contract.bytecode;

const VotedAdmins = client.eth.contract(JSON.parse(contract.interface));
const tx = { from: primaryAddress, data: bytecode, gas: 4000000 };
const inChain = VotedAdmins.new(/* min days */ 3,
                                /* max days */ 14,
                                /* percent */ 50,
                                tx);

var result = VotedAdmins.at(inChain.address);

console.log(inChain.address);