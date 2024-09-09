// SPDX-License-Identifier: MIT 
pragma solidity >=0.8.2 <0.9.0;

import "../node_modules/hardhat/console.sol";
import "./_Rank.sol";
import "./_UserType.sol";

contract FFFMaster {
    // Bussiness master 
    address payable public master;
    uint public totalMembers;
    uint public totalActiveMembers;

    // Bussiness refund
    //Verification parameters
    uint private _minAmountToTransfer = 100;  // Currently is 100 wei
    uint private _refundPercent = 3;
    uint private _transferPercent = 100 - _refundPercent;

    struct Member {
        address payable client;
        address[] enrolled;
        bool isActive;
        bool isRegistered;
        uint balance;
        Rank rank;
        UserType userType;
    }

    // Memebers within 3F contract
    mapping(address => Member) public members;

    
    modifier onlyMaster() {
        require(msg.sender == master, "You aren't the master user");
        _;
    }

    modifier onlyActiveMember(){
        require(members[msg.sender].isActive, "Member not active");
        _;
    }

    modifier  checkIfNotRegistered() {
        require(!members[msg.sender].isRegistered, "Member already exists");
        _;
    }

    modifier checkMemberBalance(uint _amount) {
        require(members[msg.sender].balance >= _amount, "Insufficient balance");
        _;
    }

    modifier checkContractBalance(uint _amount) {
        require(address(this).balance >= _amount, "The contract doesn't have sufficient balance");
        _;
    }

    modifier checkValidAddress(address _recipient) {
        require(_recipient != address(0), "Invalid address");
        _;
    }

    modifier preventBankruptcy(uint _amount) {
        uint totalBalance = address(this).balance;
        uint precision = 100;
        uint maxQuantity = 75;
        require(
            (totalBalance * maxQuantity) / precision >= _amount, 
            "No more than 75% of the total contract balance may be withdrawn."
        );
        _;
    }

    /*----------------------------------------------------------*
    *                      CONTRACT EVENTS                      *
    *----------------------------------------------------------*/

    event Deposit(address indexed from, uint amount);
    event Transfer(address indexed from, address indexed to, uint amount);
    event Withdraw(address indexed to, uint amount);
    event Refund(address indexed to, uint amount);
    
    event DesactivateMember(address indexed member);
    event NewMember(address indexed member);
    event NewRankReached(address indexed member, string rank);


    constructor() {
        console.log("Owner contract deployed by:", msg.sender);
        master = payable(msg.sender);
        totalMembers = 0;
    }

    /*----------------------------------------------------------*
    *                 MASTER PUBLIC FUNCTIONS                   *
    *----------------------------------------------------------*/

    // TODO: Modify this function for testing with real wallets
    receive() external payable {
        // Event for deposit to constract
        emit Deposit(msg.sender, msg.value);
    }

    // TODO: Modify this function when will be deployed 
    // to production
    function deposit() public payable {}

    function deactivateMember(address _client) public onlyMaster onlyActiveMember {
        members[_client].isActive = false;
        totalActiveMembers--;
        emit DesactivateMember(_client);
    }

    function withdraw(uint _amount)
        public
        onlyMaster
        checkValidAddress(master)
        checkContractBalance(_amount)
        preventBankruptcy(_amount)
    {
        (bool sent, ) = master.call{ value: _amount }("");

        require(sent, "Withdraw not realized");

        // Emit event for withdraw funds
        emit Withdraw(master, _amount);
    }

    // get the total number of contract members, regardless of whether they are active or not 
    function getTotalMembers() public view returns (uint) {
        return totalMembers;
    }

    // Only get the total number of active members per contract
    function getTotalActiveMembers() public view returns (uint) {
        return totalActiveMembers;
    }

    /*----------------------------------------------------------*
    *                 MEMBER PUBLIC FUNCTIONS                   *
    *----------------------------------------------------------*/

    // Only members deposit function
    function depositMemeberFunds() public payable onlyActiveMember {
        // Validations
        require(msg.value > 0, "You must send some balance.");

        // Change member balance status
        members[msg.sender].balance += msg.value;

        // Emit event for deposit funds
        emit Deposit(msg.sender, msg.value);

        // Refund to client
        _refundToClient(payable(msg.sender), msg.value);
    }

    function withdrawMemberFounds(uint _amount)
        public 
        onlyActiveMember
        checkValidAddress(msg.sender)
        checkMemberBalance(_amount)
        checkContractBalance(_amount)
    {
        // Transfer funds to personal wallet
        (bool sent, ) = payable(msg.sender).call{ value: _amount }("");
        require(sent, "Transfer failed");
        
        // Change member balance status
        members[msg.sender].balance -= _amount;

        // Emit withdraw event
        emit Withdraw(msg.sender, _amount);
    }

    //Create a new member to contract
    //  @Dev: 'checkIfRegistered' verify if the current sender is alrady registered
    function createMember(address payable _client) public checkIfNotRegistered {
        // To assign new member to direction
        Member storage newMember = members[_client];

        // Validations
        require(master != _client, "You cannot create an account with the master address.");
        require(!members[_client].isActive, "Member already exists");

        // To initalize the new member
        newMember.client = _client;
        newMember.isActive = true;
        newMember.isRegistered = true;
        newMember.balance = 0;
        newMember.rank = Rank.Sapphire;
        newMember.userType = UserType.Client;

        // Increase members count
        totalMembers++;
        totalActiveMembers++;

        // Emit event for new member
        emit NewMember(_client);
    }

    // NOTE: Only if nessesary
    // Return all member details
    // function getMemberDetails(address _client)
    //     public
    //     view
    //     returns (
    //         address, 
    //         address[] memory,
    //         bool,
    //         bool,
    //         uint,
    //         Rank,
    //         UserType
    //     ) 
    // {
    //     require(members[_client].isRegistered, "Member not registered");

    //     return (
    //         members[_client].client,
    //         members[_client].enrolled,
    //         members[_client].isActive,
    //         members[_client].isRegistered,
    //         members[_client].balance,
    //         members[_client].rank,
    //         members[_client].userType
    //     );
    // }

    function getMemberDetails(address _client) public view returns (Member memory) {
        require(members[_client].isRegistered, "Member not registered");
        return members[_client];
    }

    /*----------------------------------------------------------*
    *               MASTER EXTERNAL FUNCTIONS                   *
    *----------------------------------------------------------*/
    
    function getMasterBalance() external view onlyMaster returns (uint) {
        // Get the current master contract balance
        return address(this).balance;
    }
    
    /*----------------------------------------------------------*
    *               MEMBER EXTERNAL FUNCTIONS                   *
    *----------------------------------------------------------*/

    function getMemberBalance() external view returns (uint) {
        // Get the current member balance
        return members[msg.sender].balance;
    }


    function transferMemberToMember(address payable _to, uint _amount)
        external 
        onlyActiveMember
        checkValidAddress(_to)
        checkMemberBalance(_amount)
    {
        // Validations
        require(members[_to].isActive, "Recipient isn't active user"); // Validate the recipient
        require(msg.sender != master, "Master account can't be used to transfer by this way");

        // Change member balance status
        members[msg.sender].balance -= _amount;
        members[_to].balance += _amount;

        // Event after state changes
        emit Transfer(msg.sender, _to, _amount);
    }

    /*----------------------------------------------------------*
    *                MASTER PRIVATE FUNCTIONS                   *
    *----------------------------------------------------------*/

        // Change member rank functions
    function _setSapphireRank(address _client) private {
        members[_client].rank = Rank.Sapphire;
        emit NewRankReached(_client, "Sapphire");
    }

    function _setPearlRank(address _client) private {
        members[_client].rank = Rank.Pearl;
        emit NewRankReached(_client, "Pearl");
    }

    function _setRubyRank(address _client) private {
        members[_client].rank = Rank.Ruby;
        emit NewRankReached(_client, "Ruby");
    }

    function _setEmeraldRank(address _client) private {
        members[_client].rank = Rank.Emerald;
        emit NewRankReached(_client, "Emerald");
    }

    function _setDiamondRank(address _client) private {
        members[_client].rank = Rank.Diamond;
        emit NewRankReached(_client, "Diamond");
    }

    function _getRefundAmount(uint _amount) private view  returns (uint) {
        return (_amount * _refundPercent) / 100;
    }

    function _refundToClient(address payable _to, uint _amount)
        private
        onlyActiveMember
        checkValidAddress(_to)
        checkMemberBalance(_amount)
        checkContractBalance(_amount)
    {
        uint refundAmount = _getRefundAmount(_amount);
        assert(_amount > refundAmount);


        // NOTE: Check the behavior of this condition, cause the client balance will be affected
        (bool sent, ) = _to.call{ value: refundAmount }("");
        require(sent, "Refund failed");

        // Change member balance status
        members[_to].balance -= refundAmount;

        // Emit event for refound
        emit Refund(_to, refundAmount);
    }

    /*----------------------------------------------------------*
    *                MEMBER PRIVATE FUNCTIONS                   *
    *----------------------------------------------------------*/

}