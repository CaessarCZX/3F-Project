// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

contract FFFBusiness {
    address payable private _businessWallet;
    uint128 private _totalMembers;
    uint128 private _totalActiveMembers;

    uint128 private _minAmountToTransfer = 10000000000000000;  // Currently is a wei unit (0.01 Ether)
    uint8 constant private MAX_TICKETS = 8;
    
    uint8 private _refundTierOne = 5;
    uint8 private _refundTierTwo = 10;
    uint8 private _refundTierThree = 15;
    uint8 private _refundTierFour = 20;
    uint8 private _refundTierFive = 25;

    uint8 private _quialifyToImproveRank = 3;

    enum Ranks {
        Sapphire,   // 0
        Pearl,      // 1
        Ruby,       // 2
        Emerald,    // 3
        Diamond     // 4
    }

    struct Member {
        address payable _memberWallet;
        address[] enrolled;
        bool isActive;
        bool isRegistered;
        uint balance;
        uint8 refundPercentToMember;
        uint8 refundPercentToBussiness;
        Rank rank;
    }

    struct WithdrawTicket {
        address payable to;
        uint128 requestedAmount;
        uint32 requestDate;
        bool isPaid;
    }

    mapping(address => Member) private members;
    mapping(address => WithdrawTicket[]) private whitdrawals;

    modifier onlyBusiness() {
        require(msg.sender == _businessWallet, "Error: Not the business");
        _;
    }

    modifier onlyActiveMember() {
        require(members[msg.sender].isActive, "Member not active");
        _;
    }

    modifier onlyActiveMember(Member _currentMember){
        require(_currentMember.isActive, "Member not active");
        _;
    }

    modifier onlyActiveMember(address _currentMember){
        require(members[_currentMember].isActive, "Member not active");
        _;
    }

    modifier onlyFirstDeposit(Member _currentMember){
        require(_currentMember);
        _;
    }

    modifier checkMemberBalance(Member _currentMember, uint _amount) {
        require(_currentMember.balance >= _amount, "Insufficient balance");
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

    modifier checkMinimumAmount() {
        require(msg.value >= _minAmountToTransfer, "Minimum amount is 0.01 Ethers");
        _;
    }

    modifier preventZeroAmount(uint _currentAmount) {
        require(_currentAmount > 0, "The amount must be greater than zero");
        _;
    }

    event Deposit(address indexed from, uint amount);
    event Transfer(address indexed from, address indexed to, uint amount);
    event Withdraw(address indexed to, uint amount);
    event Refund(address indexed to, uint amount);
    
    event BusinessWalletSet(address indexed oldBusinessWallet, address indexed newBusinessWallet);
    event ActivateMember(address indexed member);
    event DesactivateMember(address indexed member);
    event NewMember(address indexed member);
    event NewRankReached(address indexed member, string rank);

    constructor() {
        // console.log("Owner contract deployed by:", msg.sender);
        _businessWallet = payable(msg.sender);
        _totalMembers = 0;
        _totalActiveMembers = 0;
        emit BusinessWalletSet(address(0), _businessWallet);
    }

    function deposit() public payable {}

    function deactivateMember(address _memberAddress) public onlyBusiness onlyActiveMember(_memberAddress) {
        members[_memberAddress].isActive = false;
        _totalActiveMembers--;
        emit DesactivateMember(_memberAddress);
    }

    // function to reactivate member as well
    function activateMember(address _memberAddress) public onlyBusiness {
        require(!members[_memberAddress].isActive, "Member is already active");
        members[_memberAddress].isActive = true;
        _totalActiveMembers++;
        emit ActivateMember(_memberAddress);

    }

    function getTotalMembers() public view returns (uint) {
        return _totalMembers;
    }

    function getTotalActiveMembers() public view returns (uint) {
        return _totalActiveMembers;
    }

    function getBusinessWallet() public view returns (address) {
        return _businessWallet;
    }

    function changeBusinessWallet(address _newBusinessWallet) public onlyBusiness {
        emit BusinessWalletSet(_businessWallet, _newBusinessWallet);
        _businessWallet = payable(_newBusinessWallet);
    }

    function getMemberDetails(Member member)
        public
        view
        returns (
            address, 
            address[] memory,
            bool,
            bool,
            uint,
            uint8,
            uint8,
            Rank
        ) 
    {
        require(member.isRegistered, "Member not registered");

        return (
            member.client,
            member.enrolled,
            member.isActive,
            member.isRegistered,
            member.balance,
            member.refundPercentToMember;
            member.refundPercentToBussiness;
            member.rank
        );
    }

    function getMemberDetails(address _memberAddress)
        public
        view
        returns (
            address, 
            address[] memory,
            bool,
            bool,
            uint,
            uint8,
            uint8,
            Rank
        ) 
    {
        Member memory member = members[_memberAddress];
        require(member.isRegistered, "Member not registered");

        return (
            member.client,
            member.enrolled,
            member.isActive,
            member.isRegistered,
            member.balance,
            member.refundPercentToMember;
            member.refundPercentToBussiness;
            member.rank
        );
    }

    function createMember(address payable _newMember) public {
        // require(!members[_client].isRegistered, "Member already exists");
        
        Member storage newMember = members[_newMember];
        newMember.client = _newMember;
        newMember.isActive = true;
        newMember.isRegistered = true;
        newMember.balance = 0;
        newMember.refundPercentToMember = _refundTierOne;
        newMember.refundPercentToBussiness = 100 - _refundTierOne;
        newMember.rank = Rank.Sapphire;

        _totalMembers++;
        _totalActiveMembers++;

        emit NewMember(_client);
    }

    function addReferralToUpline(address _to, address _from)
        public
        onlyActiveMember(_to)
        checkValidAddress(_to)
    {
        members[_to].enrolled.push(_from);
    }

    function depositMemeberFunds(address _uplineAddress) public payable checkMinimumAmount{

        if (!members[msg.sender].isRegistered) {
            createMember(payable(msg.sender));
            addReferralToUpline(_uplineAddress, msg.sender);
        }

        members[msg.sender].balance += msg.value;
        emit Deposit(msg.sender, msg.value);

        Member memory member = members[msg.sender];
        uint refundToMember = _getRefundAmount(msg.value, member.refundPercentToMember);
        uint refundToBussines = msg.value - refundToMember;
        require(refundToBusiness >= refundToMember, "Failed transaction");

        _payment(_businessWallet, refundToBusiness);
        _payment(msg.sender, refundToMember);
        emit Refund(msg.sender, refundToMember);
    }

    function withdrawalRequest(uint _requestedAmount)
        public
        onlyActiveMember(msg.sender)
        preventZeroAmount(_requestedAmount) 
    {
        require();
    }

    function payToMember(address _memberAddress, uint _amount)
        public
        onlyBusiness
        preventZeroAmount(_amount)
    {
        
    }

    function _payment(address payable _to, uint _amount)
        private
        preventZeroAmount(_amount)
    {
        (bool sent, ) = _to.call{ value: _amount }("");
        require(sent, "Failed transaction");
    }

    function _getRefundAmount(uint _totalAmount, uint _refundPercent) private pure returns (uint) {
        return (_totalAmount * _refundPercent) / 100;
    }

}