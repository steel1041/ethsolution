pragma solidity ^0.4.20;

contract Admin {
    address public owner;
    bool public off;
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
        require(off);
        _;
    }
    
    // 实现所有权转移
    function transferAdmin(address _owner) public onlyAdmin {
        owner = _owner;
    }
    
    //设置开关 
    function setOffStatus(bool status) onlyAdmin public{
        off = status;
    }
    
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }


    function wdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, WAD), y / 2) / y;
    }
    
    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x);
    }
}