pragma solidity ^0.4.18;

// using idea https://github.com/ethereum/dapp-bin/blob/master/library/iterable_mapping.sol
library TimelineDB {

  
  uint64 constant internal None = uint64(0);
  
  event LogPrune(uint64 indexed key, int value);
  

  struct timeline
  {
    mapping(uint64 => IndexValue) data;
    uint64 first;  // unixtime
    uint64 last;  // unixtime
    uint size;
    uint MAX_SIZE;
  }
  
  struct IndexValue { 
    uint64 key; 
    int value; 
    uint64 next; 
    uint64 prev; 
    int reputation;
    Provider[] providers;
  }
  
  struct Provider {
    address issuer;
    int reputation;
  }
  
  function get(timeline storage self, uint64 key) view public returns (int) 
  {
    require(key >= self.first && key <= self.last && self.size > 0 && self.data[key].key == key);
    //self.data[key].count=self.data[key].count+1;
    return self.data[key].value;
  }

  function insert(timeline storage self, uint64 key, int value) public  returns (bool replaced)
  {
    require(key <= now);
    short(self, key);
    self.data[key].reputation = issuer(self, key, value);
    
    uint64 keyIndex = self.data[key].key;
    self.data[key].value = value;
    if (keyIndex > 0)
      return true;
    else
    {
      if (self.last == None && self.first == None && self.size == 0)
      {
        self.first = self.last = key;
        self.data[key].prev = self.data[key].next = None;
      }      
      else {
        if (key < self.first) 
        {
          self.data[self.first].prev = key;
          self.data[key].next = self.first;
          self.first = key;
        }
        if (key > self.last)
        {
          self.data[self.last].next = key;
          self.data[key].prev = self.last;
          self.last = key;
        }
        if (key < self.last && key > self.first)
        {
          uint64 _key = find(self, key); // return _key < key
          self.data[key].prev = _key;
          self.data[self.data[_key].next].prev = key;
          self.data[key].next = self.data[_key].next;
          self.data[_key].next = key;
        }
      }
      self.data[key].key = key;
      self.size++;
      return false;
    }    
  }
  
  function short(timeline storage self, uint64 key) internal returns (bool)
  {
  
    //if (self.size >= self.MAX_SIZE && key < self.first) throw;
    if (self.size <  self.MAX_SIZE) return;
    
    require(!(self.size >= self.MAX_SIZE && key < self.first));

    uint64 _key = self.first;
    self.first = self.data[_key].next;
    self.data[self.first].prev = None;
    
    LogPrune(_key, self.data[_key].value);
    delete self.data[_key];
    
    self.size--;
  }
  
  function find(timeline storage self, uint64 key) view internal  returns (uint64)
  {
    uint64 _key = self.last;
    while(_key > key && _key != None)
    {
      _key = self.data[_key].prev;
    }
    return _key;
  }
  
  function issuer(timeline storage self, uint64 key, int value) internal returns (int)
    {
    Provider memory _provider;
    _provider.issuer = msg.sender;
    if(self.data[key].providers.length == 0) _provider.reputation++;
    else 
    {
      if (value == self.data[key].value) 
        {
          self.data[key].providers[0].reputation++;
          _provider.reputation++;
        }
      else {
        self.data[key].providers[0].reputation--;
        _provider.reputation--;
        }
    }
    for(uint i = 0; i < self.data[key].providers.length; i++){
      if (msg.sender == self.data[key].providers[i].issuer){
        return _provider.reputation;
      }
    }
    self.data[key].providers.push(_provider);
    return _provider.reputation;
  }

}