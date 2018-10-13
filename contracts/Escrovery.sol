/**
 * (c) 2018 Jeff Pickhardt. All rights reserved.
 */

pragma solidity ^0.4.24;
contract Escrovery {
  address public manager;
  
  struct Challenge {
      address newAddress;
      uint escrowedAmount;
      uint blockTime;
  }
  
  struct Account {
      uint balance;
      uint challengeDuration;
      Challenge[10] openChallenges; // TODO use dynamic sizing
      string description; // Optional description that may help you find your account if you forget which one it is. For example, "Jeff's account"
  }
  
  mapping(bytes32 => Challenge) unrevealedChallenges;

  mapping(address => Account) accounts;
 
  constructor() public {
    manager = msg.sender;
  }

  function createAccount() public payable {
      require(accounts[msg.sender].balance == 0);
      require(msg.value > 0);
      
      Account storage myAccount;
      myAccount.balance = msg.value;
      myAccount.challengeDuration = 604800; // 7 days in seconds, TODO make this configurable by the account
      accounts[msg.sender] = myAccount;
  }
  
  function closeAccount() public {
      require(accounts[msg.sender].balance > 0);

      uint closingBalance = accounts[msg.sender].balance;
      delete accounts[msg.sender];
      msg.sender.transfer(closingBalance);
  }
  
  function submitChallenge(bytes32 dataHash) public payable {
      require(unrevealedChallenges[dataHash].escrowedAmount == 0);
      require(msg.value > 0);
      
      unrevealedChallenges[dataHash] = Challenge({
          newAddress: address(0),
          escrowedAmount: msg.value, // TODO bin the values to powers of k, for some k
          blockTime: now
      });
  }
  
  function revealChallenge(address challengedAddress, address newAddress) public {
      uint REVEAL_VALID_DURATION = 86400; // 1 day in seconds
      bytes32 computedDataHash = keccak256(abi.encodePacked(newAddress, '||', challengedAddress));
      Account storage challengedAccount = accounts[challengedAddress];
      require(challengedAccount.balance > 0);
      Challenge storage referencedChallenge = unrevealedChallenges[computedDataHash];
      require(referencedChallenge.escrowedAmount > 0); // TODO make this > a configurable value by the account in question
      require(now < (referencedChallenge.blockTime + REVEAL_VALID_DURATION));
      
      referencedChallenge.newAddress = newAddress;
      referencedChallenge.blockTime = now;
      challengedAccount.openChallenges[challengedAccount.openChallenges.length] = referencedChallenge;
      delete unrevealedChallenges[computedDataHash];
  }
  
  function claimChallenge(address challengedAddress) public {
      Account storage challengedAccount = accounts[challengedAddress];
      require(challengedAccount.balance > 0);
      
      Challenge storage myChallenge;
      uint i = 0;
      for (i = 0; i < challengedAccount.openChallenges.length; i++){
          myChallenge = challengedAccount.openChallenges[i];
          if (myChallenge.newAddress == msg.sender) {
              break;
          }
      }
      
      // Require the first open challenge to be the winner
      // TODO relax this assumption
      require(i == 0);
      require(myChallenge.newAddress == msg.sender);
      require(now < myChallenge.blockTime + challengedAccount.challengeDuration);
      
      accounts[msg.sender] = challengedAccount;
      delete challengedAccount.openChallenges[i];
      delete accounts[challengedAddress]; 
      giveAccountOpenChallenges(msg.sender);
  }
  
  // Clears all open challenges for an account that you own.
  function respondToChallenges() public {
      Account storage myAccount = accounts[msg.sender];
      require(myAccount.balance > 0);
      giveAccountOpenChallenges(msg.sender);
  }
  
  function giveAccountOpenChallenges(address accountAddress) {
      Account storage whichAccount = accounts[accountAddress];
      for (uint i = 0; i < whichAccount.openChallenges.length; i++){
          Challenge storage whichChallenge = whichAccount.openChallenges[i];
          whichAccount.balance += whichChallenge.escrowedAmount;
          whichChallenge.escrowedAmount = 0;
          delete whichAccount.openChallenges[i];
      }
  }
}
