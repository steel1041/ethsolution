pragma solidity ^0.4.20;

import "./admin.sol";

contract Oracle is Admin{
  
    string constant public configKey = "configKey";
    string constant public priceKey = "priceKey";
    string constant public ethKey = "eth_price";
    Config public config;
    
    mapping (string => uint)  configMapping;   //config
    mapping (string => uint128)  priceMapping;     //prices
    mapping (address => bool)  public auths;  //auths
  
    mapping (uint96 => uint128) public values;
    mapping (address => uint96) public indexes;
    uint96 public next = 0x0;

    uint96 public min = 0x1;
    
    event OracleOperated(address indexed from,string opType,uint256 opValue);
    event AuthOperated(address indexed from,address indexed to,string opType);
    
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
    
    function Oracle () public {
    }
    
    function set(address addr,uint128 price) public {
        require(auths[msg.sender]);
        require(msg.sender==addr);
        require(price>0);
        
        uint96 nextId = indexes[addr];
        if(nextId == 0x0){
            nextId = uint96(uint96(next) + 1);
        }
        indexes[addr] = nextId;
        values[nextId] = price;
        next = nextId;
        
        //计算后进行赋值 
        uint128 ret = compute();
        if(ret>0){
            priceMapping[ethKey] = ret;
            OracleOperated(msg.sender,ethKey,ret);
        }
    }

    
    function setMin(uint96 min_) public onlyAdmin {
        require(min_ != 0x0);
        min = min_;
    }
    
    function flush() public onlyAdmin{
        config = Config(getConfig("liquidate_line_rate_c"),
        getConfig("liquidate_dis_rate_c"),
        getConfig("fee_rate_c"),
        getConfig("liquidate_top_rate_c"),
        getConfig("liquidate_line_rateT_c"),
        getConfig("issuing_fee_c"),
        getConfig("debt_top_c"));
    }
    
    function setAuth(address addr) public onlyAdmin returns(bool success){
        auths[addr] = true;
        AuthOperated(msg.sender,addr,"set");
        return true;
    }
    
    function releaseAuth(address addr) public onlyAdmin returns(bool success){
        auths[addr] = false;
        AuthOperated(msg.sender,addr,"unset");
        return true;
    }
    
    function setConfig(string memory key,uint128 value) public returns(bool success){
        require(auths[msg.sender]);
        configMapping[key] = value;
        OracleOperated(msg.sender,key,value);
        return true;
    }
    
    function getConfig(string memory key) public view returns(uint value){
        return configMapping[key];
    }
    
    function setPrice(string memory key,uint128 value) public returns(bool success){
        require(auths[msg.sender]);
        priceMapping[key]=value;
        OracleOperated(msg.sender,key,value);
        return true;
    }
    
    function getPrice(string memory key) public view returns(uint128 value){
        return priceMapping[key];
    }
    
    function compute() public view returns (uint128 ret) {
        uint128[] memory wuts = new uint128[](uint96(next));
        uint96 ctr = 0;
        for (uint96 i = 1; i < uint96(uint96(next)+1); i++) {
            if (values[uint96(i)] != 0) {
                    uint128 wut = values[uint96(i)];
                    if (ctr == 0 || wut >= wuts[ctr - 1]) {
                        wuts[ctr] = wut;
                    } else {
                        uint96 j = 0;
                        while (wut >= wuts[j]) {
                            j++;
                        }
                        for (uint96 k = ctr; k > j; k--) {
                            wuts[k] = wuts[k - 1];
                        }
                        wuts[j] = wut;
                    }
                    ctr++;
                
            }
        }

        if (ctr < min) {
            return 0;
        }

        uint128 value;
        if (ctr % 2 == 0) {
            uint128 val1 = uint128(wuts[(ctr / 2) - 1]);
            uint128 val2 = uint128(wuts[ctr / 2]);
            value = uint128(wdiv(add(val1, val2), 2 ether));
        } else {
            value = wuts[(ctr - 1) / 2];
        }
        return value;
    }

}