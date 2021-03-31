// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "./Token.sol";

contract dBank {

  //assign Token contract to variable
  Token private token;

  //add mappings
  mapping(address=>uint) public etherBalanceOf;
  mapping(address=>uint) public depositStart;
  mapping(address=>bool) public isDeposited;

  mapping(address=>uint) public collateralEther;
  mapping(address=>bool) public isBorrowed;

  //add events
  event Deposit(address indexed user,uint etherAmount,uint timeStart);
  event Withdraw(address indexed user,uint etherAmount,uint depositTime,uint interest);
  event Borrow(address indexed user,uint collateralEtherAmount,uint borrowedTokenAmount);
  event Payoff(address indexed user,uint fee);

  //pass as constructor argument deployed Token contract
  constructor(Token _token) public {
    //assign token deployed contract to variable
    token = _token;
  }

  function deposit() payable public {
    //check if msg.sender didn't already deposited funds

    require(isDeposited[msg.sender]==false,"Error : User has already Deposited");
    //check if msg.value is >= than 0.01 ETH
    require(msg.value>=0.01 ether , "Error : Minimum value is 0.01 ether");

    etherBalanceOf[msg.sender] = etherBalanceOf[msg.sender] + msg.value;
    //increase msg.sender ether deposit balance
    //start msg.sender hodling time
    depositStart[msg.sender] = depositStart[msg.sender] + block.timestamp;


    //set msg.sender deposit status to true
    isDeposited[msg.sender] = true;

    //emit Deposit event
    emit Deposit(msg.sender,msg.value,block.timestamp);
  }

  function withdraw() public {
    //check if msg.sender deposit status is true
    require(isDeposited[msg.sender]==true,"Error: User hasnt deposited");
    // //assign msg.sender ether deposit balance to variable for event
    uint userBalance = etherBalanceOf[msg.sender];

    // //check user's hodl time
    uint depositTime = block.timestamp - depositStart[msg.sender];

    //calc interest per second
    //calc accrued interest
    uint interestPerSecond = 31668017 * (etherBalanceOf[msg.sender]/0.01 ether);
    uint interest = interestPerSecond * depositTime;

    //send eth to user
    msg.sender.transfer(userBalance);
    //send interest in tokens to user
    token.mint(msg.sender,interest);

    //reset depositer data
    etherBalanceOf[msg.sender]=0;
    isDeposited[msg.sender]=false;
    depositStart[msg.sender]=0;

    //emit event
    emit Withdraw(msg.sender,userBalance,depositTime,interest);
  }

  function borrow() payable public {
    //check if collateral is >= than 0.01 ETH
    require(msg.value>=0.01 ether,"Error, Collateral value should be greater than 0.01 ether");
    //check if user doesn't have active loan
    require(isBorrowed[msg.sender]==false,"Error, User already has an existing loan");

    //add msg.value to ether collateral
    collateralEther[msg.sender]= collateralEther[msg.sender] + msg.value;

    //calc tokens amount to mint, 50% of msg.value
    uint tokensToMint = collateralEther[msg.sender]/2;

    //mint&send tokens to user
    token.mint(msg.sender,tokensToMint);

    //activate borrower's loan status
    isBorrowed[msg.sender]=true;

    //emit event
    emit Borrow(msg.sender,collateralEther[msg.sender],tokensToMint);
  }

  function payOff() public {
    //check if loan is active
    require(isBorrowed[msg.sender],"Take a loan before you pay off");
    //transfer tokens from user back to the contract
    require(token.transferFrom(msg.sender,address(this),collateralEther[msg.sender]/2),"Error : Cant receive Tokens");

    //calc fee
    uint fee = collateralEther[msg.sender]/10;

    //send user's collateral minus fee
    msg.sender.transfer(collateralEther[msg.sender]-fee);

    //reset borrower's data
    isBorrowed[msg.sender]=false;
    collateralEther[msg.sender]=0;

    //emit event
    emit Payoff(msg.sender,fee);
  }
}