pragma solidity ^0.4.21;

import "./Notary.sol";

contract NotaryInterface {
    function getNotarySeller() external view returns (address);
    function getNotayCadasterNumber() external view returns (uint256);
    function getNotaryAddress() external view returns (address);
}

contract CadasterDatabase {

    NotaryInterface NI;

    //owner of the contract
    address public owner;

    event PropertyAdded (address seller, uint256 nrcadastral, uint256 timeofaquire, bool reserved);
    event PropertyReserved(address seller, uint256 cadasternumber, uint256 propertyindex, uint256 contractindex);
    event PropertyFree(address seller, uint256 cadasternumber, uint256 propertyindex, uint256 contractindex);
    event SoldProperty(address buyer, uint256 cadasternumber, uint256 propertyindex, uint256 timeofaquire);

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    // constructor function
    function CadasterDatabase() public {
        owner = msg.sender;
    }

    // @dev This struct represents a property and it's characteristics
    // should be added: phisical address, size in sqm, topographical coordinates, uPort integration
    struct Property {

        address landlord;

        uint256 cadasternumber;

        uint256 timeofaquire;

        bool reserved;

    }

    Property[] public propertyarray; // All properties are stored here.
    uint256 public propertiescount; // This is the total number of properties.
    address[] public notaries; // This is where all of the Notary contracts are stored.

    // @dev This function should be used by the cadaster bureau to add new properties
    // @param _landlord The ethereum address of the owner of the property
    // @param _cadasternumber The unique ID of the property called cadasternumber
    // @param _timeofaquire The time that the property was aquired by the current landlord
    // @param _reserved Prevents the landlord from selling the property to multiple parties at the same time
    // TODO: should check that it is not already added
    function addProperty (
        address _landlord,
        uint256 _cadasternumber,
        uint256 _timeofaquire,
        bool _reserved) public onlyOwner {

        Property memory init;

        init.landlord = _landlord;
        init.cadasternumber = _cadasternumber;
        init.timeofaquire = _timeofaquire;
        init.reserved = _reserved;
        propertiescount++;

        propertyarray.push(init);

        emit PropertyAdded(_landlord, _cadasternumber, _timeofaquire, _reserved);
    }

    // @dev Replaces cadasternumber at current index and (possibly) adds new Property
    // @param _landlord The ethereum address of the owner of the property
    // @param _currentcadasternumber The current cadasternumber of the property
    // @param _firstcadasternumber The first (or modified) cadasternumber
    // @param _secondcadasternumber The second cadasternumber
    // @param _propertyindex The index of Property struct
    // TODO: the landlord should be notified and accept these changes
    function splitOrModifyProperty (
        address _landlord,
        uint256 _currentcadasternumber,
        uint256 _firstcadasternumber,
        uint256 _secondcadasternumber,
        uint256 _propertyindex) external onlyOwner {

        require(propertyarray[_propertyindex].landlord == _landlord);
        require(propertyarray[_propertyindex].cadasternumber == _currentcadasternumber);

        propertyarray[_propertyindex].cadasternumber = _firstcadasternumber;
        propertyarray[_propertyindex].timeofaquire = block.timestamp;

        if (_secondcadasternumber != 0) {

            addProperty(_landlord, _secondcadasternumber, block.timestamp, propertyarray[_propertyindex].reserved);
            propertiescount++;
            emit PropertyAdded(_landlord,
            _secondcadasternumber,
            block.timestamp,
            propertyarray[_propertyindex].reserved);
        }
    }

    // @dev Takes an index as param and returns landlord address,
    // @dev cadasternumber and if the property is reserved
    // @param _propertyindex The index of Property struct
    function forIndex(uint256 _propertyindex) external view returns (
        address, uint256, bool) {

        return (propertyarray[_propertyindex].landlord,
            propertyarray[_propertyindex].cadasternumber,
            propertyarray[_propertyindex].reserved);
    }

    // @dev Takes an index, an adress and a uint256 as param and
    // @dev returns true if the index matches the address and the uint256
    // @param _propertyindex The index of Property struct
    // @param _landlord The address for which it should match
    // @param _cadasternumber The uint256 for which it should match
    function isOwner(uint256 _propertyindex,
        address _landlord,
        uint256 _cadasternumber) external view returns (bool isindeed) {

        require(propertyarray[_propertyindex].landlord == _landlord);
        require(propertyarray[_propertyindex].cadasternumber == _cadasternumber);
        return true;
    }

    // @dev Deploys a new Notary contract which allows properties to be traded
    // @param _seller The seller which must also be the landlord and it is the only one that can deploy the contract
    // @param _buyer The buyer of the property. This can be any address
    // @param _propertyindex The index of Property struct
    // @param _price The price of the property. Can be negotiated later
    // @param _duration The duration of Notary contract. Can be negotiated later
    // @param _cadasternumber The cadasternumber from the Property struct
    function newNotary (address _seller, uint256 _propertyindex, uint256 _cadasternumber) external {

        require(msg.sender == propertyarray[_propertyindex].landlord);
        require(propertyarray[_propertyindex].landlord == _seller);
        require(propertyarray[_propertyindex].cadasternumber == _cadasternumber);

        Notary notary = new Notary(_seller, _propertyindex, this, notaries.length);
        notaries.push(notary);
    }

    // @dev Returns the Notary address and the length of notaries array. It is used to identify Notary contract
    // @param _contractindex The index of the Notary contract
    function identifyNotary(uint256 _contractindex) external view returns (address) {
        return (notaries[_contractindex]);
    }

    // @dev It is used to mark a Property struct as reserved in order to prevent double selling of the same Property
    // @param _propertyindex The index of Property struct
    // @param _contractindex The index of the Notary contract

    // rename function in order to avoid confusion ?
    function reserveProperty(uint256 _propertyindex, uint256 _contractindex) external {
        NI = NotaryInterface(notaries[_contractindex]);
        require(msg.sender == NI.getNotaryAddress());
      //  require(notaries[_contractindex] == NI.getNotaryAddress());
        require(propertyarray[_propertyindex].landlord == NI.getNotarySeller());
        //require(propertyarray[_propertyindex].cadasternumber == NI.getNotayCadasterNumber());
        propertyarray[_propertyindex].reserved = true;

         emit PropertyReserved(propertyarray[_propertyindex].landlord,
            propertyarray[_propertyindex].cadasternumber,
            _propertyindex, _contractindex);
    }

    // @dev It is used to mark a Property struct as free for sale
    // @param _propertyindex The index of Property struct
    // @param _contractindex The index of the Notary contract
    function releaseProperty(uint256 _propertyindex, uint256 _contractindex) external {
        NI = NotaryInterface(notaries[_contractindex]);
        require(msg.sender == NI.getNotaryAddress());
        //require(notaries[_contractindex] == NI.getNotaryAddress());
        require(propertyarray[_propertyindex].landlord == NI.getNotarySeller());
      //  require(propertyarray[_propertyindex].cadasternumber == NI.getNotayCadasterNumber());
        propertyarray[_propertyindex].reserved = false;

        emit PropertyFree(propertyarray[_propertyindex].landlord,
            propertyarray[_propertyindex].cadasternumber,
            _propertyindex, _contractindex);
    }

    // @dev This function changes the landlord, timeofaquire and reserved status after the tranasction is complete
    // @param _newlandlord This is basically the buyer in the Notary contract
    // @param _propertyindex The index of Property struct
    // @param _contractindex The index of the Notary contract
    // @param _selltime The timestamp at which the property was sold. Replaces timeofaquire
    function sellProperty(address _newlandlord,
        uint256 _propertyindex,
        uint256 _contractindex,
        uint256 _selltime) external {

        NI = NotaryInterface(notaries[_contractindex]);
        require(msg.sender == NI.getNotaryAddress());
        //require(notaries[_contractindex] == NI.getNotaryAddress());
        require(propertyarray[_propertyindex].landlord == NI.getNotarySeller());
        //require(propertyarray[_propertyindex].cadasternumber == NI.getNotayCadasterNumber());

        propertyarray[_propertyindex].landlord = _newlandlord;
        propertyarray[_propertyindex].reserved = false;
        propertyarray[_propertyindex].timeofaquire = _selltime;

        emit SoldProperty(_newlandlord, propertyarray[_propertyindex].cadasternumber, _propertyindex, _selltime);
    }

    // @dev fallback function
    function() public payable {}

}
