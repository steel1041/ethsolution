pragma solidity ^0.4.20;

import "./admin.sol";

/**
 * @author steel
 * @title SAR Token
 * @dev   
 */
contract SDUSDToken{
    function mint(address guy, uint wad) public returns(bool);
    function burn(address guy, uint wad) public returns(bool);
    function balanceOf(address src) public view returns (uint);
    function totalSupply() public view returns (uint);
    function transfer(address dst, uint wad) public returns(bool);
    function transferFrom(address src, address dst, uint wad) public returns(bool);
}

contract SETHToken{
    function totalSupply() public view returns (uint);
    function balanceOf(address src) public view returns (uint);
    function transfer(address dst, uint wad) public returns(bool);
    function transferFrom(address src, address dst, uint wad) public returns(bool);
}

contract OracleToken{
    function getConfig(string memory key) public view returns(uint value);
    function getPrice(string memory key) public view returns(uint128 value);
}

contract SARToken{
    function createSAR(address addr,uint256 locked,uint256 hasDrawed,uint256 bondLocked,
                        uint256 bondDrawed,uint256 lastHeight,uint256 fee) public returns(bool);
}

contract SAR is Admin{
    uint public constant POWNER_TEN = 10 ** 10;
    uint public constant TYPE_OPEN = 1;
    uint public constant TYPE_RESERVE = 2;
    uint public constant TYPE_WITHDRAW = 3;
    uint public constant TYPE_EXPANDE = 4;
    uint public constant TYPE_CONTR = 5;
    uint public constant TYPE_RESCUE = 6;
    uint public constant TYPE_RESCUE_T = 7;
    uint public constant TYPE_WITHDRAW_T = 8;
    uint public constant TYPE_CLOSE = 9;
    uint public constant TYPE_ONEKEY = 10;
    
    uint256 public bondGlobal;
    mapping (address => Sar)  public  sars;
    mapping (address => bool) public  sarStatus;     //sarExistStatus
    mapping (address => bool) public  bondStatus;
    //mapping (string => address) public accounts;
    
    address public feeAccount;
    address public newAccount;
    address public oldAccount;

    event Operated(address indexed from,uint opType,uint256 opValue);
    event Operatedfee(address indexed from,uint256 fee);
    
    SETHToken public seth;
    SDUSDToken  public  sdusd;
    OracleToken public oracle;
    SARToken public sar;
    
    struct Sar 
    {
        //SAR owner
        address owner;

        //amount of locked collateral
        uint256 locked;

        //amount of issued sdusd  
        uint256 hasDrawed;

        //amount of used bond
        uint256 bondLocked;

        //amount of sdusd liquidated by bond
        uint256 bondDrawed;

        //block 
        uint256 lastHeight;

        //amount of stable fee(sdusd)
        uint256 fee;
    }
    
    function SAR(
        SETHToken seth_,
        SDUSDToken  sdusd_,
        OracleToken oracle_
        ) public{
        seth = seth_;
        sdusd = sdusd_;
        oracle = oracle_;
    }
    

    function setFeeAccount(address _account) public onlyAdmin{
        require(_account != address(0));
        feeAccount = _account;
    }
    
    function setNewAccount(address _account) public onlyAdmin{
        require(_account != address(0));
        newAccount = _account;
    }
    
    function setOldAccount(address _account) public onlyAdmin{
        require(_account != address(0));
        oldAccount = _account;
    }
    
    function setSETH(SETHToken seth_) public onlyAdmin{
        require(seth_ != address(0));
        seth = seth_;
    }
    
    function setSDUSD(SDUSDToken sdusd_) public onlyAdmin{
        sdusd = sdusd_;
    }
    
    function setOracle(OracleToken oracle_) public onlyAdmin{
        require(oracle_ != address(0));
        oracle = oracle_;
    }
    
    function setSARToken(SARToken sar_) public onlyAdmin{
        require(sar_ != address(0));
        sar = sar_;
    }
    
    function sarOwner(address addr) public view returns (address) {
        return sars[addr].owner;
    }
    
    function locked(address addr) public view returns (uint256){
        return sars[addr].locked;
    }
    
    function hasDrawed(address addr) public view returns (uint256){
        return sars[addr].hasDrawed;
    }
    
    function bondLocked(address addr) public view returns (uint256){
        return sars[addr].bondLocked;
    }
    
    function bondDrawed(address addr) public view returns (uint256){
        return sars[addr].bondDrawed;
    }
    
    function lastHeight(address addr) public view returns (uint256){
        return sars[addr].lastHeight;
    }
    
    function fee(address addr) public view returns (uint256){
        return sars[addr].fee;
    }

    function era() public view returns (uint) {
        return block.timestamp;
    }
    
    function debtTop() public view returns(uint) {
        return oracle.getConfig("debt_top_c");
    }
    
    function liquidateLineRate() public view returns(uint){
        return oracle.getConfig("liquidate_line_rate_c");
    }
    
    function liquidateDisRate() public view returns(uint){
        return oracle.getConfig("liquidate_dis_rate_c");
    }
    
    function feeRate() public view returns(uint){
        return oracle.getConfig("fee_rate_c");
    }

    function liquidateTopRate() public view returns(uint){
        return oracle.getConfig("liquidate_top_rate_c");
    }
    
    function ethPrice() public view returns(uint){
        return oracle.getPrice("eth_price"); //150.23=>15023  
    }
    
    function setBond(address src,bool status) public onlyAdmin returns(bool){
        bondStatus[src] = status;
        return true;
    }
    
    //--SAR-operations--------------------------------------------------
    function open() public onlyOff returns (bool success) {
        require(!sarStatus[msg.sender]);    //Check status
        sars[msg.sender] = Sar(msg.sender,0,0,0,0,block.number,0);
        sarStatus[msg.sender] = true;
        Operated(msg.sender,TYPE_OPEN,0);
        return true;
    }
    
    /**An example of upgrade 'accept' method, the createSAR interface should been 
      * implemented in the following new SAR contract
      **/
    // function createSAR(address addr,uint256 locked,uint256 hasDrawed,uint256 bondLocked,
    //                     uint256 bondDrawed,uint256 lastHeight,uint256 fee) 
    //     public returns(bool success) {
        
    // }
    
    //Migrate SAR account to new contract by owner of SAR
    function migrateSAR() public onlyOff returns(bool success){
        require(sarStatus[msg.sender]);
         
        uint256 hasDrawedMount = hasDrawed(msg.sender);
        uint256 lockedMount = locked(msg.sender); 
        uint256 bondLockedMount = bondLocked(msg.sender);
        uint256 bondDrawedMount = bondDrawed(msg.sender);
        uint256 lastHeightNumer = lastHeight(msg.sender);
        uint256 feeMount = fee(msg.sender);
        
        //transfer seth to new sar
        require(newAccount!= address(0));
        
        if(lockedMount>0){
            require(sdusd.transfer(newAccount,lockedMount));
        }
        
        require(sar.createSAR(msg.sender,lockedMount,hasDrawedMount,bondLockedMount,
                bondDrawedMount,lastHeightNumer,feeMount));
        return true;
    }
    
    
    function reserve(uint256 mount) public onlyOff returns (bool success){
        require(mount>0);
        require(sarStatus[msg.sender]);    //Check status
        require(msg.sender == sarOwner(msg.sender));
        require(seth.transferFrom(msg.sender,this,mount));
        
        sars[msg.sender].locked = add(locked(msg.sender), mount);
        Operated(msg.sender,TYPE_RESERVE,mount);
        return true;
    }
    
    function withdraw(uint256 mount) public onlyOff  returns (bool success){
        require(mount>0);
        require(sarStatus[msg.sender]);   
        require(msg.sender == sarOwner(msg.sender));
        
        uint256 hasDrawedMount = hasDrawed(msg.sender);
        uint256 lockedMount = locked(msg.sender); 
        
        require(lockedMount >= mount);
        require(mul(sub(lockedMount,mount),ethPrice()) >= mul(hasDrawedMount,liquidateLineRate()));
        
        require(seth.transfer(msg.sender,mount));
        sars[msg.sender].locked = sub(sars[msg.sender].locked, mount);
         Operated(msg.sender,TYPE_WITHDRAW,mount);
        return true;
    }

    function expande(uint256 mount) public onlyOff returns (bool success){
        require(mount>0);
        require(sarStatus[msg.sender]);
        require(msg.sender == sarOwner(msg.sender));
        
        uint256 hasDrawedMount = hasDrawed(msg.sender);
        require(debtTop() >= add(hasDrawedMount, mount));
        
        uint256 lockedMount = locked(msg.sender);
        uint256 maxMount = mul(lockedMount,mul(ethPrice(),100));
        uint256 checkMount = mul(add(hasDrawedMount, mount),liquidateLineRate());
        require(maxMount >= checkMount);
        
        sars[msg.sender].hasDrawed = add(hasDrawedMount, mount);
        sdusd.mint(msg.sender, mount);
        
        uint lastHeightNumer = block.number;
        if(hasDrawedMount == 0){
            sars[msg.sender].lastHeight = lastHeightNumer;
            sars[msg.sender].fee = 0;
        }else{
            uint256 currFee = div(mul(mul(sub(lastHeightNumer,lastHeight(msg.sender)),hasDrawedMount),feeRate()),POWNER_TEN);
            sars[msg.sender].lastHeight = lastHeightNumer;
            sars[msg.sender].fee = add(currFee,fee(msg.sender));
        }
         Operated(msg.sender,TYPE_EXPANDE,mount);
        return true;
    }
    
    function contr(uint256 mount) public onlyOff returns (bool success){
        require(mount > 0);
        require(sarStatus[msg.sender]);
        require(msg.sender == sarOwner(msg.sender));
        
        uint256 hasDrawedMount = hasDrawed(msg.sender);
        require(hasDrawedMount >= mount);
        
        uint lastHeightNumer = block.number;
        //手续费外扣 
        uint256 currFee = div(mul(mul(sub(lastHeightNumer,lastHeight(msg.sender)),hasDrawedMount),feeRate()),POWNER_TEN);
        uint256 needUSDFee = div(mul(add(currFee,fee(msg.sender)),mount),hasDrawedMount);

        require(sdusd.balanceOf(msg.sender) >= add(mount,needUSDFee));
        if(feeAccount == address(0)){
            feeAccount = owner;
        }
        require(sdusd.transferFrom(msg.sender,feeAccount,needUSDFee));
        require(sdusd.burn(msg.sender,mount));
        
        sars[msg.sender].lastHeight = lastHeightNumer;
        sars[msg.sender].fee = sub(add(currFee,fee(msg.sender)),needUSDFee);
        sars[msg.sender].hasDrawed = sub(hasDrawedMount, mount);
        
        Operated(msg.sender,TYPE_CONTR,mount);
        Operatedfee(msg.sender,needUSDFee);
        return true;
    }
    
    function rescue(address dest,uint256 mount) public onlyOff returns (bool success){
        require(mount > 0);
        require(sarStatus[msg.sender]);
        require(sarStatus[dest]);
        uint256 hasDrawedMount = hasDrawed(dest);
        uint256 lockedMount = locked(dest); 
        
        uint currentRate = mul(lockedMount,ethPrice())/hasDrawedMount;
        
        uint rateClear = getRateClear(currentRate,liquidateDisRate());
        
        require(mul(lockedMount,ethPrice()) <= mul(hasDrawedMount,liquidateLineRate()));
        
        uint256 canClear = 0;
        if(currentRate>100 && currentRate<liquidateLineRate()){
             canClear = div(mul(mount,10000),mul(ethPrice(),rateClear));
             
             require(canClear > 0);
             require(canClear < lockedMount);
             require(mount < hasDrawedMount);
             require(mul(sub(hasDrawedMount,mount),liquidateTopRate()) >= mul(sub(lockedMount,canClear),ethPrice()));
        }
        if(currentRate <= 100){
            require(hasDrawedMount == mount);
            canClear = lockedMount;
        }
        require(sdusd.burn(msg.sender,mount));
        
        sars[dest].locked = sub(lockedMount,canClear);
        sars[dest].hasDrawed = sub(hasDrawedMount,mount);
        sars[msg.sender].locked = add(sars[msg.sender].locked,canClear);
        
        Operated(msg.sender,TYPE_RESCUE,mount);
        return true;
    }
    
    function getRateClear(uint currentRate,uint rateClear) internal pure returns(uint){
        uint ret = rateClear;
        if (currentRate > 0 && rateClear > 0)
        {
            uint result = div(1000000,currentRate);
            if (result > mul(rateClear,100))
            {
                ret = div(add(result,100),100);
            }
        }
        require(ret >= rateClear);
        return ret;
    }
    
    function rescueT(uint256 bondMount) public onlyOff returns (bool success){
        require(bondMount > 0);
        require(sarStatus[msg.sender]);
        require(bondStatus[msg.sender]);
        
        uint256 hasDrawedMount = hasDrawed(msg.sender);
        uint256 lockedMount = locked(msg.sender); 
        
        require(hasDrawedMount > 0);
        require(hasDrawedMount >= bondMount);
        
        uint currentRate = mul(lockedMount,ethPrice())/mul(hasDrawedMount,100);
        require(currentRate < liquidateLineRate());
        
        uint256 canClear = div(bondMount,ethPrice());
        
        if(currentRate > 100 && currentRate < liquidateLineRate()){
            uint lastRate = div(mul(sub(lockedMount,canClear),ethPrice()),sub(hasDrawedMount,bondMount));
            require(lastRate < liquidateTopRate());
        }
        
        if(canClear>=lockedMount){
            canClear = lockedMount;
        }else{
             sars[msg.sender].locked = sub(lockedMount,canClear);
        }
        
        sars[msg.sender].locked = sub(lockedMount,canClear);
        sars[msg.sender].hasDrawed = sub(hasDrawedMount,bondMount);
        
        sars[msg.sender].bondLocked = add(sars[msg.sender].bondLocked,canClear);
        sars[msg.sender].bondDrawed = add(sars[msg.sender].bondDrawed,bondMount);
        bondGlobal = add(bondGlobal,bondMount);
        Operated(msg.sender,TYPE_RESCUE_T,bondMount);
        return true;
    }
    
    function withdrawT(uint256 mount) public onlyOff returns (bool success){
        require(mount > 0);
        require(sarStatus[msg.sender]);
        require(bondStatus[msg.sender]);
        require(msg.sender == sarOwner(msg.sender));
        
        uint256 lockedMount = locked(msg.sender); 
        uint256 bondDrawedMount = bondDrawed(msg.sender);
        uint256 bondLockedMount = bondLocked(msg.sender);
        
        require(bondLockedMount > 0);
        require(bondDrawedMount > 0);
        require(bondDrawedMount >= mount);
        
        sdusd.burn(msg.sender,mount);
        
        uint256 can = div(mul(bondLockedMount,mount),bondDrawedMount);

        sars[msg.sender].locked = add(lockedMount, can);
        sars[msg.sender].bondLocked = sub(bondLockedMount,can);
        sars[msg.sender].bondDrawed = sub(bondDrawedMount,mount);
        
        bondGlobal = sub(bondGlobal,mount);
        require(bondGlobal >= 0);
        Operated(msg.sender,TYPE_WITHDRAW_T,mount);
        return true;
    }


    function close() public onlyOff returns (bool success){
        require(sarStatus[msg.sender]);
        require(msg.sender == sarOwner(msg.sender));
        require(locked(msg.sender)==0);
        require(hasDrawed(msg.sender)==0);
        require(fee(msg.sender)==0);
        require(bondLocked(msg.sender)==0);
        require(bondDrawed(msg.sender)==0);
        
        sars[msg.sender].lastHeight=0;
        sarStatus[msg.sender] = false;
        Operated(msg.sender,TYPE_CLOSE,0);
        return true;
    }
    
    function onekey(uint256 reserveMount,uint256 expandeMount) public onlyOff returns(bool success){
        require(reserveMount>0);
        require(expandeMount>0);
        
        if(!sarStatus[msg.sender]){
            sars[msg.sender] = Sar(msg.sender,0,0,0,0,block.number,0);
            sarStatus[msg.sender] = true;
            Operated(msg.sender,1,0);
        }

        //require(msg.sender == owner(msg.sender));
        require(seth.transferFrom(msg.sender,this,reserveMount));
        sars[msg.sender].locked = add(sars[msg.sender].locked, reserveMount);
        //Operated(msg.sender,2,reserveMount);
        
        uint256 hasDrawedMount = hasDrawed(msg.sender);
        require(debtTop() >= add(hasDrawedMount, expandeMount));
        
        uint256 lockedMount = locked(msg.sender);
        uint256 maxMount = mul(lockedMount,mul(ethPrice(),100));
        uint256 checkMount = mul(add(hasDrawedMount, expandeMount),liquidateLineRate());
        require(maxMount >= checkMount);
        
        sars[msg.sender].hasDrawed = add(hasDrawedMount, expandeMount);
        require(sdusd.mint(msg.sender, expandeMount));
        
        uint lastHeightNumer = block.number;
        if(hasDrawedMount == 0){
            sars[msg.sender].lastHeight = lastHeightNumer;
            sars[msg.sender].fee = 0;
        }else{
            uint256 currFee = div(mul(mul(sub(lastHeightNumer,lastHeight(msg.sender)),hasDrawedMount),feeRate()),POWNER_TEN);
            sars[msg.sender].lastHeight = lastHeightNumer;
            sars[msg.sender].fee = add(currFee,fee(msg.sender));
        }
        Operated(msg.sender,TYPE_ONEKEY,expandeMount);
        return true;
    }
    

    
}