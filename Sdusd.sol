pragma solidity ^0.4.16;

contract Admin {
    address public admin;

    modifier onlyAdmin {
        require(msg.sender == admin);
        _;
    }
}

contract SDUSD is Admin{
    uint256                                            _supply;
    mapping (address => uint256)                       _balances;
    mapping (address => mapping (address => uint256))  _approvals;
    
    string public name     = "Standard USD";
    string public symbol   = "SDUSD";
    uint256  public  decimals = 18;

    mapping (address => bool) public  auths;

    event Mint(address indexed guy, uint wad);
    event Burn(address indexed guy, uint wad);
    event Approval(address indexed src, address indexed guy, uint wad);
    event Transfer(address indexed src, address indexed dst, uint wad);
    
    
    function SDUSD() public {
        admin = msg.sender;
        _balances[msg.sender] = 0;
        _supply = 0;
        
    }
    
    
    // 实现所有权转移
    function transferOwnership(address newAdmin) onlyAdmin {
        admin = newAdmin;
    }
    
    function setAuth(address addr,bool result) onlyAdmin{
        auths[addr] = result;
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

        Approval(msg.sender, guy, wad);
        return true;
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

        Transfer(src, dst, wad);
        return true;
    }
    
    function mint(address guy, uint wad) public  {
        //check auth from contract or sender
        require(auths[msg.sender]);
        _balances[guy] = add(_balances[guy], wad);
        _supply = add(_supply, wad);
        Mint(guy, wad);
    }
    
    function burn(address guy, uint wad) public   {
        //check auth from contract or sender
        require(auths[msg.sender]);
        _balances[guy] = sub(_balances[guy], wad);
        _supply = sub(_supply, wad);
        Burn(guy, wad);
    }
    
    function add(uint x, uint y) internal  returns (uint z) {
        require((z = x + y) >= x);
    }
    
    function sub(uint x, uint y) internal  returns (uint z) {
        require((z = x - y) <= x);
    }
}