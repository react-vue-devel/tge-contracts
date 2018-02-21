pragma solidity ^0.4.18;

import "./dependencies/token/ERC20/MintableToken.sol";
import "./dependencies/token/ERC20/PausableToken.sol";


contract LendroidSupportToken is MintableToken, PausableToken {

  string public constant name = "Lendroid Support Token";
  string public constant symbol = "LST";
  uint256 public constant decimals = 18;

  uint256 public constant MAX_SUPPLY = 12000000000 * (10 ** uint256(decimals));// 12 billion tokens, 18 decimal places

  /**
   * @dev Constructor that pauses tradability of tokens.
   */
  function LendroidSupportToken() public {
    paused = true;
    totalSupply_ = MAX_SUPPLY;
  }
}
