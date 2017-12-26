/*var MiniMeTokenFactory = artifacts.require("MiniMeTokenFactory");
var MiniMeToken = artifacts.require("MiniMeToken");
//var MetaCoin = artifacts.require("./MetaCoin.sol");

module.exports = function(deployer) {
  deployer.deploy(MiniMeTokenFactory).then(function() {
    return deployer.deploy(MiniMeToken, MiniMeTokenFactory.address, 0, 0,'ETHORA Token',18,'ETHORA', 'true');
  });  
    
};
*/



var Timeline = artifacts.require("TimelineDB");
var Ethora = artifacts.require("EthOra");
var Vault = artifacts.require("Vault");
//var MetaCoin = artifacts.require("./MetaCoin.sol");

module.exports = function(deployer) {
  deployer.deploy(Timeline);
  deployer.link(Timeline, Ethora);
  deployer.deploy(Vault).then(function() {
    //return deployer.deploy(MiniMeToken, MiniMeTokenFactory.address, 0, 0,'ETHORA Token',18,'ETHORA', 'true');
    return deployer.deploy(Ethora,'ETHORA Contract','ETHORA',Vault.address,'0x966114ea3312d5b9bc2dd7b7539d17fd0cc0ec56',1000000000000000 , 3600, 100, {gas: 2500000});//1000000000000000
  }).then(function(){
    return Vault.deployed();
  }).then(function(VaultInstance){
    return VaultInstance.changeParent(Ethora.address);
  }); 
  
  
};
