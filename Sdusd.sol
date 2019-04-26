pragma solidity ^0.4.20;

import "./admin.sol";

contract SDUSD is Admin{
    uint256 public                                           _supply;
    mapping (address => uint256) public                      _balances;
    mapping (address => mapping (address => uint256)) public _approvals;
    
    string public name     = "Standard USD";
    string public symbol   = "SDUSD";
    uint256  public  decimals = 18;
    address public sar;

    event Mint(address indexed guy, uint wad);
    event Burn(address indexed guy, uint wad);
    event Approval(address indexed src, address indexed guy, uint wad);
    event Transfer(address indexed src, address indexed dst, uint wad);
    
    function SDUSD () public {
        _balances[msg.sender] = 0;
        _supply = 0;
        
    }
    
    function setSar(address _sar) public onlyAdmin{
        sar = _sar;
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
        require(wad>0);
        return transferFrom(msg.sender, dst, wad);
    }

    function approve(address guy, uint wad) public returns (bool) {
        require(wad>=0);
        _approvals[msg.sender][guy] = wad;

        Approval(msg.sender, guy, wad);
        return true;
    }
    
    function transferFrom(address src, address dst, uint wad)
        public
        returns (bool)
    {
        require(wad>=0);
        if (src != msg.sender && _approvals[src][msg.sender] != uint(-1)) {
            _approvals[src][msg.sender] = sub(_approvals[src][msg.sender], wad);
        }
        _balances[src] = sub(_balances[src], wad);
        _balances[dst] = add(_balances[dst], wad);

        Transfer(src, dst, wad);
        return true;
    }
    
    function mint(address guy, uint wad) public onlySdusdOff returns (bool){
        //check auth from contract or sender
        require(wad>0);
        require(sar!=address(0));
        require(msg.sender==sar);
        _balances[guy] = add(_balances[guy], wad);
        _supply = add(_supply, wad);
        Mint(guy, wad);
        return true;
    }
    
    function burn(address guy, uint wad) public onlySdusdOff returns (bool){
        //check auth from contract or sender
        require(wad>0);
        require(sar!=address(0));
        require(msg.sender==sar);
        _balances[guy] = sub(_balances[guy], wad);
        _supply = sub(_supply, wad);
        Burn(guy, wad);
        return true;
    }
    
}