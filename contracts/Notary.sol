pragma solidity ^0.4.19;

contract CadasterDatabaseInterface {

    function forIndex(uint _propertyindex) external view returns (address, uint, bool);
    function reserveProperty (uint _propertyindex, uint _contractindex) public;
    function sellProperty(address _newlandlord, uint _propertyindex, uint _contractindex, uint _selltime) public;

}


contract Notary {

    CadasterDatabaseInterface CDBI;

    address public seller;
    address public buyer;

    uint public index;
    uint public contractindex;

    uint public price;
    uint public pricedifference;
    uint public downpayment;

    uint public starttime;
    uint public duration;
    uint public endtime;

    uint public sellerprice;
    uint public buyerprice;

    uint public downpaymentbuyer;
    uint public downpaymentseller;

    uint public sellerduration;
    uint public buyerduration;

    event EmitDownPaymentIsSet (address who, uint howmuch);
    event EmitAgreedForPreliminary (address who);

    event EmitPreliminaryContractInitiated (address buyer, address seller,
        uint price, uint downpaymentbuyer, uint starttime, uint duration);

    event EmitSellerProposal(uint proposedprice, uint proposedduration);
    event EmitBuyerProposal (uint proposedprice, uint proposedduration);
    event EmitBuyerBalanceIncrease (uint howmuch);
    event EmitContractVoided(bool isvoided);
    event EmitContractBreaked(address who);
    event EmitNewPriceSet(uint howmuch);
    event EmitNewDurationSet (uint howmuch);
    event EmitAgreementForTransaction(bool agreeementfortransaction);
    event EmitTransactionComplete (address buyer, address seller, uint price, uint endtime);
    event EmitBalanceIsClaimed (address claimer);

    modifier onlyBuyer {
        require(msg.sender == buyer);
        _;
    }

    modifier onlySeller {
        require(msg.sender == seller);
        _;
    }

    modifier onlyParties {
        require(msg.sender == seller || msg.sender == buyer);
        _;
    }

    modifier propertyIsNotReserved {
        require(isreserved == false);
        _;
    }

    modifier propertyIsReserved {
        require(isreserved == true);
        _;
    }

    modifier correctDownPayment {
        require(downpaymentseller == downpaymentbuyer);
        require(downpaymentbuyer != 0); // both necessary ?
        require(downpaymentseller != 0);
        _;
    }

    mapping (address => bool) public agreedforpreliminary;
    mapping (address => bool) public agreedfortransaction;
    mapping (address => uint) public balances;
    mapping (address => bool) public breakscontract;
    mapping (address => bool) public agreedforvoid;

    // Properly place these 3 variables
    bool public isreserved;
    uint public cadasternumber;
    address public propertylandlord;

    //constructor
    // CDBI address could be set manually in order to avoid confusion
    function Notary(
    address _seller,
    address _buyer,
    uint _propertyindex,
    uint _price,
    uint _duration,
    address _CDBAddress,
    uint _contractindex,
    uint _cadasternumber) public {

        CDBI = CadasterDatabaseInterface(_CDBAddress);
        (propertylandlord, cadasternumber, isreserved) = CDBI.forIndex(_propertyindex);

        require(propertylandlord == _seller);
        require(cadasternumber == _cadasternumber);
        seller = _seller;
        buyer = _buyer;
        index = _propertyindex;
        price = _price;
        duration = _duration;
        contractindex = _contractindex;

    }

    // TODO: merge the next 3 functions into a single one
    // used by the CadasterDatabase contract to get the seller of the current contract
    function getNotarySeller() external view returns (address) {
        return seller;
    }

    function getNotayCadasterNumber() external view returns (uint) {
        return cadasternumber;
    }

    function getNotaryAddress() external view returns (address) {
        return this;
    }

    // @dev downPayment function sets the value which will be held as escrow when preliminaryContract is triggered
    // @param _downpayment The value which either party wishes to set as downpayment
    //  can be called multiple times prior transaction
    // attention: if parties fail to agree on a downpayment the contract just
    // waits for finish and has little effect as downpayment remains zero => no penalties
    function downPayment (uint _downpayment) public payable onlyParties propertyIsNotReserved correctDownPayment {

        if (msg.sender == buyer) {
            require(agreedforpreliminary[buyer] == false);
            downpaymentbuyer = _downpayment;
            balances[buyer] += downpaymentbuyer;
        }

        if (msg.sender == seller) {
            require(agreedforpreliminary[seller] == false);
	          downpaymentseller = _downpayment;
            balances[seller] += downpaymentseller;
        }

        EmitDownPaymentIsSet(msg.sender, _downpayment);
    }

    // @dev When a party calls this it means he/she agrees with the terms.
    // @dev If both parties agree, preliminaryContract is triggered
    function agreementForPreliminary () public onlyParties propertyIsNotReserved correctDownPayment {

        if (msg.sender == buyer) {
            agreedforpreliminary[buyer] = true;
            EmitAgreedForPreliminary(msg.sender);
        }
        if (msg.sender == seller) {
            agreedforpreliminary[seller] = true;
            EmitAgreedForPreliminary(msg.sender);
        }
        if (agreedforpreliminary[buyer] == true && agreedforpreliminary[seller] == true) preliminaryContract();
    }

    // @dev This is the function which actually produces effect and locks the downpayment as escrow
    //Checks-Effects-Interaction
    function preliminaryContract () private onlyParties propertyIsNotReserved
                              correctDownPayment returns (bool success) {

        require(agreedforpreliminary[buyer] == true && agreedforpreliminary[seller] == true);

        require(balances[buyer] == downpaymentbuyer);
        require(balances[buyer] == balances[seller]);
        require(balances[seller] == downpaymentseller);

        starttime = now;
        endtime = starttime + duration;
        CDBI.reserveProperty(index, contractindex);
        // update isreserved Could just manually set it
        (, , isreserved) = CDBI.forIndex(index);

        balances[buyer] -= downpaymentbuyer;
        balances[seller] -= downpaymentseller;
        pricedifference = price - downpaymentseller; // or downpaymentbuyer
        return true;

        EmitPreliminaryContractInitiated(buyer, seller, price, downpaymentbuyer, starttime, duration);
    }

    // @dev Seller can propose diffrent terms for transaction (price and duration)
    // @param _sellerprice The new price proposed by the seller
    // @param _duration The new duration proposed by the seller
    function sellerProposal(uint _sellerprice, uint _sellerduration) public onlySeller propertyIsReserved {

        sellerprice = _sellerprice;
        require(_sellerduration > (now - starttime));
        sellerduration = _sellerduration;
        triggerProposals();

        EmitSellerProposal(_sellerprice, _sellerduration);
    }

    // @dev Buyer can propose diffrent terms for transaction (price and duration)
    // @param _buyerprice The new price proposed by the buyer
    // @param _duration The new duration proposed by the buyer
    function buyerProposal(uint _buyerprice, uint _buyerduration) public onlyBuyer propertyIsReserved  {

        buyerprice = _buyerprice;
        require(_buyerduration > (now - starttime));
        buyerduration = _buyerduration;
        triggerProposals();

        EmitBuyerProposal(_buyerprice, _buyerduration);
    }

    // @dev This function gets triggered eacht time either party proposes diffrent terms
    function triggerProposals () private onlyParties propertyIsReserved {

        if (sellerprice == buyerprice && sellerprice != 0 && buyerprice != 0) {
            price = sellerprice; // or price = buyerprice;

            EmitNewPriceSet(sellerprice);
        }
        if (sellerduration == buyerduration && sellerduration != 0 && buyerduration != 0) {
            duration = buyerduration; // idem

            EmitNewDurationSet(buyerduration);
        }
    }

    // @dev Allows the buyer to increase his balance so that it has enough funds for transaction
    function increaseBuyerBalance () public payable onlyBuyer propertyIsReserved {

        require(agreedfortransaction[buyer] == false);// this can lock the contract if buyer forgets to
        if (msg.sender == buyer) balances[buyer] += msg.value;

        EmitBuyerBalanceIncrease(msg.value);
    }

    // @dev Either party can call this function, breaking the contract and loosing the downpayment as a penalty
    // TODO: make sure property is NOT reserved after contract termination
    function disagreementForVoid() public onlyParties propertyIsReserved {

        require(downpaymentbuyer != 0 && downpaymentseller == downpaymentbuyer && downpaymentseller != 0);
        if (msg.sender == buyer) {
            breakscontract[buyer] = true;
            transaction();

            EmitContractBreaked(msg.sender);
        }
        if (msg.sender == seller) {
            breakscontract[seller] = true;
            transaction();

            EmitContractBreaked(msg.sender);
        }
    }

    // @dev If both parties agree to void the contract, both receive the downpayment as a refund
    // TODO: makes sure property is NOT reserved after contract termination
    function agreementForVoid () public onlyParties propertyIsReserved  {

        require(downpaymentbuyer != 0 && downpaymentseller == downpaymentbuyer && downpaymentseller != 0);
        if (msg.sender == buyer) agreedforvoid[buyer] = true;
        if (msg.sender == seller) agreedforvoid[seller] = true;
        if (agreedforvoid[buyer] == true && agreedforvoid[seller] == true) {
            transaction();

            EmitContractVoided(true);
        }
    }

    // @dev When a party calls this it means he agrees with the terms. If both agree tranasction is triggered
    function agreementForTransaction () public onlyParties propertyIsReserved  {

        require(downpaymentbuyer != 0 && downpaymentseller == downpaymentbuyer && downpaymentseller != 0);
        if (msg.sender == buyer) {agreedfortransaction[buyer] = true;}
        if (msg.sender == seller) {agreedfortransaction[seller] = true;}
        if (agreedfortransaction[buyer] == true && agreedfortransaction[seller] == true) {
            transaction();

            EmitAgreementForTransaction(true);
        }
    }

    // @dev This is the funcion which resolves the contract either way
    // TODO: make sure property is NOT reserved after contract termination
    function transaction () private propertyIsReserved returns (bool transactioncomplete) {

        if (balances[buyer] >= pricedifference && breakscontract[seller] == false && breakscontract[buyer] == false &&
            agreedforvoid[buyer] == false && agreedforvoid[seller] == false) {

              //pricedifference = price - downpaymentbuyer; // or downpaymentseller
            balances[buyer] -= pricedifference;
            balances[seller] += pricedifference;
            balances[seller] += downpaymentbuyer + downpaymentseller;
            CDBI.sellProperty(buyer, index, contractindex, now);

        } else if (agreedforvoid[buyer] == true && agreedforvoid[seller] == true) {
        //  || (breakscontract[buyer] == true && breakscontract[seller] == true) this should not be possible
            balances[buyer] += downpaymentbuyer;
            balances[seller] += downpaymentseller;
        } else if (breakscontract[buyer] == true && breakscontract[seller] == false) {
            balances[seller] += downpaymentbuyer;
        } else if (breakscontract[buyer] == false && breakscontract[seller] == true) {
            balances[buyer] += downpaymentseller;
        }

        return true;

        EmitTransactionComplete(seller, buyer, price, endtime);
    }

    // @dev Allows either party to claim it's balance
    // Checks-Effects-Interaction
    // replace this with pullpayment.sol
    function claimBalance(address _claimer) public onlyParties {

        //require(propertyarray[index].reserved == false);
        if (_claimer == seller && balances[seller] > 0) {
			      balances[seller] = 0;
            seller.transfer(balances[seller]);
        }

        if (_claimer == buyer && balances[buyer] > 0) {
			      balances[buyer] = 0;
            buyer.transfer(balances[buyer]);
        }

        EmitBalanceIsClaimed(_claimer);
    }

    // @dev fallback function
    function() public payable { revert(); }

        // TODO: Rearrange function order based on visibility
        // TODO: Gas optimizations
        // TODO: use safemath in order to provent overflows
        // add a selfdestruct after both balances are claimed ?
        // TODO: There is no way to loop propertyarray as it would (presumably) be
        // very large and an OOG error would be reached fast.
        // Possible fix: Loop it client-side via events
        // TODO:duration is set in seconds, using "now" as a source of time and transaction function does not trigger
        // if duration time expires(and it should).
        // Possible fix: use Ehereum Alarm clock from https://github.com/pipermerriam/ethereum-alarm-clock
}
