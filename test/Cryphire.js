var {expect} = require('chai')
var {ethers} = require('hardhat')
const helpers= require('@nomicfoundation/hardhat-toolbox/network-helpers')
const tokenABI = require('../tokenABI.json')
const {before} = require('mocha')
let investor = "0x69166e49d2fd23E4cbEA767d7191bE423a7733A5"
const tokenAddress = "0xdAC17F958D2ee523a2206206994597C13D831ec7" //USDT
const DAI = "0x6B175474E89094C44Da98b954EedeAC495271d0F" //DAI
const UNI = "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984" //UNISWAP 
describe('Cryphire', async()=> {
let cryphire
  before(async () => {
    await helpers.reset("https://eth-mainnet.g.alchemy.com/v2/EDVesxXnpj6wZoq8trrtFnNy6kBa9_fP");
    [trader] = await ethers.getSigners()
    let swap_router = "0xE592427A0AEce92De3Edee1F18E0157C05861564"
    let _nonFungiblePositionManager = "0xC36442b4a4522E871399CD717aBDD847Ab11FE88"
    const Cryphire = await ethers.getContractFactory("Cryphire");
    cryphire = await Cryphire.connect(trader).deploy(7,30,25,tokenAddress,swap_router,_nonFungiblePositionManager);
    await cryphire.waitForDeployment();
  })


    it("transfer token", async () => {
        let [trader] = await ethers.getSigners()
        await hre.network.provider.send("hardhat_impersonateAccount", [investor]);
        //await helpers.impersonateAccount(investor)
        const impersonatedSigner = await ethers.getSigner(investor)
        const tokenContract = new ethers.Contract(tokenAddress,tokenABI,impersonatedSigner);
        const block = await ethers.provider.getBlock('latest');
        const baseFeePerGas = block.baseFeePerGas;
        console.log("Base Fee Per Gas:", baseFeePerGas.toString());
         const maxFeePerGas = ethers.toNumber(baseFeePerGas) * 2; // 2x base fee to ensure the transaction gets mined  
         let amount = ethers.parseUnits('100000', 6);      
        let dt = await tokenContract.transfer(trader.address, amount,{
            maxFeePerGas: maxFeePerGas,
        }) 
        const receipt = await dt.wait();
        console.log(receipt)

    })


    it("approve & stake token trader", async () => {
        let [trader] = await ethers.getSigners()
        const tokenContract = new ethers.Contract(tokenAddress,tokenABI,trader);
        let amount = ethers.parseUnits('600', 6); 
         await tokenContract.connect(trader).approve(cryphire.target,amount) 
        let allowance = await tokenContract.allowance(trader.address,cryphire.target)
        console.log("allowance:",allowance)
        let amount_to_stake = ethers.parseUnits('500', 6); 
        let dt = await cryphire.connect(trader).traderStake(ethers.toNumber(amount_to_stake),4) 
        console.log(dt)
        let traderStake = await cryphire.trader_stake()
        console.log("trader investment: ",ethers.toNumber(traderStake))
    })

    it("approve & invest token investor", async () => {
  
         await hre.network.provider.send("hardhat_impersonateAccount", [investor]);
         const impersonatedSigner = await ethers.getSigner(investor)
         const tokenContract = new ethers.Contract(tokenAddress,tokenABI,impersonatedSigner);
         let amount = ethers.parseUnits('1000', 6); 
         let approve = await tokenContract.approve(cryphire.target,amount) 
         console.log(approve)
         let allowance = await tokenContract.allowance(investor,cryphire.target)
         console.log("allowance:",allowance)
         let amount_to_invest = ethers.parseUnits('500', 6); 
         let dt = await cryphire.connect(impersonatedSigner).depositERC20_inv(ethers.toNumber(amount_to_invest)); 
         console.log(dt)
         let balance = await cryphire.investor_investment(investor)
         console.log("investor investment: ",ethers.toNumber(balance))
 
     })

     it("swapForExactInputSingle", async () => {
        let [trader] = await ethers.getSigners()
        let amountIn = ethers.parseUnits('100', 6); 
        let dt = await cryphire.connect(trader).swapForExactInputSingle(
          amountIn,
          tokenAddress,
          DAI,
          100,
          0) 

        console.log(dt)
     })

     it("balance of DAI in contract", async () => {
        let [trader] = await ethers.getSigners()
        let dt = await cryphire.connect(trader).balance_of_tokens(DAI)
        console.log("balance of DAI:",dt)
     })
     
     it("swapForExactOutputSingle", async () => {
        let [trader] = await ethers.getSigners()
        let amountOut = ethers.parseUnits('15', 18); 
        let amount_in_maximum = ethers.parseUnits('250', 6);
        let dt = await cryphire.connect(trader).swapForExactOutputSingle(
          tokenAddress,
          UNI,
          3000,
          amountOut,
          amount_in_maximum,
          0);

        console.log(dt)
     })

     it("balance of UNI in contract", async () => {
        let [trader] = await ethers.getSigners()
        let dt = await cryphire.connect(trader).balance_of_tokens(UNI)
        console.log("balance of UNI:",dt)
     })

     it("minting new position", async () => {
        let [trader] = await ethers.getSigners()
        let amount0ToMint = ethers.parseUnits('50', 18); 
        let amount1ToMint = ethers.parseUnits('50', 6); 
        let dt = await cryphire.connect(trader).mintNewPosition(
          DAI,
          tokenAddress,
          100,
          amount0ToMint,
          amount1ToMint
      )
        console.log(dt)
     })

     it("collecting pool fee",async()=>{
        let [trader] = await ethers.getSigners()
        let idTrackingIndex = await cryphire.idTrackingIndex()
      let trackingIndex = ethers.toNumber(idTrackingIndex)-1
        let idTrackingIndexToTokenId = await cryphire.idTrackingIndexToTokenId(trackingIndex)
  
        let tokenId = ethers.toNumber(idTrackingIndexToTokenId)
        console.log("tokenId:",tokenId)
        let dt = await cryphire.connect(trader).collectAllFees(tokenId)
        console.log(dt)
     })

     it("increaseLiquidityCurrentRange",async()=>{
        let [trader] = await ethers.getSigners()
        let idTrackingIndex = await cryphire.idTrackingIndex()
      let trackingIndex = ethers.toNumber(idTrackingIndex)-1
        let idTrackingIndexToTokenId = await cryphire.idTrackingIndexToTokenId(trackingIndex)
  
        let tokenId = ethers.toNumber(idTrackingIndexToTokenId)
        console.log("tokenId:",tokenId)
        let amountAdd0 = ethers.parseUnits('10', 18);
        let amountAdd1 = ethers.parseUnits('10', 6);
        let dt = await cryphire.connect(trader).increaseLiquidityCurrentRange(tokenId,amountAdd0,amountAdd1)
        console.log(dt)
     })

     it("getLiquidity",async()=>{
        let [trader] = await ethers.getSigners()
        let idTrackingIndex = await cryphire.idTrackingIndex()
      let trackingIndex = ethers.toNumber(idTrackingIndex)-1
        let idTrackingIndexToTokenId = await cryphire.idTrackingIndexToTokenId(trackingIndex)
  
        let tokenId = ethers.toNumber(idTrackingIndexToTokenId)
        console.log("tokenId:",tokenId)
        let dt = await cryphire.connect(trader).getLiquidity(tokenId)
        console.log(dt)
     })

     it("decreaseLiquidityInHalf",async()=>{
        let [trader] = await ethers.getSigners()
        let idTrackingIndex = await cryphire.idTrackingIndex()
      let trackingIndex = ethers.toNumber(idTrackingIndex)-1
        let idTrackingIndexToTokenId = await cryphire.idTrackingIndexToTokenId(trackingIndex)
  
        let tokenId = ethers.toNumber(idTrackingIndexToTokenId)
        console.log("tokenId:",tokenId)
        let dt = await cryphire.connect(trader).decreaseLiquidityInHalf(tokenId)
        console.log(dt)
     })

     it("getLiquidity after decrease",async()=>{
      let [trader] = await ethers.getSigners()
      let idTrackingIndex = await cryphire.idTrackingIndex()
    let trackingIndex = ethers.toNumber(idTrackingIndex)-1
      let idTrackingIndexToTokenId = await cryphire.idTrackingIndexToTokenId(trackingIndex)

      let tokenId = ethers.toNumber(idTrackingIndexToTokenId)
      console.log("tokenId:",tokenId)
      let dt = await cryphire.connect(trader).getLiquidity(tokenId)
      console.log(dt)
   })
})

