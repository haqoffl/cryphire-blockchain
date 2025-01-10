// SPDX-License-Identifier: GPL-3.0
import './Cryphire.sol';
pragma solidity ^0.7.0;
pragma abicoder v2;

contract PoolFactory {
    event poolCreated(address indexed poolAddress,uint _durationInDaysForRaising,uint _durationInDaysForPool,uint _trader_share,address _accepting_token,address _swapRouter, address _nonFungiblePositionManager);
    Cryphire[] public cryphire;
function createNewPool(uint _durationInDaysForRaising,uint _durationInDaysForPool,uint _trader_share,address _accepting_token,address _swapRouter, address _nonFungiblePositionManager) public{
    Cryphire _cryphire = new Cryphire(_durationInDaysForRaising,_durationInDaysForPool,_trader_share,_accepting_token,_swapRouter,_nonFungiblePositionManager);
    cryphire.push(_cryphire);
    emit poolCreated(address(_cryphire),_durationInDaysForRaising,_durationInDaysForPool,_trader_share,_accepting_token,_swapRouter, _nonFungiblePositionManager);
}

function getPool(uint _index) public view returns(address){
    Cryphire _cryphire = cryphire[_index];
    return address(_cryphire);
}

function getPoolCount() public view returns(uint){
    return cryphire.length;
    }
}


contract BaseFactory {
PoolFactory public poolFactory;
mapping(address=>address) public ownedFactory;

function createNewFactory()public{
require(ownedFactory[msg.sender] == address(0),"you already have a factory");
PoolFactory _poolFactory = new PoolFactory();
ownedFactory[msg.sender] = address(_poolFactory);
}

function getFactory()public view returns(address){
    return ownedFactory[msg.sender];
}

}