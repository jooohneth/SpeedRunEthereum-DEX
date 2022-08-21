// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract DEX {

    ///@notice Declaring token
    IERC20 token; 

    ///@notice Total Liquidity inside the contract
    uint public totalLiquidity;

    ///@notice Mapping of user to amount of liquidity added
    mapping(address => uint) public liquidity;

    
    ///@notice Emitted when ethToToken() swap transacted 
    event EthToTokenSwap(address indexed trader, string action, uint ethInput, uint tokenOutput);

    ///@notice Emitted when tokenToEth() swap transacted
    event TokenToEthSwap(address indexed trader, string action, uint tokenInput, uint ethOutput);

    ///@notice Emitted when liquidity provided to DEX and mints LPTs.
    event LiquidityProvided(address indexed liquidityProvider, uint liquidityAmount, uint ethAmount, uint tokenAmount);

    ///@notice Emitted when liquidity removed from DEX and decreases LPT count within DEX.
    event LiquidityRemoved(address indexed liquidityProvider, uint liquidityAmount, uint ethAmount, uint tokenAmount);

    constructor(address token_addr) public {
        token = IERC20(token_addr);
    }


    ///@notice initializes amount of tokens that will be transferred to the DEX itself. Loads contract up with both ETH and Balloons.
    ///@param tokens amount to be transferred to DEX
    ///@return totalLiquidity is the number of LPTs minting as a result of deposits made to DEX contract
    function init(uint tokens) public payable returns (uint) {

        require(totalLiquidity == 0, "Fail: can't call init if totalLiquidity != 0");

        totalLiquidity = address(this).balance;
        liquidity[msg.sender] = totalLiquidity;

        require(token.transferFrom(msg.sender, address(this), tokens), "Failed to transfer!");

        return totalLiquidity;

    }

    ///@notice Determines the price of a given asset
    ///@param xInput amount of asset that you want to swap
    ///@param xReserves amount of assets in liquidity pool for the asset that you want to swap
    ///@param yReserves amount of assets in liquidity pool for the asset that you want to swap to
    ///@return yOutput amount of asset that you want to swap to
    ///custom:mathExample ETH to BAL (excluding fees): ETH amount * Reserve of BAL / Reserve of ETH + ETH amount = BAL amount
    function price(uint xInput, uint xReserves, uint yReserves) public pure returns (uint yOutput) {
        
        uint numerator = (xInput * 997) * yReserves; 
        uint denominator = (xReserves * 1000) + (xInput * 997);

        return (numerator / denominator);

    }

    ///@notice Returns Liquidity provided by a given user/lp
    function getLiquidity(address lp) public view returns (uint) {
        return liquidity[lp];
    }

    ///@notice Swaps ETH to Token
    ///@dev Price function calculated using price function
    function ethToToken() public payable returns (uint tokenOutput) {
        require(msg.value > 0, "Provide ETH to swap!");

        uint xReserve = address(this).balance - msg.value;
        uint yReserve = token.balanceOf(address(this));

        tokenOutput = price(msg.value, xReserve, yReserve);

        require(token.transfer(msg.sender, tokenOutput), "Token transfer failed!");

        emit EthToTokenSwap(msg.sender, "ETH to Token", msg.value, tokenOutput);

    }

    ///@notice Swaps Token to ETH 
    ///@dev Price function calculated using price function
    function tokenToEth(uint tokenInput) public returns (uint ethOutput) {
        require(tokenInput > 0, "Proved Tokens to swap!");

        uint xReserve = token.balanceOf(address(this));
        uint yReserve = address(this).balance;

        ethOutput = price(tokenInput, xReserve, yReserve);

        require(token.transferFrom(msg.sender, address(this), tokenInput), "Token transfer failed!");

        (bool success, ) = msg.sender.call{value: ethOutput}("");
        require(success, "ETH transfer failed!");

        emit TokenToEthSwap(msg.sender, "Token to ETH", tokenInput, ethOutput);

    }

    ///@notice Deposits ETH and Token to liquidity pool
    ///@return tokenAmount Amount of tokens needed for the amount of ETH provided to keep the ration in liquidity pool
    function deposit() public payable returns (uint tokenAmount) {

        uint ethReserve = address(this).balance - msg.value;
        uint tokenReserve = token.balanceOf(address(this));

        tokenAmount = (msg.value * tokenReserve / ethReserve) + 1;

        uint liquidityMinted = msg.value * totalLiquidity / ethReserve;
        liquidity[msg.sender]  += liquidityMinted;
        totalLiquidity += liquidityMinted;

        require(token.transferFrom(msg.sender, address(this), tokenAmount));

        emit LiquidityProvided(msg.sender, liquidityMinted, msg.value, tokenAmount);

    }

    ///@notice Withdraws ETH and Token from liquidity pool
    ///@param amount Amount of liquidity provided
    ///@return ethAmount Amount of ETH to be withdrawn
    ///@return tokenAmount Amount of Tokens to be withdrawn
    function withdraw(uint amount) public returns (uint ethAmount, uint tokenAmount) {

        require(liquidity[msg.sender] >= amount, "Not enough Liquidity to withdraw!");

        uint ethReserve = address(this).balance;
        uint tokenReserve = token.balanceOf(address(this));

        ethAmount = amount * ethReserve / totalLiquidity;
        tokenAmount = amount * tokenReserve / totalLiquidity;

        liquidity[msg.sender] -= amount;
        totalLiquidity -= amount;

        (bool success, ) = msg.sender.call{value: ethAmount}("");
        require(success, "Transaction failed!");

        require(token.transfer(msg.sender, tokenAmount));

        emit LiquidityRemoved(msg.sender, amount, ethAmount, tokenAmount);

    }
}
