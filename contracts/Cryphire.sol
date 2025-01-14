// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.7.0;
pragma abicoder v2;
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import '@uniswap/v3-periphery/contracts/base/LiquidityManagement.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "hardhat/console.sol";

interface INFTManagerPosition {
    // NB: the fields of this custom struct match the order of the primitive types returned by INonFungiblePositionManager.positions()
    struct NFTPosition {
            uint96 nonce;
            address operator;
            address token0;
            address token1;
            uint24 fee;
            int24 tickLower;
            int24 tickUpper;
            uint128 liquidity;
            uint256 feeGrowthInside0LastX128;
            uint256 feeGrowthInside1LastX128;
            uint128 tokensOwed0;
            uint128 tokensOwed1;
 
    }
    // Note the function is identical to INonFungiblePositionManager.positions except for the return type
    // This workaround does not seem to work if the external function accepts too many input parameters and you want to encode the inputs into a custom struct, likely because this results in a different function selector and so you're calling a function that doesn't exist, however, this is not an issue for the return value since that is not considered when computing the function signature hash
    function positions(uint256 tokenId) external view returns (NFTPosition memory);
}


contract Cryphire is IERC721Receiver {
    event liquidityMinted(uint256 tokenId,address indexed token0,address indexed token1,uint128 liquidity);
    event liquidityIncreased(uint256 tokenId,uint128 currentLiquidity);
    event liquidityDecreased(uint256 tokenId,uint128 currentLiquidity);
    address payable public trader;
    mapping(address=>bool) investor;
    uint public trader_stake;
    mapping(address=>uint) public investor_investment;
    uint public max_pool_limit;
    uint public raised_amount;
    uint public raising_deadline;
    uint public pool_deadline;
    uint public trader_share;
      struct Deposit {
        address owner;
        uint128 liquidity;
        address token0;
        address token1;
    }
    mapping(uint256 => Deposit) public deposits;
    uint public idTrackingIndex;
    mapping(uint256 => uint256) public idTrackingIndexToTokenId;
   address public immutable acceptingToken;
   uint public decimal;
    ISwapRouter public immutable swapRouter;
    INonfungiblePositionManager public immutable nonfungiblePositionManager;
    INFTManagerPosition public immutable nftPositionManager;
    constructor(uint _durationInDaysForRaising,uint _durationInDaysForPool,uint _trader_share,address _accepting_token,address _swapRouter, address _nonFungiblePositionManager) payable{
        trader = payable(msg.sender);
        pool_deadline = block.timestamp + (_durationInDaysForPool * 1 days);
        raising_deadline = block.timestamp + (_durationInDaysForRaising * 1 days);
        trader_share=_trader_share;
        acceptingToken = _accepting_token;
        decimal = IERC20(_accepting_token).decimals();
        swapRouter = ISwapRouter(_swapRouter);
        nonfungiblePositionManager = INonfungiblePositionManager(_nonFungiblePositionManager);
        nftPositionManager = INFTManagerPosition(_nonFungiblePositionManager);
        }

    modifier isstakeDepositedByTrader(){
        console.log("trader stake: ",trader_stake);
        require(trader_stake != 0, "trader not have stake");
        _;
    }
    
    modifier onlyTrader(){
        console.log("modifier called");

        require(trader == msg.sender,"ONLY TRADER");
        _;
    }

function traderStake(uint amount,uint times)public {
    require(trader == msg.sender,"ONLY TRADER");
    require(raising_deadline > block.timestamp,"EXPIRED");
   TransferHelper.safeTransferFrom(address(acceptingToken), msg.sender, address(this), amount);
    trader_stake+= amount;
    max_pool_limit = trader_stake *times;
    console.log("everything is alright");
    console.log("trader stake: ",trader_stake);
}

function depositERC20_inv(uint amount) public isstakeDepositedByTrader{
        require(trader != msg.sender);
        uint poolBalance = IERC20(acceptingToken).balanceOf(address(this));
        require(max_pool_limit > (amount+poolBalance),"HTPL");
        require(raising_deadline > block.timestamp,"EXPIRED");
        
        //TransferHelper.safeApprove(address(acceptingToken),address(this), amount);
        TransferHelper.safeTransferFrom(address(acceptingToken), msg.sender, address(this), amount);
        investor[msg.sender] = true;
        investor_investment[msg.sender] += amount;
        raised_amount += amount;
}

function swapForExactInputSingle(uint256 amountIn,address token_in,address token_out,uint24 pool_fee,uint160 _sqrtPriceLimitX96) external onlyTrader  returns(uint) {
            //uint feeTier = 3000;
            require(raised_amount>= amountIn,"LB");
            TransferHelper.safeApprove(token_in, address(swapRouter), amountIn);
            ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: token_in,
                tokenOut: token_out,
                fee: pool_fee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: _sqrtPriceLimitX96 //0
            });


            return swapRouter.exactInputSingle(params);
            
}

function swapForExactOutputSingle(address token_in,address token_out,uint24 pool_fee,uint amount_out,uint amount_in_maximum,uint160 _sqrtPriceLimitX96) onlyTrader public{
      require(raised_amount>= amount_in_maximum,"LB");
      TransferHelper.safeApprove(token_in, address(swapRouter), amount_in_maximum);
      ISwapRouter.ExactOutputSingleParams memory params =
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: token_in,
                tokenOut: token_out,
                fee: pool_fee,
                recipient: address(this),
                deadline: block.timestamp,
                amountOut: amount_out,
                amountInMaximum: amount_in_maximum,
                sqrtPriceLimitX96: _sqrtPriceLimitX96
            });
                uint amountIn = swapRouter.exactOutputSingle(params);
                    console.log("amount in:",amountIn);
                if (amountIn < amount_in_maximum) {
            TransferHelper.safeApprove(token_in, address(swapRouter), 0);
        }

}

    // Implementing `onERC721Received` so this contract can receive custody of erc721 tokens
function onERC721Received(address operator,address,uint256 tokenId,bytes calldata) external override returns (bytes4) {
        _createDeposit(operator, tokenId);
        return this.onERC721Received.selector;
}


function _createDeposit(address owner, uint256 tokenId) internal {
        (, , address token0, address token1, , , , uint128 liquidity, , , , ) =
            nonfungiblePositionManager.positions(tokenId);

        deposits[tokenId] = Deposit({owner: owner, liquidity: liquidity, token0: token0, token1: token1});
        idTrackingIndexToTokenId[idTrackingIndex] = tokenId;
        idTrackingIndex++;
        console.log("deposit");
        emit liquidityMinted(tokenId,token0,token1,liquidity);
}

function isPoolExist(address factory, address tokenA, address tokenB, uint24 fee) external view returns (address) {
   address add =  IUniswapV3Factory(factory).getPool(tokenA, tokenB, fee);
   return add;
}

function mintNewPosition(
    address _token0,
    address _token1,
    uint24 _poolFee,
    uint amount0ToMint,
    uint amount1ToMint) external  returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) {

        //uint256 slippageTolerance = 100; // 1% in basis points (100 basis points = 1%)
        // uint _amount0min = amount0ToMint - ((amount0ToMint * slippageTolerance) / 10000);
        //uint _amount1min = amount1ToMint - ((amount1ToMint * slippageTolerance) / 10000);
        TransferHelper.safeApprove(_token0,address(nonfungiblePositionManager),amount0ToMint);
        TransferHelper.safeApprove(_token1,address(nonfungiblePositionManager),amount1ToMint);
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
        token0: _token0,
        token1: _token1,
        fee: _poolFee,
        tickLower: TickMath.MIN_TICK,
        tickUpper: TickMath.MAX_TICK,
        amount0Desired: amount0ToMint,
        amount1Desired: amount1ToMint,
        amount0Min:0,
        amount1Min:0,
        recipient: address(this),
        deadline: block.timestamp + 30 minutes // Ensure the deadline is reasonable
        });
        console.log("passed");
        (tokenId, liquidity, amount0, amount1) = nonfungiblePositionManager.mint(params);
        console.log("Minted position. Token ID:", tokenId, "Liquidity:", liquidity);
        console.log("Amount0:", amount0, "Amount1:", amount1);
        _createDeposit(address(this), tokenId);
        if (amount0 < amount0ToMint) {
        TransferHelper.safeApprove(_token0, address(nonfungiblePositionManager), 0);
        uint256 refund0 = amount0ToMint - amount0;
        TransferHelper.safeTransfer(_token0,address(this), refund0);
        }

        if (amount1 < amount1ToMint) {
        TransferHelper.safeApprove(_token1, address(nonfungiblePositionManager), 0);
        uint256 refund1 = amount1ToMint - amount1;
        TransferHelper.safeTransfer(_token1,address(this), refund1);
        }
        emit liquidityMinted(tokenId,_token0,_token1,liquidity);
        return (tokenId, liquidity, amount0, amount1);
}


function collectAllFees(uint256 tokenId) external onlyTrader returns (uint256 amount0, uint256 amount1) {
            INonfungiblePositionManager.CollectParams memory params =
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

            (amount0, amount1) = nonfungiblePositionManager.collect(params);
            console.log("Collected fees. Amount0:", amount0);
            console.log("Collected fees. Amount1:", amount1);
        // _sendToOwner(tokenId, amount0, amount1);

        return (amount0, amount1);
}


function increaseLiquidityCurrentRange(uint256 tokenId,uint256 amountAdd0,uint256 amountAdd1)external onlyTrader returns (uint128 liquidity,uint256 amount0,uint256 amount1) {
        //uint256 slippageTolerance = 100; // 1% in basis points (100 basis points = 1%)
       // uint _amount0min = amountAdd0 - ((amountAdd0 * slippageTolerance) / 10000);
        //uint _amount1min = amountAdd0 - ((amountAdd0 * slippageTolerance) / 10000);

        TransferHelper.safeApprove(deposits[tokenId].token0,address(nonfungiblePositionManager), amountAdd0);
        TransferHelper.safeApprove(deposits[tokenId].token1,address(nonfungiblePositionManager), amountAdd1);

        INonfungiblePositionManager.IncreaseLiquidityParams memory params = INonfungiblePositionManager.IncreaseLiquidityParams({
            tokenId: tokenId,
            amount0Desired: amountAdd0,
            amount1Desired: amountAdd1,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp
        });

        (liquidity, amount0, amount1) = nonfungiblePositionManager.increaseLiquidity(params);
        console.log("liquidity:",liquidity);
        console.log("amount0:",amount0);
        console.log("amount1:",amount1);
        deposits[tokenId].liquidity += liquidity;

        emit liquidityIncreased(tokenId, deposits[tokenId].liquidity);
        return (liquidity, amount0, amount1);
}

function decreaseLiquidity(uint256 tokenId,uint128 percentage) public onlyTrader returns (uint256 amount0, uint256 amount1) {
        uint128 liquidity = deposits[tokenId].liquidity;
        uint128 removingLiquidity = (liquidity*percentage)/100;
        INonfungiblePositionManager.DecreaseLiquidityParams memory params =
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: removingLiquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            });

  


        (amount0, amount1) = nonfungiblePositionManager.decreaseLiquidity(params);
        deposits[tokenId].liquidity = liquidity - removingLiquidity;
        console.log(amount0,amount1,deposits[tokenId].liquidity);
        emit liquidityDecreased(tokenId, deposits[tokenId].liquidity);
        return (amount0, amount1);
}

    function getLiquidityPosition(uint256 _tokenId) public view returns (INFTManagerPosition.NFTPosition memory position) {
     position = nftPositionManager.positions(_tokenId);
    return position;
    }

function _sendToOwner(uint256 tokenId,uint256 amount0,uint256 amount1) internal {
        address owner = deposits[tokenId].owner;
        address token0 = deposits[tokenId].token0;
        address token1 = deposits[tokenId].token1;
          TransferHelper.safeTransfer(token0, owner, amount0);
        TransferHelper.safeTransfer(token1, owner, amount1);
}

function retrieveNFT(uint256 tokenId) onlyTrader external {
        require(msg.sender == trader, 'Not the trader');
        //remove information related to tokenId
        delete deposits[tokenId];
}


function balance_of_tokens(address _token) public view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
}

// percentageShare = investor_investment[user] * (10 ** decimal) / raised_amount
function percentageShare(address user)public view returns(uint){
    uint share = investor_investment[user] * (10 ** decimal) / raised_amount;
    return share;
}

//tokenToTransfer = userContribution * tokenBalanceInContract / (10 ** tokenDecimal)
function tokenToTransfer(address token,address user) public view returns (uint) { 
    uint tokenDecimal = IERC20(token).decimals();
    uint tokenBalanceInContract = IERC20(token).balanceOf(address(this));
    uint tokenAmount = percentageShare(user) * tokenBalanceInContract / (10 ** tokenDecimal);
    return tokenAmount;
}

function claimProfit(address token) public {
    //require(pool_deadline > block.timestamp,"you can't claim now");
    //require(raising_deadline > block.timestamp,"you can't claim now");
    uint tokenAmount = tokenToTransfer(token,msg.sender);
    IERC20(token).transfer(msg.sender,tokenAmount);
}

//this function can call by investors when trader makes delay to end the pool
function clearLiquidity(uint _id) public returns (uint256 amount0, uint256 amount1) {
    //require(pool_deadline < block.timestamp,"you can't end the pool,still active");
    INFTManagerPosition.NFTPosition memory position = getLiquidityPosition(_id);
    require(position.liquidity > 0,"pool already empty");
       uint128 liquidity = deposits[_id].liquidity;
       console.log(_id,liquidity);
        uint128 removingLiquidity = (liquidity*100)/100;
        INonfungiblePositionManager.DecreaseLiquidityParams memory params =
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: _id,
                liquidity: removingLiquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            });

       (amount0, amount1) = nonfungiblePositionManager.decreaseLiquidity(params);
       deposits[_id].liquidity = liquidity - removingLiquidity;
       emit liquidityDecreased(_id, deposits[_id].liquidity);
       return(amount0,amount1);
    
}

}



// function checkLiquidity(address pairAddress, uint256 minLiquidity) external view returns (bool) {
//     (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pairAddress).getReserves();
//     require(reserve0 >= minLiquidity || reserve1 >= minLiquidity, "Low Liquidity Pool");
//     return true;
// }

// function calculatePriceImpact(uint256 inputAmount, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
//     uint256 amountOut = (inputAmount * reserveOut) / (reserveIn + inputAmount);
//     uint256 priceImpact = ((reserveOut - amountOut) * 10000) / reserveOut;
//     return priceImpact; // Basis points
// }

//ganache-cli --fork.network mainnet --unlock 0x69166e49d2fd23E4cbEA767d7191bE423a7733A5


