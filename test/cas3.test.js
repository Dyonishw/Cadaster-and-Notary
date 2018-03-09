import expectThrow from './helpers/expectThrow';

const CadasterDatabase = artifacts.require("./CadasterDatabase.sol");
const Notary = artifacts.require("./Notary.sol");

contract('CadasterDatabase', function (accounts) {
    var ownerAddress = accounts[0];
    var firstLandlord = accounts[1];
    var secondLandlord = accounts[2];
    var buyerAddress = accounts[3];
    var externalAddress = accounts[9];
    let CDB;

    beforeEach(async function () {
     CDB = await CadasterDatabase.new();
     });

         it('should test for disagreementForVoid to pass', async function () {

           await expectThrow(CDB.addProperty(firstLandlord, 123123, 456456, false, {from: externalAddress}));
           await CDB.addProperty(firstLandlord, 123123, 456456, false, {from: ownerAddress});

           await expectThrow(CDB.replaceAndAdd(firstLandlord, 123123, 456456, 789789, 0, {from: externalAddress}));
           await expectThrow(CDB.replaceAndAdd(externalAddress, 123123, 456456, 789789, 0, {from: ownerAddress}));
           await expectThrow(CDB.replaceAndAdd(firstLandlord, 1231231, 456456, 789789, 0, {from: ownerAddress}));
           await CDB.replaceAndAdd(firstLandlord, 123123, 456456, 789789, 0, {from: ownerAddress});

           await expectThrow(CDB.newNotary(firstLandlord ,0 , 456456, {from: externalAddress}));
           await expectThrow(CDB.newNotary(externalAddress ,0 , 456456, {from: firstLandlord}));
           await expectThrow(CDB.newNotary(firstLandlord ,0 , 4564564, {from: firstLandlord}));
           await CDB.newNotary(firstLandlord ,0 , 456456, {from: firstLandlord});

           await expectThrow(CDB.reserveProperty(0, 0, {from: ownerAddress}));
           await expectThrow(CDB.reserveProperty(0, 0, {from: firstLandlord}));
           await expectThrow(CDB.reserveProperty(0, 0, {from: externalAddress}));

           await expectThrow(CDB.releaseProperty(0, 0, {from: ownerAddress}));
           await expectThrow(CDB.releaseProperty(0, 0, {from: firstLandlord}));
           await expectThrow(CDB.releaseProperty(0, 0, {from: externalAddress}));

           await expectThrow(CDB.sellProperty(externalAddress, 0, 0, 456456456456, {from: ownerAddress}));
           await expectThrow(CDB.sellProperty(externalAddress, 0, 0, 456456456456, {from: firstLandlord}));
           await expectThrow(CDB.sellProperty(externalAddress, 0, 0, 456456456456, {from: externalAddress}));

           let getNotaryAddress = await CDB.identifyNotary(0);
           let notar = await Notary.at(getNotaryAddress);
           console.log(getNotaryAddress + " this is Notary contract address ");

           // should have 0 balance at deployment
           const startBalance = await web3.eth.getBalance(getNotaryAddress);
           assert.equal(startBalance, 0);

           let vanzatorul = await CDB.forIndex(0);
           console.log(vanzatorul +" this is the seller address");

           let sellerbalance = web3.eth.getBalance(firstLandlord);
           console.log(sellerbalance + " this is initial seller balance");
           let buyerbalance = web3.eth.getBalance(buyerAddress);
           console.log(buyerbalance + " thi is initial buyer balance");

           const price = web3.toWei('7', 'ether');
           const downpayment = web3.toWei('1', 'ether');
           const newprice = web3.toWei('6', 'ether');
           const buyerincrease = web3.toWei('5', 'ether');

           await expectThrow(notar.setInitialParameters(buyerAddress, price, 963963, {from: externalAddress}));
           await notar.setInitialParameters(buyerAddress, price, 963963, {from: firstLandlord});
           await expectThrow(notar.setInitialParameters(buyerAddress, price, 963963, {from: firstLandlord}));

           await expectThrow(notar.agreementForPreliminary({from: firstLandlord}));
           await expectThrow(notar.agreementForPreliminary({from: buyerAddress}));
           await expectThrow(notar.preliminaryContract({from: firstLandlord}));
           await expectThrow(notar.preliminaryContract({from: buyerAddress}));
           await expectThrow(notar.sellerProposal(newprice, 963963111, {from: firstLandlord}));
           await expectThrow(notar.buyerProposal(newprice, 963963111, {from: buyerAddress}));
           await expectThrow(notar.increaseBuyerBalance({from:buyerAddress, value: buyerincrease}));

           await expectThrow(notar.downPayment(downpayment, {from: externalAddress, value: downpayment}));
           await notar.downPayment(downpayment, {from: firstLandlord, value: downpayment});
           await notar.downPayment(downpayment, {from: buyerAddress, value: downpayment});
           await expectThrow(notar.downPayment(downpayment, {from: firstLandlord, value: downpayment}));
           await expectThrow(notar.downPayment(downpayment, {from: buyerAddress, value: downpayment}));

           await expectThrow(notar.preliminaryContract({from: firstLandlord}));
           await expectThrow(notar.preliminaryContract({from: buyerAddress}));
           await expectThrow(notar.sellerProposal(newprice, 963963111, {from: firstLandlord}));
           await expectThrow(notar.buyerProposal(newprice, 963963111, {from: buyerAddress}));
           await expectThrow(notar.increaseBuyerBalance({from:buyerAddress, value: buyerincrease}));

           await expectThrow(notar.agreementForPreliminary({from: externalAddress}));
           await notar.agreementForPreliminary({from: firstLandlord});
           await notar.agreementForPreliminary({from: buyerAddress});

           await expectThrow(notar.sellerProposal(newprice, 963963111, {from: firstLandlord}));
           await expectThrow(notar.buyerProposal(newprice, 963963111, {from: buyerAddress}));
           await expectThrow(notar.increaseBuyerBalance({from:buyerAddress, value: buyerincrease}));

           await expectThrow(notar.preliminaryContract({from: externalAddress}));
           await notar.preliminaryContract({from: firstLandlord});

           await expectThrow(notar.sellerProposal(newprice, 963963111, {from: externalAddress}));
           await notar.sellerProposal(newprice, 963963111, {from: firstLandlord});

           await expectThrow(notar.buyerProposal(newprice, 963963111, {from: externalAddress}));
           await notar.buyerProposal(newprice, 963963111, {from: buyerAddress});

           await expectThrow(notar.increaseBuyerBalance({from:externalAddress, value: buyerincrease}));
           await notar.increaseBuyerBalance({from: buyerAddress, value:buyerincrease});
           // test are mostly identical up until this point

           await expectThrow(notar.disagreementForVoid({from:externalAddress}));
           await notar.disagreementForVoid({from: firstLandlord});
           await expectThrow(notar.disagreementForVoid({from: buyerAddress}));

           await expectThrow(notar.withdrawBalances({from: externalAddress}));
           await notar.withdrawBalances({from: buyerAddress});
           await notar.withdrawBalances({from: firstLandlord});

           let sellerbalancef = web3.eth.getBalance(firstLandlord);
           console.log(sellerbalancef + " this is final seller balance");
           let buyerbalancef = web3.eth.getBalance(buyerAddress);
           console.log(buyerbalancef + " this is final buyer balance");

           let noulproprietar = await CDB.forIndex(0);
           console.log(noulproprietar +" this should be the seller");
           
         });

     }); // END OF CONTRACT
