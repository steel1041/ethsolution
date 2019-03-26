pragma solidity ^0.5.2;

import "./admin.sol";

contract SETH is Admin {
    string public name     = "S Ether";
    string public symbol   = "SETH";
    uint256  public  decimals = 18;

    uint256                                            _supply;
    mapping (address => uint256)                       _balances;
    mapping (address => mapping (address => uint256))  _approvals;

    event Approval(address indexed src, address indexed guy, uint wad);
    event Transfer(address indexed src, address indexed dst, uint wad);
    event Deposit(address indexed dst, uint wad);
    event Withdrawal(address indexed src, uint wad);
    
    constructor() public payable {
        _balances[msg.sender] += msg.value;
        _supply = add(_supply, msg.value);
        emit Deposit(msg.sender, msg.value);
    }
    
    function withdraw(uint wad) public {
        require(_balances[msg.sender] >= wad);
        _balances[msg.sender] -= wad;
        msg.sender.transfer(wad);
        _supply = sub(_supply, wad);
        emit Withdrawal(msg.sender, wad);
    }

    function transferFrom(address src, address dst, uint wad)
        public
        returns (bool)
    {
        if (src != msg.sender && _approvals[src][msg.sender] != uint(-1)) {
            _approvals[src][msg.sender] = sub(_approvals[src][msg.sender], wad);
        }

        _balances[src] = sub(_balances[src], wad);
        _balances[dst] = add(_balances[dst], wad);

        emit Transfer(src, dst, wad);
        return true;
    }
    
     function totalSupply() public view returns (uint) {
        return _supply;
    }
    function balanceOf(address src) public view returns (uint) {
        return _balances[src];
    }
    function allowance(address src, address guy) public view returns (uint) {
        return _approvals[src][guy];
    }

    function transfer(address dst, uint wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function approve(address guy, uint wad) public returns (bool) {
        _approvals[msg.sender][guy] = wad;

        emit Approval(msg.sender, guy, wad);
        return true;
    }
    

}