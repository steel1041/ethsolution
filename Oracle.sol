pragma solidity ^0.4.16;

contract owned {
    address public owner;

    function owned() {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    // 实现所有权转移
    function transferOwnership(address newOwner) onlyOwner {
        owner = newOwner;
    }
}

contract Oracle is owned{
    string constant configKey = "configKey";
    string constant priceKey = "priceKey";
    Config public config;
    mapping (string => uint)  configMapping;   //config
    mapping (string => uint128)  priceMapping;     //prices
    mapping (address => bool)  public auths;  //auths
  
    event OracleOperated(address indexed from,string opType,uint256 opValue);
    
    //Oracle config 
    struct Config
    {
        uint liquidate_line_rate_c;
        
        uint liquidate_dis_rate_c;
        
        uint fee_rate_c;
        
        uint liquidate_top_rate_c;
        
        uint liquidate_line_rateT_c;
        
        uint issuing_fee_c;
        
        uint debt_top_c;
    }
    
    function Oracle(address admin) public {
        if(admin != 0 ) owner = admin;
        auths[admin] = true;
    }
    
    function flush() public onlyOwner{
        config = Config(getConfig("liquidate_line_rate_c"),
        getConfig("liquidate_dis_rate_c"),
        getConfig("fee_rate_c"),
        getConfig("liquidate_top_rate_c"),
        getConfig("liquidate_line_rateT_c"),
        getConfig("issuing_fee_c"),
        getConfig("debt_top_c"));
    }
    
    function setAuth(address addr) public onlyOwner returns(bool success){
        auths[addr] = true;
        return true;
    }
    
    function releaseAuth(address addr) public onlyOwner returns(bool success){
        auths[addr] = false;
        return true;
    }
    
    function setConfig(string key,uint set) public returns(bool success){
        require(auths[msg.sender]);
        configMapping[key] = set;
        OracleOperated(msg.sender,key,set);
        return true;
    }
    
    function getConfig(string key) public view returns(uint value){
        return configMapping[key];
    }
    
    function setPrice(string key,uint128 set) public returns(bool success){
        require(auths[msg.sender]);
        priceMapping[key]=set;
        OracleOperated(msg.sender,key,set);
        return true;
    }
    
     function getPrice(string key) public view returns(uint128 value){
        return priceMapping[key];
    }
}