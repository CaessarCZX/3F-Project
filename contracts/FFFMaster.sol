// SPDX-License-Identifier: MIT 
pragma solidity >=0.8.2 <0.9.0;

import "../node_modules/hardhat/console.sol";
import "./_Rank.sol";

contract FFFMaster {

    /*----------------------------------------------------------*
    *                    Bussiness master                       *
    *----------------------------------------------------------*/
    address payable private _master;
    uint private _totalMembers;
    uint private _totalActiveMembers;

    /*----------------------------------------------------------*
    *                VERIFICATION PARAMETERS                    *
    *----------------------------------------------------------*/
    
    // Minimum deposit 
    uint private _minAmountToTransfer = 10000000000000000;  // Currently is a wei unit (0.01 Ether)
    
    // Refund percentage by rank
    uint private _refundTierOne = 5;
    uint private _refundTierTwo = 10;
    uint private _refundTierThree = 15;
    uint private _refundTierFour = 20;
    uint private _refundTierFive = 25;

    // Number of members enrolled to rise in rank
    // NOTE: qualify to improve rank
    // NOTE: This is a temporal value!!!!
    uint private _quialifyToImproveRank = 3;


    struct Member {
        address payable client;
        address[] enrolled;
        bool isActive;
        uint balance;
        uint refundPercentToMember;
        uint refundPercentToBussiness;
        Rank rank;
    }

    struct WithdrawTicket {
        address payable to;
        uint requestedAmount;
        uint requestDate;
        bool isPaid;
    }

    // Memebers within 3F contract
    mapping(address => Member) private members;
    // Member withdrawal requests
    mapping(address => WithdrawTicket[]) private whitdrawals;


    
    modifier onlyMaster() {
        require(msg.sender == _master, "Not the master user");
        _;
    }

    modifier onlyActiveMember(){
        require(members[msg.sender].isActive, "Member not active");
        _;
    }

    // modifier  checkIfNotRegistered() {
    //     require(!members[msg.sender].isRegistered, "Member already exists");
    //     _;
    // }

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

    // NOTE: Function to verify!!!!
    // modifier preventBankruptcy(uint _amount) {
    //     uint totalBalance = address(this).balance;
    //     uint precision = 100;
    //     uint maxQuantity = 75;
    //     require(
    //         (totalBalance * maxQuantity) / precision >= _amount, 
    //         "No more than 75% of the total contract balance may be withdrawn."
    //     );
    //     _;
    // }

    /*----------------------------------------------------------*
    *                      CONTRACT EVENTS                      *
    *----------------------------------------------------------*/

    event Deposit(address indexed from, uint amount);
    event Transfer(address indexed from, address indexed to, uint amount);
    event Withdraw(address indexed to, uint amount);
    event Refund(address indexed to, uint amount);
    
    event ActivateMember(address indexed member);
    event DesactivateMember(address indexed member);
    event NewMember(address indexed member);
    event NewRankReached(address indexed member, string rank);


    constructor() {
        console.log("Owner contract deployed by:", msg.sender);
        _master = payable(msg.sender);
        _totalMembers = 0;
        _totalActiveMembers = 0;
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
        _totalActiveMembers--;
        emit DesactivateMember(_client);
    }

    // function to reactivate member as well
    function activateMember(address _client) public onlyMaster {
        require(!members[_client].isActive, "Member is already active");
        members[_client].isActive = true;
        _totalActiveMembers++;
        emit ActivateMember(_client);

    }

    function withdraw(uint _amount)
        public
        onlyMaster
        checkValidAddress(_master)
        checkContractBalance(_amount)
    {
        (bool sent, ) = _master.call{ value: _amount }("");

        require(sent, "Withdraw not realized");

        // Emit event for withdraw funds
        emit Withdraw(_master, _amount);
    }

    // get the total number of contract members, regardless of whether they are active or not 
    function getTotalMembers() public view returns (uint) {
        return _totalMembers;
    }

    // Only get the total number of active members per contract
    function getTotalActiveMembers() public view returns (uint) {
        return _totalActiveMembers;
    }

    // Get the current master address
    function getMasterAddress() public view returns (address) {
        return _master;
    }

    // Return all member details
    function getMemberDetails(address _client)
        public
        view
        returns (
            address, 
            address[] memory,
            bool,
            bool,
            uint,
            Rank,
            UserType
        ) 
    {
        require(members[_client].isRegistered, "Member not registered");

        return (
            members[_client].client,
            members[_client].enrolled,
            members[_client].isActive,
            members[_client].isRegistered,
            members[_client].balance,
            members[_client].rank,
            members[_client].userType
        );
    }

    /*----------------------------------------------------------*
    *                 MEMBER PUBLIC FUNCTIONS                   *
    *----------------------------------------------------------*/

    // Only members deposit function
    function depositMemeberFunds() public payable {
        // Validations
        require(msg.value > 0, "You must send some balance.");

        // create a new member if it doesn't already exist
        createMember(payable(msg.sender));

        // Change member balance status
        members[msg.sender].balance += msg.value;

        // Emit event for deposit funds
        emit Deposit(msg.sender, msg.value);

        // Refund to client
        // _refundToClient(payable(msg.sender), msg.value);
    }

    // function withdrawMemberFounds(uint _amount)
    //     public 
    //     onlyActiveMember
    //     checkValidAddress(msg.sender)
    //     checkMemberBalance(_amount)
    //     checkContractBalance(_amount)
    // {
    //     // Transfer funds to personal wallet
    //     (bool sent, ) = payable(msg.sender).call{ value: _amount }("");
    //     require(sent, "Transfer failed");
        
    //     // Change member balance status
    //     members[msg.sender].balance -= _amount;

    //     // Emit withdraw event
    //     emit Withdraw(msg.sender, _amount);
    // }

    // This feature can only be used for the current depositor.
    // NOTE: to add a new referral to the upline
    // Lack validation for upline address
    function addReferralToUpline(address _uplineAddress)
        public
        onlyActiveMember
        checkValidAddress(_uplineAddress)
    {
        members[_uplineAddress].enrolled.push(msg.sender);
    }

    //Create a new member to contract
    // NOTE: Add verification for unregistered users, the last verification was erazed
    function createMember(address payable _client) public {
        // To assign new member to direction
        Member storage newMember = members[_client];

        // Validations
        // require(_master != _client, "You cannot create an account with the master address.");
        require(!members[_client].isActive, "Member already exists");

        // To initalize the new member
        newMember.client = _client;
        newMember.isActive = true;
        newMember.isRegistered = true;
        newMember.balance = 0;
        newMember.rank = Rank.Sapphire;
        newMember.userType = UserType.Client;

        // Increase members count
        _totalMembers++;
        _totalActiveMembers++;

        // Emit event for new member
        emit NewMember(_client);
    }

    // Return all member details
    function getCurrentMemberDetails()
        public
        view
        onlyActiveMember
        returns (
            address, 
            address[] memory,
            bool,
            bool,
            uint,
            Rank,
            UserType
        ) 
    {
        require(members[msg.sender].isRegistered, "Member not registered");

        return (
            members[msg.sender].client,
            members[msg.sender].enrolled,
            members[msg.sender].isActive,
            members[msg.sender].isRegistered,
            members[msg.sender].balance,
            members[msg.sender].rank,
            members[msg.sender].userType
        );
    }

    // NOTE: Only if nessesary
    // Get member struct
    // function getMemberDetails(address _client) public view returns (Member memory) {
    //     require(members[_client].isRegistered, "Member not registered");
    //     return members[_client];
    // }

    // Get current member struct
    // function getCurrentMemberDetails() public view onlyActiveMember returns (Member memory) {
    //     return members[msg.sender];
    // }

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

    function getMemberBalance() external view onlyActiveMember returns (uint) {
        // Get the current member balance
        return members[msg.sender].balance;
    }

    // NOTE: Comment this function for waiting functionality
    // function transferMemberToMember(address payable _to, uint _amount)
    //     external 
    //     onlyActiveMember
    //     checkValidAddress(_to)
    //     checkMemberBalance(_amount)
    // {
    //     // Validations
    //     require(members[_to].isActive, "Recipient isn't active user"); // Validate the recipient
    //     require(msg.sender != _master, "Master account can't be used to transfer by this way");

    //     // Change member balance status
    //     members[msg.sender].balance -= _amount;
    //     members[_to].balance += _amount;

    //     // Event after state changes
    //     emit Transfer(msg.sender, _to, _amount);
    // }

    /*----------------------------------------------------------*
    *                MASTER PRIVATE FUNCTIONS                   *
    *----------------------------------------------------------*/

        // Change member rank functions

    // Tier One
    function _setSapphireRank(address _memberAddress) private {
        members[_memberAddress].rank = Rank.Sapphire;
        members[_memberAddress].refundTier = _refundTierOne;
        emit NewRankReached(_memberAddress, "Sapphire");
    }

    // Tier Two
    function _setPearlRank(address _memberAddress) private {
        members[_memberAddress].rank = Rank.Pearl;
        members[_memberAddress].refundTier = _refundTierTwo;
        emit NewRankReached(_memberAddress, "Pearl");
    }

    // Tier Three
    function _setRubyRank(address _memberAddress) private {
        members[_memberAddress].rank = Rank.Ruby;
        members[_memberAddress].refundTier = _refundTierThree;
        emit NewRankReached(_memberAddress, "Ruby");
    }

    // Tier Four
    function _setEmeraldRank(address _memberAddress) private {
        members[_memberAddress].rank = Rank.Emerald;
        members[_memberAddress].refundTier = _refundTierFour;
        emit NewRankReached(_memberAddress, "Emerald");
    }

    // Tier Five
    function _setDiamondRank(address _memberAddress) private {
        members[_memberAddress].rank = Rank.Diamond;
        members[_memberAddress].refundTier = _refundTierFive;
        emit NewRankReached(_memberAddress, "Diamond");
    }

    function _getRefundAmount(uint _totalAmount, uint _refundPercent) private pure returns (uint) {
        return (_totalAmount * _refundPercent) / 100;
    }

    function _getMemberRefundPercent(address _memberAddress) private view returns (uint) {
        return members[_memberAddress].refundPercentToMember;
    }

    function _refundToClient(address payable _to, uint _totalAmount)
        private
        onlyActiveMember
        checkValidAddress(_to)
        checkContractBalance(_amount)
    {
        uint refundPercent = _getMemberRefundPercent(_to);
        uint refundAmount = _getRefundAmount(_totalAmount, refundPercent);
        assert(_totalAmount > refundAmount);


        // NOTE: Check the behavior of this condition, the client balance won't be affected
        // IMPORTANT! : not reflect changes in the client's balance sheet status
        (bool sent, ) = _to.call{ value: refundAmount }("");
        require(sent, "Refund failed");


        // Emit event for refound
        emit Refund(_to, refundAmount);
    }

    function updateRefundPercentage(address _memberAddress) private {
        uint totalEnrolledPerMember = member[_memberAddress].enrolled.length;
        require(totalEnrolledPerMember > 0, "No addresses enrolled for this member");
        uint qualificationRank = totalEnrolledPerMember / _qualifyToImproveRank;

        if (qualificationRank >= 5) {
            _setDiamondRank(_memberAddress);
        } else if (qualificationRank >= 4) {
            _setEmeraldRank(_memberAddress);
        } else if (qualificationRank >= 3) {
            _setRubyRank(_memberAddress);
        } else if (qualificationRank >= 2) {
            _setPearlRank(_memberAddress);
        }
    }

    /*----------------------------------------------------------*
    *                MEMBER PRIVATE FUNCTIONS                   *
    *----------------------------------------------------------*/

}