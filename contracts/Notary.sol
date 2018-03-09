pragma solidity ^0.4.21;

import "./math/SafeMath.sol";

contract CadasterDatabaseInterface {

    function forIndex(uint256 _propertyindex) external view returns (address, uint256, bool);
    function reserveProperty(uint256 _propertyindex, uint256 _contractindex) external;
    function releaseProperty(uint256 _propertyindex, uint256 _contractindex) external;
    function sellProperty(address _newlandlord, uint256 _propertyindex, uint256 _contractindex, uint256 _selltime) external;

}

contract Notary {

    using SafeMath for uint256;

    CadasterDatabaseInterface CDBI;

    address public seller;
    address public buyer;

    uint256 public index;
    uint256 public contractindex;

    uint256 public price;
    uint256 public pricedifference;
    uint256 public downpayment;
    uint256 public totalBalances;

    uint256 public starttime;
    uint256 public duration;
    uint256 public endtime;

    uint256 public sellerprice;
    uint256 public buyerprice;

    uint256 public downpaymentbuyer;
    uint256 public downpaymentseller;

    uint256 public sellerduration;
    uint256 public buyerduration;

    bool initialset;
    bool public isreserved;
    address public propertylandlord;

    event DownPaymentIsSet (address who, uint256 howmuch);
    event AgreedForPreliminary (address who);
    event PreliminaryContractInitiated (address buyer,
        uint256 price, uint256 starttime, uint256 duration);
    event SellerProposal(uint256 proposedprice, uint256 proposedduration);
    event BuyerProposal (uint256 proposedprice, uint256 proposedduration);
    event BuyerBalanceIncrease (uint256 howmuch);
    event ContractVoided(bool isvoided);
    event ContractBreaked(address who);
    event NewPriceSet(uint256 howmuch);
    event NewDurationSet (uint256 howmuch);
    event AgreementForTransaction(bool agreeementfortransaction);
    event TransactionComplete (address buyer, address seller, uint256 price, uint256 endtime);
    event BalanceIsClaimed (address claimer);

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
        require(downpaymentbuyer != 0);
        require(downpaymentseller != 0);
        _;
    }

    mapping (address => bool) public agreedforpreliminary;
    mapping (address => bool) public agreedfortransaction;
    mapping (address => uint256) public balances;
    mapping (address => bool) public breakscontract;
    mapping (address => bool) public agreedforvoid;

    //constructor
    function Notary(
    address _seller,
    uint256 _propertyindex,
    address _CDBAddress,
    uint256 _contractindex) public {

        CDBI = CadasterDatabaseInterface(_CDBAddress);
        (propertylandlord, , isreserved) = CDBI.forIndex(_propertyindex);

        require(propertylandlord == _seller);

        seller = _seller;
        index = _propertyindex;
        contractindex = _contractindex;

    }


    function setInitialParameters(address _buyer,
       uint256 _price,
       uint256 _duration) external onlySeller {

        require(!initialset);
        initialset = true;
        buyer = _buyer;
        price = _price;
        duration = _duration;
    }

    // used by the CadasterDatabase contract to get the seller of the current contract
    function getNotarySeller() external view returns (address) {
        return seller;
    }

    function getNotayCadasterNumber() external view returns (uint256) {
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
    // BUG: one party can call this again and break ?
    function downPayment(uint256 _downpayment) external payable onlyParties propertyIsNotReserved {

        require(_downpayment != 0);
        require(_downpayment == msg.value);

        if (msg.sender == buyer) {
            require(agreedforpreliminary[buyer] == false);
            require(downpaymentbuyer == 0);
            downpaymentbuyer = _downpayment;
            balances[buyer] = balances[buyer].add(downpaymentbuyer);
        }

        if (msg.sender == seller) {
            require(agreedforpreliminary[seller] == false);
            require(downpaymentseller == 0);
            downpaymentseller = _downpayment;
            balances[seller] = balances[buyer].add(downpaymentseller);
        }

         emit DownPaymentIsSet(msg.sender, _downpayment);
    }

    // @dev When a party calls this it means he/she agrees with the terms.
    // @dev If both parties agree, preliminaryContract is triggered
    // could this be called at the same time => does not know that the other one is also true  => not preliminaryContract ?
    function agreementForPreliminary() external onlyParties propertyIsNotReserved correctDownPayment {

        if (msg.sender == buyer) {
            agreedforpreliminary[buyer] = true;
             AgreedForPreliminary(msg.sender);
        }
        if (msg.sender == seller) {
            agreedforpreliminary[seller] = true;
             AgreedForPreliminary(msg.sender);
        }
        if (agreedforpreliminary[buyer] == true && agreedforpreliminary[seller] == true) {
            balances[buyer] = balances[buyer].sub(downpaymentbuyer);
            balances[seller] = balances[seller].sub(downpaymentseller);
        }
    }

    // @dev This is the function which actually produces effect and locks the downpayment as escrow
    function preliminaryContract() public onlyParties propertyIsNotReserved correctDownPayment {

        require(agreedforpreliminary[buyer] == true && agreedforpreliminary[seller] == true);

        starttime = block.timestamp;
        endtime = starttime.add(duration);
        CDBI.reserveProperty(index, contractindex);
        // update isreserved Could just manually set it
        (, , isreserved) = CDBI.forIndex(index);

        pricedifference = price.sub(downpaymentseller); // or downpaymentbuyer
        emit PreliminaryContractInitiated(buyer, price, starttime, duration);
    }

    // @dev Seller can propose diffrent terms for transaction (price and duration)
    // @param _sellerprice The new price proposed by the seller
    // @param _duration The new duration proposed by the seller
    function sellerProposal(uint256 _sellerprice, uint256 _sellerduration) external onlySeller propertyIsReserved {

        require(_sellerduration > now.sub(starttime));
        sellerprice = _sellerprice;
        sellerduration = _sellerduration;
        triggerProposals();

        emit SellerProposal(_sellerprice, _sellerduration);
    }

    // @dev Buyer can propose diffrent terms for transaction (price and duration)
    // @param _buyerprice The new price proposed by the buyer
    // @param _duration The new duration proposed by the buyer
    function buyerProposal(uint256 _buyerprice, uint256 _buyerduration) external onlyBuyer propertyIsReserved  {

        require(_buyerduration > now.sub(starttime));
        buyerprice = _buyerprice;
        buyerduration = _buyerduration;
        triggerProposals();

        emit BuyerProposal(_buyerprice, _buyerduration);
    }

    // @dev This function gets triggered eacht time either party proposes diffrent terms
    function triggerProposals() private onlyParties propertyIsReserved {

        if (sellerprice == buyerprice && sellerprice != 0 && buyerprice != 0) {
            price = sellerprice; // or price = buyerprice;
            pricedifference = price.sub(downpaymentseller);

          emit NewPriceSet(sellerprice);
        }
        if (sellerduration == buyerduration && sellerduration != 0 && buyerduration != 0) {
            duration = buyerduration; // idem
            endtime = starttime.add(duration);

            emit NewDurationSet(buyerduration);
        }
    }

    // @dev Allows the buyer to increase his balance so that it has enough funds for transaction
    function increaseBuyerBalance() external payable onlyBuyer propertyIsReserved {
        // this can lock the contract if buyer forgets to increas balance
        // prior to agreeing for transaction => should remove it because
        // buyer can claim all of it's balance
        require(agreedfortransaction[buyer] == false);
        balances[buyer] = balances[buyer].add(msg.value);

         emit BuyerBalanceIncrease(msg.value);

    }

    // @dev Either party can call this function, breaking the contract and loosing the downpayment as a penalty
    function disagreementForVoid() external onlyParties propertyIsReserved correctDownPayment {

        if (msg.sender == buyer) {
            breakscontract[buyer] = true;
            transaction();

             emit ContractBreaked(msg.sender);
        }
        if (msg.sender == seller) {
            breakscontract[seller] = true;
            transaction();

             emit ContractBreaked(msg.sender);
        }
    }

    // @dev If both parties agree to void the contract, both receive the downpayment as a refund
    function agreementForVoid () external onlyParties propertyIsReserved correctDownPayment {

        if (msg.sender == buyer) agreedforvoid[buyer] = true;
        if (msg.sender == seller) agreedforvoid[seller] = true;
        if (agreedforvoid[buyer] == true && agreedforvoid[seller] == true) {
            transaction();

             emit ContractVoided(true);
        }
    }

    // @dev When a party calls this it means he agrees with the terms. If both agree tranasction is triggered
    function agreementForTransaction () external onlyParties propertyIsReserved correctDownPayment  {

        if (msg.sender == buyer) {agreedfortransaction[buyer] = true;}
        if (msg.sender == seller) {agreedfortransaction[seller] = true;}
        if (agreedfortransaction[buyer] == true && agreedfortransaction[seller] == true) {
            transaction();

            emit AgreementForTransaction(true);
        }
    }

    // temporary alternative to Alarm Clock
    function triggerTermination () external onlyParties {
        require(now < endtime);
        transaction();
      }

    // @dev This is the funcion which resolves the contract either way
    function transaction () private propertyIsReserved correctDownPayment {

        if (balances[buyer] >= pricedifference && breakscontract[seller] == false && breakscontract[buyer] == false &&
            agreedforvoid[buyer] == false && agreedforvoid[seller] == false) {

            //pricedifference = price - downpaymentbuyer; // or downpaymentseller
            balances[buyer] = balances[buyer].sub(pricedifference);
            balances[seller] = balances[seller].add(pricedifference).add(downpaymentseller).add(downpaymentbuyer);
            CDBI.sellProperty(buyer, index, contractindex, now);
            // downpaymentbuyer = 0;
            // downpaymentseller = 0;
            isreserved = false;

        } else if (agreedforvoid[buyer] == true && agreedforvoid[seller] == true) {
        //  || (breakscontract[buyer] == true && breakscontract[seller] == true) this should not be possible
            balances[buyer] = balances[buyer].add(downpaymentbuyer).add(downpaymentseller);
            //balances[seller] = balances[seller].add(downpaymentseller);
            CDBI.releaseProperty(index, contractindex);
            // downpaymentbuyer = 0;
            // downpaymentseller = 0;
            isreserved = false;

        } else if (breakscontract[buyer] == true && breakscontract[seller] == false) {
            balances[seller] = balances[seller].add(downpaymentbuyer).add(downpaymentseller);
            //balances[seller] = balances[seller].add(downpaymentseller);
            CDBI.releaseProperty(index, contractindex);
             //downpaymentbuyer = 0;
             //downpaymentseller = 0;
            isreserved = false;

        } else if (breakscontract[buyer] == false && breakscontract[seller] == true) {
            balances[buyer] = balances[buyer].add(downpaymentseller).add(downpaymentbuyer);
            //balances[buyer] = balances[buyer].add(downpaymentbuyer);
            CDBI.releaseProperty(index, contractindex);
             //downpaymentbuyer = 0;
             //downpaymentseller = 0;
            isreserved = false;

        }

        emit TransactionComplete(seller, buyer, price, endtime);
    }

    // inspired by:
    //https://github.com/OpenZeppelin/zeppelin-solidity/blob/master/contracts/payment/PullPayment.sol

     function withdrawBalances() public onlyParties propertyIsNotReserved {
        address claimer = msg.sender;
        uint256 withdrawal = balances[claimer];

        require(withdrawal != 0);
        require(this.balance >= withdrawal);

        //totalBalances = totalBalances.sub(withdrawal);
        balances[claimer] = 0;

        assert(claimer.send(withdrawal));

        emit BalanceIsClaimed(msg.sender);
    }

    // @dev fallback function
    function() public payable {}

        // TODO: modify cadasternumber from uint256 to string ?
        // TODO: Pause, Limit, Upgrade
        // add a selfdestruct after both balances are claimed ?
        // TODO: There is no way to loop propertyarray as it would (presumably) be
        // very large and an OOG error would be reached fast.
        // Possible fix: Loop it client-side via events
        // TODO:duration is set in seconds, using "now" as a source of time and transaction function does not trigger
        // if duration time expires(and it should).
        // Possible fix: use Ehereum Alarm clock from https://github.com/pipermerriam/ethereum-alarm-clock
}
