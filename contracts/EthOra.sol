pragma solidity ^0.4.18;


import "./TimelineDB.sol";
import "zeppelin-solidity/contracts/ownership/Ownable.sol";
import "zeppelin-solidity/contracts/token/StandardToken.sol";
import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "zeppelin-solidity/contracts/math/Math.sol";

contract EthOra is Ownable, StandardToken {
    using SafeMath for uint256;
    using Math for uint256;
    
    string public name;                
    string public symbol;      
    uint8 public decimals;

    
    uint public price;
    uint64 public period; // in seconds for price cost
    mapping(address => uint) periods;   // allowed periods in future for accessing data
    mapping(address => int) reputations;   // allowed periods in future for accessing data

    TimelineDB.timeline data;
    
    event LogInserted(uint64 indexed key, int reputation, uint64 first, uint64 last, uint size);
    event LogUpdated(uint64 indexed key, int reputation);
    event LogGotten(uint64 indexed key);
    event LogPrune(uint64 indexed key, int value);
    event LogDeposit(address indexed from, uint value);
    event LogPeriod(address indexed user, uint period);
    
    function EthOra(
        string _tokenName,
        string _tokenSymbol,
        uint _price,
        uint64 _period,
        uint8 _decimals,
        uint _dbsize
    ) public {
        name = _tokenName;                                 // Set the name
        symbol = _tokenSymbol;                             // Set the symbol
        price = _price;
        period = _period;
        decimals = _decimals;
        data.MAX_SIZE = _dbsize > 0 ? _dbsize : 100;

    }    
    
    function () payable public {
        require((msg.value > 0) && (price > 0) && (period > 0));
        require(doPayment());
        uint _period = now.max256(periods[msg.sender]);
        periods[msg.sender] = _period.add( msg.value.div( price).mul( period));
        //LogDeposit(msg.sender, msg.value);
        LogPeriod(msg.sender, periods[msg.sender]);        
        transfer(this, msg.value);
    }
    
    function doPayment() internal returns (bool){
        uint amount = msg.value;
        require(amount > 0);
        require(increaseApproval(this, amount));
        balances[msg.sender] = balanceOf(msg.sender).add(amount);
        totalSupply = totalSupply.add(amount);
        Transfer(0, msg.sender, amount);
        return true;
    }
    
    function asyncSend(address dest, uint amount) internal returns (bool){
        require(dest != address(0));
        require(amount > 0);
        totalSupply = totalSupply.add(amount);
        balances[dest] = balanceOf(dest).add(amount);
        allowed[dest][this] = allowed[dest][this].add(amount);
        Transfer(this, dest, amount);
        Approval(dest, this, allowed[dest][this]);        
        return true;
    }
    
    function asyncRequest(address from, uint amount) internal returns (bool){
        require(from != address(0));
        require(amount > 0);
        require(totalSupply >= amount);
        require(balances[from] >= amount);
        require(allowed[from][this] >= amount);
        totalSupply = totalSupply.sub(amount);
        balances[from] = balanceOf(from).sub(amount);
        Transfer(from, this, amount);
        Approval(from, this, allowed[from][this]);  
        return true;
    }
    
    function withdraw(uint amount) public returns (bool){
        require(amount > 0);
        require(balances[msg.sender] >= amount);
        require(decreaseApproval(this, amount));
        balances[msg.sender] = balanceOf(msg.sender).sub(amount);
        totalSupply = totalSupply.sub(amount);
        msg.sender.transfer(amount);
        Transfer(msg.sender, 0, amount);
        return true;
    }   
    
    function insert(int64 _key, int _value) external returns (bool replaced)
    {
        require(_key >= 0);
        periods[msg.sender] = uint(_key).add(period);
        LogPeriod(msg.sender, periods[msg.sender]);
        if (msg.sender != tx.origin){
            periods[tx.origin] = uint(_key).add(period);
            LogPeriod(tx.origin, periods[tx.origin]);
        }
        
        if (!TimelineDB.insert(data, uint64(_key), _value)){
            LogInserted(uint64(_key),rep(uint64(_key)), data.first, data.last, data.size);
            return false;
        }
        else 
        {
            LogUpdated(uint64(_key),rep(uint64(_key)));
            return true;
        }
    }
    
    function rep(uint64 key) internal returns (int)
    {
        if (data.data[key].providers.length > 10 ){
            for(uint i=0; i< data.data[key].providers.length; i++)
            {
                reputations[data.data[key].providers[i].issuer] += data.data[key].providers[i].reputation;
            }
            reputations[msg.sender] += data.data[key].reputation;
        }
        
        return reputations[msg.sender];
    }
    
    function get(int64 _key) external returns (uint64 key, int value)
    {
        return _get(uint64(_key));
    }
    
    function _get(uint64 _key) internal returns (uint64 key, int value)
    {
        require((_key >= 0) && ((now <= periods[msg.sender])||(now <= periods[tx.origin])));
        int _value = TimelineDB.get(data, _key);
        LogGotten(_key);
        return (_key, _value);
    }
    
    function getLast() external returns (uint64 key, int value)
    {
        return _get(data.last);
    }
    
    function getFirst() external returns (uint64 key, int value)
    {
        return  _get(data.first);
    }    
    
    function setPrice(uint _price, uint64 _period) onlyOwner public
    {
        price = _price;
        period = _period;
    }
    
    function getPeriod() public view returns (uint)
    {
        return periods[msg.sender];
    }

    function getReputation(address issuer) public view returns (int)
    {
        if(issuer == address(0)) return reputations[msg.sender];
        else return reputations[issuer];
    }

}
