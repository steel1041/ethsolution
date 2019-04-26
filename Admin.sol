pragma solidity ^0.4.20;

contract Admin {
    address public owner;
    bool public sarOff;
    bool public sdusdOff;
    uint constant WAD = 10 ** 18;
    uint constant RAY = 10 ** 27;
    
    function Admin() public{
        owner = msg.sender;
    }

    modifier onlyAdmin {
        require(msg.sender == owner);
        _;
    }
    
    modifier onlyOff {
        require(sarOff);
        _;
    }
    
    modifier onlySdusdOff {
        require(sdusdOff);
        _;
    }
    
    // 实现所有权转移
    function transferAdmin(address _owner) public onlyAdmin {
        require(_owner != address(0));
        owner = _owner;
    }
    
    //设置开关 
    function setSarOff(bool status) onlyAdmin public{
        sarOff = status;
    }
    
    //设置开关 
    function setSdusdOff(bool _status) onlyAdmin public{
        sdusdOff = _status;
    }
    
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x);
    }

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
            require(b > 0);
            uint256 c = a / b;
            return c;
    }

    function wdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = add(mul(x, WAD), y / 2) / y;
    }
    
    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x);
    }
}