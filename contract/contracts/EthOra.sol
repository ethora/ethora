pragma solidity ^0.4.18;

import "./Controlled.sol";
import "./TimelineDB.sol";
import "zeppelin-solidity/contracts/ownership/Ownable.sol";

contract EthOra is Controlled, Ownable {
    
    string public name;                
    string public symbol;      
    
    uint public price;
    uint public decimals;
    uint64 public period; // in seconds for price cost
    mapping(address => uint) periods;   // allowed periods in future for accessing data
    mapping(address => int) reputations;   // allowed periods in future for accessing data
    //MiniMeToken public tokenContract;   // The new token for this Campaign
    address public vaultAddress;        // The address to hold the funds donated    
    Vault vault;

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
        address _vaultAddress,
        address _tokenAddress,
        uint _price,
        uint64 _period,
        uint _dbsize
    ) public {
        require ((_vaultAddress != 0)&&(_tokenAddress != 0));                    // To prevent burning ETH    
        name = _tokenName;                                 // Set the name
        symbol = _tokenSymbol;                             // Set the symbol
        vaultAddress = _vaultAddress;   //0x811AE29096280f3E581a8a0Fb96f3d99504eC1f1
        //tokenContract = MiniMeToken(_tokenAddress);// The Deployed Token Contract 0x966114ea3312d5b9bc2dd7b7539d17fd0cc0ec56 REP 0x39d85e313a5adae404d2979976292f1ff8abcfb2
        price = _price;
        period = _period;
        data.MAX_SIZE = _dbsize > 0 ? _dbsize : 100;
        vault = Vault(_vaultAddress);
    }    
    
    function () payable public
    {
        require((msg.value > 0) && (price > 0) && (period > 0));
        vault.call.value(msg.value)();
        uint _period = max(now, periods[msg.sender]);
        periods[msg.sender] = _period + msg.value / price * period;
        LogDeposit(msg.sender, msg.value);
        LogPeriod(msg.sender, periods[msg.sender]);
    }
    
    function insert(int64 _key, int _value) external returns (bool replaced)
    {
        require(_key >= 0);
        periods[msg.sender] = uint(_key) + period;      
        LogPeriod(msg.sender, periods[msg.sender]);
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
        require((_key >= 0) && (now <= periods[msg.sender]));
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

    function max(uint a, uint b) pure internal returns (uint) {
        return a > b ? a : b;
    }

}

contract Vault is Controlled{

    modifier onlyParent { require (msg.sender == parent); _; }

    address public parent;
    
    event Payments(address indexed to, uint value);
    event Deposit(address indexed from, uint value);

    function Vault() public { parent = msg.sender;}

    function changeParent(address _newParent) onlyParent public {
        parent = _newParent;
    }    

    function changeParentC(address _newParent) onlyController public {
        parent = _newParent;
    }        
    
    function () payable public {
        Deposit(msg.sender, msg.value);
        Deposit(tx.origin, msg.value);
    }
    
    function fund(address _to, uint _value) onlyParent public
    {
        require(_to.send(_value));
        Payments(_to, _value);
    }
}