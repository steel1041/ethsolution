pragma solidity ^0.4.16;

contract DSMath {
    function add(uint x, uint y) internal  returns (uint z) {
        require((z = x + y) >= x);
    }
    function sub(uint x, uint y) internal  returns (uint z) {
        require((z = x - y) <= x);
    }
    function mul(uint x, uint y) internal  returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    function min(uint x, uint y) internal  returns (uint z) {
        return x <= y ? x : y;
    }
    function max(uint x, uint y) internal  returns (uint z) {
        return x >= y ? x : y;
    }
    function imin(int x, int y) internal  returns (int z) {
        return x <= y ? x : y;
    }
    function imax(int x, int y) internal  returns (int z) {
        return x >= y ? x : y;
    }

    uint constant WAD = 10 ** 18;
    uint constant RAY = 10 ** 27;

    function wmul(uint x, uint y) internal  returns (uint z) {
        z = add(mul(x, y), WAD / 2) / WAD;
    }
    function rmul(uint x, uint y) internal  returns (uint z) {
        z = add(mul(x, y), RAY / 2) / RAY;
    }
    function wdiv(uint x, uint y) internal  returns (uint z) {
        z = add(mul(x, WAD), y / 2) / y;
    }
    function rdiv(uint x, uint y) internal  returns (uint z) {
        z = add(mul(x, RAY), y / 2) / y;
    }

    // This famous algorithm is called "exponentiation by squaring"
    // and calculates x^n with x as fixed-point and n as regular unsigned.
    //
    // It's O(log n), instead of O(n) for naive repeated multiplication.
    //
    // These facts are why it works:
    //
    //  If n is even, then x^n = (x^2)^(n/2).
    //  If n is odd,  then x^n = x * x^(n-1),
    //   and applying the equation for even x gives
    //    x^n = x * (x^2)^((n-1) / 2).
    //
    //  Also, EVM division is flooring and
    //    floor[(n-1) / 2] = floor[n / 2].
    //
    function rpow(uint x, uint n) internal  returns (uint z) {
        z = n % 2 != 0 ? x : RAY;

        for (n /= 2; n != 0; n /= 2) {
            x = rmul(x, x);

            if (n % 2 != 0) {
                z = rmul(z, x);
            }
        }
    }
}

contract AdminCon {
    address public admin;

    bool public off;
    function owned() {
        admin = msg.sender;
    }

    modifier onlyAdmin {
        require(msg.sender == admin);
        _;
    }
    
    modifier onlyOff {
        require(off);
        _;
    }

    // 实现所有权转移
    function transferOwnership(address newAdmin) onlyAdmin {
        admin = newAdmin;
    }
    
    function setOffStatus(bool status) onlyAdmin{
        off = status;
    }
}

contract SDUSDToken{
    function mint(address guy, uint wad) public;
    function burn(address guy, uint wad) public;
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

contract Oracle{
     function getConfig(string key) public view returns(uint value);
     function getPrice(string key) public view returns(uint128 value);
}

contract SarTub is DSMath,AdminCon{

    uint constant POWNER_TEN = 10 ** 10;
    uint256 public bondGlobal;
    mapping (address => Sar)  public  sars;
    mapping (address => bool) public  sarStatus;     //sarExistStatus
    mapping (address => bool) public  bondStatus;
    
    event Operated(address indexed from,uint opType,uint256 opValue);

    SETHToken public seth;
    SDUSDToken  public  sdusd;
    Oracle public oracle;
    
    
    function SarTub(SETHToken seth_,SDUSDToken  sdusd_,Oracle oracle_) public{
        seth = seth_;
        sdusd = sdusd_;
        oracle = oracle_;
    }
    
    function owner(address addr) public view returns (address) {
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
    
    function fee(address addr) public view returns (uint){
        return sars[addr].fee;
    }

    function era() public constant returns (uint) {
        return block.timestamp;
    }
    
    function debtTop() internal returns(uint) {
        return oracle.getConfig("debt_top_c");
    }
    
    function liquidateLineRate() internal returns(uint){
        return oracle.getConfig("liquidate_line_rate_c");
    }
    
    function liquidateDisRate() internal returns(uint){
        return oracle.getConfig("liquidate_dis_rate_c");
    }
    
    function feeRate() internal returns(uint){
        return oracle.getConfig("fee_rate_c");
    }

    function liquidateTopRate() internal returns(uint){
        return oracle.getConfig("liquidate_top_rate_c");
    }
    
    function ethPrice() internal returns(uint){
        return oracle.getPrice("eth_price"); //150.23=>15023  
    }
    
    function setBond(address src,bool status) public onlyAdmin returns(bool){
        bondStatus[src] = status;
        return true;
    }
    
    //--SAR-operations--------------------------------------------------
    function open() public returns (bool success) {
        require(!sarStatus[msg.sender]);    //Check status
        sars[msg.sender] = Sar(msg.sender,0,0,0,0,block.number,0);
        sarStatus[msg.sender] = true;
        Operated(msg.sender,1,0);
        return true;
    }
    
    function reserve(uint256 wad) public returns (bool success){
        require(sarStatus[msg.sender]);    //Check status
        require(msg.sender == owner(msg.sender));
        require(seth.transferFrom(msg.sender,this,wad));
        sars[msg.sender].locked = add(sars[msg.sender].locked, wad);
        Operated(msg.sender,2,wad);
        return true;
    }
    
    function withdraw(uint256 mount) public  returns (bool success){
        require(sarStatus[msg.sender]);   
        require(msg.sender == owner(msg.sender));
        
        uint256 hasDrawedMount = hasDrawed(msg.sender);
        uint256 lockedMount = locked(msg.sender); 
        
        require(lockedMount >= mount);
        
        require(mul(sub(lockedMount,mount),ethPrice()) >= mul(hasDrawedMount,liquidateLineRate()));
        
        require(seth.transfer(msg.sender,mount));
        sars[msg.sender].locked = sub(sars[msg.sender].locked, mount);
        Operated(msg.sender,3,mount);
        return true;
    }

    function expande(uint256 wad) public  returns (bool success){
        require(sarStatus[msg.sender]);
        require(msg.sender == owner(msg.sender));
        
        uint256 hasDrawedMount = hasDrawed(msg.sender);
        require(debtTop() >= add(hasDrawedMount, wad));
        
        uint256 lockedMount = locked(msg.sender);
        uint256 maxMount = mul(lockedMount,ethPrice());
        uint256 checkMount = mul(add(hasDrawedMount, wad),liquidateLineRate());
        require(maxMount >= checkMount);
        
        sars[msg.sender].hasDrawed = add(hasDrawedMount, wad);
        sdusd.mint(msg.sender, wad);
        
        uint lastHeightNumer = block.number;
        if(hasDrawedMount == 0){
            sars[msg.sender].lastHeight = lastHeightNumer;
            sars[msg.sender].fee = 0;
        }else{
            uint256 currFee = (lastHeightNumer - lastHeight(msg.sender)) * hasDrawedMount * feeRate() / POWNER_TEN;
            sars[msg.sender].lastHeight = lastHeightNumer;
            sars[msg.sender].fee = currFee + fee(msg.sender);
        }
        Operated(msg.sender,4,wad);
        return true;
    }
    
    function contr(uint256 wad) public  returns (bool success){
        require(wad > 0);
        require(sarStatus[msg.sender]);
        require(msg.sender == owner(msg.sender));
        
        uint256 hasDrawedMount = hasDrawed(msg.sender);
        require(hasDrawedMount >= wad);
        
        uint lastHeightNumer = block.number;
        
        uint256 currFee = (lastHeightNumer - lastHeight(msg.sender)) * hasDrawedMount * feeRate() / POWNER_TEN;
        uint256 needUSDFee = add(currFee,fee(msg.sender)) * wad / hasDrawedMount;

        require(sdusd.balanceOf(msg.sender) >= add(wad,needUSDFee));
        
        sars[msg.sender].lastHeight = lastHeightNumer;
        sars[msg.sender].fee = sub(add(currFee,fee(msg.sender)),needUSDFee);
        sars[msg.sender].hasDrawed = sub(hasDrawedMount, wad);
        
        require(sdusd.transferFrom(msg.sender,this,needUSDFee));
        sdusd.burn(msg.sender,wad);
        Operated(msg.sender,5,wad);
        return true;
    }
    
    function rescue(address dest,uint256 wad) public  returns (bool success){
        require(wad > 0);
        require(sarStatus[msg.sender]);
        require(sarStatus[dest]);
        uint256 hasDrawedMount = hasDrawed(dest);
        uint256 lockedMount = locked(dest); 
        
        uint currentRate = mul(lockedMount,ethPrice())/mul(hasDrawedMount,100);
        uint rateClear = getRateClear(currentRate,liquidateDisRate());
        
        require(mul(lockedMount,ethPrice())<mul(hasDrawedMount,feeRate()));
        
        uint256 canClear = 0;
        if(currentRate>100 && currentRate<feeRate()){
             canClear = wad / (ethPrice() * rateClear);
             
             require(canClear > 0);
             require(canClear < lockedMount);
             require(wad < hasDrawedMount);
             require(mul(sub(hasDrawedMount,wad),liquidateTopRate()) > mul(sub(lockedMount,canClear),ethPrice()));
        }
        if(currentRate <= 100){
            require(hasDrawedMount==wad);
            canClear = lockedMount;
        }
        sdusd.burn(msg.sender,wad);
        sars[dest].locked = sub(lockedMount,canClear);
        sars[dest].hasDrawed = sub(hasDrawedMount,wad);
        
        sars[msg.sender].locked = add(sars[msg.sender].locked,canClear);
        Operated(msg.sender,6,wad);
        return true;
    }
    
    function getRateClear(uint currentRate,uint rateClear) internal returns(uint){
        uint ret = rateClear;
        if (currentRate > 0 && rateClear > 0)
        {
            uint result = 1000000 / currentRate;
            if (result > rateClear * 100)
            {
                ret = (result + 100) / 100;
            }
        }
        require(ret >= rateClear);
        return ret;
    }
    
    function rescueT(uint256 bondMount) public  returns (bool success){
        require(bondMount > 0);
        require(sarStatus[msg.sender]);
        require(bondStatus[msg.sender]);
        
        uint256 hasDrawedMount = hasDrawed(msg.sender);
        uint256 lockedMount = locked(msg.sender); 
        
        require(hasDrawedMount > 0);
        require(hasDrawedMount >= bondMount);
        
        uint currentRate = mul(lockedMount,ethPrice())/mul(hasDrawedMount,100);
        require(currentRate < feeRate());
        
        uint256 canClear = bondMount/ethPrice();
        
        if(currentRate > 100 && currentRate < feeRate()){
            uint lastRate = mul(sub(lockedMount,canClear),ethPrice())/sub(hasDrawedMount,bondMount);
            require(lastRate <= liquidateTopRate());
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
        Operated(msg.sender,6,bondMount);
        return true;
    }
    
    function withdrawT(uint256 mount) public  returns (bool success){
        require(mount > 0);
        require(sarStatus[msg.sender]);
        require(bondStatus[msg.sender]);
        require(msg.sender == owner(msg.sender));
        
        uint256 lockedMount = locked(msg.sender); 
        uint256 bondDrawedMount = bondDrawed(msg.sender);
        uint256 bondLockedMount = bondLocked(msg.sender);
        
        require(bondLockedMount > 0);
        require(bondDrawedMount > 0);
        require(bondLockedMount >= mount);
        
        sdusd.burn(msg.sender,mount);
        
        uint256 can = mul(bondLockedMount,mount)/bondDrawedMount;

        sars[msg.sender].locked = add(lockedMount, can);
        sars[msg.sender].bondLocked = sub(bondLockedMount,can);
        sars[msg.sender].bondDrawed = sub(bondDrawedMount,mount);
        
        bondGlobal = sub(bondGlobal,mount);
        require(bondGlobal >= 0);
        Operated(msg.sender,8,mount);
        return true;
    }


    function close() public  returns (bool success){
        require(sarStatus[msg.sender]);
        require(msg.sender == owner(msg.sender));
        require(locked(msg.sender)==0);
        require(hasDrawed(msg.sender)==0);
        require(fee(msg.sender)==0);
        require(bondLocked(msg.sender)==0);
        require(bondDrawed(msg.sender)==0);
        
        sarStatus[msg.sender] = false;
        Operated(msg.sender,7,0);
        return true;
    }
    
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
        uint lastHeight;

        //amount of stable fee(sdusd)
        uint256 fee;
    }
    
}